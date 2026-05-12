--  state_pension_gui.adb
--  ============================================================================
--  Gnoga front-end for the UK new State Pension qualifying-years calculator.
--
--  Single-stack Ada: the SPARK-verified core (State_Pension.Decide) is
--  called directly from the GUI handler.  No FFI, no JSON, no IPC.
--  ============================================================================

with Ada.Exceptions;
with Ada.Calendar;
with Ada.Calendar.Arithmetic;
with Ada.Calendar.Formatting;

with UXStrings;

with Gnoga;
with Gnoga.Application.Multi_Connect;
with Gnoga.Gui.Base;
with Gnoga.Gui.Element.Common;
with Gnoga.Gui.Element.Form;
with Gnoga.Types;
with Gnoga.Gui.View;
with Gnoga.Gui.Window;

with State_Pension;

procedure State_Pension_Gui is
   use Gnoga;
   use all type Gnoga.String;

   Disclaimer_Banner : constant Gnoga.String :=
     "DEMONSTRATOR ONLY. New State Pension (post-2016) qualifying years "
     & "only. Does NOT model pre-2016 basic State Pension, SERPS/S2P, "
     & "protected payments, deferred-pension increments, or triple-lock "
     & "projection. NOT for use in real entitlement decisions.";

   --------------------------------------------------------------------
   --  Calendar helpers — GUI-layer only (NOT in the SPARK core).
   --
   --  Epoch is 1901-01-01.  State Pension claimants are born before 1970,
   --  so the HMPPS 1970 epoch would leave the proven core with negative
   --  day numbers; 1901 keeps every relevant date safely positive and
   --  matches Ada.Calendar.Year_Number's 1901..2399 range.
   --------------------------------------------------------------------

   function Days_Since_Epoch (Date_Str : Standard.String) return Integer is
      use Ada.Calendar;
      use Ada.Calendar.Arithmetic;
      Epoch : constant Time := Time_Of (1901, 1, 1);
      T     : constant Time := Time_Of
        (Year   => Year_Number   (Integer'Value (Date_Str (Date_Str'First     .. Date_Str'First + 3))),
         Month  => Month_Number  (Integer'Value (Date_Str (Date_Str'First + 5 .. Date_Str'First + 6))),
         Day    => Day_Number    (Integer'Value (Date_Str (Date_Str'First + 8 .. Date_Str'First + 9))));
      Days  : Day_Count;
      Secs  : Duration;
      Lps   : Leap_Seconds_Count;
   begin
      Difference (T, Epoch, Days, Secs, Lps);
      return Integer (Days);
   end Days_Since_Epoch;

   function Day_Num_To_Date_String (D : Integer) return Standard.String is
      use Ada.Calendar;
      use Ada.Calendar.Arithmetic;
      Epoch : constant Time := Time_Of (1901, 1, 1);
      T     : constant Time := Epoch + Day_Count (D);
      Img   : constant Standard.String := Ada.Calendar.Formatting.Image (T);
   begin
      return Img (Img'First .. Img'First + 9);
   end Day_Num_To_Date_String;

   --------------------------------------------------------------------
   --  Per-connection state.
   --------------------------------------------------------------------

   type App_Info is new Gnoga.Types.Connection_Data_Type with record
      Window     : Gnoga.Gui.Window.Pointer_To_Window_Class;
      View       : Gnoga.Gui.View.View_Type;

      Banner     : Gnoga.Gui.Element.Common.DIV_Type;
      Title      : Gnoga.Gui.Element.Common.DIV_Type;

      Form       : Gnoga.Gui.Element.Form.Form_Type;

      DWP_Sub_L     : Gnoga.Gui.Element.Form.Label_Type;
      DWP_Sub       : Gnoga.Gui.Element.Form.Number_Type;
      HMRC_Sub_L    : Gnoga.Gui.Element.Form.Label_Type;
      HMRC_Sub      : Gnoga.Gui.Element.Form.Number_Type;
      Citizen_Sub_L : Gnoga.Gui.Element.Form.Label_Type;
      Citizen_Sub   : Gnoga.Gui.Element.Form.Number_Type;

      DoB_L     : Gnoga.Gui.Element.Form.Label_Type;
      DoB       : Gnoga.Gui.Element.Form.Date_Type;

      Q_Years_L : Gnoga.Gui.Element.Form.Label_Type;
      Q_Years   : Gnoga.Gui.Element.Form.Number_Type;

      As_Of_L   : Gnoga.Gui.Element.Form.Label_Type;
      As_Of     : Gnoga.Gui.Element.Form.Date_Type;

      Rate_L    : Gnoga.Gui.Element.Form.Label_Type;
      Rate      : Gnoga.Gui.Element.Form.Number_Type;

      Result_Reason : Gnoga.Gui.Element.Common.DIV_Type;
      Result_Weekly : Gnoga.Gui.Element.Common.DIV_Type;
      Result_Annual : Gnoga.Gui.Element.Common.DIV_Type;
      Result_Start  : Gnoga.Gui.Element.Common.DIV_Type;

      Footer        : Gnoga.Gui.Element.Common.DIV_Type;

      Calculate     : Gnoga.Gui.Element.Form.Submit_Button_Type;
   end record;

   type App_Ptr is access all App_Info;

   --------------------------------------------------------------------
   --  Format pence as £x.xx string fragment.
   --------------------------------------------------------------------

   function Pence_To_Pounds_String (P : Integer) return Standard.String is
      Pounds : constant Integer := P / 100;
      Pennies : constant Integer := P mod 100;
   begin
      if Pennies < 10 then
         return Integer'Image (Pounds) & ".0" & Integer'Image (Pennies)
                  (Integer'Image (Pennies)'First + 1 .. Integer'Image (Pennies)'Last);
      else
         return Integer'Image (Pounds) & "."  & Integer'Image (Pennies)
                  (Integer'Image (Pennies)'First + 1 .. Integer'Image (Pennies)'Last);
      end if;
   end Pence_To_Pounds_String;

   --------------------------------------------------------------------
   --  Calculate handler — calls into the SPARK core.
   --------------------------------------------------------------------

   procedure On_Calculate (Object : in out Gnoga.Gui.Base.Base_Type'Class) is
      App : constant App_Ptr := App_Ptr (Object.Connection_Data);
      use State_Pension;

      DWP_Sub_I     : constant Integer := Value (App.DWP_Sub.Value);
      HMRC_Sub_I    : constant Integer := Value (App.HMRC_Sub.Value);
      Citizen_Sub_I : constant Integer := Value (App.Citizen_Sub.Value);
      DoB_I         : constant Integer :=
        Days_Since_Epoch (UXStrings.To_UTF_8 (App.DoB.Value));
      Q_Years_I     : constant Integer := Value (App.Q_Years.Value);
      As_Of_I       : constant Integer :=
        Days_Since_Epoch (UXStrings.To_UTF_8 (App.As_Of.Value));
      Rate_I        : constant Integer := Value (App.Rate.Value);

      DWP_R  : DWP_Record;
      HMRC_R : HMRC_Record;
      Citi_R : Citizen_Record;
      Ctx    : Query_Context;
      Weekly : Weekly_Rate;
      Annual : Annual_Total;
      Reason : Decision_Reason;
   begin
      DWP_R  := (Subject => DWP_Subject_Id (Natural (DWP_Sub_I)),
                 Date_Of_Birth => Date_Of_Birth_Day (DoB_I));
      HMRC_R := (Subject => HMRC_Subject_Id (Natural (HMRC_Sub_I)),
                 Date_Of_Birth => Date_Of_Birth_Day (DoB_I),
                 Qualifying_Count => Qualifying_Years (Q_Years_I));
      Citi_R := (Subject => Citizen_Subject_Id (Natural (Citizen_Sub_I)),
                 Date_Of_Birth => Date_Of_Birth_Day (DoB_I));
      Ctx    := (As_Of_Date           => Day_Number (As_Of_I),
                 Full_New_Weekly_Rate => Weekly_Rate (Rate_I));

      Decide (DWP_R, HMRC_R, Citi_R, Ctx, Weekly, Annual, Reason);

      App.Result_Reason.Inner_HTML
        ("<strong>" & From_UTF_8 (Decision_Reason'Image (Reason)) & "</strong>");

      App.Result_Weekly.Inner_HTML
        ("Weekly: <strong>" & Image (Integer (Weekly)) & " pence (£"
         & From_UTF_8 (Pence_To_Pounds_String (Integer (Weekly))) & ")</strong>");

      App.Result_Annual.Inner_HTML
        ("Annual: <strong>" & Image (Integer (Annual)) & " pence (£"
         & From_UTF_8 (Pence_To_Pounds_String (Integer (Annual))) & ")</strong>");

      if Reason = Records_Disagree then
         App.Result_Start.Inner_HTML ("(records disagree)");
      else
         App.Result_Start.Inner_HTML
           ("State Pension start date: <strong>"
            & From_UTF_8 (Day_Num_To_Date_String
                          (Integer (State_Pension_Start_Day
                                    (Date_Of_Birth_Day (DoB_I)))))
            & "</strong>");
      end if;
   exception
      when E : others =>
         App.Result_Reason.Inner_HTML
           ("ERROR: " & From_UTF_8 (Ada.Exceptions.Exception_Message (E)));
         App.Result_Weekly.Inner_HTML ("");
         App.Result_Annual.Inner_HTML ("");
         App.Result_Start.Inner_HTML  ("");
   end On_Calculate;

   --------------------------------------------------------------------
   --  Connection setup.
   --------------------------------------------------------------------

   procedure On_Connect
     (Main_Window : in out Gnoga.Gui.Window.Window_Type'Class;
      Connection  :    access Gnoga.Application.Multi_Connect.Connection_Holder_Type)
   is
      pragma Unreferenced (Connection);
      App : constant App_Ptr := new App_Info;
   begin
      Main_Window.Connection_Data (Data => App);
      App.Window := Main_Window'Unchecked_Access;

      App.View.Create (Parent => Main_Window);
      App.View.Box_Width (Value => 760);

      App.Banner.Create  (Parent => App.View, Content => Disclaimer_Banner);
      App.Banner.Background_Color ("#fff3cd");
      App.Banner.Color  ("#664d03");

      App.Title.Create (Parent => App.View,
                        Content =>
                          "<h2>UK new State Pension qualifying-years calculator</h2>"
                          & "<p>Formally-verified Ada/SPARK 2014 demonstrator. "
                          & "<a href=""https://github.com/tonygair/uk-state-pension-calculator"" target=""_blank"">"
                          & "Source &amp; proof on GitHub.</a></p>");

      App.Form.Create (Parent => App.View);

      App.DWP_Sub.Create (Form => App.Form);
      App.DWP_Sub.Value (12345);
      App.DWP_Sub_L.Create (Form => App.Form, Label_For => App.DWP_Sub,
                            Content => "DWP subject ID: ");
      App.Form.New_Line;

      App.HMRC_Sub.Create (Form => App.Form);
      App.HMRC_Sub.Value (12345);
      App.HMRC_Sub_L.Create (Form => App.Form, Label_For => App.HMRC_Sub,
                             Content => "HMRC subject ID: ");
      App.Form.New_Line;

      App.Citizen_Sub.Create (Form => App.Form);
      App.Citizen_Sub.Value (12345);
      App.Citizen_Sub_L.Create (Form => App.Form, Label_For => App.Citizen_Sub,
                                Content => "Citizen subject ID: ");
      App.Form.New_Line;

      App.DoB.Create (Form => App.Form);
      App.DoB.Value ("1958-04-06");
      App.DoB_L.Create (Form => App.Form, Label_For => App.DoB,
                        Content => "Date of birth (after 6 Apr 1953): ");
      App.Form.New_Line;

      App.Q_Years.Create (Form => App.Form);
      App.Q_Years.Value (35);
      App.Q_Years_L.Create (Form => App.Form, Label_For => App.Q_Years,
                            Content => "HMRC qualifying years: ");
      App.Form.New_Line;

      App.As_Of.Create (Form => App.Form);
      App.As_Of.Value ("2026-04-06");
      App.As_Of_L.Create (Form => App.Form, Label_For => App.As_Of,
                          Content => "As-of date: ");
      App.Form.New_Line;

      App.Rate.Create (Form => App.Form);
      App.Rate.Value (23025);
      App.Rate_L.Create (Form => App.Form, Label_For => App.Rate,
                         Content => "Full new SP weekly rate (pence): ");
      App.Form.New_Line;
      App.Form.New_Line;

      App.Calculate.Create (Form => App.Form, Value => "Calculate");
      App.Form.On_Submit_Handler (Handler => On_Calculate'Unrestricted_Access);
      App.Form.New_Line;
      App.Form.New_Line;

      App.Result_Reason.Create (Parent => App.View, Content => "(awaiting input)");
      App.Result_Weekly.Create (Parent => App.View, Content => "");
      App.Result_Annual.Create (Parent => App.View, Content => "");
      App.Result_Start.Create  (Parent => App.View, Content => "");

      App.Footer.Create
        (Parent  => App.View,
         Content =>
           "<hr style=""margin-top:2em""/>"
           & "<p><small><em>Worked demonstrator by "
           & "<strong>The Dark Factory Ltd</strong>, Sunderland. "
           & "Chapter 2 of our civic software series — "
           & "Chapter 1: <a href=""https://hmpps-release-demo.thedarkfactory.dev/"" target=""_blank"">"
           & "HMPPS sentence-release calculator</a>. "
           & "To commission a production version, or apply the same "
           & "formally-verified approach to other civilian government "
           & "calculators, contact "
           & "<a href=""mailto:tony.gair@thedarkfactory.co.uk"">"
           & "tony.gair@thedarkfactory.co.uk</a>.</em></small></p>");
   exception
      when E : others =>
         Gnoga.Log (Message => "On_Connect: ", Occurrence => E);
   end On_Connect;

begin
   Gnoga.Application.Title (Name =>
     "UK State Pension Calculator — Demonstrator");
   Gnoga.Application.HTML_On_Close
     (HTML => "Demonstrator closed.");
   Gnoga.Application.Multi_Connect.Initialize (Port => 8089);
   Gnoga.Application.Multi_Connect.On_Connect_Handler
     (Event => On_Connect'Unrestricted_Access);
   Gnoga.Application.Multi_Connect.Message_Loop;
exception
   when E : others =>
      Gnoga.Log (E);
end State_Pension_Gui;
