class Upgrades extends X2StrategyElement;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Laboratory_Level_2());
	Templates.AddItem(Laboratory_Level_3());

	return Templates;
}

static function X2DataTemplate Laboratory_Level_2()
{
	local X2FacilityUpgradeTemplate Template;
	local ArtifactCost Resources;

	`CREATE_X2TEMPLATE(class'X2FacilityUpgradeTemplate', Template, 'Laboratory_Level_2');
	Template.PointsToComplete = 0;
	Template.MaxBuild = 1;
	Template.iPower = -3;
	Template.UpgradeValue = 1;
	Template.UpkeepCost = 40;
	Template.strImage = "img:///UILibrary_StrategyImages.FacilityIcons.ChooseFacility_Laboratory_AdditionalResearchStation";
	Template.OnUpgradeAddedFn = class'X2StrategyElement_DefaultFacilityUpgrades'.static.OnUpgradeAdded_UnlockStaffSlot;

	Template.Requirements.RequiredUpgrades.AddItem('Laboratory_AdditionalResearchStation');

	Resources.ItemTemplateName = 'Supplies';
	Resources.Quantity = 125;
	Template.Cost.ResourceCosts.AddItem(Resources);

	return Template;
}

static function X2DataTemplate Laboratory_Level_3()
{
	local X2FacilityUpgradeTemplate Template;
	local ArtifactCost Resources;

	`CREATE_X2TEMPLATE(class'X2FacilityUpgradeTemplate', Template, 'Laboratory_Level_3');
	Template.PointsToComplete = 0;
	Template.MaxBuild = 1;
	Template.iPower = -3;
	Template.UpgradeValue = 1;
	Template.UpkeepCost = 40;
	Template.strImage = "img:///UILibrary_StrategyImages.FacilityIcons.ChooseFacility_Laboratory_AdditionalResearchStation";
	Template.OnUpgradeAddedFn = class'X2StrategyElement_DefaultFacilityUpgrades'.static.OnUpgradeAdded_UnlockStaffSlot;

	Template.Requirements.RequiredUpgrades.AddItem('Laboratory_Level_2');

	Resources.ItemTemplateName = 'Supplies';
	Resources.Quantity = 125;
	Template.Cost.ResourceCosts.AddItem(Resources);

	return Template;
}
