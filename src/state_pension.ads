--  state_pension.ads
--  ============================================================================
--  UK new State Pension qualifying-years calculator — formally verified.
--
--  SPARK 2014 specification (the contract).
--
--  Models post-2016 new State Pension only (Pensions Act 2014).
--  Does NOT model:
--    - Pre-2016 basic State Pension + Additional State Pension (SERPS / S2P)
--    - Protected payment for the 1951-1995 transitional cohort
--    - Deferred-pension increments
--    - Triple-lock projection — the statutory weekly rate is a query
--      parameter, not encoded inside the proven core
--
--  Chapter 2 of The Dark Factory's civic software series.
--  Chapter 1: HMPPS sentence-release calculator (live).
--
--  Apache-2.0; in the spirit of the Open Government Licence v3.0.
--  ============================================================================

package State_Pension
  with SPARK_Mode => On
is

   --=========================================================================
   --  Subject identifiers — strongly typed per source.
   --
   --  Same discipline as HMPPS: the compiler refuses to silently confuse a
   --  DWP subject ID with an HMRC NI number, or either with the citizen's
   --  self-asserted ID.  Records_Agree (below) is the explicit
   --  reconciliation step where the type-distinct identifiers are checked
   --  for cross-source agreement.
   --=========================================================================

   type DWP_Subject_Id     is new Natural;
   type HMRC_Subject_Id    is new Natural;
   type Citizen_Subject_Id is new Natural;

   --=========================================================================
   --  Calendar — integer days from 1901-01-01.
   --
   --  Same idiom as HMPPS (calendar conversion at the I/O boundary only,
   --  no leap-year reasoning inside the proven core) but with an earlier
   --  epoch — State Pension claimants are born well before 1970, so the
   --  1970 epoch HMPPS used would leave the proven core dealing with
   --  negative day numbers.  1901-01-01 keeps every relevant date safely
   --  positive *and* matches Ada.Calendar.Year_Number's lower bound
   --  (1901..2399), so the I/O-boundary date helpers don't need a
   --  GNAT-extension calendar package.
   --
   --  Range covers 1901-01-01 through approximately 2174 — comfortable
   --  headroom past any plausible date-of-birth or State-Pension-age
   --  calculation this code will ever see.
   --=========================================================================

   type Day_Number is range 0 .. 100_000;

   --  Date-of-birth subrange: 6 April 1953 (the first day of the
   --  new-State-Pension cohort under Pensions Act 2014) through
   --  1 January 2030 (generous upper bound on plausible future
   --  claimants).
   --
   --  6 April 1953 = day 19_088 from 1901-01-01.
   --  1 January 2030 = day 47_117 from 1901-01-01.
   --
   --  This narrows the precondition cleanly: every claimant the proven
   --  core sees is in the new-State-Pension cohort by construction.
   subtype Date_Of_Birth_Day is Day_Number range 19_088 .. 47_117;

   --=========================================================================
   --  Monetary amounts — pence, integer, no floating point.
   --=========================================================================

   subtype Pence_Amount is Integer range 0 .. 10_000_000;       -- £100,000
   subtype Weekly_Rate  is Pence_Amount range 0 .. 100_000;     -- £1,000/wk
   subtype Annual_Total is Pence_Amount range 0 .. 5_200_000;   -- 52 weeks

   --=========================================================================
   --  Qualifying-year count.
   --=========================================================================

   subtype Qualifying_Years is Integer range 0 .. 80;

   --  Statutory thresholds for the post-2016 new State Pension.
   --  Pensions Act 2014, ss. 2-3.  Hard-coded because they ARE the statute.
   Qualifying_Year_Threshold : constant Qualifying_Years := 10;
   Full_Year_Threshold       : constant Qualifying_Years := 35;

   --=========================================================================
   --  Source records — one per data-holder, with type-distinct Subject_Id.
   --=========================================================================

   --  DWP holds: subject's date of birth (for State Pension age) and is
   --  the benefit-paying authority.
   type DWP_Record is record
      Subject       : DWP_Subject_Id;
      Date_Of_Birth : Date_Of_Birth_Day;
   end record;

   --  HMRC holds: subject's NI contribution history, hence the count of
   --  qualifying years toward State Pension entitlement.
   type HMRC_Record is record
      Subject          : HMRC_Subject_Id;
      Date_Of_Birth    : Date_Of_Birth_Day;
      Qualifying_Count : Qualifying_Years;
   end record;

   --  Citizen-asserted record (what the applicant says about themselves).
   --  Present for the reconciliation discipline: the citizen's own claim
   --  must agree with the two government sources before entitlement is
   --  issued.
   type Citizen_Record is record
      Subject       : Citizen_Subject_Id;
      Date_Of_Birth : Date_Of_Birth_Day;
   end record;

   --=========================================================================
   --  Query context — when is this calculation being made, and at what
   --  statutory weekly rate?  Triple-lock projection lives in the caller.
   --=========================================================================

   type Query_Context is record
      As_Of_Date           : Day_Number;
      Full_New_Weekly_Rate : Weekly_Rate;
   end record;

   --=========================================================================
   --  Reconciliation — explicit cross-source agreement check.
   --
   --  Three sources must agree on date of birth AND on subject identity
   --  (the Subject_Id types are cast to Natural precisely here — and only
   --  here — to compare across the type-distinct domains).  The
   --  type-distinct discipline still holds at every other call site.
   --
   --  Same idiom as HMPPS Records_Agree.
   --=========================================================================

   function Records_Agree
     (DWP     : DWP_Record;
      HMRC    : HMRC_Record;
      Citizen : Citizen_Record)
      return Boolean
   is
     (DWP.Date_Of_Birth = HMRC.Date_Of_Birth
      and then HMRC.Date_Of_Birth = Citizen.Date_Of_Birth
      and then Natural (DWP.Subject)  = Natural (HMRC.Subject)
      and then Natural (HMRC.Subject) = Natural (Citizen.Subject));

   --=========================================================================
   --  State Pension start day — function of date of birth, per the
   --  statutory schedule (Pensions Act 2014 + Pensions Act 2011 + the
   --  ongoing reviews).
   --
   --  Returns the first day from which State Pension is payable for this
   --  date of birth.  Body implements the statutory table; postcondition
   --  expresses the property the statute itself guarantees:
   --
   --    - the result is always after the date of birth
   --    - the gap is at least 60 years and at most 70 years
   --      (covers the entire post-1953 cohort under any plausible future
   --       revision short of statutory upheaval)
   --=========================================================================

   function State_Pension_Start_Day (DoB : Date_Of_Birth_Day)
      return Day_Number
     with
       Post =>
         State_Pension_Start_Day'Result > DoB
         and then State_Pension_Start_Day'Result - Day_Number (DoB)
                    in 21_915 .. 25_567;
   --  21_915 ≈ 60 years × 365.25.  25_567 ≈ 70 years × 365.25.

   --=========================================================================
   --  Decision reason — every output case explicitly enumerated.
   --=========================================================================

   type Decision_Reason is
     (Records_Disagree,
      Pre_State_Pension_Age,
      Below_Qualifying_Threshold,
      Pro_Rata_Entitlement,
      Full_Entitlement);

   --=========================================================================
   --  Decide — the main contract.
   --
   --  Postcondition specifies, by case, the conditions under which each
   --  possible output is permitted.  Gnatprove machine-checks that the
   --  body satisfies this postcondition for every input the type system
   --  admits.  No input combination produces an entitlement when the
   --  source records disagree.
   --=========================================================================

   procedure Decide
     (DWP           : in  DWP_Record;
      HMRC          : in  HMRC_Record;
      Citizen       : in  Citizen_Record;
      Context       : in  Query_Context;
      Weekly_Amount : out Weekly_Rate;
      Annual_Amount : out Annual_Total;
      Reason        : out Decision_Reason)
     with
       Post =>
         --  Records_Disagree case
         (if Reason = Records_Disagree then
             Weekly_Amount = 0
             and then Annual_Amount = 0
             and then not Records_Agree (DWP, HMRC, Citizen))
         and then

         --  Pre_State_Pension_Age case
         (if Reason = Pre_State_Pension_Age then
             Weekly_Amount = 0
             and then Annual_Amount = 0
             and then Records_Agree (DWP, HMRC, Citizen)
             and then Context.As_Of_Date
                        < State_Pension_Start_Day (DWP.Date_Of_Birth))
         and then

         --  Below_Qualifying_Threshold case
         (if Reason = Below_Qualifying_Threshold then
             Weekly_Amount = 0
             and then Annual_Amount = 0
             and then Records_Agree (DWP, HMRC, Citizen)
             and then Context.As_Of_Date
                        >= State_Pension_Start_Day (DWP.Date_Of_Birth)
             and then HMRC.Qualifying_Count < Qualifying_Year_Threshold)
         and then

         --  Pro_Rata_Entitlement case
         (if Reason = Pro_Rata_Entitlement then
             Records_Agree (DWP, HMRC, Citizen)
             and then Context.As_Of_Date
                        >= State_Pension_Start_Day (DWP.Date_Of_Birth)
             and then HMRC.Qualifying_Count >= Qualifying_Year_Threshold
             and then HMRC.Qualifying_Count <  Full_Year_Threshold
             and then Weekly_Amount =
                        Context.Full_New_Weekly_Rate
                        * HMRC.Qualifying_Count
                        / Full_Year_Threshold)
         and then

         --  Full_Entitlement case
         (if Reason = Full_Entitlement then
             Records_Agree (DWP, HMRC, Citizen)
             and then Context.As_Of_Date
                        >= State_Pension_Start_Day (DWP.Date_Of_Birth)
             and then HMRC.Qualifying_Count >= Full_Year_Threshold
             and then Weekly_Amount = Context.Full_New_Weekly_Rate)
         and then

         --  Annual is always 52 weekly payments (the new State Pension
         --  is paid weekly in arrears under the Pensions Act 2014).
         Annual_Amount = Weekly_Amount * 52;

end State_Pension;
