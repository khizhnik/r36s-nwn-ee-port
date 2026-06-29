#include "nw_inc_nui"

void main()
{
    object oPC = GetFirstPC();
    if (oPC == OBJECT_INVALID)
    {
        WriteTimestampedLogEntry("R36S_NUI_NO_PC");
        return;
    }

    WriteTimestampedLogEntry("R36S_NUI_BUILDER_BOOTSTRAP");

    json jCol = JsonArray();

    json jRow = JsonArray();
    jRow = JsonArrayInsert(jRow, NuiLabel(JsonString("A"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
    jRow = JsonArrayInsert(jRow, NuiSpacer());
    jRow = JsonArrayInsert(jRow, NuiLabel(JsonString("B"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
    jCol = JsonArrayInsert(jCol, NuiRow(jRow));

    jRow = JsonArray();
    jRow = JsonArrayInsert(jRow, NuiButton(JsonString("OK")));
    jRow = JsonArrayInsert(jRow, NuiSpacer());
    jRow = JsonArrayInsert(jRow, NuiButton(JsonString("Cancel")));
    jCol = JsonArrayInsert(jCol, NuiRow(jRow));

    json jRoot = NuiCol(jCol);
    json jWindow = NuiWindow(jRoot, JsonString("R36S BUILDER TEST"), NuiRect(80.0f, 80.0f, 420.0f, 220.0f), JsonBool(FALSE), JsonNull(), JsonBool(TRUE), JsonBool(FALSE), JsonBool(TRUE));

    int nToken = NuiCreate(oPC, jWindow, "r36snui");
    WriteTimestampedLogEntry("R36S_NUI_TOKEN: " + IntToString(nToken));
}
