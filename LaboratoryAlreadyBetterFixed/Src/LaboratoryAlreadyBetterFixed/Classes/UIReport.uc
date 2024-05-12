class UIReport extends UIScreen;
// Modified from UIResearchReport

var public localized string m_strCodename;
var public localized string m_strTopSecret;
var public localized string m_strResearchReport;

var name DisplayTag;
var name CameraTag;

var public bool bInstantInterp;

var UILargeButton ContinueButton;
var XComGameState_FacilityXCom Facility;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);
	UpdateNavHelp();

	class'UIUtilities'.static.DisplayUI3D(DisplayTag, CameraTag, 0.0f);

    SetTimer(0.1f, false, nameof(HideRoomContainer));
    InitResearchReport();
}

simulated function UpdateNavHelp()
{
	local UINavigationHelp NavHelp;

	NavHelp = `HQPRES.m_kAvengerHUD.NavHelp;
	NavHelp.ClearButtonHelp();
	NavHelp.AddBackButton(CloseScreen);
	NavHelp.Show();
}

simulated function HideRoomContainer()
{
    local UIFacility_Labs UIFacility_Labs;

    UIFacility_Labs = UIFacility_Labs(`SCREENSTACK.GetScreen(class'UIFacility_Labs'));
    UIFacility_Labs.m_kRoomContainer.Hide();
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();
	`HQPRES.m_kAvengerHUD.NavHelp.ClearButtonHelp();
	UIMovie_3D(Movie).HideDisplay(DisplayTag);
}

simulated function CloseScreen()
{
	`HQPRES.m_kAvengerHUD.NavHelp.ClearButtonHelp();
	super.CloseScreen();
}

simulated function InitResearchReport()
{
	local int i;
	local string Unlocks;
	local array<String> arrStrings;
	local XComGameStateHistory History;
	local XComGameState_Tech Tech;
	local XComGameState_WorldRegion RegionState;
	local array<StateObjectReference> arrNewTechs;
	local array<StateObjectReference> arrNewInstantTechs;
	local array<StateObjectReference> arrNewBreakthroughTechs;
	local array<StateObjectReference> arrNewInspiredTechs;
	local array<StateObjectReference> arrNewProjects;
	local array<X2ItemTemplate> arrNewItems;
	local array<X2FacilityTemplate> arrNewFacilities;
	local array<X2FacilityUpgradeTemplate> arrNewUpgrades;
	local XGParamTag ParamTag;
	local LaboratoryProject LaboratoryProject;
	local XComGameState NewGameState;
    
	class'UIUtilities_Sound'.static.PlayOpenSound();

	History = `XCOMHISTORY;
	Facility = `XCOMHQ.GetFacilityByName('Laboratory');

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("UIReport.InitResearchReport");

    LaboratoryProject = LaboratoryProject(History.GetGameStateForObjectID(Facility.BuildQueue[0].ObjectID));
	Tech = XComGameState_Tech(NewGameState.ModifyStateObject(class'XComGameState_Tech', LaboratoryProject.ProjectFocus.ObjectID));
    // Prevents the report cards from also popping up in the main research facility
	Tech.bSeenResearchCompleteScreen = true;

	// Unlocks--------------------------------------------------------------------
	Tech.GetMyTemplate().GetUnlocks(arrNewTechs, arrNewProjects, arrNewItems, arrNewFacilities, arrNewUpgrades, arrNewInstantTechs, arrNewBreakthroughTechs, arrNewInspiredTechs);

	// Items
	arrStrings = class'UIAlert'.static.GetItemUnlockStrings(arrNewItems);
	for( i = 0; i < arrStrings.Length; i++ )
	{
		Unlocks $= arrStrings[i];
		if(i < arrStrings.Length - 1)
			Unlocks $= "\n";
	}
	// Facilities
	arrStrings = class'UIAlert'.static.GetFacilityUnlockStrings(arrNewFacilities);
	if(arrStrings.Length > 0 && Unlocks != "") Unlocks $= "\n";
	for( i = 0; i < arrStrings.Length; i++ )
	{
		Unlocks $= arrStrings[i];
		if(i < arrStrings.Length - 1)
			Unlocks $= "\n";
	}
	// Facility Upgrades
	arrStrings = class'UIAlert'.static.GetUpgradeUnlockStrings(arrNewUpgrades);
	if(arrStrings.Length > 0 && Unlocks != "") Unlocks $= "\n";
	for (i = 0; i < arrStrings.Length; i++)
	{
		Unlocks $= arrStrings[i];
		if(i < arrStrings.Length - 1)
			Unlocks $= "\n";
	}
	// Techs
	arrStrings = class'UIAlert'.static.GetResearchUnlockStrings(arrNewTechs);
	if(arrStrings.Length > 0 && Unlocks != "") Unlocks $= "\n";
	for( i = 0; i < arrStrings.Length; i++ )
	{
		Unlocks $= arrStrings[i];
		if(i < arrStrings.Length - 1)
			Unlocks $= "\n";
	}
	// Proving Ground Projects
	arrStrings = class'UIAlert'.static.GetProjectUnlockStrings(arrNewProjects);
	if(arrStrings.Length > 0 && Unlocks != "") Unlocks $= "\n";
	for (i = 0; i < arrStrings.Length; i++)
	{
		Unlocks $= arrStrings[i];
		if(i < arrStrings.Length - 1)
			Unlocks $= "\n";
	}

	if (Tech.GetMyTemplate().UnlockedDescription != "")
	{
		if (Unlocks != "") Unlocks $= "\n";

		ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));

		// Datapads
		if (Tech.IntelReward > 0)
		{
			ParamTag.StrValue0 = string(Tech.IntelReward);
		}

		// Facility Leads
		if (Tech.RegionRef.ObjectID != 0)
		{
			RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(Tech.RegionRef.ObjectID));
			ParamTag.StrValue0 = RegionState.GetDisplayName();
		}

		Unlocks $= `XEXPAND.ExpandString(Tech.GetMyTemplate().UnlockedDescription);
	}

	AS_UpdateResearchReport(
		m_strResearchReport, 
		class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS( Tech.GetDisplayName() ),
		m_strCodename @ Tech.GetCodeName(),
		class'X2StrategyGameRulesetDataStructures'.static.GetDateString( Tech.CompletionTime ),
		Tech.GetImage(),
		Unlocks,
		Tech.GetLongDescription(),
		m_strTopSecret);

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

simulated function AS_UpdateResearchReport(string header, string project, string code, string date, string image, string unlocks, string description, string greeble)
{
	MC.BeginFunctionOp("UpdateResearchReport");
	MC.QueueString(header);
	MC.QueueString(project);
	MC.QueueString(code);
	MC.QueueString(date);
	MC.QueueString(image);
	MC.QueueString(unlocks);
	MC.QueueString(description);
	MC.QueueString(greeble);
	MC.EndOp();
}

//============================================================================== 

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
    {
		return false;
    }

	bHandled = true;

	switch (cmd)
	{
		case class'UIUtilities_Input'.const.FXS_BUTTON_B:
		case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
		case class'UIUtilities_Input'.const.FXS_BUTTON_A: 
		case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
		case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR:
			CloseScreen();
        	`SCREENSTACK.Push(`HQPRES.Spawn(class'UILaboratory', `HQPRES), `HQPRES.Get3DMovie());
			break;
		default:
			bHandled = false;
			break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}


//==============================================================================

defaultproperties
{
	DisplayTag      = "UIBlueprint_Camera_1";
	CameraTag       = "UIBlueprint_Camera_1";

	Package = "/ package/gfxResearchReport/ResearchReport";
	InputState = eInputState_Evaluate;
	bAnimateOnInit = true;
}
