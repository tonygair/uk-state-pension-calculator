# Specification — UK new State Pension qualifying-years calculator

Plain-English reading of `src/state_pension.ads`.

## What this calculates

For a UK citizen on the **post-2016 new State Pension** regime, decide:

- Whether they are currently entitled to State Pension at all
- If so, at what weekly and annual rate

The calculation is **point-in-time**: based on the qualifying years recorded
*so far*, not a projection of what they might accrue between now and their
State Pension age.

## Scope and limits

**In scope:**
- New State Pension only (Pensions Act 2014)
- Date-of-birth-based State Pension age lookup
- Qualifying-year count → entitlement-tier decision
- Pro-rata calculation between thresholds
- Three-source identity reconciliation (DWP / HMRC / Citizen)

**Out of scope — deliberately:**
- Pre-2016 basic State Pension + Additional State Pension (SERPS / S2P)
- Protected payment for the 1951-1995 transitional cohort
- Deferred-pension increments (delaying claim)
- Triple-lock projection — the weekly statutory rate is a query parameter,
  not encoded inside the proven core
- Pension Credit, Savings Credit, Guarantee Credit
- Overseas residence rules and reciprocal-agreement adjustments
- Married Women's Reduced Rate election history

## The three data sources

| Source | What it knows | Why type-distinct |
|---|---|---|
| **DWP** | Date of birth, benefit administration | The paying authority |
| **HMRC** | Date of birth, NI qualifying-year count | The contribution record |
| **Citizen** | Date of birth, self-asserted identity | The applicant's own claim |

Each source's `Subject_Id` is a distinct Ada type. The compiler **refuses to
silently confuse** a DWP_Subject_Id with an HMRC_Subject_Id. The only place
the type-distinction is dropped — via explicit cast to `Natural` — is inside
`Records_Agree`, which is the explicit cross-source reconciliation step.

## The decision tree

The `Decide` procedure exhausts five mutually-exclusive cases:

1. **Records_Disagree** — the three sources do not all agree on date of
   birth AND subject identity. **No entitlement is issued.**

2. **Pre_State_Pension_Age** — sources agree, but the claimant has not
   yet reached State Pension age. Zero entitlement; reapply later.

3. **Below_Qualifying_Threshold** — at State Pension age, but with fewer
   than 10 qualifying years on the NI record. Statutory minimum not met;
   zero entitlement.

4. **Pro_Rata_Entitlement** — at State Pension age, with between 10 and
   34 qualifying years. Weekly rate is the full statutory weekly rate
   multiplied by `qualifying_years / 35` (integer division).

5. **Full_Entitlement** — at State Pension age, with 35 or more
   qualifying years. Weekly rate equals the full statutory weekly rate.

The annual figure is always exactly `52 × weekly`, because the new State
Pension is paid weekly in arrears under Pensions Act 2014.

## What the formal proof guarantees

For **every input combination the type system admits**, `gnatprove`
machine-checks that:

- The reason returned is consistent with the inputs (each case's
  conditions are necessary and sufficient)
- The amount returned matches the formula stated for that case
- Zero entitlement is issued whenever the sources disagree
- Zero entitlement is issued whenever State Pension age has not been reached
- Zero entitlement is issued whenever qualifying-year count is below the
  statutory minimum
- The pro-rata formula scales linearly between the two thresholds
- The annual figure exactly equals 52 weekly payments
- No integer overflow occurs in any arithmetic on the bounded types
- No runtime exception is raised by any operation in the proven core

What the proof does NOT guarantee:

- That the statutory rates passed in are correct (the calling code is
  responsible for sourcing the current rate)
- That the date-of-birth and qualifying-year inputs are themselves
  correct (the calling code is responsible for sourcing accurate data
  from DWP and HMRC)
- That the State_Pension_Start_Day function's tabulated body matches the
  current statutory schedule (we prove monotonicity and reasonable
  bounds; the precise table is the engineer's responsibility — and is
  itself testable against the published DWP forecast service)

## The pattern this instantiates

This package is the second worked instantiation of The Dark Factory's
**SPARK statutory-calculator engine pattern**. The pattern itself:

- N data sources, each with a distinct typed Subject_Id
- An explicit `Records_Agree` reconciliation step
- A `Decide` procedure with a `Decision_Reason` enum
- A postcondition enumerating, by case, the conditions for each outcome
- Calendar conversion at the I/O boundary only

Chapter 1 (HMPPS sentence-release) instantiated this for 4 sources
(Court / NOMIS / OASys / Delius) and 7 decision reasons. This chapter
instantiates it for 3 sources (DWP / HMRC / Citizen) and 5 decision
reasons. **The shape is identical**; only the rules differ.

## Reuse — other calculators with the same shape

The engine pattern is naturally suited to any statutory eligibility-and-
proportion calculation. Concrete candidates across UK government:

| Calculator | Department | Why it fits the pattern |
|---|---|---|
| Home Detention Curfew (HDC) eligibility | MoJ | Same procurement scope as HMPPS — Chapter 3 candidate |
| NI qualifying-year record display | HMRC | Same data as this calculator, different presentation |
| Carer's Allowance eligibility | DWP | Threshold + earnings test |
| Statutory Sick Pay calculator | HMRC / DWP | Threshold + qualifying days |
| Court Fees calculator | MoJ | Banded fee schedule |
| Tax-Free Childcare eligibility | HMRC | Combined-income threshold |
| Pension Credit standard amount | DWP | Income-tested top-up |
| Council Tax band lookup | Local authorities | Banded property valuation |

This list is the literal demonstration of the "buy once, rather than
buying many times" position published in the *Roadmap for modern digital
government* (20 January 2026). One verified engine, many statutory
instantiations.
