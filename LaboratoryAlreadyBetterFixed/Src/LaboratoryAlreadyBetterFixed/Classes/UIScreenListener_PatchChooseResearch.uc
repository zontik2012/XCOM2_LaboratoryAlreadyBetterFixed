class UIScreenListener_PatchChooseResearch extends UIScreenListener config(game);

// Removes research projects that are already assigned in the Laboratory
// TODO: Ideally I'd want to be able to "take" lab projects, but I can't find a way to intercept button press/research event

var config bool Enabled;
var localized string m_strLabProject;

var UIChooseResearch CurrentScreen;  //technically as UIChoose-x- is a child of so we can cast to this

// This event is triggered after a screen is initialized
event OnInit(UIScreen Screen)
{
    if (!default.Enabled) {
        return;
    }
    
    CurrentScreen = UIChooseResearch(`SCREENSTACK.GetCurrentScreen());

    if (CurrentScreen != none)
    {
        Update(Screen);
    }
} 

simulated function Update(UIScreen Screen)
{
	local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;
    local UIChooseResearch Parent;
    local int i;

    Parent = UIChooseResearch(Screen);

    if (Parent != none) {
        LaboratoryProject = class'Helper'.static.GetCurrentLaboratoryProject();

        for(i = 0; i < Parent.m_arrRefs.Length; i++)
        {
            if (Parent.m_arrRefs[i].ObjectID == LaboratoryProject.ProjectFocus.ObjectID)
            {
                Parent.m_arrRefs.Remove(i, 1);
                Parent.arrItems.Remove(i, 1);
                break;
            }
        }

        Parent.PopulateData();
    }
}