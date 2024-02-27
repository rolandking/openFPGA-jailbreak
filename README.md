<p align="center">
<img src="https://github.com/rolandking/openFPGA-jailbreak/assets/1222719/248d9f2f-9a95-45b8-9332-71dfcb8afa3c"/>
</p>

# openFPGA-jailbreak

A port of jailbreak to the Analogue Pocket. Original code from the [MisTer port](github.com/MiSTer-devel/Arcade-Jailbreak_MiSTer)



## OVERVIEW 

Jailbreak is an arcade game where you, a lone policeman, take on hoards of escaped convicts to try and rescue the warden. 

You start with a pistol but each time you rescue a hostage (by running into them) you gain a new weapon or more ammunition for one of the weapons you have. You can cycle through the weapons at any time. Although your pistol never runs out of ammunition, other weapons do and when they do they will disappear from inventory and you will fall back to the pistol. 

You can die by running into a convict, getting shot (some convicts have guns), getting run over by stolen vehicles and .. some other ways. 

If you kill a hostage you lose any special weapons you have equipped. 



## PLATFORM

Analogue Pocket



## BUILDING

    `git clone git@githum.com:rolandking/openFPGA-jailbreak.git --recursive`

or clone the repo and do 

    `git submodule init`
    `git submodule update`

the quartus project file is at `src/fpga/ap_core.apf`


## ROMS

ROMs are not included, please provide your own. An MRA file is linked if you want to build your own. 


## CONTROLS

`A`      - fire the weapon

`B`      - cycle through available weapons

`select` - add a coin

`start`  - start the game

various options can be set (lives, difficulty) and persist across restarts

The high score table is saved in the Pocket's `Save` directory

Opening the menu pauses the game



## CREDITS

Thank you to the Mister-devel team for the MiSTer port which this code wraps. 
