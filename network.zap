-- network.zap -- ZAP network protocol definition for NFL game.
-- Generate with: zap build network.zap

opt server_output = "src/ServerScriptService/Server/ZapServer.lua"
opt client_output = "src/ReplicatedStorage/Code/Client/ZapClient.lua"

-- Reliable server-to-client: full state + important params
event OnReliableUpdates = {
    from: Server,
    type: Reliable,
    call: Polling,
    data: (
        buf: buffer,
        variants: Instance[..256][..256]
    )
}

-- Unreliable server-to-client: positions, velocities, remote tick
event OnUnreliableUpdates = {
    from: Server,
    type: Unreliable,
    call: Polling,
    data: (
        buf: buffer(..512),
        variants: Instance[..32][..32]
    )
}

-- Client requests full world state from server (sync, yielded on client)
funct WaitForServer = {
    call: Sync,
    args: (),
    rets: (
        buffer,
        Instance[..256][..256]
    )
}

-- Client requests re-sync (can be called mid-game)
funct OnReceiveFull = {
    call: Sync,
    args: (),
    rets: (
        buffer,
        Instance[..256][..256]
    )
}

-- NFL input frame — bitmask for input flags, no FPS-specific fields
type InputFrame = struct {
    X: f32,
    Z: f32,
    Tick: u32,
    Yaw: f32,
    Pitch: f32,
    Flags: u32,
    RenderFrame: f32
}

event MoveInput = {
    from: Client,
    type: Unreliable,
    call: SingleAsync,
    data: struct {
        History: InputFrame[..32]
    }
}
