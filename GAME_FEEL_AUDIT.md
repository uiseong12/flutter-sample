# Game-like Feel Audit (2026-02-14)

## Quick external findings (search summary)
- **Game Feel core**: input → response → context → polish loop is critical (Wikipedia summary of Steve Swink's game-feel framing).
- **Flutter animation guidance**: polished apps rely on implicit + explicit animation mix (Flutter animations docs).
- **Microinteractions** like fade/scale/slide reduce jarring transitions and improve perceived quality (Flutter opacity animation cookbook).
- **If heavier game systems needed**: Flame exists as a Flutter game engine with loop/effects/particles/collision.

## Current project strengths
- Story map + route history exists.
- VN scene has background/character/dialog structure.
- Character show/hide + tap pulse + page fade already present.
- Systems loop (work/shop/date/story) is implemented.

## Gaps vs “looks like a real game”
1. **No timeline/cutscene camera language**
   - Need cinematic pans, zooms, focus blur, foreground overlays.
2. **Dialogue pacing is static**
   - Need typewriter text, skip/auto modes, character nameplate animation, voice blips.
3. **Low feedback layering**
   - Need SFX + haptics-like visual cues + particle bursts on key events.
4. **Weak state transitions**
   - Need scene transition presets (fade-to-black, crossfade, flash, shake).
5. **Insufficient character performance**
   - Need expression variants (neutral/smile/angry/sad/blush) + pose swaps.
6. **HUD/game loop readability**
   - Need persistent quest/objective panel + relationship trend arrows.
7. **No emotional lighting progression**
   - Need LUT-like color overlays by mood/route.

## High-impact improvement backlog (priority)
### P0 (must)
- Typewriter dialogue + click to advance + skip/auto buttons.
- Character expression swap per line.
- Scene transition manager (fade/slide/flash presets).
- SFX hooks for select/tap/reward/ending.

### P1
- Camera tween (slow zoom/pan in VN scenes).
- Particle accents (sparkles for romance gains, shards for conflict choices).
- Animated relationship bars with up/down delta popup.

### P2
- Voice pack integration (short synthetic character voice blips).
- Dynamic music states (calm/tension/romance) with crossfade.
- Route codex UI (tree view with locked/unlocked branches).

## Story package used for image generation
- Theme: medieval romance-politics fantasy.
- Core cast:
  - Heroine: noblewoman with strategic agency.
  - Elian: disciplined knight captain, protective romance line.
  - Lucian: mage scholar, forbidden-knowledge romance line.
  - Serena: aristocratic diplomat, power/affection hybrid route.
- Ending rule: first character to 100 affection locks ending.

## Generated art outputs (OpenAI Images API)
- `assets/generated/heroine/...png`
- `assets/generated/elian/...png`
- `assets/generated/lucian/...png`
- `assets/generated/serena/...png`
- `assets/generated/bg_castle/...png`
- `assets/generated/bg_ballroom/...png`
- `assets/generated/bg_tower/...png`

Each folder also includes:
- `prompts.json`
- `index.html`

## Recommended next implementation step
1. Integrate generated PNGs into runtime scene assets.
2. Add expression state model per character.
3. Implement typewriter + auto-play dialogue controller.
4. Add transition manager and SFX event bus.
