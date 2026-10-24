# OpenVPN for Android remote API

`aidl/` and `java/` hold the *remote API* of [OpenVPN for Android](https://github.com/schwabe/ics-openvpn)
(`de.blinkt.openvpn`) by Arne Schwabe: the three AIDL interfaces and `APIVpnProfile`. The author publishes
these files for exactly this use and exempts them from the GPLv2 (see the header of `APIVpnProfile.java`
and `remoteExample/LICENSE.remoteExample`, Apache-2.0).

ALONE VPN does **not** contain the OpenVPN engine. It talks to the separately installed OpenVPN for Android
app through this API; `scripts/patch_incoming_intents.py` copies these files into the generated Android project.
