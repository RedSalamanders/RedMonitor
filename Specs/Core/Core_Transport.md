# ETW transport and producer client

Compatibility provider: `RedSalamanderMonitor`, GUID `{440c70f6-6c6b-4ff7-9a3f-0b7db411b31a}`.
`DebugMessage` fields remain `Type` UINT32, `ProcessId` UINT32, `ThreadId` UINT32,
`FileTime` UINT64 Windows FILETIME and `Message` counted UTF-16. Keyword 1, information level.
Legacy `PerfScope` fields and decoding remain supported.

Severity values are Text=0, Error=1, Warning=2, Info=4, Perf=8, Debug=16. Filter bits are
Text=1, Error=2, Warning=4, Info=8, Perf=16, Debug=32. All=63 is a filter mask, never a message severity.
The minimal client exposes explicit registration lifetime, bounded counted text and status return.
One client/provider owner per module; do not share a provider handle across DLL boundaries. Stop producer
threads before destroying the module owner. A disabled provider returns before formatting or allocation.
Payloads exceeding 16000 UTF-16 code units are rejected with ERROR_BUFFER_OVERFLOW.

The viewer currently subscribes to this one provider; multi-provider/source selection remains future work.
All four application adapters use the same Client.h normalization: a required static app label becomes a bounded [Application] text prefix and an additive counted UTF-16 Application field. Legacy fields and their types remain unchanged; old viewers ignore the extra field. PID/TID metadata remains authoritative. Independent apps retain their
existing dedicated performance providers and fallback log policy.

Sessions are owned explicitly. Starting must never stop or attach to a pre-existing session by name.
Callback routing belongs to each session's Context/UserContext, never a global listener pointer.
Stop first rejects callbacks, closes its consumer, then waits at most five seconds. Only shared owned
callback state may outlive that bounded wait. GUI result payloads use the registered token mechanism
and are drained at WM_NCDESTROY. Permission denial is visible and recoverable without file-view loss.

Self Info/Perf diagnostics are runtime opt-in with --etw; default operation must not feed its own log
back into the viewer. Real event roundtrip and permission-denial cases are separate validation gates.
