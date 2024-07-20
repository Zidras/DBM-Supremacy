local mod	= DBM:NewMod("NorthrendBeasts", "DBM-Coliseum")
local L		= mod:GetLocalizedStrings()

local --[[UnitExists,]] UnitGUID, UnitName = --[[UnitExists,]] UnitGUID, UnitName
-- local GetSpellInfo = GetSpellInfo
local GetPlayerMapPosition, SetMapToCurrentZone = GetPlayerMapPosition, SetMapToCurrentZone

mod:SetRevision("20240720012127")
mod:SetCreatureID(34796, 35144, 34799, 34797)
mod:SetUsedIcons(1, 2, 3, 4, 5, 6, 7, 8)
mod:SetMinSyncRevision(20220925000000)
mod:SetMinCombatTime(30)
mod:SetBossHPInfoToHighest()

mod:RegisterCombat("combat")

mod:RegisterEvents(
	"CHAT_MSG_MONSTER_YELL"
)
mod:RegisterEventsInCombat(
	"SPELL_CAST_START 66313 66330 67647 67648 67649 66794 67644 67645 67646 66821 66818 66901 67615 67616 67617 66902 67627 67628 67629 66683 67660 67661 67662",
	"SPELL_CAST_SUCCESS 67641 66883 67642 67643 66824 67612 67613 67614 66879 67624 67625 67626 66689 67650 67651 67652",
	"SPELL_AURA_APPLIED 67477 66331 67478 67479 67657 66759 67658 67659 66823 67618 67619 67620 66869 66758 66636 68335 676",
	"SPELL_AURA_APPLIED_DOSE 67477 66331 67478 67479 66636",
	"SPELL_AURA_REMOVED 66869 66758",
	"SPELL_DAMAGE 66320 67472 67473 67475 66317 66881 67638 67639 67640",
	"SPELL_MISSED 66320 67472 67473 67475 66317 66881 67638 67639 67640",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"UNIT_DIED"
--	"UNIT_SPELLCAST_START boss1",
--	"UNIT_SPELLCAST_SUCCEEDED boss1 boss2"
)

local gormok = L.Gormok
local dreadscale = L.Dreadscale
local acidmaw = L.Acidmaw
local icehowl = L.Icehowl

-- General
local enrageTimer			= mod:NewBerserkTimer(520)
local timerCombatStart		= mod:NewCombatTimer(11)
local timerNextBoss			= mod:NewTimer(150, "TimerNextBoss", 2457, nil, nil, 1)

mod:AddRangeFrameOption("10")

-- Stage One: Gormok the Impaler
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1)..": "..gormok)
local warnImpaleOn			= mod:NewStackAnnounce(66331, 2, nil, "Tank|Healer")
local warnFireBomb			= mod:NewSpellAnnounce(66317, 3, nil, false)
local WarningSnobold		= mod:NewAnnounce("WarningSnobold", 4)

local specWarnImpale3		= mod:NewSpecialWarningStack(66331, nil, 3, nil, nil, 1, 6)
local specWarnAnger3		= mod:NewSpecialWarningStack(66636, "Tank|Healer", 3, nil, nil, 1, 6)
local specWarnGTFO			= mod:NewSpecialWarningGTFO(66317, nil, nil, nil, 1, 8)
local specWarnSilence		= mod:NewSpecialWarningSpell(66330, "SpellCaster")
local specWarnStompPreWarn	= mod:NewSpecialWarningPreWarn(66330, "SpellCaster", 3, nil, nil, 1, 2)

local timerNextStomp		= mod:NewCDTimer(20, 66330, nil, nil, nil, 2, nil, DBM_COMMON_L.INTERRUPT_ICON, true, mod:IsSpellCaster() and 3 or nil, 3) -- 5s variance. Added "keep" arg
local timerImpaleCD			= mod:NewCDTimer(9, 66331, nil, "Tank|Healer", nil, 5, nil, DBM_COMMON_L.TANK_ICON, true) -- 1s variance [9-10]. Added "keep" arg. If boss is disarmed once this script event fires, Impale cyclechecks every 2.5s until no longer disarmed. 10 stack only per player
local timerRisingAnger		= mod:NewCDTimer(18.5, 66636, nil, nil, nil, 1, nil, nil, true) -- Snobold spawn on Gormok back: 8s variance [16-24] --> Release Snobold after 2.5s, granting also 1 stack of Rising Anger.

local soundAuraMastery		= mod:NewSound(66330, "soundConcAuraMastery")

-- Stage Two: Acidmaw & Dreadscale
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2)..": "..dreadscale.." & "..acidmaw)
local warnSlimePool			= mod:NewSpellAnnounce(66883, 2, nil, "Melee")
local warnToxin				= mod:NewTargetAnnounce(66823, 3)
local warnBile				= mod:NewTargetAnnounce(66869, 3)
local warnEnrageWorm		= mod:NewSpellAnnounce(68335, 3)

local specWarnToxin			= mod:NewSpecialWarningMoveTo(66823, nil, nil, nil, 1, 2)
local specWarnBile			= mod:NewSpecialWarningYou(66869, nil, nil, nil, 1, 2)

local timerSubmerge			= mod:NewCDSourceTimer(45, 66948, nil, nil, nil, 6, "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendBurrow.blp", nil, true) -- 5s variance [45-50]. Added "Keep" arg
local timerEmerge			= mod:NewNextSourceTimer(8.5, 66947, nil, nil, nil, 6, "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendUnBurrow.blp") -- 2.5s burrowing + 6s underground
local timerSweepCD			= mod:NewCDSourceTimer(15, 66794, nil, "Melee", nil, 3, nil, nil, true) -- 15s variance! [15-30] (EVENT_SPELL_SWEEP). Added "Keep" arg.
local timerAcidicSpewCD		= mod:NewCDTimer(15, 66819, nil, "Tank", 2, 5, nil, DBM_COMMON_L.TANK_ICON, true) -- 15s variance! [15-30] (EVENT_SPELL_SPEW). Added "Keep" arg.
local timerMoltenSpewCD		= mod:NewCDTimer(15, 66820, nil, "Tank", 2, 5, nil, DBM_COMMON_L.TANK_ICON, true) -- 15s variance! [15-30] (EVENT_SPELL_SPEW). Added "Keep" arg.
local timerParalyticSprayCD	= mod:NewNextTimer(20, 66901, nil, nil, nil, 3) -- Fixed timer for EVENT_SPELL_SPRAY: 20s (_SPELL_SPRAY)
local timerBurningSprayCD	= mod:NewNextTimer(20, 66902, nil, nil, nil, 3) -- Fixed timer for EVENT_SPELL_SPRAY: 20s (_SPELL_SPRAY)
local timerParalyticBiteCD	= mod:NewNextTimer(20, 66824, nil, "Melee", nil, 3) -- Fixed timer for EVENT_SPELL_BITE: 20s (_SPELL_BITE)
local timerBurningBiteCD	= mod:NewNextTimer(20, 66879, nil, "Melee", nil, 3) -- Fixed timer for EVENT_SPELL_BITE: 20s (_SPELL_BITE)
local timerSlimePoolCD		= mod:NewNextSourceTimer(30, 66883, nil, "Melee", nil, 3) -- Fixed timer for EVENT_SPELL_SLIME_POOL: 30s

mod:AddSetIconOption("SetIconOnBileTarget", 66869, false, 0, {1, 2, 3, 4, 5, 6, 7, 8})

-- Stage Three: Icehowl
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(3)..": "..icehowl)
local warnBreath			= mod:NewSpellAnnounce(66689, 2)
local warnRage				= mod:NewSpellAnnounce(66759, 3)
local warnCharge			= mod:NewTargetNoFilterAnnounce(52311, 4)

local specWarnCharge		= mod:NewSpecialWarningRun(52311, nil, nil, nil, 4, 2)
local specWarnChargeNear	= mod:NewSpecialWarningClose(52311, nil, nil, nil, 3, 2)
local specWarnFrothingRage	= mod:NewSpecialWarningDispel(66759, "RemoveEnrage", nil, nil, 1, 2)

local timerBreath			= mod:NewCastTimer(5, 66689, nil, nil, nil, 3) -- 5s channel. is it random target or tank?
local timerBreathCD			= mod:NewCDTimer(20, 66689, nil, nil, nil, 3, nil, nil, true) -- 10s variance [20-30]. Added "Keep" arg
local timerStaggeredDaze	= mod:NewBuffActiveTimer(15, 66758, nil, nil, nil, 5, nil, DBM_COMMON_L.DAMAGE_ICON)
local timerNextCrash		= mod:NewCDTimer(32, 66683, nil, nil, nil, 2, nil, DBM_COMMON_L.MYTHIC_ICON, true) -- Jump + 2s for spell. Added "Keep" arg.

mod:AddSetIconOption("SetIconOnChargeTarget", 52311, true, 0, {8})
mod:AddBoolOption("ClearIconsOnIceHowl", true)
mod:AddBoolOption("IcehowlArrow")

mod:GroupSpells(66902, 66869)--Burning Spray with Burning Bile
mod:GroupSpells(66901, 66823)--Paralytic Spray with Toxic Bile
mod:GroupSpells(52311, 66758, 66759)--Furious Charge, Staggering Daze, and Frothing Rage

local bileName = DBM:GetSpellInfo(66869)
local phases = {}
-- local acidmawEngaged = false
-- local acidmawSubmerged = false
-- local dreadscaleEngaged = false
mod.vb.burnIcon = 1
mod.vb.DreadscaleMobile = true
mod.vb.AcidmawMobile = false
mod.vb.DreadscaleDead = false
mod.vb.AcidmawDead = false

local function updateHealthFrame(phase)
	if phases[phase] then
		return
	end
	phases[phase] = true
	mod.vb.phase = phase
	if phase == 1 then
		DBM.BossHealth:Clear()
		DBM.BossHealth:AddBoss(34796, gormok)
	elseif phase == 2 then
		DBM.BossHealth:AddBoss(35144, acidmaw)
		DBM.BossHealth:AddBoss(34799, dreadscale)
	elseif phase == 3 then
		DBM.BossHealth:AddBoss(34797, icehowl)
	end
end

local function isBuffOwner(uId, spellId)
	if not uId and not spellId then return end
	local _, _, _, _, _, _, _, unitCaster = DBM:UnitBuff(uId, spellId)
	if unitCaster == uId then
		return true
	else
		return false
	end
end

local function slimePoolOnRepeat(self)
	warnSlimePool:Show()
	timerSlimePoolCD:Start(self.vb.DreadscaleMobile and not self.vb.DreadscaleDead and dreadscale or acidmaw)
	self:Schedule(30, slimePoolOnRepeat, self)
end

local function wormsEngaged(self) -- Acidmaw = _MODEL_STATIONARY ; Dreadscale is Mobile. Fires ScheduleEvents()
	self:SetStage(2)
	timerSubmerge:Start(acidmaw)
	timerSubmerge:Start(dreadscale)
	timerSweepCD:Start(acidmaw)
	timerParalyticSprayCD:Start()
	timerSlimePoolCD:Start(15, dreadscale)
	self:Schedule(15, slimePoolOnRepeat, self)
	timerMoltenSpewCD:Start()
	timerBurningBiteCD:Start(15)
end


local function scheduledAcidmawSubmerged(self) -- no submerge emote
	DBM:AddSpecialEventToTranscriptorLog("Acidmaw Submerged")
	timerAcidicSpewCD:Stop()
	timerParalyticBiteCD:Stop()
	timerParalyticSprayCD:Stop()
	timerSlimePoolCD:Stop(acidmaw)
	self:Unschedule(slimePoolOnRepeat)
	timerSweepCD:Stop(acidmaw)
	timerSubmerge:Stop(acidmaw)
	timerEmerge:Start(acidmaw)
end

local function icehowlEngaged(self)
	self:SetStage(3)
	timerBreathCD:Start(14)
	timerNextCrash:Start() -- Fixed timer: 30s jump + 2s spell
end

function mod:OnCombatStart(delay)
	table.wipe(phases)
--	acidmawEngaged = false
--	acidmawSubmerged = false
--	dreadscaleEngaged = false
	self.vb.burnIcon = 8
	self.vb.DreadscaleMobile = true
	self.vb.AcidmawMobile = false
	self.vb.DreadscaleDead = false
	self.vb.AcidmawDead = false
	self:SetStage(1)
	specWarnStompPreWarn:Schedule(12-delay) -- 3s pre-warn.
	if self.Options.soundConcAuraMastery and isBuffOwner("player", 19746) then -- Concentration Aura Mastery by a Paladin will negate the interrupt effect of Staggering Stomp
		soundAuraMastery:Schedule(12-delay, "Interface\\AddOns\\DBM-Core\\sounds\\PlayerAbilities\\AuraMastery.ogg")
	else
		specWarnStompPreWarn:ScheduleVoice(12-delay, "silencesoon")
	end
	timerRisingAnger:Start(-delay)
	timerNextStomp:Start(15-delay)
	timerImpaleCD:Start() -- 1s variance [9-10]
	updateHealthFrame(1)
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

--These remain methods since they can't reverse schedule each other as local functions
--[[ Disabling scheduling methods since worms submerge at different times on Warmane. Also, since Warmane has boss units, we also have access to the proper events
["UNIT_SPELLCAST_SUCCEEDED"] = {
	"Churning Ground Visual-npc:34799-240 = pull:141.2/Stage 2/58.2, 5.0, 45.1, 5.0, Stage 3/31.2", -- [6]
	"Churning Ground Visual-npc:35144-247 = pull:144.2/Stage 2/61.2, 5.0, 45.0, 5.0, Stage 3/28.2", -- [7]
}
function mod:WormsEmerge()
	timerSubmerge:Start()
	if not self.vb.AcidmawDead then
		if self.vb.DreadscaleMobile then
			timerSweepCD:Start(22)			-- Log review: 22-24s (N/H?)
			timerParalyticSprayCD:Start(18)	-- Log review: 18-20s (N/H?)
		else
			timerSlimePoolCD:Start(14)
			timerParalyticBiteCD:Start(5)
			timerAcidicSpewCD:Start(10)
		end
	end
	if not self.vb.DreadscaleDead then
		if self.vb.DreadscaleMobile then
			timerSlimePoolCD:Start(15)
			timerMoltenSpewCD:Start(26)
			timerBurningBiteCD:Start(5)
		else
			timerSweepCD:Start(16)
			timerBurningSprayCD:Start(17)
		end
	end
	self:ScheduleMethod(45, "WormsSubmerge")
end

function mod:WormsSubmerge()
	timerEmerge:Start()
	timerSweepCD:Cancel()
	timerSlimePoolCD:Cancel()
	timerMoltenSpewCD:Cancel()
	timerParalyticSprayCD:Cancel()
	timerBurningBiteCD:Cancel()
	timerAcidicSpewCD:Cancel()
	timerBurningSprayCD:Cancel()
	timerParalyticBiteCD:Cancel()
	self.vb.DreadscaleMobile = not self.vb.DreadscaleMobile
	self:ScheduleMethod(5, "WormsEmerge")
end]]

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if spellId == 66313 then									-- FireBomb (Impaler)
		warnFireBomb:Show()
	elseif args:IsSpellID(66330, 67647, 67648, 67649) then		-- Staggering Stomp
		timerNextStomp:Start()
		specWarnSilence:Show()
		specWarnStompPreWarn:Schedule(17) -- prewarn 3 sec before next
		if self.Options.soundConcAuraMastery and isBuffOwner("player", 19746) then -- Concentration Aura Mastery by a Paladin will negate the interrupt effect of Staggering Stomp
			soundAuraMastery:Schedule(17, "Interface\\AddOns\\DBM-Core\\sounds\\PlayerAbilities\\AuraMastery.ogg")
		else
			specWarnStompPreWarn:ScheduleVoice(17, "silencesoon")
		end
	elseif args:IsSpellID(66794, 67644, 67645, 67646) then		-- Sweep stationary worm
		timerSweepCD:Start(args.sourceName)
	elseif spellId == 66821 then							-- Molten spew
		timerMoltenSpewCD:Start()
	elseif spellId == 66818 then							-- Acidic Spew
		timerAcidicSpewCD:Start()
	elseif args:IsSpellID(66901, 67615, 67616, 67617) then		-- Paralytic Spray
		timerParalyticSprayCD:Start()
	elseif args:IsSpellID(66902, 67627, 67628, 67629) then		-- Burning Spray
		self.vb.burnIcon = 1
		timerBurningSprayCD:Start()
	elseif args:IsSpellID(66683, 67660, 67661, 67662) then		-- Massive Crash (Icehowl)
		timerBreathCD:Cancel()
		timerNextCrash:Start() -- debug
		timerNextCrash:Cancel()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(67641, 66883, 67642, 67643) then			-- Slime Pool Cloud Spawn
		warnSlimePool:Show()
		timerSlimePoolCD:Start(args.sourceName)
	elseif args:IsSpellID(66824, 67612, 67613, 67614) then		-- Paralytic Bite
		timerParalyticBiteCD:Start()
	elseif args:IsSpellID(66879, 67624, 67625, 67626) then		-- Burning Bite
		timerBurningBiteCD:Start()
	elseif args:IsSpellID(66689, 67650, 67651, 67652) then		-- Arctic Breath
		timerBreathCD:Start()
		timerBreath:Start()
		warnBreath:Show()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if args:IsSpellID(67477, 66331, 67478, 67479) then	-- Impale
		timerImpaleCD:Start()
		warnImpaleOn:Show(args.destName, 1)
	elseif args:IsSpellID(67657, 66759, 67658, 67659) then	-- Frothing Rage
		timerBreathCD:Start(5) -- 3s variance [5-8]
		timerNextCrash:Start() -- 20s variance! [30-50] + 2s spell
		warnRage:Show()
		specWarnFrothingRage:Show()
		specWarnFrothingRage:Play("trannow")
	elseif args:IsSpellID(66823, 67618, 67619, 67620) then	-- Paralytic Toxin
		warnToxin:CombinedShow(0.3, args.destName)
		if args:IsPlayer() then
			specWarnToxin:Show(bileName)
			specWarnToxin:Play("targetyou")
		end
	elseif spellId == 66869 then	-- Burning Bile
		warnBile:CombinedShow(0.3, args.destName)
		if args:IsPlayer() then
			specWarnBile:Show()
			specWarnBile:Play("targetyou")
		end
		if self.Options.SetIconOnBileTarget and self.vb.burnIcon < 9 then
			self:SetIcon(args.destName, self.vb.burnIcon)
			self.vb.burnIcon = self.vb.burnIcon + 1
		end
	elseif spellId == 66758 then	-- Staggered Daze
		timerStaggeredDaze:Start()
		-- Delays events by 15s?? Not working as expected
--		timerBreathCD:Start() -- 3s variance [5-8] + 15s delay
--		timerNextCrash:Start() -- 20s variance! [30-50] + [15s delay] + 2s spell
	elseif spellId == 66636 then	-- Rising Anger
		WarningSnobold:Show(args.destName)
		timerRisingAnger:Start()
	elseif spellId == 68335 then	-- Enrage
		warnEnrageWorm:Show()
	elseif spellId == 676 then		-- Disarm (Warriors) - 10s.
		timerImpaleCD:Restart(10.5) -- Impale rechecks disarmed flag every 2.5s, so attempt to eyeball it in the middle
	end
end

function mod:SPELL_AURA_APPLIED_DOSE(args)
	if args:IsSpellID(67477, 66331, 67478, 67479) then	-- Impale
		local amount = args.amount or 1
		timerImpaleCD:Start()
		if (amount >= 3) or (amount >= 2 and self:IsHeroic()) then
			if args:IsPlayer() then
				specWarnImpale3:Show(amount)
				specWarnImpale3:Play("stackhigh")
			else
				warnImpaleOn:Show(args.destName, amount)
			end
		end
	elseif args.spellId == 66636 then	-- Rising Anger
		local amount = args.amount or 1
		WarningSnobold:Show(args.destName)
		timerRisingAnger:Start()
		if amount >= 4 then -- only 4 snobolds
			timerRisingAnger:Stop()
			specWarnAnger3:Show(amount)
			specWarnAnger3:Play("stackhigh")
		end
	end
end

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 66869 then
		if self.Options.SetIconOnBileTarget then
			self:SetIcon(args.destName, 0)
		end
	elseif spellId == 66758 then -- Techincally not in line with script (not on SAR), but looks better during event. Unfortunately, these timers are also all over the place...
		timerBreathCD:Start(11.82) -- 10s+ variance?
		timerNextCrash:Start(23.41) -- 20s+? variance?
	end
end

function mod:SPELL_DAMAGE(_, _, _, destGUID, _, _, spellId, spellName)
	if ((spellId == 66320 or spellId == 67472 or spellId == 67473 or spellId == 67475 or spellId == 66317) or (spellId == 66881 or spellId == 67638 or spellId == 67639 or spellId == 67640)) and destGUID == UnitGUID("player") then	-- Fire Bomb (66317 is impact damage, not avoidable but leaving in because it still means earliest possible warning to move. Other 4 are tick damage from standing in it) // Slime Pool
		specWarnGTFO:Show(spellName)
		specWarnGTFO:Play("watchfeet")
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg, sender, _, _, target)
	if (msg:match(L.Charge) or msg:find(L.Charge)) and target then
		target = DBM:GetUnitFullName(target)
		warnCharge:Show(target)
		if self.Options.ClearIconsOnIceHowl then
			self:ClearIcons()
		end
		if target == UnitName("player") then
			specWarnCharge:Show()
			specWarnCharge:Play("justrun")
			if self.Options.PingCharge then
				Minimap:PingLocation()
			end
		elseif self:CheckNearby(11, target) then
			specWarnChargeNear:Show(target)
			specWarnChargeNear:Play("runaway")
		end
		if self.Options.IcehowlArrow then
			local uId = DBM:GetRaidUnitId(target)
			local x, y = GetPlayerMapPosition(uId)
			if x == 0 and y == 0 then
				SetMapToCurrentZone()
				x, y = GetPlayerMapPosition(uId)
			end
			DBM.Arrow:ShowRunAway(x, y, 12, 5)
		end
		if self.Options.SetIconOnChargeTarget then
			self:SetIcon(target, 8, 5)
		end
	elseif msg == L.DreadscaleSubmerged or msg:find(L.DreadscaleSubmerged) then
		DBM:Debug("Submerge casted by " .. sender, 2)
		if sender == acidmaw then
			DBM:AddMsg("Acidmaw Submerge EMOTE implemented in the boss server script. Notify Zidras on Github or Discord")
		elseif sender == dreadscale then
			DBM:AddSpecialEventToTranscriptorLog("Dreadscale Submerged")
			timerMoltenSpewCD:Stop()
			timerBurningBiteCD:Stop()
			timerBurningSprayCD:Stop()
			timerSlimePoolCD:Stop(dreadscale)
			self:Unschedule(slimePoolOnRepeat)
			timerSweepCD:Stop(dreadscale)
			timerSubmerge:Stop(dreadscale)
			timerEmerge:Start(dreadscale)
			if not self.vb.AcidmawDead then
				self:Schedule(1.5, scheduledAcidmawSubmerged, self)
			end
		end
	elseif (msg == L.DreadscaleEmerged or msg:find(L.DreadscaleEmerged)) or (msg == L.AcidmawEmerged or msg:find(L.AcidmawEmerged)) then
		DBM:Debug("Emerge casted by " .. sender, 2)
		if sender == acidmaw then
			self.vb.AcidmawMobile = not self.vb.AcidmawMobile
			DBM:Debug("Acidmaw PHASE_STATIONARY: " .. tostring(self.vb.AcidmawMobile), 2)
			timerSubmerge:Start(acidmaw)
			if self.vb.AcidmawMobile then
				timerSlimePoolCD:Start(15, acidmaw) -- Fixed timer for ScheduleEvents() on Emerge: 15s
				self:Schedule(15, slimePoolOnRepeat, self)
				timerParalyticBiteCD:Start() --  Fixed timer for ScheduleEvents() on Emerge: 20s (if Acidmaw)
				timerAcidicSpewCD:Start() -- Same variance for ScheduleEvents() on Emerge: 15-30s
			else
				timerSweepCD:Start(acidmaw) -- Same variance for ScheduleEvents() on Emerge: 15-30s
				timerParalyticSprayCD:Start(20) -- Fixed timer for ScheduleEvents() on Emerge: 20s (if Acidmaw)
			end
		elseif sender == dreadscale then
			self.vb.DreadscaleMobile = not self.vb.DreadscaleMobile
			DBM:Debug("Dreadscale PHASE_STATIONARY: " .. tostring(self.vb.DreadscaleMobile), 2)
			timerSubmerge:Start(dreadscale)
			if self.vb.DreadscaleMobile then
				timerSlimePoolCD:Start(15, dreadscale) -- Fixed timer for ScheduleEvents() on Emerge: 15s
				self:Schedule(15, slimePoolOnRepeat, self)
				timerMoltenSpewCD:Start() -- Same variance for ScheduleEvents() on Emerge: 15-30s
				timerBurningBiteCD:Start(15) -- Fixed timer for ScheduleEvents() on Emerge: 15s (if Dreadscale)
			else
				timerSweepCD:Start(dreadscale) -- Same variance for ScheduleEvents() on Emerge: 15-30s
				timerBurningSprayCD:Start(15) -- Fixed timer for ScheduleEvents() on Emerge: 15s (if Dreadscale)
			end
		end
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.CombatStart or msg:find(L.CombatStart) then
		timerCombatStart:Start()
		if self:IsHeroic() then
			timerNextBoss:Start()	-- events.RescheduleEvent(EVENT_SCENE_005, 150000); Worms
									-- events.RescheduleEvent(EVENT_SCENE_006, 340000); Icehowl
			enrageTimer:Start()		-- events.RescheduleEvent(EVENT_NORTHREND_BEASTS_ENRAGE, 520000);
		end
	elseif msg == L.Phase2 or msg:find(L.Phase2) then
		self:SetStage(1.5)
--		self:ScheduleMethod(13.5, "WormsEmerge")
		self:Schedule(15, wormsEngaged, self)
		timerCombatStart:Start(15)
		if self:IsHeroic() then
			local elapsedNextBossTimer = timerNextBoss:GetTime()
			timerNextBoss:Restart(340-elapsedNextBossTimer)
		end
		updateHealthFrame(2)
		if self.Options.RangeFrame then
			DBM.RangeCheck:Show(10)
		end
--[[	self:RegisterShortTermEvents(
			"INSTANCE_ENCOUNTER_ENGAGE_UNIT"
		)]]
	elseif msg == L.Phase3 or msg:find(L.Phase3) then
		updateHealthFrame(3)
		self:SetStage(2.5)
--		self:UnscheduleMethod("WormsSubmerge")
--		self:UnscheduleMethod("WormsEmerge")
		self:Schedule(13, icehowlEngaged, self)
		timerCombatStart:Start(13)
		if self:IsHeroic() then
			timerNextBoss:Cancel()
		end
		timerSubmerge:Cancel()
		timerEmerge:Cancel()
		if self.Options.RangeFrame then
			DBM.RangeCheck:Hide()
		end
--[[	self:RegisterShortTermEvents(
			"INSTANCE_ENCOUNTER_ENGAGE_UNIT"
		)]]
	end
end

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 34796 then
		specWarnStompPreWarn:Cancel()
		specWarnStompPreWarn:CancelVoice()
		soundAuraMastery:Cancel()
		timerNextStomp:Stop()
		timerImpaleCD:Stop()
		timerRisingAnger:Stop()
		DBM.BossHealth:RemoveBoss(cid) -- remove Gormok from the health frame
	elseif cid == 35144 then -- Acidmaw dead
		-- DoAction(-2)
		self.vb.AcidmawDead = true
		timerParalyticSprayCD:Cancel()
		timerParalyticBiteCD:Cancel()
		timerAcidicSpewCD:Cancel()
		timerSubmerge:Cancel(acidmaw)
		if self.vb.AcidmawMobile then
			timerSlimePoolCD:Cancel(args.destName)
			self:Unschedule(slimePoolOnRepeat)
		else
			timerSweepCD:Cancel(args.destName)
		end
		if self.vb.DreadscaleDead then
			timerNextBoss:Cancel()
			DBM.BossHealth:RemoveBoss(35144)
			DBM.BossHealth:RemoveBoss(34799)
		else
			if self.vb.DreadscaleMobile then -- Dreadscale mobile
				timerSubmerge:Cancel(dreadscale)
			else -- Dreadscale stationary
				timerSubmerge:Start(1, dreadscale)
			end
		end
	elseif cid == 34799 then -- Dreadscale dead
		-- DoAction(-2)
		self.vb.DreadscaleDead = true
		timerBurningSprayCD:Cancel()
		timerBurningBiteCD:Cancel()
		timerMoltenSpewCD:Cancel()
		timerSubmerge:Cancel(dreadscale)
		if self.vb.DreadscaleMobile then
			timerSlimePoolCD:Cancel(args.destName)
			self:Unschedule(slimePoolOnRepeat)
		else
			timerSweepCD:Cancel(args.destName)
		end
		if self.vb.AcidmawDead then
			timerNextBoss:Cancel()
			DBM.BossHealth:RemoveBoss(35144)
			DBM.BossHealth:RemoveBoss(34799)
		else
			if self.vb.AcidmawMobile then -- Acidmaw mobile
				timerSubmerge:Cancel(acidmaw)
			else -- Acidmaw stationary
				timerSubmerge:Start(1, acidmaw)
				self:Schedule(1, scheduledAcidmawSubmerged, self)
			end
		end
	elseif cid == 34797 then
		DBM:EndCombat(self)
	end
end

--[[function mod:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
	for i = 1, 5 do
		local unitID = "boss"..i
		if UnitExists(unitID) then
			local cid = self:GetUnitCreatureId(unitID)
			local bossName = UnitName(unitID)
			if cid == 35144 and not acidmawEngaged then -- Acidmaw (stationary on engage)
				self:SetStage(2) -- IEEU fires in tandem, so phasing only once is fine
				acidmawEngaged = true
				if self:IsHeroic() then
					timerNextBoss:Start()
				end
				timerSubmerge:Start(49.3, bossName) -- REVIEW! 2s delay from visual to submerge (25H Lordaeron 2022/09/03) - 50
				timerSweepCD:Start(18.6, bossName) -- (2021/10/21 || 25H Lordaeron 2022/09/03 || 10N Lordaeron 2022/10/02 || 25H Lordaeron 2022/10/09) - 22-24s (N/H?) || 24 || 20.0 || 18.6
				timerParalyticSprayCD:Start(15.5)	-- (2021/10/21 || 25H Lordaeron 2022/09/03 || 25H Lordaeron 2022/09/28 || 10N Lordaeron 2022/10/02 || 25N Lordaeron 2022/10/21) - 18-20s (N/H?) || 22 || 20.2 || 30.3 || 15.5
			elseif cid == 34799 and not dreadscaleEngaged then -- Dreadscale (mobile on engage)
				dreadscaleEngaged = true
				timerSubmerge:Start(bossName)
				timerSlimePoolCD:Start(15, bossName) -- (25H Lordaeron 2022/09/03) - 15
				timerMoltenSpewCD:Start(19.2) -- (25H Lordaeron 2022/09/03 || 25H Lordaeron 2022/09/28 || 25N Lordaeron 2022/10/13) - 24 || 23.2 || 19.2
				timerBurningBiteCD:Start(15.4) -- (25H Lordaeron 2022/09/03 || 25N Lordaeron 2022/10/13) - 19 || 15.4
			elseif cid == 34797 then -- Icehowl
				self:SetStage(3)
				timerNextCrash:Start(40.9) -- REVIEW!
				self:UnregisterShortTermEvents()
			end
			if unitID == "boss2" then
				self:UnregisterShortTermEvents() -- both worms are on boss frames, job finished.
			end
		end
	end
end]]

--[[function mod:UNIT_SPELLCAST_START(_, spellName)
	if spellName == GetSpellInfo(66683) then -- Massive Crash
		timerNextCrash:Start()
	end
end]]

--[[function mod:UNIT_SPELLCAST_SUCCEEDED(uId, spellName)
	if spellName == GetSpellInfo(66948) then -- Submerge
		local npcId = self:GetUnitCreatureId(uId)
		local unitName = UnitName(uId) or UNKNOWN
		DBM:Debug("Submerge casted by " .. unitName.. ": " .. tostring(npcId), 2)
		if npcId == 35144 then -- Acidmaw
			acidmawSubmerged = true -- this workaround is necessary since I had one log (25H Lordaeron 2022/09/24) that Emerged fired 1.0s after IEEU, so enforce submerge/emerge conditional logic
			timerAcidicSpewCD:Stop()
			timerParalyticBiteCD:Stop()
			timerParalyticSprayCD:Stop()
			timerSlimePoolCD:Stop(acidmaw)
			timerSweepCD:Stop(acidmaw)
			timerEmerge:Start(7.5, UnitGUID(uId)) -- REVIEW! 3s delay from visual to emerge (25H Lordaeron 2022/09/03) - 8, 7
		elseif npcId == 34799 then -- Dreadscale
			timerMoltenSpewCD:Stop()
			timerBurningBiteCD:Stop()
			timerBurningSprayCD:Stop()
			timerSlimePoolCD:Stop(dreadscale)
			timerSweepCD:Stop(dreadscale)
			timerEmerge:Start(6.5, UnitGUID(uId)) -- (25H Lordaeron 2022/09/03) - 7, 6
		end
	elseif spellName == GetSpellInfo(66947) then -- Emerge
		local npcId = self:GetUnitCreatureId(uId)
		local unitName = UnitName(uId) or UNKNOWN
		DBM:Debug("Emerge casted by " .. unitName.. ": " .. tostring(npcId), 2)
		if npcId == 35144 and acidmawSubmerged then -- Acidmaw
			self.vb.AcidmawMobile = not self.vb.AcidmawMobile
			acidmawSubmerged = false
			DBM:Debug("Acidmaw PHASE_STATIONARY: " .. tostring(self.vb.AcidmawMobile), 2)
			timerSubmerge:Start(43, acidmaw)
			if self.vb.AcidmawMobile then
				timerSlimePoolCD:Start(acidmaw) -- (25H Lordaeron 2022/09/03) - 12
				timerParalyticBiteCD:Start(13) -- (25H Lordaeron 2022/09/03 || 25H Lordaeron 2022/09/28 || 25H Lordearon 2022/10/09 || 25N Lordaeron 2022/10/13 || 25N Lordaeron 2022/10/21 || 25N Lordaeron 2022/12/07) - 28 || 26.2 || 22.0 || 20.2 || 16.5 || 13.0
				timerAcidicSpewCD:Start(15.9) -- (25H Lordaeron 2022/09/03) - 21 || 15.9
			else
				timerSweepCD:Start(22, acidmaw)	-- Log review: 22-24s (N/H?)
				timerParalyticSprayCD:Start(16.7)	-- (old log review (N/H?) || 25H Lordaeron 2022/09/28) - 18-20 || 16.7
			end
		elseif npcId == 34799 then -- Dreadscale
			self.vb.DreadscaleMobile = not self.vb.DreadscaleMobile
			DBM:Debug("Dreadscale PHASE_STATIONARY: " .. tostring(self.vb.DreadscaleMobile), 2)
			timerSubmerge:Start(44, dreadscale)
			if self.vb.DreadscaleMobile then
				timerSlimePoolCD:Start(dreadscale) -- (25H Lordaeron 2022/09/03) - 12
				timerMoltenSpewCD:Start(21.4) -- (25H Lordaeron 2022/09/03 || 25H Lordaeron 2022/09/28 || 25N Lordaeron 2022/10/13) - 24 || 21.8 || 21.4
				timerBurningBiteCD:Start(14.2) -- (25H Lordaeron 2022/09/03 || 25H Lordaeron 2022/09/28) - 19 || 14.2
			else
				timerSweepCD:Start(14.8, dreadscale) -- (25H Lordaeron 2022/09/03 || 25N Lordaeron 2022/10/21) - 17 || 14.8
				timerBurningSprayCD:Start(13.4) -- (25H Lordaeron 2022/09/03 || 25H Lordaeron 2022/09/28) - 20 || 13.5
			end
		end
	end
end]]
