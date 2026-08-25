#!/usr/bin/env python3
"""Generate res://data/tree/*.json from per-branch templates.

Four branches radiating from a centre point, laid out as layered fans so a
node's parent is always the ring-inward node at a similar angle. That is
what keeps edges short and the tree readable.
"""
import json, math, os

OUT = os.path.join(os.path.dirname(__file__), "..", "data", "tree")

BRANCHES = ["burn", "shroud", "reach", "root"]
WEDGE = math.tau / 4
RING_0 = 190.0
RING_STEP = 150.0
RING_WIDTH = [1, 3, 4, 5, 5, 6, 6, 6, 6]

nodes = []
by_branch = {b: [] for b in BRANCHES}


def add(**kw):
    kw.setdefault("max_rank", 8)
    kw.setdefault("cost_growth", 1.15)
    kw.setdefault("lum", 0.0)
    kw.setdefault("requires", [])
    kw.setdefault("effects", [])
    kw.setdefault("keystone", False)
    kw.setdefault("section", "base")
    nodes.append(kw)
    by_branch.setdefault(kw["branch"], []).append(kw)
    return kw


def eff(stat, value, op="add"):
    return {"stat": stat, "op": op, "value": value}


def rule(name):
    return {"op": "rule", "rule": name}


def centre_angle(i):
    return i * WEDGE - math.pi / 2


def place(bi, ring, slot, slots, fill=0.80):
    c = centre_angle(bi)
    a = c if slots <= 1 else c + (slot / (slots - 1) - 0.5) * WEDGE * fill
    r = RING_0 + ring * RING_STEP
    return a, {"x": round(math.cos(a) * r, 1), "y": round(math.sin(a) * r, 1)}


def angle_of(n):
    return math.atan2(n["pos"]["y"], n["pos"]["x"])


# (suffix, name, desc, effects, max_rank, cost, lum, ring)
TEMPLATES = {
"burn": [
 ("entry","Ignition","+8% damage per rank.",[eff("damage_mult",0.08)],10,40,4.0,0),
 ("stoke","Stoke","+10% fire rate per rank.",[eff("fire_rate_mult",0.10)],8,90,3.5,1),
 ("edge","Edge","+3% critical chance per rank.",[eff("crit_chance",0.03)],10,110,3.0,1),
 ("fuel","Fuel","+11% damage per rank.",[eff("damage_mult",0.11)],10,240,5.0,1),
 ("bellows","Bellows","+12% fire rate per rank.",[eff("fire_rate_mult",0.12)],8,420,4.5,2),
 ("shear","Shear","Critical hits do +0.4x damage per rank.",[eff("crit_mult",0.4)],6,520,4.0,2),
 ("split","Split Shot","+1 projectile per rank. Each one is more light.",
  [eff("projectiles",1.0)],3,1400,7.0,2),
 ("furnace","Furnace","+15% damage per rank. Very loud.",[eff("damage_mult",0.15)],10,1100,6.5,3),
 ("roar","Roar","+14% fire rate per rank.",[eff("fire_rate_mult",0.14)],8,2200,6.0,3),
 ("whitehot","White Hot","+5% critical chance per rank.",[eff("crit_chance",0.05)],8,3000,5.5,4),
 ("more","More","+1% damage. No cap.",[eff("damage_mult",0.01)],-1,300,0.4,2),
 ("faster","Faster","+1% fire rate. No cap.",[eff("fire_rate_mult",0.01)],-1,600,0.4,3),
],
"shroud": [
 ("entry","Cowl","Luminance reduced 2% per rank.",[eff("shroud",0.02)],8,45,0.0,0),
 ("baffle","Baffle","Luminance reduced 3% per rank.",[eff("shroud",0.03)],10,120,0.0,1),
 ("hold","Hold Breath","Douse drains 8% slower per rank.",
  [eff("douse_efficiency",0.08)],6,150,0.0,1),
 ("recover","Recover","Douse refills 12% faster per rank.",
  [eff("douse_refill",0.12)],6,190,0.0,1),
 ("mantle","Mantle","Luminance reduced 3.5% per rank.",[eff("shroud",0.035)],10,480,0.0,2),
 ("deepen","Deepen","Douse drains 10% slower per rank.",
  [eff("douse_efficiency",0.10)],5,700,0.0,2),
 ("veil","Veil","Luminance reduced 4% per rank.",[eff("shroud",0.04)],10,1300,0.0,3),
 ("smother","Smother","Douse refills 15% faster per rank.",
  [eff("douse_refill",0.15)],6,1800,0.0,3),
 ("occlude","Occlusion","Luminance reduced 4.5% per rank.",[eff("shroud",0.045)],10,3400,0.0,4),
 ("hush","Hush","Luminance reduced 0.4%. No cap.",[eff("shroud",0.004)],-1,320,0.0,2),
 ("still","Stillness","Luminance reduced 0.4%. No cap.",[eff("shroud",0.004)],-1,1100,0.0,3),
],
"reach": [
 ("entry","Aperture","+7% turret range per rank.",[eff("range_mult",0.07)],8,45,1.0,0),
 ("focus","Focus","+9% turret range per rank.",[eff("range_mult",0.09)],8,130,1.2,1),
 ("pierce","Pierce","Projectiles pass through +1 contact per rank.",
  [eff("pierce",1.0)],3,600,1.8,1),
 ("lead","Lead","+8% range and +4% fire rate per rank.",
  [eff("range_mult",0.08),eff("fire_rate_mult",0.04)],6,340,1.5,1),
 ("track","Tracking","Aim assist cone +12% per rank. Easier to stay on target.",
  [eff("aim_assist",0.12)],6,260,1.0,1),
 ("chain","Chain","Projectiles jump to +1 nearby contact per rank.",
  [eff("chain",1.0)],3,1500,2.0,2),
 ("sweepr","Sweep","+11% turret range per rank.",[eff("range_mult",0.11)],8,760,1.6,2),
 ("splinter","Splinter","+1 projectile per rank.",[eff("projectiles",1.0)],2,2600,2.0,3),
 ("horizon","Horizon","+13% turret range per rank.",[eff("range_mult",0.13)],8,2000,1.8,3),
 ("lockon","Lock On","Aim assist cone +18% per rank.",[eff("aim_assist",0.18)],6,1400,1.6,2),
 ("further","Further","+1% range. No cap.",[eff("range_mult",0.01)],-1,280,0.1,2),
 ("keener","Keener","+1% range. No cap.",[eff("range_mult",0.01)],-1,900,0.1,3),
],
"root": [
 ("entry","Anchor","+9% mote yield per rank.",[eff("mote_mult",0.09,"mul")],8,50,2.0,0),
 ("shield","Second Skin","+1 shield per rank.",[eff("shields",1.0)],2,400,2.5,1),
 ("gather","Gather","+11% mote yield per rank.",[eff("mote_mult",0.11,"mul")],8,180,2.2,1),
 ("bank","Bank","+5% embers banked per rank.",[eff("ember_mult",0.05,"mul")],6,600,2.4,1),
 ("thick","Thicken","+1 shield per rank.",[eff("shields",1.0)],2,2200,3.0,2),
 ("harvest","Harvest","+13% mote yield per rank.",[eff("mote_mult",0.13,"mul")],8,900,2.8,2),
 ("deepbank","Deep Bank","+6% embers banked per rank.",
  [eff("ember_mult",0.06,"mul")],6,2400,2.6,3),
 ("bounty","Bounty","+16% mote yield per rank.",[eff("mote_mult",0.16,"mul")],8,3200,3.2,3),
 ("lastwall","Last Wall","+1 shield per rank.",[eff("shields",1.0)],1,9000,3.4,4),
 ("thrift","Thrift","+1% mote yield. No cap.",[eff("mote_mult",0.01,"mul")],-1,340,0.2,2),
 ("keep","Keep","+1% embers banked. No cap.",[eff("ember_mult",0.01,"mul")],-1,1200,0.2,3),
],
}

KEYSTONES = [
 ("burn_wildfire","burn","Wildfire",
  "Damage x3. Luminance grows +0.3/s continuously, forever.",
  [rule("wildfire")], 6000, 8.0),
 ("shroud_cinder","shroud","Cinder",
  "Below 20 luminance nothing spawns at all. Above it, spawn rate doubles.",
  [rule("cinder")], 6000, 0.0),
 ("reach_longshot","reach","Longshot",
  "Range x2.5 and projectiles pierce. Fire rate halved.",
  [rule("longshot")], 6000, 2.0),
 ("root_diaspora","root","Diaspora",
  "+3 shields. All mote income -40%.",
  [rule("diaspora")], 6000, 3.0),
]

# Filler to reach ~130. (stat, value, op, lum)
DEEPEN = {
 "burn":   [("damage_mult",0.06,"add",3.4),("fire_rate_mult",0.06,"add",3.0),
            ("crit_chance",0.02,"add",2.6)],
 "shroud": [("shroud",0.02,"add",0.0),("douse_efficiency",0.05,"add",0.0),
            ("douse_refill",0.08,"add",0.0)],
 "reach":  [("range_mult",0.06,"add",1.2),("fire_rate_mult",0.03,"add",1.4)],
 "root":   [("mote_mult",0.05,"mul",2.1),("ember_mult",0.05,"mul",2.3)],
}
WORDS = ["Ash","Tinder","Coal","Wick","Glim","Spark","Char","Kindle","Flint",
         "Slag","Fume","Brand","Taper","Torch","Pyre","Soot","Lumen","Nit",
         "Lux","Ember","Cinder","Scoria","Fleck","Grain","Mote","Shard"]

TARGET = {"burn": 33, "shroud": 32, "reach": 32, "root": 33}

for bi, b in enumerate(BRANCHES):
    tmpl = TEMPLATES[b]
    want = TARGET[b] - 1                     # one slot for the keystone
    slots = {}
    for t in tmpl:
        slots.setdefault(t[7], []).append(("t", t))
    k = 0
    while len(tmpl) + k < want:
        slots.setdefault(4 + k // 4, []).append(("g", k))
        k += 1

    placed = {}
    for ring in sorted(slots.keys()):
        items = slots[ring]
        n_slots = max(len(items), RING_WIDTH[min(ring, len(RING_WIDTH) - 1)])
        for slot, (kind, payload) in enumerate(items):
            a, pos = place(bi, ring, slot, n_slots)
            requires = []
            if ring > 0:
                prev = placed.get(ring - 1) or placed.get(ring - 2) or placed.get(0)
                if prev:
                    requires = [min(prev, key=lambda n: abs(angle_of(n) - a))["id"]]
            if kind == "t":
                suf, name, desc, effects, mr, cost, lum, _r = payload
                add(id=f"{b}_{suf}", branch=b, name=name, desc=desc, max_rank=mr,
                    cost=cost, cost_growth=1.08 if mr < 0 else 1.15, lum=lum,
                    requires=requires, effects=effects, pos=pos)
            else:
                gk = payload
                stat, val, op, lum = DEEPEN[b][gk % len(DEEPEN[b])]
                word = WORDS[(gk + bi * 7) % len(WORDS)]
                add(id=f"{b}_{word.lower()}_{gk}", branch=b, name=word,
                    desc=f"{stat.replace('_',' ')} +{val} per rank.",
                    max_rank=6 + (gk % 3) * 2,
                    cost=round(500 * (1.0 + gk * 0.5) * (1.75 ** (ring - 3))),
                    cost_growth=1.15, lum=round(lum * (1.0 + gk * 0.07), 2),
                    requires=requires, effects=[eff(stat, val, op)], pos=pos)
            placed.setdefault(ring, []).append(nodes[-1])

    kid, kb, kname, kdesc, keffects, kcost, klum = \
        next(k for k in KEYSTONES if k[1] == b)
    outer = max(placed.keys())
    a, pos = place(bi, outer + 1, 0, 1)
    parent = min(placed[outer], key=lambda n: abs(angle_of(n) - a))
    add(id=kid, branch=b, name=kname, desc=kdesc, max_rank=1, cost=kcost,
        cost_growth=1.0, lum=klum, requires=[parent["id"]], effects=keffects,
        pos=pos, keystone=True)

# --- emit ------------------------------------------------------------------
os.makedirs(OUT, exist_ok=True)
buckets = {}
for n in nodes:
    fname = f"{n['branch']}.json"
    buckets.setdefault(fname, []).append(n)
for fname, items in buckets.items():
    with open(os.path.join(OUT, fname), "w") as f:
        json.dump(items, f, indent=1)

ids = {n["id"] for n in nodes}
assert len(ids) == len(nodes), "duplicate ids"
missing = [r for n in nodes for r in n["requires"] if r not in ids]
assert not missing, f"missing requires: {missing[:5]}"
print(f"{len(nodes)} nodes")
for f, items in sorted(buckets.items()):
    print(f"  {f}: {len(items)}")
