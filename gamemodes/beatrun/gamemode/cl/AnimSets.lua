-- Animation sets and per-action overrides
-- Both sets have the same sequences (same names, same order), only the bone order differs,
-- so any action can be played from either model as long as the body anim is rebuilt on it

local AnimSet = CreateClientConVar("Beatrun_AnimSet", "0", true, false, "Animation set: 0 = Reanimated, 1 = Original")
local PerAction = CreateClientConVar("Beatrun_AnimSetPerAction", "0", true, false, "Pick the animation set per action instead of using Beatrun_AnimSet for everything")

-- Index is the Beatrun_AnimSet value
BEATRUN_ANIMSET_MODELS = {
	[0] = "new_climbanim", -- Reanimated
	[1] = "old_climbanim" -- Original
}

-- Models that belong to an animation set, anything else (custom anims, ladders...) is left alone
BEATRUN_ANIMSET_MODELNAMES = {
	new_climbanim = true,
	old_climbanim = true
}

-- Per-action override values
BEATRUN_ANIMSET_DEFAULT = -1 -- follow Beatrun_AnimSet
BEATRUN_ANIMSET_REANIMATED = 0
BEATRUN_ANIMSET_ORIGINAL = 1

-- Every action with an animation and the sequences it plays. Sequences not listed here use the global set
BEATRUN_ANIM_ACTIONS = {
	{ key = "stand", sequences = { "stand", "walktostandleft" } },
	{ key = "walk", sequences = { "walkfwd", "walkback" } },
	{ key = "run", sequences = { "runfwd", "runbwd", "runfwdstart", "runland", "runpose", "run_pose" } },
	{ key = "sprint", sequences = { "sprintfwd" } },
	{ key = "crouch", sequences = { "crouchfwd", "crouchbwd", "crouchstill", "crouchtostandleft" } },
	{ key = "jump", sequences = { "jumpslow", "jumpfast", "jumpstill", "jumpcrouch" } },
	{ key = "fall", sequences = { "jumpair", "jumpidle", "fallinguncontrolled" } },
	{ key = "landing", sequences = { "land", "landgun", "landcrouch", "landguncrouch", "fallhurt" } },
	{ key = "roll", sequences = { "meroll", "merollgun", "merollcrouch", "merollguncrouch", "rollanim" } },
	{ key = "coil", sequences = { "jumpcoil", "jumpcoilcatalyst", "jumpcoilend", "jumpcoilendcrouch", "mecoil" } },
	{ key = "quickturn", sequences = { "jumpturnfly", "jumpturnflyidle", "jumpturnland", "jumpturnlandidle", "jumpturnlandstand", "jumpturnlandcrouch", "jumpturnlandstandgun", "jumpturnflypiecesign", "jumpturnflypiecesignloop" } },
	{ key = "evaderoll", sequences = { "evaderoll", "evaderollcrouch" } },
	{ key = "sidestep", sequences = { "dodgejumpleft", "dodgejumpright" } },
	{ key = "wallrun", sequences = { "wallrunleftstart", "wallrunleft", "wallrunrightstart", "wallrunright", "jumpwrleft", "jumpwrright" } },
	{ key = "wallclimb", sequences = { "wallrunverticalstart", "wallrunvertical", "wallrunverticalturn" } },
	{ key = "hang", sequences = { "hang", "hangpose", "hanghardstart", "hanghardstart2", "hanghardstartvertical", "hangfoldedstart", "hangfoldedendhang", "hangstrafeleft", "hangstraferight", "hangcornerleft", "hangcornerright", "hangjumpup" } },
	{ key = "climb", sequences = { "hangheaveup", "hangfoldedheaveup", "climb1", "climb2" } },
	{ key = "vault", sequences = { "vaultover", "vaultonto", "vaultkong", "vaultoverhigh", "vaultontohigh" } },
	{ key = "stepup", sequences = { "stepuprightleg" } },
	{ key = "springboard", sequences = { "springboardleftleg" } },
	{ key = "slide", sequences = { "meslidestart", "meslideloop", "meslideend", "meslideendcrouch", "meslideendprone", "meslidestart45", "meslideloop45", "slidestart", "slideloop", "slideend" } },
	{ key = "dive", sequences = { "divestart", "diveidle", "diveslidestart", "diveslideidle", "diveslideend", "diveslideendcrouch", "diveslidetomelee" } },
	{ key = "melee", sequences = { "meleeair", "meleeairhit", "meleeairstill", "meleeslide", "meleewrleft", "meleewrright", "kick" } },
	{ key = "dropkick", sequences = { "jumpcoilkick", "jumpcoilkickhit" } },
	{ key = "punch", sequences = { "punchright", "punchleft", "punchmid" } },
	{ key = "doors", sequences = { "bargein", "doorbash", "dooranim" } },
	{ key = "wallhand", sequences = { "standhandwallright", "standhandwallleft", "standhandwallboth", "standhandwallrightdown", "standhandwallleftdown", "standhandwallbothdown" } },
	{ key = "ladder", sequences = { "ladderenterbottom", "ladderclimbhangstart", "ladderclimbuplefthand", "ladderclimbuplefthandstill", "ladderclimbuprighthand", "ladderclimbuprighthandstill", "ladderexittoplefthand", "ladderexittoprighthand", "ladderclimbdownfast" } },
	{ key = "zipline", sequences = { "ziplinestart", "zipline", "jumpzipline" } },
	{ key = "balance", sequences = { "walkbalancefwd", "walkbalancestill", "walkbalancedfwdlean", "walkbalancedstilllean", "walkbalancelosebalanceleft", "walkbalancelosebalanceright", "walkbalancefalloffleft", "walkbalancefalloffright" } },
	{ key = "swingbar", sequences = { "swing", "swingstraight", "swingjumpoff" } },
	{ key = "grapple", sequences = { "grapplecenter", "grapplepose" } },
	{ key = "disarm", sequences = { "snatchscar", "snatchsniper" } },
	{ key = "swim", sequences = { "water_in", "water_float", "water_swimfwd", "water_swimright", "water_swimleft", "water_swimback" } },
	{ key = "matfall", sequences = { "falldown" } },
	{ key = "death", sequences = { "diestand", "diestandlong", "standhurt" } }
}

local actionconvar = {} -- sequence name -> override convar

for _, action in ipairs(BEATRUN_ANIM_ACTIONS) do
	action.convar = "Beatrun_AnimSet_" .. action.key
	action.label = "#beatrun.toolsmenu.animations.action." .. action.key

	local cvar = CreateClientConVar(action.convar, tostring(BEATRUN_ANIMSET_DEFAULT), true, false, "Animation set for this action: -1 = Default (Beatrun_AnimSet), 0 = Reanimated, 1 = Original", -1, 1)

	for _, seq in ipairs(action.sequences) do
		actionconvar[seq] = cvar
	end
end

-- Animation set (0 or 1) a sequence should play from
function BeatrunAnimSetFor(seq)
	local set = AnimSet:GetInt() == 0 and 0 or 1

	if PerAction:GetBool() then
		local cvar = seq and actionconvar[seq]
		local override = cvar and cvar:GetInt()

		if override == BEATRUN_ANIMSET_REANIMATED or override == BEATRUN_ANIMSET_ORIGINAL then
			set = override
		end
	end

	return set
end

-- Model name (without "models/" and ".mdl") a sequence should play from
function BeatrunAnimModel(seq)
	return BEATRUN_ANIMSET_MODELS[BeatrunAnimSetFor(seq)]
end

-- Saving between sessions. The convars are archived, but the engine only writes those to client.vcfg on a clean
-- exit, so a map change, a disconnect or a crash could lose them. The selection is kept in its own file too,
-- written whenever something changes and loaded back on every map
local SAVE_DIR = "beatrun/local"
local SAVE_FILE = SAVE_DIR .. "/animsets.json"

-- Convar name -> allowed values
local saved = {
	Beatrun_AnimSet = { [0] = true, [1] = true },
	Beatrun_AnimSetPerAction = { [0] = true, [1] = true }
}

local actionvalues = {
	[BEATRUN_ANIMSET_DEFAULT] = true,
	[BEATRUN_ANIMSET_REANIMATED] = true,
	[BEATRUN_ANIMSET_ORIGINAL] = true
}

for _, action in ipairs(BEATRUN_ANIM_ACTIONS) do
	saved[action.convar] = actionvalues
end

local function SaveAnimSets()
	local data = {}

	for name in pairs(saved) do
		local cvar = GetConVar(name)
		if cvar then data[name] = cvar:GetInt() end
	end

	file.CreateDir(SAVE_DIR)
	file.Write(SAVE_FILE, util.TableToJSON(data, true))
end

local function LoadAnimSets()
	local data = util.JSONToTable(file.Read(SAVE_FILE, "DATA") or "")
	if not istable(data) then return end

	for name, value in pairs(data) do
		local allowed = saved[name]
		local cvar = GetConVar(name)
		value = tonumber(value)

		if allowed and cvar and value and allowed[value] and cvar:GetInt() ~= value then
			cvar:SetInt(value)
		end
	end
end

LoadAnimSets()

for name in pairs(saved) do
	cvars.AddChangeCallback(name, function()
		-- Debounced, "Reset all to default" changes every action at once
		timer.Create("BeatrunAnimSetsSave", 0.5, 1, SaveAnimSets)
	end, "BeatrunAnimSetsSave")
end

-- Changing map right after picking something would skip the pending save
hook.Add("ShutDown", "BeatrunAnimSetsSave", function()
	if timer.Exists("BeatrunAnimSetsSave") then
		timer.Remove("BeatrunAnimSetsSave")
		SaveAnimSets()
	end
end)
