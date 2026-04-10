# MVP Checklist

| Feature Area | Status | Notes |
|---|---|---|
| Core loop | Done | Heat -> cooling -> relay/clear -> transition -> next sector is playable. |
| Room progression | Partial | Sector transitions work; scaling and variety are still limited. |
| Enemies | Partial | 3 enemy types exist; behavior tuning and balance still needed. |
| HUD and screens | Partial | HUD + Pause + Game Over + Transition exist; objective flow is still basic. |
| Emergency events | Missing | No blackout/toxic gas/door failure/system breakdown implemented yet. |
| Troubleshooting interactions | Missing | No repair-console/switch loop for unblocking progression yet. |
| Weapon switching | Partial | Two weapons exist, but user-facing switching flow is incomplete. |
| Main menu | Missing | Not implemented. |
| Reward/upgrade screen | Missing | Not implemented. |
| Room type system | Missing | No explicit Transit/Combat/Cooling/Hazard/Relay room typing in gameplay. |
| VFX/SFX polish | Missing | Visual/audio feedback is still minimal for target sci-fi tension. |
| Tests | Partial | Basic widget/enemy tests exist; integration/regression coverage is limited. |

## Next Priority

1. Finish `weapon switching` input + HUD indicator.
2. Add first `emergency event` (Blackout) with a simple resolve action.
3. Add one `troubleshooting interaction` (switch/console) that can unlock progression.

## Post-MVP Asset Track

1. Integrate `player` sprite sheet (idle/run/jump/dash) without gameplay logic changes.
2. Integrate enemy sprite sheets one-by-one (`crawler`, `hover_drone`, `sentry_turret`).
3. Add first-pass environment art (`platform`, `background`, `relay gate`) with safe fallback.
4. Add VFX polish pass and light SFX layering after sprite integration is stable.

