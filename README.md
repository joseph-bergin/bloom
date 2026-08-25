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

**Hold Space to hide.** Light drops to 10%, spawning slows fivefold, and you
earn nothing while you hold it. The meter is your breath: run it to empty
and it is spent until it has refilled most of the way back, so you cannot
mash the key at zero.

**T** opens the tree — **between levels only.** Upgrades are a phase, not
something you do mid-fight. **Esc** settings.

## Sight

**What your light reaches, you can fight. What it does not, you cannot.**

Two radii matter and they come from different places. *Sight* is bought with
light — brightness is literally how far you can see. *Range* is bought with
Reach. The turret needs both: it will not lock, and its shots will not
touch, anything outside your light. Contacts out there draw as hollow
brackets — you know something is coming, not what.

That makes brightness a two-sided trade rather than a straight cost. Bright
means more enemies and the ability to fight them; dark means fewer enemies
you cannot see coming. Range past your sight is wasted, so the HUD shows
both numbers and warns when sight is the binding one.

It also gives Shroud a job. **Dark Adaptation** buys sight that costs no
light to have — the branch's answer to the one thing going dark takes from
you. Before this, Shroud bought safety and nothing else, and the runner
showed a pure-Burn build performing *worse than buying nothing at all*.
With sight in play Burn moved from level 5.0 to 7.0, and burn + shroud from
6.0 to 8.0.

A boss is always visible however dark it is. Losing track of the thing the
level is about would read as a bug rather than as darkness.

## Levels

A run is a ladder of levels. Each level is a kill quota, then a **boss**.
The quota is set from how fast the field is currently spawning, so a level
is always about the same stretch of time however bright you are — being
brighter means more to kill, not a shorter level. If you dawdle, the boss
arrives on schedule anyway.

The boss is a wall. Nothing else spawns while it lives, it has its own
health bar, and killing it clears the level and pays a bonus. If it reaches
you it costs a shield and **comes straight back** — the level does not
advance. That is deliberate: when a breaching boss advanced the level, a
build with no damage at all could walk the whole ladder by paying shields,
and damage bought nothing.

**Clearing a level hands control back to you.** The field empties, the
banner lands, and the tree opens so you can spend what the level paid.
Nothing resumes until you press *Begin level N*. That is the rhythm the
game runs on: fight, clear, spend, go again.

Three shields gone ends the run. The level you reached is the score.

## Look

**The typeface is a 5x7 bitmap font**, authored glyph by glyph in
`tools/gen_font.py` and emitted as a BMFont page Godot loads directly. No
external asset, the same as the audio. The cell is 5x8 rather than 5x7 —
that eighth row is below the baseline, and without it there is nowhere for
a descender to go, so `g` reads as `a` and `p` as `P`. Sizes are integer
multiples of the cell, canvas filtering is nearest, and the font's
`fixed_size_scale_mode` is set to `INTEGER_ONLY` — without that last one a
fixed-size bitmap font renders at its native 7px at every requested size,
which looks like the font never loaded at all.

One frame shape, used everywhere: a chamfered panel with corner ticks and
an accent rule down the left edge, drawn by `ui/ChamferBox.gd`. Every panel,
button, meter and modal comes from `ui/ui_theme.gd`. Colour always means the
same thing — amber is motes and light, green is progress, red is threat,
blue is Douse.

**The HUD says as little as it can.** Shields are pips you count, not
"shields 3 / 3". Douse is a bare bar; the words appear once, the first time
you lose a shield, and never again. The one line of prose that earns its
place is what your light is doing to the field, because that is the whole
design.

**Impacts answer back.** A landed shot throws sparks along the shot line
and flashes the contact white; a kill throws shards and an expanding ring
in the contact's tier colour, with a tick on hit and a brighter one on a
crit; the boss arrives on a low two-note horn and a cleared level answers
with a rising one. Going dark drops a cold veil over the field, pulls the boundary
inward, throws a ripple outward and ducks the whole mix — Douse used to be
a number changing in a panel.

The field sits in a drifting three-layer starfield with a polar grid that
echoes the radial shape of the game, a machined turret-reach ring, and a
vignette. A few stars are drawn above 1.0 so the glow rig catches them.

**The tree** is hexagonal cells, each carrying a glyph drawn from what the
node actually does — a spike for damage, chevrons for fire rate, an eclipse
for shroud, widening arcs for range, a reticle for aim assist. The icons are
derived from the node's effects rather than assigned by hand, so a node's
picture and its effect cannot drift apart. Rank is an arc around the rim,
owned nodes are drawn above 1.0 so they glow, and unreached branches sit as
dark silhouettes one step past the frontier.

## No prestige

There is no meta-currency and no cross-run carry. A run is the whole game:
climb as far as you can, and the tree unbuilds when you start again. The
only thing that persists is your best level.

This is a deliberate simplification from an earlier version that had an
"ember" prestige layer. It removes the multi-hour arc the spec described —
the game is now a single escalating run scored by depth, closer to an
arcade high-score loop than a long incremental.

## Acceptance criteria

| Phase | Criterion | Result |
|---|---|---|
| 0 | A circle at HDR brightness visibly blooms | pass |
| 1 | 60fps with 300 contacts; loop playable with zero tree | pass — 112fps on an M2 |
| 2 | Luminance drives spawn rate, tier and drift; Douse works | pass |
| 3 | Purchasing a node grows the bloom within one frame; validator passes | pass |
| 4 | Retiring early beats dying at every point on the curve | pass — asserted across six orders of magnitude |
| 5 | ~130 nodes + ~20 ember; never motes in hand with nothing to buy | pass — 130 + 24, next purchase never exceeds 2× wealth |
| — | Levels end visibly, with a boss | pass — boss bar, clear banner, level readout |
| 6 | Feel, audio, Steam no-op without Steam | pass |

And the two checks from §10 "things that will kill this":

- **Luminance must read as the difficulty.** The HUD line under the readout
  says `^ spawn x1.6  max tier 0  speed 26` and updates live. It turns red
  past 4× and inverts to a green "nothing is spawning" while Dousing.
- **Shroud must not be a trap or an autobuy.** Currently it leans trap. See
  the open item below.

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

## Open balance item

The tree has to be worth its luminance. It now is, but only for a build that
commits. Over a single run (four seeds averaged, score is level reached):

| build | level | motes | dps |
|---|---|---|---|
| burn + reach | 8.3 | 12.3K | 73 |
| mixed (all four) | 8.0 | 12.8K | 34 |
| burn + shroud | 8.0 | 9.8K | 23 |
| reach | 8.0 | 9.8K | 8 |
| burn | 7.0 | 11.7K | 129 |
| shroud | 7.0 | 5.6K | 8 |
| **buy nothing** | **7.0** | **5.6K** | **8** |
| root | 6.0 | 10.1K | 8 |

Committed builds clearly beat idling, and the curve is smooth rather than
the cliff it used to be — the boss now keeps the damage you did to it
across attempts, so a wall you cannot clear outright can be ground down at
a shield apiece. Before that the run was bistable: break through and
compound forever, or stall at level 6 with nothing in between.

Sight fixed the two branches that were not paying rent. Burn went from
*worse than buying nothing* to par, because the light it generates now buys
sight as well as danger, and Shroud pairs into a real build for the first
time. What is left is that a **pure** Shroud build still only ties with
idling — which is arguably correct, since it has no damage at all — and
Root has slipped to the bottom.

So the shape is right — commitment beats dabbling beats idling — but the
floor is too high and two of the four branches are not carrying their
weight. Reproduce with:

```bash
godot --headless --script res://tools/sim_runner.gd -- --minutes=45 --runs=4
```

## Balance, and how it got there

The spec's starting values did not survive the runner, which is what §6 says
to expect. Three changed:

- **`HP_TIER_MULT` 1.6 → 2.2.** At 1.6 the turret was never overwhelmed —
  1365 kills, zero breaches, every build surviving indefinitely. Contact
  health has to outrun damage growth or brightness costs you nothing. At 2.2
  a pure-Burn run dies at 20 minutes and a mixed run at 30, which is the
  spec's 15–30 minute window.
- **`MOTE_TIER_MULT` 1.9 → 2.6.** The single most important number here.
  Health scaled at 2.2 per tier while motes scaled at 1.9, which meant a
  higher-tier contact paid *less per point of health* than a low one — so
  being brighter was strictly a mistake and the entire tree was a trap.
  Rewards now outrun costs per tier, which is what makes growth worth its
  exposure. There is a test asserting the inequality holds.
- **`EMBER_DIVISOR` 1000 → 80** (since removed with prestige). At 1000 the campaign flatlined: 2 embers per
  run forever, 4 of 24 ember nodes after four hours, luminance pinned at 82
  every cycle. Ember upgrades are the only thing that raises the ceiling
  between runs, so if they never accumulate nothing escalates. At 80 the
  ratchet engages — motes climb 5.4K → 27K, luminance 73 → 114, ember income
  10 → 36 per run.
- **The field and the boss got faster.** Levels were ending with the player
  waiting for the boss to amble into range. It now starts at 80% of the
  field radius and moves at 0.62 of contact speed rather than 0.30, which
  cut time-in-range about threefold and meant boss health had to come down
  with it.
- **Levels rebalanced the whole economy.** Pausing spawns for boss fights
  and breathers cut kill throughput about fourfold, so income moved onto the
  level-clear bonus. That bonus is tied to what the level's boss is worth
  rather than to the level number — an exponential in the level number ran
  away to 10^19 the moment the player could clear levels quickly.
- **Infinite sinks had to become additive.** Three of them multiplied, and
  an uncapped multiplicative node is an exponential with no ceiling: a
  thousand ranks of "+1% mote yield" compounded to 21,000x. Sinks exist so
  there is always something cheap to click, not to become the build.
- **`PRESTIGE_DENSITY`, new, 0.04.** §1 says each prestige starts you in a
  darker, denser field and nothing implemented it. Spawn rate now rises 4%
  per cycle. It wants to stay small: at 0.10 the field outran the player's
  ember gains and runs shrank from 25 minutes to six.

A `--set=KEY=VALUE` flag on the runner sweeps any of these, which is why the
values in `constants.gd` are `var` rather than `const`.

## Bugs the criteria caught

**Retiring could tie with dying.** `floor(embers × 1.25)` collapses to the
same integer at small payouts — at 500 motes both paid 2. Phase 4 requires
retiring to win at *every* point, so the retire payout is now floored at one
more than the death payout.

**The shopping model in the runner bought the cheapest node**, which meant it
poured everything into infinite sinks and luminance never moved. That was a
bad model, not a bad game, but it hid the real pacing problem for several
runs. It now buys the deepest affordable node and falls back to sinks only
when nothing else is affordable — which is what the spec says sinks are for.

**A compile error in the runner looked exactly like a hang.** `load()`
returned a failed script, the `.new()` call errored, and the SceneTree just
kept running instead of quitting — so the harness sat there forever and I
spent a while optimising a sim that was never executing. The runner now
checks the load and exits with the parse errors.

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
data/tree/  130 nodes across 4 branches
tools/      sim_runner, gen_tree.py, dev/Shot
tests/      212 assertions
```

The previous, much larger version of this game is on the `main` branch.
