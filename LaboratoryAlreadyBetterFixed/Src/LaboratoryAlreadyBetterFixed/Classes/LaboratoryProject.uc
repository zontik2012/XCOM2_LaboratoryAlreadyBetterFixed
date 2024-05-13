class LaboratoryProject extends XComGameState_HeadquartersProject;
// We can't inherit from XComGameState_HeadquartersProjectResearch as that would allow the main research lab to steal our projects, whenever the player enters that facility
// We also need special CalculateWorkPerHour anyways

var bool bShadowProject;
var bool bProvingGroundProject;
var bool bForcePaused;
var bool bIgnoreScienceScore;

function SetProjectFocus(StateObjectReference FocusRef, optional XComGameState NewGameState, optional StateObjectReference AuxRef)
{
	local XComGameStateHistory History;
	local XComGameState_Tech Tech;

	History = `XCOMHISTORY;

	ProjectFocus = FocusRef;
	AuxilaryReference = AuxRef;
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
    local float Handicap;

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

    Handicap = class'X2DownloadableContentInfo_LaboratoryAlreadyBetterFixed'.static.GetCurrentHandicap();
        
    if (Handicap > 0)
    {
        iTotalResearch *= (Handicap / 100);
    }
    
    return iTotalResearch;
}


// Modified from XComGameState_HeadquartersProjectResearch
// Add the tech to XComs list of completed research, and call any OnResearched methods for the tech
function OnProjectCompleted()
{
	local XComGameState_Tech TechState;
	local HeadquartersOrderInputContext OrderInput;
	local StateObjectReference TechRef;
	local XComGameState NewGameState;
    local XComGameState_FacilityXCom Facility;
    local XComGameStateHistory History;
    local XComGameState_HeadquartersXCom XComHQ;

	TechRef = ProjectFocus;

	OrderInput.OrderType = eHeadquartersOrderType_ResearchCompleted;
	OrderInput.AcquireObjectReference = ProjectFocus;

	class'XComGameStateContext_HeadquartersOrder'.static.IssueHeadquartersOrder(OrderInput);

	`GAME.GetGeoscape().Pause();
    Facility = XComGameState_FacilityXCom(`XCOMHISTORY.GetGameStateForObjectID(AuxilaryReference.ObjectID));

    if(bInstant)
	{
		TechState = XComGameState_Tech(`XCOMHISTORY.GetGameStateForObjectID(TechRef.ObjectID));
		TechState.DisplayTechCompletePopups();
		`HQPRES.ResearchReportPopup(TechRef);
	}
	else
	{
        if(`GAME.GetGeoscape().IsScanning())
        {
			`HQPRES.StrategyMap2D.ToggleScan();
        }

		Facility.GetMyTemplate().SelectFacilityFn(Facility.GetReference(), true);

	    `SCREENSTACK.Push(`HQPRES.Spawn(class'UIReport', `HQPRES), `HQPRES.Get3DMovie());
	}

    // Clear the project from the Laboratory build queue and from the main XComHQ Projects list and the StateObject related to this Project
    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("LaboratoryProject.OnProjectCompleted");
    Facility = XComGameState_FacilityXCom(NewGameState.ModifyStateObject(class'XComGameState_FacilityXCom', AuxilaryReference.ObjectID));
    Facility.BuildQueue.Length = 0;
	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
    XComHQ.Projects.RemoveItem(GetReference());
    NewGameState.RemoveStateObject(ObjectID);
    `XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

function RushResearch(XComGameState NewGameState)
{
	local XComGameState_Tech TechState;

	TechState = XComGameState_Tech(NewGameState.GetGameStateForObjectID(ProjectFocus.ObjectID));

	UpdateProjectPointsRemaining(GetCurrentWorkPerHour());
	ProjectPointsRemaining -= Round(float(ProjectPointsRemaining) * TechState.TimeReductionScalar);
	ProjectPointsRemaining = Clamp(ProjectPointsRemaining, 0, InitialProjectPoints);

	StartDateTime = `STRATEGYRULES.GameTime;
	if(MakingProgress())
	{
		SetProjectedCompletionDateTime(StartDateTime);
	}
}
function AddResearchDays(int NumDays)
{
	local int PointsToAdd;

	PointsToAdd = CalculateWorkPerHour(, true);
	PointsToAdd *= (NumDays * 24);

	ProjectPointsRemaining += PointsToAdd;

	StartDateTime = `STRATEGYRULES.GameTime;
	if(MakingProgress())
	{
		SetProjectedCompletionDateTime(StartDateTime);
	}
}

static function Import(out LaboratoryProject LaboratoryProject, XComGameState_HeadquartersProjectResearch ProjectResearch)
{
    LaboratoryProject.bShadowProject = ProjectResearch.bShadowProject;
    LaboratoryProject.bProvingGroundProject = ProjectResearch.bProvingGroundProject;
    LaboratoryProject.bForcePaused = ProjectResearch.bForcePaused;
    LaboratoryProject.bIgnoreScienceScore = ProjectResearch.bIgnoreScienceScore;

    LaboratoryProject.ProjectFocus = ProjectResearch.ProjectFocus;
    LaboratoryProject.AuxilaryReference = ProjectResearch.AuxilaryReference;
    LaboratoryProject.StartDateTime =  ProjectResearch.StartDateTime;
    LaboratoryProject.CompletionDateTime =  ProjectResearch.CompletionDateTime;
    LaboratoryProject.ProjectPointsRemaining = ProjectResearch.ProjectPointsRemaining;
    LaboratoryProject.InitialProjectPoints = ProjectResearch.InitialProjectPoints;
    LaboratoryProject.WorkPerHour = ProjectResearch.WorkPerHour;
    LaboratoryProject.bInstant = ProjectResearch.bInstant;
    LaboratoryProject.bProgressesDuringFlight = ProjectResearch.bProgressesDuringFlight;
    LaboratoryProject.bNoInterruptOnComplete = ProjectResearch.bNoInterruptOnComplete;
    LaboratoryProject.SavedDiscountPercent = ProjectResearch.SavedDiscountPercent;
    LaboratoryProject.bIncremental = ProjectResearch.bIncremental;
    LaboratoryProject.BlocksRemaining = ProjectResearch.BlocksRemaining;
    LaboratoryProject.BlockPointsRemaining = ProjectResearch.BlockPointsRemaining;
    LaboratoryProject.BlockCompletionDateTime = ProjectResearch.BlockCompletionDateTime;
    LaboratoryProject.ProjectCompleteNotification = ProjectResearch.ProjectCompleteNotification;
    LaboratoryProject.ProjectTimeBeforePausesHours = ProjectResearch.ProjectTimeBeforePausesHours;
    LaboratoryProject.ResumeProject();
}

static function Export(LaboratoryProject LaboratoryProject, out XComGameState_HeadquartersProjectResearch ProjectResearch)
{
    ProjectResearch.bShadowProject = LaboratoryProject.bShadowProject;
    ProjectResearch.bProvingGroundProject = LaboratoryProject.bProvingGroundProject;
    ProjectResearch.bForcePaused = LaboratoryProject.bForcePaused;
    ProjectResearch.bIgnoreScienceScore = LaboratoryProject.bIgnoreScienceScore;

    ProjectResearch.ProjectFocus = LaboratoryProject.ProjectFocus;
    ProjectResearch.AuxilaryReference = LaboratoryProject.AuxilaryReference;
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
    ProjectResearch.PauseProject();
}
