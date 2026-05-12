--  state_pension.adb
--  ============================================================================
--  Body — the implementation of the contract in state_pension.ads.
--  ============================================================================

package body State_Pension
  with SPARK_Mode => On
is

   --=========================================================================
   --  State_Pension_Start_Day — simplified statutory schedule.
   --
   --  Models Pensions Act 2014 + Pensions Act 2011 in three brackets,
   --  enough to demonstrate the type-discipline and proof shape without
   --  the full 28-line transitional table.
   --
   --  Production deployment would either expand this to the full table
   --  or replace it with a verified lookup against the DWP forecast
   --  service.  The postcondition in the spec — monotonic in DoB, gap
   --  in [60 years, 70 years] — guarantees no implementation can violate
   --  the statutory window.
   --
   --  Brackets (day-numbers epoched at 1901-01-01):
   --    DoB ≤ 21_644 (born on/before 6 April 1960):  SP age 66 → +24_107 d
   --    21_644 < DoB ≤ 27_854 (born ≤ 6 April 1977): SP age 67 → +24_472 d
   --    DoB > 27_854:                                SP age 68 → +24_837 d
   --=========================================================================

   function State_Pension_Start_Day (DoB : Date_Of_Birth_Day)
      return Day_Number
   is
   begin
      if DoB <= 21_644 then
         return DoB + 24_107;   --  66 × 365.25 ≈ 24_106.5
      elsif DoB <= 27_854 then
         return DoB + 24_472;   --  67 × 365.25 ≈ 24_471.75
      else
         return DoB + 24_837;   --  68 × 365.25 = 24_837
      end if;
   end State_Pension_Start_Day;

   --=========================================================================
   --  Decide — the main decision procedure.
   --
   --  Sequential elimination through the five mutually-exclusive cases.
   --  Each branch sets Reason explicitly before setting amount outputs,
   --  so gnatprove can match each branch to its postcondition clause.
   --=========================================================================

   procedure Decide
     (DWP           : in  DWP_Record;
      HMRC          : in  HMRC_Record;
      Citizen       : in  Citizen_Record;
      Context       : in  Query_Context;
      Weekly_Amount : out Weekly_Rate;
      Annual_Amount : out Annual_Total;
      Reason        : out Decision_Reason)
   is
   begin
      --  Case 1: cross-source records do not agree.
      if not Records_Agree (DWP, HMRC, Citizen) then
         Weekly_Amount := 0;
         Annual_Amount := 0;
         Reason        := Records_Disagree;
         return;
      end if;

      --  Case 2: not yet at State Pension age.
      if Context.As_Of_Date
            < State_Pension_Start_Day (DWP.Date_Of_Birth)
      then
         Weekly_Amount := 0;
         Annual_Amount := 0;
         Reason        := Pre_State_Pension_Age;
         return;
      end if;

      --  Case 3: insufficient qualifying years (below statutory minimum).
      if HMRC.Qualifying_Count < Qualifying_Year_Threshold then
         Weekly_Amount := 0;
         Annual_Amount := 0;
         Reason        := Below_Qualifying_Threshold;
         return;
      end if;

      --  Case 4 / 5: at-or-above minimum.  Pro-rata or full?
      if HMRC.Qualifying_Count >= Full_Year_Threshold then
         Weekly_Amount := Context.Full_New_Weekly_Rate;
         Annual_Amount := Weekly_Amount * 52;
         Reason        := Full_Entitlement;
      else
         Weekly_Amount := Context.Full_New_Weekly_Rate
                          * HMRC.Qualifying_Count
                          / Full_Year_Threshold;
         Annual_Amount := Weekly_Amount * 52;
         Reason        := Pro_Rata_Entitlement;
      end if;
   end Decide;

end State_Pension;
