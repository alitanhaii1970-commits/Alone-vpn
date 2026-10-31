# Connection architecture (Phase 1)

Baseline: release v1.7.1. The app is Flutter/Dart; the tunnel engine is the pinned `v2ray_box` plugin (Xray via libXray, plus OpenVPN for Android for .ovpn profiles). There is no in-repo `XrayBridge.kt`: the Kotlin bridge lives inside the plugin. Kotlin coroutines / StateFlow therefore do not apply; the project's own pattern (`ChangeNotifier` + typed enums) is used.

```
UI (dial, cards)  ->  ConnectionManager  ->  VpnEngine
                                              |- XrayEngine  -> Conn (existing state machine, unchanged) -> Engine / v2ray_box
                                              `- SmartEngine  (placeholder: not installed)
```

- `lib/core/connection/link_state.dart` — `LinkState` (disconnected, preparing, connecting, connected, disconnecting, error, engineNotInstalled) and `EngineStatus`.
- `lib/core/connection/vpn_engine.dart` — `VpnEngine` interface, `EngineKind`, `EngineNotInstalled`.
- `lib/core/connection/engines.dart` — `XrayEngine` (adapter over `Conn`, adds no behaviour) and `SmartEngine` (never connects, never reports activity).
- `lib/core/connection/connection_manager.dart` — the single controller: one request at a time, mutual exclusion (the running engine is stopped and confirmed down before another starts; if it cannot be stopped the new one is not started), start/stop timeouts, cancellation, no cached state (all statuses are read from the engines).
- `lib/ui/screens/connection_cards.dart` — Smart Connection card (disabled, states that licensing and integration approval are pending) and Manual Connection card (real status, real errors).
- The home dial now calls `ConnectionManager.toggle(EngineKind.manual)`, which delegates to the same `Conn` methods as before.

Not done in this phase: no Lantern/Radiance code or binaries, no GPL decision, no release.
