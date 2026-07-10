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

void BootstrapLogResManResource(string sLabel, string sResRef, int nResType)
{
    string sAlias;
    string sContent;

    WriteTimestampedLogEntry("R36S_RESMAN_TEST_BEGIN");
    sAlias = ResManGetAliasFor(sResRef, nResType);
    WriteTimestampedLogEntry(sLabel + "_ALIAS: " + sAlias);
    sContent = ResManGetFileContents(sResRef, nResType);
    WriteTimestampedLogEntry(sLabel + "_CONTENT_LEN: " + IntToString(GetStringLength(sContent)));
    WriteTimestampedLogEntry(sLabel + "_FOUND: " + IntToString((sContent == "") ? 0 : 1));
}

int R36S_GetSelectedSaveIndex(object oPC)
{
    int nIndex = GetLocalInt(oPC, "R36S_SELECTED_SAVE_INDEX");
    if (nIndex < 0)
    {
        string sLegacyFolder = GetLocalString(oPC, "R36S_SELECTED_SAVE_FOLDER");
        if (sLegacyFolder != "")
        {
            return 0;
        }
    }
    return nIndex;
}

string R36S_GetSaveFolderByIndex(object oPC, int nIndex)
{
    if (nIndex == 0)
    {
        string sFolder = GetLocalString(oPC, "R36S_SAVEINDEX_0_FOLDER");
        if (sFolder == "")
        {
            sFolder = GetLocalString(oPC, "R36S_SAVEINDEX_FOLDER");
        }
        return sFolder;
    }
    return "";
}

string R36S_GetSelectedSaveFolder(object oPC)
{
    int nIndex = R36S_GetSelectedSaveIndex(oPC);
    string sFolder = GetLocalString(oPC, "R36S_SELECTED_SAVE_FOLDER");
    if (sFolder != "")
    {
        return sFolder;
    }
    if (nIndex >= 0)
    {
        return R36S_GetSaveFolderByIndex(oPC, nIndex);
    }
    return "";
}

void R36S_SetSelectedSave(object oPC, int nIndex, string sFolder)
{
    SetLocalInt(oPC, "R36S_SELECTED_SAVE_INDEX", nIndex);
    SetLocalString(oPC, "R36S_SELECTED_SAVE_FOLDER", sFolder);
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

json BuildSaveListState(object oPC, string sState, string sFolder, string sSaveName, string sArea, string sMTime)
{
    json jPanel = JsonArray();
    jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("Save List"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));

    if (sState == "loaded")
    {
        int nSelectedIndex = R36S_GetSelectedSaveIndex(oPC);
        string sSelectedFolder = R36S_GetSelectedSaveFolder(oPC);
        string sEntryFolder = R36S_GetSaveFolderByIndex(oPC, 0);
        string sEntrySaveName = GetLocalString(oPC, "R36S_SAVEINDEX_0_SAVE_NAME");
        string sEntryArea = GetLocalString(oPC, "R36S_SAVEINDEX_0_AREA");
        string sEntryMTime = GetLocalString(oPC, "R36S_SAVEINDEX_0_MTIME");

        if (sEntryFolder == "")
        {
            sEntryFolder = sFolder;
        }
        if (sEntrySaveName == "")
        {
            sEntrySaveName = sSaveName;
        }
        if (sEntryArea == "")
        {
            sEntryArea = sArea;
        }
        if (sEntryMTime == "")
        {
            sEntryMTime = sMTime;
        }

        string sEntryPrefix = "  ";
        if (nSelectedIndex == 0 && sEntryFolder == sSelectedFolder)
        {
            sEntryPrefix = "> ";
        }

        json jEntry = JsonArray();
        jEntry = JsonArrayInsert(jEntry, NuiId(NuiButton(JsonString(sEntryPrefix + sEntrySaveName + "\n" + sEntryArea + "\n" + sEntryMTime)), "btn_save_0"));

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
        json jPreview = NuiImage(JsonString("r36s_preview"), JsonInt(NUI_ASPECT_FIT), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_MIDDLE));
        jPreview = NuiWidth(jPreview, 180.0f);
        jPreview = NuiHeight(jPreview, 120.0f);
        jPanel = JsonArrayInsert(jPanel, NuiRow(JsonArrayInsert(JsonArray(), jPreview)));
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

json BuildCharacterPanelState(object oPC, string sState, string sFolder, string sSaveName, string sArea, string sMTime)
{
    string sCharacterName = GetLocalString(oPC, "R36S_SAVEINDEX_0_CHARACTER_NAME");
    string sPortraitResRef = GetLocalString(oPC, "R36S_SAVEINDEX_0_PORTRAIT_RESREF");
    string sPortraitImageResRef = sPortraitResRef + "l";
    string sClassName = GetLocalString(oPC, "R36S_SAVEINDEX_0_CLASS_NAME");
    string sLevel = GetLocalString(oPC, "R36S_SAVEINDEX_0_LEVEL");
    string sModuleName = GetLocalString(oPC, "R36S_SAVEINDEX_0_MODULE_NAME");

    if (sCharacterName == "")
    {
        sCharacterName = GetLocalString(oPC, "R36S_SAVEINDEX_CHARACTER_NAME");
    }
    if (sPortraitResRef == "")
    {
        sPortraitResRef = GetLocalString(oPC, "R36S_SAVEINDEX_PORTRAIT_RESREF");
        sPortraitImageResRef = sPortraitResRef + "l";
    }
    if (sClassName == "")
    {
        sClassName = GetLocalString(oPC, "R36S_SAVEINDEX_CLASS_NAME");
    }
    if (sLevel == "")
    {
        sLevel = GetLocalString(oPC, "R36S_SAVEINDEX_LEVEL");
    }
    if (sModuleName == "")
    {
        sModuleName = GetLocalString(oPC, "R36S_SAVEINDEX_MODULE_NAME");
    }

    json jPanel = JsonArray();
    jPanel = JsonArrayInsert(jPanel, NuiLabel(JsonString("Character information"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));

    if (sState == "loaded")
    {
        json jPortrait = NuiImage(JsonString(sPortraitImageResRef), JsonInt(NUI_ASPECT_FIT), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_MIDDLE));
        jPortrait = NuiWidth(jPortrait, 60.0f);
        jPortrait = NuiHeight(jPortrait, 90.0f);

        json jInfoCol = JsonArray();
        jInfoCol = JsonArrayInsert(jInfoCol, NuiLabel(JsonString("Folder: " + sFolder), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        jInfoCol = JsonArrayInsert(jInfoCol, NuiLabel(JsonString("Save: " + sSaveName), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        jInfoCol = JsonArrayInsert(jInfoCol, NuiLabel(JsonString("Character: " + sCharacterName), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        jInfoCol = JsonArrayInsert(jInfoCol, NuiLabel(JsonString("Class: " + sClassName + " (" + sLevel + ")"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        jInfoCol = JsonArrayInsert(jInfoCol, NuiLabel(JsonString("Module: " + sModuleName), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        jInfoCol = JsonArrayInsert(jInfoCol, NuiLabel(JsonString("Area: " + sArea), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        jInfoCol = JsonArrayInsert(jInfoCol, NuiLabel(JsonString("Time: " + sMTime), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        jInfoCol = JsonArrayInsert(jInfoCol, NuiLabel(JsonString("Portrait: " + sPortraitResRef + " -> " + sPortraitImageResRef), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP)));
        json jInfoColFrame = NuiCol(jInfoCol);
        jInfoColFrame = NuiWidth(jInfoColFrame, 170.0f);

        json jInfoRow = JsonArray();
        jInfoRow = JsonArrayInsert(jInfoRow, jPortrait);
        jInfoRow = JsonArrayInsert(jInfoRow, NuiWidth(NuiSpacer(), 8.0f));
        jInfoRow = JsonArrayInsert(jInfoRow, jInfoColFrame);
        jPanel = JsonArrayInsert(jPanel, NuiRow(jInfoRow));
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

    json jLeftPanel = BuildSaveListState(oPC, sState, sFolder, sSaveName, sArea, sMTime);
    jLeftPanel = NuiWidth(jLeftPanel, 340.0f);
    jLeftPanel = NuiHeight(jLeftPanel, 330.0f);

    json jRightPanel = JsonArray();
    jRightPanel = JsonArrayInsert(jRightPanel, BuildPreviewPanelState(sState));
    jRightPanel = JsonArrayInsert(jRightPanel, NuiWidth(NuiSpacer(), 20.0f));
    jRightPanel = JsonArrayInsert(jRightPanel, BuildCharacterPanelState(oPC, sState, sFolder, sSaveName, sArea, sMTime));
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
        SetLocalString(oPC, "R36S_SAVEINDEX_STATE", "nodata");
        SetLocalString(oPC, "R36S_SAVEINDEX_SAVE_NAME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_AREA", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_MTIME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_MODULE_NAME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_FOLDER", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_CHARACTER_NAME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_PORTRAIT_RESREF", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_CLASS_NAME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_LEVEL", "");
        ShowLoadGameScreenState(oPC, "nodata", "", "", "", "");
        return;
    }

    if (FindSubString(sContent, "EMPTY|") == 0)
    {
        SetLocalString(oPC, "R36S_SAVEINDEX_STATE", "empty");
        SetLocalString(oPC, "R36S_SAVEINDEX_SAVE_NAME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_AREA", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_MTIME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_MODULE_NAME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_FOLDER", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_CHARACTER_NAME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_PORTRAIT_RESREF", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_CLASS_NAME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_LEVEL", "");
        ShowLoadGameScreenState(oPC, "empty", "", "", "", "");
        return;
    }

    int nSaveStart = FindSubString(sContent, "SAVE|");
    if (nSaveStart < 0)
    {
        WriteTimestampedLogEntry("R36S_SAVEINDEX_EMPTY");
        SetLocalString(oPC, "R36S_SAVEINDEX_STATE", "nodata");
        SetLocalString(oPC, "R36S_SAVEINDEX_SAVE_NAME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_AREA", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_MTIME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_MODULE_NAME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_FOLDER", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_CHARACTER_NAME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_PORTRAIT_RESREF", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_CLASS_NAME", "");
        SetLocalString(oPC, "R36S_SAVEINDEX_LEVEL", "");
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
        sRest = GetSubString(sRest, nSep3 + 1, GetStringLength(sRest) - (nSep3 + 1));
    }
    else
    {
        sArea = sRest;
        sRest = "";
    }

    int nSep4 = FindSubString(sRest, "|");
    string sModuleName;
    if (nSep4 >= 0)
    {
        sMTime = GetSubString(sRest, 0, nSep4);
        sRest = GetSubString(sRest, nSep4 + 1, GetStringLength(sRest) - (nSep4 + 1));
    }
    else
    {
        sMTime = sRest;
        sRest = "";
    }

    int nSep5 = FindSubString(sRest, "|");
    string sCharacterName;
    if (nSep5 >= 0)
    {
        sModuleName = GetSubString(sRest, 0, nSep5);
        sRest = GetSubString(sRest, nSep5 + 1, GetStringLength(sRest) - (nSep5 + 1));
    }
    else
    {
        sModuleName = sRest;
        sRest = "";
    }

    int nSep6 = FindSubString(sRest, "|");
    string sPortraitResRef;
    if (nSep6 >= 0)
    {
        sCharacterName = GetSubString(sRest, 0, nSep6);
        sRest = GetSubString(sRest, nSep6 + 1, GetStringLength(sRest) - (nSep6 + 1));
    }
    else
    {
        sCharacterName = sRest;
        sRest = "";
    }

    int nSep7 = FindSubString(sRest, "|");
    string sClassName;
    if (nSep7 >= 0)
    {
        sPortraitResRef = GetSubString(sRest, 0, nSep7);
        sRest = GetSubString(sRest, nSep7 + 1, GetStringLength(sRest) - (nSep7 + 1));
    }
    else
    {
        sPortraitResRef = sRest;
        sRest = "";
    }

    int nSep8 = FindSubString(sRest, "|");
    string sLevel;
    if (nSep8 >= 0)
    {
        sClassName = GetSubString(sRest, 0, nSep8);
        sLevel = GetSubString(sRest, nSep8 + 1, GetStringLength(sRest) - (nSep8 + 1));
    }
    else
    {
        sClassName = sRest;
        sLevel = "";
    }

    WriteTimestampedLogEntry("R36S_SAVEINDEX_CONTENT_BEGIN");
    WriteTimestampedLogEntry(sContent);
    WriteTimestampedLogEntry("R36S_SAVEINDEX_CONTENT_END");
    WriteTimestampedLogEntry("R36S_SAVEINDEX_FIRST_SAVE: " + sSaveName);
    BootstrapLogResManResource("R36S_RESMAN_PREVIEW", "r36s_preview", RESTYPE_TGA);
    BootstrapLogResManResource("R36S_RESMAN_PORTRAIT", "r36s_portrait", RESTYPE_TGA);
    BootstrapLogResManResource("R36S_RESMAN_CHARACTER", "r36s_character", RESTYPE_BIC);
    SetLocalString(oPC, "R36S_SAVEINDEX_STATE", "loaded");
    // TODO: remove legacy flat R36S_SAVEINDEX_* locals after multi-save indexed model is complete.
    SetLocalString(oPC, "R36S_SAVEINDEX_0_FOLDER", sFolder);
    SetLocalString(oPC, "R36S_SAVEINDEX_0_SAVE_NAME", sSaveName);
    SetLocalString(oPC, "R36S_SAVEINDEX_0_AREA", sArea);
    SetLocalString(oPC, "R36S_SAVEINDEX_0_MTIME", sMTime);
    SetLocalString(oPC, "R36S_SAVEINDEX_0_MODULE_NAME", sModuleName);
    SetLocalString(oPC, "R36S_SAVEINDEX_0_CHARACTER_NAME", sCharacterName);
    SetLocalString(oPC, "R36S_SAVEINDEX_0_PORTRAIT_RESREF", sPortraitResRef);
    SetLocalString(oPC, "R36S_SAVEINDEX_0_CLASS_NAME", sClassName);
    SetLocalString(oPC, "R36S_SAVEINDEX_0_LEVEL", sLevel);
    // TODO: remove legacy flat R36S_SAVEINDEX_* locals after multi-save indexed model is complete.
    SetLocalString(oPC, "R36S_SAVEINDEX_FOLDER", sFolder);
    SetLocalString(oPC, "R36S_SAVEINDEX_SAVE_NAME", sSaveName);
    SetLocalString(oPC, "R36S_SAVEINDEX_AREA", sArea);
    SetLocalString(oPC, "R36S_SAVEINDEX_MTIME", sMTime);
    SetLocalString(oPC, "R36S_SAVEINDEX_MODULE_NAME", sModuleName);
    SetLocalString(oPC, "R36S_SAVEINDEX_CHARACTER_NAME", sCharacterName);
    SetLocalString(oPC, "R36S_SAVEINDEX_PORTRAIT_RESREF", sPortraitResRef);
    SetLocalString(oPC, "R36S_SAVEINDEX_CLASS_NAME", sClassName);
    SetLocalString(oPC, "R36S_SAVEINDEX_LEVEL", sLevel);
    if (R36S_GetSelectedSaveFolder(oPC) == "" || R36S_GetSelectedSaveIndex(oPC) < 0)
    {
        R36S_SetSelectedSave(oPC, 0, sFolder);
    }
    ShowLoadGameScreenState(oPC, "loaded", sFolder, sSaveName, sArea, sMTime);
}
