class UIFacility_LabsAlreadyBetter extends UIFacility_Labs;

var public UIFacility_ResearchProgress m_ResearchProgress;

var localized string m_strStartResearch;
var localized string m_strCurrentResearch;
var localized string m_strProgress;
//----------------------------------------------------------------------------
// MEMBERS

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	// Research queue
	m_ResearchProgress = Spawn(class'UIFacility_ResearchProgress', self).InitResearchProgress();

	UpdateResearchProgress();
	RealizeNavHelp();
}

simulated function CreateFacilityButtons()
{

	AddFacilityButton(m_strStartResearch, OnChooseResearch);
}

simulated function String GetProgressString()
{
	if (Class'Helper'.static.HasLaboratoryResearchProject())
	{
		return m_strProgress @ class'UIUtilities_Strategy'.static.GetResearchProgressString(`XCOMHQ.GetResearchProgress(Class'Helper'.static.GetCurrentLaboratoryTech().GetReference()));
	}
	else
	{
		return "";
	}
}

simulated function EUIState GetProgressColor()
{
	return class'UIUtilities_Strategy'.static.GetResearchProgressColor(`XCOMHQ.GetResearchProgress(Class'Helper'.static.GetCurrentLaboratoryTech().GetReference()));
}

simulated function UpdateResearchProgress()
{
	local int ProjectHours;
	local string days, progress;
	local XComGameState_Tech LaboratoryTech;
	local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;

	LaboratoryProject = class'Helper'.static.GetCurrentLaboratoryProject();

	if(LaboratoryProject != none)
	{
		LaboratoryTech = XComGameState_Tech(`XCOMHISTORY.GetGameStateForObjectID(LaboratoryProject.ProjectFocus.ObjectID));

		ProjectHours = LaboratoryProject.GetCurrentNumHoursRemaining();

		if (ProjectHours < 0)
			days = class'UIUtilities_Text'.static.GetColoredText(class'UIFacility_PowerCore'.default.m_strStalledResearch, eUIState_Warning);
		else
			days = class'UIUtilities_Text'.static.GetTimeRemainingString(ProjectHours);

		progress = class'UIUtilities_Text'.static.GetColoredText(GetProgressString(), GetProgressColor());
		m_ResearchProgress.Update(m_strCurrentResearch, LaboratoryTech.GetMyTemplate().DisplayName, days, progress, int(100 * LaboratoryProject.GetPercentComplete()));
		m_ResearchProgress.Show();
	}
	else
	{
		m_ResearchProgress.Hide();
	}
}

simulated function bool IsProjectStalled()
{
	if( class'Helper'.static.GetCurrentLaboratoryProject() != none )
		return class'Helper'.static.GetCurrentLaboratoryProject().GetCurrentNumHoursRemaining() < 0;
	else
		return false;
}


simulated function OnChooseResearch()
{
	Class'Helper'.static.UIChooseLaboratoryResearch();
}

// ------------------------------------------------------------


simulated function RealizeStaffSlots()
{
	super.RealizeStaffSlots();
	
	UpdateResearchProgress();
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();

	if (m_kTitle != none)
		m_kTitle.Hide();
} 

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	
	UpdateResearchProgress();

	if (m_kTitle != none)
		m_kTitle.Show();
}

function bool NeedResearchReportPopup(out array<StateObjectReference> TechRefs)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_Tech TechState;
	local int idx;
	local bool bNeedPopup;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	bNeedPopup = false;

	for (idx = 0; idx < XComHQ.TechsResearched.Length; idx++)
	{
		TechState = XComGameState_Tech(History.GetGameStateForObjectID(XComHQ.TechsResearched[idx].ObjectID));

		if (TechState != none && !TechState.bSeenResearchCompleteScreen && !TechState.GetMyTemplate().bShadowProject && TechState.GetMyTemplate().bProvingGround)
		{
			TechRefs.AddItem(TechState.GetReference());
			bNeedPopup = true;
		}
	}

	return bNeedPopup;
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	if(!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;
	
	return super.OnUnrealCommand(cmd, arg);
}
