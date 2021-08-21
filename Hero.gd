extends KinematicBody

const MIN_ROT_Y=-89
const MAX_ROT_Y=45
const ZOOM_MIN=2
const ZOOM_MAX=10
const GRAVITY=-9.8
const VEL_SPEED=2
const ROT_SPEED=1.5
const JUMP_SPEED=-250
const LOOK_PERSON = 0.25

export var Sensitivity_X=0.4
export var Sensitivity_Y=0.4
export var Zoom_step=0.5
export var Rotate_Model_Step = PI
export var camera_far_long=200
export var start_hp = 90
export var start_max_hp = 90
export var power_damage = 20
export var recovery = 100

onready var animation= $AnimationPlayer
onready var rotate_node=$ControlledSpatial
onready var raycast_node=$ControlledSpatial/RayCast
onready var raycast_node2=$ControlledSpatial/SpringArm/Camera/RayCastCamera
onready var springarm_node=$ControlledSpatial/SpringArm
onready var model_node=$Spatial/Skeleton
onready var camera_node=$ControlledSpatial/SpringArm/Camera
onready var arm=$ControlledSpatial/SpringArm/Camera/PositionNode
onready var hero_hp = $Hero_UI/HP_Progress

var mouse_relative=Vector2()
var velocity=Vector3()
var state="Idle"
var aim=1
var chek_1_look=0
var chek_1_look_back=0
var input_enabled:bool=true
var gun_fire:bool=false
var active_gun = null
var items = 0
var inventory = {}
var target: bool = true
var timer = 0
var need_heal: bool = false

var hero_resistance = 1
var hero_speed = 1
var hero_damage = 1
var hero_health = 1

var hero_resistance_exp = 0
var hero_speed_exp = 0
var hero_damage_exp = 0
var hero_health_exp = 0

var walk_time = 0

func _ready():
	camera_node.current=true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hero_hp.hp = start_hp + hero_health * 10
	start_max_hp += hero_health * 10
	hero_hp.set_start_hp(hero_hp.hp, start_max_hp)
	set_resistance_lvl()
	set_speed_lvl()
	set_damage_lvl()
	set_health_lvl()
	GameInstance.can_play = true

func _physics_process(delta):
	var direction=Vector3()
	var need_state=""
	var need_animation=""
	
	if input_enabled:
		if Input.is_action_pressed("ui_left"):
			rotate_y(ROT_SPEED*delta)
			need_state="Turn"
		elif Input.is_action_pressed("ui_right"):
			rotate_y(-ROT_SPEED*delta)
			need_state="Turn"
		if Input.is_action_pressed("ui_up"):
			direction.z=1
			need_state="Walk"
			walk_time += 1
			if walk_time >= 1000:
				walk_time = 0
				speed_exp(1)
			if Input.is_action_pressed("ui_shift"):
				direction.z=2.5
				need_state="Run"
			direction.z *= (1 + hero_speed / 10)
		elif Input.is_action_pressed("ui_down"):
			direction.z=-1
			need_state="Walk"
		
		if Input.is_action_just_pressed("attack"):
#			if gun_fire:
#				#gun.fire()
#				pass
#			else: 
			need_state="Attack"
			power_damage *= (1 + hero_damage / 10)
			chek_interaction(power_damage)
		if Input.is_action_just_pressed("Interact"):
			chek_interaction(power_damage)
		
		if Input.is_action_just_pressed("ui_jump") and is_on_floor():
			velocity.y=-JUMP_SPEED*delta
		
		if need_heal:
			timer += delta
			if timer > 20:
				if timer > 25:
					recovery_hp()
	
	if Input.is_action_just_pressed("1_look"):
		chek_1_look+=1
		if !chek_1_look%2:
			springarm_node.spring_length=chek_1_look_back
			aim=1
			arm.visible=false
			gun_fire=false
			camera_node.far=100
		else:
			chek_1_look_back=springarm_node.spring_length
			aim = LOOK_PERSON
			arm.visible=true
			gun_fire=true
			springarm_node.spring_length=-aim
			camera_node.far=camera_far_long
	
	if direction:
		direction=direction.rotated(Vector3(0,1,0),rotation.y)*VEL_SPEED
	
	if !is_on_floor():
		velocity.y+=GRAVITY*delta
	
	velocity.z=direction.z
	velocity.x=direction.x
	
	velocity=move_and_slide(velocity,Vector3.UP)
	
	if mouse_relative!=Vector2.ZERO and aim != LOOK_PERSON:
		rotate_camera(Vector2(mouse_relative.y*delta*Sensitivity_Y,mouse_relative.x*delta*Sensitivity_X))
		mouse_relative=Vector2()
		
	if !need_state and animation.current_animation!="Attack": 
		need_state="Idle"
	
	set_state(need_state, need_animation)

func _input(event):
	if input_enabled:
		if event is InputEventMouseMotion:
			if aim == LOOK_PERSON:
				transform.basis = Basis(Vector3.UP, rotation.y - event.relative.x * 0.001)
				springarm_node.transform.basis = Basis(Vector3.RIGHT, springarm_node.rotation.x - event.relative.y * 0.001)
				springarm_node.rotation.y=PI
				if springarm_node.rotation.x > 1.4: springarm_node.rotation.x = 1.4
				elif springarm_node.rotation.x < -1.4: springarm_node.rotation.x = -1.4
				
			else:
				mouse_relative+=event.relative
		elif event.is_action_pressed("camera_zoom_in") and aim != LOOK_PERSON:
			zoom_camera(1)
		elif event.is_action_pressed("camera_zoom_out") and aim != LOOK_PERSON:
			zoom_camera(-1)

func zoom_camera(direction):
	if direction>0 and springarm_node.spring_length<=ZOOM_MIN:
		springarm_node.spring_length=ZOOM_MIN

	elif direction<0 and springarm_node.spring_length>=ZOOM_MAX:
		springarm_node.spring_length=ZOOM_MAX
	else: 
		springarm_node.spring_length-=direction*Zoom_step

func rotate_camera(offset):
	springarm_node.rotation.y-=offset.y / 2
	if springarm_node.rotation.y>PI:
		springarm_node.rotation.y-=PI*2
	elif springarm_node.rotation.y>-PI:
		springarm_node.rotation.y+=PI*2
	if offset.x<=0 and springarm_node.rotation_degrees.x>=MAX_ROT_Y:
		return
	if offset.x>=0 and springarm_node.rotation_degrees.x<=MIN_ROT_Y:
		return
	springarm_node.rotation.x-=offset.x / 2

func set_state(s, a = ""):
	if !s or state == s: return
	state=s
	if !a:a=s
	if animation.current_animation==a: return
	if a=="Run":animation.playback_speed=1.5
	else: animation.playback_speed=1
	animation.play(a,0.3)

func get_gun(object):
	active_gun = load(object).instance()
	arm.add_child(active_gun)

func pick(object):
	var it = object.get_item()
	if it in inventory.keys():
		inventory[it] += object.get_amount()
	else:
		inventory[it] = object.get_amount() 
	GameInstance.ui.update_invetory(inventory)

func _unhandled_input(event):
	if event.is_action_pressed("inventory"):
		GameInstance.ui.toggle_inventory(inventory)

func set_resistance_lvl():
	$Hero_UI/VBoxContainer/Resistance.text = "Resistance:   %d  LVL" % hero_resistance

func set_speed_lvl():
	$Hero_UI/VBoxContainer/Speed.text = "Speed:             %d  LVL" % hero_speed

func set_damage_lvl():
	$Hero_UI/VBoxContainer/Damage.text = "Damage:         %d  LVL" % hero_damage

func set_health_lvl():
	$Hero_UI/VBoxContainer/Health.text = "Health:             %d  LVL" % hero_health
	hero_hp.hp = start_hp + hero_health * 10
	start_max_hp += hero_health * 10
	hero_hp.set_start_hp(hero_hp.hp, start_max_hp)

func recovery_hp():
	if hero_hp.hp - recovery < start_max_hp:
		hero_hp.hp += recovery
		timer = 20
		print("---")
	else:
		hero_hp.hp = start_max_hp
		timer = 0
		need_heal = false

func resistance_exp(experience):
	hero_resistance_exp += experience
	if hero_resistance_exp >= 10 * hero_resistance:
		hero_resistance += 1
		set_resistance_lvl()
		hero_resistance_exp = 0

func speed_exp(experience):
	hero_speed_exp += experience
	if hero_speed_exp >= 10 * hero_speed:
		hero_speed += 1
		set_speed_lvl()
		hero_speed_exp = 0

func damage_exp(experience):
	hero_damage_exp += experience
	if hero_damage_exp >= 10 * hero_damage:
		hero_damage += 1
		set_damage_lvl()
		hero_damage_exp = 0

func heatlh_exp(experience):
	hero_health_exp += experience
	if hero_health_exp >= 10 * hero_health:
		hero_health += 1
		set_health_lvl()
		hero_health_exp = 0

func damage(damage_for_hero):
	if damage_for_hero <= hero_resistance:
		damage_for_hero = 1
	else:
		damage_for_hero -= hero_resistance
	hero_hp.hp -= damage_for_hero
	hero_hp.update_hp()
	need_heal = true
	print(need_heal)
	resistance_exp(damage_for_hero/10)
	heatlh_exp(damage_for_hero/10)
	if hero_hp.hp <= 0:
		target = false
		GameInstance.death_screen.open()

func chek_interaction(damage_from_hero):
	if aim == LOOK_PERSON:
		if !raycast_node2.collide_object:
			return
		if raycast_node2.collide_object.has_method("interaction"):
			raycast_node2.collide_object.interaction(damage_from_hero) 
	else:
		if !raycast_node.collide_object:
			return
		if raycast_node.collide_object.has_method("interaction"):
			raycast_node.collide_object.interaction(damage_from_hero) 

func save():
	var data = {
		"filename": get_filename(),
		"position": self.global_transform.origin,
		"resistance": hero_resistance,
		"speed": hero_speed,
		"damage": hero_damage,
		"health": hero_health,
		"resistance_exp": hero_resistance_exp,
		"speed_exp": hero_speed_exp,
		"damage_exp": hero_damage_exp,
		"health_exp": hero_health_exp,
		"start_hp": start_hp,
		"start_max_hp": start_max_hp,
		"power": power_damage,
		"inventory": inventory
	}
	return data

func load_from_data(data):
	self.global_transform.origin = data["position"]
	hero_resistance = data["resistance"]
	hero_speed = data["speed"]
	hero_damage = data["damage"]
	hero_health = data["health"]
	hero_resistance_exp = data["resistance_exp"]
	hero_speed_exp = data["speed_exp"]
	hero_damage_exp = data["damage_exp"]
	hero_health_exp = data["health_exp"]
	start_hp = data["start_hp"]
	start_max_hp = data["start_max_hp"]
	power_damage = data["power"]
	inventory = data["inventory"]
	set_resistance_lvl()
	set_speed_lvl()
	set_damage_lvl()
	set_health_lvl()
	hero_hp.hp = start_hp + hero_health * 10
	start_max_hp = start_hp + hero_health * 10
	hero_hp.set_start_hp(hero_hp.hp, start_max_hp)
	GameInstance.player = self
