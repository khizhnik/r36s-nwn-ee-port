#include "nw_inc_nui"

void main()
{
    object oPC = GetEnteringObject();
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_ONCLIENTENTER");
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_ENTERING_VALID: " + IntToString(oPC != OBJECT_INVALID));
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_ENTERING_IS_PC: " + IntToString(GetIsPC(oPC)));

    if (oPC == OBJECT_INVALID || !GetIsPC(oPC))
    {
        return;
    }

    json jCol = JsonArray();

    jCol = JsonArrayInsert(jCol, NuiLabel(JsonString("Bootstrap module OK"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));

    json jRow = JsonArray();
    jRow = JsonArrayInsert(jRow, NuiButton(JsonString("OK")));
    jRow = JsonArrayInsert(jRow, NuiSpacer());
    jRow = JsonArrayInsert(jRow, NuiButton(JsonString("Cancel")));
    jCol = JsonArrayInsert(jCol, NuiRow(jRow));

    json jRoot = NuiCol(jCol);
    json jWindow = NuiWindow(jRoot, JsonString("R36S BOOTSTRAP"), NuiRect(80.0f, 80.0f, 420.0f, 220.0f), JsonBool(FALSE), JsonNull(), JsonBool(TRUE), JsonBool(FALSE), JsonBool(TRUE));

    int nToken = NuiCreate(oPC, jWindow, "r36snui", "r36s_onenter_nui");
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_TOKEN: " + IntToString(nToken));
}
