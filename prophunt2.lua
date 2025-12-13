--[[
#version 2
#include "script/include/player.lua"
#include "Automatic.lua"
#include "/mplib/mp.lua"
]]


shared.hiders = {}
server.lobbySettings = {}
server.lobbySettings.enforceLimit = 1 -- Using 1 and 0 instead of booleans
server.lobbySettings.forceTeams = 1
server.lobbySettings.randomTeams = 1
server.lobbySettings.amountHunters = 1

function server.init()
	hudInit(true)
	hudAddUnstuckButton()
	teamsInit(2)
	teamsSetNames({"Hiders", "Hunters"})
	teamsSetColors{{0,1,1},{1,0,0}}

	statsInit()

	countdownInit(10)

	spawnInit()
	toolsSetDropToolsOnDeath(false)
	spawnSetDefaultLoadoutForTeam(1,{{}}) -- Hiders
	spawnSetDefaultLoadoutForTeam(2,{{"sledge", 0}, {"gun", 3}}) -- Hunters
end

function server.tick(dt)
	if teamsTick(dt) then
		spawnRespawnAllPlayers()
	end

	if countdownTick(dt) then return end

	if not teamsIsSetup() then 
		for p in Players() do
			DisablePlayer(p)
		end
		return
	end

	spawnTick(dt, teamsGetPlayerTeamsList())
	eventlogTick(dt)
end

function server.start(settings)
	shared.time = settings.time
	server.lobbySettings.enforceLimit = settings.enforceLimit
	server.lobbySettings.forceTeams = settings.forceTeams
	server.lobbySettings.randomTeams = settings.randomTeams
	server.lobbySettings.amountHunters = settings.amountHunters
	
	AutoInspect(settings,2, " ", false)

	

	teamsStart(true)
end

function client.draw(dt)
	-- during countdown, display the title of the game mode.
	hudDrawTitle(dt, "Prophunt!")
	hudDrawBanner(dt)


	if not teamsIsSetup() then
		teamsDraw(dt)

		if not hudGameIsSetup() then
			local maxHunters = {}
			local players = GetMaxPlayers()
			for i=1, math.max(players - 1, 12) do
				maxHunters[#maxHunters+1] = {label = tostring(i).. " Hunter", value = i}
			end

			local settings = {
			{
				title = "",
					items = {
						{key = "savegame.mod.settings.time", 
						label = "Round Lenth", info="How long one round lasts", options = {{label = "05:00", value = 5*60},{label = "07:30", value = 7.5*60}, {label = "10:00", value=10*60}, {label = "03:00", value=3*60}}},
						{key = "savegame.mod.settings.hideTime", 
						label = "Hide Time", info="How much time hiders have to hide", options = {{label = "01:00", value=60} , {label = "01:30", value=90}, {label = "02:00", value=120}, {label = "00:30", value = 30}, {label = "00:45", value=45}}},
						{key = "savegame.mod.settings.joinHunters", 
						label = "Hider Hunters", info="Makes the hiders join the hunters once found.", options = {{label = "Enable", value = 1},{label = "Disable", value = 0}}},
						{key = "savegame.mod.settings.hunters", 
						label = "Hunters Amount", info="The amount of hunters at the beginning of a game. There will always be atleast one hider", options = maxHunters},
						{key = "savegame.mod.settings.enforceLimit", 
						label = "Limit Hunters", info="At the start of each game, the server removes extra hunters if there are more hunters than are set in 'Hunters Amount'.", options = {{label = "Enable", value = 1},{label = "Disable", value = 0}}},
						{key = "savegame.mod.settings.serverRandomTeams", 
						label = "Random Hunters", info="The server will randomize each team no matter if someone already joined hunters or hiders.", options = {{label = "Enable", value = 1},{label = "Disable", value = 0}}}
					}
				}
			}

			if hudDrawGameSetup(settings) then
				ServerCall("server.start", { 
					time = GetFloat("savegame.mod.settings.time") , 
					amountHunters = GetInt("savegame.mod.settings.hunters"), 
					forceTeams = GetInt("savegame.mod.settings.forceTeams"), 
					enforceLimit = GetInt("savegame.mod.settings.enforceLimit") , 
					randomTeams = GetInt("savegame.mod.settings.serverRandomTeams") 
				})
			end
		end
		return
	end

	hudDrawTimer(10, 1)
	eventlogDraw(dt, teamsGetPlayerColorsList())
end