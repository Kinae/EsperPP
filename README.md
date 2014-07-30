EsperPP
=======
Very basic Esper resource tracker. Or, well, not so basic anymore ... nor does it only track resources ...

Since I didn't like the default UI's Psi Point tracker for Espers I have created my own. It was not really meant for public use since it is just set up how I like it and there is very little customization options for the addon, but I've got a couple of request to share it, so here it goes for the folk who might want to use it.

Some time have passed and now there are customization and a ton of new features (list below).

####Update:
From version 9.1.0.1 there are some customization options

##Goal:
Provide a cleaner Psi Point tracking interface and some additional aid for Espers.

##Target audience:
Espers.

##Features:
* Movable psi point display
* The Psi point trackers color is now customizable. By default the psi point counter turns yellow when at 4 psi points. Turns red when at 5 (aka max) also an extra graphic appears to draw more attention to the fact you are at max psi points.
* Color the psi point tracking interface different when out of combat.
* Show timer bars for when Concentrated Blade is supposed to land. These timers bars are created when you use the ability so they might show up for CBs that you casted and missed your target. I have not find a way to track when you actually spawn a CB that'll land, so for now all casts are assumed to land.
* Concentrated blade timer can be hidden.
* Movable / sizable focus bar for the healers. You can also just hide it if you are a DPS.
* Focus bar is colorable additionally there is a reactive option that allows you to set the background color of the focus bar based on how much percentage of focus you have left.
* Psi Charge tracking: This is pretty ugly till Carbine fixes the API, please make sure you read the description in the options before widdling with the settings.
* Telegraph assist: show where the telegraph would be for the corresponding spell if it was cast on a flat surface. Currently supported spells:
	* Mind Burst

##Configuration window slash command:
> /epp

> /EsperPP

##Planned features:
* Additional customization based on requests.
* Add a more elegant way of tracking for "Psi Charge" buff that you get when you use either tier 8 Telekinetic Strike or Psychic Frenzy. Right now you can't track it because the API does not return this buff in any of the tables. Bug reported: https://forums.wildstar-online.com/forums/index.php?/topic/38160-buff-api-bug-with-psi-charge/ waiting for Carbine to fix it.

##How to install:
Extract the EsperPP.zip file into the Wildstar Addon folder ( which can be found at %APPDATA%\Roaming\NCSOFT\WildStar\Addons by default, if you can't find the Addons folder, then create it! )
