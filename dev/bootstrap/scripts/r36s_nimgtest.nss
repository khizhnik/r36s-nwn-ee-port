#include "nw_inc_nui"

void main()
{
    WriteTimestampedLogEntry("R36S_NUI_IMAGE_TEST_OPEN");

    object oPC = GetFirstPC();
    if (oPC == OBJECT_INVALID)
    {
        return;
    }

    json jTitle = NuiLabel(JsonString("NuiImage Portrait ResRef Test"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP));

    json jRow1 = JsonArray();
    json jRow2 = JsonArray();
    json jRow3 = JsonArray();

    json jControlImage = NuiImage(JsonString("po_exornova_h"),
        JsonInt(NUI_ASPECT_FIT),
        JsonInt(NUI_HALIGN_CENTER),
        JsonInt(NUI_VALIGN_MIDDLE));
    jControlImage = NuiWidth(jControlImage, 120.0f);
    jControlImage = NuiHeight(jControlImage, 180.0f);
    json jControlCol = JsonArray();
    jControlCol = JsonArrayInsert(jControlCol, jControlImage);
    jControlCol = JsonArrayInsert(jControlCol, NuiHeight(NuiSpacer(), 6.0f));
    jControlCol = JsonArrayInsert(jControlCol, NuiLabel(JsonString("control: po_exornova_h"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));

    json jCandidateH = NuiImage(JsonString("po_hu_m_21_h"),
        JsonInt(NUI_ASPECT_FIT),
        JsonInt(NUI_HALIGN_CENTER),
        JsonInt(NUI_VALIGN_MIDDLE));
    jCandidateH = NuiWidth(jCandidateH, 120.0f);
    jCandidateH = NuiHeight(jCandidateH, 180.0f);
    json jCandidateHCol = JsonArray();
    jCandidateHCol = JsonArrayInsert(jCandidateHCol, jCandidateH);
    jCandidateHCol = JsonArrayInsert(jCandidateHCol, NuiHeight(NuiSpacer(), 6.0f));
    jCandidateHCol = JsonArrayInsert(jCandidateHCol, NuiLabel(JsonString("candidate: po_hu_m_21_h"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));

    json jCandidateL = NuiImage(JsonString("po_hu_m_21_l"),
        JsonInt(NUI_ASPECT_FIT),
        JsonInt(NUI_HALIGN_CENTER),
        JsonInt(NUI_VALIGN_MIDDLE));
    jCandidateL = NuiWidth(jCandidateL, 120.0f);
    jCandidateL = NuiHeight(jCandidateL, 180.0f);
    json jCandidateLCol = JsonArray();
    jCandidateLCol = JsonArrayInsert(jCandidateLCol, jCandidateL);
    jCandidateLCol = JsonArrayInsert(jCandidateLCol, NuiHeight(NuiSpacer(), 6.0f));
    jCandidateLCol = JsonArrayInsert(jCandidateLCol, NuiLabel(JsonString("candidate: po_hu_m_21_l"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));

    json jCandidateM = NuiImage(JsonString("po_hu_m_21_m"),
        JsonInt(NUI_ASPECT_FIT),
        JsonInt(NUI_HALIGN_CENTER),
        JsonInt(NUI_VALIGN_MIDDLE));
    jCandidateM = NuiWidth(jCandidateM, 120.0f);
    jCandidateM = NuiHeight(jCandidateM, 180.0f);
    json jCandidateMCol = JsonArray();
    jCandidateMCol = JsonArrayInsert(jCandidateMCol, jCandidateM);
    jCandidateMCol = JsonArrayInsert(jCandidateMCol, NuiHeight(NuiSpacer(), 6.0f));
    jCandidateMCol = JsonArrayInsert(jCandidateMCol, NuiLabel(JsonString("candidate: po_hu_m_21_m"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));

    json jCandidateS = NuiImage(JsonString("po_hu_m_21_s"),
        JsonInt(NUI_ASPECT_FIT),
        JsonInt(NUI_HALIGN_CENTER),
        JsonInt(NUI_VALIGN_MIDDLE));
    jCandidateS = NuiWidth(jCandidateS, 120.0f);
    jCandidateS = NuiHeight(jCandidateS, 180.0f);
    json jCandidateSCol = JsonArray();
    jCandidateSCol = JsonArrayInsert(jCandidateSCol, jCandidateS);
    jCandidateSCol = JsonArrayInsert(jCandidateSCol, NuiHeight(NuiSpacer(), 6.0f));
    jCandidateSCol = JsonArrayInsert(jCandidateSCol, NuiLabel(JsonString("candidate: po_hu_m_21_s"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));

    jRow1 = JsonArrayInsert(jRow1, NuiSpacer());
    jRow1 = JsonArrayInsert(jRow1, NuiCol(jControlCol));
    jRow1 = JsonArrayInsert(jRow1, NuiWidth(NuiSpacer(), 20.0f));
    jRow1 = JsonArrayInsert(jRow1, NuiCol(jCandidateHCol));
    jRow1 = JsonArrayInsert(jRow1, NuiSpacer());

    jRow2 = JsonArrayInsert(jRow2, NuiSpacer());
    jRow2 = JsonArrayInsert(jRow2, NuiCol(jCandidateLCol));
    jRow2 = JsonArrayInsert(jRow2, NuiWidth(NuiSpacer(), 20.0f));
    jRow2 = JsonArrayInsert(jRow2, NuiCol(jCandidateMCol));
    jRow2 = JsonArrayInsert(jRow2, NuiSpacer());

    jRow3 = JsonArrayInsert(jRow3, NuiSpacer());
    jRow3 = JsonArrayInsert(jRow3, NuiCol(jCandidateSCol));
    jRow3 = JsonArrayInsert(jRow3, NuiWidth(NuiSpacer(), 20.0f));
    jRow3 = JsonArrayInsert(jRow3, NuiLabel(JsonString("If only the left image renders, NuiImage works but the candidate resrefs are not currently resolvable."), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_MIDDLE)));
    jRow3 = JsonArrayInsert(jRow3, NuiSpacer());

    json jCol = JsonArray();
    jCol = JsonArrayInsert(jCol, NuiHeight(jTitle, 38.0f));
    jCol = JsonArrayInsert(jCol, NuiHeight(NuiSpacer(), 8.0f));
    jCol = JsonArrayInsert(jCol, NuiRow(jRow1));
    jCol = JsonArrayInsert(jCol, NuiHeight(NuiSpacer(), 10.0f));
    jCol = JsonArrayInsert(jCol, NuiRow(jRow2));
    jCol = JsonArrayInsert(jCol, NuiHeight(NuiSpacer(), 10.0f));
    jCol = JsonArrayInsert(jCol, NuiRow(jRow3));

    json jWindow = NuiWindow(
        NuiCol(jCol),
        JsonString("NuiImage Test"),
        NuiRect(0.0f, 0.0f, 640.0f, 480.0f),
        JsonBool(FALSE),
        JsonNull(),
        JsonBool(TRUE),
        JsonBool(FALSE),
        JsonBool(TRUE));

    NuiCreate(oPC, jWindow, "r36snui", "r36s_nimgtest");
}
