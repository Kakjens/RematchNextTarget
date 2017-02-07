local _,L = ...
local rematch = Rematch
local rematchsettings = RematchSettings
local old_PLAYER_TARGET_CHANGED = rematch.PLAYER_TARGET_CHANGED
local saved
local framebattle
local framelog
local frametimer
local version = "0.2.0"
local checkpets
local previous_target = nil
local rmtchnxt_defaults
--TODO: some restrcucturisation of code
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
	for i, v in pairs(prio2) do
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
	--Outlond
	aliroute = mergetables(aliroute,outland)
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
	--Northrend(NYI)
	horderoute = mergetables(horderoute,northrend)
	--Outlond(NYI)
	horderoute = mergetables(horderoute,outland)
	return horderoute
end


local function notGarrison(mapID)
	return mapID ~= 971 and mapID ~= 976 -- neither Frostwall nor Lunarfall
end

local function petbattlefinalround(self,event,winner)
	--print(winner)
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
						local function timerUpdate(self,elapsed)
							total = total + elapsed
							if enabled then
								if total >= 5 then
									local dialog = StaticPopup_Show ("RMTCHNXTTRGTQ")
									if dialog then dialog.teamname = route[key] end
									enabled = false
								end
							end
						end
						frametimer :SetScript("OnUpdate", timerUpdate)
						--print("Press Alt, and then select the trainer")
					end
				else
					print("No next target defined!")
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
			print("The pet order is ",same)
			if not same then print(order, order1) end
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
frametimer = CreateFrame("frame")
framebattle = CreateFrame("Frame", "RematchNextTarget");
framebattle:RegisterEvent("PET_BATTLE_FINAL_ROUND")
framebattle:SetScript("OnEvent", petbattlefinalround);
framelog = CreateFrame("FRAME","RematchNextTarget");
framelog:RegisterEvent("ADDON_LOADED");
--framelog = CreateFrame("FRAME","RematchNextTarget");
framelog:RegisterEvent("PLAYER_LOGOUT");
framelog:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "RematchNextTarget" then
			local function copytable(db, defaults)
				if type(db) ~= "table" then db = {} end
				if type(defaults) ~= "table" then print("hmmm") return db end
				for k, v in pairs(defaults) do
					if type(v) == "table" then
						print("recursion")
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
			if (rmtchnxttrgt_saved.version ~= version) then print("New Rematch Next Target verion loaded!") end
			checkpets = rmtchnxttrgt_saved.checkpets
			--if (myAllianceroute == nil) then myAllianceroute = getAllianceRoute() end
			--if (myHorderoute == nil) then myHorderoute = getHordeRoute() end
			--print("third stage")
			if UnitFactionGroup("player") == "Horde" then route = myHorderoute; end
			if UnitFactionGroup("player") == "Alliance" then route = myAllianceroute; end
			--self:UnregisterEvent("ADDON_LOADED")
		else 
			--print("rematch",arg1)
		end
	else
		if event == "PLAYER_LOGOUT" then
			--if route == nil then print("wonderfull") end
			if UnitFactionGroup("player") == "Horde" then myHorderoute = route; end
			if UnitFactionGroup("player") == "Alliance" then myAllianceroute = route; end
			rmtchnxttrgt_saved.version = version
			rmtchnxttrgt_saved.checkpets = checkpets
		end
	end
end)
local function loadteamr(self)
	--print(self.teamname)
	local nxttrgt = rematch.notableNames[self.teamname]
	print(format("Loaded team for %s.",nxttrgt))
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
		print("available comands -/rmtnxt 0; /rmtnxt save1; /rmtnxt save2 ")
	end
	if msg =="0" then
		local temp = rematchsettings.loadedTeam
		if temp then
			route[temp] = 0
			print(rematchsettings.loadedTeam, " next target set to none")
		else
			print("No team loaded")
		end
	end
	if msg == "save1" then
		previous_target = rematchsettings.loadedTeam
		print("saved ",previous_target, "for previous target")
	end
	if msg == "save2" then
		if previous_target then
			if rematchsettings.loadedTeam then
				if previous_target ~= rematchsettings.loadedTeam then
					if route[previous_target] then print("overwriting existing next target") end
					route[previous_target] = rematchsettings.loadedTeam
					print("succesfully saved")
				else
					print("target can't be equal to previous target")
				end
			else
				print("no team currently is loaded")
			end
		else
			print("no previous target saved")
		end
		
	end
	if msg == "pets" then
		local message = "Currently "
		if not checkpets then message = message .. "not " end
		message = message .. "checking for wrong order of pets in trainer"
		print(message)
	end
	if msg == "pets on" then
		checkpets = true
		print("Now checking for wrong orfer of pets in trainer")
	end
	if msg == "pets off" then
		checkpets = false
		print("Now not checking for wrong orfer of pets in trainer")
	end
	if msg == "reset1" then
		if myAllianceroute == nil or (myAllianceroute == {}) then print("ohohoho1") end
		if myHorderoute == nil or (myHorderoute == {}) then print("ahahaha1") end
		myHorderoute = nil
		myAllianceroute = nil
		print("reseted to nil")
	end
	if msg == "reset2" then
		myAllianceroute = allianceDefaultRoute
		if myAllianceroute == nil then print("ohohoho") end
		myHorderoute = hordeDefaultRoute
		if myHorderoute == nil then print("ahahaha") end
		print("end")
		route = {}
		if UnitFactionGroup("player") == "Horde" then route = myHorderoute; end
		if UnitFactionGroup("player") == "Alliance" then route = myAllianceroute; end
		if route == nil or (route == {}) then print("Amazing") end
	end
end
local function my_PLAYER_TARGET_CHANGED(self)
	--local saved = RematchSaved
	local name,npcID = rematch:GetUnitNameandID("target")
	print (name, " ",npcID) -- code to check to verify the accuracy of the NPC ID - name of NPC table
	local namefromtable = rematch.notableNames [npcID]
	if namefromtable then
		if name ~= namefromtable then
			print (format("%s does not match %s",name,namefromtable))
		end
	end
	if route[npcID] then
		local key = route[npcID]
		if key then
			if saved[key] then
				local nxttrgt = rematch.notableNames[key]
				print(format("Loaded team for %s.",nxttrgt))
				rematch:LoadTeam(key)
			end
		end
	end
end
function Rematch:PLAYER_TARGET_CHANGED()
	if IsAltKeyDown() then
		local name,npcID = rematch:GetUnitNameandID("target")
		return my_PLAYER_TARGET_CHANGED(self)
	else
		if IsControlKeyDown() then
			local name,npcID = rematch:GetUnitNameandID("target")	
		else
			return old_PLAYER_TARGET_CHANGED(self)
		end
	end
end

