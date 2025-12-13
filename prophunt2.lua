--[[
#version 2
#include "script/include/player.lua"
#include "Automatic.lua"
#include "/mplib/mp.lua"
]]


server.lobbySettings = {}
server.lobbySettings.enforceLimit = 1 -- Using 1 and 0 instead of booleans
server.lobbySettings.forceTeams = 1
server.lobbySettings.randomTeams = 1
server.lobbySettings.amountHunters = 1

shared.hiders = {}
shared.game = {}
shared.game.time = 0
shared.game.hunterFreed = false

server.game = {}
server.game.time = 0
server.game.hunterFreed = false

server.hunterData = {}
server.hunterData.hunter = {}

server.hiderData = {}
server.hiderData.hider = {}


client.game = {}
client.game.hider = {}
client.game.hider.lookAtShape = -1


function server.init()
	hudInit(true)
	hudAddUnstuckButton()
	teamsInit(2)
	teamsSetNames({"Hiders", "Hunters"})
	teamsSetColors{{0,1,1},{1,0,0}}

	statsInit()

	spawnInit()
	toolsSetDropToolsOnDeath(false)
	spawnSetDefaultLoadoutForTeam(1,{{}}) -- Hiders
	spawnSetDefaultLoadoutForTeam(2,{{"sledge", 0}, {"gun", 3}}) -- Hunters


end

function server.start(settings)
	server.game.time = settings.time
	shared.game.time = math.floor(server.game.time)

	server.lobbySettings.enforceLimit = settings.enforceLimit
	server.lobbySettings.forceTeams = settings.forceTeams
	server.lobbySettings.randomTeams = settings.randomTeams
	server.lobbySettings.amountHunters = settings.amountHunters

	AutoInspect(settings,2, " ", false)
	countdownInit(settings.hideTime, "hidersHiding")

	teamsStart(true)

	for id in Players() do 
		if teamsGetTeamId(id) == 1 then
			server.hiderData.hider[id] = {}
			server.hiderData.hider[id].propBody = -1
		else
			server.hunterData.hunter[id] = {}
		end
	end

	server.hunterData.hunters = teamsGetTeamPlayers(2)
end

function server.tick(dt)
	newPlayerJoinRoutine()

	if teamsTick(dt) then
		spawnRespawnAllPlayers()
	end

	if not teamsIsSetup() then 
		for p in Players() do
			DisablePlayer(p)
		end
		return
	end

	spawnTick(dt, teamsGetPlayerTeamsList())
	eventlogTick(dt)

	server.hunterTick(dt)
	server.hiderTick(dt)

	countdownTick(dt, 0, false)

	if server.game.hunterFreed then
		server.game.time = server.game.time - dt 			-- update time
		shared.game.time = math.floor(server.game.time) 	-- sync only whole seconds to client
	end
end

function newPlayerJoinRoutine()
	for id in PlayersAdded() do
		
	end
end

function server.hunterTick(dt)
	if not server.game.hunterFreed then
		local count = GetEventCount("countdownFinished")
		local data, finished = GetEvent("countdownFinished", 1)
		local hunters = teamsGetTeamPlayers(2)

		if data == "hidersHiding" and finished then

			for i = 1, #hunters do
				spawnRespawnPlayer(hunters[i])
			end

			server.game.hunterFreed = true
			shared.game.hunterFreed = true

			eventlogPostMessage({"loc@EVENT_GLHF"})
		else
			for i = 1, #hunters do
				SetPlayerTransform(Transform(Vec(1000,10,1000)), hunters[i])
			end

			return
		end
	end
end

function server.hiderTick(dt)
	
end

function server.update()
	server.hunterUpdate()
	server.hiderUpdate()
end

function server.hunterUpdate()
	
end

function server.hiderUpdate()
	
end

--- Helper Server Functions ---

function server.clientPropSpawnRequest(playerid, propid)
    local string = "Player " .. GetPlayerName(playerid) .. " wants to spawn prop " .. propid
	local shape = playerGetLookAtShape(10, GetLocalPlayer())
	local shapeBody = GetShapeBody(shape)
	DebugPrint("askjldas")
	if shape == propid and shapeBody ~= server.hiderData.hider[playerid].propBody then 
		DebugPrint("inside")
		--Delete(server.hiderData.hider[playerid].propBody)

		local newBody, newShape = server.cloneShape(propid)

		local bodyTransform = GetBodyTransform(newBody)
		local aa,bb = GetBodyBounds()


		SetBodyTransform(newBody,Transform(VecAdd(GetPlayerTransform().pos,Vec(0,0,2)),bodyTransform.rot))
		SetBodyDynamic(newBody,true)
		server.disableBodyCollission(newBody,true)

		server.hiderData.hider[playerid].propBody = newBody
		SetTag(newBody, "unbreakable")
	end
end

function server.disableBodyCollission(body, bool)
    local shapes = GetEntityChildren(body, "", true, "shape")
    local mask = 0 
    if bool then 
        mask = 253
    end

    for i = 1, #shapes do
        if bool then
            SetShapeCollisionFilter(shapes[i], 4, 4)
        else
            SetShapeCollisionFilter(shapes[i], 1, 255)
        end
    end
end

function server.DisablePlayers(teamID, disablePlayer)
	for p in Players() do
		if teamsGetTeamId(p) == teamID or teamID == 0 then
			if disablePlayer then
				SetPlayerWalkingSpeed(0, p)
				DisablePlayerDamage(p)
				SetPlayerParam("disableinteract", true, p)
			end
		end
	end
end

function server.cloneShape( shape )
    local newBody = Spawn('<body pos="0.0 0 0.0" dynamic="true"> <voxbox tags="deleteTempShape" size="1 1 1"/> </body>',Transform(),false)[1] -- Temo shape because empty bodies get rmoved?
    local save = CreateShape(newBody,Transform(),0)
    CopyShapeContent( shape, save )
    local x, y, z, scale = GetShapeSize( shape )
    local start = GetShapeWorldTransform( shape )
    local body = GetShapeBody(save)
    ResizeShape( shape, 0, 0, 0, x - 1, y - 1, z + 1 )
    SetBrush( "cube", 1, 1 )
    DrawShapeBox( shape, 0, 0, z + 1, 0, 0, z + 1 )
    local pieces = SplitShape( shape, false )
    local moved = VecScale( TransformToLocalPoint( GetShapeWorldTransform( shape ), start.pos ), 1 / scale )
    local mx, my, mz = math.floor( moved[1] + 0.5 ), math.floor( moved[2] + 0.5 ), math.floor( moved[3] + 0.5 )
    ResizeShape( shape, mx, my, mz, 1, 1, 1 )

    CopyShapeContent( save, shape )
    local splitoffset = VecScale( TransformToLocalPoint( GetShapeWorldTransform( pieces[1] ), start.pos ), 1 / scale )
    local sx, sy, sz = math.floor( splitoffset[1] + 0.5 ), math.floor( splitoffset[2] + 0.5 ),
                        math.floor( splitoffset[3] + 0.5 )
    ResizeShape( pieces[1], sx, sy, sz, 1, 1, 1 )
    CopyShapeContent( save, pieces[1] )
    Delete( save )
    for i = 2, #pieces do
        Delete( pieces[i] )
    end
    Delete(FindShape("deleteTempShape",true))

    SetShapeBody( pieces[1], newBody ,true)
    SetShapeLocalTransform( pieces[1], GetShapeLocalTransform(shape))

    return newBody, pieces[1]
end

-- Client Functions

function client.tick()
		SetBool("game.disablemap", true)

	if teamsGetTeamId(GetLocalPlayer()) == 1 then 
		-- Hider Logic
		client.SelectProp()
	else
		-- Hunter Logic?
	end
end

function client.SelectProp()
    client.HighlightDynamicBodies()
    if client.game.hider.lookAtShape ~= -1 then
        if InputPressed("interact") then
            ServerCall("server.clientPropSpawnRequest", GetLocalPlayer(), client.game.hider.lookAtShape)
        end
    end
end

function client.HighlightDynamicBodies()
	local playerTransform = GetPlayerTransform()
    local aa = VecAdd(playerTransform.pos, Vec(5,5,5))
    local bb = VecAdd(playerTransform.pos, Vec(-5,-5,-5))

    QueryRequire("physical dynamic large")
    local bodies = QueryAabbBodies(bb, aa)

    client.game.hider.lookAtShape = -1

    for i = 1, #bodies do
        local body = bodies[i]
        if IsBodyVisible(body, 5, false) then
            DrawBodyOutline(body, 1 ,1 ,1, 1)
            local shape = playerGetLookAtShape(10, GetLocalPlayer())
            if GetShapeBody(shape) == body then
                DrawBodyHighlight(body, 0.8)
                client.game.hider.lookAtShape = shape 
            end
        end
    end
end

function client.draw(dt)
	-- during countdown, display the title of the game mode.

	if InputPressed('e') then 	PostEvent("whatever", GetTime()) end 

	hudDrawTitle(dt, "Prophunt!")
	hudDrawBanner(dt)
	if not client.SetupScreen(dt) then return end -- If Setup not complete dont proceed

	if shared.countdownName == "hidersHiding" then
		countdownDraw("Hiders are Hiding!")
	end

	if shared.game.hunterFreed then
		hudDrawTimer(shared.game.time, 1)
	end

	if teamsGetTeamId(GetLocalPlayer()) == 1 then
		client.DrawTransformPrompt()
	end

	eventlogDraw(dt, teamsGetPlayerColorsList())
end

function client.DrawTransformPrompt()
    if client.game.hider.lookAtShape ~= -1 then
        local boundsAA, boundsBB = GetBodyBounds(GetShapeBody(client.game.hider.lookAtShape))
        local middle = VecLerp(boundsAA, boundsBB, 0.5)
        AutoTooltip("Transform Into Prop (E)", middle, false, 40, 1)
    end
end

function client.SetupScreen(dt)
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
						label = "Hide Time", info="How much time hiders have to hide", options = {{label = "01:00", value=60} , {label = "01:30", value=90}, {label = "02:00", value=120},{label = "00:30", value = 3}, {label = "00:30", value = 30}, {label = "00:45", value=45}}},
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
					randomTeams = GetInt("savegame.mod.settings.serverRandomTeams"),
					hideTime = GetFloat("savegame.mod.settings.hideTime"),
					
				})
			end
		end
		return false
	end
	return true
end

-- Global Helper Function

function playerGetLookAtShape(dist,playerID)

	local cameraT = GetPlayerCameraTransform(playerID or GetLocalPlayer())
	local playerFwd = VecNormalize(TransformToParentVec(cameraT, Vec(0, 0, -1)))

    QueryRequire("physical dynamic large")
    local hit,_,_,shape = QueryRaycast(cameraT.pos, playerFwd, dist, 0, false)

    if hit and IsShapeBroken(shape) == false then 
        return shape 
    else 
        return -1
    end
end