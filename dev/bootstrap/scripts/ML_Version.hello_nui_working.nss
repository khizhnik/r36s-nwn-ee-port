void main()
{
    string sEventType = NuiGetEventType();
    if (sEventType != "")
    {
        return;
    }

    WriteTimestampedLogEntry("R36S_NUI_BOOTSTRAP");

    object oPC = GetFirstPC();
    if (oPC == OBJECT_INVALID)
    {
        WriteTimestampedLogEntry("R36S_NUI_NO_PC");
        return;
    }

    string sJson = "{\"version\":1,\"title\":\"R36S NUI TEST\",\"geometry\":{\"x\":100,\"y\":100,\"w\":300,\"h\":120},\"root\":{\"type\":\"group\",\"children\":[{\"type\":\"label\",\"value\":\"Hello from NUI\"}]}}";
    WriteTimestampedLogEntry("R36S_NUI_JSON: " + sJson);

    json jNui = JsonParse(sJson);
    if (JsonGetType(jNui) == JSON_TYPE_NULL)
    {
        WriteTimestampedLogEntry("R36S_NUI_PARSE_ERROR: " + JsonGetError(jNui));
        return;
    }

    int nToken = NuiCreate(oPC, jNui, "r36snui", "ML_Version");
    WriteTimestampedLogEntry("R36S_NUI_TOKEN: " + IntToString(nToken));
}
