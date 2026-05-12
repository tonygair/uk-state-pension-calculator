# uk-state-pension-calculator

> **Chapter 2 of The Dark Factory's civic software series.
> Chapter 1: [HMPPS sentence-release calculator](https://github.com/tonygair/hmpps-release-calculator) (live).**

A formally-verified UK new State Pension qualifying-years calculator, in
SPARK 2014.

Released under Apache License 2.0 — in the spirit of the Open Government
Licence v3.0, the standard re-use licence for UK public-sector
information. Adopt, fork, modify, or ignore without obligation.

## Status

**Specification phase.** The SPARK contract (`src/state_pension.ads`) is
written and reviewable. Body and proof obligations come next.

## What this is

A worked illustration that the SPARK statutory-calculator engine pattern
generalises beyond MoJ. Same discipline as Chapter 1: distinct typed
identifiers per data source, explicit cross-source reconciliation, a
single proven `Decide` procedure whose postcondition enumerates every
output case the type system admits.

Three data sources (DWP / HMRC / Citizen). Five decision reasons. One
contract. Compiler enforces the type discipline; `gnatprove`
machine-checks the body against the contract.

## What this is NOT

- A deployed State Pension service.
- A model of the full historical State Pension regime (no SERPS / S2P, no
  protected payments, no deferred-pension increments).
- A model of triple-lock projection — statutory rates are query
  parameters, not encoded inside the proven core.
- A claim that government should adopt this without further work. The
  intended reader's response is *"what would a production version need?"*
  — not *"deploy this."*

## What this demonstrates

UK government has historically procured variants of this same calculation
multiple times across multiple departments — DWP forecast services,
HMRC NI record displays, GOV.UK content pages, third-party tools. Each
procurement re-pays the cost of getting the rules right.

A single SPARK-verified engine, parameterised by the statutory rules of
the specific instantiation, removes that duplication. Per the *Roadmap
for modern digital government* (20 January 2026), pillar 5: *"buy once,
rather than buying many times."*

The engine pattern's other candidate instantiations are listed in
[doc/SPECIFICATION.md](doc/SPECIFICATION.md#reuse--other-calculators-with-the-same-shape).

## Files

| Path | Contents |
|---|---|
| `src/state_pension.ads` | Specification — the contract |
| `src/state_pension.adb` | Body — TODO (specification phase) |
| `doc/SPECIFICATION.md` | Plain-English reading of the spec |
| `doc/ENGINE-PATTERN.md` | The reusable shape — TODO |
| `OPEN-LETTER.md` | Covering letter to the digital-reform conversation — TODO |
| `LICENSE` | Apache License 2.0 |

## Commercial enquiries

This calculator is a free public gift under Apache-2.0 — adopt it
without obligation.

If you'd like to commission a production-grade version, or to apply the
same formally-verified approach to other civilian government calculators,
contact `tony.gair@thedarkfactory.co.uk`.

## Author

Tony Gair, The Dark Factory Ltd (Sunderland), May 2026.
