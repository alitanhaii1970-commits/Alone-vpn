# Connection architecture

The app is Flutter/Dart. There is one tunnel at a time, and one controller in front of it.

```
UI (dial, two cards) -> ConnectionManager -> VpnEngine
                                              |- XrayEngine     -> Conn (existing state machine) -> Xray / OpenVPN profiles the user added
                                              `- VpnGateEngine  -> SmartServerManager (VPN Gate API + cache)
                                                                -> SmartTunnel -> Conn (OpenVPN for Android remote API)
```

- `lib/core/connection/link_state.dart`: typed `LinkState` (disconnected, preparing, connecting, connected, disconnecting, error, engineNotInstalled).
- `lib/core/connection/connection_manager.dart`: the only place that starts/stops engines. One request at a time; the running engine is stopped (and confirmed down) before another starts; start/stop timeouts and cancellation; no cached state, everything is read from the engines.
- `lib/core/connection/engines.dart`: `XrayEngine`, an adapter over the existing `Conn`; it only reports sessions the user started.
- `lib/core/connection/vpngate_engine.dart`: Smart mode. Picks relays by quality, tries them in turn, and reports "connected" only after the tunnel is up AND the public IP seen from outside has changed.
- `Conn` gained one additive thing: `connect({Server? smart})` and `origin`. A Smart profile is transient and is never added to the user's server list.

## Smart mode data
Source: the official VPN Gate API, https://www.vpngate.net/api/iphone/ (CSV with an inline OpenVPN profile per relay). Every profile is validated (no script directives, no management channel, no credentials prompt, inline CA only) and rejected otherwise. The last good list is cached on the device and used when the API is down.

## What Smart mode is not
- The relays are run by volunteers; they are not ALONE servers. Operators may keep logs; the app shows each server's own log policy after connecting.
- Ping and speed shown are what VPN Gate reports, not measurements made by the app.
- The OpenVPN engine is the separately installed "OpenVPN for Android" app, used through its official remote API (see `android_res/ovpn/NOTICE.md`). ALONE VPN does not embed an OpenVPN engine.
