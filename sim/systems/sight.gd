class_name Sight
extends RefCounted
## What your light reaches, you can fight. What it does not, you cannot.
##
## This is the mechanic the whole design was pitched on. Before it, light
## was a spawn-table modifier read once when a contact appeared and never
## again; now it is a volume in the field that decides what the turret is
## allowed to touch.
##
## Two radii matter and they come from different places:
##   sight  — how far your light reaches, bought with luminance
##   range  — how far the turret shoots, bought with Reach
## You need both. Range past your sight is wasted, and sight past your range
## only tells you what is coming.

static func radius(s: GameStateData) -> float:
	return Constants.VISION_BASE + sqrt(maxf(s.effective_luminance(), 0.0)) \
		* Constants.VISION_LUM_SCALE + Stats.vision_add

## The distance at which the turret can actually engage: the nearer of the
## two. Displayed in the HUD so the player can see which one is binding.
static func engagement(s: GameStateData) -> float:
	return minf(radius(s), Stats.turret_range)

static func can_see(s: GameStateData, c: Contact) -> bool:
	# A boss announces itself. Losing track of the thing the level is about
	# would read as a bug rather than as darkness.
	if c.is_boss:
		return true
	return c.pos.length() <= radius(s)

static func engageable(s: GameStateData, c: Contact) -> bool:
	if not can_see(s, c):
		return false
	return c.pos.length() <= Stats.turret_range
