#include "nw_inc_nui"

void ShowBootstrapMenu(object oPC)
{
    json jCol = JsonArray();

    json jRow1 = JsonArray();
    jRow1 = JsonArrayInsert(jRow1, NuiId(NuiButton(JsonString("New")), "btn_new"));
    jRow1 = JsonArrayInsert(jRow1, NuiSpacer());
    jRow1 = JsonArrayInsert(jRow1, NuiId(NuiButton(JsonString("Load")), "btn_load"));
    jCol = JsonArrayInsert(jCol, NuiRow(jRow1));

    jCol = JsonArrayInsert(jCol, NuiSpacer());

    json jRow2 = JsonArray();
    jRow2 = JsonArrayInsert(jRow2, NuiId(NuiButton(JsonString("Multiplayer")), "btn_multiplayer"));
    jRow2 = JsonArrayInsert(jRow2, NuiSpacer());
    jRow2 = JsonArrayInsert(jRow2, NuiId(NuiButton(JsonString("Options")), "btn_options"));
    jCol = JsonArrayInsert(jCol, NuiRow(jRow2));

    jCol = JsonArrayInsert(jCol, NuiSpacer());

    json jRow3 = JsonArray();
    jRow3 = JsonArrayInsert(jRow3, NuiId(NuiButton(JsonString("Movies")), "btn_movies"));
    jRow3 = JsonArrayInsert(jRow3, NuiSpacer());
    jRow3 = JsonArrayInsert(jRow3, NuiId(NuiButton(JsonString("News")), "btn_news"));
    jCol = JsonArrayInsert(jCol, NuiRow(jRow3));

    jCol = JsonArrayInsert(jCol, NuiSpacer());

    json jExitRow = JsonArray();
    jExitRow = JsonArrayInsert(jExitRow, NuiSpacer());
    jExitRow = JsonArrayInsert(jExitRow, NuiId(NuiButton(JsonString("Exit")), "btn_exit"));
    jExitRow = JsonArrayInsert(jExitRow, NuiSpacer());
    jCol = JsonArrayInsert(jCol, NuiRow(jExitRow));

    json jRoot = NuiCol(jCol);
    json jWindow = NuiWindow(jRoot, JsonString("R36S BOOTSTRAP"), NuiRect(0.0f, 0.0f, 640.0f, 480.0f), JsonBool(FALSE), JsonNull(), JsonBool(TRUE), JsonBool(FALSE), JsonBool(TRUE));

    int nToken = NuiCreate(oPC, jWindow, "r36snui", "r36s_onenter_nui");
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_TOKEN: " + IntToString(nToken));
}

void ShowExitConfirm(object oPC)
{
    json jCol = JsonArray();

    jCol = JsonArrayInsert(jCol, NuiLabel(JsonString("Quit Neverwinter Nights?"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));
    jCol = JsonArrayInsert(jCol, NuiSpacer());

    json jRow = JsonArray();
    jRow = JsonArrayInsert(jRow, NuiSpacer());
    jRow = JsonArrayInsert(jRow, NuiId(NuiButton(JsonString("Yes")), "btn_exit_yes"));
    jRow = JsonArrayInsert(jRow, NuiSpacer());
    jRow = JsonArrayInsert(jRow, NuiId(NuiButton(JsonString("No")), "btn_exit_no"));
    jRow = JsonArrayInsert(jRow, NuiSpacer());
    jCol = JsonArrayInsert(jCol, NuiRow(jRow));

    json jRoot = NuiCol(jCol);
    json jWindow = NuiWindow(jRoot, JsonString("R36S BOOTSTRAP"), NuiRect(0.0f, 0.0f, 640.0f, 480.0f), JsonBool(FALSE), JsonNull(), JsonBool(TRUE), JsonBool(FALSE), JsonBool(TRUE));

    int nToken = NuiCreate(oPC, jWindow, "r36snui", "r36s_onenter_nui");
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_TOKEN: " + IntToString(nToken));
}

void main()
{
    string sEventType = NuiGetEventType();
    if (sEventType != "")
    {
        object oPC = NuiGetEventPlayer();
        string sEventElement = NuiGetEventElement();
        string sEventPlayerValid = IntToString(oPC != OBJECT_INVALID);
        int nEventWindow = NuiGetEventWindow();

        WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_EVENT_TYPE: " + sEventType);
        WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_EVENT_ELEMENT: " + sEventElement);
        WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_EVENT_PLAYER_VALID: " + sEventPlayerValid);

        if (sEventType == "click" && sEventElement == "btn_exit")
        {
            WriteTimestampedLogEntry("R36S_BOOTSTRAP_EXIT_BUTTON");
            if (oPC != OBJECT_INVALID && nEventWindow != 0)
            {
                NuiDestroy(oPC, nEventWindow);
                ShowExitConfirm(oPC);
            }
            return;
        }

        if (sEventType == "click" && sEventElement == "btn_exit_yes")
        {
            WriteTimestampedLogEntry("R36S_BOOTSTRAP_EXIT_CONFIRMED");
            WriteTimestampedLogEntry("R36S_BOOTSTRAP_EXIT_NO_NUIDESTROY_EXPERIMENT");
            return;
        }

        if (sEventType == "click" && sEventElement == "btn_exit_no")
        {
            WriteTimestampedLogEntry("R36S_BOOTSTRAP_EXIT_CANCELLED");
            if (oPC != OBJECT_INVALID && nEventWindow != 0)
            {
                NuiDestroy(oPC, nEventWindow);
                ShowBootstrapMenu(oPC);
            }
        }

        return;
    }

    object oPC = GetEnteringObject();
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_ONCLIENTENTER");
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_ENTERING_VALID: " + IntToString(oPC != OBJECT_INVALID));
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_ENTERING_IS_PC: " + IntToString(GetIsPC(oPC)));

    if (oPC == OBJECT_INVALID || !GetIsPC(oPC))
    {
        return;
    }
    ShowBootstrapMenu(oPC);
}
