local mod	= DBM:NewMod("Putricide", "DBM-Icecrown", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20240806233437")
mod:SetCreatureID(36678)
mod:SetUsedIcons(1, 2, 3, 4)
mod:SetHotfixNoticeRev(20240611000000)
mod:SetMinSyncRevision(20220908000000)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 70351 71966 71967 71968 71617 72842 72843 72851 72852 71621 72850 70672 72455 72832 72833 73121 73122 73120 71893",
	"SPELL_CAST_SUCCESS 70341 71255 72855 72856 70911 72615 72295 74280 74281",
	"SPELL_AURA_APPLIED 70447 72836 72837 72838 70672 72455 72832 72833 72451 72463 72671 72672 70542 70539 72457 72875 72876 70352 74118 70353 74119 72855 72856 70911",
	"SPELL_AURA_APPLIED_DOSE 72451 72463 72671 72672 70542",
	"SPELL_AURA_REFRESH 70539 72457 72875 72876 70542",
	"SPELL_AURA_REMOVED 70447 72836 72837 72838 70672 72455 72832 72833 72855 72856 70911 71615 70539 72457 72875 72876 70542",
	"SPELL_SUMMON 70342",
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"UNIT_HEALTH"
)

-- General
local berserkTimer					= mod:NewBerserkTimer(600)

-- buffs from "Drink Me"
local timerMutatedSlash				= mod:NewTargetTimer(20, 70542, nil, false, nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerRegurgitatedOoze			= mod:NewTargetTimer(20, 70539, nil, nil, nil, 5, nil, DBM_COMMON_L.TANK_ICON)

-- Stage One
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1)..": 100% – 80%")
local warnSlimePuddle				= mod:NewSpellAnnounce(70341, 2)
local warnUnstableExperimentSoon	= mod:NewSoonAnnounce(70351, 3)
local warnUnstableExperiment		= mod:NewSpellAnnounce(70351, 4)
local warnVolatileOozeAdhesive		= mod:NewTargetNoFilterAnnounce(70447, 3)
local warnGaseousBloat				= mod:NewTargetNoFilterAnnounce(70672, 3)
local warnUnboundPlague				= mod:NewTargetNoFilterAnnounce(70911, 3, nil, false, nil, nil, nil, true)		-- Heroic Ability, sound muted

local specWarnVolatileOozeAdhesive	= mod:NewSpecialWarningYou(70447, nil, nil, nil, 1, 2)
local specWarnVolatileOozeAdhesiveT	= mod:NewSpecialWarningMoveTo(70447, nil, nil, nil, 1, 2)
local specWarnGaseousBloat			= mod:NewSpecialWarningRun(70672, nil, nil, nil, 4, 2)
local specWarnGaseousBloatCast		= mod:NewSpecialWarningMove(72833, nil, nil, nil, 1, 2)		-- Gaseous Bloat (cast)
local specWarnUnboundPlague			= mod:NewSpecialWarningYou(70911, nil, nil, nil, 1, 2, 3)	-- Heroic Ability
local yellUnboundPlague				= mod:NewYellMe(70911, false)	-- Heroic Ability, disabled by default to reduce chat bubble spam

local timerGaseousBloat				= mod:NewTargetTimer(20, 70672, nil, nil, nil, 3)			-- Duration of debuff
local timerGaseousBloatCast			= mod:NewCastTimer(3, 70672, nil, nil, nil, 3)				-- Cast duration
local timerSlimePuddleCD			= mod:NewNextTimer(35, 70341, nil, nil, nil, 5, nil, DBM_COMMON_L.TANK_ICON) -- Fixed timer: 35s
local timerUnstableExperimentCD		= mod:NewCDTimer(35, 70351, nil, nil, nil, 1, nil, DBM_COMMON_L.DEADLY_ICON, true) -- 5s variance [35-40]. Added "keep" arg
local timerUnboundPlagueCD			= mod:NewNextTimer(90, 70911, nil, nil, nil, 3, nil, DBM_COMMON_L.HEROIC_ICON)
local timerUnboundPlague			= mod:NewBuffActiveTimer(12, 70911, nil, nil, nil, 3)		-- Heroic Ability: we can't keep the debuff 60 seconds, so we have to switch at 12-15 seconds. Otherwise the debuff does to much damage!

local soundSlimePuddle				= mod:NewSound(70341)

mod:AddSetIconOption("OozeAdhesiveIcon", 70447, true, 0, {4})--green icon for green ooze
mod:AddSetIconOption("GaseousBloatIcon", 70672, true, 0, {2})--Orange Icon for orange/red ooze
mod:AddSetIconOption("UnboundPlagueIcon", 70911, true, 0, {3})

-- Stage Two
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2)..": 80% – 35%")
local warnPhase2					= mod:NewPhaseAnnounce(2, 2, nil, nil, nil, nil, nil, 2)
local warnChokingGasBombSoon		= mod:NewPreWarnAnnounce(71255, 5, 3, nil, "Melee")
local warnChokingGasBomb			= mod:NewSpellAnnounce(71255, 3, nil, "Melee")		-- Phase 2 ability

local specWarnChokingGasBomb		= mod:NewSpecialWarningMove(71255, "Melee", nil, nil, 1, 2)
local specWarnMalleableGooCast		= mod:NewSpecialWarningSpell(72295, "Ranged", nil, nil, 2, 2)

local timerChokingGasBombCD			= mod:NewCDTimer(35, 71255, nil, nil, nil, 3, nil, nil, true) -- 5s variance [35-40]. Added "keep" arg
local timerChokingGasBombExplosion	= mod:NewCastTimer(12, 71279, nil, nil, nil, 2)
local timerMalleableGooCD			= mod:NewCDTimer(25, 72295, nil, nil, nil, 3, nil, nil, true) -- 5s variance [25-30]. Added "keep" arg

local soundSpecWarnMalleableGoo		= mod:NewSound(72295, nil, "Ranged")
local soundMalleableGooSoon			= mod:NewSoundSoon(72295, nil, "Ranged")
local soundSpecWarnChokingGasBomb	= mod:NewSound(71255, nil, "Melee")
local soundChokingGasSoon			= mod:NewSoundSoon(71255, nil, "Melee")

--mod:AddSetIconOption("MalleableGooIcon", 72295, true, 0, {1})
--mod:AddArrowOption("GooArrow", 72295)

-- Stage Three
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(3)..": 35% – 0%")
local warnPhase3					= mod:NewPhaseAnnounce(3, 2, nil, nil, nil, nil, nil, 2)
local warnMutatedPlague				= mod:NewStackAnnounce(72451, 3, nil, "Tank|Healer|RemoveEnrage") -- Phase 3 ability

local timerMutatedPlagueCD			= mod:NewCDTimer(10, 72451, nil, "Tank|Healer|RemoveEnrage", nil, 5, nil, DBM_COMMON_L.TANK_ICON)				-- 10 to 11

-- Intermission
mod:AddTimerLine(DBM_COMMON_L.INTERMISSION)
local warnPhase2Soon				= mod:NewPrePhaseAnnounce(2)
local warnPhase3Soon				= mod:NewPrePhaseAnnounce(3)
local warnTearGas					= mod:NewSpellAnnounce(71617, 2)		-- Phase transition normal
local warnVolatileExperiment		= mod:NewSpellAnnounce(72843, 4)		-- Phase transition heroic
local warnReengage					= mod:NewAnnounce("WarnReengage", 6, 1180)

local specWarnOozeVariable			= mod:NewSpecialWarningYou(70352, nil, nil, nil, nil, nil, 3)	-- Heroic Ability
local specWarnGasVariable			= mod:NewSpecialWarningYou(70353, nil, nil, nil, nil, nil, 3)	-- Heroic Ability

local timerNextPhase				= mod:NewPhaseTimer(30)
local timerReengage					= mod:NewTimer(20, "TimerReengage", 1180, nil, nil, 6)
--local timerTearGas					= mod:NewBuffFadesTimer(16, 71617, nil, nil, nil, 6)
--local timerPotions					= mod:NewBuffActiveTimer(30, 71621, nil, nil, nil, 6)

mod:GroupSpells(71255, 71279) -- Choking Gas Bomb, Choking Gas Explosion

local redOozeGUIDsCasts = {}
local heroicDelay = 0
local timerDelay = 0 -- events.DelayEvents(24000 + heroicDelay, EVENT_GROUP_ABILITIES)
mod.vb.warned_preP2 = false
mod.vb.warned_preP3 = false
mod.vb.unboundCount = 0

local function NextPhase(self)
	self:SetStage(self.vb.phase + 0.5)
	if self.vb.phase == 2 then
		warnPhase2:Show()
		warnPhase2:Play("ptwo")
		-- EVENT_PHASE_TRANSITION - scheduled for Create Concoction cast + 2.25s (will fire [CHAT_MSG_MONSTER_YELL] Hrm, I don't feel a thing. Wha?! Where'd those come from?)
	elseif self.vb.phase == 3 then
		warnPhase3:Show()
		warnPhase3:Play("pthree")
		-- EVENT_PHASE_TRANSITION - scheduled for Guzzle Potions cast + 2.25s (will fire [CHAT_MSG_MONSTER_YELL] Tastes like... Cherry! OH! Excuse me!)
	end
end

function mod:OnCombatStart(delay)
	self:SetStage(1)
	berserkTimer:Start(-delay)
	timerSlimePuddleCD:Start(10-delay) -- Fixed timer: 10s. Belongs to EVENT_GROUP_ABILITIES
	timerUnstableExperimentCD:Start(30-delay) -- 5s variance [30-35]. Belongs to EVENT_GROUP_ABILITIES
	warnUnstableExperimentSoon:Schedule(25-delay)
	table.wipe(redOozeGUIDsCasts)
	heroicDelay = 0
	self.vb.warned_preP2 = false
	self.vb.warned_preP3 = false
	self.vb.unboundCount = 0
	if self:IsHeroic() then
		timerUnboundPlagueCD:Start(20-delay) -- Fixed timer: 20s. Belongs to EVENT_GROUP_ABILITIES
	end
end

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if args:IsSpellID(70351, 71966, 71967, 71968) then	-- Unstable Experiment
		warnUnstableExperimentSoon:Cancel()
		warnUnstableExperiment:Show()
		timerUnstableExperimentCD:Start() -- Belongs to EVENT_GROUP_ABILITIES
		warnUnstableExperimentSoon:Schedule(30)
	elseif spellId == 71617 then				--Tear Gas (stun all on Normal phase) (Normal intermission)
		self:SetStage(self.vb.phase + 0.5) -- ACTION_CHANGE_PHASE
		timerDelay = 24 -- Delay EVENT_GROUP_ABILITIES
		warnTearGas:Show()
		warnUnstableExperimentSoon:Cancel()
		timerSlimePuddleCD:AddTime(timerDelay)
		if self.vb.phase == 1.5 then -- _phase == 2
			timerUnstableExperimentCD:AddTime(timerDelay)
			warnUnstableExperimentSoon:Schedule(timerUnstableExperimentCD:GetRemaining()-3)
			timerMalleableGooCD:Start(25) -- 3s variance [25-28] + heroicDelay (0 on Normal)
			soundMalleableGooSoon:Schedule(25-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable_soon.mp3")
			timerChokingGasBombCD:Start() -- 5s variance [35-40] + heroicDelay (0 on Normal)
			soundChokingGasSoon:Schedule(35-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\choking_soon.mp3")
			warnChokingGasBombSoon:Schedule(35-5)
		elseif self.vb.phase == 2.5 then -- _phase == 3
			timerUnstableExperimentCD:Cancel()
			timerMalleableGooCD:AddTime(timerDelay)
			soundMalleableGooSoon:Cancel()
			soundMalleableGooSoon:Schedule(timerMalleableGooCD:GetRemaining()-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable_soon.mp3")
			timerChokingGasBombCD:AddTime(timerDelay)
			local chokingRemaining = timerChokingGasBombCD:GetRemaining()
			soundChokingGasSoon:Cancel()
			soundChokingGasSoon:Schedule(chokingRemaining-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\choking_soon.mp3")
			warnChokingGasBombSoon:Cancel()
			warnChokingGasBombSoon:Schedule(chokingRemaining-5)
		end
	elseif args:IsSpellID(72842, 72843) then		--Volatile Experiment (Heroic intermission)
		DBM:AddMsg("Volatile Experiment SPELL_CAST_START script fixed. Notify Zidras on Discord or GitHub")
		self:SetStage(self.vb.phase + 0.5) -- ACTION_CHANGE_PHASE
		heroicDelay = 25
		timerDelay = 24 + heroicDelay -- Delay EVENT_GROUP_ABILITIES
		warnVolatileExperiment:Show()
		warnUnstableExperimentSoon:Cancel()
		timerSlimePuddleCD:AddTime(timerDelay)
		timerUnboundPlagueCD:AddTime(timerDelay)
		if self.vb.phase == 1.5 then
			timerUnstableExperimentCD:AddTime(timerDelay)
			warnUnstableExperimentSoon:Schedule(timerUnstableExperimentCD:GetRemaining()-3)
			timerMalleableGooCD:Start(50) -- 3s variance [25-28] + heroicDelay (25 on Heroic) = [50-53]
			soundMalleableGooSoon:Schedule(50-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable_soon.mp3")
			timerChokingGasBombCD:Start(60) -- 5s variance [35-40] + heroicDelay (25 on Heroic) = [60-65]
			soundChokingGasSoon:Schedule(60-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\choking_soon.mp3")
			warnChokingGasBombSoon:Schedule(60-5)
		elseif self.vb.phase == 2.5 then -- _phase == 3
			timerUnstableExperimentCD:Cancel()
			timerMalleableGooCD:AddTime(timerDelay)
			soundMalleableGooSoon:Cancel()
			soundMalleableGooSoon:Schedule(timerMalleableGooCD:GetRemaining()-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable_soon.mp3")
			timerChokingGasBombCD:AddTime(timerDelay)
			local chokingRemaining = timerChokingGasBombCD:GetRemaining()
			soundChokingGasSoon:Cancel()
			soundChokingGasSoon:Schedule(chokingRemaining-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\choking_soon.mp3")
			warnChokingGasBombSoon:Cancel()
			warnChokingGasBombSoon:Schedule(chokingRemaining-5)
		end
	elseif args:IsSpellID(72851, 72852, 71621, 72850) then		--Create Concoction (phase2 change)
		local castTime = 4 -- REVIEW! Does Heroic have different cast times? Hardcode the cast time in seconds. DO NOT USE GetSpellInfo API here, as it is affected by player Haste.
		timerNextPhase:Start(castTime+2.25) -- Schedule EVENT_PHASE_TRANSITION + 2250
	elseif args:IsSpellID(70672, 72455, 72832, 72833) then	--Red Slime
		timerGaseousBloatCast:Start(args.sourceGUID) -- account for multiple red oozes
		if not redOozeGUIDsCasts[args.sourceGUID] then
			redOozeGUIDsCasts[args.sourceGUID] = 1
		else
			redOozeGUIDsCasts[args.sourceGUID] = redOozeGUIDsCasts[args.sourceGUID] + 1
		end
		if redOozeGUIDsCasts[args.sourceGUID] > 1 then -- Red Ooze retarget
			specWarnGaseousBloatCast:Show()
			specWarnGaseousBloatCast:Play("targetchange")
		end
	elseif args:IsSpellID(73121, 73122, 73120, 71893) then		--Guzzle Potions (phase3 change)
		local castTime = 4 -- REVIEW! Does Heroic have different cast times? Hardcode the cast time in seconds. DO NOT USE GetSpellInfo API here, as it is affected by player Haste.
		timerNextPhase:Start(castTime+2.25) -- Schedule EVENT_PHASE_TRANSITION + 2250
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 70341 and self:AntiSpam(5, 1) then
		DBM:AddMsg("Slime Puddle SPELL_CAST_SUCCESS unhidden from combat log. Notify Zidras on Discord or GitHub") -- It does not fire on UltimoWow. Replaced with SPELL_SUMMON
		warnSlimePuddle:Show()
		soundSlimePuddle:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\puddle_cast.mp3")
		timerSlimePuddleCD:Start()
	elseif spellId == 71255 then -- Choking Gas
		warnChokingGasBomb:Show()
		specWarnChokingGasBomb:Show()
		soundSpecWarnChokingGasBomb:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\choking.mp3")
		soundChokingGasSoon:Cancel()
		soundChokingGasSoon:Schedule(35-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\choking_soon.mp3")
		timerChokingGasBombCD:Start() -- Belongs to EVENT_GROUP_ABILITIES
		timerChokingGasBombExplosion:Start()
		warnChokingGasBombSoon:Schedule(30)
	elseif args:IsSpellID(72855, 72856, 70911) then
		self.vb.unboundCount = self.vb.unboundCount + 1
		timerUnboundPlagueCD:Start() -- Belongs to EVENT_GROUP_ABILITIES
	elseif args:IsSpellID(72615, 72295, 74280, 74281) then -- Malleable Goo
		DBM:AddMsg("Malleable Goo SPELL_CAST_SUCCESS unhidden from combat log. Notify Zidras on Discord or GitHub") -- It does not fire on this server script. Replaced with CHAT_MSG_RAID_BOSS_EMOTE
		specWarnMalleableGooCast:Show()
		timerMalleableGooCD:Start()
		soundSpecWarnMalleableGoo:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable.mp3")
		soundMalleableGooSoon:Cancel()
		soundMalleableGooSoon:Schedule(20-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable_soon.mp3")
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if args:IsSpellID(70447, 72836, 72837, 72838) then--Green Slime
		if args:IsPlayer() then--Still worth warning 100s because it does still do knockback
			specWarnVolatileOozeAdhesive:Show()
		elseif not self:IsTank() then
			specWarnVolatileOozeAdhesiveT:Show(args.destName)
			specWarnVolatileOozeAdhesiveT:Play("helpsoak")
		else
			warnVolatileOozeAdhesive:Show(args.destName)
		end
		if self.Options.OozeAdhesiveIcon then
			self:SetIcon(args.destName, 1)
		end
	elseif args:IsSpellID(70672, 72455, 72832, 72833) then	--Red Slime
		timerGaseousBloat:Start(args.destName)
		if args:IsPlayer() then
			specWarnGaseousBloat:Show()
			specWarnGaseousBloat:Play("justrun")
			specWarnGaseousBloat:ScheduleVoice(1.5, "keepmove")
		else
			warnGaseousBloat:Show(args.destName)
		end
		if self.Options.GaseousBloatIcon then
			self:SetIcon(args.destName, 2)
		end
	--elseif args:IsSpellID(71615, 71618) then	--71615 used in 10 and 25 normal, 71618?
	--	timerTearGas:Start()
	elseif args:IsSpellID(72451, 72463, 72671, 72672) then	-- Mutated Plague
		warnMutatedPlague:Show(args.destName, args.amount or 1)
		timerMutatedPlagueCD:Start()
	elseif spellId == 70542 then
		timerMutatedSlash:Show(args.destName)
	elseif args:IsSpellID(70539, 72457, 72875, 72876) then
		timerRegurgitatedOoze:Show(args.destName)
	elseif args:IsSpellID(70352, 74118) then	--Ooze Variable
		if args:IsPlayer() then
			specWarnOozeVariable:Show()
		end
	elseif args:IsSpellID(70353, 74119) then	-- Gas Variable
		if args:IsPlayer() then
			specWarnGasVariable:Show()
		end
	elseif args:IsSpellID(72855, 72856, 70911) then	 -- Unbound Plague
		if self.Options.UnboundPlagueIcon then
			self:SetIcon(args.destName, 3)
		end
		if args:IsPlayer() then
			specWarnUnboundPlague:Show()
			specWarnUnboundPlague:Play("targetyou")
			timerUnboundPlague:Start()
			yellUnboundPlague:Yell()
		else
			warnUnboundPlague:Show(args.destName)
		end
	end
end

function mod:SPELL_AURA_APPLIED_DOSE(args)
	if args:IsSpellID(72451, 72463, 72671, 72672) then	-- Mutated Plague
		warnMutatedPlague:Show(args.destName, args.amount or 1)
		timerMutatedPlagueCD:Start()
	elseif args.spellId == 70542 then
		timerMutatedSlash:Show(args.destName)
	end
end

function mod:SPELL_AURA_REFRESH(args)
	if args:IsSpellID(70539, 72457, 72875, 72876) then
		timerRegurgitatedOoze:Show(args.destName)
	elseif args.spellId == 70542 then
		timerMutatedSlash:Show(args.destName)
	end
end

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if args:IsSpellID(70447, 72836, 72837, 72838) then
		if self.Options.OozeAdhesiveIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(70672, 72455, 72832, 72833) then
		timerGaseousBloat:Cancel(args.destName)
		if self.Options.GaseousBloatIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(72855, 72856, 70911) then						-- Unbound Plague
		timerUnboundPlague:Stop(args.destName)
		if self.Options.UnboundPlagueIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif spellId == 71615 and (self.vb.phase == 1.5 or self.vb.phase == 2.5) then	-- Tear Gas Removal. Requires phase check because sometimes Tear Gas is removed from Abomination much later than the rest of the raid, during phase 2, causing another phasing to 2.5 (Logs: 10N Frostmourne [2023-01-07]@[17:20:22] and [2023-01-07]@[17:42:33] || 10N Icecrown [2023-04-05]@[22:54:25])
		DBM:Debug("Re-engaged")
	elseif args:IsSpellID(70539, 72457, 72875, 72876) then
		timerRegurgitatedOoze:Cancel(args.destName)
	elseif spellId == 70542 then
		timerMutatedSlash:Cancel(args.destName)
	elseif (args:IsSpellID(70352, 74118) or args:IsSpellID(70353, 74119)) and (self.vb.phase == 1.5 or self.vb.phase == 2.5) then	-- Ooze Variable / Gas Variable (Heroic 25 - Phase 2 and 3). Disabled for two main reasons: raid member dying will trigger this event, and I have found multiple logs with early SAR
		DBM:Debug("Variable phasing time marker")
	end
end

function mod:SPELL_SUMMON(args)
	local spellId = args.spellId
	if spellId == 70342 and self:AntiSpam(5, 1) then -- Slime Puddle
		warnSlimePuddle:Show()
		soundSlimePuddle:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\puddle_cast.mp3")
		timerSlimePuddleCD:Start() -- Belongs to EVENT_GROUP_ABILITIES
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.HeroicIntermission or msg:find(L.HeroicIntermission) then -- ACTION_CHANGE_PHASE. Workaround to script not firing Volatile Experiment.
		self:SetStage(self.vb.phase + 0.5)
		heroicDelay = 25
		timerDelay = 24 + heroicDelay -- Delay EVENT_GROUP_ABILITIES
		warnUnstableExperimentSoon:Cancel()
		timerSlimePuddleCD:AddTime(timerDelay)
		timerUnboundPlagueCD:AddTime(timerDelay)
		if self.vb.phase == 1.5 then -- _phase == 2
			timerUnstableExperimentCD:AddTime(timerDelay)
			warnUnstableExperimentSoon:Schedule(timerUnstableExperimentCD:GetRemaining()-3)
			timerMalleableGooCD:Start(50) -- 3s variance [25-28] + heroicDelay (25 on Heroic) = [50-53]
			soundMalleableGooSoon:Schedule(50-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable_soon.mp3")
			timerChokingGasBombCD:Start(60) -- 5s variance [35-40] + heroicDelay (25 on Heroic) = [60-65]
			soundChokingGasSoon:Schedule(60-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\choking_soon.mp3")
			warnChokingGasBombSoon:Schedule(60-5)
		elseif self.vb.phase == 2.5 then -- _phase == 3
			timerUnstableExperimentCD:Cancel()
			timerMalleableGooCD:AddTime(timerDelay)
			soundMalleableGooSoon:Cancel()
			soundMalleableGooSoon:Schedule(timerMalleableGooCD:GetRemaining()-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable_soon.mp3")
			timerChokingGasBombCD:AddTime(timerDelay)
			local chokingRemaining = timerChokingGasBombCD:GetRemaining()
			soundChokingGasSoon:Cancel()
			soundChokingGasSoon:Schedule(chokingRemaining-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\choking_soon.mp3")
			warnChokingGasBombSoon:Cancel()
			warnChokingGasBombSoon:Schedule(chokingRemaining-5)
		end
	-- EVENT_RESUME_ATTACK
	elseif msg == L.YellTransform1 or msg:find(L.YellTransform1) then
		NextPhase(self)
		warnReengage:Schedule(5.5, L.name)
		timerReengage:Start(5.5)
	elseif msg == L.YellTransform2 or msg:find(L.YellTransform2) then
		NextPhase(self)
		warnReengage:Schedule(8.5, L.name)
		timerReengage:Start(8.5)
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg:find(L.MalleableGooCastEmote) then -- Malleable Goo. Workaround to missing CLEU event
		specWarnMalleableGooCast:Show()
		timerMalleableGooCD:Start() -- Belongs to EVENT_GROUP_ABILITIES
		soundSpecWarnMalleableGoo:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable.mp3")
		soundMalleableGooSoon:Cancel()
		soundMalleableGooSoon:Schedule(20-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable_soon.mp3")
	end
end

--values subject to tuning depending on dps and his health pool
function mod:UNIT_HEALTH(uId)
	if self.vb.phase == 1 and not self.vb.warned_preP2 and self:GetUnitCreatureId(uId) == 36678 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.83 then
		self.vb.warned_preP2 = true
		warnPhase2Soon:Show()
		warnPhase2Soon:Play("nextphasesoon")
	elseif self.vb.phase == 2 and not self.vb.warned_preP3 and self:GetUnitCreatureId(uId) == 36678 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.38 then
		self.vb.warned_preP3 = true
		warnPhase3Soon:Show()
		warnPhase3Soon:Play("nextphasesoon")
	elseif self:GetUnitCreatureId(uId) == 36678 and UnitHealth(uId) / UnitHealthMax(uId) == 0.35 then
		warnUnstableExperimentSoon:Cancel()
		warnChokingGasBombSoon:Cancel()
		soundMalleableGooSoon:Cancel()
		soundChokingGasSoon:Cancel()
	end
end
