local mod	= DBM:NewMod("Halion", "DBM-ChamberOfAspects", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20240820085055")
mod:SetCreatureID(39863)--40142 (twilight form)
mod:SetUsedIcons(7, 3)
mod:SetMinSyncRevision(4358) -- try to preserve this as much as possible to receive old DBM comms

mod:RegisterCombat("combat")
--mod:RegisterKill("yell", L.Kill)

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 74806 75954 75955 75956 74525 74526 74527 74528",
	"SPELL_CAST_SUCCESS 74792 74562",
	"SPELL_AURA_APPLIED 74792 74562",
	"SPELL_AURA_REMOVED 74792 74562",
	"SPELL_DAMAGE",
	"SPELL_MISSED",
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"UPDATE_WORLD_STATES",
	"UNIT_HEALTH boss1"
)

-- General
local berserkTimer					= mod:NewBerserkTimer(480)

mod:AddBoolOption("AnnounceAlternatePhase", true, "announce")

-- Stage One - Physical Realm (100%)
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1)..": "..L.PhysicalRealm)
local warnPhase2Soon				= mod:NewPrePhaseAnnounce(2)
local warningFieryCombustion		= mod:NewTargetNoFilterAnnounce(74562, 4)
local warningMeteor					= mod:NewSpellAnnounce(74648, 3)
local warningFieryBreath			= mod:NewSpellAnnounce(74525, 2, nil, "Tank|Healer")

local specWarnFieryCombustion		= mod:NewSpecialWarningRun(74562, nil, nil, nil, 4, 2)
local yellFieryCombustion			= mod:NewYellMe(74562)
local specWarnMeteorStrike			= mod:NewSpecialWarningMove(74648, nil, nil, nil, 1, 2)

local timerFieryCombustionCD		= mod:NewNextTimer(25, 74562, nil, nil, nil, 3) -- Fixed timer: 25s
local timerMeteorCD					= mod:NewNextTimer(40, 74648, nil, nil, nil, 3, nil, DBM_COMMON_L.DEADLY_ICON) -- Target or aoe? tough call. It's a targeted aoe! Fixed timer (after first): 40s. Even though on pull has variance, can't implement "keep" due to OnSync phasing, unless I sync schedule and end timer flag but that's a bit overkill
local timerMeteorCast				= mod:NewCastTimer(7, 74648)--7-8 seconds from boss yell the meteor impacts.
local timerFieryBreathCD			= mod:NewCDTimer(10, 74525, nil, "Tank|Healer", nil, 5, nil, DBM_COMMON_L.TANK_ICON, true) -- 2s variance [10-12]. Added "keep" arg.
local timerTailLashCD				= mod:NewNextTimer(10, 74531, nil, nil, nil, 2) -- Fixed timer: 10s

mod:AddSetIconOption("SetIconOnFireConsumption", 74562, true, false, {7})--Red x for Fire

-- Stage Two - Twilight Realm (75%)
local twilightRealmName = DBM:GetSpellInfo(74807)
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2)..": "..twilightRealmName)
local warnPhase3Soon				= mod:NewPrePhaseAnnounce(3)
local warnPhase2					= mod:NewPhaseAnnounce(2, 2, nil, nil, nil, nil, nil, 2)
local warningSoulConsumption		= mod:NewTargetNoFilterAnnounce(74792, 4)
local warningShadowBreath			= mod:NewSpellAnnounce(74806, 2, nil, "Tank|Healer")
local warningTwilightCutter			= mod:NewAnnounce("TwilightCutterCast", 4, 74769, nil, nil, nil, 74769)

local specWarnSoulConsumption		= mod:NewSpecialWarningRun(74792, nil, nil, nil, 4, 2)
local yellSoulConsumption			= mod:NewYellMe(74792)
local specWarnTwilightCutter		= mod:NewSpecialWarningSpell(74769, nil, nil, nil, 3, 2)

local timerSoulConsumptionCD		= mod:NewNextTimer(20, 74792, nil, nil, nil, 3) -- Fixed timer: 20s
local timerTwilightCutterCast		= mod:NewCastTimer(5, 74769, nil, nil, nil, 3, nil, DBM_COMMON_L.DEADLY_ICON)
local timerTwilightCutter			= mod:NewBuffActiveTimer(10, 74769, nil, nil, nil, 6)
local timerTwilightCutterCD			= mod:NewNextTimer(29, 74769, nil, nil, nil, 6) -- Fixed timer: 29s
local timerTwilightCutterSpawn		= mod:NewTimer(34, "TimerCutterSpawn", 74769, false, nil, 6, nil, nil, nil, nil, nil, nil, nil, 74769) -- Combines CD + Cast, and disables them too
local timerShadowBreathCD			= mod:NewCDTimer(10, 74806, nil, "Tank|Healer", nil, 5, nil, DBM_COMMON_L.TANK_ICON, true) -- 2s variance [10-12]. Added "keep" arg.

mod:AddSetIconOption("SetIconOnShadowConsumption", 74792, true, false, {3})--Purple diamond for shadow

-- Stage Three - Corporeality (50%)
local twilightDivisionName = DBM:GetSpellInfo(75063)
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(3)..": "..twilightDivisionName)
local warnPhase3					= mod:NewPhaseAnnounce(3, 2, nil, nil, nil, nil, nil, 2)

local specWarnCorporeality			= mod:NewSpecialWarningCount(74826, nil, nil, nil, 1, 2)

mod.vb.warned_preP2 = false
mod.vb.warned_preP3 = false
local playerInShadowRealm = false
local fieryCombustionCLEU = false -- Assigning a bool for CLEU check to prevent double timer starts from CLEU & Sync
local fieryBreathCLEU = false -- Assigning a bool for CLEU check to prevent double timer starts from CLEU & Sync
local soulConsumptionCLEU = false -- Assigning a bool for CLEU check to prevent double timer starts from CLEU & Sync
local shadowBreathCLEU = false -- Assigning a bool for CLEU check to prevent double timer starts from CLEU & Sync
local previousCorporeality = 0
local boss2Engaged = false

local function clearKeepTimers(self) -- Attempt to clear "keep" negative timers that are not relevant to the realm and would otherwise tick to infinity
--	if not self.AnnounceAlternatePhase then return end
	if timerShadowBreathCD:GetRemaining() < 0 then timerShadowBreathCD:Stop() end
	if timerFieryBreathCD:GetRemaining() < 0 then timerFieryBreathCD:Stop() end
end

function mod:OnCombatStart(delay)
	self.vb.warned_preP2 = false
	self.vb.warned_preP3 = false
	self:SetStage(1)
	playerInShadowRealm = false
	fieryCombustionCLEU = false
	fieryBreathCLEU = false
	soulConsumptionCLEU = false
	shadowBreathCLEU = false
	previousCorporeality = 0
	boss2Engaged = false
	berserkTimer:Start(-delay)
	timerMeteorCD:Start(20-delay) -- 5s variance [20-25]
	timerFieryCombustionCD:Start(15-delay) -- 3s variance [15-18]
	timerFieryBreathCD:Start(10-delay) -- 5s variance [10-15]
	timerTailLashCD:Start(-delay)
end

function mod:OnCombatEnd()
	if self.Options.HealthFrame then
		DBM.BossHealth:Hide()
	end
	self:UnregisterShortTermEvents()
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(74806, 75954, 75955, 75956) then
		warningShadowBreath:Show()
		timerShadowBreathCD:Start()
		shadowBreathCLEU = true
		if self:LatencyCheck() then
			self:SendSync("ShadowBreathCD")
		end
	elseif args:IsSpellID(74525, 74526, 74527, 74528) then
		warningFieryBreath:Show()
		timerFieryBreathCD:Start()
		fieryBreathCLEU = true
		if self:LatencyCheck() then
			self:SendSync("FieryBreathCD")
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)--We use spell cast success for debuff timers in case it gets resisted by a player we still get CD timer for next one
	local spellId = args.spellId
	if spellId == 74792 then
		timerSoulConsumptionCD:Start()
		soulConsumptionCLEU = true
		if self:LatencyCheck() then
			self:SendSync("ShadowCD")
		end
	elseif spellId == 74562 then
		timerFieryCombustionCD:Start()
		fieryCombustionCLEU = true
		if self.vb.phase > 1 and self:LatencyCheck() then -- useless on phase 1 since everyone is in the same realm
			self:SendSync("FieryCD")
		end
	elseif spellId == 74531 then -- Tail Lash
		timerTailLashCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)--We don't use spell cast success for actual debuff on >player< warnings since it has a chance to be resisted.
	local spellId = args.spellId
	if spellId == 74792 then
		if self:LatencyCheck() then
			self:SendSync("ShadowTarget", args.destName)
		end
		if args:IsPlayer() then
			specWarnSoulConsumption:Show()
			specWarnSoulConsumption:Play("runout")
			yellSoulConsumption:Yell()
		end
		if not self.Options.AnnounceAlternatePhase then
			warningSoulConsumption:Show(args.destName)
		end
		if self.Options.SetIconOnShadowConsumption then
			self:SetIcon(args.destName, 3)
		end
	elseif spellId == 74562 then
		if self:LatencyCheck() then
			self:SendSync("FieryTarget", args.destName)
		end
		if args:IsPlayer() then
			specWarnFieryCombustion:Show()
			specWarnFieryCombustion:Play("runout")
			yellFieryCombustion:Yell()
		end
		if not self.Options.AnnounceAlternatePhase then
			warningFieryCombustion:Show(args.destName)
		end
		if self.Options.SetIconOnFireConsumption then
			self:SetIcon(args.destName, 7)
		end
	end
end

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 74792 then
		if self.Options.SetIconOnShadowConsumption then
			self:SetIcon(args.destName, 0)
		end
	elseif spellId == 74562 then
		if self.Options.SetIconOnFireConsumption then
			self:SetIcon(args.destName, 0)
		end
	end
end

function mod:SPELL_DAMAGE(sourceGUID, _, _, destGUID, _, _, spellId)
	if (spellId == 75952 or spellId == 75951 or spellId == 75950 or spellId == 75949 or spellId == 75948 or spellId ==  75947) and destGUID == UnitGUID("player") and self:AntiSpam() then
		specWarnMeteorStrike:Show()
		specWarnMeteorStrike:Play("runaway")
	-- Physical/Shadow Realm detection:
	-- OnCombatStarts already defines playerInShadowRealm as false.
	-- Code below is meant to handle P2 and P3
	elseif (self:GetCIDFromGUID(sourceGUID) == 39863 or self:GetCIDFromGUID(destGUID) == 39863) and self.Options.HealthFrame and playerInShadowRealm then -- check if Physical Realm boss exists and playerInShadowRealm is still cached as true
		playerInShadowRealm = false
		DBM.BossHealth:Clear()
		DBM.BossHealth:AddBoss(39863, L.NormalHalion)
	elseif (self:GetCIDFromGUID(sourceGUID) == 40142 or self:GetCIDFromGUID(destGUID) == 40142) and self.Options.HealthFrame and not playerInShadowRealm then -- check if Shadow Realm boss exists
		playerInShadowRealm = true
		DBM.BossHealth:Clear()
		DBM.BossHealth:AddBoss(40142, L.TwilightHalion)
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:UNIT_HEALTH(uId)
	if not self.vb.warned_preP2 and self:GetUnitCreatureId(uId) == 39863 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.79 then
		self.vb.warned_preP2 = true
		warnPhase2Soon:Show()
	elseif not self.vb.warned_preP3 and self:GetUnitCreatureId(uId) == 40142 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.54 then
		self:SendSync("Phase3soon")
	end
end

function mod:UPDATE_WORLD_STATES()
	for i = 1, GetNumWorldStateUI() do
		local _, state, text = GetWorldStateUIInfo(i)
		if state == 1 and strfind(text, "%%") then
			local corporeality = tonumber(strmatch(text, "%d+"))
			if corporeality > 0 and previousCorporeality ~= corporeality then
				specWarnCorporeality:Show(corporeality)
				previousCorporeality = corporeality
				if corporeality > 60 then -- only voice for >= 70%, 60% is still manageable so default to the selected SA sound
					if self:IsTank() then
						specWarnCorporeality:Play("defensive")
					end
				end
				if corporeality < 40 then
					if self:IsDps() then
						specWarnCorporeality:Play("dpsstop")
					end
				elseif corporeality == 40 then
					if self:IsDps() then
						specWarnCorporeality:Play("dpsslow")
					end
				elseif corporeality == 60 then
					if self:IsDps() then
						specWarnCorporeality:Play("dpsmore")
					end
				elseif corporeality > 60 then
					if self:IsDps() then
						specWarnCorporeality:Play("dpshard")
					end
				end
			end
		end
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.Phase2 or msg:find(L.Phase2) then
		self:SendSync("Phase2")
	elseif msg == L.Phase3 or msg:find(L.Phase3) then
		self:SendSync("Phase3")
	elseif msg == L.MeteorCast or msg:find(L.MeteorCast) then--There is no CLEU cast trigger for meteor, only yell
		warningMeteor:Play("meteorrun")
		if not self.Options.AnnounceAlternatePhase then
			warningMeteor:Show()
			timerMeteorCast:Start()--7 seconds from boss yell the meteor impacts.
			timerMeteorCD:Start()
		end
		if self:LatencyCheck() then
			self:SendSync("Meteor")
		end
	elseif msg == L.twilightcutter or msg:find(L.twilightcutter) then -- 2022/10/14: No longer required since this has been fixed serverside! Nevertheless, there is no loss in functionality by doing this in Yell instead of Emote; it's even the first event fired from the pair! (~~Edited (specific for Warmane since CHAT_MSG_RAID_BOSS_EMOTE fires twice: at 5s and at cutter)~~)
			specWarnTwilightCutter:Schedule(5)
			specWarnTwilightCutter:ScheduleVoice(5, "farfromline")
		if not self.Options.AnnounceAlternatePhase then
			timerTwilightCutterCD:Cancel()
			warningTwilightCutter:Show()
			timerTwilightCutter:Schedule(5)--Delay it since it happens 5 seconds after the emote
			if self.Options.TimerCutterSpawn then
				timerTwilightCutterSpawn:Schedule(15)
			else
				timerTwilightCutterCast:Start()
				timerTwilightCutterCD:Schedule(15)
			end
		end
		if self:LatencyCheck() then
			self:SendSync("TwilightCutter")
		end
	end
end

function mod:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
	if not boss2Engaged and UnitExists("boss2") and self:GetUnitCreatureId("boss2") then
		-- EVENT_SEND_ENCOUNTER_UNIT
		boss2Engaged = true -- Not sure how many times IEEU fires here, but doesn't hurt to protect this with a logic failsafe
		-- 2 seconds had passed since JustEngagedWith fired internally
		timerTailLashCD:Start(8) -- Fixed timer: 10s (-2)
		timerShadowBreathCD:Start(8) -- 5s variance [10-15] (-2)
		timerSoulConsumptionCD:Start(18) -- Fixed timer: 20s (-2)
		if self.Options.TimerCutterSpawn then
			timerTwilightCutterSpawn:Start(19)
		else
			timerTwilightCutterCD:Start(14) -- Fixed timer: 16s (-2)
		end
		self:UnregisterShortTermEvents()
	end
end

function mod:OnSync(msg, target)
	if msg == "TwilightCutter" then
		if self.Options.AnnounceAlternatePhase then -- 2022/10/14: Removed antispam workaround since this has been fixed serverside! (~~Edited to circumvent Warmane double cutter boss emote~~)
			timerTwilightCutterCD:Cancel()
			warningTwilightCutter:Show()
			timerTwilightCutter:Schedule(5)--Delay it since it happens 5 seconds after the emote
			if self.Options.TimerCutterSpawn then
				timerTwilightCutterSpawn:Schedule(15)
			else
				timerTwilightCutterCast:Start()
				timerTwilightCutterCD:Schedule(15)
			end
		end
	elseif msg == "Meteor" then
		if self.Options.AnnounceAlternatePhase then
			warningMeteor:Show()
			timerMeteorCast:Start()
			timerMeteorCD:Start()
		end
	elseif msg == "ShadowTarget" then
		if self.Options.AnnounceAlternatePhase then
			warningSoulConsumption:Show(target)
		end
	elseif msg == "FieryTarget" then
		if self.Options.AnnounceAlternatePhase then
			warningFieryCombustion:Show(target)
		end
	elseif msg == "ShadowCD" then
		if self.Options.AnnounceAlternatePhase and not soulConsumptionCLEU then
			soulConsumptionCLEU = false -- reset state for next CLEU/sync check
			timerSoulConsumptionCD:Start()
		end
	elseif msg == "ShadowBreathCD" then
		if self.Options.AnnounceAlternatePhase and not shadowBreathCLEU then
			shadowBreathCLEU = false -- reset state for next CLEU/sync check
			warningShadowBreath:Show()
			timerShadowBreathCD:Start()
		end
	elseif msg == "FieryBreathCD" then
		if self.Options.AnnounceAlternatePhase and not fieryBreathCLEU then
			fieryBreathCLEU = false -- reset state for next CLEU/sync check
			warningFieryBreath:Show()
			timerFieryBreathCD:Start()
		end
	elseif msg == "FieryCD" and self.vb.phase > 1 then -- block old comms that run this for the entirety of the raid, which is useless on phase 1 since everyone is in the same realm
		if self.Options.AnnounceAlternatePhase and not fieryCombustionCLEU then
			fieryCombustionCLEU = false -- reset state for next CLEU/sync check
			timerFieryCombustionCD:Start()
		end
	elseif msg == "Phase2" and self.vb.phase < 2 then
		self:SetStage(2)
		timerFieryBreathCD:Cancel()
		timerMeteorCD:Cancel()
		timerFieryCombustionCD:Cancel()
		warnPhase2:Show()
		warnPhase2:Play("ptwo")
--		timerShadowBreathCD:Start() -- ~5s variance [13.7-18.4] (25H Lordaeron 2022/09/21 wipe1 || 25H Lordaeron 2022/09/21 wipe2 || 25H Lordaeron 2022/09/21 wipe3 || 25H Lordaeron 2022/09/23) - 15.9 || 13.7 || 18.1 || 18.4
--		timerSoulConsumptionCD:Start(22.8)--Edited. not exact, 15 seconds from tank aggro, but easier to add 5 seconds to it as a estimate timer than trying to detect this. (25N Lordaeron 2022/10/09 || 25H Lordaeron 2022/10/15 || 25H Lordaeron 2022/10/30) - 23.8 || 23.4 || 22.8
--		if self.Options.TimerCutterSpawn then
--			timerTwilightCutterSpawn:Start(35)
--		else
--			timerTwilightCutterCD:Start(30) -- (25N Lordaeron 2022/09/20 || 25H Lordaeron 2022/09/21) - Stage 2/30.0 || Stage 2/30.0
--		end
		self:Schedule(20, clearKeepTimers, self)
		self:RegisterShortTermEvents(
			"INSTANCE_ENCOUNTER_ENGAGE_UNIT" -- EVENT_SEND_ENCOUNTER_UNIT. Fixed timer: 2s
		)
		-- Delays all events by 10s (but could not find a reason for this, since twilight realm is a different class, so do nothing for now. Maybe impacts phase 3?)
	elseif msg == "Phase3" and self.vb.phase < 3 then
		self:SetStage(3)
		warnPhase3:Show()
		warnPhase3:Play("pthree")
		timerMeteorCD:Start(23.2) --REVIEW! These i'm not sure if they start regardless of drake aggro, or if it varies as well.
		timerFieryCombustionCD:Start(17.8) -- REVIEW! source of variance?
		self:Schedule(20, clearKeepTimers, self)
	elseif msg == "Phase3soon" and not self.vb.warned_preP3 then
		self.vb.warned_preP3 = true
		warnPhase3Soon:Show()
	end
end
