--  state_pension_demo.adb
--  ============================================================================
--  CLI driver — exercises every Decision_Reason in the proven core.
--
--  Same shape as the HMPPS demo: a small set of typed test cases, one per
--  decision path, that show the contract working without invoking any
--  calendar logic.  All Day_Number values are integers from 1900-01-01.
--  ============================================================================

with Ada.Text_IO;        use Ada.Text_IO;
with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with State_Pension;       use State_Pension;

procedure State_Pension_Demo is

   --  Statutory weekly rate to use across the demo — 2025-26 new State
   --  Pension rate of £230.25/week, expressed as pence (23_025).
   Demo_Weekly : constant Weekly_Rate := 23_025;

   --  An "as of" date well into the future (1 January 2030 = day 47_117
   --  from 1901-01-01) so every claimant in our demo has plausibly
   --  reached State Pension age by the as-of moment, except the
   --  deliberately-too-young case.
   Demo_As_Of : constant Day_Number := 47_117;

   --  A canonical date of birth in the new-State-Pension cohort:
   --  6 April 1953 = day 19_088 from 1901-01-01.
   Demo_DoB   : constant Date_Of_Birth_Day := 19_088;

   --  Canonical context.
   Demo_Ctx : constant Query_Context :=
     (As_Of_Date           => Demo_As_Of,
      Full_New_Weekly_Rate => Demo_Weekly);

   procedure Show
     (Label  : Standard.String;
      DWP    : DWP_Record;
      HMRC   : HMRC_Record;
      Citi   : Citizen_Record;
      Ctx    : Query_Context := Demo_Ctx)
   is
      Weekly : Weekly_Rate;
      Annual : Annual_Total;
      Reason : Decision_Reason;
   begin
      Decide (DWP, HMRC, Citi, Ctx, Weekly, Annual, Reason);
      Put_Line ("[" & Label & "]");
      Put_Line ("  Reason: " & Decision_Reason'Image (Reason));
      Put      ("  Weekly: ");  Put (Weekly, 0);
      Put_Line (" pence");
      Put      ("  Annual: ");  Put (Annual, 0);
      Put_Line (" pence");
      New_Line;
   end Show;

begin
   Put_Line ("UK new State Pension qualifying-years calculator");
   Put_Line ("================================================");
   Put_Line ("Statutory weekly rate: 23_025 pence (£230.25/week)");
   Put_Line ("As of date:            day 47_482 (1 January 2030)");
   New_Line;

   --  Case 1: Records_Disagree (DWP and HMRC disagree on DoB).
   Show ("Case 1: DWP and HMRC disagree on date of birth",
         DWP  => (Subject => 12_345, Date_Of_Birth => Demo_DoB),
         HMRC => (Subject => 12_345, Date_Of_Birth => Demo_DoB + 100,
                  Qualifying_Count => 35),
         Citi => (Subject => 12_345, Date_Of_Birth => Demo_DoB));

   --  Case 2: Pre_State_Pension_Age (as-of date is BEFORE the claimant's
   --  State Pension age).  Claimant born late, querying too early.
   Show ("Case 2: As-of date precedes State Pension age",
         DWP  => (Subject => 12_345, Date_Of_Birth => Date_Of_Birth_Day (40_000)),
         HMRC => (Subject => 12_345, Date_Of_Birth => Date_Of_Birth_Day (40_000),
                  Qualifying_Count => 35),
         Citi => (Subject => 12_345, Date_Of_Birth => Date_Of_Birth_Day (40_000)),
         Ctx  => (As_Of_Date           => 47_117,
                  Full_New_Weekly_Rate => Demo_Weekly));

   --  Case 3: Below_Qualifying_Threshold (9 years on the NI record).
   Show ("Case 3: Below qualifying threshold (9 years)",
         DWP  => (Subject => 12_345, Date_Of_Birth => Demo_DoB),
         HMRC => (Subject => 12_345, Date_Of_Birth => Demo_DoB,
                  Qualifying_Count => 9),
         Citi => (Subject => 12_345, Date_Of_Birth => Demo_DoB));

   --  Case 4: Pro_Rata_Entitlement (20 years → 20/35 of full rate).
   Show ("Case 4: Pro-rata entitlement (20 of 35 years)",
         DWP  => (Subject => 12_345, Date_Of_Birth => Demo_DoB),
         HMRC => (Subject => 12_345, Date_Of_Birth => Demo_DoB,
                  Qualifying_Count => 20),
         Citi => (Subject => 12_345, Date_Of_Birth => Demo_DoB));

   --  Case 5: Full_Entitlement (35+ qualifying years).
   Show ("Case 5: Full entitlement (35 years)",
         DWP  => (Subject => 12_345, Date_Of_Birth => Demo_DoB),
         HMRC => (Subject => 12_345, Date_Of_Birth => Demo_DoB,
                  Qualifying_Count => 35),
         Citi => (Subject => 12_345, Date_Of_Birth => Demo_DoB));

end State_Pension_Demo;
