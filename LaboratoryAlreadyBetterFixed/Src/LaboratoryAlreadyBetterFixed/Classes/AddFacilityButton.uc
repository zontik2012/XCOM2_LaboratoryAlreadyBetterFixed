class AddFacilityButton extends UIScreenListener config(game);

var localized string OpenUILaboratory;

// This event is triggered after a screen is initialized
event OnInit(UIScreen Screen)
{
    CreateButton(Screen);
	CreateQueue(Screen);
} 

function CreateButton(UIScreen Screen)
{
	local UIFacility_Labs Parent;

	Parent = UIFacility_Labs(Screen);
	Parent.AddFacilityButton(caps(OpenUILaboratory), DoOpenUILaboratory);
}

simulated function DoOpenUILaboratory()
{
	`SCREENSTACK.Push(`HQPRES.Spawn(class'UILaboratory', `HQPRES), `HQPRES.Get3DMovie());
}

simulated function CreateQueue(UIScreen Screen)
{
	local UIFacility_Labs Parent;
	local UIEventQueue Queue;
	local UIFacility_ResearchProgress BuildProgress;

	Parent = UIFacility_Labs(Screen);

	Queue = Parent.Spawn(class'UIEventQueue', Parent).InitEventQueue();
	Queue.MCName = 'BuildQueue';
	BuildProgress = Parent.Spawn(class'UIFacility_ResearchProgress', Parent).InitResearchProgress();
	BuildProgress.MCName = 'BuildProgress';

	class'UILaboratory'.static.RefreshQueue();
}

defaultproperties
{
	ScreenClass = UIFacility_Labs;
}