--local _,L = ...
local _
local rematch = Rematch
local rematchsettings = RematchSettings
local old_PLAYER_TARGET_CHANGED = rematch.PLAYER_TARGET_CHANGED
local saved
local framebattle = CreateFrame("Frame", "RematchNextTargetbattle");
local framelog = CreateFrame("FRAME","RematchNextTargetlog");
local frametimer = CreateFrame("frame")
local version = GetAddOnMetadata("RematchNextTarget", "Version")
local checkpets
local previous_target = nil
local rmtchnxt_defaults
local faction
--TODO: some restrcucturisation of code
--TODO: In Celestial tournament, display suggested defeat order for trainers
--iekava = 3
--myAllianceroutetemp = {}
--myHorderoutetemp = {}
local route
--format for route
--{
--[NPC ID for current target] = NPC ID for the next target
--}
--get the NPC IDs for trainers from, for example, NPCs.txt
local function mergetables(prio1,prio2)
	for i, _ in pairs(prio2) do
		--print(i)
		if not prio1[i] then
			prio1[i] = prio2[i]
		end
    end
	--temp = prio1
	--return temp
	return prio1
end
local pandariatamers = {}
pandariatamers = {
	[68465] = 66738,
	[66738] = 68463,
	[68463] = 66918,
	[66918] = 66739,
	[66739] = 68462,
	[68462] = 66741,
	[66741] = 66734,
	[66734] = 66733,
	[66733] = 66730,
	[66730] = 68464,
	[68464] = 0, -- no next target
}
local beastsofFable = {}
beastsofFable = {
	[68564] = 68563,
	[68563] = 68562,
	[68562] = 68559,
	[68559] = 68558,
	[68558] = 68566,
	[68566] = 68560,
	[68560] = 68561,
	[68561] = 68555,
	[68555] = 68565,
	[68565] = 0, -- no next target
}
local northrend = {
}
northrend = {
	[32689] = 66636, -- Adorean Lew in Runewearer Square, Dalaran - use whichever you like of those two
	[32690] = 66636, -- Bitty Frostflinger in Runewearer Square, Dalaran - use whichever you like of those two
	[66636] = 66639,
	[66639] = 66638,
	[66638] = 66635,
	[66635] = 66675, -- use Argent Crusader's Tabard to get there
	[66675] = 0, -- no next target
}
local outland = {}
outland = {
	[18481] = 66553, -- A'dal in Shattrah City
	[66553] = 66552,
	[66552] = 66551,
	[66551] = 66557, --use Blessed Medialion of Karabor to get there
	[66557] = 66550,
	[66550] = 0, -- no next target
}
local tanaan = {}
tanaan = {
	[94650] = 94642,
	[94642] = 94644,
	[94644] = 94649,
	[94649] = 94648,
	[94648] = 94646,
	[94646] = 94647,
	[94647] = 94637,
	[94637] = 94640,
	[94640] = 94641,
	[94641] = 94643,
	[94643] = 94639,
	[94639] = 94601,
	[94601] = 94645,
	[94645] = 94638,
	[94638] = 0 -- no next target,
}
local allianceDefaultRoute = {}
local function getallianceDefaultRoute()
	local aliroute = {}
	--Draenor
	aliroute[85418] = 87122 -- Lio the Lioness <Battle�Pet�Master> -  pet healer in alliance garrison
	aliroute[87124] = 87123
	aliroute[87123] = 87125
	aliroute[87125] = 83837
	aliroute[83837] = 87122
	aliroute[87122] = 87110
	aliroute[87110] = 0 -- no next target
	--Pandaria tamers
	aliroute = mergetables(aliroute,pandariatamers)
	--Beasts of Fable
	aliroute[64572] = 68564 -- Sara Finkleswitch <Battle�Pet�Trainer> - alliance Beasts of Fable quest giver
	aliroute = mergetables(aliroute,beastsofFable)
	--Northrend
	aliroute = mergetables(aliroute,northrend)
	--Outland
	aliroute = mergetables(aliroute,outland)
	--Tanaan
	aliroute = mergetables(aliroute,tanaan)
	return aliroute
end


local hordeDefaultRoute = {}
local function gethordeDefaultRoute()
	local horderoute = {}
	--Draenor
	horderoute[79858] = 87122 -- Serr'ah <Battle�Pet�Master> - pet healer in horde garrison
	horderoute[87122] = 83837
	horderoute[83837] = 87125
	horderoute[87125] = 87123
	horderoute[87123] = 87124
	horderoute[87124] = 87110
	horderoute[87110] = 0 -- no next target
	--Pandaria tamers
	horderoute = mergetables(horderoute,pandariatamers)
	--Beasts of Fable
	horderoute[64582] = 68564 -- Gentle Sun <Battle�Pet�Trainer> - horde Beasts of Fable quest giver
	horderoute = mergetables(horderoute,beastsofFable)
	--Northrend
	horderoute = mergetables(horderoute,northrend)
	--Outland
	horderoute = mergetables(horderoute,outland)
	--Tanaan
	horderoute = mergetables(horderoute,tanaan)
	return horderoute
end


local function notGarrison(mapID)
	return mapID ~= 971 and mapID ~= 976 -- neither Frostwall nor Lunarfall
end
local winner
local elapsed
local function petbattlefinalround(...)
	--self,event,winner
	--print(winner)
	--also add option to detect leveling pets who have small amouunt of xp on this level, with possibility to remove from leveling queue
	--also add option whether have dialog pop-up
	_, _, winner = ...
	if winner == 1 then -- show dialog only if the trainer is defeated
	--if winner == 2 then -- faster testing with forfeiting
		local key = rematch.recentTarget
		--local key = rematchsettings.loadedTeam
		if key and saved[key] then
			--print(rematch.recentTarget)
			SetMapToCurrentZone();
			local continent = GetCurrentMapContinent();
			local temp=GetCurrentMapAreaID()
			if temp ~= 955 and notGarrison(temp) and continent ~= 8 then -- neither Celestial Tournament, nor Garrison nor Broken Isles
				if route[key] then
					if (route[key] ~= 0) then
						local enabled = true --for me seems like overkill. Isn't here some C-Timer function to delay ?
						local total = 0
						local function timerUpdate(...)
							_, elapsed = ...
							total = total + elapsed
							if enabled then
								if total >= 5 then
									if route[key] ~= rematchsettings.loadedTeam then
										local dialog = StaticPopup_Show ("RMTCHNXTTRGTQ")
										if dialog then dialog.teamname = route[key] end
									end
									enabled = false
								end
							end
						end
						frametimer :SetScript("OnUpdate", timerUpdate)
						--print("Press Alt, and then select the trainer")
					end
				else
					DEFAULT_CHAT_FRAME:AddMessage("No next target defined!")
				end
			end
		end
	else 
		--print("you were defeated")
	end
	if checkpets then
	--for iOwner = 1, 2 do
		local keyy = rematch.recentTarget
		local same = true
		local notableIndex
		for index,info in pairs(rematch.notableNPCs) do
			if info[1]==keyy then
				notableIndex = index
				break
			end
		end
		if notableIndex then
			local order  = "Correct pet order for NPC " .. tostring(keyy) .. " is "
			local order1 = " instead of "
			local IndexMax = C_PetBattles.GetNumPets(2)
			for iIndex = 1, IndexMax do
				local nSpeciesID = C_PetBattles.GetPetSpeciesID(2, iIndex)
				local mSpeciesID = rematch.notableNPCs[notableIndex][iIndex+2]
				if mSpeciesID then 
					if mSpeciesID ~= nSpeciesID then same = false end
					if iIndex ~= 1 then
						order = order .. ", "
						order1 = order1 .. ", "
					end
					order = order .. tostring(nSpeciesID)
					order1 = order1 .. tostring(mSpeciesID)
				end
			end
			DEFAULT_CHAT_FRAME:AddMessage("The pet order is " .. same)
			if not same then DEFAULT_CHAT_FRAME:AddMessage(order .. " " .. order1) end
		end
	end
end
local function getrmtchnxt_defaults ()
	local default_set = {}
	default_set = {
		["version"] = "0", -- for some reason has to be string instead of integer
		["checkpets"] = false,
	}
	return default_set
end

framebattle:RegisterEvent("PET_BATTLE_FINAL_ROUND")
framebattle:SetScript("OnEvent", petbattlefinalround);
framelog:RegisterEvent("ADDON_LOADED");
framelog:RegisterEvent("PLAYER_LOGOUT");
framelog:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "RematchNextTarget" then
			local function copytable(db, defaults)
				if type(db) ~= "table" then db = {} end
				if type(defaults) ~= "table" then return db end
				for k, v in pairs(defaults) do
					if type(v) == "table" then
						db[k] = copytable(db[k], v)
					elseif type(v) ~= type(db[k]) then
						db[k] = v
					end
				end
				return db
			end
			allianceDefaultRoute = getallianceDefaultRoute()
			myAllianceroute = copytable(myAllianceroute, allianceDefaultRoute) 
			hordeDefaultRoute = gethordeDefaultRoute()
			myHorderoute = copytable(myHorderoute, hordeDefaultRoute)
			rmtchnxt_defaults = getrmtchnxt_defaults()
			rmtchnxttrgt_saved = copytable(rmtchnxttrgt_saved, rmtchnxt_defaults)
			if (rmtchnxttrgt_saved.version ~= version) then DEFAULT_CHAT_FRAME:AddMessage("New Rematch Next Target verion loaded! Type /rmtnxt for options.") end
			checkpets = rmtchnxttrgt_saved.checkpets
			--if (myAllianceroute == nil) then myAllianceroute = getAllianceRoute() end
			--if (myHorderoute == nil) then myHorderoute = getHordeRoute() end
			--print("third stage")
			faction = UnitFactionGroup("player")
			if faction == "Horde" then route = myHorderoute; end
			if faction == "Alliance" then route = myAllianceroute; end
			self:UnregisterEvent("ADDON_LOADED")
		else 
			--print("rematch",arg1)
		end
	else
		if event == "PLAYER_LOGOUT" then
			--if route == nil then print("wonderfull") end
			if faction == "Horde" then myHorderoute = route; end
			if faction == "Alliance" then myAllianceroute = route; end
			rmtchnxttrgt_saved.version = version
			rmtchnxttrgt_saved.checkpets = checkpets
		end
	end
end)
local function loadteamr(self)
	--print(self.teamname)
	local nxttrgt = rematch.notableNames[self.teamname]
	DEFAULT_CHAT_FRAME:AddMessage("Loaded team for " .. nxttrgt)
	rematch:LoadTeam(self.teamname)
end
rematch:InitModule(function()
	saved = RematchSaved
	StaticPopupDialogs["RMTCHNXTTRGTQ"] = {
		text = "Do you want to load team for the next target?",
		button1 = "Yes",
		button2 = "No",
		OnAccept = function(self)
			loadteamr(self)
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
	}
end)

SLASH_RMTNXT1 = "/rmtnxt";
function SlashCmdList.RMTNXT(msg)
	if msg == "" then
		DEFAULT_CHAT_FRAME:AddMessage("Available comands:")
		DEFAULT_CHAT_FRAME:AddMessage(" /rmtnxt 0 - sets next target for loaded team to none")
		DEFAULT_CHAT_FRAME:AddMessage(" /rmtnxt save1 - sets currently loaded team as previous target")
		DEFAULT_CHAT_FRAME:AddMessage(" /rmtnxt save2 - sets currently loaded team as next target")
		DEFAULT_CHAT_FRAME:AddMessage(" /rmtnxt pets - Displays current status of checkng for order of pets on trainers")
		DEFAULT_CHAT_FRAME:AddMessage(" /rmtnxt pets on - Switches on the checkng for order of pets on trainers")
		DEFAULT_CHAT_FRAME:AddMessage(" /rmtnxt pets off - Switches off the checkng for order of pets on trainers")
		DEFAULT_CHAT_FRAME:AddMessage(" /rmtnxt reset - Resets current factions routes to default")
	end
	if msg =="0" then
		local temp = rematchsettings.loadedTeam
		if temp then
			route[temp] = 0
			DEFAULT_CHAT_FRAME:AddMessage(rematchsettings.loadedTeam .. " next target set to none")
		else
			DEFAULT_CHAT_FRAME:AddMessage("No team loaded")
		end
	end
	if msg == "save1" then
		previous_target = rematchsettings.loadedTeam
		DEFAULT_CHAT_FRAME:AddMessage("Saved " .. previous_target .. " for previous target")
	end
	if msg == "save2" then
		if previous_target then
			if rematchsettings.loadedTeam then
				if previous_target ~= rematchsettings.loadedTeam then
					if route[previous_target] then DEFAULT_CHAT_FRAME:AddMessage("Overwriting existing next target") end
					route[previous_target] = rematchsettings.loadedTeam
					DEFAULT_CHAT_FRAME:AddMessage("Succesfully saved")
				else
					DEFAULT_CHAT_FRAME:AddMessage("Target can't be equal to previous target; use /rmtnxt 0 to end the route")
				end
			else
				DEFAULT_CHAT_FRAME:AddMessage("No team loaded")
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("No previous target saved")
		end
	end
	if msg == "pets" then
		local message = "Currently "
		if not checkpets then message = message .. "not " end
		message = message .. "checking for wrong order of pets in trainer"
		DEFAULT_CHAT_FRAME:AddMessage(message)
	end
	if msg == "pets on" then
		checkpets = true
		DEFAULT_CHAT_FRAME:AddMessage("Now checking for wrong order of pets in trainer")
	end
	if msg == "pets off" then
		checkpets = false
		DEFAULT_CHAT_FRAME:AddMessage("Now not checking for wrong order of pets in trainer")
	end
	--[[
	if msg == "reset1" then
		if myAllianceroute == nil or (myAllianceroute == {}) then print("ohohoho1") end
		if myHorderoute == nil or (myHorderoute == {}) then print("ahahaha1") end
		myHorderoute = nil
		myAllianceroute = nil
		print("reseted to nil")
	end
	--]]
	if msg == "reset" then
		--myAllianceroute = allianceDefaultRoute
		--if myAllianceroute == nil then print("ohohoho") end
		--myHorderoute = hordeDefaultRoute
		--if myHorderoute == nil then print("ahahaha") end
		--print("end")
		route = {}
		if faction == "Horde" then route = hordeDefaultRoute end
		if faction == "Alliance" then route = allianceDefaultRoute end
		--if route == nil or (route == {}) then print("Amazing") end
		DEFAULT_CHAT_FRAME:AddMessage("Route reseted for " .. faction)
	end
end

local function my_PLAYER_TARGET_CHANGED(self)
	--local saved = RematchSaved
	local name,npcID = rematch:GetUnitNameandID("target")
	--print (name, " ",npcID) -- code to check to verify the accuracy of the NPC ID - name of NPC table
	local namefromtable = rematch.notableNames [npcID]
	if namefromtable then
		if name ~= namefromtable then
			DEFAULT_CHAT_FRAME:AddMessage(name .. " does not match " .. namefromtable)
		end
	end
	if route[npcID] then
		local key = route[npcID]
		if key then
			if saved[key] then
				local nxttrgt = rematch.notableNames[key]
				rematch:LoadTeam(key)
				DEFAULT_CHAT_FRAME:AddMessage("Loaded team for " .. nxttrgt)
			end
		end
	end
end

function Rematch:PLAYER_TARGET_CHANGED()
	if IsAltKeyDown() then
		--local name,npcID = rematch:GetUnitNameandID("target")
		return my_PLAYER_TARGET_CHANGED(self)
	else
		if IsControlKeyDown() then
			local name,npcID = rematch:GetUnitNameandID("target")	
		else
			return old_PLAYER_TARGET_CHANGED(self)
		end
	end
end

