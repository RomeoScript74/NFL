-- PipeLines.lua -- Phase and pipeline definitions (shared).
-- Ported from FPS reference; NFL may add/remove phases as needed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local planck = require(ReplicatedStorage.Packages.planck)
local phase = planck.Phase
local pipeline = planck.Pipeline

-- Physics phases (60 Hz fixed-step)
local Timers            = phase.new("Timers")
local PreInput          = phase.new("PreInput")
local Input             = phase.new("Input")
local PreCombat         = phase.new("PreCombat")
local Combat            = phase.new("Combat")
local PostCombat        = phase.new("PostCombat")
local Movement          = phase.new("Movement")
local Gravity           = phase.new("Gravity")
local PostGravity       = phase.new("PostGravity")
local Impulse           = phase.new("Impulse")
local WallCollision     = phase.new("WallCollision")
local PostWallCollision = phase.new("PostWallCollision")
local Integration       = phase.new("Integration")
local Collision         = phase.new("Collision")
local PostCollision     = phase.new("PostCollision")
local Cleanup           = phase.new("Cleanup")
local Resolve           = phase.new("Resolve")
local React             = phase.new("React")
local PostReact         = phase.new("PostReact")
local Flush             = phase.new("Flush")
local VisualSmoothing   = phase.new("VisualsSmoothing")
local VisualsIK         = phase.new("VisualsIK")
local InputBridge       = phase.new("InputBridge")

local Simulation = pipeline.new("Simulation")
	:insert(Timers)
	:insert(PreInput)
	:insert(Input)
	:insert(PreCombat)
	:insert(Combat)
	:insert(PostCombat)
	:insert(Movement)
	:insert(Gravity)
	:insert(PostGravity)
	:insert(Impulse)
	:insert(WallCollision)
	:insert(PostWallCollision)
	:insert(Integration)
	:insert(Collision)
	:insert(PostCollision)
	:insert(Cleanup)

local EffectsPipeline = pipeline.new("Effects")
	:insert(Resolve)
	:insert(React)
	:insert(PostReact)
	:insert(Flush)

local VisualsPipeline = pipeline.new("VisualsPipeline")
	:insert(VisualSmoothing)
	:insert(VisualsIK)

local InputBridgePipeline = pipeline.new("InputBridgePipeline")
	:insert(InputBridge)

return {
	Pipelines = {
		Simulation          = Simulation,
		Effects             = EffectsPipeline,
		Visuals             = VisualsPipeline,
		InputBridge         = InputBridgePipeline,
	},

	Phases = {
		Timers              = Timers,
		PreInput            = PreInput,
		Input               = Input,
		PreCombat           = PreCombat,
		Combat              = Combat,
		PostCombat          = PostCombat,
		Movement            = Movement,
		Gravity             = Gravity,
		PostGravity         = PostGravity,
		Impulse             = Impulse,
		WallCollision       = WallCollision,
		PostWallCollision   = PostWallCollision,
		Integration         = Integration,
		Collision           = Collision,
		PostCollision       = PostCollision,
		Cleanup             = Cleanup,

		Resolve             = Resolve,
		React               = React,
		PostReact           = PostReact,
		Flush               = Flush,

		VisualSmoothing     = VisualSmoothing,
		VisualsIK           = VisualsIK,

		InputBridge         = InputBridge,
	},
}
