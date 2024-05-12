class Monkey_UIChooseResearch extends UIScreenListener config(game);

// Removes research projects that are already assigned in the Laboratory

var config bool Enabled;

// This event is triggered after a screen is initialized
event OnInit(UIScreen Screen)
{
    if (default.Enabled)
    {
        Update(Screen);
    }
} 

simulated function Update(UIScreen Screen)
{
	local LaboratoryProject LaboratoryProject;
    local XComGameState_FacilityXCom FacilityState;
    local UIChooseResearch Parent;
	local XComGameState_Tech Tech;
    local string DisplayName;
    local int i;

    Parent = UIChooseResearch(Screen);
	FacilityState = `XCOMHQ.GetFacilityByName('Laboratory');

    if (FacilityState.BuildQueue.Length > 0)
    {
		LaboratoryProject = LaboratoryProject(`XCOMHISTORY.GetGameStateForObjectID(FacilityState.BuildQueue[0].ObjectID));
		Tech = XComGameState_Tech(`XCOMHISTORY.GetGameStateForObjectID(LaboratoryProject.ProjectFocus.ObjectID));
        DisplayName = Tech.GetDisplayName();

    	for(i = 0; i < Parent.m_arrRefs.Length; i++)
        {
            if (Parent.m_arrRefs[i].ObjectID == LaboratoryProject.ProjectFocus.ObjectID)
            {
                Parent.m_arrRefs.Remove(i, 1);
                break;
            }
        }
        for (i = 0; i < Parent.arrItems.Length; i++)
        {
            if (Parent.arrItems[i].Title == DisplayName)
            {
                Parent.arrItems.Remove(i, 1);
                break;
            }
        }

        Parent.PopulateData();
    }
}

defaultproperties
{
	ScreenClass = UIChooseResearch;
}