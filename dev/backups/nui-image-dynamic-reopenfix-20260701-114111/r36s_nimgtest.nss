#include "nw_inc_nui"

void main()
{
    object oPC = GetFirstPC();
    if (oPC == OBJECT_INVALID)
    {
        return;
    }

    string sEventType = NuiGetEventType();
    string sEventElement = NuiGetEventElement();

    if (sEventType == "click" && sEventElement == "btn_reload")
    {
        int nToken = GetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_TOKEN");
        if (nToken > 0)
        {
            NuiDestroy(oPC, nToken);
            SetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_TOKEN", 0);
        }
        DelayCommand(0.25f, ExecuteScript("r36s_nimgtest", oPC));
        return;
    }

    if (sEventType != "")
    {
        return;
    }

    if (GetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_REFRESH_PENDING") == 1)
    {
        int nToken = GetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_TOKEN");
        if (nToken > 0)
        {
            NuiDestroy(oPC, nToken);
            SetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_TOKEN", 0);
        }
        SetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_REFRESH_PENDING", 0);
    }

    WriteTimestampedLogEntry("R36S_NUI_IMAGE_TEST_OPEN");

    json jTitle = NuiLabel(JsonString("NuiImage Save Screen Test"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP));

    json jControlImage = NuiImage(JsonString("po_exornova_h"),
        JsonInt(NUI_ASPECT_FIT),
        JsonInt(NUI_HALIGN_CENTER),
        JsonInt(NUI_VALIGN_MIDDLE));
    jControlImage = NuiWidth(jControlImage, 180.0f);
    jControlImage = NuiHeight(jControlImage, 180.0f);
    json jControlCol = JsonArray();
    jControlCol = JsonArrayInsert(jControlCol, jControlImage);
    jControlCol = JsonArrayInsert(jControlCol, NuiHeight(NuiSpacer(), 6.0f));
    jControlCol = JsonArrayInsert(jControlCol, NuiLabel(JsonString("control: po_exornova_h"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));

    json jCandidateImage = NuiImage(JsonString("r36s_screen"),
        JsonInt(NUI_ASPECT_FIT),
        JsonInt(NUI_HALIGN_CENTER),
        JsonInt(NUI_VALIGN_MIDDLE));
    jCandidateImage = NuiWidth(jCandidateImage, 180.0f);
    jCandidateImage = NuiHeight(jCandidateImage, 180.0f);
    json jCandidateCol = JsonArray();
    jCandidateCol = JsonArrayInsert(jCandidateCol, jCandidateImage);
    jCandidateCol = JsonArrayInsert(jCandidateCol, NuiHeight(NuiSpacer(), 6.0f));
    jCandidateCol = JsonArrayInsert(jCandidateCol, NuiLabel(JsonString("candidate: r36s_screen"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));

    json jRow = JsonArray();
    jRow = JsonArrayInsert(jRow, NuiSpacer());
    jRow = JsonArrayInsert(jRow, NuiCol(jControlCol));
    jRow = JsonArrayInsert(jRow, NuiWidth(NuiSpacer(), 20.0f));
    jRow = JsonArrayInsert(jRow, NuiCol(jCandidateCol));
    jRow = JsonArrayInsert(jRow, NuiSpacer());

    json jNote = NuiLabel(JsonString("If the right image appears, NuiImage can render screen.tga as r36s_screen."), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_MIDDLE));

    json jCol = JsonArray();
    jCol = JsonArrayInsert(jCol, NuiHeight(jTitle, 38.0f));
    jCol = JsonArrayInsert(jCol, NuiHeight(NuiSpacer(), 8.0f));
    jCol = JsonArrayInsert(jCol, NuiRow(jRow));
    jCol = JsonArrayInsert(jCol, NuiHeight(NuiSpacer(), 12.0f));
    jCol = JsonArrayInsert(jCol, jNote);
    jCol = JsonArrayInsert(jCol, NuiHeight(NuiSpacer(), 10.0f));
    jCol = JsonArrayInsert(jCol, NuiRow(JsonArrayInsert(JsonArrayInsert(JsonArray(), NuiSpacer()), NuiId(NuiButton(JsonString("Reload")), "btn_reload"))));

    json jWindow = NuiWindow(
        NuiCol(jCol),
        JsonString("NuiImage Save Screen Test"),
        NuiRect(0.0f, 0.0f, 640.0f, 480.0f),
        JsonBool(FALSE),
        JsonNull(),
        JsonBool(TRUE),
        JsonBool(FALSE),
        JsonBool(TRUE));

    NuiCreate(oPC, jWindow, "r36snui", "r36s_nimgtest");
    SetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_TOKEN", GetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_TOKEN") + 1);

    if (GetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_AUTOREFRESHED") == 0)
    {
        SetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_AUTOREFRESHED", 1);
        SetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_REFRESH_PENDING", 1);
        DelayCommand(8.0f, ExecuteScript("r36s_nimgtest", oPC));
    }
}
