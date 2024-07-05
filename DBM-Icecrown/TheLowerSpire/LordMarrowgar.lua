local mod	= DBM:NewMod("LordMarrowgar", "DBM-Icecrown", 1)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20240705182820")
mod:SetCreatureID(36612)
mod:SetUsedIcons(1, 2, 3, 4, 5, 6, 7, 8)
mod:SetHotfixNoticeRev(20221117000000)
mod:SetMinSyncRevision(20221117000000)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 69076",
	"SPELL_AURA_REMOVED 69065 69076",
	"SPELL_CAST_START 69057 70826 72088 72089 73144 73145 69076",
	"SPELL_SUMMON 69062 72669 72670"
)

local preWarnWhirlwind		= mod:NewSoonAnnounce(69076, 3)
local warnBoneSpike			= mod:NewCastAnnounce(69057, 2)
local warnImpale			= mod:NewTargetNoFilterAnnounce(72669, 3)

local specWarnColdflame		= mod:NewSpecialWarningGTFO(69146, nil, nil, nil, 1, 8)
local specWarnWhirlwind		= mod:NewSpecialWarningRun(69076, nil, nil, nil, 4, 2)

local timerBoneSpike		= mod:NewCDTimer(15, 69057, nil, nil, nil, 1, nil, DBM_COMMON_L.DAMAGE_ICON, true) -- Has two sets of spellIDs, one before bone storm and one during bone storm (both sets are separated below). Will use UNIT_SPELLCAST_START for calculations since it uses spellName and thus already groups them in the log. 5s variance [15-20]. Added "keep" arg.
local timerWhirlwindCD		= mod:NewCDTimer(90, 69076, nil, nil, nil, 2, nil, DBM_COMMON_L.MYTHIC_ICON, true) -- 5s variance [90-95]. Added "keep" arg.
local timerWhirlwind		= mod:NewBuffActiveTimer(30, 69076, nil, nil, nil, 6) -- Manual calculation SAR-SAA. 20s on 10man, 30.14s on 25man (there is SARefresh 0.14s after SAA)
local timerBoned			= mod:NewAchievementTimer(8, 4610)
local timerBoneSpikeUp		= mod:NewCastTimer(69057)
local timerWhirlwindStart	= mod:NewCastTimer(69076)

local soundBoneSpike		= mod:NewSound(69057)
local soundBoneStorm		= mod:NewSound(69076)

local berserkTimer			= mod:NewBerserkTimer(600)

mod:AddSetIconOption("SetIconOnImpale", 72669, true, 0, {8, 7, 6, 5, 4, 3, 2, 1})

mod.vb.impaleIcon = 8
local spinning = false

function mod:OnCombatStart(delay)
	spinning = false
	preWarnWhirlwind:Schedule(40-delay)
	timerWhirlwindCD:Start(45-delay) -- 5s variance [45-50]
	timerBoneSpike:Start(10-delay) -- 5s variance [10-15]
	berserkTimer:Start(-delay)
	self:RegisterShortTermEvents(
		"SPELL_PERIODIC_DAMAGE 69146 70823 70824 70825",
		"SPELL_PERIODIC_MISSED 69146 70823 70824 70825"
	)
end

function mod:OnCombatEnd()
	self:UnregisterShortTermEvents()
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 69076 then						-- Bone Storm (Whirlwind)
		spinning = true
		specWarnWhirlwind:Show()
		specWarnWhirlwind:Play("justrun")
		if self:IsDifficulty("normal10", "heroic10") then
			timerWhirlwind:Show(20)
		else
			timerWhirlwind:Show()
		end
		if self:IsNormal() then
			timerBoneSpike:Cancel()						-- He doesn't do Bone Spike Graveyard during Bone Storm on normal
		end
	end
end

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 69065 then						-- Impaled
		if self.Options.SetIconOnImpale then
			self:SetIcon(args.destName, 0)
		end
	elseif spellId == 69076 then
		spinning = false
		timerWhirlwind:Cancel()
		if self:IsNormal() then
			timerBoneSpike:Start(15)					-- He will do Bone Spike Graveyard [15-20] seconds after whirlwind ends on normal
		end
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(69057, 70826, 72088, 72089) or args:IsSpellID(73144, 73145) then	-- Bone Spike Graveyard (no bone storm) | (during bone storm HC)
		-- REVIEW! Check if it casts 73144/73145, and uses "no bone storm" IDs with no cast time. There is a SPELL_CAST_START but no UNIT_SPELLCAST_START, only SUCCEEDED.
		if not spinning then
			warnBoneSpike:Show()
		end
		if args:IsSpellID(73144, 73145) then
			DBM:AddMsg("Bone Spike Graveyard 73144/73145 SPELL_CAST_START fixed on server script. Notify Zidras on Discord or GitHub")
		end
		-- end workaround
		timerBoneSpike:Start()
		timerBoneSpikeUp:Start()
		soundBoneSpike:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\Bone_Spike_cast.mp3")
	elseif args.spellId == 69076 then
		preWarnWhirlwind:Schedule(85)
		timerWhirlwindCD:Start()
		timerWhirlwindStart:Start()
		soundBoneStorm:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\Bone_Storm_cast.mp3")
	end
end

function mod:SPELL_PERIODIC_DAMAGE(_, _, _, destGUID, _, _, spellId, spellName)
	if (spellId == 69146 or spellId == 70823 or spellId == 70824 or spellId == 70825) and destGUID == UnitGUID("player") and self:AntiSpam() then		-- Coldflame, MOVE!
		specWarnColdflame:Show(spellName)
		specWarnColdflame:Play("watchfeet")
	end
end
mod.SPELL_PERIODIC_MISSED = mod.SPELL_PERIODIC_DAMAGE

function mod:SPELL_SUMMON(args)
	if args:IsSpellID(69062, 72669, 72670) then			-- Impale
		warnImpale:CombinedShow(0.3, args.sourceName)
		timerBoned:Restart()
		if self.Options.SetIconOnImpale then
			self:SetIcon(args.sourceName, self.vb.impaleIcon)
		end
		if self.vb.impaleIcon < 1 then
			self.vb.impaleIcon = 8
		end
		self.vb.impaleIcon = self.vb.impaleIcon - 1
	end
end
