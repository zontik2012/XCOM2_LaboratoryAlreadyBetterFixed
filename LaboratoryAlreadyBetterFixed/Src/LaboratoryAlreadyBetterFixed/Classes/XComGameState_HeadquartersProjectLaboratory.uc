
//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_HeadquartersProjectLaboratory.uc
//  AUTHOR:  zontik2012  --  05/15/2024
//  PURPOSE: This object represents the instance data for an Laboratory research project
//           Unfortunately had to be duplicated instead of extended to not bug out.
//---------------------------------------------------------------------------------------
class XComGameState_HeadquartersProjectLaboratory extends XComGameState_HeadquartersProject config(game);
var bool bForcePaused;
var bool bIgnoreScienceScore;
var bool bShadowProject;
var bool bProvingGroundProject;

var config float ResearchSpeed;

function SetProjectFocus(StateObjectReference FocusRef, optional XComGameState NewGameState, optional StateObjectReference AuxRef)
{
	local XComGameStateHistory History;
	local XComGameState_Tech Tech;

	History = `XCOMHISTORY;

	ProjectFocus = FocusRef;
	AuxilaryReference = `XCOMHQ.GetFacilityByName('Laboratory').GetReference();
	Tech = XComGameState_Tech(History.GetGameStateForObjectID(FocusRef.ObjectID));

	bInstant = Tech.IsInstant();
	
	if (Tech.bBreakthrough) // If this tech is a breakthrough, duration is not modified by science score
	{
		bIgnoreScienceScore = true;
	}

	UpdateWorkPerHour();
	InitialProjectPoints = Tech.GetProjectPoints(WorkPerHour);
	ProjectPointsRemaining = InitialProjectPoints;
	StartDateTime = `STRATEGYRULES.GameTime;
	if(MakingProgress())
	{
		SetProjectedCompletionDateTime(StartDateTime);
	}
	else
	{
		// Set completion time to unreachable future
		CompletionDateTime.m_iYear = 9999;
	}
}

function int CalculateWorkPerHour(optional XComGameState StartState = none, optional bool bAssumeActive = false)
{
	local XComGameStateHistory History;
	local int iTotalResearch;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_HeadquartersResistance ResHQ;
	local XComGameState_Tech TechState;

    History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

    // Can't make progress when paused
    if (bForcePaused && !bAssumeActive)
    {
        return 0;
    }    
    if (bIgnoreScienceScore)
    {
        iTotalResearch = 5; // Research defaults to a base level of one scientist
    }
    else
    {
        iTotalResearch = XComHQ.GetScienceScore(true);
    }
    
    if (iTotalResearch == 0)
    {
        return 0;
    }
    else
    {
        // Check for Higher Learning
        iTotalResearch += Round(float(iTotalResearch) * (float(XComHQ.ResearchEffectivenessPercentIncrease) / 100.0));

        TechState = XComGameState_Tech(History.GetGameStateForObjectID(ProjectFocus.ObjectID));
        ResHQ = XComGameState_HeadquartersResistance(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersResistance'));

        // Check for Res Order bonuses
        if(TechState.IsWeaponTech() && ResHQ.WeaponsResearchScalar > 0)
        {
            iTotalResearch = Round(float(iTotalResearch) * ResHQ.WeaponsResearchScalar);
        }
        else if(TechState.IsArmorTech() && ResHQ.ArmorResearchScalar > 0)
        {
            iTotalResearch = Round(float(iTotalResearch) * ResHQ.ArmorResearchScalar);
        }
    }


    if (default.ResearchSpeed > 0)
    {
        iTotalResearch *= default.ResearchSpeed;
    }
    return iTotalResearch;
}


// Modified from XComGameState_HeadquartersProjectResearch
// Add the tech to XComs list of completed research, and call any OnResearched methods for the tech
function OnProjectCompleted()
{
	local XComGameState_Tech TechState;
	local StateObjectReference TechRef;

    `LOG("Starting OnProjectCompleted", ,'LaboratoryAlreadyBetterFixed');
	TechRef = ProjectFocus;

	class'XComGameStateContext_LaboratoryResearch'.static.SubmitLaboratoryResearch(ProjectFocus);

	`GAME.GetGeoscape().Pause();

    if(bInstant)
	{
        `LOG("Instant research completed", ,'LaboratoryAlreadyBetterFixed');
		TechState = XComGameState_Tech(`XCOMHISTORY.GetGameStateForObjectID(TechRef.ObjectID));
		TechState.DisplayTechCompletePopups();

		class'Helper'.static.LaboratoryResearchReportPopup(TechRef);
	}
	else
	{
        `LOG("Non-instant research completed", ,'LaboratoryAlreadyBetterFixed');
        class'Helper'.static.UILaboratoryResearchComplete(TechRef);
	}
}

static function Import(out XComGameState_HeadquartersProjectLaboratory ProjectLaboratory, XComGameState_HeadquartersProjectResearch ProjectResearch)
{
    ProjectLaboratory.bShadowProject = ProjectResearch.bShadowProject;
    ProjectLaboratory.bProvingGroundProject = ProjectResearch.bProvingGroundProject;
    ProjectLaboratory.bForcePaused = ProjectResearch.bForcePaused;
    ProjectLaboratory.bIgnoreScienceScore = ProjectResearch.bIgnoreScienceScore;

    ProjectLaboratory.ProjectFocus = ProjectResearch.ProjectFocus;
    ProjectLaboratory.AuxilaryReference = `XCOMHQ.GetFacilityByName('Laboratory').GetReference();
    ProjectLaboratory.StartDateTime =  ProjectResearch.StartDateTime;
    ProjectLaboratory.CompletionDateTime =  ProjectResearch.CompletionDateTime;
    ProjectLaboratory.ProjectPointsRemaining = ProjectResearch.ProjectPointsRemaining;
    ProjectLaboratory.InitialProjectPoints = ProjectResearch.InitialProjectPoints;
    ProjectLaboratory.WorkPerHour = ProjectResearch.WorkPerHour;
    ProjectLaboratory.bInstant = ProjectResearch.bInstant;
    ProjectLaboratory.bProgressesDuringFlight = ProjectResearch.bProgressesDuringFlight;
    ProjectLaboratory.bNoInterruptOnComplete = ProjectResearch.bNoInterruptOnComplete;
    ProjectLaboratory.SavedDiscountPercent = ProjectResearch.SavedDiscountPercent;
    ProjectLaboratory.bIncremental = ProjectResearch.bIncremental;
    ProjectLaboratory.BlocksRemaining = ProjectResearch.BlocksRemaining;
    ProjectLaboratory.BlockPointsRemaining = ProjectResearch.BlockPointsRemaining;
    ProjectLaboratory.BlockCompletionDateTime = ProjectResearch.BlockCompletionDateTime;
    ProjectLaboratory.ProjectCompleteNotification = ProjectResearch.ProjectCompleteNotification;
    ProjectLaboratory.ProjectTimeBeforePausesHours = ProjectResearch.ProjectTimeBeforePausesHours;
    ProjectLaboratory.ResumeProject();
}

static function Export(XComGameState_HeadquartersProjectLaboratory LaboratoryProject, out XComGameState_HeadquartersProjectResearch ProjectResearch)
{
    ProjectResearch.bShadowProject = LaboratoryProject.bShadowProject;
    ProjectResearch.bProvingGroundProject = LaboratoryProject.bProvingGroundProject;
    ProjectResearch.bForcePaused = LaboratoryProject.bForcePaused;
    ProjectResearch.bIgnoreScienceScore = LaboratoryProject.bIgnoreScienceScore;

    ProjectResearch.ProjectFocus = LaboratoryProject.ProjectFocus;
    // ProjectResearch.AuxilaryReference = LaboratoryProject.AuxilaryReference; //no aux ref for research projects
    ProjectResearch.StartDateTime =  LaboratoryProject.StartDateTime;
    ProjectResearch.CompletionDateTime =  LaboratoryProject.CompletionDateTime;
    ProjectResearch.ProjectPointsRemaining = LaboratoryProject.ProjectPointsRemaining;
    ProjectResearch.InitialProjectPoints = LaboratoryProject.InitialProjectPoints;
    ProjectResearch.WorkPerHour = LaboratoryProject.WorkPerHour;
    ProjectResearch.bInstant = LaboratoryProject.bInstant;
    ProjectResearch.bProgressesDuringFlight = LaboratoryProject.bProgressesDuringFlight;
    ProjectResearch.bNoInterruptOnComplete = LaboratoryProject.bNoInterruptOnComplete;
    ProjectResearch.SavedDiscountPercent = LaboratoryProject.SavedDiscountPercent;
    ProjectResearch.bIncremental = LaboratoryProject.bIncremental;
    ProjectResearch.BlocksRemaining = LaboratoryProject.BlocksRemaining;
    ProjectResearch.BlockPointsRemaining = LaboratoryProject.BlockPointsRemaining;
    ProjectResearch.BlockCompletionDateTime = LaboratoryProject.BlockCompletionDateTime;
    ProjectResearch.ProjectCompleteNotification = LaboratoryProject.ProjectCompleteNotification;
    ProjectResearch.ProjectTimeBeforePausesHours = LaboratoryProject.ProjectTimeBeforePausesHours;
    ProjectResearch.UpdateWorkPerHour(); //So that main lab will show correct remaining time
    ProjectResearch.PauseProject();
}
