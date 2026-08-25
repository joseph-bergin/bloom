# BLOOM

A small incremental game. One screen, one loop, one big skill tree.
Every upgrade you buy makes you brighter, and brightness is the thing that
spawns the enemies.

Godot 4, GDScript, statically typed. Built from `BLOOM-spec-simple.md`.

## Running

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

**Aim with the mouse.** The turret fires on its own whenever anything is
inside its range, but it fires where you point — so choosing what to kill
next is the active decision. An assist cone steers shots onto whatever you
are pointing near, and Reach nodes widen it. Point at empty dark and you
miss. The HUD says `ON TARGET` when the trigger has something.

**Hold Space to hide.** Luminance drops to 10%, spawning nearly stops, and
you earn nothing while you hold it. It is the panic button and the greed
dial at once.

**T** opens the tree, **Esc** settings.

### Headless tools

```bash
# build comparison — mixed must beat every extreme
godot --headless --script res://tools/sim_runner.gd -- --minutes=45 --runs=4

# a full campaign: successive runs, banking embers between them
godot --headless --script res://tools/sim_runner.gd -- --cycles=12 --retire=25 --build=mixed

# sweep any tuning value without editing the file
godot --headless --script res://tools/sim_runner.gd -- --set=HP_TIER_MULT=2.6

# 182 assertions
godot --headless --script res://tests/test_runner.gd

# regenerate the tree from templates
python3 tools/gen_tree.py
```

## Acceptance criteria

| Phase | Criterion | Result |
|---|---|---|
| 0 | A circle at HDR brightness visibly blooms | pass |
| 1 | 60fps with 300 contacts; loop playable with zero tree | pass — 112fps on an M2 |
| 2 | Luminance drives spawn rate, tier and drift; Douse works | pass |
| 3 | Purchasing a node grows the bloom within one frame; validator passes | pass |
| 4 | Retiring early beats dying at every point on the curve | pass — asserted across six orders of magnitude |
| 5 | ~130 nodes + ~20 ember; never motes in hand with nothing to buy | pass — 130 + 24, next purchase never exceeds 2× wealth |
| 6 | Feel, audio, Steam no-op without Steam | pass |

And the two checks from §10 "things that will kill this":

- **Luminance must read as the difficulty.** The HUD line under the readout
  says `^ spawn x1.6  max tier 0  speed 26` and updates live. It turns red
  past 4× and inverts to a green "nothing is spawning" while Dousing.
- **Shroud must not be a trap or an autobuy.** Verified in the runner: a
  mixed build banks 10 embers against 6 for pure-Burn, 6 for Reach, 9 for
  Root and 5 for pure-Shroud. Mixed beats every extreme.

## Aiming, and the field scale

The first build auto-targeted the nearest contact and drew the field at 57%
scale. Both were wrong: the player had nothing to do, and everything was too
small to read.

The turret now fires along the aim vector. It still pulls the trigger itself
and every upgrade still applies — the player supplies target selection, which
is the decision that was missing. `GameStateData.aim` is set by the input
layer and only read by the sim, so the simulation still never touches the
scene tree, and the headless runner falls back to nearest-target so balance
comparisons stay valid.

The field shrank from 640 units to 440 with every other length scaled by the
same factor, which leaves the simulation identical in relative terms while
drawing everything roughly 1.5x larger. Contact radii deliberately did not
scale down — that is the actual zoom.

## Balance, and how it got there

The spec's starting values did not survive the runner, which is what §6 says
to expect. Three changed:

- **`HP_TIER_MULT` 1.6 → 2.2.** At 1.6 the turret was never overwhelmed —
  1365 kills, zero breaches, every build surviving indefinitely. Contact
  health has to outrun damage growth or brightness costs you nothing. At 2.2
  a pure-Burn run dies at 20 minutes and a mixed run at 30, which is the
  spec's 15–30 minute window.
- **`EMBER_DIVISOR` 1000 → 80.** At 1000 the campaign flatlined: 2 embers per
  run forever, 4 of 24 ember nodes after four hours, luminance pinned at 82
  every cycle. Ember upgrades are the only thing that raises the ceiling
  between runs, so if they never accumulate nothing escalates. At 80 the
  ratchet engages — motes climb 5.4K → 27K, luminance 73 → 114, ember income
  10 → 36 per run.
- **`PRESTIGE_DENSITY`, new, 0.04.** §1 says each prestige starts you in a
  darker, denser field and nothing implemented it. Spawn rate now rises 4%
  per cycle. It wants to stay small: at 0.10 the field outran the player's
  ember gains and runs shrank from 25 minutes to six.

A `--set=KEY=VALUE` flag on the runner sweeps any of these, which is why the
values in `constants.gd` are `var` rather than `const`.

## Two bugs the criteria caught

**Retiring could tie with dying.** `floor(embers × 1.25)` collapses to the
same integer at small payouts — at 500 motes both paid 2. Phase 4 requires
retiring to win at *every* point, so the retire payout is now floored at one
more than the death payout.

**The shopping model in the runner bought the cheapest node**, which meant it
poured everything into infinite sinks and luminance never moved. That was a
bad model, not a bad game, but it hid the real pacing problem for several
runs. It now buys the deepest affordable node and falls back to sinks only
when nothing else is affordable — which is what the spec says sinks are for.

## Deviations

**Godot 4.3, not 4.4+.** That is what is installed. Everything load-bearing —
Forward+, `hdr_2d`, 2D glow — is present, and the project is tagged `4.3` in
`config/features`, which opens unchanged in 4.4.

**Audio is synthesised, not sampled.** Every cue is a PCM buffer built at
startup in `audio/synth.gd`: kill pops pitched by streak, the purchase chunk,
the breach and its one second of true silence, the Douse hum. No binary
assets, and cues stay tunable as numbers. §7 asks for a real sound pass
before ship; this is a working stand-in, not that pass.

**Tests are self-hosted.** `tests/suite.gd` runs with plain Godot, no addon.

**Two extra autoloads** beyond the five in §5: `event_bus.gd` so the sim can
stay ignorant of the UI, and `audio.gd` for §7's feedback.

## Layout

```
autoload/   constants, event_bus, tree_db, stats, game_state, save_manager,
            audio, steam_bridge
sim/        contact, projectile, game_state_data, tree_node
            systems/ luminance, spawning, turret, field
scenes/     Main, FieldView and its draw layers
ui/         HUD, TreeView, modals
data/tree/  130 base nodes across 4 branches + 24 ember nodes
tools/      sim_runner, gen_tree.py, dev/Shot
tests/      182 assertions
```

The previous, much larger version of this game is on the `main` branch.
