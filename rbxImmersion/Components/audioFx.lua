--[[
	AudioFx.lua
	Written by https://github.com/itsriskyrn
	Documentation: https://github.com/DevEmilRBLX/rbxImmersion/wiki/AudioFx
]]

local AudioFx = {}
AudioFx.__index = AudioFx

-- Services
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService   = game:GetService("RunService")
local Players      = game:GetService("Players")

-- Dependencies
local Audio = require(script.Parent.Audio)

-- Singleton
local _instance = nil

-- Internal aliases
local ALIAS_HEARTBEAT = "_fx_heartbeat"
local ALIAS_TINNITUS  = "_fx_tinnitus"

-- Default FX assets
local _config = {
	heartbeatId = "rbxassetid://139459003161851",
	tinnitusId  = "rbxassetid://140036050358607",
}

-- Configure
function AudioFx.Configure(cfg: { heartbeatId: string?, tinnitusId: string? })
	if cfg.heartbeatId then _config.heartbeatId = cfg.heartbeatId end
	if cfg.tinnitusId then _config.tinnitusId = cfg.tinnitusId end
end


function AudioFx:_getEqualizer()
	local eq = SoundService:FindFirstChild("_rbxImmersion_EQ")

	if not eq then
		eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "_rbxImmersion_EQ"
		eq.Parent = SoundService
	end

	return eq
end

-- Get reverb
function AudioFx:_getReverb()
	local rv = SoundService:FindFirstChild("_rbxImmersion_Reverb")

	if not rv then
		rv = Instance.new("ReverbSoundEffect")
		rv.Name = "_rbxImmersion_Reverb"
		rv.Parent = SoundService
	end

	return rv
end

-- Constructor
local function new()
	local self = setmetatable({}, AudioFx)

	self._audio = Audio.Get()
	self._heartbeatConnection = nil

	self._audio:Register(ALIAS_HEARTBEAT, _config.heartbeatId, {
		Volume = 0,
		Looped = true,
		Group  = "fx",
	})

	self._audio:Register(ALIAS_TINNITUS, _config.tinnitusId, {
		Volume = 0,
		Looped = true,
		Group  = "fx",
	})

	return self
end


function AudioFx.Get()
	if not _instance then
		_instance = new()
	end
	return _instance
end

-- Muffle
function AudioFx:Muffle(intensity: number, duration: number)
	intensity = math.clamp(intensity, 0, 1)

	local eq = self:_getEqualizer()

	local target = {
		HighGain = -14 * intensity,
		MidGain  = -8 * intensity,
		LowGain  = 0,
	}

	if duration and duration > 0 then
		TweenService:Create(eq, TweenInfo.new(duration, Enum.EasingStyle.Sine), target):Play()
	else
		eq.HighGain = target.HighGain
		eq.MidGain  = target.MidGain
		eq.LowGain  = target.LowGain
	end
end

-- Reverb
function AudioFx:Reverb(preset: string, duration: number)
	local rv = self:_getReverb()

	local presets = {
		none    = {0,   0,   0,   -96, 0},
		room    = {0.4, 0.6, 0.5, -10,  0},
		cave    = {2.0, 0.9, 0.7, -6,   0},
		hall    = {1.5, 0.8, 0.8, -8,   0},
		arena   = {3.5, 1.0, 0.9, -4,   0},
		outdoor = {0.8, 0.3, 0.3, -16,  0},
	}

	local p = presets[preset:lower()]
	if not p then
		warn(("AudioFx:Reverb() unknown preset '%s'"):format(preset))
		return
	end

	local target = {
		DecayTime = p[1],
		Density   = p[2],
		Diffusion = p[3],
		WetLevel  = p[4],
		DryLevel  = p[5],
	}

	if duration and duration > 0 then
		TweenService:Create(rv, TweenInfo.new(duration, Enum.EasingStyle.Sine), target):Play()
	else
		for k, v in pairs(target) do
			rv[k] = v
		end
	end
end

-- Heartbeat start
function AudioFx:StartHeartbeat(minHealth: number, maxHealth: number)
	minHealth = minHealth or 0
	maxHealth = maxHealth or 50

	self:StopHeartbeat()

	local audio = self._audio
	audio:Play(ALIAS_HEARTBEAT)

	local sound = audio:GetSound(ALIAS_HEARTBEAT)
	local player = Players.LocalPlayer

	local function getHealth()
		local char = player.Character
		if not char then return maxHealth end

		local hum = char:FindFirstChildOfClass("Humanoid")
		return hum and hum.Health or maxHealth
	end

	self._heartbeatConnection = RunService.Heartbeat:Connect(function()
		local health = getHealth()

		if health >= maxHealth then
			sound.Volume = 0
			sound.PlaybackSpeed = 1
			return
		end

		local t = 1 - math.clamp((health - minHealth) / (maxHealth - minHealth), 0, 1)

		sound.Volume = t * 0.8
		sound.PlaybackSpeed = 0.8 + (t * 0.8)
	end)
end

-- Heartbeat stop
function AudioFx:StopHeartbeat()
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	self._audio:Stop(ALIAS_HEARTBEAT)

	local sound = self._audio:GetSound(ALIAS_HEARTBEAT)
	sound.Volume = 0
	sound.PlaybackSpeed = 1
end

-- Tinnitus
function AudioFx:Tinnitus(duration: number, volume: number)
	duration = duration or 3
	volume = volume or 0.6

	local audio = self._audio
	local sound = audio:GetSound(ALIAS_TINNITUS)

	sound:Stop()
	sound.TimePosition = 0

	sound.Volume = volume
	sound.PlaybackSpeed = 1
	sound:Play()

	local tween = TweenService:Create(
		sound,
		TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
		{ Volume = 0 }
	)

	tween:Play()
	tween.Completed:Connect(function()
		sound:Stop()
	end)
end

-- Fade
function AudioFx:FadeGroup(groupName: string, targetVolume: number, duration: number)
	self._audio:SetGroupVolume(groupName, targetVolume, duration)
end

function AudioFx:Destroy()
	self:StopHeartbeat()

	self._audio:Unregister(ALIAS_HEARTBEAT)
	self._audio:Unregister(ALIAS_TINNITUS)

	local eq = SoundService:FindFirstChild("_rbxImmersion_EQ")
	if eq then eq:Destroy() end

	local rv = SoundService:FindFirstChild("_rbxImmersion_Reverb")
	if rv then rv:Destroy() end

	_instance = nil
end

return AudioFx