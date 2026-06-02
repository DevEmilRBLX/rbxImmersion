local Components = script.Parent.Components

type ScreenBorderModule = typeof(require(Components.screenBorder))
type CameraModule = typeof(require(Components.Camera))
type AudioModule = typeof(require(Components.Audio))
type AudioFxModule = typeof(require(Components.audioFx))

type Modules = {
	screenBorder: ScreenBorderModule,
	Camera: CameraModule,
	Audio: AudioModule,
	AudioFx: AudioFxModule,
}

local rbxImmersion: Modules = {
	screenBorder = require(Components.screenBorder),
	Camera = require(Components.Camera),
	Audio = require(Components.Audio),
	AudioFx = require(Components.audioFx),
}

return rbxImmersion