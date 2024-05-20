
class XComGameStateContext_LaboratoryResearch extends XComGameStateContext;

var StateObjectReference LaboratoryProjectFocus;

//XComGameStateContext interface
//***************************************************
/// <summary>
/// Should return true if ContextBuildGameState can return a game state, false if not. Used internally and externally to determine whether a given context is
/// valid or not.
/// </summary>
function bool Validate(optional EInterruptionStatus InInterruptionStatus)
{
	return true;
}

/// <summary>
/// Override in concrete classes to converts the InputContext into an XComGameState
/// </summary>
function XComGameState ContextBuildGameState()
{
	local XComGameState NewGameState;

	//Make the new game state
	NewGameState = `XCOMHISTORY.CreateNewGameState(true, self);

    CompleteLaboratoryResearch(NewGameState, LaboratoryProjectFocus);

	return NewGameState;
}

/// <summary>
/// Convert the ResultContext and AssociatedState into a set of visualization tracks
/// </summary>
protected function ContextBuildVisualization()
{	
}

/// <summary>
/// Returns a short description of this context object
/// </summary>
function string SummaryString()
{
	return "";
}

/// <summary>
/// Returns a string representation of this object.
/// </summary>
function string ToString()
{
	return "";
}
//***************************************************

private function CompleteLaboratoryResearch(XComGameState AddToGameState, StateObjectReference TechReference)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_FacilityXCom FacilityState;
	local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;
	local XComGameState_Tech TechState;
	local X2TechTemplate TechTemplate;
	local int idx;
	`LOG("Completing Laboratory Research", , 'LaboratoryAlreadyBetterFixed');

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

	if(XComHQ != none)
	{
		`LOG("Removing LaboratoryProject from facility & hq", , 'LaboratoryAlreadyBetterFixed');
		XComHQ = XComGameState_HeadquartersXCom(AddToGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		XComHQ.TechsResearched.AddItem(TechReference);
		for(idx = 0; idx < XComHQ.Projects.Length; idx++)
		{
			LaboratoryProject = XComGameState_HeadquartersProjectLaboratory(History.GetGameStateForObjectID(XComHQ.Projects[idx].ObjectID));
			
			if (LaboratoryProject != None && LaboratoryProject.ProjectFocus == TechReference)
			{
				`LOG("Removed project from XComHQ", , 'LaboratoryAlreadyBetterFixed');
				XComHQ.Projects.RemoveItem(LaboratoryProject.GetReference());
				AddToGameState.RemoveStateObject(LaboratoryProject.GetReference().ObjectID);

				FacilityState = XComGameState_FacilityXCom(History.GetGameStateForObjectID(LaboratoryProject.AuxilaryReference.ObjectID));

				if (FacilityState != none)
				{
				`LOG("Removed project from Facility BuildQueue", , 'LaboratoryAlreadyBetterFixed');
					FacilityState = XComGameState_FacilityXCom(AddToGameState.ModifyStateObject(class'XComGameState_FacilityXCom', FacilityState.ObjectID));
					FacilityState.BuildQueue.RemoveItem(LaboratoryProject.GetReference());
				}

				break;
			}
		}
	}

	TechState = XComGameState_Tech(AddToGameState.ModifyStateObject(class'XComGameState_Tech', TechReference.ObjectID));
	TechState.TimesResearched++;
	TechState.TimeReductionScalar = 0;
	TechState.CompletionTime = `GAME.GetGeoscape().m_kDateTime;

	`LOG("Triggering TechState's OnResearchCompleted", , 'LaboratoryAlreadyBetterFixed');
	TechState.OnResearchCompleted(AddToGameState);
	
	TechTemplate = TechState.GetMyTemplate(); // Get the template for the completed tech
	if (!TechState.IsInstant())
	{
		XComHQ.CheckForInstantTechs(AddToGameState);

		// Do not allow two breakthrough techs back-to-back, jump straight to inspired check
		if (TechTemplate.bBreakthrough || !XComHQ.CheckForBreakthroughTechs(AddToGameState))
		{
			// If there is no breakthrough activated, check to activate inspired tech
			XComHQ.CheckForInspiredTechs(AddToGameState);
		}
	}
	
	// Do not clear Breakthrough and Inspired references until after checking for instant
	// to avoid game state conflicts when potentially choosing a new breakthrough tech if the tech tree is exhausted
	if (TechState.bBreakthrough && XComHQ.CurrentBreakthroughTech.ObjectID == TechState.ObjectID)
	{
		XComHQ.CurrentBreakthroughTech.ObjectID = 0;
	}
	else if (TechState.bInspired && XComHQ.CurrentInspiredTech.ObjectID == TechState.ObjectID)
	{
		XComHQ.CurrentInspiredTech.ObjectID = 0;
	}

	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(AddToGameState, 'ResAct_TechsCompleted');

	`LOG("Triggering ResearchCompleted Event", , 'LaboratoryAlreadyBetterFixed');
	`XEVENTMGR.TriggerEvent('ResearchCompleted', TechState, LaboratoryProject, AddToGameState);
}

static function SubmitLaboratoryResearch(StateObjectReference UseInputContext)
{
	local XComGameStateContext_LaboratoryResearch NewLaboratoryResearchContext;

	NewLaboratoryResearchContext = XComGameStateContext_LaboratoryResearch(class'XComGameStateContext_LaboratoryResearch'.static.CreateXComGameStateContext());
	NewLaboratoryResearchContext.LaboratoryProjectFocus = UseInputContext;

	`LOG("Submitting NewLaboratoryResearchContext", , 'LaboratoryAlreadyBetterFixed');
	`GAMERULES.SubmitGameStateContext(NewLaboratoryResearchContext);
}