extends Node
## Signal hub. Declarations only.
## The sim emits; UI, audio and feel subscribe. The sim holds no UI refs.

signal contact_killed(tier: int, at: Vector2, motes: float)
signal contact_spawned(c: Contact)
signal shield_breached(remaining: int)
signal run_ended(reason: String)
signal run_started()

signal node_purchased(id: StringName, rank: int)
signal respec_performed()
signal stats_recomputed()

signal ember_banked(gained: float, cycle: int)
signal section_unlocked(section: StringName)
signal game_loaded()
