--[[
	Audio.lua
	Written by https://github.com/itsriskyrn
	Documentation: https://github.com/DevEmilRBLX/rbxImmersion/wiki/Audio
]]

local Audio = {}
Audio.__index = Audio

-- Services
local TweenService  = game:GetService("TweenService")
local SoundService  = game:GetService("SoundService")

local _instance = nil

-- Private helpers

-- Returns or creates a SoundGroup inside SoundService
function Audio:_getOrCreateSoundGroup(groupName: string)
	local sg = SoundService:FindFirstChild("_rbxI_" .. groupName)
	if not sg then
		sg          = Instance.new("SoundGroup")
		sg.Name     = "_rbxI_" .. groupName
		sg.Volume   = 1
		sg.Parent   = SoundService
	end
	return sg
end

-- Returns or creates the container folder for raw Sound objects
function Audio:_getOrCreateContainer()
	local c = SoundService:FindFirstChild("_rbxImmersion_Audio")
	if not c then
		c        = Instance.new("Folder")
		c.Name   = "_rbxImmersion_Audio"
		c.Parent = SoundService
	end
	return c
end

function Audio:_assertTrack(alias: string)
	assert(self._tracks[alias], ("Audio — no track registered with alias '%s'"):format(alias))
end

-- Constructor

local function new()
	local self = setmetatable({}, Audio)

	self._tracks       = {}
	self._groups       = {}
	self._masterVolume = 1

	self._container    = self:_getOrCreateContainer()

	return self
end

-- Public API

function Audio.Get()
	if not _instance then
		_instance = new()
	end
	return _instance
end

-- Registration
function Audio:Register(alias: string, assetId: string, options)
	assert(type(alias)   == "string", "Audio:Register() — alias must be a string")
	assert(type(assetId) == "string", "Audio:Register() — assetId must be a string")

	options = options or {}

	local groupName = options.Group or "master"
	local sg        = self:_getOrCreateSoundGroup(groupName)
	self._groups[groupName] = sg

	local sound               = Instance.new("Sound")
	sound.Name                = "_rbxI_" .. alias
	sound.SoundId             = assetId
	sound.Volume              = options.Volume        or 1
	sound.Looped              = options.Looped        or false
	sound.PlaybackSpeed       = options.PlaybackSpeed or 1
	sound.RollOffMaxDistance  = options.RollOff       or 0
	sound.SoundGroup          = sg
	sound.Parent              = self._container

	self._tracks[alias] = { sound = sound, group = groupName }
end

-- Unregister and destroy a track
function Audio:Unregister(alias: string)
	self:_assertTrack(alias)
	local entry = self._tracks[alias]
	entry.sound:Destroy()
	self._tracks[alias] = nil
end

-- Playback 
function Audio:Play(alias: string, options)
	self:_assertTrack(alias)
	options = options or {}

	local sound = self._tracks[alias].sound

	if options.volume then
		sound.Volume = options.volume
	end

	if options.fadeIn and options.fadeIn > 0 then
		local targetVolume = sound.Volume
		sound.Volume = 0
		sound:Play()
		TweenService:Create(sound, TweenInfo.new(options.fadeIn, Enum.EasingStyle.Sine), { Volume = targetVolume }):Play()
	else
		sound:Play()
	end
end

-- Stop a registered track
function Audio:Stop(alias: string, options)
	self:_assertTrack(alias)
	options = options or {}

	local sound = self._tracks[alias].sound

	if options.fadeOut and options.fadeOut > 0 then
		local tween = TweenService:Create(sound, TweenInfo.new(options.fadeOut, Enum.EasingStyle.Sine), { Volume = 0 })
		tween:Play()
		tween.Completed:Connect(function()
			sound:Stop()
		end)
	else
		sound:Stop()
	end
end

-- Pause a registered track
function Audio:Pause(alias: string)
	self:_assertTrack(alias)
	self._tracks[alias].sound:Pause()
end

-- Resume a paused track
function Audio:Resume(alias: string)
	self:_assertTrack(alias)
	self._tracks[alias].sound:Resume()
end

-- Returns true if the track is currently playing
function Audio:IsPlaying(alias: string): boolean
	self:_assertTrack(alias)
	return self._tracks[alias].sound.Playing
end

-- Crossfade from one track to another over `duration` seconds
function Audio:Crossfade(fromAlias: string, toAlias: string, duration: number)
	self:_assertTrack(fromAlias)
	self:_assertTrack(toAlias)
	duration = duration or 1

	local fromSound = self._tracks[fromAlias].sound
	local toSound   = self._tracks[toAlias].sound

	local fromVolume = fromSound.Volume

	toSound.Volume = 0
	toSound:Play()

	local fadeOut = TweenService:Create(fromSound, TweenInfo.new(duration, Enum.EasingStyle.Sine), { Volume = 0 })
	local fadeIn  = TweenService:Create(toSound,   TweenInfo.new(duration, Enum.EasingStyle.Sine), { Volume = fromVolume })

	fadeOut:Play()
	fadeIn:Play()

	fadeOut.Completed:Connect(function()
		fromSound:Stop()
		fromSound.Volume = fromVolume 
	end)
end

-- Set the volume of a single track (optionally tweened)
function Audio:SetVolume(alias: string, volume: number, duration: number)
	self:_assertTrack(alias)
	volume = math.clamp(volume, 0, 1)

	local sound = self._tracks[alias].sound
	if duration and duration > 0 then
		TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Sine), { Volume = volume }):Play()
	else
		sound.Volume = volume
	end
end

-- Set the volume of an entire group (e.g. mute all "sfx")
function Audio:SetGroupVolume(groupName: string, volume: number, duration: number)
	local sg = SoundService:FindFirstChild("_rbxI_" .. groupName)
	if not sg then
		warn(("Audio:SetGroupVolume() — group '%s' does not exist"):format(groupName))
		return
	end
	volume = math.clamp(volume, 0, 1)
	if duration and duration > 0 then
		TweenService:Create(sg, TweenInfo.new(duration, Enum.EasingStyle.Sine), { Volume = volume }):Play()
	else
		sg.Volume = volume
	end
end

-- Set master volume (affects all SoundGroups managed by this module)
function Audio:SetMasterVolume(volume: number, duration: number)
	volume = math.clamp(volume, 0, 1)
	self._masterVolume = volume

	for _, sg in pairs(self._groups) do
		if duration and duration > 0 then
			TweenService:Create(sg, TweenInfo.new(duration, Enum.EasingStyle.Sine), { Volume = volume }):Play()
		else
			sg.Volume = volume
		end
	end
end

-- Playback Speed 
function Audio:SetSpeed(alias: string, speed: number, duration: number)
	self:_assertTrack(alias)
	local sound = self._tracks[alias].sound
	if duration and duration > 0 then
		TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Sine), { PlaybackSpeed = speed }):Play()
	else
		sound.PlaybackSpeed = speed
	end
end

-- Stop all registered tracks at once
function Audio:StopAll(options)
	for alias, _ in pairs(self._tracks) do
		self:Stop(alias, options)
	end
end

-- Pause all registered tracks at once
function Audio:PauseAll()
	for alias, _ in pairs(self._tracks) do
		self:Pause(alias)
	end
end

-- Resume all registered tracks at once
function Audio:ResumeAll()
	for alias, _ in pairs(self._tracks) do
		self:Resume(alias)
	end
end

-- Stop all tracks in a specific group
function Audio:StopGroup(groupName: string, options)
	for alias, entry in pairs(self._tracks) do
		if entry.group == groupName then
			self:Stop(alias, options)
		end
	end
end

-- Get the raw Sound object for a track (for advanced use)
function Audio:GetSound(alias: string): Sound
	self:_assertTrack(alias)
	return self._tracks[alias].sound
end

-- Get a list of all registered aliases
function Audio:GetAllAliases(): { string }
	local list = {}
	for alias in pairs(self._tracks) do
		table.insert(list, alias)
	end
	return list
end

-- Get all aliases belonging to a group
function Audio:GetGroupAliases(groupName: string): { string }
	local list = {}
	for alias, entry in pairs(self._tracks) do
		if entry.group == groupName then
			table.insert(list, alias)
		end
	end
	return list
end

-- Destroy all tracks, groups, and reset the singleton
function Audio:Destroy()
	for _, entry in pairs(self._tracks) do
		entry.sound:Destroy()
	end

	local container = SoundService:FindFirstChild("_rbxImmersion_Audio")
	if container then container:Destroy() end

	for _, sg in pairs(self._groups) do
		sg:Destroy()
	end

	self._tracks  = {}
	self._groups  = {}
	_instance     = nil
end

return Audio