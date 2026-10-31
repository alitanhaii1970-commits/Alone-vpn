# ALONE VPN v14 — Glass layer (Phase 1) · 2026-10-31

## What changed vs v13 (everything else is untouched)
- Additive `<style id="alone-glass">` + `<script id="alone-glass-js">`. Delete both → exact v13.
- Glass depth tiers: bar/sheet/dialog (`.glass`) get sheen, rim light, coloured bounce light; cards get the same look with NO extra blur layer (cheap).
- Press/hover glint that follows the finger/mouse; press physics on pressable cards only.
- Perf: removed the redundant `blur(42px)` + blend on the 3 ambient orbs; animations pause when the tab is hidden; adaptive "lite glass" if the first ~45 frames are slow (<~38 fps); fallback if `backdrop-filter` is unsupported.
- Real phones (≤520px, touch): full-screen app, no phone frame/camera hole/fake status bar, safe-area aware nav. Frame stays on desktop.
- Version strings v13 → v14.

## Libraries used
None added. v13 already has spring easing (`linear()`), inline SVG icons and canvas charts; GSAP/Motion/Lucide/Chart.js would only add weight.

## Reviewed libraries (license + latest version from the npm registry, 2026-10-31)
| Project | Version | License |
|---|---|---|
| motiondivision/motion | 14.9.0 | MIT |
| greensock/GSAP | 3.15.0 | GSAP "no charge" license (custom) |
| juliangarnier/anime | 4.5.0 | MIT |
| airbnb/lottie-web | 5.13.0 | MIT |
| lucide-icons/lucide | 1.65.0 | ISC |
| iconoir-icons/iconoir | 7.12.1 | MIT |
| floating-ui/floating-ui | 1.8.0 | MIT |
| radix-ui/primitives | 1.3.1 | MIT |
| tradingview/lightweight-charts | 5.2.1 | Apache-2.0 |
| chartjs/Chart.js | 4.6.1 | MIT |
| apache/echarts | 6.1.0 | Apache-2.0 |
| material-components/material-web | 2.5.0 | Apache-2.0 |

Not verified: star counts / last-push dates (GitHub API returned 403/429 from my sandbox). Glassmorphism repo search only returned small projects (e.g. VII-Cae/hyalite--liquid-glass, MIT) — I borrowed ideas only, no code.

## Tests actually run
- JS syntax (node --check), `#alone-spec` JSON parse, duplicate-id scan: OK.
- Headless Chromium 141 @390×844 touch: loads, 0 page errors (1 pre-existing network error: external font, no internet in sandbox); home/settings/servers, dark + light + saver rendered and viewed; glint JS verified; desktop keeps the frame.
- NOT tested: real Android device, real frame rate, RTL↔LTR/English pass, import/export/config flows (unchanged from v13), screen readers.

## Still simulated (unchanged)
Connect/disconnect, ping, traffic and stats, Xray core status, VpnService — everything marked `data-sim="true"` and the `real` list in `#alone-spec`.

## NOT done in this phase
Subscription URLs, QR import, Hysteria2 parsing, new traffic charts, Blur/Animation quality settings UI, skeleton redesign, Android native guide.
