class_name Cold
extends RefCounted
## Endgame. You stop hiding your light and start lowering the ambient energy
## of the entire region. It works. Nothing can find you. Nothing can find anything.

static func unlocked(data: GameStateData) -> bool:
	return Ember.cold_unlocked(data)

static func rank(data: GameStateData) -> int:
	return data.cold_rank

static func max_rank() -> int:
	return Constants.TIER_MAX

static func at_maximum(data: GameStateData) -> bool:
	return data.cold_rank >= max_rank()

## The correct ending is not victory. It is choosing the empty configuration.
static func ending_reached(data: GameStateData) -> bool:
	return at_maximum(data) and data.contacts.is_empty()

static func income_scalar(data: GameStateData) -> float:
	return pow(1.0 - Constants.COLD_INCOME_PENALTY, float(data.cold_rank))
