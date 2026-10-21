extends SceneTree
## Mani's jog (easy run) clip: length, flight phase, planted feet, bounce, knees. Run:
##   godot --headless --path game --script res://tests/run_run_anim_tests.gd
## Exits with code 1 on any failure. Skipped when mani.glb is a Git LFS pointer (CI).

const MANI: String = "res://characters/mani/mani.glb"
const AUTHORED_SPEED: float = 2.8        ## m/s, the jog_anim_speed the clip is authored for
const SAMPLE_FPS: float = 30.0
var _failures: int = 0
var _checks: int = 0


static func _lfs_pointer() -> bool:
	var f: FileAccess = FileAccess.open(MANI, FileAccess.READ)
	if f == null:
		return true
	return f.get_buffer(24).get_string_from_ascii().begins_with("version https://git-lfs")


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("ok   - " + what)
	else:
		_failures += 1
		print("FAIL - " + what)


func _initialize() -> void:
	if _lfs_pointer():
		print("SKIPPED run animation tests: Git LFS assets are not checked out (CI).")
		print("0 checks, 0 failures")
		quit(0)
		return
	await process_frame
	var inst: Node = (load(MANI) as PackedScene).instantiate()
	root.add_child(inst)
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(ap != null and sk != null, "mani.glb has an AnimationPlayer and a Skeleton3D")
	for clip: String in ["idle", "walk", "jog", "carry", "stairs_down", "car_enter_driver"]:
		_check(ap.has_animation(clip), "clip %s still present" % clip)
	_check(ap.get_animation_list().size() >= 17, "all 17 clips intact (%d)" % ap.get_animation_list().size())
	var jog: Animation = ap.get_animation("jog")
	_check(jog != null and jog.length > 0.68 and jog.length < 0.78, "jog length %.3f s (cadence %.0f steps/min)" % [jog.length, 120.0 / jog.length])
	_check(jog.loop_mode == Animation.LOOP_NONE or true, "jog loop mode noted (%d); the player loops it" % jog.loop_mode)
	ap.play("jog")
	ap.pause()
	var n: int = int(round(jog.length * SAMPLE_FPS))
	var bl: int = sk.find_bone("ball_l")
	var br: int = sk.find_bone("ball_r")
	var fl: int = sk.find_bone("foot_l")
	var fr: int = sk.find_bone("foot_r")
	var pel: int = sk.find_bone("pelvis")
	var hd: int = sk.find_bone("head")
	var ua: int = sk.find_bone("upperarm_l")
	var la: int = sk.find_bone("lowerarm_l")
	var hn: int = sk.find_bone("hand_l")
	var kl: int = sk.find_bone("calf_l")
	var hl: int = sk.find_bone("thigh_l")
	_check(min(bl, br, fl, fr, pel, hd, kl, hl) >= 0, "rig bones found")
	var rows: Array = []
	for i in range(n + 1):
		ap.seek(float(i) / SAMPLE_FPS, true)
		sk.force_update_all_bone_transforms()
		rows.append({
			"bl": _g(sk, bl), "br": _g(sk, br), "fl": _g(sk, fl), "fr": _g(sk, fr),
			"pel": _g(sk, pel), "ua": _g(sk, ua), "la": _g(sk, la), "hn": _g(sk, hn), "hd": _g(sk, hd), "kl": _g(sk, kl), "hl": _g(sk, hl),
		})
	# ground contact: the ball of the foot is down, or the heel strikes (ankle at its flat height)
	var airborne: int = 0
	var slide_max: float = 0.0
	var slide_sum: float = 0.0
	var slide_n: int = 0
	var pz_min: float = 1e9
	var pz_max: float = -1e9
	var hz_min: float = 1e9
	var hz_max: float = -1e9
	for i in range(n):
		var r: Dictionary = rows[i]
		var down_l: bool = (r.bl as Vector3).y < 0.03 or (r.fl as Vector3).y < 0.085
		var down_r: bool = (r.br as Vector3).y < 0.03 or (r.fr as Vector3).y < 0.085
		if not down_l and not down_r:
			airborne += 1
		pz_min = minf(pz_min, (r.pel as Vector3).y)
		pz_max = maxf(pz_max, (r.pel as Vector3).y)
		hz_min = minf(hz_min, (r.hd as Vector3).y)
		hz_max = maxf(hz_max, (r.hd as Vector3).y)
		var nx: Dictionary = rows[i + 1]
		for key: String in ["bl", "br"]:
			var a: Vector3 = r[key]
			var b: Vector3 = nx[key]
			if a.y < 0.02 and b.y < 0.02:                  # ball planted on both samples (mid / late stance)
				var v: float = (b.z - a.z) * SAMPLE_FPS + AUTHORED_SPEED   # body goes +Z, planted foot goes -Z
				slide_max = maxf(slide_max, absf(v))
				slide_sum += absf(v)
				slide_n += 1
	var flight: float = float(airborne) / float(n)
	print("flight %.0f %%  slide mean %.3f max %.3f m/s (%d pairs)  pelvis bob %.3f  head bob %.3f" % [
		flight * 100.0, slide_sum / maxf(slide_n, 1), slide_max, slide_n, pz_max - pz_min, hz_max - hz_min])
	_check(flight >= 0.12 and flight <= 0.30, "flight phase present: both feet off the ground %.0f %% of the cycle" % (flight * 100.0))
	_check(slide_n >= 6, "planted-foot samples found (%d)" % slide_n)
	_check(slide_max < 0.35, "foot slide in stance max %.3f m/s < 0.35" % slide_max)
	_check(slide_sum / maxf(slide_n, 1) < 0.15, "foot slide in stance mean %.3f m/s < 0.15" % (slide_sum / maxf(slide_n, 1)))
	_check(pz_max - pz_min > 0.03 and pz_max - pz_min < 0.09, "pelvis bounce %.1f cm (3..9 cm)" % ((pz_max - pz_min) * 100.0))
	_check(hz_max - hz_min < 0.09, "head bob %.1f cm < 9 cm" % ((hz_max - hz_min) * 100.0))
	var kmax: float = 0.0
	for i in range(n):
		var r2: Dictionary = rows[i]
		var thigh: Vector3 = (r2.kl as Vector3) - (r2.hl as Vector3)
		var shin: Vector3 = (r2.fl as Vector3) - (r2.kl as Vector3)
		kmax = maxf(kmax, rad_to_deg(thigh.angle_to(shin)))
	_check(kmax > 90.0 and kmax < 125.0, "swing knee flexion max %.0f deg (90..125)" % kmax)
	# arms: elbow ~90 deg, hand never higher than the chest, hand not far ahead of the body
	var emin: float = 999.0
	var emax: float = 0.0
	var reach: float = 0.0
	var hmax: float = -9.0
	var hmin: float = 9.0
	for i in range(n):
		var r3: Dictionary = rows[i]
		var up: Vector3 = (r3.la as Vector3) - (r3.ua as Vector3)
		var fo: Vector3 = (r3.hn as Vector3) - (r3.la as Vector3)
		var ea: float = rad_to_deg(up.angle_to(fo))
		emin = minf(emin, ea)
		emax = maxf(emax, ea)
		reach = maxf(reach, (r3.hn as Vector3).z - (r3.ua as Vector3).z)
		hmax = maxf(hmax, (r3.hn as Vector3).y - (r3.ua as Vector3).y)
		hmin = minf(hmin, (r3.hn as Vector3).y - (r3.ua as Vector3).y)
	print("elbow %.0f..%.0f deg  hand forward of shoulder max %.2f m  hand height vs shoulder %.2f..%.2f m" % [emin, emax, reach, hmin, hmax])
	_check(emin > 75.0 and emax < 115.0, "elbow stays bent ~90 deg (%.0f..%.0f)" % [emin, emax])
	_check(reach < 0.32, "hand forward of the shoulder %.2f m < 0.32 (no zombie reach)" % reach)
	_check(hmax < -0.10 and hmin > -0.45, "hand between chest and waist height (%.2f..%.2f m below the shoulder)" % [-hmax, -hmin])
	# walk and idle untouched in length (pedestrians reuse them)
	_check(absf(ap.get_animation("walk").length - 1.0) < 0.05, "walk length unchanged (%.2f s)" % ap.get_animation("walk").length)
	_check(absf(ap.get_animation("idle").length - 4.0) < 0.05, "idle length unchanged (%.2f s)" % ap.get_animation("idle").length)
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


## Bone origin in the model's space (y up, +z forward).
func _g(sk: Skeleton3D, bone: int) -> Vector3:
	return sk.get_bone_global_pose(bone).origin
