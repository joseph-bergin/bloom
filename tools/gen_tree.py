#!/usr/bin/env python3
"""Bulk tree generation from per-constellation templates.

Emits res://data/tree/*.json. Costs are template-driven then hand-tuned via
the TUNE table at the bottom. Gateway blight_safe is derived from the edge
set after generation, which is what keeps the validator's soft-lock rule
true by construction rather than by vigilance.
"""
import json, math, os, random

random.seed(0xB1002)
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "tree")

# constellation -> (angle index, identity blurb, lum range)
CONS = [
    ("expansion",  0, (3.0, 8.0)),
    ("shroud",     1, (0.0, 0.0)),
    ("optics",     2, (0.5, 1.0)),
    ("sweep",      3, (1.0, 2.0)),
    ("lance",      4, (2.0, 4.0)),
    ("tether",     5, (1.0, 2.0)),
    ("redundancy", 6, (2.0, 3.0)),
    ("cognition",  7, (1.0, 2.0)),
]

nodes = []          # list of dicts
by_con = {c: [] for c, _, _ in CONS}


def add(**kw):
    kw.setdefault("kind", "rank")
    kw.setdefault("max_rank", 6)
    kw.setdefault("cost_growth", 1.15)
    kw.setdefault("lum", 0.0)
    kw.setdefault("requires", [])
    kw.setdefault("effects", [])
    kw.setdefault("blight_safe", False)
    kw.setdefault("reveal_radius", 180)
    kw.setdefault("region", "base")
    nodes.append(kw)
    by_con.setdefault(kw["constellation"], []).append(kw)
    return kw["id"]


WEDGE = math.tau / 8
RING_0 = 250.0
RING_STEP = 175.0


def polar(angle, radius):
    return {"x": round(math.cos(angle) * radius, 1),
            "y": round(math.sin(angle) * radius, 1)}


def wedge_centre(con_idx):
    return con_idx * WEDGE - math.pi / 2


def layout(con_idx, ring, slot, slots, fill=0.74):
    """Place a node on its ring, spread evenly across the constellation wedge.

    Rings fan outward and slots spread across the wedge, so a node's parent is
    always the ring-inward node at a similar angle. That is what keeps edges
    short and non-crossing — the tree has to be readable to be the content.
    """
    centre = wedge_centre(con_idx)
    span = WEDGE * fill
    if slots <= 1:
        a = centre
    else:
        a = centre + (slot / (slots - 1) - 0.5) * span
    return a, RING_0 + ring * RING_STEP


def angle_of(node, con_idx):
    return math.atan2(node["pos"]["y"], node["pos"]["x"])


def eff(stat, value, op="add"):
    return {"stat": stat, "op": op, "value": value}


def rule(name):
    return {"op": "rule", "rule": name}


# ---------------------------------------------------------------------------
# Per-constellation templates: (suffix, name, desc, effects, max_rank,
#                               motes, signal, facets, lum, ring, kind)
# ---------------------------------------------------------------------------

TEMPLATES = {
"expansion": [
 ("entry","Ignition","The colony learns to burn hotter. Mote yield +8% per rank.",
  [eff("yield_mult",0.08,"mul")],5,18,0,0,3.0,0,"rank"),
 ("bloomfeed","Bloomfeed","Mote yield +6% per rank.",[eff("yield_mult",0.06,"mul")],8,60,0,0,3.5,1,"rank"),
 ("spread","Spread","Mote yield +9% per rank. Loud.",[eff("yield_mult",0.09,"mul")],8,140,0,0,5.0,1,"rank"),
 ("rootmass","Rootmass","Tribute rate +7% per rank.",[eff("tribute_mult",0.07,"mul")],6,180,0,0,4.0,1,"rank"),
 ("harvest","Harvest","Mote yield +11% per rank.",[eff("yield_mult",0.11,"mul")],8,420,0,0,6.0,2,"rank"),
 ("efflorescence","Efflorescence","Mote yield +14% per rank. Very loud.",
  [eff("yield_mult",0.14,"mul")],8,1100,0,0,8.0,3,"rank"),
 ("gleaning","Gleaning","Signal from every read +10% per rank.",[eff("signal_mult",0.10,"mul")],6,90,0,0,2.0,1,"rank"),
 ("facetwork","Facetwork","Facet yield +12% per rank.",[eff("facet_mult",0.12,"mul")],5,0,0,2,4.0,2,"rank"),
 ("thermal","Thermal Bleed","Mote yield +18% per rank. Structural luminance climbs with it.",
  [eff("yield_mult",0.18,"mul")],6,2600,0,0,11.0,4,"rank"),
 ("greed","Greed","Mote yield +1%. No cap. Cheap forever.",
  [eff("yield_mult",0.01,"mul")],-1,240,0,0,0.4,2,"sink"),
 ("appetite","Appetite","Mote yield +1%. No cap.",[eff("yield_mult",0.01,"mul")],-1,900,0,0,0.4,3,"sink"),
],
"shroud": [
 ("entry","Cowl","Structural luminance reduced by 2% per rank.",[eff("shroud",0.02)],6,22,0,0,0.0,0,"rank"),
 ("baffle","Baffle","Structural luminance reduced by 3% per rank.",[eff("shroud",0.03)],8,120,0,0,0.0,1,"rank"),
 ("dampen","Dampening Field","Transient light fades faster: tau -0.8s per rank.",
  [eff("transient_decay",0.8)],6,150,0,0,0.0,1,"rank"),
 ("mantle","Mantle","Structural luminance reduced by 3.5% per rank.",[eff("shroud",0.035)],8,480,0,0,0.0,2,"rank"),
 ("smother","Smother","Transient light fades faster: tau -0.6s per rank.",
  [eff("transient_decay",0.6)],6,520,0,0,0.0,2,"rank"),
 ("occlude","Occlusion","Structural luminance reduced by 4% per rank.",[eff("shroud",0.04)],8,1400,0,0,0.0,3,"rank"),
 ("quiet","Quiet Growth","Everything you build costs 4% less luminance per rank.",
  [eff("lum_mult",-0.04,"mul")],6,900,0,0,0.0,2,"rank"),
 ("veil","Veil","Structural luminance reduced by 4.5% per rank.",[eff("shroud",0.045)],8,3800,0,0,0.0,4,"rank"),
 ("hush","Hush","Structural luminance reduced by 0.4%. No cap.",[eff("shroud",0.004)],-1,300,0,0,0.0,2,"sink"),
 ("stillness","Stillness","Structural luminance reduced by 0.4%. No cap.",[eff("shroud",0.004)],-1,1200,0,0,0.0,3,"sink"),
],
"optics": [
 ("entry","Aperture","Passive sensing reaches 40u further per rank.",
  [eff("passive_range",40.0)],6,20,0,0,0.5,0,"rank"),
 ("resolution","Resolution","Optics grade +1 per rank. Grade 4 gives range data; grade 6 sees strikes coming.",
  [eff("optics_grade",1.0)],8,110,40,0,0.8,1,"rank"),
 ("collimate","Collimation","Bearing noise cut: precision +0.35 per rank.",
  [eff("bearing_precision",0.35)],6,130,30,0,0.6,1,"rank"),
 ("dwell","Dwell","Passive reads arrive 0.5s sooner per rank.",[eff("passive_speed",0.5)],6,190,50,0,0.7,1,"rank"),
 ("baseline","Long Baseline","Passive sensing reaches 70u further per rank.",
  [eff("passive_range",70.0)],8,420,0,0,0.9,2,"rank"),
 ("track","Track Fusion","Tracking +0.30 per rank. Slows staleness and shrinks uncertainty.",
  [eff("tracking",0.30)],8,560,120,0,1.0,2,"rank"),
 ("classify","Classification","Contact tier readings become exact.",
  [eff("tier_id",1.0)],1,0,0,3,1.0,3,"rank"),
 ("deep","Deep Listen","Passive sensing range +12% per rank.",
  [eff("passive_range_mult",0.12,"mul")],6,1500,0,0,1.2,3,"rank"),
 ("interfere","Interferometry","Tracking +0.5 per rank.",[eff("tracking",0.5)],6,3200,400,0,1.4,4,"rank"),
 ("squint","Squint","Bearing precision +0.03. No cap.",[eff("bearing_precision",0.03)],-1,180,20,0,0.1,2,"sink"),
 ("attend","Attend","Tracking +0.02. No cap.",[eff("tracking",0.02)],-1,600,60,0,0.1,3,"sink"),
],
"sweep": [
 ("entry","Pulse","Sweep radius +8% per rank.",[eff("sweep_radius",0.08)],6,24,20,0,1.0,0,"rank"),
 ("carrier","Carrier","Sweep ring travels 10% faster per rank.",
  [eff("sweep_speed_mult",0.10,"mul")],6,120,40,0,1.0,1,"rank"),
 ("recover","Recovery","Sweep cooldown -0.7s per rank.",[eff("sweep_cooldown",0.7)],6,160,60,0,1.2,1,"rank"),
 ("reach","Reach","Sweep radius +11% per rank.",[eff("sweep_radius",0.11)],8,380,0,0,1.4,2,"rank"),
 ("cascade_ping","Cascade Ping","Sweep radius +9% per rank and cooldown -0.3s per rank.",
  [eff("sweep_radius",0.09),eff("sweep_cooldown",0.3)],6,900,200,0,1.6,2,"rank"),
 ("multi","Multisweep","Sweep radius +15% per rank.",[eff("sweep_radius",0.15)],6,2400,0,0,2.0,3,"rank"),
 ("masking","Masking","The sweep's transient flare is 5% quieter per rank.",
  [eff("lum_mult",-0.02,"mul")],5,1600,300,0,0.0,3,"rank"),
 ("ripple","Ripple","Sweep radius +1%. No cap.",[eff("sweep_radius",0.01)],-1,260,30,0,0.1,2,"sink"),
],
"lance": [
 ("entry","Spike","Lance flight speed +9% per rank.",
  [eff("lance_speed_mult",0.09,"mul")],6,26,0,0,2.0,0,"rank"),
 ("guidance","Guidance","Tracking +0.25 per rank. Stale data hurts your aim less.",
  [eff("tracking",0.25)],8,140,0,0,2.2,1,"rank"),
 ("floor","Hard Floor","Minimum hit chance +4% per rank.",[eff("min_hit_chance",0.04)],6,220,0,0,2.4,1,"rank"),
 ("velocity","Velocity","Lance flight speed +12% per rank.",
  [eff("lance_speed_mult",0.12,"mul")],8,500,0,0,2.8,2,"rank"),
 ("salvo","Salvo","+1 lance per launch, per rank. Each one is its own flash.",
  [eff("salvo",1.0)],3,1800,0,0,4.0,2,"rank"),
 ("chain","Chain Detonation","Chance a snuff catches a neighbour: +8% per rank.",
  [eff("chain_chance",0.08)],6,2200,0,2,3.6,3,"rank"),
 ("muffle","Muffled Warhead","Backlight from your detonations -6% per rank.",
  [eff("backlight_mult",-0.06,"mul")],6,2600,0,0,2.0,3,"rank"),
 ("penetrator","Penetrator","Minimum hit chance +6% per rank.",[eff("min_hit_chance",0.06)],6,4200,0,0,3.4,4,"rank"),
 ("hone","Hone","Tracking +0.02. No cap.",[eff("tracking",0.02)],-1,320,0,0,0.2,2,"sink"),
 ("sharpen","Sharpen","Lance speed +1%. No cap.",[eff("lance_speed_mult",0.01,"mul")],-1,700,0,0,0.2,3,"sink"),
],
"tether": [
 ("entry","First Debt","Sensor capacity +1 per rank.",[eff("tether_capacity",1.0)],3,150,80,0,1.0,0,"rank"),
 ("stability","Standing","Tether stability +0.25 per rank. Slack accrues slower.",
  [eff("tether_stability",0.25)],8,240,100,0,1.2,1,"rank"),
 ("tribute","Tribute","Tribute yield +9% per rank.",[eff("tribute_mult",0.09,"mul")],8,300,0,0,1.4,1,"rank"),
 ("terms","Terms","Reassert costs 8% less signal per rank.",
  [eff("reassert_cost_mult",-0.08,"mul")],6,420,150,0,1.0,1,"rank"),
 ("capacity","Wide Net","Sensor capacity +1 per rank.",[eff("tether_capacity",1.0)],4,1400,400,0,1.8,2,"rank"),
 ("credibility","Credibility","Tether stability +0.4 per rank.",[eff("tether_stability",0.4)],6,1900,500,0,1.6,3,"rank"),
 ("levy","Levy","Tribute yield +13% per rank.",[eff("tribute_mult",0.13,"mul")],8,3400,0,0,2.0,3,"rank"),
 ("collateral","Collateral","Facet yield +10% per rank.",[eff("facet_mult",0.10,"mul")],5,0,0,3,1.4,4,"rank"),
 ("lean","Lean On","Tribute +1%. No cap.",[eff("tribute_mult",0.01,"mul")],-1,380,60,0,0.1,2,"sink"),
],
"redundancy": [
 ("entry","Second Body","Maximum redundancy +1 per rank.",[eff("max_redundancy",1.0)],3,320,0,0,2.0,0,"rank"),
 ("dispersal","Dispersal","Chance an incoming strike is absorbed: +7% per rank.",
  [eff("strike_mitigation",0.07)],6,480,0,0,2.4,1,"rank"),
 ("hardening","Hardening","Blight takes 8% fewer nodes per rank.",[eff("blight_resist",0.08)],6,600,0,0,2.2,1,"rank"),
 ("thirdbody","Third Body","Maximum redundancy +1 per rank.",[eff("max_redundancy",1.0)],3,2200,0,0,3.0,2,"rank"),
 ("scatter","Scatter","Chance an incoming strike is absorbed: +5% per rank.",
  [eff("strike_mitigation",0.05)],6,2800,0,0,2.6,3,"rank"),
 ("immune","Immune Response","Blight takes 10% fewer nodes per rank.",
  [eff("blight_resist",0.10)],5,3600,0,2,2.8,3,"rank"),
 ("deepbody","Deep Body","Maximum redundancy +1 per rank.",[eff("max_redundancy",1.0)],2,9000,0,4,3.6,4,"rank"),
 ("brace","Brace","Strike mitigation +0.5%. No cap.",[eff("strike_mitigation",0.005)],-1,900,0,0,0.2,2,"sink"),
],
"cognition": [
 ("entry","Attention","Node costs -3% per rank.",[eff("cost_mult",-0.03,"mul")],6,200,0,0,1.0,0,"rank"),
 ("autosweep","Reflex Sweep","Sweeps fire on cooldown without you.",
  [rule("auto_sweep")],1,1200,300,0,1.4,1,"rank"),
 ("autolance","Reflex Lance","Lances launch on your triage policy without you.",
  [rule("auto_lance")],1,2600,0,1,1.8,2,"rank"),
 ("triage","Triage","+1 triage rule slot per rank.",[eff("triage_slots",1.0)],4,1800,400,0,1.2,2,"rank"),
 ("autotether","Reflex Tether","Tethers are established on your triage policy without you.",
  [rule("auto_tether")],1,4200,900,0,1.6,3,"rank"),
 ("banked","Banked Light","Dormancy efficiency +6% per rank.",
  [eff("dormancy_efficiency",0.06)],6,900,0,0,1.0,1,"rank"),
 ("deepbank","Deep Bank","Dormancy efficiency +5% per rank.",
  [eff("dormancy_efficiency",0.05)],5,3000,0,0,1.2,3,"rank"),
 ("economy","Economy","Node costs -4% per rank.",[eff("cost_mult",-0.04,"mul")],6,2400,0,0,1.4,3,"rank"),
 ("thrift","Thrift","Node costs -0.5%. No cap.",[eff("cost_mult",-0.005,"mul")],-1,700,0,0,0.1,2,"sink"),
],
}

# --- Keystones, hand-authored exactly as specified -------------------------
KEYSTONES = [
 ("shroud_nullwake","shroud","Nullwake",
  "Structural luminance -60%. You can never use active sweep again.",
  [eff("lum_mult",-0.6,"mul"), rule("nullwake")], 0, 0, 6, 0.0, 5),
 ("optics_long_ear","optics","Long Ear",
  "Passive range x3, full range data, exact tier. Active sweep reveals nothing new.",
  [rule("long_ear")], 0, 0, 6, 1.0, 5),
 ("lance_overburn","lance","Overburn",
  "Lances always hit regardless of staleness. Every lance triples backlight.",
  [rule("overburn")], 0, 0, 7, 3.0, 5),
 ("expansion_wildfire","expansion","Wildfire",
  "Mote income x4. Structural luminance grows +0.4/s continuously, forever.",
  [rule("wildfire")], 0, 0, 8, 6.0, 5),
 ("tether_hostage","tether","Hostage Doctrine",
  "Tribute x2. If any tether fires, all tethers fire simultaneously.",
  [rule("hostage_doctrine")], 0, 0, 7, 2.0, 5),
 ("redundancy_diaspora","redundancy","Diaspora",
  "+3 maximum redundancy. All income -40%.",
  [rule("diaspora")], 0, 0, 8, 3.0, 5),
 ("cognition_autarch","cognition","Autarch",
  "Full automation of sweep, lance and tether. You can no longer manually target anything.",
  [rule("autarch")], 0, 0, 10, 2.0, 5),
 # The spec's keystone table leaves Sweep without one, which its own
 # validator rule forbids. Lighthouse fills the gap in the same idiom:
 # a rule change with a drawback that reframes the constellation.
 ("sweep_lighthouse","sweep","Lighthouse",
  "Sweep has no cooldown and covers the whole field. Every sweep costs quadruple transient luminance, and everything it touches notices.",
  [rule("lighthouse")], 0, 0, 8, 2.0, 5),
 ("shroud_cinder","shroud","Cinder",
  "While luminance is under 20 you are undetectable. Above 20, awareness accrues at triple rate.",
  [rule("cinder")], 0, 0, 9, 0.0, 5),
]

# --- Build base constellations --------------------------------------------
# Two phases: assign every node a ring and slot, then wire each to the
# nearest node one ring inward. Parenting by proximity is what stops the
# graph from turning into a hairball.
con_index = {c: i for c, i, _ in CONS}
entry_ids = {}
rings_of = {}          # constellation -> {ring: [node dict]}

target = {"expansion": 30, "shroud": 30, "optics": 32, "sweep": 28,
          "lance": 32, "tether": 30, "redundancy": 28, "cognition": 30}

DEEPEN = {
    "expansion": [("yield_mult", 0.05, "mul", 3.2), ("tribute_mult", 0.05, "mul", 2.4)],
    "shroud":    [("shroud", 0.02, "add", 0.0), ("transient_decay", 0.3, "add", 0.0)],
    "optics":    [("passive_range", 30.0, "add", 0.6), ("tracking", 0.15, "add", 0.7)],
    "sweep":     [("sweep_radius", 0.05, "add", 1.1), ("sweep_cooldown", 0.25, "add", 1.3)],
    "lance":     [("lance_speed_mult", 0.06, "mul", 2.1), ("min_hit_chance", 0.02, "add", 2.4)],
    "tether":    [("tribute_mult", 0.05, "mul", 1.2), ("tether_stability", 0.15, "add", 1.1)],
    "redundancy": [("strike_mitigation", 0.03, "add", 2.1), ("blight_resist", 0.04, "add", 2.0)],
    "cognition": [("cost_mult", -0.02, "mul", 1.0), ("dormancy_efficiency", 0.03, "add", 1.1)],
}
WORDS = ["Filament", "Ash", "Tinder", "Ember", "Coal", "Wick", "Glim", "Spark",
         "Cinderlet", "Char", "Kindle", "Flint", "Scoria", "Slag", "Fume",
         "Brand", "Taper", "Torch", "Pyre", "Soot", "Lumen", "Candela", "Nit",
         "Phot", "Lux", "Stilb", "Talbot", "Rayl"]

# Slots per ring, outward. Wider rings further out gives the fan its shape.
RING_WIDTH = [1, 4, 5, 6, 6, 7, 7, 7]

for con, idx, _lum in CONS:
    tmpl = TEMPLATES[con]
    keystones_here = 2 if con in ("shroud", "sweep") else 1
    want = target[con] - keystones_here

    # --- phase 1: ring/slot assignment ---
    slots = {}          # ring -> list of (kind_payload)
    for t in tmpl:
        slots.setdefault(t[9], []).append(("tmpl", t))

    k = 0
    total = len(tmpl)
    while total < want:
        ring = 3 + k // 4
        slots.setdefault(ring, []).append(("gen", k))
        total += 1
        k += 1

    # --- phase 2: place and wire ---
    placed = {}
    for ring in sorted(slots.keys()):
        items = slots[ring]
        n_slots = max(len(items), RING_WIDTH[min(ring, len(RING_WIDTH) - 1)])
        for slot, (kind, payload) in enumerate(items):
            a, r = layout(idx, ring, slot, n_slots)
            p = polar(a, r)
            requires = []
            if ring > 0:
                prev = placed.get(ring - 1) or placed.get(ring - 2) or placed.get(0)
                if prev:
                    parent = min(prev, key=lambda n: abs(angle_of(n, idx) - a))
                    requires = [parent["id"]]

            if kind == "tmpl":
                suffix, name, desc, effects, mr, motes, sig, fac, lum, _r, nkind = payload
                cost = {}
                if motes:
                    cost["motes"] = motes
                if sig:
                    cost["signal"] = sig
                if fac:
                    cost["facets"] = fac
                growth = 1.08 if nkind == "sink" else 1.15
                add(id=f"{con}_{suffix}", constellation=con, name=name, desc=desc,
                    kind=nkind, max_rank=mr, cost=cost, cost_growth=growth, lum=lum,
                    requires=requires, effects=effects, pos=p, reveal_radius=200)
                node = nodes[-1]
            else:
                gk = payload
                stat, val, op, lum = DEEPEN[con][gk % len(DEEPEN[con])]
                word = WORDS[(gk + idx * 5) % len(WORDS)]
                mult = 1.0 + gk * 0.55
                add(id=f"{con}_{word.lower()}_{gk}", constellation=con, name=word,
                    desc=f"{stat.replace('_', ' ')} {'+' if val > 0 else ''}{val} per rank.",
                    kind="rank", max_rank=6 + (gk % 3) * 2,
                    cost={"motes": round(300 * mult * (1.9 ** (ring - 2)))},
                    cost_growth=1.15, lum=round(lum * (1.0 + gk * 0.08), 2),
                    requires=requires, effects=[eff(stat, val, op)],
                    pos=p, reveal_radius=200)
                node = nodes[-1]
            placed.setdefault(ring, []).append(node)

    entry_ids[con] = f"{con}_entry"
    rings_of[con] = placed

# --- Keystones -------------------------------------------------------------
key_slot = {}
for kid, con, name, desc, effects, motes, sig, fac, lum, _ring in KEYSTONES:
    idx = con_index[con]
    outer = max(rings_of[con].keys())
    n_here = sum(1 for k in KEYSTONES if k[1] == con)
    slot = key_slot.get(con, 0)
    key_slot[con] = slot + 1
    a, _r = layout(idx, outer + 1, slot, max(n_here, 2), fill=0.5)
    r = RING_0 + (outer + 1) * RING_STEP
    candidates = rings_of[con][outer]
    parent = min(candidates, key=lambda n: abs(angle_of(n, idx) - a))
    add(id=kid, constellation=con, name=name, desc=desc, kind="keystone",
        max_rank=1, cost={"facets": fac}, cost_growth=1.0, lum=lum,
        requires=[parent["id"]], effects=effects,
        pos=polar(a, r), reveal_radius=320)

# --- Bridges: expensive facet links between distant constellations ---------
BRIDGES = [
 ("bridge_shroud_expansion","shroud","expansion","Cold Bloom",
  "Growth without the glare: mote yield +25% and structural luminance -10%.",
  [eff("yield_mult",0.25,"mul"), eff("lum_mult",-0.10,"mul")], 5),
 ("bridge_optics_lance","optics","lance","Firing Solution",
  "Tracking +1.2 and minimum hit chance +10%.",
  [eff("tracking",1.2), eff("min_hit_chance",0.10)], 5),
 ("bridge_sweep_tether","sweep","tether","Standing Watch",
  "Sensor capacity +2 and tether stability +0.8.",
  [eff("tether_capacity",2.0), eff("tether_stability",0.8)], 6),
 ("bridge_redundancy_shroud","redundancy","shroud","Deep Cover",
  "Strike mitigation +15% and structural luminance -8%.",
  [eff("strike_mitigation",0.15), eff("lum_mult",-0.08,"mul")], 6),
 ("bridge_cognition_optics","cognition","optics","Wide Attention",
  "Optics grade +2 and +1 triage rule slot.",
  [eff("optics_grade",2.0), eff("triage_slots",1.0)], 7),
 ("bridge_lance_expansion","lance","expansion","Reaping",
  "Mote yield +30%. Backlight +20%.",
  [eff("yield_mult",0.30,"mul"), eff("backlight_mult",0.20,"mul")], 7),
]
for bid, a, b, name, desc, effects, fac in BRIDGES:
    ia, ib = con_index[a], con_index[b]
    outer_a = rings_of[a][max(rings_of[a].keys())]
    outer_b = rings_of[b][max(rings_of[b].keys())]
    # Pick the ends that face each other so the bridge is the short way round.
    mid_dir = (wedge_centre(ia) + wedge_centre(ib)) / 2
    pa = min(outer_a, key=lambda n: abs(angle_of(n, ia) - mid_dir))
    pb = min(outer_b, key=lambda n: abs(angle_of(n, ib) - mid_dir))
    mx = (pa["pos"]["x"] + pb["pos"]["x"]) / 2
    my = (pa["pos"]["y"] + pb["pos"]["y"]) / 2
    add(id=bid, constellation=a, name=name, desc=desc, kind="bridge",
        max_rank=1, cost={"facets": fac}, cost_growth=1.0, lum=1.0,
        requires=[pa["id"], pb["id"]], effects=effects,
        pos={"x": round(mx, 1), "y": round(my, 1)}, reveal_radius=400)

# --- Ember-only regions ----------------------------------------------------
REGIONS = [
 ("choir", 8, "The Choir", [
   ("voice","Voice","Tribute yield +20% per rank.",[eff("tribute_mult",0.20,"mul")],6,4000,0,0,1.4),
   ("chord","Chord","Sensor capacity +1 per rank.",[eff("tether_capacity",1.0)],3,9000,0,0,2.0),
   ("descant","Descant","Tether stability +0.6 per rank.",[eff("tether_stability",0.6)],6,6000,0,0,1.6),
   ("antiphon","Antiphon","Signal income +18% per rank.",[eff("signal_mult",0.18,"mul")],6,5200,0,0,1.2),
   ("plainsong","Plainsong","Structural luminance -5% per rank.",[eff("lum_mult",-0.05,"mul")],6,7000,0,0,0.0),
   ("unison","Unison","Tribute +2%. No cap.",[eff("tribute_mult",0.02,"mul")],-1,3000,0,0,0.2),
   ("refrain","Refrain","Reassert costs 12% less signal per rank.",[eff("reassert_cost_mult",-0.12,"mul")],6,6400,0,0,1.0),
   ("cantor","Cantor","Facet yield +15% per rank.",[eff("facet_mult",0.15,"mul")],5,8200,0,0,1.2),
   ("motet","Motet","Tribute yield +14% per rank.",[eff("tribute_mult",0.14,"mul")],8,10500,0,0,1.8),
   ("drone","Drone","Tether stability +0.35 per rank.",[eff("tether_stability",0.35)],8,7600,0,0,1.4),
   ("hymn","Hymn","Signal income +12% per rank.",[eff("signal_mult",0.12,"mul")],6,9100,0,0,1.0),
   ("psalm","Psalm","Sensor capacity +1 per rank.",[eff("tether_capacity",1.0)],2,18000,0,0,2.4),
   ("echo","Echo","Signal income +2%. No cap.",[eff("signal_mult",0.02,"mul")],-1,4400,0,0,0.2),
 ], ("choir_keystone","Massed Voice",
     "Every tether reinforces the others: stability +0.5 per live tether.",
     [eff("tether_stability",0.5), rule("massed_voice")], 9)),
 ("lattice", 9, "The Lattice", [
   ("strut","Strut","Maximum redundancy +1 per rank.",[eff("max_redundancy",1.0)],3,12000,0,0,2.6),
   ("truss","Truss","Strike mitigation +8% per rank.",[eff("strike_mitigation",0.08)],6,8000,0,0,2.2),
   ("weave","Weave","Blight resistance +12% per rank.",[eff("blight_resist",0.12)],5,9500,0,0,2.0),
   ("node","Node","Node costs -5% per rank.",[eff("cost_mult",-0.05,"mul")],6,11000,0,0,1.4),
   ("span","Span","Tracking +0.6 per rank.",[eff("tracking",0.6)],6,7500,0,0,1.6),
   ("joint","Joint","Blight resistance +1%. No cap.",[eff("blight_resist",0.01)],-1,5000,0,0,0.2),
   ("gusset","Gusset","Strike mitigation +6% per rank.",[eff("strike_mitigation",0.06)],6,13500,0,0,2.0),
   ("cantilever","Cantilever","Maximum redundancy +1 per rank.",[eff("max_redundancy",1.0)],2,26000,0,0,3.0),
   ("tension","Tension","Tracking +0.4 per rank.",[eff("tracking",0.4)],8,10200,0,0,1.4),
   ("shear","Shear","Minimum hit chance +5% per rank.",[eff("min_hit_chance",0.05)],6,14800,0,0,2.2),
   ("keying","Keying","Node costs -4% per rank.",[eff("cost_mult",-0.04,"mul")],6,16000,0,0,1.2),
   ("pier","Pier","Blight resistance +10% per rank.",[eff("blight_resist",0.10)],4,19000,0,0,2.0),
   ("rivet","Rivet","Strike mitigation +0.6%. No cap.",[eff("strike_mitigation",0.006)],-1,6800,0,0,0.2),
 ], ("lattice_keystone","Load Bearing",
     "Blight can never take more than two nodes at once.",
     [eff("blight_resist",0.4), rule("load_bearing")], 10)),
 ("the_cold", 10, "The Cold", [
   ("draw","Draw Down","Structural luminance -7% per rank.",[eff("lum_mult",-0.07,"mul")],6,20000,0,0,0.0),
   ("still","Stillness","Awareness accrues 10% slower per rank.",[eff("shroud",0.02)],6,26000,0,0,0.0),
   ("empty","Emptying","Mote yield +25% per rank. The field is thinner now.",
    [eff("yield_mult",0.25,"mul")],6,32000,0,0,2.0),
   ("silence","Silence","Transient light fades faster: tau -1.0s per rank.",
    [eff("transient_decay",1.0)],4,24000,0,0,0.0),
   ("last","Last Light","Dormancy efficiency +8% per rank.",[eff("dormancy_efficiency",0.08)],4,28000,0,0,0.8),
   ("thin","Thinning","Structural luminance -1%. No cap.",[eff("lum_mult",-0.01,"mul")],-1,15000,0,0,0.0),
   ("hoarfrost","Hoarfrost","Structural luminance -6% per rank.",[eff("lum_mult",-0.06,"mul")],6,34000,0,0,0.0),
   ("rime","Rime","Transient light fades faster: tau -0.8s per rank.",[eff("transient_decay",0.8)],4,30000,0,0,0.0),
   ("dim","Dimming","Mote yield +20% per rank.",[eff("yield_mult",0.20,"mul")],6,38000,0,0,1.6),
   ("hollow","Hollowing","Structural luminance reduced by 5% per rank.",[eff("shroud",0.05)],6,42000,0,0,0.0),
   ("quench","Quench","Backlight from your detonations -10% per rank.",[eff("backlight_mult",-0.10,"mul")],5,36000,0,0,0.0),
   ("null","Null","Node costs -6% per rank.",[eff("cost_mult",-0.06,"mul")],5,44000,0,0,0.8),
   ("fade","Fade","Structural luminance -1%. No cap.",[eff("lum_mult",-0.01,"mul")],-1,22000,0,0,0.0),
 ], ("the_cold_keystone","Ambient Zero",
     "The region cannot sustain high tiers. Nothing can find you. Nothing can find anything.",
     [eff("shroud",0.2), rule("ambient_zero")], 12)),
]

for rid, ridx, rname, items, key in REGIONS:
    base_angle = ridx * math.tau / 11 - math.pi / 2
    entry_id = f"{rid}_entry"
    # The region hangs off a base keystone so it is reachable in the graph.
    anchor = {"choir": "tether_hostage", "lattice": "redundancy_diaspora",
              "the_cold": "shroud_cinder"}[rid]
    add(id=entry_id, constellation=rid, name=f"{rname} — Entry",
        desc=f"A region that only catches once an ember has carried you here.",
        kind="rank", max_rank=1, cost={"motes": 2500}, cost_growth=1.0, lum=0.5,
        requires=[anchor], effects=[],
        pos={"x": round(math.cos(base_angle) * 2250, 1),
             "y": round(math.sin(base_angle) * 2250, 1)},
        region=rid, reveal_radius=400)
    for j, (suf, name, desc, effects, mr, motes, sig, fac, lum) in enumerate(items):
        a = base_angle + (j / max(len(items) - 1, 1) - 0.5) * 0.55
        r = 2450 + (j % 3) * 160
        add(id=f"{rid}_{suf}", constellation=rid, name=name, desc=desc,
            kind="sink" if mr < 0 else "rank", max_rank=mr,
            cost={"motes": motes}, cost_growth=1.12 if mr > 0 else 1.06,
            lum=lum, requires=[entry_id], effects=effects,
            pos={"x": round(math.cos(a) * r, 1), "y": round(math.sin(a) * r, 1)},
            region=rid, reveal_radius=300)
    kid, kname, kdesc, keffects, kfac = key
    add(id=kid, constellation=rid, name=kname, desc=kdesc, kind="keystone",
        max_rank=1, cost={"facets": kfac}, cost_growth=1.0, lum=1.0,
        requires=[entry_id], effects=keffects,
        pos={"x": round(math.cos(base_angle) * 2900, 1),
             "y": round(math.sin(base_angle) * 2900, 1)},
        region=rid, reveal_radius=420)

# --- Derive blight_safe from the edge set ----------------------------------
# A gateway is any node something else requires. Blighting one would lock its
# whole downstream subtree, so the generator marks them safe by construction.
required = set()
for n in nodes:
    for r in n["requires"]:
        required.add(r)
for n in nodes:
    n["blight_safe"] = n["id"] in required

# --- Emit ------------------------------------------------------------------
FILES = {c: f"{c}.json" for c, _, _ in CONS}
buckets = {}
for n in nodes:
    if n["region"] != "base":
        buckets.setdefault("ember_regions.json", []).append(n)
    else:
        buckets.setdefault(FILES[n["constellation"]], []).append(n)

os.makedirs(OUT, exist_ok=True)
for fname, items in buckets.items():
    with open(os.path.join(OUT, fname), "w") as f:
        json.dump(items, f, indent=1)

ids = [n["id"] for n in nodes]
assert len(ids) == len(set(ids)), "duplicate ids"
missing = [r for n in nodes for r in n["requires"] if r not in set(ids)]
assert not missing, f"missing requires: {missing[:5]}"
print(f"{len(nodes)} nodes")
for f, items in sorted(buckets.items()):
    print(f"  {f}: {len(items)}")
counts = {}
for n in nodes:
    counts[n["constellation"]] = counts.get(n["constellation"], 0) + 1
print("  per constellation:", counts)
print("  gateways (blight_safe):", sum(1 for n in nodes if n["blight_safe"]))
print("  blightable leaves:", sum(1 for n in nodes if not n["blight_safe"]))
