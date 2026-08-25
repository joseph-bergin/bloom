# BLOOM

An incremental game where the number going up is rendered as a light you
cannot switch off. Godot 4, GDScript, statically typed.

Built from `BLOOM-spec-godot.md`, phases 0–12.

## Running

```bash
godot --path . # or open project.godot in the Godot editor
```

Keys: **Space** sweep · **T** tree · **F** lance the selection · **Esc** settings /
close tree · click a contact to select · mouse wheel zooms.

### Headless tools

```bash
# balance harness — writes CSV of currencies, luminance, contacts, pressure
godot --headless --script res://tools/sim_runner.gd -- --minutes=60
godot --headless --script res://tools/sim_runner.gd -- --minutes=40 --build=greedy
godot --headless --script res://tools/sim_runner.gd -- --backlight=2000

# test suite (201 assertions)
godot --headless --script res://tests/test_runner.gd

# tree statistics, validation, bulk retune
godot --headless --script res://tools/tree_generator.gd -- --report
godot --headless --script res://tools/tree_generator.gd -- --validate

# regenerate the tree JSON from templates
python3 tools/gen_tree.py
```

## Acceptance criteria

| Phase | Criterion | Result |
|---|---|---|
| 0 | Circle at HDR brightness visibly blooms | pass |
| 1 | 60fps with 200 contacts | pass — 87fps avg on an M2 |
| 2 | 60-minute sim under 5s, writes CSV | pass — 2.3s |
| 3 | No file under `scenes/` or `ui/` references `true_position` | pass — asserted in the suite |
| 4 | Buy everything, hide nothing → dies within 20 min | pass — dies at 1:01 |
| 4 | Buy only Shroud → survives indefinitely, earns almost nothing | pass — 40 min, 0 motes |
| 5 | Purchase visibly increases bloom glow within one frame | pass |
| 5 | Validator passes on all JSON | pass |
| 6 | Displayed witness probability matches observed rate | pass — worst error 1.2% over 2000 rolls/tier |
| 8 | 10,000 random blight configurations, zero soft-locks | pass |
| 9 | Never spendable currency with nothing affordable | pass — next purchase never exceeds 1.33× wealth |
| 10 | Round-trip save/load/migrate across three schema versions | pass |
| 12 | `SteamBridge` no-ops cleanly without Steam | pass |

## Deviations from the spec, and why

**Godot 4.3, not 4.4+.** 4.3 is what is installed. Everything load-bearing —
Forward+, `hdr_2d`, 2D glow, `draw_multiline_colors` — is present. The project
is tagged `4.3` in `config/features`, which opens unchanged in 4.4.

**A ninth keystone.** The spec's keystone table gives Shroud two (Nullwake,
Cinder) and Sweep none, which its own validator rule forbids ("every
constellation has ≥1 keystone"). All eight specified keystones are implemented
exactly; **Lighthouse** was added for Sweep in the same idiom — no cooldown and
whole-field coverage, at quadruple transient luminance and everything it
touches notices you.

**A luminance baseline of 2.5.** Nothing in the spec stops effective luminance
reaching exactly zero, and at zero no contact can ever accrue awareness, so
building nothing is permanently safe. Shroud reduces this baseline like any
other structural light but cannot remove it, which is what `SHROUD_CAP`'s
"never allow full invisibility" implies. It lives in `constants.gd` as a
tunable.

**Audio is synthesised, not sampled.** Every cue is a PCM buffer built at
startup in `audio/synth.gd`. No binary assets, and cues stay tunable as
numbers. The bus layout (`Master → SFX/Ambient/UI/Music`, compressor on
Master) is built at runtime in `AudioDirector` rather than shipped as
`bus_layout.tres`.

**Tests are self-hosted, not gdUnit4.** gdUnit4 is an addon and is not
installed here. `tests/suite.gd` is written in the same shape (`test_*`
methods, assert helpers) and runs with `godot --headless --script
res://tests/test_runner.gd`. Porting to gdUnit4 is a mechanical rename.

**Tree generation is `tools/gen_tree.py`.** First-pass generation runs once;
`tools/tree_generator.gd` is the in-engine tool for what actually happens
repeatedly — statistics, validation, and bulk cost/luminance retunes across
290 nodes.

**Contact rendering is batched.** The spec says not to reach for
`MultiMeshInstance2D` pre-emptively. Profiling at 200 contacts showed
`ContactLayer` alone costing more than half the frame, and the cost was draw
calls. Marker bodies now accumulate into one `canvas_item_add_triangle_array`
call — no MultiMesh, 30fps → 87fps.

## Open balance findings

These come out of the harness, which exists precisely to surface them
(§12: "these are starting values, not answers").

- **A do-nothing player is not in serious danger at 30 minutes** (§15's
  turtling check). The awareness threshold scales as `1.9^tier`, so cascade
  makes contacts progressively *less* able to see a faint bloom, and tiers 0–1
  — the only ones that can see one — flee rather than strike. This is in
  direct tension with Phase 4's criterion that a pure-Shroud build survives
  indefinitely, which is implemented as specified. Inverting the tier term
  fixes §15 and breaks Phase 4; the acceptance criterion won.
- **Shroud is over-supplied.** A full build offers 346% raw reduction against
  an 88% cap, so Shroud saturates at roughly a quarter of the constellation.
  §15 wants Shroud to scale on the same curve as Expansion. Surfaced by
  `tree_generator.gd --report`.
- **The `greedy` harness build dies at 1:01**, not 20 minutes, because the
  harness force-purchases every node at t=0 with base redundancy. The
  direction is right; the number is degenerate.

## Layout

```
autoload/   Constants, EventBus, GameState, TreeDB, Stats, SaveManager,
            AudioDirector, SteamBridge
sim/        data/ systems/ tree/ prestige/ — all RefCounted, no Nodes,
            never reads the scene tree
scenes/     Main, SimRoot, FieldView and its draw layers
ui/         HUD, panels, tree view, modals
data/tree/  290 nodes across 8 constellations + 3 ember regions
tools/      sim_runner, tree_generator, gen_tree.py, dev/Shot
tests/      201 assertions
```
