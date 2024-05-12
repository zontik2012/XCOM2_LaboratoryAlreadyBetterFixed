class X2DownloadableContentInfo_LaboratoryAlreadyBetterFixed extends X2DownloadableContentInfo;

var config bool ExtraSlots;

var config bool Handicap;
var config int HandicapAmount;

static event OnPostTemplatesCreated()
{
	if (default.ExtraSlots)
	{
		AddSlots();
	}

	ChangeSlots();
}

static event OnLoadedSavedGameToStrategy()
{
	class'Helper'.static.UpdateStaffSlots('Laboratory');
}

static function AddSlots()
{
	local X2StrategyElementTemplateManager StrategyElementTemplateManager;
	local StaffSlotDefinition StaffSlotDef;
	local X2FacilityTemplate Template;
	
	StrategyElementTemplateManager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	Template = X2FacilityTemplate(StrategyElementTemplateManager.FindStrategyElementTemplate('Laboratory'));	

	Template.Upgrades.AddItem('Laboratory_Level_2');
	Template.Upgrades.AddItem('Laboratory_Level_3');

	StaffSlotDef.StaffSlotTemplateName = 'LaboratoryStaffSlot';
	StaffSlotDef.bStartsLocked = true;
	Template.StaffSlotDefs.AddItem(StaffSlotDef);
	Template.StaffSlotDefs.AddItem(StaffSlotDef);
}

static function ChangeSlots()
{
	local X2StrategyElementTemplateManager StrategyElementTemplateManager;
	local X2StaffSlotTemplate Template;
	
	StrategyElementTemplateManager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	Template = X2StaffSlotTemplate(StrategyElementTemplateManager.FindStrategyElementTemplate('LaboratoryStaffSlot'));	

	// We override the default slot behavior to add in own
	Template.FillFn = FillLaboratorySlot;
	Template.EmptyFn = EmptyLaboratorySlot;
	Template.GetBonusDisplayStringFn = GetLaboratoryBonusDisplayString;
	Template.IsStaffSlotBusyFn = IsStaffSlotBusyDefault;
	Template.CanStaffBeMovedFn = CanStaffBeMoved;
}
static function FillLaboratorySlot(XComGameState NewGameState, StateObjectReference SlotRef, StaffUnitInfo UnitInfo, optional bool bTemporary = false)
{
	class'X2StrategyElement_DefaultStaffSlots'.static.FillLaboratorySlot(NewGameState, SlotRef, UnitInfo, bTemporary);
}

static function EmptyLaboratorySlot(XComGameState NewGameState, StateObjectReference SlotRef)
{
	class'X2StrategyElement_DefaultStaffSlots'.static.EmptyLaboratorySlot(NewGameState, SlotRef);
}

static function string GetLaboratoryBonusDisplayString(XComGameState_StaffSlot SlotState, optional bool bPreview)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_FacilityXCom FacilityState;
	local string Contribution;
	local float PercentIncrease;
	local int UnitSkill, SlotOrder, SciScore;

	FacilityState = SlotState.GetFacility();
	SlotOrder = FacilityState.GetReverseOrderAmongFilledStaffSlots(SlotState, bPreview);

	if (SlotState.IsSlotFilled())
	{
		XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();

		UnitSkill = SlotState.GetMyTemplate().GetContributionFromSkillFn(SlotState.GetAssignedStaff());
		SciScore = XComHQ.GetScienceScore(true);
		SciScore -= SlotOrder * UnitSkill;

		// Need to return the percent increase in overall research speed provided by this unit
		PercentIncrease = (UnitSkill * 100.0) / SciScore;

		if (default.Handicap)
		{
			PercentIncrease = ApplyHandicap(PercentIncrease, FacilityState.StaffSlots.Length);
		}

		Contribution = string(Round(PercentIncrease));
	}

	return class'X2StrategyElement_DefaultStaffSlots'.static.GetBonusDisplayString(SlotState, "%AVENGERBONUS", Contribution);
}

static function bool IsStaffSlotBusyDefault(XComGameState_StaffSlot SlotState)
{
	return !IsRemovingStaffPossible();
}
static function bool CanStaffBeMoved(StateObjectReference SlotRef)
{
	return IsRemovingStaffPossible();
}
static function bool IsRemovingStaffPossible()
{
	local XComGameState_FacilityXCom Facility;

	Facility = `XCOMHQ.GetFacilityByName('Laboratory');

	if (Facility != None)
	{
		// If there currently is a project running in this facility and that emptying this staffslot would mean no staff is left to do the project, do not allow staff to be moved until the player has paused the project
		if ((Facility.BuildQueue.Length > 0) && ((Facility.GetNumFilledStaffSlots() - 1) <= 0))
		{
			return false;
		}
	}	

	return true;
}

static function float ApplyHandicap(float PercentIncrease, int NumSlots)
{
	local float HandicapPerSlot;

	HandicapPerSlot = GetHandicapPerSlot(NumSlots);
	PercentIncrease -= HandicapPerSlot;

	if (PercentIncrease < HandicapPerSlot)
	{
		PercentIncrease = HandicapPerSlot;
	}

	return PercentIncrease;
}
static function float GetHandicapPerSlot(int NumSlots)
{
	return float(default.HandicapAmount / NumSlots);
}

static function float GetCurrentHandicap()
{
    local float TotalHandicap, HandicapPerSlot;
    local XComGameState_FacilityXCom Facility;
	local XComGameState_StaffSlot StaffSlot;
	local XComGameState_Unit Staff;
	local int i;

    if (class'X2DownloadableContentInfo_LaboratoryAlreadyBetterFixed'.default.Handicap)
    {
		Facility = `XCOMHQ.GetFacilityByName('Laboratory');

		if (Facility != none)
		{
			HandicapPerSlot = GetHandicapPerSlot(Facility.StaffSlots.Length);

			for (i = 0; i < Facility.StaffSlots.Length; i++)
			{
				StaffSlot = Facility.GetStaffSlot(i);

				if (StaffSlot != none)
				{
					if (StaffSlot.IsSlotFilled())
					{
						Staff = StaffSlot.GetAssignedStaff();
						TotalHandicap += ApplyHandicap(float(Staff.GetSkillLevel()), Facility.StaffSlots.Length);
					}
					else
					{
						// There is a slot but it's empty, apply handicap penalty to total handicap
						TotalHandicap -= HandicapPerSlot;
					}
				}
			}

			TotalHandicap = (100 - abs(TotalHandicap));      
			
			return TotalHandicap;
		}
	}
	
	return 0;
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
	local LaboratoryProject LaboratoryProject;
	local HQEvent Event;
	local int i, ProjectHours;
	local XComGameState_FacilityXCom Laboratory;
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;

	History = `XCOMHISTORY;
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ(true);
	Laboratory = XComHQ.GetFacilityByName('Laboratory');

	if (Laboratory != none)
	{
		for (i = 0; i < Laboratory.BuildQueue.Length; i++)
		{
			LaboratoryProject = LaboratoryProject(History.GetGameStateForObjectID(Laboratory.BuildQueue[i].ObjectID));

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
			Event.Data = Tech.GetMyTemplate().DisplayName;
			Event.ImagePath = class'UIUtilities_Image'.const.EventQueue_Science;
			Events.AddItem(Event);
		}
	}
}
