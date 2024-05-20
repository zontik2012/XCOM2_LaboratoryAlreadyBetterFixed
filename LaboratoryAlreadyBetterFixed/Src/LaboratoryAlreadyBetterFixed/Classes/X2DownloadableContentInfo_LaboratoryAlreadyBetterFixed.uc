class X2DownloadableContentInfo_LaboratoryAlreadyBetterFixed extends X2DownloadableContentInfo;

// Event Strings
var localized string LaboratoryResearchEventLabel;

static event OnPostTemplatesCreated()
{
	local X2StrategyElementTemplateManager StrategyElementTemplateManager;
	local X2FacilityTemplate Template;

	StrategyElementTemplateManager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	Template = X2FacilityTemplate(StrategyElementTemplateManager.FindStrategyElementTemplate('Laboratory'));

	// Template.GetQueueMessageFn = GetLaboratoryResearchQueueMessageV1;
	Template.GetQueueMessageFn = GetLaboratoryResearchQueueMessageV2;
	Template.NeedsAttentionFn = LaboratoryNeedsAttention;
}

// Based on PowerCoreNeedsAttention
static function bool LaboratoryNeedsAttention(StateObjectReference FacilityRef)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

	return (!class'Helper'.static.HasLaboratoryResearchProject() && XComHQ.HasTechsAvailableForResearch());
}

//  Based on active project, powercore-like
static function string GetLaboratoryResearchQueueMessageV1(StateObjectReference FacilityRef)
{
	local string description, time;
	
	if (!class'Helper'.static.HasLaboratoryResearchProject())
	{
		return class'UIUtilities_Text'.static.GetColoredText(class'UIFacility_Powercore'.default.m_strNoActiveResearch, eUIState_Bad);
	}
	else
	{
		// get data
		description = class'Helper'.static.GetCurrentLaboratoryTech().GetDisplayName();

		if (class'Helper'.static.GetCurrentLaboratoryProject().GetCurrentNumHoursRemaining() < 0)
			time = class'UIUtilities_Text'.static.GetColoredText(class'UIFacility_Powercore'.default.m_strStalledResearch, eUIState_Warning);
		else
			time = class'UIUtilities_Text'.static.GetTimeRemainingString(class'Helper'.static.GetCurrentLaboratoryProject().GetCurrentNumHoursRemaining());

		return description $":" @ time;
	}
}

//  Based on facility buildqueue, provingground-like
static function string GetLaboratoryResearchQueueMessageV2(StateObjectReference FacilityRef)
{
	local XComGameStateHistory History;
	local XComGameState_FacilityXCom FacilityState;
	local XComGameState_Tech TechState;
	local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;
	local StateObjectReference BuildItemRef;
	local string strStatus, Message;

	History = `XCOMHISTORY;
	FacilityState = XComGameState_FacilityXCom(History.GetGameStateForObjectID(FacilityRef.ObjectID));

	//Show info about the first item in the build queue.
	if (FacilityState.BuildQueue.length == 0)
	{
		strStatus = class'UIUtilities_Text'.static.GetColoredText(class'UIFacility_Powercore'.default.m_strNoActiveResearch, eUIState_Bad);
	}
	else
	{
		BuildItemRef = FacilityState.BuildQueue[0];
		LaboratoryProject = XComGameState_HeadquartersProjectLaboratory(History.GetGameStateForObjectID(BuildItemRef.ObjectID));
		TechState = XComGameState_Tech(History.GetGameStateForObjectID(LaboratoryProject.ProjectFocus.ObjectID));

		if (LaboratoryProject.GetCurrentNumHoursRemaining() < 0)
			Message = class'UIUtilities_Text'.static.GetColoredText(class'UIFacility_Powercore'.default.m_strStalledResearch, eUIState_Warning);
		else
			Message = class'UIUtilities_Text'.static.GetTimeRemainingString(LaboratoryProject.GetCurrentNumHoursRemaining());

		strStatus = TechState.GetMyTemplate().DisplayName $ ":" @ Message;
	}

	return strStatus;
}


// -------------------------------------------------------------
// ------------ X2WOTCCommunityHighlander Additions ------------
// -------------------------------------------------------------

/// <summary>
/// Called from XComGameState_HeadquartersXCom
/// lets mods add their own events to the event queue when the player is at the Avenger or the Geoscape
/// </summary>
static function bool GetDLCEventInfo(out array<HQEvent> arrEvents)
{
	GetLaboratoryProjectEvents(arrEvents);
	return (arrEvents.Length > 0); //returning true will tell the game to add the events have been added to the above array
}

static function GetLaboratoryProjectEvents(out array<HQEvent> Events)
{
	local XComGameState_Tech Tech;
	local XComGameState_HeadquartersProjectLaboratory LaboratoryProject;
	local HQEvent Event;
	local int i, ProjectHours;
	local XComGameState_FacilityXCom Facility;
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;

	History = `XCOMHISTORY;
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ(true);
	Facility = XComHQ.GetFacilityByName('Laboratory');

	if (Facility != none)
	{
		for (i = 0; i < Facility.BuildQueue.Length; i++)
		{
			LaboratoryProject = XComGameState_HeadquartersProjectLaboratory(History.GetGameStateForObjectID(Facility.BuildQueue[i].ObjectID));

			// Calculate the hours based on which type of Headquarters Project this queue item is
			if (i == 0)
			{
				ProjectHours = LaboratoryProject.GetCurrentNumHoursRemaining();
			}
			else
			{
				ProjectHours += LaboratoryProject.GetProjectedNumHoursRemaining();
			}

			Tech = XComGameState_Tech(History.GetGameStateForObjectID(LaboratoryProject.ProjectFocus.ObjectID));

			Event.Hours = ProjectHours;
			Event.Data = default.LaboratoryResearchEventLabel @ Tech.GetMyTemplate().DisplayName;
			Event.ImagePath = class'UIUtilities_Image'.const.EventQueue_Science;
			Events.AddItem(Event);
		}
	}
}

/// <summary>
/// Calls DLC specific popup handlers to route messages to correct display functions
/// </summary>
static function bool DisplayQueuedDynamicPopup(DynamicPropertySet PropertySet)
{
	local XComHQPresentationLayer Pres;
	local UIAlert_LaboratoryAlreadyBetterFixed Alert;

	if (PropertySet.PrimaryRoutingKey == 'UIAlert_LaboratoryAlreadyBetterFixed')
	{
		Pres = `HQPRES;

		Alert = Pres.Spawn(class'UIAlert_LaboratoryAlreadyBetterFixed', Pres);
		Alert.DisplayPropertySet = PropertySet;
		Alert.eAlertName = PropertySet.SecondaryRoutingKey;

		Pres.ScreenStack.Push(Alert);
		return true;
	}

	return false;
}