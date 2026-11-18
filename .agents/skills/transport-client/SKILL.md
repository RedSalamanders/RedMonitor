---
name: transport-client
description: Change the RedMonitor producer SDK, wire decoder or ETW session lifecycle. Use when changing the producer interface, the event GUID, field names or types, severity and filter mapping, provider registration and shutdown, or how the viewer owns its ETW session.
---

# transport-client

Read Specs/Core/Core_Transport.md. Keep GUID, field names/types and severity/filter distinctions compatible. One registration owner per module; stop producers before disposal. Test real roundtrip, disabled path, payload bounds, foreign-session ownership and bounded shutdown.
