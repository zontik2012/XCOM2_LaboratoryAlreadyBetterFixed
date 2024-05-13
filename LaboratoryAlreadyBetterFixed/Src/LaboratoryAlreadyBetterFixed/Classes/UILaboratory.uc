class UILaboratory extends UIScreen config(Game);

var config float ZoomInTime;
var config bool ShowResearchUnlocks;
var config bool ShowLockedTech;
var config bool ShowCompletedTech;
var config bool ShowLockedTechBreakthrough;
var config array<name> DisableTech;

var localized string m_strTitle;
var localized string m_strStart;
var localized string m_strPause;
var localized string m_strResume;
var localized string m_strInProgress;
var localized string m_strAlreadyCompleted;
var localized string m_strRequirementsNotMet;
var localized string ToggleQueue;

var localized string m_strRewardsTitle;
var localized string m_strRewardsEmpty;
var localized string m_strRewardsPossible;
var localized string m_strRewardsPartial;
var localized string m_strRewardsUnknown;

var name DisplayTag;
var name CameraTag;

var XComGameStateHistory History;
var XComGameState_HeadquartersXCom XComHQ;

var UIList Research_List;
var UIBGBox Research_ListBG;

var UIItemCard ItemCard;

var UIBGBox RewardBG;
var UIPanel Reward;
var UIX2PanelHeader TitleHeader;
var UITextContainer Description;

//custom struct for unlocks
struct UnlockedItems_Orig
{
	var name ItemType;
	var string Unlock;
    var bool isPartial;
    var string ItemImage;
    var bool isRewardDeck;
    var bool bHide;
};

//easy strings for the icons
var string ItemIcon, FacilityIcon, FacilityUpgradeIcon, ResearchIcon, ProvingGroundIcon, ShadowIcon, PsiIcon, ErrorIcon;

var int ConfirmButtonX;
var int ConfirmButtonY;

// Used as buffers where headers would be
var Commodity Dummy;
var XComGameState_Tech Dummy_Tech;

var array<Commodity> Research_Com;
var array<XComGameState_Tech> Research_Tech;

var XComGameState_FacilityXCom FacilityState;

var bool UserQueueToggleState;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	History = `XCOMHISTORY;
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ(true);
	FacilityState = XComHQ.GetFacilityByName('Laboratory');

    DisablePackagePanels();

	BuildScreen();
    UpdateNavHelp();
    UpdateList();
	DoToggleQueue();

    // Once the UI has fully stopped moving, first then do we want to show the resources panel
    SetTimer(1.0f, false, nameof(UpdateResources));
    SetTimer(1.5f, false, nameof(ShowResources));
}

simulated function UpdateResources()
{
    `HQPRES.m_kAvengerHUD.UpdateIntel();
    `HQPRES.m_kAvengerHUD.UpdateEleriumCrystals();
    `HQPRES.m_kAvengerHUD.UpdateAlienAlloys();
    `HQPRES.m_kAvengerHUD.UpdateScientistScore();
    `HQPRES.m_kAvengerHUD.UpdateEngineerScore();
}
// Has to be split from UpdateResources otherwise it will get duplicated everytime that function is called
simulated function ShowResources()
{
    `HQPRES.m_kAvengerHUD.ResourceContainer.Show();
}
simulated function BuildScreen()
{
	TitleHeader = Spawn(class'UIX2PanelHeader', self);
	TitleHeader.InitPanelHeader('Header', m_strTitle);
	TitleHeader.SetHeaderWidth(1540);
    TitleHeader.SetPosition(200, 65);

	Research_ListBG = Spawn(class'UIBGBox', self);
    Research_ListBG.LibID = class'UIUtilities_Controls'.const.MC_X2Background;
    Research_ListBG.InitBG('Research_ListBG', 185, 110, 500, 820);
	Research_ListBG.bShouldPlayGenericUIAudioEvents = false;

	Research_List = Spawn(class'UIList', self);
    Research_List.InitList('Research_List', (Research_ListBG.X + 10), (Research_ListBG.Y + 12), (Research_ListBG.Width - 40), (Research_ListBG.Height - 25));
	Research_List.bSelectFirstAvailable = true;
	Research_List.bStickyHighlight = true;
	Research_List.OnSelectionChanged = OnItemSelectedCallback;
	Research_List.OnItemDoubleClicked = Research_List_OnPurchaseClicked;		
	Navigator.SetSelected(Research_List);
    
    // if (`ISCONTROLLERACTIVE)
    // {
    //     Research_List.OnItemClicked = OnItemSelectedCallback;
    // }

	ItemCard = Spawn(class'UIItemCard', self);
    ItemCard.InitItemCard('PreviewCard');
    ItemCard.SetPosition(690, 112);

	// send mouse scroll events to the list
	Research_ListBG.ProcessMouseEvents(Research_List.OnChildMouseEvent);

    if (default.ShowResearchUnlocks)
    {
        BuildResearchUnlocks();
    }

	class'UIUtilities'.static.DisplayUI3D(DisplayTag, CameraTag, ZoomInTime);
}

simulated function UpdateNavHelp()
{
	local UINavigationHelp NavHelp;

	NavHelp = `HQPRES.m_kAvengerHUD.NavHelp;

	NavHelp.ClearButtonHelp();
	NavHelp.bIsVerticalHelp = `ISCONTROLLERACTIVE;
	NavHelp.AddBackButton(CloseScreen);

	if(`ISCONTROLLERACTIVE)
	{
		NavHelp.AddSelectNavHelp();
		NavHelp.AddLeftHelp(ToggleQueue, class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
	}
	else
	{
		NavHelp.AddLeftHelp(ToggleQueue, , DoToggleQueueButton);
	}
}

simulated function OnItemSelectedCallback(UIList ContainerList, int ItemIndex)
{
    local StateObjectReference ItemRef;

    ItemRef = Research_Tech[ItemIndex].GetReference();

    if (ItemRef.ObjectID > 0)
    {
        ItemCard.PopulateSimpleCommodityCard(Research_Com[ItemIndex], ItemRef);

        if (default.ShowResearchUnlocks)
        {
            UpdateRewardText();
        }
    }
}

simulated function BuildResearchUnlocks()
{
    //setup the new panel and common icons as strings, inject image, (image path, width, hieght, vertical offset)
    ItemIcon =              class'UIUtilities_Text'.static.InjectImage("img:///UILibrary_XPACK_StrategyImages.MissionIcon_SupplyDrop",  20, 20, -5); //the only one NOT referrenced in UIUtilities_Image
    ResearchIcon =          class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.AlertIcon_Science,                20, 20, -5); //techs
    ProvingGroundIcon =     class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.AlertIcon_Construction,           20, 20, -5);
    ShadowIcon =            class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_AttentionIcon,               20, 20, -5);
    FacilityIcon =          class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.AlertIcon_Engineering,            20, 20, -5);
    FacilityUpgradeIcon =   class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.FacilityStatus_Power,             20, 20, -5);
    PsiIcon =               class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.EventQueue_Psi,                   20, 20, -5);
    ErrorIcon =             class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.EventQueue_Alien,                 20, 20, -5); //used for quick identifiction of errors

    RewardBG = Spawn(class'UIBGBox', self);
    RewardBG.LibID = class'UIUtilities_Controls'.const.MC_X2Background;
    RewardBG.InitBG('ShowResearchUnlocks-Reward-BG', 1255, 110, 500, 820);

    Reward = Spawn(class'UIPanel', self);
    Reward.InitPanel('ShowResearchUnlocks-Reward');
    Reward.SetSize(RewardBG.Width, RewardBG.Height);
    Reward.SetPosition(RewardBG.X, RewardBG.Y);

    TitleHeader = Spawn(class'UIX2PanelHeader', Reward);
    TitleHeader.InitPanelHeader('', class'UIUtilities_Text'.static.GetColoredText(m_strRewardsTitle, eUIState_Cash, 32), "");
    TitleHeader.SetPosition(TitleHeader.X + 10, TitleHeader.Y + 10);
    TitleHeader.SetHeaderWidth(Reward.Width - 20);

    Description = Spawn(class'UITextContainer', Reward);
    Description.InitTextContainer();
    Description.bAutoScroll = true;
    Description.SetSize(RewardBG.Width - 20, RewardBG.Height - 55);
    Description.SetPosition(Description.X + 10, Description.Y + 50);

    Description.Text.SetHeight(Description.Text.Height * 7.0f);

    UpdateRewardText();
}

simulated function UpdateRewardText()
{
  	local XComGameState_Tech Tech;
    local X2TechTemplate TechTemplate;
    local array<UnlockedItems_Orig> UnlockedItems;
	local string Unlocks;
    local int i;

    i = Research_List.SelectedIndex;
	Tech = Research_Tech[i];
    
    if (Tech != none)
    {
        TechTemplate = Tech.GetMyTemplate();

        //work out what it unlocks
        CustomGetUnlocks(TechTemplate, UnlockedItems);

        //create the message array string  
        MessageArray(Unlocks, UnlockedItems);

        //change the description in the reward list        
        Description.SetText(class'UIUtilities_Text'.static.AddFontInfo(Unlocks, false, false, false, 22) );
    }
}

///////////////////////////////////////////////////////////////////////////////
//  INFORMATION GATHERING
///////////////////////////////////////////////////////////////////////////////

// work out what the selected item unlocks
static function CustomGetUnlocks(X2TechTemplate TemplateToUpdate, out array<UnlockedItems_Orig> UnlockedItems)
{
    local X2ItemTemplateManager             ItemTemplateManager;
    local X2StrategyElementTemplateManager  TemplateManager;

    local X2DataTemplate                    DataTemplate;
    local X2ItemTemplate                    ItemTemplate, Tier2Template, Tier3Template;	
    local X2TechTemplate                    TechTemplate;
    local X2FacilityTemplate                FacilityTemplate;
    local X2FacilityUpgradeTemplate         FacilityUpgTemplate;     
    local X2SchematicTemplate               SchematicTemplate;    

	local array<name>                       TemplateNames;
    local name                              TemplateName;
    local int                               i;

    local UnlockedItems_Orig UnlockedItem;
    
    ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
    TemplateManager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

	TemplateManager.GetTemplateNames(TemplateNames);       

    //for techs, research, proving ground, facility schematics
    foreach TemplateNames(TemplateName)
	{
        //Research Techs and Proving Grounds are covered here
        TechTemplate = X2TechTemplate(TemplateManager.FindStrategyElementTemplate(TemplateName));
        if ( TechTemplate != None )             
        {                
            if (TechTemplate.Requirements.RequiredTechs.Find(TemplateToUpdate.DataName) != INDEX_NONE)
            {
                // skip over breakthroughs and remove techs that have already been completed and techs to be hidden based on config DisabledTechs
                if (TechTemplate.bBreakthrough || `XCOMHQ.IsTechResearched(TechTemplate.DataName))
                {
                    continue; //move on to the next item
                }
                else
                {
                    if ( TechTemplate.bProvingGround )      {   UnlockedItem.ItemType = 'PG';       }
                    else if (TechTemplate.bShadowProject)   {   UnlockedItem.ItemType = 'Shadow';   }
                    else                                    {   UnlockedItem.ItemType = 'Tech';     }

                    UnlockedItem.Unlock = TechTemplate.DisplayName;
                    UnlockedItem.isRewardDeck = false;                    

                    //found out if the item requires more stuff than this tech
                    UnlockedItem.isPartial = IsPartialUnlock(TemplateToUpdate.DataName, TechTemplate.Requirements.RequiredTechs);

                    //add it to the OUT array
                    UnlockedItems.AddItem(UnlockedItem);
                    
                    continue; //move on to the next item

                }
            }
        }//end tech != none

        // it wasn't a 'tech' (research/shadow/PG/breakthrough) ... not already done ... so must be a facility
        //check for a facility
        FacilityTemplate = X2FacilityTemplate(TemplateManager.FindStrategyElementTemplate(TemplateName));
        if ( FacilityTemplate != none )
        {
            if(FacilityTemplate.Requirements.RequiredTechs.Find(TemplateToUpdate.DataName) != INDEX_NONE )
            {
                UnlockedItem.ItemType = 'Facility';
                UnlockedItem.Unlock = FacilityTemplate.DisplayName;
                UnlockedItem.isRewardDeck = false;                

                //found out if the item requires more stuff than this tech
                UnlockedItem.isPartial = IsPartialUnlock(TemplateToUpdate.DataName, FacilityTemplate.Requirements.RequiredTechs);
                
                //add it to the OUT array
                UnlockedItems.AddItem(UnlockedItem);
                continue; //move on to the next item
            }
        }//end facility !=none

        //wasn't a facility, must be a facility upgrade
        FacilityUpgTemplate = X2FacilityUpgradeTemplate(TemplateManager.FindStrategyElementTemplate(TemplateName));
        if ( FacilityUpgTemplate != none )
        {
            if(FacilityUpgTemplate.Requirements.RequiredTechs.Find(TemplateToUpdate.DataName) != INDEX_NONE )
            {
                UnlockedItem.ItemType = 'FacilityUpgrade';
                UnlockedItem.Unlock = FacilityUpgTemplate.DisplayName;
                UnlockedItem.isRewardDeck = false;                             

                //found out if the item requires more stuff than this tech
                UnlockedItem.isPartial = IsPartialUnlock(TemplateToUpdate.DataName, FacilityUpgTemplate.Requirements.RequiredTechs);
                
                //add it to the OUT array
                UnlockedItems.AddItem(UnlockedItem);
                continue; //move on to the next item
            }
        }//end fac upgrade !=none
    }//end strategy templates check

    // For items and schematics
    foreach ItemTemplateManager.IterateTemplates(DataTemplate, none)
    {
        ItemTemplate = X2ItemTemplate(DataTemplate);

        if (ItemTemplate != none)
        {
            UnlockedItem.ItemType = 'Item';
            
            // if ( default.bObfuscateIfNotFound && default.arrItemToObfuscate.Find(ItemTemplate.DataName) != -1)
            // {
            //     //try to find if xcom has ever had or has the item in question
            //     //by type, unlocked, current inventory, by state/quantity recorded at least once (even if current is 0)
            //     if  (   `XCOMHQ.EverAcquiredInventoryTypes.Find(ItemTemplate.DataName) != INDEX_NONE
            //         ||  `XCOMHQ.UnlockedItems.Find(ItemTemplate.DataName) != INDEX_NONE
            //         ||  `XCOMHQ.HasItem(ItemTemplate)
            //         ||  `XCOMHQ.GetNumItemInInventory(ItemTemplate.DataName) > 0
            //         ||  `XCOMHQ.GetItemByName(ItemTemplate.DataName) != none
            //         )
            //     {
            //         UnlockedItem.bHide = false;
            //     }
            //     else
            //     {
            //         UnlockedItem.bHide = true;
            //     }
            // }
            // else    //not an item to obfuscate
            // {
            //   UnlockedItem.bHide = false;
            // }

            if (ItemTemplate.Requirements.RequiredTechs.Find(TemplateToUpdate.DataName) != INDEX_NONE
                || ItemTemplate.ArmoryDisplayRequirements.RequiredTechs.Find(TemplateToUpdate.DataName) != INDEX_NONE
                || ItemTemplate.CreatorTemplateName == TemplateToUpdate.DataName
               )
            {
                //for item schematic templates
                SchematicTemplate = X2SchematicTemplate(DataTemplate);
                if (SchematicTemplate != none)
                {   
                    // I think this block of code does't use ItemTemplate anymore, so let's use it
                    ItemTemplate = ItemTemplateManager.FindItemTemplate(SchematicTemplate.ReferenceItemTemplate);                                
                    
                    UnlockedItem.Unlock = SchematicTemplate.GetItemFriendlyName();
                    UnlockedItem.isRewardDeck = false;                    

                    //found out if the item requires more stuff than this tech
                    UnlockedItem.isPartial = IsPartialUnlock(TemplateToUpdate.DataName, ItemTemplate.Requirements.RequiredTechs);

					//this should stop any 'empty' schematics from being added ... thanks Iridar!
					// if (SchematicTemplate.ItemsToUpgrade.Length != 0 && SchematicTemplate.ItemRewards.Length != 0) // This one skipped COTK2.0 schematics
                    // This should do it - refer to PATemplateMods::KillItem from "Prototype Armoury Beta"
                    if (SchematicTemplate.CanBeBuilt != false && SchematicTemplate.PointsToComplete < 999999)
					{
						//add it to the OUT array
						UnlockedItems.AddItem(UnlockedItem);
                    }
                    continue; //move on to the next item in the list
                }
                //normal item directly unlocked
                else
                {
                    UnlockedItem.Unlock = ItemTemplate.GetItemFriendlyNameNoStats();
                    UnlockedItem.isRewardDeck = false;                    

                    //found out if the item requires more stuff than this tech
                    UnlockedItem.isPartial = IsPartialUnlock(TemplateToUpdate.DataName, ItemTemplate.Requirements.RequiredTechs);

                    //add it to the OUT array
                    UnlockedItems.AddItem(UnlockedItem);

                    continue; //move on to the next item in the list
                }            
            }
            //item is part of a reward deck
            else if (ItemTemplate.RewardDecks.Find(TemplateToUpdate.RewardDeck) != INDEX_NONE )
            {
                // Check if the item list should be shown as the upgraded version of the items
                // Example: Experimental Grenade projects that should show Acid Bomb instead of Acid Grenade if AdvancedGrenade Tech has been researched
                Tier2Template = ItemTemplateManager.GetUpgradedItemTemplateFromBase(ItemTemplate.DataName);            
                Tier3Template = ItemTemplateManager.GetUpgradedItemTemplateFromBase(Tier2Template.DataName);

                if (Tier2Template != none && `XCOMHQ.IsTechResearched(Tier2Template.CreatorTemplateName))
                {
                    ItemTemplate = Tier2Template;   //eg showing Acid Bomb instead of Grenade if Advanced Explosives is done
                }

                if (Tier3Template != none && `XCOMHQ.IsTechResearched(Tier3Template.CreatorTemplateName))
                {
                    ItemTemplate = Tier3Template;   //eg showing Acid Warhead instead of Bomb/Grenade if Superior Explosives is done
                }                

                UnlockedItem.Unlock = ItemTemplate.GetItemFriendlyNameNoStats();
                UnlockedItem.isRewardDeck = true; // Will always show as a possible item reward, finally                

                UnlockedItem.isPartial = false; // For experimental items, we pretend that it will never be partial and we will always get one of the items
            
                //add it to the OUT array
                UnlockedItems.AddItem(UnlockedItem);

                continue; //move on to the next item in the list
            }
        } //end item template !=none
    } // end item templates check

    // Tech Templates that give items directly e.g. IcarusArmor tech template gives MediumAlienArmor
    if (TemplateToUpdate.ItemRewards.Length > 0)
    {
        for ( i = 0; i < TemplateToUpdate.ItemRewards.Length; i++)
        {
            ItemTemplate = ItemTemplateManager.FindItemTemplate(TemplateToUpdate.ItemRewards[i]);

            if (ItemTemplate != none)
            {
                //check its not already on the list
                if (UnlockedItems.Find('Unlock', ItemTemplate.GetItemFriendlyNameNoStats()) == INDEX_NONE)
                {
                    UnlockedItem.ItemType = 'Item';
                    UnlockedItem.isRewardDeck = false;  //a bit of special case, this one should always be false
                    UnlockedItem.isPartial = false;     //a bit of special case, this one should always be false                    

                    // Need to cater for scenario where the tech gives schematic instead of item
                    SchematicTemplate = X2SchematicTemplate(ItemTemplate);
                    if (SchematicTemplate != none) //example: Bolt Caster Tech gives Bolt Caster Schematic
                    {
                        UnlockedItem.Unlock = SchematicTemplate.GetItemFriendlyName();                        
                    }
                    else //example: IcarusArmor tech template gives MediumAlienArmor
                    {
                        UnlockedItem.Unlock = ItemTemplate.GetItemFriendlyNameNoStats();                        
                    }
    
                    //add it to the OUT array as it's not part of it already
                    UnlockedItems.AddItem(UnlockedItem);
                    continue; //move on to the next item
                }
            } //end != none
        } //end for loop
    }//end direct item check

    //THIS would be where MORE SPECIAL LOGIC goes for the case-by-case basis, not required for my PexM listener though
    //Maybe a new config struct for (i ; i < default.arrOverride ; i++)
    //  { // check and do stuff }
    //  add to the OUT array
    //  log
}

//find out if this item requires more than the current tech
static function bool IsPartialUnlock(name ExcludedTech, array<name> RequiredTechs)
{
    local X2StrategyElementTemplateManager StratMgr;
	local X2TechTemplate TechTemplate;
	local int i;
	
	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

	for(i = 0; i < RequiredTechs.Length; i++)
	{
		TechTemplate = X2TechTemplate(StratMgr.FindStrategyElementTemplate(RequiredTechs[i]));

		if(TechTemplate != none && TechTemplate.DataName != ExcludedTech )
		{
			if(!`XCOMHQ.TechTemplateIsResearched(TechTemplate))
			{
                //xcom still needs more techs to unlock this
                return true;
			}
		}
	}
    //xcom does not need more techs to unlock this
	return false;
}

///////////////////////////////////////////////////////////////////////////////
//  STRING FORMATION FOR DISPLAY
///////////////////////////////////////////////////////////////////////////////

//construct the entire unlocks description string ... line by line ...
simulated function MessageArray(out string Unlocks, array<UnlockedItems_Orig> UnlockedItems)
{
    local int i; 

    for( i = 0; i < UnlockedItems.Length; i++)
    {
        //add the correct Icon
        switch ( UnlockedItems[i].ItemType )
        {
            case 'Item':            Unlocks $= (ItemIcon $ ": ");               break;
            case 'Tech':            Unlocks $= (ResearchIcon $ ": ");           break;
            case 'PG':              Unlocks $= (ProvingGroundIcon $ ": ");      break;
            case 'Shadow':          Unlocks $= (ShadowIcon $ ": ");             break;
            case 'Facility':        Unlocks $= (FacilityIcon $ ": ");           break;
            case 'FacilityUpgrade': Unlocks $= (FacilityUpgradeIcon $ ": ");    break;
            case 'Psi':             Unlocks $= (PsiIcon $ ": ");                break;
            default:                Unlocks $= (ErrorIcon $ ": ");              break;
        }       

        //show or hide the unlock name ... pexm has some special handling for its items, see above
        if ( UnlockedItems[i].bHide )   { Unlocks $= m_strRewardsUnknown;      }
        else                            { Unlocks $= UnlockedItems[i].Unlock;   }

        //append the partial tag if it needs more techs/stuff
        if ( UnlockedItems[i].isPartial )   { Unlocks $= " " $m_strRewardsPartial;     }

        //append the deck tag if it is part of a deck 
        if ( UnlockedItems[i].isRewardDeck ){ Unlocks $= " " $m_strRewardsPossible;    }

        //if we have more lines add a line break
        if(i < UnlockedItems.Length - 1)    { Unlocks $= "\n";                  }
    }

    if (UnlockedItems.Length <= 0 )
    {
        Unlocks $= ShadowIcon $": " $m_strRewardsEmpty;
    }
}

simulated function UpdateList()
{
	local array<XComGameState_Tech> Available, Locked, Completed;
	local XComGameState_Tech TechState;
    local X2TechTemplate TechTemplate;
    local XComGameState_Tech ActiveTech;
	local LaboratoryProject LaboratoryProject;
    local StateObjectReference TechRef;

    if (FacilityState.BuildQueue.Length > 0)
    {
        LaboratoryProject = LaboratoryProject(History.GetGameStateForObjectID(FacilityState.BuildQueue[0].ObjectID));
    }

	foreach History.IterateByClassType(class'XComGameState_Tech', TechState)
	{
        TechTemplate = TechState.GetMyTemplate();

        if (TechTemplate != none && !TechTemplate.bProvingGround && !TechTemplate.bShadowProject)
        {
            if (default.DisableTech.Find(TechTemplate.DataName) == INDEX_NONE)
            {
                TechRef = TechState.GetReference();

                if ((LaboratoryProject != none) && (LaboratoryProject.ProjectFocus.ObjectID == TechRef.ObjectID))
                {
                    ActiveTech = TechState;
                    continue;
                }

                if ((TechTemplate.bRepeatable || !XComHQ.IsTechCurrentlyBeingResearched(TechState)) && XComHQ.IsTechAvailableForResearch(TechRef, false, false))
                {
                    Available.AddItem(TechState);
                }
                else if (XComHQ.GetPausedProject(TechRef) != none)
                {
                    Available.AddItem(TechState);
                }
                else if (XComHQ.TechIsResearched(TechRef))
                {
                    Completed.AddItem(TechState);
                }
                else
                {
                    Locked.AddItem(TechState);
                }
            }
        }
	}

    Research_Com.Length = 0;
    Research_Tech.Length = 0;
	Research_List.ClearItems();

    if (ActiveTech != none)
    {
        AddActiveTech(ActiveTech);
    }

    AddToLists(Available);

    if (default.ShowLockedTech)
    {
        AddToLists(Locked, true, false);
    }
    if (default.ShowCompletedTech)
    {
        AddToLists(Completed, true, true);
    }


	SetSelectedItem();
}

simulated function SetSelectedItem()
{
	local int i;

    for (i = 0; i < Research_Tech.Length; i++)
    {
        if (Research_Tech[i].ObjectID > 0)
        {
            Research_List.SetSelectedIndex(i);
            break;
        }
    }
}

simulated function AddToLists(array<XComGameState_Tech> Techs, optional bool Disabled = false, optional bool Completed = false)
{
    local array<Commodity> Commodities;
    local UIInventory_ListItem ListItem;
    local X2TechTemplate TechTemplate;
    local XComGameState_Tech Tech;
    local int i;
    local UIInventory_HeaderListItem Header;
    local bool First_Research;

    if (Techs.Length <= 0)
    {
        return;
    }

    // We have to remove Breakthroughs here as having them in the pool when sorting slows down the entire GUI
    if (Disabled && !default.ShowLockedTechBreakthrough)
    {
        // Because we're removing items from the list, we have to go through it backwards
        for(i = (Techs.Length - 1); i >= 0; i--)
        {  
            Tech = Techs[i];
            TechTemplate = Tech.GetMyTemplate();  

            if (TechTemplate.bBreakthrough)
            {
                Techs.remove(i, 1);
            }
        }
    }

    Sort(Techs);
    Commodities = TechToCommodity(Techs, Disabled);

    for (i = 0; i < Techs.Length; i++)
    {    
        Tech = Techs[i];
        TechTemplate = Tech.GetMyTemplate();

        if (!First_Research && Disabled)
        {
            First_Research = true;
            Header = Spawn(class'UIInventory_HeaderListItem', Research_List.ItemContainer);
            Header.bIsNavigable = false;

            if (Completed)
            {
                Header.InitHeaderItem(, caps(m_strAlreadyCompleted));
            }
            else
            {
                Header.InitHeaderItem(, caps(m_strRequirementsNotMet));
            }

            Research_Com.AddItem(Dummy);
            Research_Tech.AddItem(Dummy_Tech);
        }

        Research_Com.AddItem(Commodities[i]);
        Research_Tech.AddItem(Tech);
        ListItem = Spawn(class'UIInventory_ListItem', Research_List.ItemContainer);

        ListItem.InitInventoryListCommodity(Commodities[i], Tech.GetReference(), caps(m_strStart), eUIConfirmButtonStyle_Default, ConfirmButtonX, ConfirmButtonY);

        if (Disabled)
        {
            if (Completed)
            {
                ListItem.DisableListItem(m_strAlreadyCompleted);
            }
            else
            {
                ListItem.DisableListItem(m_strRequirementsNotMet);
            }
        }    
        else
        {
            if (!XComHQ.CanAffordCommodity(Commodities[i]) || !XComHQ.MeetsCommodityRequirements(Commodities[i]))
            {
                ListItem.DisableListItem(m_strRequirementsNotMet);
            }
        }    
    }
}
simulated function AddActiveTech(XComGameState_Tech TechState)
{
    local array<Commodity> Commodities;
    local array<XComGameState_Tech> Techs;
    local UIInventory_ListItem ListItem;
    local Commodity Commodity;

    Techs.AddItem(TechState);
    Commodities = TechToCommodity(Techs);
    Commodity = Commodities[0];
    Commodity.Title @= caps(m_strInProgress);

    Research_Com.AddItem(Commodity);
    Research_Tech.AddItem(TechState);

    ListItem = Spawn(class'UIInventory_ListItem', Research_List.ItemContainer);
    ListItem.InitInventoryListCommodity(Commodity, TechState.GetReference(), caps(m_strPause), eUIConfirmButtonStyle_Default, ConfirmButtonX, ConfirmButtonY);
}

simulated function Sort(out array<XComGameState_Tech> Techs)
{
	Techs.Sort(SortByName);
	Techs.Sort(SortProjectsTime);
	Techs.Sort(SortProjectsTier);
	Techs.Sort(SortProjectsPriority);
	Techs.Sort(SortProjectsCanResearch);   
}

simulated function array<Commodity> TechToCommodity(array<XComGameState_Tech> Techs, optional bool Disabled = false)
{
    local array<Commodity> Commodities;
    local Commodity Commodity;
    local XComGameState_Tech Tech;
    local StateObjectReference TechRef;
	local bool bPausedProject;
	local StrategyCost EmptyCost;
	local StrategyRequirement EmptyReqs;

    foreach Techs(Tech)
    {
        TechRef = Tech.GetReference();
        bPausedProject = XComHQ.HasPausedProject(TechRef);
        
        Commodity.Title = Tech.GetDisplayName();

        // We don't want any suffixes if the project is disabled
        if (!Disabled)
        {
            if (bPausedProject)
            {
                Commodity.Title @= class'UIChooseResearch'.default.m_strPaused;
            }
            else if (Tech.bForceInstant)
            {
                Commodity.Title @= class'UIChooseResearch'.default.m_strInstant;
            }
            else if (Tech.bBreakthrough)
            {
                Commodity.Title @= class'UIChooseResearch'.default.m_strBreakthrough;
            }
            else if (Tech.bInspired)
            {
                Commodity.Title @= class'UIChooseResearch'.default.m_strInspired;
            }
        }

        Commodity.Image = Tech.GetImage();
        Commodity.Desc = Tech.GetSummary();
        Commodity.OrderHours = GetResearchHours(TechRef);
        Commodity.bTech = true;

        if (bPausedProject)
        {
            Commodity.Cost = EmptyCost;
            Commodity.Requirements = EmptyReqs;
        }
        else
        {
            Commodity.Cost = Tech.GetMyTemplate().Cost;
            Commodity.Requirements = GetBestStrategyRequirementsForUI(Tech.GetMyTemplate());
            Commodity.CostScalars = XComHQ.ResearchCostScalars;
        }

        Commodities.AddItem(Commodity);
    }

    return Commodities;
}

static function int SortProjectsPriority(XComGameState_Tech A, XComGameState_Tech B)
{
	local XComGameState_Tech TechStateA, TechStateB;

	TechStateA = A;
	TechStateB = B;

	if(TechStateA.IsPriority() && !TechStateB.IsPriority()) return 1;
	else if(!TechStateA.IsPriority() && TechStateB.IsPriority()) return -1;
	else return 0;
}
function int SortProjectsCanResearch(XComGameState_Tech A, XComGameState_Tech B)
{
	local X2TechTemplate TechTemplateA, TechTemplateB;
	local bool CanResearchA, CanResearchB;

	TechTemplateA = A.GetMyTemplate();
	TechTemplateB = B.GetMyTemplate();

	CanResearchA = XComHQ.MeetsRequirmentsAndCanAffordCost(TechTemplateA.Requirements, TechTemplateA.Cost, XComHQ.ResearchCostScalars, 0.0, TechTemplateA.AlternateRequirements);
	CanResearchB = XComHQ.MeetsRequirmentsAndCanAffordCost(TechTemplateB.Requirements, TechTemplateB.Cost, XComHQ.ResearchCostScalars, 0.0, TechTemplateB.AlternateRequirements);

	if (CanResearchA && !CanResearchB) return 1;
	else if (!CanResearchA && CanResearchB) return -1;
    else return 0;
}
simulated function int SortProjectsTime(XComGameState_Tech A, XComGameState_Tech B)
{
	local int HoursA, HoursB;

	HoursA = GetResearchHours(A.GetReference());
	HoursB = GetResearchHours(B.GetReference());

	if (HoursA < HoursB) return 1;
	else if (HoursA > HoursB) return -1;
	else return 0;
}
static function int SortProjectsTier(XComGameState_Tech A, XComGameState_Tech B)
{
	local int TierA, TierB;

	TierA = A.GetMyTemplate().SortingTier;
	TierB = B.GetMyTemplate().SortingTier;

	if (TierA < TierB) return 1;
	else if (TierA > TierB) return -1;
	else return 0;
}

// Copied from UIFacilitySummary
static function int SortByName(XComGameState_Tech A, XComGameState_Tech B)
{
	local string NameA, NameB;

	NameA = A.GetMyTemplate().DisplayName;
	NameB = B.GetMyTemplate().DisplayName;

	if(NameA < NameB) return 1;
	else if(NameA > NameB) return -1;
	else return 0;
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

simulated function PlayNegativeSound()
{
	class'UIUtilities_Sound'.static.PlayNegativeSound();
}
simulated function PlaySound_ResearchConfirm()
{
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("ResearchConfirm");
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
    {
		return false;
    }

	switch(cmd)
	{
		case class'UIUtilities_Input'.const.FXS_BUTTON_A:
		case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
			OnPurchaseClicked();
			bHandled = true;
			break;
		case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
		case class'UIUtilities_Input'.const.FXS_BUTTON_B:
			CloseScreen();
			bHandled = true;
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_START:
			`HQPRES.UIPauseMenu( , true);
			bHandled = true;
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_Y:
		case class'UIUtilities_Input'.const.FXS_KEY_TAB:
			UserQueueToggleState = !UserQueueToggleState;
			DoToggleQueue();
			bHandled = true;
			break;
	}

	if (bHandled)
	{
		return true;
	}

	return super.OnUnrealCommand(cmd, arg);
}

simulated function Research_List_OnPurchaseClicked(UIList kList, int itemIndex)
{
	OnPurchaseClicked();
}

simulated function OnPurchaseClicked()
{
	local XComGameState_HeadquartersProjectResearch ResearchProject;
    local XComGameState_Tech Tech;
    local int i;

    i = Research_List.SelectedIndex;
    Tech = Research_Tech[i];

    if ((Tech.ObjectID > 0) && (FacilityState.HasStaff()))
    {
        if (IsActiveTech(Tech))
        {
            PlaySound_ResearchConfirm();
            // The tech is actively being researched in this facility, pause it
            PauseTech();    
            UpdateList();     
            DoToggleQueue();
        }
        else
        {
            ResearchProject = XComHQ.GetPausedProject(Tech.GetReference());

            if (ResearchProject != none)
            {
                PlaySound_ResearchConfirm();
                ResumeProject(ResearchProject);
                UpdateList();
                DoToggleQueue();
            }
            else if (XComHQ.CanAffordCommodity(Research_Com[i]) && XComHQ.MeetsCommodityRequirements(Research_Com[i]))
            {
                PlaySound_ResearchConfirm();
                StartProject(Tech);
                UpdateList();
                DoToggleQueue();
            }        
        }
    }
	else
	{
		PlayNegativeSound();
	}
}

simulated function ResumeTech(XComGameState_Tech Tech)
{
	local XComGameState_HeadquartersProjectResearch ResearchProject;
    local StateObjectReference TechRef;

    TechRef = Tech.GetReference();
    ResearchProject = XComHQ.GetPausedProject(TechRef);

    if (ResearchProject != none)
    {
        ResumeProject(ResearchProject);
    }
}
simulated function ResumeProject(XComGameState_HeadquartersProjectResearch ResearchProject)
{
	local XComGameState NewGameState;
	local LaboratoryProject LaboratoryProject;

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("UILaboratory.ResumeProject");
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
    FacilityState = XComGameState_FacilityXCom(NewGameState.ModifyStateObject(class'XComGameState_FacilityXCom', FacilityState.ObjectID));
    FacilityState.BuildQueue.Length = 0;

    ResearchProject = XComGameState_HeadquartersProjectResearch(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersProjectResearch', ResearchProject.ObjectID));
    ResearchProject.bForcePaused = false;      
	LaboratoryProject = LaboratoryProject(NewGameState.CreateNewStateObject(class'LaboratoryProject'));
    class'LaboratoryProject'.static.Import(LaboratoryProject, ResearchProject);
    FacilityState.BuildQueue.AddItem(LaboratoryProject.GetReference());
    XComHQ.Projects.RemoveItem(ResearchProject.GetReference());
    XComHQ.Projects.AddItem(LaboratoryProject.GetReference());
    NewGameState.RemoveStateObject(ResearchProject.ObjectID);

    `XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
}
simulated function PauseTech()
{
    PauseProject(GetActiveProject());
}
simulated function PauseProject(LaboratoryProject LaboratoryProject)
{
	local XComGameState NewGameState;
    local XComGameState_HeadquartersProjectResearch ResearchProject;

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("UILaboratory.PauseProject");
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
    FacilityState = XComGameState_FacilityXCom(NewGameState.ModifyStateObject(class'XComGameState_FacilityXCom', FacilityState.ObjectID));
    FacilityState.BuildQueue.Length = 0;

    LaboratoryProject = LaboratoryProject(NewGameState.ModifyStateObject(class'LaboratoryProject', LaboratoryProject.ObjectID));
    LaboratoryProject.bForcePaused = true;      
	ResearchProject = XComGameState_HeadquartersProjectResearch(NewGameState.CreateNewStateObject(class'XComGameState_HeadquartersProjectResearch'));
    class'LaboratoryProject'.static.Export(LaboratoryProject, ResearchProject);
    XComHQ.Projects.RemoveItem(LaboratoryProject.GetReference());
    XComHQ.Projects.AddItem(ResearchProject.GetReference());
    NewGameState.RemoveStateObject(LaboratoryProject.ObjectID);

    `XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
}
simulated function LaboratoryProject GetActiveProject()
{
    if (FacilityState.BuildQueue.Length > 0)
    {
		return LaboratoryProject(History.GetGameStateForObjectID(FacilityState.BuildQueue[0].ObjectID));
    }

    return none;
}
simulated function bool IsActiveTech(XComGameState_Tech Tech)
{
    local LaboratoryProject LaboratoryProject;

    LaboratoryProject = GetActiveProject();

    if ((LaboratoryProject != none) && (LaboratoryProject.ProjectFocus.ObjectID == Tech.GetReference().ObjectID))
    {
        return true;
    }

    return false;
}
simulated function StartProject(XComGameState_Tech Tech)
{
    if (FacilityState.BuildQueue.Length > 0)
    {
        PauseTech();
    }
    
	SetNewLaboratoryProject(Tech);
}

function SetNewLaboratoryProject(XComGameState_Tech Tech)
{
	local XComGameState NewGameState;
	local LaboratoryProject LaboratoryProject;
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
	LaboratoryProject = LaboratoryProject(NewGameState.CreateNewStateObject(class'LaboratoryProject'));

	if (ResearchProject != none)
	{
		class'LaboratoryProject'.static.Import(LaboratoryProject, ResearchProject);
		LaboratoryProject.bForcePaused = false;
        XComHQ.Projects.RemoveItem(ResearchProject.GetReference());      
	}
	else
	{
    	LaboratoryProject.SetProjectFocus(TechRef, NewGameState, FacilityState.GetReference());

		TechCost = TechTemplate.Cost;
		XComHQ.PayStrategyCost(NewGameState, TechCost, XComHQ.ResearchCostScalars);
        UpdateResources();
	}

    XComHQ.Projects.AddItem(LaboratoryProject.GetReference());   

	FacilityState = XComGameState_FacilityXCom(NewGameState.ModifyStateObject(class'XComGameState_FacilityXCom', FacilityState.ObjectID));
    FacilityState.BuildQueue.Length = 0;
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

// These are panels that come with the Package, they cannot be removed but they can be hidden
// We use their MCName(from UIInventory) to override them and take control of them, then we hide them
simulated function DisablePackagePanels()
{
    local UIX2PanelHeader PackageTitleHeader;
    local UIPanel ListContainer;
    local UIItemCard PackageItemCard;
    local UIPanel ListBG;
    local UIList List;

	PackageTitleHeader = Spawn(class'UIX2PanelHeader', self);
	PackageTitleHeader.InitPanelHeader('TitleHeader');
	PackageTitleHeader.Hide();
	ListContainer = Spawn(class'UIPanel', self).InitPanel('InventoryContainer');
	ListContainer.Hide();
	PackageItemCard = Spawn(class'UIItemCard', ListContainer).InitItemCard('ItemCard');
	PackageItemCard.Hide();
	ListBG = Spawn(class'UIPanel', ListContainer);
	ListBG.InitPanel('InventoryListBG'); 
	ListBG.Hide();
	List = Spawn(class'UIList', ListContainer);
	List.InitList('inventoryListMC');
	List.Hide();
}

simulated function CloseScreen()
{
    super.CloseScreen();
    `HQPRES.m_kAvengerHUD.ResourceContainer.Hide();
}

simulated function DoToggleQueueButton()
{
	UserQueueToggleState = !UserQueueToggleState;
	DoToggleQueue();
}

simulated function DoToggleQueue()
{
	local UIScreen QueueScreen;
	local UIFacility_Labs Laboratory;
	local UIEventQueue Queue;
	local UIFacility_ResearchProgress Progress;

	QueueScreen = Movie.Stack.GetScreen(class'UIFacility_Labs');

    if (QueueScreen != None)
    {
        Laboratory = UIFacility_Labs(QueueScreen);

        Queue = UIEventQueue(Laboratory.GetChildByName('BuildQueue'));
        Progress = UIFacility_ResearchProgress(Laboratory.GetChildByName('BuildProgress'));
        
        // A Project has to be active for the queue to be displayed at all
        if ((UserQueueToggleState) && (FacilityState.BuildQueue.Length > 0))
        {
            RefreshQueue();
            Queue.SetVisible(true);
            Progress.SetVisible(true);
        }
        else
        {
            Queue.SetVisible(false);
            Progress.SetVisible(false);				
        }
	}
}

static function RefreshQueue()
{
	local UIScreen QueueScreen;
	local UIFacility_Labs Laboratory;
	local UIEventQueue Queue;
	local UIFacility_ResearchProgress Progress;
    local XComGameState_FacilityXCom iFacility;

	QueueScreen = `SCREENSTACK.GetScreen(class'UIFacility_Labs');

	if (QueueScreen != None)
	{
        Laboratory = UIFacility_Labs(QueueScreen);

      	Queue = UIEventQueue(Laboratory.GetChildByName('BuildQueue'));
		Progress = UIFacility_ResearchProgress(Laboratory.GetChildByName('BuildProgress'));
	    iFacility = `XCOMHQ.GetFacilityByName('Laboratory');

		UpdateBuildQueue(iFacility, Queue);
		UpdateBuildProgress(iFacility, Queue, Progress);
		Queue.DeactivateButtons();

        if ((iFacility.BuildQueue.Length > 0) && (Laboratory == `SCREENSTACK.GetCurrentScreen()))
        {
            // Always show these in the facility screen if there is a project running
            Progress.Show();
            Queue.Show();
        }
	}
}
static function UpdateBuildQueue(XComGameState_FacilityXCom Laboratory, out UIEventQueue Queue)
{
	local XComGameState_Tech Tech;
	local LaboratoryProject LaboratoryProject;
	local array<HQEvent> BuildItems;
	local HQEvent BuildItem;
	local int i, ProjectHours;

	for (i = 0; i < Laboratory.BuildQueue.Length; i++)
	{
		LaboratoryProject = LaboratoryProject(`XCOMHISTORY.GetGameStateForObjectID(Laboratory.BuildQueue[i].ObjectID));

		// Calculate the hours based on which type of Headquarters Project this queue item is
		if (i == 0)
		{
			ProjectHours = LaboratoryProject.GetCurrentNumHoursRemaining();
		}
		else
		{
			ProjectHours += LaboratoryProject.GetProjectedNumHoursRemaining();
		}

		Tech = XComGameState_Tech(`XCOMHISTORY.GetGameStateForObjectID(LaboratoryProject.ProjectFocus.ObjectID));

		BuildItem.Hours = ProjectHours;
		BuildItem.Data = Tech.GetMyTemplate().DisplayName;
		BuildItem.ImagePath = class'UIUtilities_Image'.const.EventQueue_Science;
		BuildItems.AddItem(BuildItem);
	}

	Queue.UpdateEventQueue(BuildItems, true, false);
	Queue.HideDateTime();
}
static function UpdateBuildProgress(XComGameState_FacilityXCom Laboratory, out UIEventQueue Queue, out UIFacility_ResearchProgress Progress)
{
	local string Days, Time, Speed;
	local XComGameState_Tech Tech;
	local LaboratoryProject LaboratoryProject;
	local int ProjectHours;
    local EUIState iColor;
    local EResearchProgress Category;

    if (Laboratory.BuildQueue.Length > 0)
    {
		LaboratoryProject = LaboratoryProject(`XCOMHISTORY.GetGameStateForObjectID(Laboratory.BuildQueue[0].ObjectID));
		Tech = XComGameState_Tech(`XCOMHISTORY.GetGameStateForObjectID(LaboratoryProject.ProjectFocus.ObjectID));
		ProjectHours = LaboratoryProject.GetCurrentNumHoursRemaining();

		if (ProjectHours < 0)
        {
			Days = class'UIUtilities_Text'.static.GetColoredText(class'UIFacility_PowerCore'.default.m_strStalledResearch, eUIState_Warning);
        }
		else
        {
			Days = class'UIUtilities_Text'.static.GetTimeRemainingString(ProjectHours);
        }

        Category = GetResearchProgress(Tech.GetReference());
	    Speed = class'UIFacility_Powercore'.default.m_strProgress @ class'UIUtilities_Strategy'.static.GetResearchProgressString(Category);
        iColor = class'UIUtilities_Strategy'.static.GetResearchProgressColor(Category);
		Time = class'UIUtilities_Text'.static.GetColoredText(Speed, iColor);
		Progress.Update(class'UIFacility_Powercore'.default.m_strCurrentResearch, Tech.GetMyTemplate().DisplayName, Days, Time, int(100 * LaboratoryProject.GetPercentComplete()));
		Progress.Show();
		Queue.SetY(-250); // move up to make room for BuildProgress bar
	}
	else
	{
		Progress.Hide();
		Queue.Hide();
	}
}
// Modfied from XComGameState_HeadquartersXCom
static function EResearchProgress GetResearchProgress(StateObjectReference TechRef)
{
	local int iHours, iDays;

	if(TechRef.ObjectID == 0)
	{
		return eResearchProgress_Normal;
	}

	iHours = GetResearchHours(TechRef);
	iDays = class'X2StrategyGameRulesetDataStructures'.static.HoursToDays(iHours);

	if(iDays <= `ScaleStrategyArrayInt(class'XComGameState_HeadquartersXCom'.default.ResearchProgressDays_Fast))
    {
		return eResearchProgress_Fast;
    }
	else if(iDays <= `ScaleStrategyArrayInt(class'XComGameState_HeadquartersXCom'.default.ResearchProgressDays_Normal))
    {
		return eResearchProgress_Normal;
    }
	else if(iDays <= `ScaleStrategyArrayInt(class'XComGameState_HeadquartersXCom'.default.ResearchProgressDays_Slow))
    {
		return eResearchProgress_Slow;
    }
	else
    {
		return eResearchProgress_VerySlow;
    }
}
// Modfied from XComGameState_HeadquartersXCom
static function int GetResearchHours(StateObjectReference TechRef)
{
	local int iHours;
	local XComGameState NewGameState;
	local XComGameStateHistory iHistory;
	local LaboratoryProject LaboratoryProject;
    local XComGameState_HeadquartersProjectResearch ResearchProject;

	iHistory = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("SHOULD NOT BE SUBMITTED");
	LaboratoryProject = LaboratoryProject(NewGameState.CreateNewStateObject(class'LaboratoryProject'));
	
	ResearchProject = `XCOMHQ.GetPausedProject(TechRef);

	if (ResearchProject == none)
	{
		LaboratoryProject.SetProjectFocus(TechRef);
	}
    else
    {
        class'LaboratoryProject'.static.Import(LaboratoryProject, ResearchProject);
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

    Package         = "/ package/gfxInventory/Inventory";

	DisplayTag      = "UIBlueprint_Camera_1";
	CameraTag       = "UIBlueprint_Camera_1";

	ConfirmButtonX = 12
	ConfirmButtonY = 0

	bHideOnLoseFocus = true;
    bIsIn3D = true;
	bAnimateOnInit = true;
    
	UserQueueToggleState = true;
}
