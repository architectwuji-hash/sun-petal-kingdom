extends CharacterBody3D

signal inventory_changed(item: String, new_count: int)
signal health_changed(current: int, maximum: int)
signal player_died
## Emitted when the player makes noise enemies can hear.
## origin = world position of the sound, volume 0.0–1.0 scales hearing radius.
signal made_noise(origin: Vector3, volume: float)
signal dark_tier_changed(tier: int)
signal divine_tier_changed(tier: int)
## Wall scenes used by build mode.
const WOOD_WALL_SCENE  := preload("res://scenes/objects/WoodWall3D.tscn")
const STONE_WALL_SCENE := preload("res://scenes/objects/StoneWall3D.tscn")
enum BuildItem { WOOD_WALL, STONE_WALL }

# ── tunables ──────────────────────────────────────────────────────────────────
const MOVE_SPEED:   float = 3.5
const SPRINT_SPEED: float = 6.5
const JUMP_FORCE:   float = 9.0
const GRAVITY:      float = 20.0
const INTERACT_RANGE: float = 5.0
# ──────────────────────────────────────────────────────────────────────────────

var max_health: int  = 100
var health: int      = 100
var _is_dead: bool   = false
var _input_blocked: bool = false  # set by Kipatah or any UI panel
var _jump_pending: bool = false
var _cam_shake: float   = 0.0
var _camera_pivot: Node3D = null
var _spring_arm: SpringArm3D = null
var _camera: Camera3D = null
var _cam_pitch: float = -0.35
var _attack_cooldown: float = 0.0
var _attack_hitbox: Area3D = null
var _char_model: Node3D = null
var _anim: AnimationPlayer = null
var _attack_anim_time: float = 0.0
var _dev_inspect_mode: bool = false
var _sprint_noise_timer: float = 0.0
# ── charge blast state ────────────────────────────────────────────────────────
var _is_charging: bool = false
var _charge_power: float = 0.0
var _charge_vfx_layers: Array[Node3D] = []  # 4 instances, one per power tier
var _charge_level_label: Label3D = null       # floating "LV.X" above player
const _SPRINT_NOISE_INTERVAL := 1.2   ## seconds between sprint pings
# Remap Quaternius UAL bone names → Mixamo bone names (after stripping "mixamorig:" prefix).
# We strip that prefix at runtime because Godot's NodePath uses ":" as a separator, so a
# bone named "mixamorig:Hips" inside a track path "Skeleton3D:mixamorig:Hips" is parsed as
# two subnames ("mixamorig" + "Hips") and the lookup silently fails.  Stripped names like
# "Hips" contain no colon and resolve correctly.  Mesh skinning uses bone *indices* not
# names, so renaming at runtime does not break the mesh.
const BONE_REMAP_Q_TO_MIXAMO: Dictionary = {
	"pelvis": "Hips", "spine_01": "Spine",
	"spine_02": "Spine1", "spine_03": "Spine2",
	"clavicle_l": "LeftShoulder", "upperarm_l": "LeftArm",
	"lowerarm_l": "LeftForeArm", "hand_l": "LeftHand",
	"clavicle_r": "RightShoulder", "upperarm_r": "RightArm",
	"lowerarm_r": "RightForeArm", "hand_r": "RightHand",
	"thigh_l": "LeftUpLeg", "calf_l": "LeftLeg",
	"foot_l": "LeftFoot", "ball_l": "LeftToeBase",
	"thigh_r": "RightUpLeg", "calf_r": "RightLeg",
	"foot_r": "RightFoot", "ball_r": "RightToeBase",
	"neck_01": "Neck", "head": "Head",
}
const SWORD_SCENE := preload("res://assets/models/weapons/quaternius_sword_golden.gltf")
const SWORD_GLOW_SHADER := preload("res://assets/shaders/enchanted_fresnel.gdshader")
# Bronze/plain versions of this same pack's swords didn't read as "mythical" -
# Sword_Golden is the closest same-artist, same-style option to something
# legendary, so it gets dressed up further at runtime with an emissive glow
# and a soft pulsing light rather than swapping in a mismatched asset pack.
const SWORD_ANIM_LIBRARY_SCENE := preload("res://assets/animations/quaternius/UAL1_Standard.glb")
const SWORD_ANIM_LIBRARY_SCENE_2 := preload("res://assets/animations/quaternius/UAL2_Standard.glb")
# Mixamo locomotion animations for Gomushi — proper rig match, no retargeting
# distortion. Gomushi was auto-rigged by Mixamo so its skeleton bones match exactly.
# To add Walk/Sprint: go to Mixamo → upload this same Idle.fbx → pick the animation
# → download WITHOUT SKIN → save as Walk.fbx / Sprint.fbx in this same folder.
const MIXAMO_DIR := "res://assets/animations/mixamo/"
# clip name in our AnimationPlayer -> Mixamo FBX file. Loaded with load(), so a
# missing file is just skipped instead of stopping the game from starting.
# To add Walk/Sprint later: drop Walk.fbx / Sprint.fbx in the folder and add
# "Walk": "Walk.fbx", "Sprint": "Sprint.fbx" here.
const MIXAMO_CLIPS := {
	"Idle": "Idle.fbx",
	"Walk": "Walk.fbx",
	"Sprint": "Sprint.fbx",
	"RunBackward": "RunBackward.fbx",
	"Mx_ThrustSlash": "ThrustSlash.fbx",
	"Mx_HeavySwing": "HeavyWeaponSwing.fbx",
	"Mx_MeleeCombo": "MeleeComboAttack.fbx",
	"Mx_JumpAttack": "GreatSwordJumpAttack.fbx",
	"Mx_RunJumpAttack": "RunJumpAttack.fbx",
	"Mx_Punch": "Punching.fbx",
	"Mx_Punch2": "Punching2.fbx",
	"Mx_SideKick": "SideKick.fbx",
	"Mx_SpellCast": "SpellCasting.fbx",
	"Mx_CastingSpell": "CastingSpell.fbx",
	"Mx_ChokeLift": "ChokeLift.fbx",
	"Mx_KnockedOut": "KnockedOut.fbx",
}
# Playback speed per clip - Mixamo clips are long, so they're sped up to feel snappy.
const CLIP_SPEED := {
	"Mx_ThrustSlash": 2.0, "Mx_HeavySwing": 2.6, "Mx_MeleeCombo": 2.0,
	"Mx_JumpAttack": 1.4, "Mx_RunJumpAttack": 2.0,
	"Mx_Punch": 1.3, "Mx_Punch2": 1.3, "Mx_SideKick": 1.6,
	"Mx_SpellCast": 2.0, "Mx_ChokeLift": 1.5, "Mx_KnockedOut": 1.8,
}
const UNARMED_COMBO: Array[String] = ["Mx_Punch", "Mx_Punch2", "Mx_SideKick"]
# Universal Animation Library 2's actual 3-hit sword combo (same rig, same
# retargeting trick as the first library) - A -> B -> C, each of the first
# two followed by its own recovery clip if the player doesn't chain into the
# next hit in time. Sword_Regular_C has no _Rec clip - it flows back to idle.
const SWORD_COMBO_ANIMS: Array[String] = ["Mx_ThrustSlash", "Mx_HeavySwing", "Mx_MeleeCombo"]
const SWORD_COMBO_RECOVERIES: Array[String] = ["", "", ""]
const AXE_SCENE := preload("res://assets/models/weapons/quaternius_axe.glb")
const AXE_SWING_ANIM := "Sword_Attack"
const AXE_SWING_SPEED: float = 1.3
const AXE_DAMAGE: int = 25
const AXE_COOLDOWN: float = 1.1
const PLAYER_BLAST_SCENE: PackedScene = preload("res://scenes/player/PlayerBlast.tscn")
const MAX_CHARGE_POWER: float = 5000.0
const CHARGE_RATE: float      = 800.0   # fills 5000 in ~6.25 s
# Fraction of the swing clip where the axe head actually connects - damage
# is dealt at that moment instead of the instant the button is pressed.
const AXE_HIT_FRACTION: float = 0.45
const SWORD_DAMAGE: int = 15
const COMBO_WINDOW: float = 1.0
var _combo_index: int = 0
var _combo_reset_timer: float = 0.0
var _pending_recovery: String = ""
var _pending_recovery_swing: int = -1
var _swing_token: int = 0
const SLASH_VFX_SCENE := preload("res://assets/vfx/fiery_slash/slash.tscn")
# The pack's own slash.res was saved by Godot 4.4 (unreadable in 4.2), so the
# same arc mesh is taken from the pack's original Slash_model.glb instead.
const SLASH_MESH_SCENE := preload("res://assets/vfx/fiery_slash/Slash_model.glb")
var _slash_mesh: Mesh = null
var _sword: Node3D = null
var _skeleton: Skeleton3D = null
var _sword_equipped: bool = false
var _axe: Node3D = null
var _axe_equipped: bool = false
var _current_weapon: String = "sword"  # "sword" | "axe" | "hands"

# Quaternius "Modular Character Outfits - Fantasy" - Ranger set, chosen for
# the forest scenes. Ships as separate skinned-mesh parts that share the
# Universal Base Character rig's exact bone names (verified: 65/65 joints
# match, same names like "pelvis", "clavicle_l", etc.), so each part's mesh
# can be lifted out of its own tiny imported scene and re-parented onto our
# OWN Skeleton3D, same trick already used for the animation library.
const OUTFIT_BODY_SCENE       := preload("res://assets/models/characters/quaternius/outfits/Male_Ranger_Body.gltf")
const OUTFIT_ARMS_SCENE       := preload("res://assets/models/characters/quaternius/outfits/Male_Ranger_Arms.gltf")
const OUTFIT_LEGS_SCENE       := preload("res://assets/models/characters/quaternius/outfits/Male_Ranger_Legs.gltf")
const OUTFIT_FEET_SCENE       := preload("res://assets/models/characters/quaternius/outfits/Male_Ranger_Feet_Boots.gltf")
const OUTFIT_HOOD_SCENE       := preload("res://assets/models/characters/quaternius/outfits/Male_Ranger_Head_Hood.gltf")
const OUTFIT_PAULDRON_SCENE   := preload("res://assets/models/characters/quaternius/outfits/Male_Ranger_Acc_Pauldron.gltf")

var inventory: Dictionary = {
	"meat":       0,
	"cowhide":    0,
	"souls":      0,
	"monkey_fur": 0,
	"wood":       0,
	"stone":      0,
	"mushroom":   0,
}

# ── Soul System ────────────────────────────────────────────────────────────
var souls_sold_total: int       = 0   ## cumulative souls sold to demons
var souls_sacrificed_total: int = 0   ## cumulative souls sacrificed to Auros
var dark_tier: int              = 0   ## 0-5 (Tainted→Hellbound)
var divine_tier: int            = 0   ## 0-5 (Acknowledged→Divine)
var divine_bonus: int           = 0   ## permanent attack bonus from Auros

const DARK_THRESHOLDS:   Array[int] = [100, 1000, 10000, 25000, 50000, 100000]
const DIVINE_THRESHOLDS: Array[int] = [100, 1000, 10000, 25000, 50000, 100000]
const DIVINE_BONUSES:    Array[int] = [10, 20, 35, 50, 65, 100]  ## % attack multipliers
var dark_protection_percent: int = 0  ## % reduction on evil-type attacks (max 40 at divine tier 4)

# ── build mode ──────────────────────────────────────────────────────────────
const WALL_WOOD_COST    := 3          ## wood needed to place one wood wall
const WALL_STONE_COST   := 5          ## stone needed to place one stone wall
const WALL_PLACE_DIST   := 5.5        ## metres in front of player
const WALL_SNAP_DIST    := 2.5        ## XZ distance to snap ghost to a wall edge
const WALL_HALF_WIDTH   := 2.0        ## world-space half-width (model 2.0 * node scale 2.0 / 2)
var _build_mode:  bool      = false
var _build_item:  BuildItem = BuildItem.WOOD_WALL
var _ghost_wall:  Node3D    = null    ## semi-transparent preview
var _place_ray:   RayCast3D = null    ## ground-snapping ray
var _ghost_mats:  Array[BaseMaterial3D] = []  ## ghost materials for snap tinting
var _ghost_snapped: bool = false             ## true while ghost is locked to a snap socket

func _ready() -> void:
	add_to_group("player")
	up_direction = Vector3(0, 1, 0)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Build follow camera
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	add_child(_camera_pivot)
	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "SpringArm3D"
	_spring_arm.spring_length = 5.5
	_spring_arm.position = Vector3(0, 1.5, 0)
	_camera_pivot.add_child(_spring_arm)
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_spring_arm.add_child(_camera)
	_camera.make_current()
	_camera_pivot.rotation.x = _cam_pitch
	_attack_hitbox = get_node_or_null("AttackHitbox")
	_create_charge_ring()
	_char_model = get_node_or_null("CharacterModel")
	if _char_model:
		_anim = _find_anim_player(_char_model)
		_skeleton = _find_skeleton(_char_model)
		# Strip "mixamorig:" prefix from Mixamo bone names so NodePath parsing
		# works correctly (colons in bone names break track path resolution).
		_strip_mixamo_prefix()
		if _anim == null:
			# The base character ships with zero animations of its own, so
			# Godot's glTF import won't have created an AnimationPlayer for
			# it at all - make one ourselves, as a direct child of the
			# character root (the same place the animation library's own
			# AnimationPlayer sits relative to its Armature/Skeleton3D), so
			# the borrowed animations' bone paths resolve correctly.
			_anim = AnimationPlayer.new()
			_anim.name = "AnimationPlayer"
			_char_model.add_child(_anim)
	if _anim:
		_merge_animation_library()
		_load_mixamo_locomotion()   # overrides Idle/Walk/Sprint with proper Mixamo versions
		# UAL clips use plain names (Idle, Walk, Sprint — no _Loop suffix)
		for loop_name in ["Idle", "Walk", "Sprint", "Jog_Fwd", "Swim_Fwd", "Swim_Idle", "Sword_Idle", "Crouch_Idle", "Crouch_Fwd"]:
			if _anim.has_animation(loop_name):
				_anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
		if _anim.has_animation("TreeChopping"):
			_anim.get_animation("TreeChopping").loop_mode = Animation.LOOP_NONE
		_anim.play("Idle")
		_anim.animation_finished.connect(_on_anim_finished)
	# New rig (Quaternius Universal Base Character) has a real elbow and
	# wrist bone, unlike the old Kenney rig, so the sword can actually be
	# held naturally - attach it via BoneAttachment3D on hand_r.
	_attach_sword()
	_attach_axe()  # loaded hidden; sword is default
	# Ranger outfit for the forest scenes - see _attach_outfit() for why the
	# base body mesh gets hidden once the outfit pieces are on.
	_attach_outfit()
	# Exclude player body from spring arm so mesh doesn't vanish when looking down
	_spring_arm.add_excluded_object(get_rid())
	_spring_arm.collision_mask = 0   # don't shorten for any geometry

func set_input_blocked(v: bool) -> void:
	_input_blocked = v

func _input(event: InputEvent) -> void:
	if _input_blocked:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if _dev_inspect_mode:
			# Orbit the CAMERA around the stationary character - character does not turn
			if _camera_pivot:
				_camera_pivot.rotate_y(-event.relative.x * 0.003)
		else:
			rotate_y(-event.relative.x * 0.003)
			_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.003, -0.55, 0.4)
			if _camera_pivot:
				_camera_pivot.rotation.x = _cam_pitch
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: _jump_pending = true
			KEY_E:     _try_interact()
			KEY_F:     _do_attack()
			KEY_Q:     _switch_weapon()
			KEY_P:     _toggle_dev_inspect()
			KEY_B:     _toggle_build_mode()
			KEY_R:     _cycle_build_item()
			KEY_G:     if not _is_dead and _play_clip("Mx_ChokeLift"): _apply_melee_hit(SWORD_DAMAGE)
			KEY_ESCAPE:
				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				else:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not _build_mode and not _is_dead:
		if event.pressed:
			_start_charge()
		else:
			_release_charge()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _build_mode:
			_place_build_item()
		else:
			_do_attack()
	if event.is_action_pressed("ui_accept"):
		_jump_pending = true

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if _input_blocked:
		# Freeze the player while a UI panel (e.g. Kipatah menu) is open
		velocity.x = move_toward(velocity.x, 0.0, 60.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 60.0 * delta)
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		move_and_slide()
		return

	_attack_cooldown = max(_attack_cooldown - delta, 0.0)
	_combo_reset_timer = max(_combo_reset_timer - delta, 0.0)

	if _dev_inspect_mode:
		velocity = Vector3.ZERO
		move_and_slide()
		_update_locomotion_anim(delta)
		return

	if is_on_floor():
		velocity.y = max(velocity.y, 0.0)
		if _jump_pending:
			velocity.y = JUMP_FORCE
	else:
		velocity.y -= GRAVITY * delta
	_jump_pending = false

	var is_sprinting := Input.is_action_pressed("sprint")
	var speed := SPRINT_SPEED if is_sprinting else MOVE_SPEED
	var input  := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input == Vector2.ZERO:
		input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	if dir:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	# Sprint noise — makes enemies aware the player is moving fast nearby
	if is_sprinting and (velocity.x != 0.0 or velocity.z != 0.0):
		_sprint_noise_timer -= delta
		if _sprint_noise_timer <= 0.0:
			_sprint_noise_timer = _SPRINT_NOISE_INTERVAL
			made_noise.emit(global_position, 0.5)

	_update_locomotion_anim(delta)
	_update_build_mode(delta)
	_update_charge(delta)

func _attach_sword() -> void:
	if not _skeleton:
		print("Sword attach failed: no Skeleton3D found on character model")
		return
	# After _strip_mixamo_prefix(), Mixamo rig has "RightHand"; Quaternius has "hand_r"
	var _hand_bone_r := "RightHand" if _skeleton.find_bone("RightHand") != -1 else "hand_r"
	var bone_idx := _skeleton.find_bone(_hand_bone_r)
	if bone_idx == -1:
		print("Sword attach failed: no right hand bone found")
		return
	var attach := BoneAttachment3D.new()
	attach.name = "SwordAttachment"
	_skeleton.add_child(attach)
	attach.bone_name = _hand_bone_r  # set AFTER add_child so bone_idx resolves
	_sword = SWORD_SCENE.instantiate()
	attach.add_child(_sword)
	# hand_r's own local +Y axis already points the same way the fingers
	# extend (checked directly against the finger bones' rest translations
	# in the glTF), and the Kenney sword mesh's blade also points along its
	# own local +Y with the grip near the origin - so a real wrist bone
	# means we don't have to fake anything with rotation this time, the
	# sword just sits in the hand pointing the way the fingers already
	# point. BoneAttachment3D follows hand_r's animated pose every frame,
	# so it rides the Sword_Idle / Sword_Attack animations automatically.
	_sword.position = Vector3(0.0, 0.05, 0.0)
	_sword.rotation_degrees = Vector3.ZERO
	# Sword_Golden's raw mesh is authored ~6 units tip-to-grip (checked directly
	# against its .obj vertex bounds) - way bigger than a real-world blade
	# relative to this character. CharacterModel itself is already scaled up
	# 1.3x, so to land on a sensible ~1-unit blade length in the FINAL scene
	# (proportionate to the character's own ~2.35-unit scaled height) this
	# needs roughly 1.0 / (1.3 * 6.0) =~ 0.13 local scale. Untested in-editor -
	# nudge this value if it still reads too big/small once you see it.
	_sword.scale = Vector3(0.13, 0.13, 0.13)
	_sword_equipped = true
	_add_sword_glow()

func _attach_axe() -> void:
	if not _skeleton:
		return
	var _hand_bone_r2 := "RightHand" if _skeleton.find_bone("RightHand") != -1 else "hand_r"
	if _skeleton.find_bone(_hand_bone_r2) == -1:
		return
	var attach := BoneAttachment3D.new()
	attach.name = "AxeAttachment"
	_skeleton.add_child(attach)
	attach.bone_name = _hand_bone_r2  # set AFTER add_child so bone_idx resolves
	_axe = AXE_SCENE.instantiate()
	attach.add_child(_axe)
	# Measured from the pack's own Axe.obj: the haft runs along local +Y
	# (y -1.72 .. 3.54) with the head at the top (y 1.15 .. 3.39) and the
	# edge pointing +X - the SAME axes as Sword_Golden, so it needs no
	# rotation, just the sword's scale. The grip point is ~1.0 unit up from
	# the butt of the haft, so the axe is raised by that much (scaled) to
	# put the hand on the lower handle instead of the middle.
	var axe_scale := 0.13
	_axe.rotation_degrees = Vector3.ZERO
	_axe.scale = Vector3(axe_scale, axe_scale, axe_scale)
	_axe.position = Vector3(0.0, 0.05 + 1.0 * axe_scale, 0.0)
	_axe.visible = false  # sword is default; shown only when player switches

func _switch_weapon() -> void:
	## Cycle: sword → axe → hands → sword
	if _current_weapon == "sword":
		if _sword:
			_sword.visible = false
		if _axe:
			_axe.visible = true
		_sword_equipped = false
		_axe_equipped = true
		_current_weapon = "axe"
		_swing_token += 1
		_show_float_text("🪓 Axe", global_position + Vector3(0, 2.5, 0))
		print("[DEV] Switched to axe")
	elif _current_weapon == "axe":
		if _axe:
			_axe.visible = false
		if _sword:
			_sword.visible = false
		_axe_equipped = false
		_sword_equipped = false
		_current_weapon = "hands"
		_show_float_text("✊ Bare Hands", global_position + Vector3(0, 2.5, 0))
		print("[DEV] Switched to hands")
	else:
		## hands → sword
		if _sword:
			_sword.visible = true
		_sword_equipped = true
		_axe_equipped = false
		_current_weapon = "sword"
		_show_float_text("⚔ Sword", global_position + Vector3(0, 2.5, 0))
		print("[DEV] Switched to sword")

func _attach_outfit() -> void:
	if not _skeleton:
		return
	# Quaternius Ranger outfit only fits the Quaternius Universal Base Character rig
	if _skeleton.find_bone("hand_r") == -1:
		print("[DEV] Skipping Ranger outfit — not a Quaternius rig")
		return
	for scene in [OUTFIT_BODY_SCENE, OUTFIT_ARMS_SCENE, OUTFIT_LEGS_SCENE, OUTFIT_FEET_SCENE, OUTFIT_HOOD_SCENE, OUTFIT_PAULDRON_SCENE]:
		_graft_outfit_piece(scene)
	# Per the outfit pack's own Readme: "these outfits work together with the
	# Universal Base Character kit - when using the clothing, only the head
	# of the model is required, using the full body will result in clipping."
	# Our base character's body is one single mesh named "SuperHero_Male" -
	# hide it now that the Ranger pieces cover the torso/arms/legs/feet, but
	# keep the Eyebrows/Eyes meshes so the face still reads under the hood.
	var base_body := _find_mesh_by_name(_char_model, "SuperHero_Male")
	if base_body:
		base_body.visible = false

func _graft_outfit_piece(scene: PackedScene) -> void:
	# Each outfit part glTF imports as its own tiny scene with its own
	# Armature/Skeleton3D copy plus one skinned MeshInstance3D. We only want
	# the mesh - its Skin resource maps vertices to bones purely by NAME, and
	# our own skeleton has the exact same bone names, so the mesh can be
	# re-parented straight onto our skeleton and pointed at it with no other
	# changes needed.
	var temp := scene.instantiate()
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(temp, meshes)
	for mesh in meshes:
		mesh.get_parent().remove_child(mesh)
		_skeleton.add_child(mesh)
		mesh.skeleton = mesh.get_path_to(_skeleton)
		mesh.transform = Transform3D.IDENTITY
	temp.queue_free()

func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_mesh_instances(c, out)

func _find_mesh_by_name(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and node.name == mesh_name:
		return node
	for c in node.get_children():
		var found := _find_mesh_by_name(c, mesh_name)
		if found:
			return found
	return null

func _add_sword_glow() -> void:
	# The previous version (emissive material + a point light in the scene)
	# read as "a light near a sword", not an enchanted blade - a light
	# illuminates its surroundings, it doesn't make the sword's own surface
	# look magical. This uses the free CC0 "Glowing Fresnel" shader from
	# godotshaders.com instead (see assets/shaders/enchanted_fresnel.gdshader
	# for the adaptation notes): an animated, noise-driven rim glow baked
	# into the material itself, independent of scene lighting - applied only
	# to the blade's actual gold surfaces, not the wood/steel grip.
	if not _sword:
		return
	var noise_tex := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.15
	noise_tex.noise = fn
	noise_tex.width = 128
	noise_tex.height = 128
	noise_tex.seamless = true
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(_sword, meshes)
	for mesh in meshes:
		if not mesh.mesh:
			continue
		for i in mesh.mesh.get_surface_count():
			var src_mat := mesh.get_active_material(i)
			var base_color := Color(0.63, 0.51, 0.17)
			if src_mat is StandardMaterial3D:
				base_color = src_mat.albedo_color
			if not _looks_golden(base_color):
				continue
			var shader_mat := ShaderMaterial.new()
			shader_mat.shader = SWORD_GLOW_SHADER
			shader_mat.set_shader_parameter("base_color", Vector3(base_color.r, base_color.g, base_color.b))
			shader_mat.set_shader_parameter("glow_color", Vector3(1.0, 0.9, 0.5))
			shader_mat.set_shader_parameter("speed", 0.4)
			shader_mat.set_shader_parameter("glow_intensity", 1.5)
			shader_mat.set_shader_parameter("glow_amount", 2.0)
			shader_mat.set_shader_parameter("pos_mult", 0.0)
			shader_mat.set_shader_parameter("noise", noise_tex)
			mesh.set_surface_override_material(i, shader_mat)

func _looks_golden(c: Color) -> bool:
	# Cheap heuristic to target only the blade's Gold/LightGold surfaces (not
	# the DarkSteel/DarkWood/LightWood grip parts): gold/yellow tones have
	# red and green clearly higher than blue.
	return c.r > 0.3 and c.g > 0.2 and (c.r - c.b) > 0.15

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var found := _find_skeleton(c)
		if found:
			return found
	return null

func _strip_mixamo_prefix() -> void:
	# Godot NodePath uses ":" as a subname separator, so a bone named
	# "mixamorig:Hips" inside a track path "Skeleton3D:mixamorig:Hips" is
	# interpreted as two subnames ("mixamorig" + "Hips") and the bone lookup
	# silently fails — animations play but nothing moves.
	# Stripping the prefix at runtime gives clean names ("Hips", "Spine", …)
	# that resolve correctly.  Mesh skin binds use bone NAMES, so _fix_skin_bind_names()
	# renames those to match.
	if not _skeleton:
		return
	var stripped := false
	for i in _skeleton.get_bone_count():
		var bname := _skeleton.get_bone_name(i)
		# Tripo3D exports with underscore separator ("mixamorig_Hips");
		# standard Mixamo exports use colon ("mixamorig:Hips").
		# Both prefixes are 10 characters, so substr(10) strips either one.
		if bname.begins_with("mixamorig:") or bname.begins_with("mixamorig_"):
			_skeleton.set_bone_name(i, bname.substr(10))
			stripped = true
	if stripped:
		print("[DEV] Stripped mixamorig prefix from skeleton bones")
		# glTF imports bind the mesh skin to bones BY NAME, so after renaming
		# the bones we must rename the skin binds too — otherwise every vertex
		# loses its bone and the whole body collapses into a tiny blob.
		_fix_skin_bind_names(_char_model)
	# Always print bone names so we can verify what Godot loaded / renamed
	var bone_names: Array = []
	for i in min(_skeleton.get_bone_count(), 20):
		bone_names.append(_skeleton.get_bone_name(i))
	print("[DEV] Skeleton bones (", _skeleton.get_bone_count(), " total, first 20): ", bone_names)

func _fix_skin_bind_names(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.skin != null:
			var sk: Skin = mi.skin.duplicate()
			var changed := false
			for b in sk.get_bind_count():
				var bn := String(sk.get_bind_name(b))
				if bn.begins_with("mixamorig:") or bn.begins_with("mixamorig_"):
					sk.set_bind_name(b, bn.substr(10))
					changed = true
			if changed:
				mi.skin = sk   # reassigning forces the skeleton to re-register the skin
				print("[DEV] Fixed skin bind names on ", mi.name)
	for c in node.get_children():
		_fix_skin_bind_names(c)


# ---------------------------------------------------------------------------
# Retargeting: animations authored on another rig (Quaternius UAL, or a
# different Mixamo character) store bone rotations relative to THAT rig's rest
# pose and bone axes. Copying them raw onto Gomushi twists the body (lying
# sideways, limbs bent wrong). This converts each key into "how far the bone
# moved from rest, measured in world space" and re-applies that motion on top
# of Gomushi's own rest pose.
# ---------------------------------------------------------------------------
func _node_chain_basis(root: Node, node: Node) -> Basis:
	var b := Basis.IDENTITY
	var n := node
	while n != null and n != root:
		if n is Node3D:
			b = (n as Node3D).transform.basis.orthonormalized() * b
		n = n.get_parent()
	return b

func _bone_global_rest(skel: Skeleton3D, idx: int) -> Transform3D:
	var t := Transform3D.IDENTITY
	var i := idx
	while i != -1:
		t = skel.get_bone_rest(i) * t
		i = skel.get_bone_parent(i)
	return t

func _parent_global_basis(skel: Skeleton3D, idx: int, skel_basis: Basis) -> Basis:
	var p := skel.get_bone_parent(idx)
	if p == -1:
		return skel_basis
	return (skel_basis * _bone_global_rest(skel, p).basis).orthonormalized()

func _retarget_animation(anim: Animation, src_skel: Skeleton3D, src_basis: Basis, name_map: Callable, skel_rel_path: NodePath, in_place: bool = false) -> Animation:
	var dst_basis := _node_chain_basis(_char_model, _skeleton)
	var out := anim.duplicate(true) as Animation
	var src_root_h := 1.0
	var dst_root_h := 1.0
	for i in range(out.get_track_count() - 1, -1, -1):
		var src_name := out.track_get_path(i).get_concatenated_subnames()
		var ttype := out.track_get_type(i)
		var si := src_skel.find_bone(src_name)
		var dst_name: String = name_map.call(src_name)
		var di := _skeleton.find_bone(dst_name) if dst_name != "" else -1
		if si == -1 or di == -1 or ttype == Animation.TYPE_SCALE_3D:
			out.remove_track(i)
			continue
		var s_rest := src_skel.get_bone_rest(si)
		var d_rest := _skeleton.get_bone_rest(di)
		var s_par := _parent_global_basis(src_skel, si, src_basis)
		var d_par := _parent_global_basis(_skeleton, di, dst_basis)
		if ttype == Animation.TYPE_ROTATION_3D:
			var sq := s_par.get_rotation_quaternion()
			var dq := d_par.get_rotation_quaternion()
			var s_rest_q := s_rest.basis.get_rotation_quaternion()
			var d_rest_q := d_rest.basis.get_rotation_quaternion()
			for k in out.track_get_key_count(i):
				var q: Quaternion = out.track_get_key_value(i, k)
				var delta_local := q * s_rest_q.inverse()
				var delta_world := sq * delta_local * sq.inverse()
				var nq := (dq.inverse() * delta_world * dq) * d_rest_q
				out.track_set_key_value(i, k, nq.normalized())
		elif ttype == Animation.TYPE_POSITION_3D:
			# Only the root bone (Hips) keeps position keys - other bones'
			# position tracks would stretch Gomushi to the source's proportions.
			if src_skel.get_bone_parent(si) != -1:
				out.remove_track(i)
				continue
			src_root_h = maxf((src_basis * _bone_global_rest(src_skel, si).origin).length(), 0.001)
			dst_root_h = maxf((dst_basis * _bone_global_rest(_skeleton, di).origin).length(), 0.001)
			var ratio := dst_root_h / src_root_h
			for k in out.track_get_key_count(i):
				var pos: Vector3 = out.track_get_key_value(i, k)
				var dv := s_par * (pos - s_rest.origin)
				var np := d_rest.origin + (d_par.inverse() * dv) * ratio
				if in_place:
					# Keep the body over the capsule - attacks that lunge forward
					# would otherwise leave the model ahead of the player and snap back.
					np.x = d_rest.origin.x
					np.z = d_rest.origin.z
				out.track_set_key_value(i, k, np)
		out.track_set_path(i, NodePath(str(skel_rel_path) + ":" + dst_name))
	return out

func _merge_animation_library() -> void:
	# The base character ships with no animations of its own - pull them in
	# from Quaternius's separate Universal Animation Library glb at runtime
	# instead of hand-authoring anything, since both share the same rig.
	# Each animation's tracks carry NodePaths baked in relative to ITS OWN
	# AnimationPlayer's position in the animation-library scene, which
	# won't match where our AnimationPlayer sits in our own character's
	# tree - so every copied animation's tracks get rewritten to point at
	# our own skeleton (same bone names, since both packs share one rig)
	# instead of assuming the two files imported with identical hierarchy.
	if not _skeleton:
		return
	# Track NodePaths are resolved relative to the AnimationPlayer's
	# root_node (its parent, by default - NodePath("..")), NOT relative to
	# the AnimationPlayer itself. Using the wrong reference point here was
	# the previous bug: every bone track pointed one level off from the
	# real skeleton and silently did nothing.
	var anim_root := _anim.get_node(_anim.root_node)
	var skel_rel_path := anim_root.get_path_to(_skeleton)
	# Always merge into OUR default "" library regardless of what name the
	# source file's library has. has_animation()/play() only accept a bare
	# name like "Idle_Loop" for the default "" library - a name merged into
	# any other library would need to be called as "library_name/Idle_Loop",
	# which is exactly the kind of silent mismatch that leaves every clip
	# un-playable and the skeleton stuck in its raw bind pose (arms out).
	if not _anim.has_animation_library(""):
		_anim.add_animation_library("", AnimationLibrary.new())
	var dst_lib := _anim.get_animation_library("")
	# Both animation libraries share the exact same rig, so they merge with
	# the same technique - a name that exists in both (there aren't any
	# overlaps between library 1 and 2's clips) is kept from whichever
	# merged first via the has_animation() skip below.
	var lib_scenes: Array[PackedScene] = [SWORD_ANIM_LIBRARY_SCENE, SWORD_ANIM_LIBRARY_SCENE_2]
	for lib_scene_res in lib_scenes:
		var lib_scene: Node = lib_scene_res.instantiate()
		var lib_anim := _find_anim_player(lib_scene)
		var lib_skel := _find_skeleton(lib_scene)
		var lib_basis := _node_chain_basis(lib_scene, lib_skel) if lib_skel else Basis.IDENTITY
		if lib_anim:
			for lib_name in lib_anim.get_animation_library_list():
				var src_lib := lib_anim.get_animation_library(lib_name)
				for anim_name in src_lib.get_animation_list():
					if dst_lib.has_animation(anim_name):
						continue
					var src_anim: Animation = src_lib.get_animation(anim_name)
					var anim: Animation
					if lib_skel != null:
						anim = _retarget_animation(src_anim, lib_skel, lib_basis, _map_quaternius_bone, skel_rel_path)
					else:
						anim = src_anim.duplicate(true)
					dst_lib.add_animation(anim_name, anim)
		lib_scene.queue_free()
	print("[DEV] Animations merged: ", dst_lib.get_animation_list())
	print("[DEV] anim_root=", anim_root.name, " skeleton=", _skeleton.name, " skel_rel_path=", skel_rel_path)
	var uses_mixamo := _skeleton.find_bone("Hips") != -1 and _skeleton.find_bone("pelvis") == -1
	print("[DEV] uses_mixamo=", uses_mixamo, "  Hips_idx=", _skeleton.find_bone("Hips"), "  pelvis_idx=", _skeleton.find_bone("pelvis"))
	for chk_name in ["Idle_Loop", "Idle"]:
		if dst_lib.has_animation(chk_name):
			var chk_anim := dst_lib.get_animation(chk_name)
			print("[DEV] ", chk_name, " track_count=", chk_anim.get_track_count(), " sample_path=", str(chk_anim.track_get_path(0)) if chk_anim.get_track_count() > 0 else "none")
			break

func _map_quaternius_bone(src_name: String) -> String:
	if _skeleton.find_bone(src_name) != -1:
		return src_name
	return BONE_REMAP_Q_TO_MIXAMO.get(src_name, "")

func _map_mixamo_bone(src_name: String) -> String:
	if src_name.begins_with("mixamorig:") or src_name.begins_with("mixamorig_"):
		return src_name.substr(10)
	return src_name

func _load_mixamo_locomotion() -> void:
	# Load locomotion animations from Mixamo FBX files and apply them to Gomushi's
	# skeleton. Since Gomushi was auto-rigged by Mixamo, the bone names match exactly
	# after stripping the "mixamorig:" prefix — no remapping table needed.
	# Each Mixamo FBX contains one animation named "mixamo.com"; we rename it to
	# the clip name we actually use ("Idle", "Walk", "Sprint").
	if not _anim or not _skeleton:
		return
	if not _anim.has_animation_library(""):
		_anim.add_animation_library("", AnimationLibrary.new())
	var dst_lib := _anim.get_animation_library("")
	var anim_root := _anim.get_node(_anim.root_node)
	var skel_path := anim_root.get_path_to(_skeleton)

	for target_name in MIXAMO_CLIPS:
		var path: String = MIXAMO_DIR + MIXAMO_CLIPS[target_name]
		if not ResourceLoader.exists(path):
			print("[DEV] Mixamo clip missing: ", path)
			continue
		var scene_res := load(path) as PackedScene
		if scene_res == null:
			continue
		var temp: Node = scene_res.instantiate()
		var src_ap := _find_anim_player(temp)
		var src_skel := _find_skeleton(temp)
		var src_basis := _node_chain_basis(temp, src_skel) if src_skel else Basis.IDENTITY
		if not src_ap:
			temp.queue_free()
			print("[DEV] Mixamo FBX for ", target_name, " has no AnimationPlayer")
			continue
		var found := false
		for lib_name in src_ap.get_animation_library_list():
			var src_lib := src_ap.get_animation_library(lib_name)
			for src_name in src_lib.get_animation_list():
				var src_anim: Animation = src_lib.get_animation(src_name)
				var anim: Animation
				if src_skel != null:
					anim = _retarget_animation(src_anim, src_skel, src_basis, _map_mixamo_bone, skel_path, true)
				else:
					anim = src_anim.duplicate(true)
				# Remove the Quaternius-retargeted version (if any) and replace with Mixamo
				if dst_lib.has_animation(target_name):
					dst_lib.remove_animation(target_name)
				anim.loop_mode = Animation.LOOP_LINEAR if target_name in ["Idle", "Walk", "Sprint", "RunBackward"] else Animation.LOOP_NONE
				dst_lib.add_animation(target_name, anim)
				print("[DEV] Mixamo ", src_name, " → ", target_name, " (", anim.get_track_count(), " tracks)")
				found = true
				break
			if found:
				break
		temp.queue_free()

func _toggle_dev_inspect() -> void:
	# DEV TOOL ONLY - not part of the shipped game.
	# Freezes movement and zooms the camera in so you can spin the character
	# left/right (mouse X) to inspect equipment like the sword from all angles.
	_dev_inspect_mode = not _dev_inspect_mode
	if _dev_inspect_mode:
		velocity = Vector3.ZERO
		if _spring_arm:
			# Pull back and re-center on the torso/hand area (not the head)
			# so the whole body AND the equipped sword are actually in frame.
			_spring_arm.spring_length = 5.5
			_spring_arm.position = Vector3(0, 1.0, 0)
		if _camera_pivot:
			_camera_pivot.rotation.y = 0.0
		print("[DEV] Inspect mode ON - movement frozen, mouse orbits camera around character")
	else:
		if _spring_arm:
			_spring_arm.spring_length = 5.5
			_spring_arm.position = Vector3(0, 1.5, 0)
		if _camera_pivot:
			_camera_pivot.rotation.y = 0.0
		print("[DEV] Inspect mode OFF")

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null

func _update_locomotion_anim(delta: float) -> void:
	if _anim == null:
		return
	# While charging, hold the cast stance and skip locomotion blending
	if _is_charging:
		var cast_anim := "Mx_CastingSpell"
		if _anim.has_animation(cast_anim):
			if _anim.current_animation != cast_anim or not _anim.is_playing():
				_anim.play(cast_anim, 0.25)
		return
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if _attack_anim_time > 0.0:
		_attack_anim_time -= delta
		# Recovery clips (e.g. Sword_Regular_A_Rec) are just "lowering the sword"
		# - if the player starts moving, cut straight to walking instead.
		if not (String(_anim.current_animation).ends_with("_Rec") and flat_speed > 0.3):
			return
		_attack_anim_time = 0.0
	# The animation library only has a sword-specific pose for standing
	# still (Sword_Idle) - no sword-specific walk/sprint - so we use it
	# only at rest and fall back to the normal locomotion loops otherwise.
	var want := "Sword_Idle" if (_sword_equipped or _axe_equipped) else "Idle"  ## "Idle" also covers bare hands
	# Moving backwards relative to where the player faces -> backpedal clip
	var local_vel := global_transform.basis.inverse() * Vector3(velocity.x, 0, velocity.z)
	if flat_speed > 0.3 and local_vel.z > 0.3 and _anim.has_animation("RunBackward"):
		want = "RunBackward"
	elif flat_speed > MOVE_SPEED + 0.5:
		want = "Sprint"
	elif flat_speed > 0.3:
		want = "Walk"
	if _anim.current_animation != want and _anim.has_animation(want):
		_anim.play(want, 0.15)

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	health = clampi(health - amount, 0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()

func set_health(value: int) -> void:
	health = clampi(value, 0, max_health)
	health_changed.emit(health, max_health)

func _die() -> void:
	_is_dead = true
	# Soul respawn cost
	if inventory.get("souls", 0) > 0:
		inventory["souls"] -= 1
		inventory_changed.emit("souls", inventory["souls"])
	if _anim and _anim.has_animation("Mx_KnockedOut"):
		_anim.get_animation("Mx_KnockedOut").loop_mode = Animation.LOOP_NONE
		_play_clip("Mx_KnockedOut")
	player_died.emit()
	await get_tree().create_timer(3.0).timeout
	_respawn()

func _respawn() -> void:
	health    = max_health
	_is_dead  = false
	global_position = Vector3(-80, 0, 74)
	velocity  = Vector3.ZERO
	health_changed.emit(health, max_health)

func drown() -> void:
	_cam_shake = 0.6
	take_damage(50)
	global_position = Vector3(-80, 0, 74)
	velocity = Vector3.ZERO
	print("You drowned! Respawned.")

func add_item(item: String) -> void:
	if inventory.has(item):
		inventory[item] += 1
	else:
		inventory[item] = 1
	var display := item.replace("_", " ").capitalize()
	_show_float_text("+1 " + display, global_position + Vector3(0, 2.0, 0))
	print("Picked up: ", item, " (", inventory[item], ")")
	inventory_changed.emit(item, inventory[item])

func remove_item(item: String, count: int = 1) -> bool:
	var have: int = inventory.get(item, 0)
	if have < count:
		return false
	inventory[item] = have - count
	inventory_changed.emit(item, inventory[item])
	return true

func get_item_count(item: String) -> int:
	return inventory.get(item, 0) as int

# ── Soul System ─────────────────────────────────────────────────────────────

func sell_souls(amount: int) -> bool:
	if inventory.get("souls", 0) < amount:
		return false
	inventory["souls"] -= amount
	inventory_changed.emit("souls", inventory["souls"])
	souls_sold_total += amount
	_check_dark_tier()
	return true

func sacrifice_souls(amount: int) -> bool:
	if inventory.get("souls", 0) < amount:
		return false
	inventory["souls"] -= amount
	inventory_changed.emit("souls", inventory["souls"])
	souls_sacrificed_total += amount
	_check_divine_tier()
	return true

func _check_dark_tier() -> void:
	var new_tier: int = 0
	for i: int in DARK_THRESHOLDS.size():
		if souls_sold_total >= DARK_THRESHOLDS[i]:
			new_tier = i + 1
	if new_tier != dark_tier:
		dark_tier = new_tier
		dark_tier_changed.emit(dark_tier)
		var names: Array[String] = ["Tainted", "Corrupted", "Infernal", "Damned", "Forsaken", "Hellbound"]
		_show_float_text("Dark Tier: " + names[dark_tier - 1], global_position + Vector3(0, 3.0, 0))
		print("Dark Tier reached: ", dark_tier)

func _check_divine_tier() -> void:
	var new_tier: int = 0
	for i: int in DIVINE_THRESHOLDS.size():
		if souls_sacrificed_total >= DIVINE_THRESHOLDS[i]:
			new_tier = i + 1
	if new_tier != divine_tier:
		divine_tier = new_tier
		divine_bonus = DIVINE_BONUSES[divine_tier - 1]
		divine_tier_changed.emit(divine_tier)
		var names: Array[String] = ["Acknowledged", "Devoted", "Chosen", "Blessed", "Sacred", "Divine"]
		_show_float_text("☀ " + names[divine_tier - 1] + " +" + str(divine_bonus) + "% ATK", global_position + Vector3(0, 3.0, 0))
		print("Divine Tier reached: ", divine_tier, " | Bonus: +", divine_bonus, "%")

func get_attack_power() -> int:
	var base: int = inventory.get("souls", 0)
	## Apply divine bonus as a percentage multiplier
	return base + int(base * divine_bonus / 100.0)

# ── build mode ─────────────────────────────────────────────────────────────
func _toggle_build_mode() -> void:
	_build_mode = not _build_mode
	if _build_mode:
		if _place_ray == null:
			_place_ray = RayCast3D.new()
			_place_ray.name = "PlaceRay"
			_place_ray.target_position = Vector3(0, -10, 0)
			_place_ray.enabled = true
			add_child(_place_ray)
		_spawn_ghost_wall()
		var cost_str := str(WALL_WOOD_COST) + " Wood" if _build_item == BuildItem.WOOD_WALL else str(WALL_STONE_COST) + " Stone"
		_show_float_text("Build Mode ON  (B=exit, R=cycle, LClick=place, " + cost_str + ")", global_position + Vector3(0, 3, 0))
	else:
		if _ghost_wall:
			_ghost_wall.queue_free()
			_ghost_wall = null
		_show_float_text("Build Mode OFF", global_position + Vector3(0, 2.5, 0))

func _spawn_ghost_wall() -> void:
	if _ghost_wall:
		_ghost_wall.queue_free()
		_ghost_wall = null
	_ghost_mats.clear()
	_ghost_snapped = false
	var scene := WOOD_WALL_SCENE if _build_item == BuildItem.WOOD_WALL else STONE_WALL_SCENE
	_ghost_wall = scene.instantiate()
	_ghost_wall.name = "GhostWall"
	for m: MeshInstance3D in _ghost_wall.find_children("*", "MeshInstance3D", true, false):
		var mat: Material = m.get_active_material(0)
		if mat:
			var ghost_mat := mat.duplicate() as BaseMaterial3D
			if ghost_mat:
				ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ghost_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.45)
				m.set_surface_override_material(0, ghost_mat)
				_ghost_mats.append(ghost_mat)
	for col: Node in _ghost_wall.find_children("*", "CollisionShape3D", true, false):
		(col as CollisionShape3D).disabled = true
	get_tree().root.add_child(_ghost_wall)

func _cycle_build_item() -> void:
	if not _build_mode:
		return
	_build_item = BuildItem.STONE_WALL if _build_item == BuildItem.WOOD_WALL else BuildItem.WOOD_WALL
	var name_str := "Stone Wall" if _build_item == BuildItem.STONE_WALL else "Wood Wall"
	_show_float_text(name_str, global_position + Vector3(0, 2.5, 0))
	_spawn_ghost_wall()

func _update_build_mode(_delta: float) -> void:
	if not _build_mode or _ghost_wall == null:
		return
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() > 0.001:
		fwd = fwd.normalized()
	var default_pos := global_position + fwd * WALL_PLACE_DIST
	var ground_y := global_position.y
	if _place_ray and _place_ray.is_colliding():
		ground_y = _place_ray.get_collision_point().y
	default_pos.y = ground_y

	# ── snap scan: find the nearest edge socket on any placed wall ──────────
	var best_dist  := WALL_SNAP_DIST
	var snap_pos   := default_pos
	var snap_rot   := rotation.y
	var did_snap   := false

	for wall: Node3D in get_tree().get_nodes_in_group("placed_wall"):
		# basis.x is the scaled local-X axis; normalize to get pure direction
		var bx: Vector3 = wall.global_transform.basis.x.normalized()
		var right_sock: Vector3 = wall.global_position + bx * WALL_HALF_WIDTH
		var left_sock:  Vector3 = wall.global_position - bx * WALL_HALF_WIDTH
		for sock: Vector3 in [right_sock, left_sock]:
			var d: float = Vector2(sock.x - default_pos.x, sock.z - default_pos.z).length()
			if d < best_dist:
				best_dist = d
				snap_pos  = sock
				snap_rot  = wall.rotation.y
				did_snap  = true

	_ghost_wall.global_position = snap_pos
	_ghost_wall.rotation.y      = snap_rot

	# Update ghost tint only when snap state actually changes (avoids per-frame alloc)
	if did_snap != _ghost_snapped:
		_ghost_snapped = did_snap
		_ghost_set_snap_color(did_snap)

func _ghost_set_snap_color(snapped: bool) -> void:
	var tint := Color(0.3, 1.0, 0.4, 0.6) if snapped else Color(1.0, 1.0, 1.0, 0.45)
	for mat: BaseMaterial3D in _ghost_mats:
		mat.albedo_color = tint

func _place_build_item() -> void:
	if not _build_mode or _ghost_wall == null:
		return
	if _build_item == BuildItem.WOOD_WALL:
		if get_item_count("wood") < WALL_WOOD_COST:
			_show_float_text("Need " + str(WALL_WOOD_COST) + " Wood  (have " + str(get_item_count("wood")) + ")", global_position + Vector3(0, 2.5, 0))
			return
		remove_item("wood", WALL_WOOD_COST)
		var wall := WOOD_WALL_SCENE.instantiate()
		wall.global_position = _ghost_wall.global_position
		wall.rotation.y = _ghost_wall.rotation.y
		get_tree().root.add_child(wall)
		_show_float_text("-" + str(WALL_WOOD_COST) + " Wood  |  Wood Wall placed!", wall.global_position + Vector3(0, 2.5, 0))
	else:
		if get_item_count("stone") < WALL_STONE_COST:
			_show_float_text("Need " + str(WALL_STONE_COST) + " Stone  (have " + str(get_item_count("stone")) + ")", global_position + Vector3(0, 2.5, 0))
			return
		remove_item("stone", WALL_STONE_COST)
		var wall := STONE_WALL_SCENE.instantiate()
		wall.global_position = _ghost_wall.global_position
		wall.rotation.y = _ghost_wall.rotation.y
		get_tree().root.add_child(wall)
		_show_float_text("-" + str(WALL_STONE_COST) + " Stone  |  Stone Wall placed!", wall.global_position + Vector3(0, 2.5, 0))

func _show_float_text(text: String, world_pos: Vector3) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.pixel_size = 0.012
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = Color(1.0, 0.95, 0.3)
	lbl.font_size = 28
	get_tree().root.add_child(lbl)
	lbl.global_position = world_pos
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "global_position", world_pos + Vector3(0, 2.0, 0), 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free)

func _do_attack() -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = AXE_COOLDOWN if _axe_equipped else 0.6
	_play_swing_anim()
	if _axe_equipped:
		var swing_len := 0.5
		if _anim and _anim.has_animation(AXE_SWING_ANIM):
			swing_len = _anim.get_animation(AXE_SWING_ANIM).length / AXE_SWING_SPEED
		var token := _swing_token + 1
		_swing_token = token
		await get_tree().create_timer(swing_len * AXE_HIT_FRACTION).timeout
		# Cancelled if the player switched weapons / died mid-swing
		if _is_dead or not _axe_equipped or token != _swing_token:
			return
		_apply_melee_hit(AXE_DAMAGE)
		_chop_trees()
		_mine_rocks()
		# Axe thud — loud noise that attracts nearby enemies
		made_noise.emit(global_position, 1.0)
	else:
		_apply_melee_hit(SWORD_DAMAGE)

func _chop_trees() -> void:
	# Only the axe fells trees. Any scene whose terrain supports harvesting
	# (ForestTerrain in FantasyForest) registers itself in this group.
	var chop_point := global_position - global_transform.basis.z * 1.3
	for terrain in get_tree().get_nodes_in_group("harvestable_trees"):
		if terrain.has_method("chop_at") and terrain.chop_at(chop_point, 1.8, self):
			_cam_shake = max(_cam_shake, 0.15)
			return

func _mine_rocks() -> void:
	# Only the axe mines rocks. Rocks register themselves in "harvestable_rocks".
	var mine_point := global_position - global_transform.basis.z * 1.3
	for rock in get_tree().get_nodes_in_group("harvestable_rocks"):
		if rock.has_method("mine_at") and rock.mine_at(mine_point, 1.8, self):
			_cam_shake = max(_cam_shake, 0.15)
			return


func _apply_melee_hit(damage: int) -> void:
	# Sphere cast in front of player — immediate, no hitbox polling needed
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	params.shape = sphere
	var attack_origin := global_position + Vector3(0, 1.0, 0) + (-global_transform.basis.z * 1.5)
	params.transform = Transform3D(Basis(), attack_origin)
	params.collision_mask = 1   # HurtBox default layer (layer 1)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := space.intersect_shape(params, 8)
	for hit in hits:
		var col = hit.collider
		var target = col.get_parent() if col is Area3D else col
		if target.has_method("take_damage") and not target.is_in_group("player"):
			target.take_damage(damage)

func _play_swing_anim() -> void:
	if _sword_equipped and not is_on_floor() and _play_clip("Mx_JumpAttack"):
		_spawn_slash_vfx()
	elif _sword_equipped and Input.is_action_pressed("sprint") and Vector2(velocity.x, velocity.z).length() > MOVE_SPEED and _play_clip("Mx_RunJumpAttack"):
		_spawn_slash_vfx()
	elif _sword_equipped:
		_play_sword_combo_hit()
	elif _axe_equipped:
		_play_axe_chop()
	else:
		# Unarmed: punch -> punch -> side kick, same combo window as the sword
		if _combo_reset_timer <= 0.0:
			_combo_index = 0
		var clip: String = UNARMED_COMBO[_combo_index % UNARMED_COMBO.size()]
		if not _play_clip(clip):
			_play_clip("Punch_Cross")
		_combo_reset_timer = _attack_anim_time + COMBO_WINDOW
		_combo_index = (_combo_index + 1) % UNARMED_COMBO.size()


## Plays a one-shot clip at its CLIP_SPEED and holds off idle/walk until it ends.
func _play_clip(clip: String) -> bool:
	if _anim == null or not _anim.has_animation(clip):
		return false
	var spd: float = CLIP_SPEED.get(clip, 1.6)
	_pending_recovery = ""
	_anim.stop()
	_anim.play(clip, 0.1, spd)
	_attack_anim_time = _anim.get_animation(clip).length / spd
	return true


func _play_axe_chop() -> void:
	# Sword_Attack from Universal Animation Library 1 - one big committed
	# swing, which suits a heavy axe better than the quick sword combo.
	var anim_name := AXE_SWING_ANIM
	if _anim and _anim.has_animation(anim_name):
		_anim.stop()
		_anim.play(anim_name, 0.05, AXE_SWING_SPEED)
		_attack_anim_time = _anim.get_animation(anim_name).length / AXE_SWING_SPEED
	_pending_recovery = ""
	_combo_reset_timer = 0.0  # no combo chain for axe

func _play_sword_combo_hit() -> void:
	# 3-hit combo from Universal Animation Library 2 (Sword_Regular_A/B/C) -
	# clicking attack again within COMBO_WINDOW after a hit lands advances to
	# the next hit; waiting longer than that resets back to the first hit.
	# Each of the first two hits is followed by its own recovery animation
	# (Sword_Regular_A_Rec/B_Rec) UNLESS the player chains into the next hit
	# first - handled via _on_anim_finished() below, gated by _swing_token so
	# a stale recovery from an old hit can never fire after a newer one.
	if _combo_reset_timer <= 0.0:
		_combo_index = 0
	var hit_anim := SWORD_COMBO_ANIMS[_combo_index]
	var rec_anim := SWORD_COMBO_RECOVERIES[_combo_index]
	if _anim and _anim.has_animation(hit_anim):
		var spd: float = CLIP_SPEED.get(hit_anim, 1.6)
		_anim.stop()
		_anim.play(hit_anim, 0.1, spd)
		var hit_length: float = _anim.get_animation(hit_anim).length / spd
		# Slightly longer than the clip so it finishes (and its recovery clip can
		# start) before the idle/walk logic takes over.
		_attack_anim_time = hit_length + 0.1
		_combo_reset_timer = hit_length + COMBO_WINDOW
		_swing_token += 1
		if rec_anim != "" and _anim.has_animation(rec_anim):
			_pending_recovery = rec_anim
			_pending_recovery_swing = _swing_token
		else:
			_pending_recovery = ""
	_spawn_slash_vfx()
	_combo_index = (_combo_index + 1) % SWORD_COMBO_ANIMS.size()

func _on_anim_finished(_anim_name: StringName) -> void:
	# _swing_token only still matches if no NEWER swing has started since
	# this recovery was scheduled - if the player chained into the next
	# combo hit instead, the token was already bumped and this is skipped.
	if _pending_recovery != "" and _pending_recovery_swing == _swing_token:
		var rec := _pending_recovery
		_pending_recovery = ""
		_anim.play(rec, 0.1)
		_attack_anim_time = _anim.get_animation(rec).length

func _spawn_slash_vfx() -> void:
	# "Fiery Slash Shader for Godot 4" by DevQuest (itch.io, free/pay-what-
	# you-want) - a ready-made arc mesh + shader, not something built from
	# scratch here. Its own "speed" shader parameter is really an elapsed-
	# time value the original demo tweens from 0 up to "duration" to reveal
	# then fade the slash - done here too, timed to the swing itself instead
	# of the slower default so it reads as a quick attack, not a slow burn.
	var vfx := SLASH_VFX_SCENE.instantiate()
	add_child(vfx)
	# Local to the player, so it automatically faces wherever the player is
	# facing - parked roughly where the blade sweeps during Sword_Attack.
	vfx.position = Vector3(0.0, 1.2, -1.6)
	var mesh := vfx.get_node("MeshInstance3D") as MeshInstance3D
	if _slash_mesh == null:
		var src: Node = SLASH_MESH_SCENE.instantiate()
		var found: Array[MeshInstance3D] = []
		_collect_mesh_instances(src, found)
		if found.size() > 0:
			_slash_mesh = found[0].mesh
		src.queue_free()
	mesh.mesh = _slash_mesh
	# material_override (not a per-surface override) because the mesh is only
	# assigned at runtime - a surface override set in the .tscn gets dropped
	# when the scene loads with no mesh yet.
	var mat := mesh.material_override as ShaderMaterial
	var duration: float = mat.get_shader_parameter("duration")
	mat.set_shader_parameter("speed", 0.0)
	var tw := create_tween()
	tw.tween_property(mat, "shader_parameter/speed", duration, 0.3)
	tw.tween_callback(vfx.queue_free)

func _try_interact() -> void:
	var best: Node3D = null
	var best_dist := INTERACT_RANGE * INTERACT_RANGE
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Node3D:
			var d := global_position.distance_squared_to(node.global_position)
			if d < best_dist:
				best_dist = d
				best = node
	if best == null:
		return
	if best.has_method("interact"):
		best.interact(self)
	elif best.has_meta("_interact_callable"):
		## Used by runtime-built interactables (e.g. fruit trees) that cannot
		## attach a script method but can store a Callable in metadata.
		(best.get_meta("_interact_callable") as Callable).call(self)

# ══════════════════════════════════════════════════════════════════════════════
# CHARGE BLAST SYSTEM
# RMB hold → charge up (ring VFX + cast stance), release → fire big blast.
# ══════════════════════════════════════════════════════════════════════════════

func _get_charge_color(t: float) -> Color:
	## Color ladder for t in 0..1:
	## white → blue → cyan → green → yellow → orange → red → violet (MAX)
	if t < 0.05: return Color(1.0, 1.0, 1.0).lerp(Color(0.3, 0.5, 1.0), t / 0.05)
	if t < 0.20: return Color(0.3, 0.5, 1.0).lerp(Color(0.0, 1.0, 1.0), (t - 0.05) / 0.15)
	if t < 0.40: return Color(0.0, 1.0, 1.0).lerp(Color(0.1, 1.0, 0.2), (t - 0.20) / 0.20)
	if t < 0.60: return Color(0.1, 1.0, 0.2).lerp(Color(1.0, 1.0, 0.0), (t - 0.40) / 0.20)
	if t < 0.75: return Color(1.0, 1.0, 0.0).lerp(Color(1.0, 0.45, 0.0), (t - 0.60) / 0.15)
	if t < 0.88: return Color(1.0, 0.45, 0.0).lerp(Color(1.0, 0.08, 0.0), (t - 0.75) / 0.13)
	if t < 0.96: return Color(1.0, 0.08, 0.0).lerp(Color(0.65, 0.0, 1.0), (t - 0.88) / 0.08)
	return Color(0.65, 0.0, 1.0)


func _create_charge_ring() -> void:
	var scene := load("res://assets/BinbunVFX_Vol2/StatusFX/effects/status/vfx_status_shatter.tscn") as PackedScene
	if scene == null:
		return

	# 4 layers appear at t = 0.0 / 0.25 / 0.50 / 0.75
	# Each sits at a slightly different height and starts at a different base scale
	var positions: PackedVector3Array = [
		Vector3(0.0, 0.5,  0.0),
		Vector3(0.0, 0.8,  0.0),
		Vector3(0.0, 0.35, 0.0),
		Vector3(0.0, 1.0,  0.0),
	]
	var base_scales: PackedFloat32Array = [0.45, 0.7, 1.1, 1.5]
	for i in range(4):
		var vfx := scene.instantiate() as Node3D
		vfx.position = positions[i]
		vfx.scale    = Vector3.ONE * base_scales[i]
		vfx.visible  = false
		add_child(vfx)
		_charge_vfx_layers.append(vfx)

	# Floating power level label — always faces the camera (billboard)
	_charge_level_label = Label3D.new()
	_charge_level_label.text            = "LV.1"
	_charge_level_label.font_size       = 72
	_charge_level_label.outline_size    = 8
	_charge_level_label.modulate        = Color.WHITE
	_charge_level_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	_charge_level_label.billboard       = BaseMaterial3D.BILLBOARD_ENABLED
	_charge_level_label.no_depth_test   = true
	_charge_level_label.position        = Vector3(0.7, 2.4, 0.0)
	_charge_level_label.visible         = false
	add_child(_charge_level_label)


func _start_charge() -> void:
	if _is_charging:
		return
	_is_charging   = true
	_charge_power  = 0.0
	# Show tier-0 layer immediately; higher tiers appear in _update_charge
	if _charge_vfx_layers.size() > 0:
		var vfx0 := _charge_vfx_layers[0] as Node3D
		vfx0.visible = true
		vfx0.scale   = Vector3.ONE * 0.45
		var ap0 := vfx0.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap0 and ap0.has_animation("open"):
			ap0.play("open")
	if _charge_level_label:
		_charge_level_label.visible = true
		_charge_level_label.text    = "LV.1"


func _release_charge() -> void:
	if not _is_charging:
		return
	_is_charging = false
	for vfx: Node3D in _charge_vfx_layers:
		if vfx.visible:
			var ap := vfx.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if ap and ap.has_animation("close"):
				ap.play("close")
			vfx.visible = false
	if _charge_level_label:
		_charge_level_label.visible = false
	var released_power := _charge_power
	_charge_power = 0.0
	if released_power > 50.0:
		_fire_player_blast(released_power)
	else:
		# Tap with no charge — quick spell cast animation as before
		_play_clip("Mx_SpellCast")
	# Return to idle
	if _anim and _anim.has_animation("Idle") and released_power <= 50.0:
		_anim.play("Idle", 0.3)


func _update_charge(delta: float) -> void:
	if not _is_charging:
		return
	_charge_power = minf(_charge_power + CHARGE_RATE * delta, MAX_CHARGE_POWER)
	var t := _charge_power / MAX_CHARGE_POWER
	var col := _get_charge_color(t)

	# Tier thresholds, base scales, max scales, base emission per layer
	var thresholds:    PackedFloat32Array = [0.0,  0.25, 0.50, 0.75]
	var base_scales:   PackedFloat32Array = [0.45, 0.7,  1.1,  1.5]
	var max_scales:    PackedFloat32Array = [1.1,  1.6,  2.2,  3.0]
	var base_emission: PackedFloat32Array = [4.0,  6.0,  10.0, 15.0]

	for i in range(_charge_vfx_layers.size()):
		var vfx: Node3D = _charge_vfx_layers[i]
		if t >= thresholds[i]:
			# Unlock this tier the first time we cross its threshold
			if not vfx.visible:
				vfx.visible = true
				var ap := vfx.get_node_or_null("AnimationPlayer") as AnimationPlayer
				if ap and ap.has_animation("open"):
					ap.play("open")
			# Normalize t within this tier's range so each layer grows independently
			var next_thresh: float = thresholds[i] + 0.25 if i < 3 else 1.0
			var local_t: float = clampf((t - thresholds[i]) / (next_thresh - thresholds[i]), 0.0, 1.0)
			vfx.scale = Vector3.ONE * lerpf(base_scales[i], max_scales[i], local_t)
			vfx.set("primary_color", col)
			vfx.set("emission", lerpf(base_emission[i], base_emission[i] * 2.2, local_t))

	# Power level label: LV.1 at t=0 → LV.10 at t=1
	if _charge_level_label:
		var level: int = clampi(int(t * 10.0) + 1, 1, 10)
		_charge_level_label.text     = "LV.%d" % level
		_charge_level_label.modulate = col


func _fire_player_blast(blast_power: float) -> void:
	var blast: Node3D = PLAYER_BLAST_SCENE.instantiate()
	get_parent().add_child(blast)
	var origin := global_position + Vector3(0, 1.4, 0)
	blast.global_position = origin
	blast.set("power",     blast_power)
	blast.set("direction", -global_transform.basis.z)

	# Cast flash VFX at player hands
	var vfx_cast_path := "res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/cast/vfx_fire_cast_01.tscn"
	var vfx_cast_res := load(vfx_cast_path) as PackedScene
	if vfx_cast_res:
		var fx := vfx_cast_res.instantiate() as Node3D
		get_parent().add_child(fx)
		fx.global_position = origin
		var s := lerpf(0.9, 3.5, blast_power / MAX_CHARGE_POWER)
		fx.scale = Vector3.ONE * s
		if "one_shot" in fx:
			fx.set("one_shot", true)
		if fx.has_method("play"):
			fx.call("play")
		get_tree().create_timer(1.8).timeout.connect(fx.queue_free)

	_play_clip("Mx_SpellCast")
	print("[Player] BLAST fired! Power: ", int(blast_power), " / ", int(MAX_CHARGE_POWER))

# ── Save / Load ───────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"class":       "Player3D",
		"x":           global_position.x,
		"y":           global_position.y,
		"z":           global_position.z,
		"rot_y":       rotation.y,
		"health":      health,
		"max_health":  max_health,
		"inventory":   inventory.duplicate(),
	}


func apply_save_data(d: Dictionary) -> void:
	global_position = Vector3(
		float(d.get("x", 0.0)),
		float(d.get("y", 1.0)),
		float(d.get("z", 0.0))
	)
	rotation.y = float(d.get("rot_y", 0.0))
	max_health = int(d.get("max_health", 100))
	health     = clampi(int(d.get("health", max_health)), 0, max_health)
	var saved_inv: Dictionary = d.get("inventory", {})
	for key: String in saved_inv:
		inventory[key] = int(saved_inv[key])
	emit_signal("health_changed", health, max_health)
