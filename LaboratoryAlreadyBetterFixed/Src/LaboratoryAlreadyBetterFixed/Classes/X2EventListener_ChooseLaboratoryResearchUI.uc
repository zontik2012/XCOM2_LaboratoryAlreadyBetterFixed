class X2EventListener_ChooseLaboratoryResearchUI extends X2EventListener config(UI);

var config bool bHideResources;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	if (!default.bHideResources)
	{
		Templates.AddItem(CreateResourcesTemplate());
	}

	return Templates;
}

static function X2EventListenerTemplate CreateResourcesTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'LaboratoryAlreadyBetterUpdateResourcesHook');

	Template.RegisterInStrategy = true;
	Template.AddCHEvent('UpdateResources', OnUpdateResources, ELD_Immediate);

	return Template;
}

static function EventListenerReturn OnUpdateResources(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local UIScreen CurrentScreen;
	local UIAvengerHUD HUD;

	CurrentScreen = `SCREENSTACK.GetCurrentScreen();
	HUD = `HQPRES.m_kAvengerHUD;

	switch (CurrentScreen.Class)
	{
		// Proving ground project choose screen
		case class'UIChooseLaboratoryResearch':
            HUD.UpdateIntel();
            HUD.UpdateEleriumCrystals();
            HUD.UpdateAlienAlloys();
            HUD.UpdateScientistScore();
            HUD.UpdateEngineerScore();
			HUD.ShowResources();
		default:
			break;
	}

	return ELR_NoInterrupt;
}