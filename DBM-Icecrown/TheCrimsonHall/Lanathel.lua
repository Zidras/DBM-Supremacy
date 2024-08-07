local mod	= DBM:NewMod("Lanathel", "DBM-Icecrown", 3)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20240807131049")
mod:SetCreatureID(37955)
mod:SetModelID("creature/bloodqueen/bloodqueen.m2")
mod:SetUsedIcons(1, 2, 3, 4, 7)
mod:SetMinSyncRevision(20220630221430)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 71340 71510 70838 70877 71474 70867 70879 71473 71525 71530 71531 71532 71533 70923 71772",
	"SPELL_AURA_REMOVED 71340 71510 70838 70877 71474",
	"SPELL_CAST_SUCCESS 73070 71772",
	"SPELL_DAMAGE 71726 71727 71728 71729 71277 72638 72639 72640 72637",
	"SPELL_MISSED 71726 71727 71728 71729 71277 72638 72639 72640 72637",
	-- "SPELL_PERIODIC_DAMAGE",
	-- "SPELL_PERIODIC_MISSED",
	"CHAT_MSG_RAID_BOSS_EMOTE"
)

local warnPactDarkfallen			= mod:NewTargetAnnounce(71340, 4)
local warnPactDarkfallenSoon		= mod:NewSoonAnnounce(71340, 4, nil, nil, nil, nil, nil, 2)
local warnBloodMirror				= mod:NewTargetNoFilterAnnounce(71510, 3, nil, "Tank|Healer")
local warnSwarmingShadows			= mod:NewTargetAnnounce(71266, 4)
local warnSwarmingShadowsSoon		= mod:NewSoonAnnounce(71266, 4, nil, nil, nil, nil, nil, 2)
local warnInciteTerror				= mod:NewSpellAnnounce(73070, 3, nil, nil, nil, nil, nil, 2)
local warnInciteTerrorSoon			= mod:NewSoonAnnounce(73070, 3, nil, nil, nil, nil, nil, 2)
local warnVampiricBite				= mod:NewTargetNoFilterAnnounce(70946, 2)
local warnBloodthirstSoon			= mod:NewSoonAnnounce(70877, 2)
local warnBloodthirst				= mod:NewTargetNoFilterAnnounce(70877, 3, nil, false)
local warnEssenceoftheBloodQueen	= mod:NewTargetNoFilterAnnounce(70867, 3, nil, false)

local specWarnBloodBolt				= mod:NewSpecialWarningSpell(71772, nil, nil, nil, 2, 2)
local specWarnPactDarkfallen		= mod:NewSpecialWarningYou(71340, nil, nil, nil, 1, 2)
local specWarnEssenceoftheBloodQueen= mod:NewSpecialWarningYou(70867, nil, nil, nil, 1, 2)
local specWarnBloodthirst			= mod:NewSpecialWarningYou(70877, nil, nil, nil, 3, 2)
local yellBloodthirst				= mod:NewYellMe(70877, L.YellFrenzy)
local specWarnSwarmingShadows		= mod:NewSpecialWarningYou(71266, nil, nil, nil, 4, 2)
local specWarnMindConrolled			= mod:NewSpecialWarningTarget(70923, "-Healer", nil, nil, 1, 2)
local specWarnGTFO					= mod:NewSpecialWarningGTFO(71266, nil, nil, nil, 1, 8)

local timerNextInciteTerror			= mod:NewCDTimer(120, 73070, nil, nil, nil, 6) -- Fixed timer on EVENT_AIR_PHASE: 100s on 25man, else 120s + variable movement to POINT_CENTER (I will disconsider this movement)
local timerFirstBite				= mod:NewNextTimer(15, 70946, nil, "Dps", nil, 5) -- Fixed timer: 15s
local timerNextPactDarkfallen		= mod:NewNextTimer(30, 71340, nil, nil, nil, 3)
local timerNextSwarmingShadows		= mod:NewNextTimer(30, 71266, nil, nil, nil, 3)
local timerInciteTerror				= mod:NewBuffActiveTimer(4, 73070)
local timerBloodBolt				= mod:NewBuffActiveTimer(6, 71772, nil, nil, nil, 2, nil, DBM_COMMON_L.HEALER_ICON)
local timerBloodThirst				= mod:NewBuffFadesTimer(10, 70877, nil, nil, nil, 5)
local timerEssenceoftheBloodQueen	= mod:NewBuffFadesTimer(60, 70867, nil, nil, nil, 5, nil, DBM_COMMON_L.DAMAGE_ICON)

local berserkTimer					= mod:NewBerserkTimer(330)

mod:AddRangeFrameOption(8, 71446)
mod:AddInfoFrameOption(70867, true)
mod:AddSetIconOption("BloodMirrorIcon", 71510, false, 0, {7})--red x for blood link
mod:AddSetIconOption("SwarmingShadowsIcon", 71266, true, 0, {4})
mod:AddSetIconOption("SetIconOnDarkFallen", 71340, true, 0, {1, 2, 3})

local essence = DBM:GetSpellInfoNew(70867)
local pactTargets = {}
mod.vb.pactIcons = 1

local function warnPactTargets(self)
	warnPactDarkfallen:Show(table.concat(pactTargets, "<, >"))
	table.wipe(pactTargets)
	timerNextPactDarkfallen:Start() -- Not accurate, should be fired on EVENT_PACT_OF_THE_DARKFALLEN, but is negligible (~1s)
	warnPactDarkfallenSoon:Schedule(25)
	warnPactDarkfallenSoon:ScheduleVoice(25, "linesoon")
	self.vb.pactIcons = 1
end

local function pointGround()
	timerNextSwarmingShadows:Restart(20) --This resets the swarming shadows timer
	warnSwarmingShadowsSoon:Schedule(15)
	warnSwarmingShadowsSoon:ScheduleVoice(15, "flamessoon")
	timerNextPactDarkfallen:Restart(5) --and the Pact timer also reset -5 seconds
	warnPactDarkfallenSoon:Show()
	warnPactDarkfallenSoon:Play("linesoon")
end

function mod:OnCombatStart(delay)
	berserkTimer:Start(-delay)
	timerFirstBite:Start(-delay)
	timerNextPactDarkfallen:Start(20-delay) -- Fixed timer: 20s
	warnPactDarkfallenSoon:Schedule(10-delay)
	warnPactDarkfallenSoon:ScheduleVoice(10-delay, "linesoon")
	timerNextSwarmingShadows:Start(-delay) -- Fixed timer: 30s
	warnSwarmingShadowsSoon:Schedule(25-delay)
	warnSwarmingShadowsSoon:ScheduleVoice(25-delay, "flamessoon")
	table.wipe(pactTargets)
	self.vb.pactIcons = 1
	if self.Options.RangeFrame then
		DBM.RangeCheck:Show(8)
	end
	if self:IsDifficulty("normal25", "heroic25") then -- Fixed timer on EVENT_AIR_PHASE: 127s on 25man, else 124s + variable movement to POINT_CENTER (I will disconsider this movement)
		timerNextInciteTerror:Start(127-delay)
		warnInciteTerrorSoon:Schedule(122-delay)
		warnInciteTerrorSoon:ScheduleVoice(122-delay, "fearsoon")
	else
		timerNextInciteTerror:Start(124-delay)
		warnInciteTerrorSoon:Schedule(119-delay)
		warnInciteTerrorSoon:ScheduleVoice(119-delay, "fearsoon")
	end
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
	if self.Options.InfoFrame then
		DBM.InfoFrame:Hide()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 71340 then		--Pact of the Darkfallen
		pactTargets[#pactTargets + 1] = args.destName
		if args:IsPlayer() then
			specWarnPactDarkfallen:Show()
			specWarnPactDarkfallen:Play("linegather")
		end
		if self.Options.SetIconOnDarkFallen then
			self:SetIcon(args.destName, self.vb.pactIcons)
		end
		self.vb.pactIcons = self.vb.pactIcons + 1
		self:Unschedule(warnPactTargets)
		if #pactTargets >= 3 then
			warnPactTargets(self)
		else
			self:Schedule(0.3, warnPactTargets, self)
		end
	elseif args:IsSpellID(71510, 70838) then
		warnBloodMirror:Show(args.destName)
		if self.Options.BloodMirrorIcon then
			self:SetIcon(args.destName, 7)
		end
	elseif args:IsSpellID(70877, 71474) then
		warnBloodthirst:Show(args.destName)
		if args:IsPlayer() then
			specWarnBloodthirst:Show()
			specWarnBloodthirst:Play("frenzy")--Eh, closest voice to blood thirst
			yellBloodthirst:Yell()
			if self:IsDifficulty("normal10", "heroic10") then
				timerBloodThirst:Start(15)--15 seconds on 10 man
			else
				timerBloodThirst:Start()--10 seconds on 25 man
			end
		end
	elseif args:IsSpellID(70867, 70879, 71473, 71525) or args:IsSpellID(71530, 71531, 71532, 71533) then	--Essence of the Blood Queen
		warnEssenceoftheBloodQueen:Show(args.destName)
		if self.Options.InfoFrame then
			DBM.InfoFrame:SetHeader(essence)
			DBM.InfoFrame:Show(16, "playerdebuffremaining", essence, 3)
		end
		if args:IsPlayer() then
			specWarnEssenceoftheBloodQueen:Show()
			specWarnEssenceoftheBloodQueen:Play("targetyou")
			if self:IsDifficulty("normal10", "heroic10") then
				timerEssenceoftheBloodQueen:Start(75)--75 seconds on 10 man
				warnBloodthirstSoon:Schedule(70)
			else
				timerEssenceoftheBloodQueen:Start()--60 seconds on 25 man
				warnBloodthirstSoon:Schedule(55)
			end
		end
	elseif spellId == 70923 then
		specWarnMindConrolled:Show(args.destName)
		specWarnMindConrolled:Play("findmc")
	elseif spellId == 71772 then
		specWarnBloodBolt:Show()
		specWarnBloodBolt:Play("scatter")
		timerBloodBolt:Start()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 71340 then				--Pact of the Darkfallen
		if self.Options.SetIconOnDarkFallen then
			self:SetIcon(args.destName, 0)		--Clear icon once you got to where you are supposed to be
		end
	elseif args:IsSpellID(71510, 70838) then	--Blood Mirror
		if self.Options.BloodMirrorIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(70877, 71474) then
		if args:IsPlayer() then
			timerBloodThirst:Cancel()
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 73070 then				--Incite Terror (fear before air phase)
		-- POINT_CENTER
		warnInciteTerror:Show()
		timerInciteTerror:Start()
		if self:IsDifficulty("normal25", "heroic25") then -- Fixed timer on EVENT_AIR_PHASE: 100s on 25man, else 120s + variable movement to POINT_CENTER (I will disconsider this movement)
			timerNextInciteTerror:Start(100) -- 100 seconds in between first and second on 25 man
			warnInciteTerrorSoon:Schedule(95)
			warnInciteTerrorSoon:ScheduleVoice(95, "fearsoon")
		else
			timerNextInciteTerror:Start() -- 120 seconds in between first and second on 10 man
			warnInciteTerrorSoon:Schedule(115)
			warnInciteTerrorSoon:ScheduleVoice(115, "fearsoon")
		end
		-- EVENT_AIR_START_FLYING: 2.5s
	elseif spellId == 71772 then -- Bloodbolt Whirl
		-- POINT_AIR
		-- EVENT_AIR_FLY_DOWN: 7s. Estimation of when POINT_GROUND is reached, based on timer difference of logs (Bloodbolt Whirl or SAY_AIR_PHASE, fired on POINT_AIR, and UNIT_TARGET, fired on POINT_GROUND by me->SetReactState(REACT_AGGRESSIVE)) (10N [2024-07-29]@[19:37:57]) - 151.39-139.54 [11.85]
		self:Schedule(4.85, pointGround) -- 11.85-7
	end
end

function mod:SPELL_DAMAGE(sourceGUID, _, _, destGUID, destName, _, spellId, spellName)
	if (spellId == 71726 or spellId == 71727 or spellId == 71728 or spellId == 71729) and self:GetCIDFromGUID(sourceGUID) == 37955 then	-- Vampiric Bite (first bite only, hers)
		warnVampiricBite:Show(destName)
	elseif (spellId == 71277 or spellId == 72638 or spellId == 72639 or spellId == 72640 or spellId == 72637) and destGUID == UnitGUID("player") and self:AntiSpam() then		--Swarming Shadows (spell damage, you're standing in it.)
		specWarnGTFO:Show(spellName)
		specWarnGTFO:Play("watchfeet")
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

-- function mod:SPELL_PERIODIC_DAMAGE(_, _, _, destGUID, _, _, spellId)
--	if (spellId == 71277 or spellId == 72638 or spellId == 72639 or spellId == 72640 or spellId == 72637) and destGUID == UnitGUID("player") and self:AntiSpam() then		--Swarn of Shadows (spell damage, you're standing in it.)
--		specWarnSwarmingShadows:Show()
--		specWarnSwarmingShadows:Play("runaway")
--	end
-- end
-- mod.SPELL_PERIODIC_MISSED = mod.SPELL_PERIODIC_DAMAGE

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg, _, _, _, target)
	if msg:match(L.SwarmingShadows) and target then
		target = DBM:GetUnitFullName(target)
		timerNextSwarmingShadows:Start()
		warnSwarmingShadowsSoon:Schedule(25.5)
		warnSwarmingShadowsSoon:ScheduleVoice(25.5, "flamessoon")
		if target == UnitName("player") then
			specWarnSwarmingShadows:Show()
			specWarnSwarmingShadows:Play("runout")
			specWarnSwarmingShadows:ScheduleVoice(1.5, "keepmove")
		else
			warnSwarmingShadows:Show(target)
		end
		if self.Options.SwarmingShadowsIcon then
			self:SetIcon(target, 4, 6)
		end
	end
end
