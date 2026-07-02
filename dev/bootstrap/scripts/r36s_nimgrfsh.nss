#include "nw_inc_nui"

void main()
{
    object oPC = GetFirstPC();
    if (oPC == OBJECT_INVALID)
    {
        return;
    }

    int nToken = GetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_TOKEN");
    if (nToken > 0)
    {
        NuiDestroy(oPC, nToken);
        SetLocalInt(oPC, "R36S_NUI_IMAGE_TEST_TOKEN", 0);
    }

    DelayCommand(0.25f, ExecuteScript("r36s_nimgtest", oPC));
}
