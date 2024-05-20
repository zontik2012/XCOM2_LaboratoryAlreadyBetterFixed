class UIChooseLaboratoryResearch extends UISimpleCommodityScreen config(Game);

var config array<name> DisableTech;

var localized string m_strResume;
var localized string m_strPause;
var localized string m_strInProgress;

var public bool bInstantInterp;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	RefreshNavHelp();
	RefreshQueue();
}

simulated function RefreshNavHelp()
{
	local UINavigationHelp NavHelp;

	NavHelp = `HQPRES.m_kAvengerHUD.NavHelp;

	NavHelp.ClearButtonHelp();
	NavHelp.bIsVerticalHelp = `ISCONTROLLERACTIVE;
	NavHelp.AddBackButton(CloseScreen);

	if(`ISCONTROLLERACTIVE)
	{
		NavHelp.AddSelectNavHelp();
	}
}

//-------------- EVENT HANDLING --------------------------------------------------------
simulated function OnPurchaseClicked(UIList kList, int itemIndex)
{
	if( itemIndex != iSelectedItem )
	{	
		iSelectedItem = itemIndex;
	}

	if (CanAffordItem(iSelectedItem))
	{
		if(OnTechTableOption(iSelectedItem))
		{
			PlaySFX("ResearchConfirm");
			// Movie.Stack.Pop(self);
			RefreshQueue();
			GetItems();
			PopulateData();
		}
	}
	else
	{
		PlayNegativeSound(); // bsg-jrebar (4/20/17): New PlayNegativeSound Function in Parent Class
	}
}

simulated function bool CanAffordItem(int ItemIndex)
{
	if( ItemIndex > -1 && ItemIndex < arrItems.Length )
	{
		return XComHQ.CanAffordCommodity(arrItems[ItemIndex]);
	}
	else
	{
		return false;
	}
}


//-------------- GAME DATA HOOKUP --------------------------------------------------------
simulated function GetItems()
{
	arrItems = ConvertTechsToCommodities();
}

simulated function array<Commodity> ConvertTechsToCommodities()
{
	local X2TechTemplate TechTemplate;
	local XComGameState_Tech TechState;
	local int iTech;
	local bool bPausedProject;
	local bool bLaboratoryProject;
	local bool bCompletedTech;
	local array<Commodity> arrCommodoties;
	local Commodity TechComm;
	local StrategyCost EmptyCost;
	local StrategyRequirement EmptyReqs;
	local string TechSummary;

	m_arrRefs.Remove(0, m_arrRefs.Length);
	m_arrRefs = GetTechs();
	m_arrRefs.Sort(SortTechsTime);
	m_arrRefs.Sort(SortTechsTier);
	m_arrRefs.Sort(SortTechsPriority);
	m_arrRefs.Sort(SortTechsInspired);
	m_arrRefs.Sort(SortTechsBreakthrough);
	m_arrRefs.Sort(SortTechsInstant);
	m_arrRefs.Sort(SortTechsCanResearch);

	for( iTech = 0; iTech < m_arrRefs.Length; iTech++ )
	{
		TechState = XComGameState_Tech(History.GetGameStateForObjectID(m_arrRefs[iTech].ObjectID));
		TechTemplate = TechState.GetMyTemplate();
		bPausedProject = XComHQ.HasPausedProject(m_arrRefs[iTech]);
		bLaboratoryProject = class'Helper'.static.HasLaboratoryResearchProject(m_arrRefs[iTech]);
		bCompletedTech = XComHQ.TechIsResearched(m_arrRefs[iTech]);
		
		TechComm.Title = TechState.GetDisplayName();

		if (bLaboratoryProject)
		{
			TechComm.Title = TechComm.Title @ m_strInProgress;
		}
		else if (bPausedProject)
		{
			TechComm.Title = TechComm.Title @ class'UIChooseResearch'.default.m_strPaused;
		}
		else if (TechState.bForceInstant)
		{
			TechComm.Title = TechComm.Title @ class'UIChooseResearch'.default.m_strInstant;
		}
		else if (TechState.bBreakthrough)
		{
			TechComm.Title = TechComm.Title @ class'UIChooseResearch'.default.m_strBreakthrough;
		}
		else if (TechState.bInspired)
		{
			TechComm.Title = TechComm.Title @ class'UIChooseResearch'.default.m_strInspired;
		}

		TechComm.Image = TechState.GetImage();

		TechSummary = TechState.GetSummary();
		if (TechTemplate.GetValueFn != none)
		{
			TechSummary = Repl(TechSummary, "%VALUE", TechTemplate.GetValueFn());
		}

		TechComm.Desc = TechSummary;
		TechComm.OrderHours = GetResearchHours(m_arrRefs[iTech]);
		TechComm.bTech = true;
		
		if (bLaboratoryProject || bPausedProject || (bCompletedTech && !TechTemplate.bRepeatable))
		{
			TechComm.Cost = EmptyCost;
			TechComm.Requirements = EmptyReqs;
		}
		else
		{
			TechComm.Cost = TechTemplate.Cost;
			TechComm.Requirements = GetBestStrategyRequirementsForUI(TechTemplate);
			TechComm.CostScalars = XComHQ.ResearchCostScalars;
		}

		arrCommodoties.AddItem(TechComm);
	}

	return arrCommodoties;
}

simulated function String GetButtonString(int ItemIndex)
{
	if (XComHQ.HasPausedProject(m_arrRefs[ItemIndex]))
	{
		return m_strResume;
	}
	else if (class'Helper'.static.HasLaboratoryResearchProject(m_arrRefs[ItemIndex]))
	{
		return m_strPause;
	}
	else
	{
		return m_strBuy;
	}
}

simulated function array<StateObjectReference> GetTechs() 
{
	local array<StateObjectReference> Result;

	local array<StateObjectReference> TechRefs;
    local StateObjectReference TechRef;
	local XComGameState_Tech TechState, CurrentTechState;
    local X2TechTemplate TechTemplate;
	local bool bAddLabTech;

	TechRefs = class'UIUtilities_Strategy'.static.GetXComHQ().GetAvailableTechsForResearch(false);
	
	foreach TechRefs(TechRef)
	{
		TechState = XComGameState_Tech(History.GetGameStateForObjectID(TechRef.ObjectID));
        TechTemplate = TechState.GetMyTemplate();

		if (default.DisableTech.Find(TechTemplate.DataName) == INDEX_NONE)
		{
			Result.AddItem(TechRef);
		}
	}

	//Adding current research if it is hidden without required stuff (stuff like decrypting advent datapads)
	if (class'Helper'.static.HasLaboratoryResearchProject()) {
		bAddLabTech = true;
		CurrentTechState = class'Helper'.static.GetCurrentLaboratoryTech();
		
		`LOG("There's a research currently: " @ CurrentTechState.GetMyTemplate().DataName,,'LaboratoryAlreadyBetterFixed');
		forEach Result(TechRef)
		{
			if (TechRef == CurrentTechState.GetReference())
			{
				bAddLabTech = false;
				break;
			}
		}

		if (bAddLabTech)
		{
			`LOG("Did not find this research, adding it to the list",,'LaboratoryAlreadyBetterFixed');
			Result.AddItem(CurrentTechState.GetReference());
		}
		else
		{
			`LOG("Found this research in list, do not do anything",,'LaboratoryAlreadyBetterFixed');
		}
	}

	return Result;
}

simulated function StrategyRequirement GetBestStrategyRequirementsForUI(X2TechTemplate TechTemplate)
{
	local StrategyRequirement AltRequirement;

	if (!XComHQ.MeetsAllStrategyRequirements(TechTemplate.Requirements) && TechTemplate.AlternateRequirements.Length > 0)
	{
		foreach TechTemplate.AlternateRequirements(AltRequirement)
		{
			if (XComHQ.MeetsAllStrategyRequirements(AltRequirement))
			{
				return AltRequirement;
			}
		}
	}

	return TechTemplate.Requirements;
}

function int SortTechsInstant(StateObjectReference TechRefA, StateObjectReference TechRefB)
{
	local XComGameState_Tech TechStateA, TechStateB;

	TechStateA = XComGameState_Tech(History.GetGameStateForObjectID(TechRefA.ObjectID));
	TechStateB = XComGameState_Tech(History.GetGameStateForObjectID(TechRefB.ObjectID));

	if (TechStateA.IsInstant() && !TechStateB.IsInstant())
	{
		return 1;
	}
	else if (!TechStateA.IsInstant() && TechStateB.IsInstant())
	{
		return -1;
	}
	else
	{
		return 0;
	}
}

function int SortTechsBreakthrough(StateObjectReference TechRefA, StateObjectReference TechRefB)
{
	local XComGameState_Tech TechStateA, TechStateB;

	TechStateA = XComGameState_Tech(History.GetGameStateForObjectID(TechRefA.ObjectID));
	TechStateB = XComGameState_Tech(History.GetGameStateForObjectID(TechRefB.ObjectID));

	if (TechStateA.bBreakthrough && !TechStateB.bBreakthrough)
	{
		return 1;
	}
	else if (!TechStateA.bBreakthrough && TechStateB.bBreakthrough)
	{
		return -1;
	}
	else
	{
		return 0;
	}
}

function int SortTechsInspired(StateObjectReference TechRefA, StateObjectReference TechRefB)
{
	local XComGameState_Tech TechStateA, TechStateB;

	TechStateA = XComGameState_Tech(History.GetGameStateForObjectID(TechRefA.ObjectID));
	TechStateB = XComGameState_Tech(History.GetGameStateForObjectID(TechRefB.ObjectID));

	if (TechStateA.bInspired && !TechStateB.bInspired)
	{
		return 1;
	}
	else if (!TechStateA.bInspired && TechStateB.bInspired)
	{
		return -1;
	}
	else
	{
		return 0;
	}
}

function int SortTechsPriority(StateObjectReference TechRefA, StateObjectReference TechRefB)
{
	local XComGameState_Tech TechStateA, TechStateB;

	TechStateA = XComGameState_Tech(History.GetGameStateForObjectID(TechRefA.ObjectID));
	TechStateB = XComGameState_Tech(History.GetGameStateForObjectID(TechRefB.ObjectID));

	if(TechStateA.IsPriority() && !TechStateB.IsPriority())
	{
		return 1;
	}
	else if(!TechStateA.IsPriority() && TechStateB.IsPriority())
	{
		return -1;
	}
	else
	{
		return 0;
	}
}

function int SortTechsCanResearch(StateObjectReference TechRefA, StateObjectReference TechRefB)
{
	local X2TechTemplate TechTemplateA, TechTemplateB;
	local bool CanResearchA, CanResearchB;


	TechTemplateA = XComGameState_Tech(History.GetGameStateForObjectID(TechRefA.ObjectID)).GetMyTemplate();
	TechTemplateB = XComGameState_Tech(History.GetGameStateForObjectID(TechRefB.ObjectID)).GetMyTemplate();
	CanResearchA = XComHQ.MeetsRequirmentsAndCanAffordCost(TechTemplateA.Requirements, TechTemplateA.Cost, XComHQ.ResearchCostScalars, 0.0, TechTemplateA.AlternateRequirements);
	CanResearchB = XComHQ.MeetsRequirmentsAndCanAffordCost(TechTemplateB.Requirements, TechTemplateB.Cost, XComHQ.ResearchCostScalars, 0.0, TechTemplateB.AlternateRequirements);

	if (CanResearchA && !CanResearchB)
	{
		return 1;
	}
	else if (!CanResearchA && CanResearchB)
	{
		return -1;
	}
	else
	{
		return 0;
	}
}

function int SortTechsTime(StateObjectReference TechRefA, StateObjectReference TechRefB)
{
	local int HoursA, HoursB;

	HoursA = GetResearchHours(TechRefA);
	HoursB = GetResearchHours(TechRefB);

	if (HoursA < HoursB)
	{
		return 1;
	}
	else if (HoursA > HoursB)
	{
		return -1;
	}
	else
	{
		return 0;
	}
}

function int SortTechsTier(StateObjectReference TechRefA, StateObjectReference TechRefB)
{
	local int TierA, TierB;

	TierA = XComGameState_Tech(History.GetGameStateForObjectID(TechRefA.ObjectID)).GetMyTemplate().SortingTier;
	TierB = XComGameState_Tech(History.GetGameStateForObjectID(TechRefB.ObjectID)).GetMyTemplate().SortingTier;

	if (TierA < TierB) return 1;
	else if (TierA > TierB) return -1;
	else return 0;
}

simulated function XComGameState_HeadquartersProjectLaboratory GetActiveProject()
{
	local XComGameState_FacilityXCom FacilityState;

	FacilityState = XComHQ.GetFacilityByName('Laboratory');
    if (FacilityState.BuildQueue.Length > 0)
    {
		return XComGameState_HeadquartersProjectLaboratory(History.GetGameStateForObjectID(FacilityState.BuildQueue[0].ObjectID));
    }

    return none;
}

simulated function bool IsActiveTech(XComGameState_Tech Tech)
{
    local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;

    LaboratoryProject = GetActiveProject();

    if ((LaboratoryProject != none) && (LaboratoryProject.ProjectFocus.ObjectID == Tech.GetReference().ObjectID))
    {
        return true;
    }

    return false;
}

function bool OnTechTableOption(int iOption)
{
	local XComGameState_Tech TechState;
	local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;
    local XComGameState_HeadquartersProjectResearch ResearchProject;

	TechState = XComGameState_Tech(History.GetGameStateForObjectID(m_arrRefs[iOption].ObjectID));

	if (class'Helper'.static.HasLaboratoryResearchProject()) {

		LaboratoryProject = class'Helper'.static.GetCurrentLaboratoryProject();

		if (LaboratoryProject.ProjectFocus.ObjectID == TechState.GetReference().ObjectID)
		{
			PauseProject(LaboratoryProject);
			return true;
		} else {
			PauseProject(LaboratoryProject);

			ResearchProject = XComHQ.GetPausedProject(TechState.GetReference());
			if (ResearchProject != none)
			{
				ResumeProject(ResearchProject);
				return true;
			}
			else
			{
				StartProject(TechState);
				return true;
			}
		}
	}
	else
	{
		ResearchProject = XComHQ.GetPausedProject(TechState.GetReference());
		if (ResearchProject != none)
		{
			ResumeProject(ResearchProject);
			return true;
		}
		else
		{
			StartProject(TechState);
			return true;
		}
	}
	return false;
}

simulated function StartProject(XComGameState_Tech Tech)
{
	local XComGameState NewGameState;
	local XComGameState_FacilityXCom FacilityState;
	local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;
    local XComGameState_HeadquartersProjectResearch ResearchProject;
	local StrategyCost TechCost;
    local X2TechTemplate TechTemplate;
    local StateObjectReference TechRef;
    local XComGameState_Tech BreakthroughTechState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("UILaboratory.SetNewLaboratoryProject");
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

    TechTemplate = Tech.GetMyTemplate();
    TechRef = Tech.GetReference();
	ResearchProject = XComHQ.GetPausedProject(TechRef);
	LaboratoryProject = XComGameState_HeadquartersProjectLaboratory(NewGameState.CreateNewStateObject(class'XComGameState_HeadquartersProjectLaboratory'));

	if (ResearchProject != none)
	{
		class'XComGameState_HeadquartersProjectLaboratory'.static.Import(LaboratoryProject, ResearchProject);
		LaboratoryProject.bForcePaused = false;
        XComHQ.Projects.RemoveItem(ResearchProject.GetReference());      
	}
	else
	{
    	LaboratoryProject.SetProjectFocus(TechRef);

		TechCost = TechTemplate.Cost;
		XComHQ.PayStrategyCost(NewGameState, TechCost, XComHQ.ResearchCostScalars);
	}

    XComHQ.Projects.AddItem(LaboratoryProject.GetReference());   

	FacilityState = XComHQ.GetFacilityByName('Laboratory');
	FacilityState = XComGameState_FacilityXCom(NewGameState.ModifyStateObject(class'XComGameState_FacilityXCom', FacilityState.ObjectID));
    FacilityState.BuildQueue.AddItem(LaboratoryProject.GetReference());
	

	// Only clear current Inspired or Breakthrough techs if a non-Instant project was started,
	if (!LaboratoryProject.bInstant)
	{
		if (TechTemplate.bBreakthrough)
		{
			BreakthroughTechState = XComGameState_Tech(NewGameState.ModifyStateObject(class'XComGameState_Tech', Tech.ObjectID));
			BreakthroughTechState.bBreakthrough = false;

			if (LaboratoryProject.bForcePaused) // A paused version of this breakthrough project exists, so we need to remove it
			{
				XComHQ.Projects.RemoveItem(LaboratoryProject.GetReference());
				NewGameState.RemoveStateObject(LaboratoryProject.ObjectID);
			}

			XComHQ.IgnoredBreakthroughTechs.AddItem(Tech.GetReference());
		}
	}

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	if(LaboratoryProject.bInstant)
	{
		LaboratoryProject.OnProjectCompleted();
	}

	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
	XComHQ.HandlePowerOrStaffingChange();
    
	class'X2StrategyGameRulesetDataStructures'.static.ForceUpdateObjectivesUI();
}

simulated function ResumeProject(XComGameState_HeadquartersProjectResearch ResearchProject)
{
	local XComGameState NewGameState;
	local XComGameState_FacilityXCom FacilityState;
	local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("UILaboratory.ResumeProject");
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

    ResearchProject = XComGameState_HeadquartersProjectResearch(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersProjectResearch', ResearchProject.ObjectID));
    ResearchProject.bForcePaused = false;
	
	LaboratoryProject = XComGameState_HeadquartersProjectLaboratory(NewGameState.CreateNewStateObject(class'XComGameState_HeadquartersProjectLaboratory'));
    class'XComGameState_HeadquartersProjectLaboratory'.static.Import(LaboratoryProject, ResearchProject);

	FacilityState = XComHQ.GetFacilityByName('Laboratory');
	FacilityState = XComGameState_FacilityXCom(NewGameState.ModifyStateObject(class'XComGameState_FacilityXCom', FacilityState.ObjectID));
	FacilityState.BuildQueue.AddItem(LaboratoryProject.GetReference());

    XComHQ.Projects.RemoveItem(ResearchProject.GetReference());
    XComHQ.Projects.AddItem(LaboratoryProject.GetReference());
    NewGameState.RemoveStateObject(ResearchProject.ObjectID);

    `XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
}

simulated function PauseProject(XComGameState_HeadquartersProjectLaboratory LaboratoryProject)
{
	local XComGameState NewGameState;
	local XComGameState_FacilityXCom FacilityState;
    local XComGameState_HeadquartersProjectResearch ResearchProject;

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("UILaboratory.PauseProject");
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

	FacilityState = XComHQ.GetFacilityByName('Laboratory');
	FacilityState = XComGameState_FacilityXCom(NewGameState.ModifyStateObject(class'XComGameState_FacilityXCom', FacilityState.ObjectID));
    FacilityState.BuildQueue.RemoveItem(LaboratoryProject.GetReference());

    LaboratoryProject = XComGameState_HeadquartersProjectLaboratory(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersProjectLaboratory', LaboratoryProject.ObjectID));
    LaboratoryProject.bForcePaused = true;
	ResearchProject = XComGameState_HeadquartersProjectResearch(NewGameState.CreateNewStateObject(class'XComGameState_HeadquartersProjectResearch'));
    class'XComGameState_HeadquartersProjectLaboratory'.static.Export(LaboratoryProject, ResearchProject);

    XComHQ.Projects.RemoveItem(LaboratoryProject.GetReference());
    XComHQ.Projects.AddItem(ResearchProject.GetReference());
    NewGameState.RemoveStateObject(LaboratoryProject.ObjectID);

    `XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
}

simulated function RefreshQueue()
{
	local UIScreen QueueScreen;

	QueueScreen = Movie.Stack.GetScreen(class'UIFacility_LabsAlreadyBetter');
	if (QueueScreen != None)
	{
		// UIFacility_LabsAlreadyBetter(QueueScreen).UpdateBuildQueue();
		UIFacility_LabsAlreadyBetter(QueueScreen).UpdateResearchProgress();
		// UIFacility_LabsAlreadyBetter(QueueScreen).m_NewBuildQueue.DeactivateButtons();
	}

	UpdateResources();
}

simulated function UpdateResources()
{
    `HQPRES.m_kAvengerHUD.UpdateResources();
}

// Modfied from XComGameState_HeadquartersXCom
static function int GetResearchHours(StateObjectReference TechRef)
{
	local int iHours;
	local XComGameState NewGameState;
	local XComGameStateHistory iHistory;
	local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;
    local XComGameState_HeadquartersProjectResearch ResearchProject;

	iHistory = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("SHOULD NOT BE SUBMITTED");
	LaboratoryProject = XComGameState_HeadquartersProjectLaboratory(NewGameState.CreateNewStateObject(class'XComGameState_HeadquartersProjectLaboratory'));
	
	ResearchProject = `XCOMHQ.GetPausedProject(TechRef);

	if (ResearchProject == none)
	{
		LaboratoryProject.SetProjectFocus(TechRef);
	}
    else
    {
        class'XComGameState_HeadquartersProjectLaboratory'.static.Import(LaboratoryProject, ResearchProject);
    }

	iHours = LaboratoryProject.GetProjectedNumHoursRemaining();
	
	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		NewGameState.PurgeGameStateForObjectID(LaboratoryProject.ObjectID);
	}

	iHistory.CleanupPendingGameState(NewGameState);

	if(LaboratoryProject.bInstant)
	{
		return 0;
	}
	else
	{
		return iHours;
	}
}

defaultproperties
{
	InputState = eInputState_Consume;

	DisplayTag      = "UIBlueprint_Camera_1";
	CameraTag       = "UIBlueprint_Camera_1";

	bHideOnLoseFocus = true;
}
