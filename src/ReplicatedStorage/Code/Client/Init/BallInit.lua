-- BallInit.lua — Client: binds the ball entity to its Workspace part + registers a ref.
-- Reactive (monitor) rather than polling, mirroring RemoteInterpolationInit: the
-- monitor fires once when the ball entity arrives (BALL + SERVER_POSITION), then we
-- resolve ROOTPART. The ball's part is a raw Instance and is never replicated over the
-- ECS wire (Instances must not go on the wire), so it's bound locally. Registered
-- before apply_full so the monitor catches the ball as it streams in.
--
-- The part may stream in slightly after the entity, so WaitForChild runs inside a
-- task.spawn — never yield the replication thread the monitor fires on.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local jecsUtils = require(ReplicatedStorage.Packages["jecs-utils"])
local ref = jecsUtils.ref

return function()
	local ballQuery = world:query(components.SERVER_POSITION):with(tags.BALL)

	jecsUtils.monitor(ballQuery).added(function(entity)
		-- task.spawn: the monitor fires inside Replecs's replication apply; WaitForChild
		-- yields and that thread must not be yielded. No timeout — the ball part is
		-- permanent and server-spawned, so it always arrives; a cap could only ever
		-- cause a silent bind failure for a laggy/streaming client.
		task.spawn(function()
			local ballPart = Workspace:WaitForChild("Ball")

			world:set(entity, components.ROOTPART, ballPart)
			ref.set(ballPart, entity)
			-- Interpolation state (SNAPSHOT_BUFFER etc.) is seeded separately by
			-- RemoteInterpolationInit's monitor; RemoteVisualInterpolator renders
			-- the ball once ROOTPART exists.
		end)
	end)
end
