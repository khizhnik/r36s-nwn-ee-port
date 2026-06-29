void main()
{
    object oPC = GetEnteringObject();
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_ONCLIENTENTER");
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_ENTERING_VALID: " + IntToString(oPC != OBJECT_INVALID));
    WriteTimestampedLogEntry("R36S_BOOTSTRAP_ENTERING_IS_PC: " + IntToString(GetIsPC(oPC)));
}
