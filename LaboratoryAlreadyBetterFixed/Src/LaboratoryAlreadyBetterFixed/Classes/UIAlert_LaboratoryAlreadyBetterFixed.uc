//---------------------------------------------------------------------------------------
//  FILE:    UIAlert_DLC_Day60.uc
//  AUTHOR:  Joe Weinhoffer
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class UIAlert_LaboratoryAlreadyBetterFixed extends UIAlert;

var public localized string m_strTitleLabelComplete;

simulated function BuildAlert()
{
	BindLibraryItem();

	switch ( eAlertName )
	{
	case 'eAlert_LaboratoryResearchComplete':
		BuildLaboratoryResearchCompleteAlert();
		break;		
	default:
		AddBG(MakeRect(0, 0, 1000, 500), eUIState_Normal).SetAlpha(0.75f);
		break;
	}

	// Set  up the navigation *after* the alert is built, so that the button visibility can be used. 
	RefreshNavigation();
}

simulated function Name GetLibraryID()
{
	//This gets the Flash library name to load in a panel. No name means no library asset yet. 
	switch ( eAlertName )
	{
	case 'eAlert_LaboratoryResearchComplete':				return 'Alert_Complete';
	
	default:
		return '';
	}
}

simulated function BuildLaboratoryResearchCompleteAlert()
{
	local XComGameStateHistory History;
	local XComGameState_Tech TechState;
	local XComGameState_WorldRegion RegionState;
	local TAlertCompletedInfo kInfo;
	local XGParamTag ParamTag;

	History = `XCOMHISTORY;
	TechState = XComGameState_Tech(History.GetGameStateForObjectID(
		class'X2StrategyGameRulesetDataStructures'.static.GetDynamicIntProperty(DisplayPropertySet, 'TechRef')));

	kInfo.strName = TechState.GetDisplayName();
	kInfo.strHeaderLabel = m_strTitleLabelComplete;
	kInfo.strBody = m_strResearchProjectComplete;

	if (TechState.GetMyTemplate().UnlockedDescription != "")
	{
		ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));

		// Datapads
		if (TechState.IntelReward > 0)
		{
			ParamTag.StrValue0 = string(TechState.IntelReward);
		}

		// Facility Leads
		if (TechState.RegionRef.ObjectID != 0)
		{
			RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(TechState.RegionRef.ObjectID));
			ParamTag.StrValue0 = RegionState.GetDisplayName();
		}

		kInfo.strBody $= "\n" $ `XEXPAND.ExpandString(TechState.GetMyTemplate().UnlockedDescription);
	}

	kInfo.strConfirm = m_strAssignNewResearch;
	kInfo.strCarryOn = m_strCarryOn;
	kInfo.strImage = TechState.GetImage();
	kInfo = FillInTyganAlertComplete(kInfo);
	kInfo.eColor = eUIState_Warning;
	kInfo.clrAlert = MakeLinearColor(0.75, 0.75, 0.0, 1);

	BuildCompleteAlert(kInfo);
}