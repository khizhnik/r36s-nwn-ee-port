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

// TODO: move save-selection helpers into a shared include once the NUI scripts stabilize.
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

string BootstrapLoadState(object oPC)
{
    return GetLocalString(oPC, "R36S_SAVEINDEX_STATE");
}

json BuildSaveList(object oPC)
{
    string sState = BootstrapLoadState(oPC);
    string sSaveName = GetLocalString(oPC, "R36S_SAVEINDEX_SAVE_NAME");
    string sArea = GetLocalString(oPC, "R36S_SAVEINDEX_AREA");
    string sMTime = GetLocalString(oPC, "R36S_SAVEINDEX_MTIME");

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

json BuildPreviewPanel(object oPC)
{
    string sState = BootstrapLoadState(oPC);

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

json BuildCharacterPanel(object oPC)
{
    string sState = BootstrapLoadState(oPC);
    string sFolder = GetLocalString(oPC, "R36S_SAVEINDEX_FOLDER");
    string sArea = GetLocalString(oPC, "R36S_SAVEINDEX_AREA");
    string sMTime = GetLocalString(oPC, "R36S_SAVEINDEX_MTIME");
    string sSaveName = GetLocalString(oPC, "R36S_SAVEINDEX_SAVE_NAME");

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

void ShowBootstrapMenu(object oPC)
{
    BootstrapDestroyCurrentWindow(oPC);

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
    SetLocalInt(oPC, "R36S_BOOTSTRAP_NUI_TOKEN", nToken);
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_TOKEN: " + IntToString(nToken));
}

void ShowExitConfirm(object oPC)
{
    BootstrapDestroyCurrentWindow(oPC);

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
    SetLocalInt(oPC, "R36S_BOOTSTRAP_NUI_TOKEN", nToken);
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_TOKEN: " + IntToString(nToken));
}

void ShowLoadGameScreen(object oPC)
{
    BootstrapDestroyCurrentWindow(oPC);

    json jRootCol = JsonArray();

    json jTitleRow = JsonArray();
    jTitleRow = JsonArrayInsert(jTitleRow, NuiWidth(NuiSpacer(), 220.0f));
    jTitleRow = JsonArrayInsert(jTitleRow, NuiLabel(JsonString("Load Game"), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP)));
    jTitleRow = JsonArrayInsert(jTitleRow, NuiWidth(NuiSpacer(), 220.0f));
    jRootCol = JsonArrayInsert(jRootCol, NuiRow(jTitleRow));

    json jBodyRow = JsonArray();

    json jLeftPanel = BuildSaveList(oPC);
    jLeftPanel = NuiWidth(jLeftPanel, 340.0f);
    jLeftPanel = NuiHeight(jLeftPanel, 330.0f);

    json jRightPanel = JsonArray();
    jRightPanel = JsonArrayInsert(jRightPanel, BuildPreviewPanel(oPC));
    jRightPanel = JsonArrayInsert(jRightPanel, NuiWidth(NuiSpacer(), 20.0f));
    jRightPanel = JsonArrayInsert(jRightPanel, BuildCharacterPanel(oPC));
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
            if (oPC != OBJECT_INVALID)
            {
                ShowExitConfirm(oPC);
            }
            return;
        }

        if (sEventType == "click" && sEventElement == "btn_load")
        {
            if (oPC != OBJECT_INVALID)
            {
                WriteTimestampedLogEntry("R36S_BOOTSTRAP_LOAD_REQUESTED");
                SetLocalString(oPC, "R36S_SAVEINDEX_STATE", "loading");
                SetLocalString(oPC, "R36S_SAVEINDEX_SAVE_NAME", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_AREA", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_MTIME", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_MODULE_NAME", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_FOLDER", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_CHARACTER_NAME", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_PORTRAIT_RESREF", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_CLASS_NAME", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_LEVEL", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_0_FOLDER", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_0_SAVE_NAME", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_0_AREA", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_0_MTIME", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_0_MODULE_NAME", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_0_CHARACTER_NAME", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_0_PORTRAIT_RESREF", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_0_CLASS_NAME", "");
                SetLocalString(oPC, "R36S_SAVEINDEX_0_LEVEL", "");
                R36S_SetSelectedSave(oPC, -1, "");
                ShowLoadGameScreen(oPC);
                DelayCommand(3.0f, ExecuteScript("r36s_rsi", oPC));
            }
            return;
        }

        if (sEventType == "click" && sEventElement == "btn_save_0")
        {
            if (oPC != OBJECT_INVALID)
            {
                int nSelectedIndex = 0;
                string sFolder = R36S_GetSaveFolderByIndex(oPC, nSelectedIndex);
                if (sFolder != "")
                {
                    R36S_SetSelectedSave(oPC, nSelectedIndex, sFolder);
                    WriteTimestampedLogEntry("R36S_SAVE_SELECTED_INDEX: " + IntToString(nSelectedIndex));
                    WriteTimestampedLogEntry("R36S_SAVE_SELECTED_FOLDER: " + sFolder);
                    DelayCommand(0.1f, ExecuteScript("r36s_rsi", oPC));
                }
            }
            return;
        }

        if (sEventType == "click" && sEventElement == "btn_exit_yes")
        {
            WriteTimestampedLogEntry("R36S_BOOTSTRAP_EXIT_CONFIRMED");
            WriteTimestampedLogEntry("R36S_BOOTSTRAP_EXIT_NO_NUIDESTROY_EXPERIMENT");
            return;
        }

        if (sEventType == "click" && sEventElement == "btn_load_screen_delete")
        {
            WriteTimestampedLogEntry("R36S_BOOTSTRAP_LOAD_SCREEN_DELETE_CLICKED");
            return;
        }

        if (sEventType == "click" && sEventElement == "btn_load_screen_load")
        {
            int nSelectedIndex = -1;
            string sSelectedFolder = "";
            if (oPC != OBJECT_INVALID)
            {
                nSelectedIndex = R36S_GetSelectedSaveIndex(oPC);
                sSelectedFolder = R36S_GetSelectedSaveFolder(oPC);
            }

            if (sSelectedFolder == "" || nSelectedIndex < 0)
            {
                WriteTimestampedLogEntry("R36S_BOOTSTRAP_LOAD_SAVE_NO_SELECTION");
                return;
            }

            WriteTimestampedLogEntry("R36S_SELECTED_SAVE_INDEX: " + IntToString(nSelectedIndex));
            WriteTimestampedLogEntry("R36S_SELECTED_SAVE_FOLDER: " + sSelectedFolder);
            WriteTimestampedLogEntry("R36S_BOOTSTRAP_LOAD_SAVE_REQUESTED|" + IntToString(nSelectedIndex) + "|" + sSelectedFolder);
            return;
        }

        if (sEventType == "click" && sEventElement == "btn_load_screen_cancel")
        {
            if (oPC != OBJECT_INVALID)
            {
                ShowBootstrapMenu(oPC);
            }
            return;
        }

        if (sEventType == "click" && sEventElement == "btn_exit_no")
        {
            WriteTimestampedLogEntry("R36S_BOOTSTRAP_EXIT_CANCELLED");
            if (oPC != OBJECT_INVALID)
            {
                ShowBootstrapMenu(oPC);
            }
        }

        return;
    }

    object oPC = GetEnteringObject();
    if (oPC == OBJECT_INVALID)
    {
        oPC = OBJECT_SELF;
        if (oPC != OBJECT_INVALID && GetLocalInt(oPC, "R36S_BOOTSTRAP_REDRAW_LOAD") == 1)
        {
            SetLocalInt(oPC, "R36S_BOOTSTRAP_REDRAW_LOAD", 0);
            ShowLoadGameScreen(oPC);
        }
        return;
    }

    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_ONCLIENTENTER");
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_ENTERING_VALID: " + IntToString(oPC != OBJECT_INVALID));
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_NUI_ENTERING_IS_PC: " + IntToString(GetIsPC(oPC)));

    if (oPC == OBJECT_INVALID || !GetIsPC(oPC))
    {
        return;
    }
    ShowBootstrapMenu(oPC);
}
