#include "nw_inc_nui"

void BootstrapDestroyCurrentWindow(object oPC)
{
    int nToken = GetLocalInt(oPC, "R36S_BOOTSTRAP_NUI_TOKEN");
    if (nToken > 0)
    {
        NuiDestroy(oPC, nToken);
        SetLocalInt(oPC, "R36S_BOOTSTRAP_NUI_TOKEN", 0);
    }
}

json BuildLoadButtons()
{
    json jButtonsRow = JsonArray();

    jButtonsRow = JsonArrayInsert(jButtonsRow, NuiSpacer());
    jButtonsRow = JsonArrayInsert(jButtonsRow, NuiId(NuiButton(JsonString("Delete")), "btn_load_screen_delete"));
    jButtonsRow = JsonArrayInsert(jButtonsRow, NuiWidth(NuiSpacer(), 20.0f));
    jButtonsRow = JsonArrayInsert(jButtonsRow, NuiId(NuiButton(JsonString("Load")), "btn_load_screen_load"));
    jButtonsRow = JsonArrayInsert(jButtonsRow, NuiWidth(NuiSpacer(), 20.0f));
    jButtonsRow = JsonArrayInsert(jButtonsRow, NuiId(NuiButton(JsonString("Cancel")), "btn_load_screen_cancel"));
    jButtonsRow = JsonArrayInsert(jButtonsRow, NuiSpacer());

    json jRow = NuiRow(jButtonsRow);
    jRow = NuiWidth(jRow, 600.0f);
    return jRow;
}

json BuildSaveListState(string sState, string sFolder, string sSaveName, string sArea, string sMTime)
{
    json jPanel = JsonArray();
    jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("Save List"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));

    if (sState == "loaded")
    {
        json jEntry = JsonArray();
        jEntry = JsonArrayInsert(jEntry, NuiLabel(JsonString(sSaveName), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        jEntry = JsonArrayInsert(jEntry, NuiLabel(JsonString(sArea), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        jEntry = JsonArrayInsert(jEntry, NuiLabel(JsonString(sMTime), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));

        json jEntryFrame = NuiGroup(NuiCol(jEntry), TRUE, NUI_SCROLLBARS_NONE);
        jEntryFrame = NuiWidth(jEntryFrame, 320.0f);
        jEntryFrame = NuiHeight(jEntryFrame, 78.0f);
        jPanel = JsonArrayInsert(jPanel, jEntryFrame);
    }
    else if (sState == "empty")
    {
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("No saved games found"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
    }
    else if (sState == "nodata")
    {
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("No save data received"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
    }
    else
    {
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("Loading saves..."), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
    }

    json jFrame = NuiGroup(NuiCol(jPanel), TRUE, NUI_SCROLLBARS_NONE);
    jFrame = NuiWidth(jFrame, 350.0f);
    jFrame = NuiHeight(jFrame, 330.0f);
    return jFrame;
}

json BuildPreviewPanelState(string sState)
{
    json jPanel = JsonArray();
    jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("Preview"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));

    if (sState == "loaded")
    {
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("Preview unavailable"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_MIDDLE)));
    }
    else if (sState == "empty")
    {
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("No saved games found"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_MIDDLE)));
    }
    else if (sState == "nodata")
    {
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("No save data received"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_MIDDLE)));
    }
    else
    {
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("Waiting for save data"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_MIDDLE)));
    }

    json jFrame = NuiGroup(NuiCol(jPanel), TRUE, NUI_SCROLLBARS_NONE);
    jFrame = NuiWidth(jFrame, 240.0f);
    jFrame = NuiHeight(jFrame, 145.0f);
    return jFrame;
}

json BuildCharacterPanelState(string sState, string sFolder, string sSaveName, string sArea, string sMTime)
{
    json jPanel = JsonArray();
    jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("Character information"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));

    if (sState == "loaded")
    {
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("Folder: " + sFolder), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("Save: " + sSaveName), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("Area: " + sArea), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("Time: " + sMTime), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
    }
    else if (sState == "empty")
    {
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("No saved games found"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
    }
    else if (sState == "nodata")
    {
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("No save data received"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
    }
    else
    {
        jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("No save selected"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
    }

    json jFrame = NuiGroup(NuiCol(jPanel), TRUE, NUI_SCROLLBARS_NONE);
    jFrame = NuiWidth(jFrame, 240.0f);
    jFrame = NuiHeight(jFrame, 175.0f);
    return jFrame;
}

void ShowLoadGameScreenState(object oPC, string sState, string sFolder, string sSaveName, string sArea, string sMTime)
{
    BootstrapDestroyCurrentWindow(oPC);

    json jRootCol = JsonArray();

    json jTitleRow = JsonArray();
    jTitleRow = JsonArrayInsert(jTitleRow, NuiWidth(NuiSpacer(), 220.0f));
    jTitleRow = JsonArrayInsert(jTitleRow, NuiLabel(JsonString("Load Game"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));
    jTitleRow = JsonArrayInsert(jTitleRow, NuiWidth(NuiSpacer(), 220.0f));
    jRootCol = JsonArrayInsert(jRootCol, NuiRow(jTitleRow));

    json jBodyRow = JsonArray();

    json jLeftPanel = BuildSaveListState(sState, sFolder, sSaveName, sArea, sMTime);
    jLeftPanel = NuiWidth(jLeftPanel, 340.0f);
    jLeftPanel = NuiHeight(jLeftPanel, 330.0f);

    json jRightPanel = JsonArray();
    jRightPanel = JsonArrayInsert(jRightPanel, BuildPreviewPanelState(sState));
    jRightPanel = JsonArrayInsert(jRightPanel, NuiWidth(NuiSpacer(), 20.0f));
    jRightPanel = JsonArrayInsert(jRightPanel, BuildCharacterPanelState(sState, sFolder, sSaveName, sArea, sMTime));
    jRightPanel = NuiGroup(NuiCol(jRightPanel), FALSE, NUI_SCROLLBARS_NONE);
    jRightPanel = NuiWidth(jRightPanel, 240.0f);
    jRightPanel = NuiHeight(jRightPanel, 330.0f);

    jBodyRow = JsonArrayInsert(jBodyRow, jLeftPanel);
    jBodyRow = JsonArrayInsert(jBodyRow, NuiWidth(NuiSpacer(), 20.0f));
    jBodyRow = JsonArrayInsert(jBodyRow, jRightPanel);
    jRootCol = JsonArrayInsert(jRootCol, NuiRow(jBodyRow));

    jRootCol = JsonArrayInsert(jRootCol, NuiHeight(NuiSpacer(), 10.0f));
    jRootCol = JsonArrayInsert(jRootCol, BuildLoadButtons());

    json jWindow = NuiWindow(NuiCol(jRootCol), JsonString("R36S BOOTSTRAP"), NuiRect(0.0f, 0.0f, 640.0f, 480.0f), JsonBool(FALSE), JsonNull(), JsonBool(TRUE), JsonBool(FALSE), JsonBool(TRUE));
    int nToken = NuiCreate(oPC, jWindow, "r36snui", "r36s_onenter_nui");
    SetLocalInt(oPC, "R36S_BOOTSTRAP_NUI_TOKEN", nToken);
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_TOKEN: " + IntToString(nToken));
}

void main()
{
    object oPC = OBJECT_SELF;
    WriteTimestampedLogEntry("R36S_SAVEINDEX_READ_BEGIN");

    string sContent = ResManGetFileContents("r36s_saveindex", RESTYPE_TXT);
    if (sContent == "")
    {
        WriteTimestampedLogEntry("R36S_SAVEINDEX_EMPTY");
        ShowLoadGameScreenState(oPC, "nodata", "", "", "", "");
        return;
    }

    if (FindSubString(sContent, "EMPTY|") == 0)
    {
        ShowLoadGameScreenState(oPC, "empty", "", "", "", "");
        return;
    }

    int nSaveStart = FindSubString(sContent, "SAVE|");
    if (nSaveStart < 0)
    {
        WriteTimestampedLogEntry("R36S_SAVEINDEX_EMPTY");
        ShowLoadGameScreenState(oPC, "nodata", "", "", "", "");
        return;
    }

    int nLineEnd = FindSubString(sContent, "\n", nSaveStart);
    string sLine;
    if (nLineEnd >= 0)
    {
        sLine = GetSubString(sContent, nSaveStart, nLineEnd - nSaveStart);
    }
    else
    {
        sLine = GetSubString(sContent, nSaveStart, GetStringLength(sContent) - nSaveStart);
    }

    string sPayload = GetSubString(sLine, 5, GetStringLength(sLine) - 5);

    int nSep1 = FindSubString(sPayload, "|");
    string sFolder;
    string sRest;
    if (nSep1 >= 0)
    {
        sFolder = GetSubString(sPayload, 0, nSep1);
        sRest = GetSubString(sPayload, nSep1 + 1, GetStringLength(sPayload) - (nSep1 + 1));
    }
    else
    {
        sFolder = sPayload;
        sRest = "";
    }

    int nSep2 = FindSubString(sRest, "|");
    string sSaveName;
    if (nSep2 >= 0)
    {
        sSaveName = GetSubString(sRest, 0, nSep2);
        sRest = GetSubString(sRest, nSep2 + 1, GetStringLength(sRest) - (nSep2 + 1));
    }
    else
    {
        sSaveName = sRest;
        sRest = "";
    }

    int nSep3 = FindSubString(sRest, "|");
    string sArea;
    string sMTime;
    if (nSep3 >= 0)
    {
        sArea = GetSubString(sRest, 0, nSep3);
        sMTime = GetSubString(sRest, nSep3 + 1, GetStringLength(sRest) - (nSep3 + 1));
    }
    else
    {
        sArea = sRest;
        sMTime = "";
    }

    WriteTimestampedLogEntry("R36S_SAVEINDEX_CONTENT_BEGIN");
    WriteTimestampedLogEntry(sContent);
    WriteTimestampedLogEntry("R36S_SAVEINDEX_CONTENT_END");
    WriteTimestampedLogEntry("R36S_SAVEINDEX_FIRST_SAVE: " + sSaveName);
    ShowLoadGameScreenState(oPC, "loaded", sFolder, sSaveName, sArea, sMTime);
}
