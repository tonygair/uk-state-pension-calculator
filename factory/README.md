# Factory provenance — machine-produced artifacts

This directory captures **how the Chapter 2 calculator was produced
through The Dark Factory's `ada-verified` pipeline**, including the
structured inputs that drove the factory and the artifacts the factory
emitted.

The `src/` directory at the repo root holds the **hand-written
reference implementation**. The `factory/output/` directory here holds
the **machine-produced equivalent** generated from the inputs in
`factory/inputs/` — these are not the same files; they are independent
proofs that the factory pipeline can produce a verified body from a
structured spec.

## What's here

```
factory/
├── inputs/
│   ├── spec.json              ← functional requirements + acceptance criteria
│   ├── planner_result.json    ← per-file purpose + interface signatures
│   └── test_cases.json        ← 5 test cases × 3 checks = 15 assertions
│                                covering all five Decision_Reason paths
└── output/
    ├── state_pension.ads      ← .ads produced by qwen3-coder + R1-R11 rules
    ├── state_pension.adb      ← .adb produced by Kevin's investigation loop
    │                            (N=3 candidates; winner passed compile +
    │                             gnatprove --level=0 + 5-case component test)
    └── coder_result.json      ← audit trail (files written, line counts,
                                  Kevin signatures fired, probe results)
```

## How to reproduce

Requires the forge orchestrator + Kevin service running on Gertrude
with qwen3-coder via Ollama. Validated 2026-05-12 ~16:00 BST.

```bash
# Stage the workspace
mkdir -p /tmp/sp-forge-test/src
cp factory/inputs/{spec,planner_result,test_cases}.json /tmp/sp-forge-test/
echo "module placeholder" > /tmp/sp-forge-test/go.mod

# Drive the forge
ssh gertrude.local '
  export PATH=~/.local/bin:$PATH
  export OPENAI_BASE_URL=http://127.0.0.1:11434/v1
  export FORGE_AGENT_MODEL=qwen3-coder:30b-a3b-q4_K_M
  export FORGE_MAX_TOKENS=8000
  export KEVIN_BASE_URL=http://127.0.0.1:8094
  cd ~/darkfactory-testbed/build-src/forge/agents/coder
  bb agent.bb --mode full --target ada-verified \
     --workspace /tmp/sp-forge-test \
     --job-id state-pension-chapter-2
'
```

Expected wall-clock: ~45–60 seconds (single .ads file).

Expected output: `[kevin] wrote /tmp/sp-forge-test/src/state_pension.adb
(sigs=2, compiled=true, proved=true, component_tested=true)`.

## The probe stack run on each candidate

The factory's `kevin-bodyfill!` post-pass invokes Kevin's `/generate`
with `prove=true` and inlined `test_cases`. For each of N=3 candidates
sampled at varied (seed, temperature), Kevin runs three probes in
sequence:

1. **`gnatmake -gnatc`** — structural / type-system / visibility check
   (~30 ms per candidate)
2. **`gnatprove --level=0`** — formal verification of the spec's
   Pre/Post obligations against the candidate body (~2 s per candidate)
3. **Component-tier test driver** — compiles a generated test driver
   that exercises all 5 test cases from `test_cases.json`, runs it,
   decodes the exit code (`100 + 10*case_index + check_index`) to
   identify any failed assertion (~50–100 ms per candidate)

First candidate passing all three wins. If none pass, Kevin's
example-construction recovery loop runs one final retry with the
strongest amygdala-signature one-shot prepended.

## Why two implementations

The `src/` reference and the `factory/output/` body **discharge the
same 8/8 gnatprove obligations** but differ in implementation choice
(notably `State_Pension_Start_Day`'s body — the factory picks any
delta in the spec's [21_915, 25_567] postcondition window;
implementations have varied across runs from 21_915 (60 years) to
24_107 (66.0 years) to 23_232 (63.6 years)).

This is **the inversion architecture working as designed**: the spec
is the contract wall; any body that satisfies the contract is
acceptable. The factory finds *a* body; the reference shows *one
specific* statutorily-realistic body that also satisfies the contract.

For richer factory output, tighten the spec's postcondition. The
deliberate looseness here demonstrates the factory can find any
satisfying solution; production code would constrain
`State_Pension_Start_Day` more sharply.

## Drift discipline

The forge commit that wired the test ladder into `kevin-bodyfill!` is
**`731c99e` on `~/darkfactory-testbed/build-src/forge/.git`**. Local
on Gertrude; **needs pushing to `github.com/tonygair/forge` from
Tony's hands**.

Memory note: `project_factory_test_ladder_wired_done_2026_05_12.md`.
