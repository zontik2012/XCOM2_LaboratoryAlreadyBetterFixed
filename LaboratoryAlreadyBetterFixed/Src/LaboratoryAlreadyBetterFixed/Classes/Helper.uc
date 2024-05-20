class Helper extends Object
	abstract;

static function BuildUIAlert_Mod_LaboratoryAlreadyBetterFixed(
	out DynamicPropertySet PropertySet,
	Name AlertName,
	delegate<X2StrategyGameRulesetDataStructures.AlertCallback> CallbackFunction,
	Name EventToTrigger,
	string SoundToPlay,
	bool bImmediateDisplay = true)
{
	class'X2StrategyGameRulesetDataStructures'.static.BuildDynamicPropertySet(PropertySet, 'UIAlert_LaboratoryAlreadyBetterFixed', AlertName, CallbackFunction, bImmediateDisplay, true, true, false);
	class'X2StrategyGameRulesetDataStructures'.static.AddDynamicNameProperty(PropertySet, 'EventToTrigger', EventToTrigger);
	class'X2StrategyGameRulesetDataStructures'.static.AddDynamicStringProperty(PropertySet, 'SoundToPlay', SoundToPlay);
}

static function UILaboratoryResearchComplete(StateObjectReference TechRef)
{
	local XComGameStateHistory History;
	local XComGameState_Tech TechState;
	local DynamicPropertySet PropertySet;
	local name EventToTrigger;

	History = `XCOMHISTORY;
	TechState = XComGameState_Tech(History.GetGameStateForObjectID(TechRef.ObjectID));

	if (TechState.bBreakthrough)
		EventToTrigger = 'BreakthroughComplete';
	else if (TechState.bInspired)
		EventToTrigger = 'InspirationComplete';
	else
		EventToTrigger = 'LaboratoryResearchCompletePopup';

	BuildUIAlert_Mod_LaboratoryAlreadyBetterFixed(PropertySet, 'eAlert_LaboratoryResearchComplete', LaboratoryResearchCompletePopupCB, EventToTrigger, "Geoscape_ResearchComplete", true);
	class'X2StrategyGameRulesetDataStructures'.static.AddDynamicIntProperty(PropertySet, 'TechRef', TechRef.ObjectID);
	`HQPRES.QueueDynamicPopup(PropertySet);
}

static function LaboratoryResearchCompletePopupCB(Name eAction, out DynamicPropertySet AlertData, optional bool bInstant = false)
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_FacilityXCom FacilityState;

	if (eAction == 'eUIAction_Accept')
	{
		History = `XCOMHISTORY;
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		FacilityState = XComHQ.GetFacilityByName('Laboratory');

		if( `GAME.GetGeoscape().IsScanning() )
			`HQPRES.StrategyMap2D.ToggleScan();

		FacilityState.GetMyTemplate().SelectFacilityFn(FacilityState.GetReference(), true);
		LaboratoryResearchReportPopup(History.GetGameStateForObjectID(class'X2StrategyGameRulesetDataStructures'.static.GetDynamicIntProperty(AlertData, 'TechRef')).GetReference());
	}
	else if( eAction == 'eUIAction_Cancel' )
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Trigger Research Complete Popup Closed");
		`XEVENTMGR.TriggerEvent('OnResearchCompletePopupClosed', , , NewGameState);
		`GAMERULES.SubmitGameState(NewGameState);
	}
}

static function LaboratoryResearchReportPopup(StateObjectReference TechRef, optional bool bInstantInterp = false)
{
	local UILaboratoryResearchReport LaboratoryReport;
	if(`SCREENSTACK.IsNotInStack(class'UILaboratoryResearchReport'))
	{
		LaboratoryReport = `HQPRES.Spawn(class'UILaboratoryResearchReport', `HQPRES);
		LaboratoryReport.bInstantInterp = bInstantInterp;
		`SCREENSTACK.Push(LaboratoryReport, `HQPRES.Get3DMovie());
		LaboratoryReport.InitResearchReport(TechRef);
	}
}

static function UIChooseLaboratoryResearch(optional bool bInstant = false)
{
	local UIScreen TempScreen;

	if (`SCREENSTACK.IsNotInStack(class'UIChooseLaboratoryResearch'))
	{
		TempScreen = `HQPRES.Spawn(class'UIChooseLaboratoryResearch', `HQPRES);
		UIChooseLaboratoryResearch(TempScreen).bInstantInterp = bInstant;
		`SCREENSTACK.Push(TempScreen, `HQPRES.Get3DMovie());
	}
}

//---------------------------------------------------------------------------------------
//--------------------------------LABORATORY PROJECTS------------------------------------
//---------------------------------------------------------------------------------------
static function XComGameState_Tech GetCurrentLaboratoryTech()
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;
	local int idx;

	History = `XCOMHISTORY;

	for(idx = 0; idx < `XCOMHQ.Projects.Length; idx++)
	{
		LaboratoryProject = XComGameState_HeadquartersProjectLaboratory(History.GetGameStateForObjectID(`XCOMHQ.Projects[idx].ObjectID));

		if(LaboratoryProject != none && !LaboratoryProject.bForcePaused)
		{
			return XComGameState_Tech(History.GetGameStateForObjectID(LaboratoryProject.ProjectFocus.ObjectID));
		}
	}

	return none;
}

//---------------------------------------------------------------------------------------
static function XComGameState_HeadquartersProjectLaboratory GetCurrentLaboratoryProject()
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;
	local int idx;

	History = `XCOMHISTORY;

	for (idx = 0; idx < `XCOMHQ.Projects.Length; idx++)
	{
		LaboratoryProject = XComGameState_HeadquartersProjectLaboratory(History.GetGameStateForObjectID(`XCOMHQ.Projects[idx].ObjectID));

		if (LaboratoryProject != none && !LaboratoryProject.bForcePaused)
		{
			return LaboratoryProject;
		}
	}

	return none;
}

//---------------------------------------------------------------------------------------
// If no argument, returns whether or not there's a lab project at all
// If argument is passed, returns if there's lab project with such tech
static function bool HasLaboratoryResearchProject(optional StateObjectReference TechRef)
{
	local int idx;
	local XComGameStateHistory History;
	local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;

	if (TechRef.ObjectID > 0)
	{
		History = `XCOMHISTORY;

		for (idx = 0; idx < `XCOMHQ.Projects.Length; idx++)
		{
			LaboratoryProject = XComGameState_HeadquartersProjectLaboratory(History.GetGameStateForObjectID(`XCOMHQ.Projects[idx].ObjectID));

			if (LaboratoryProject != none && LaboratoryProject.ProjectFocus == TechRef)
			{
				return true;
			}
		}

		return false;
	}

	return (GetCurrentLaboratoryProject() != none);
}
