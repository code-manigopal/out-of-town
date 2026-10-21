class_name OOTTrafficLane
extends Node3D
## A one-way lane of traffic: a polyline of world points the cars drive along, front to back. Cars register themselves
## here so each one can find the car directly ahead of it (OOTTrafficCar). Straight or bent polylines are fine; a looped
## lane sends a car that reaches the end back to the start as soon as the start is clear.

var points: PackedVector3Array = PackedVector3Array()
var speed_limit: float = 9.0
var looped: bool = true
var cars: Array[OOTTrafficCar] = []

var _cum: PackedFloat32Array = PackedFloat32Array()


func setup(p_points: PackedVector3Array, p_speed_limit: float = 9.0, p_looped: bool = true) -> void:
	points = p_points
	speed_limit = p_speed_limit
	looped = p_looped
	_cum = PackedFloat32Array([0.0])
	for i: int in range(1, points.size()):
		_cum.append(_cum[i - 1] + points[i - 1].distance_to(points[i]))
	add_to_group(&"traffic_lane")


func length() -> float:
	return _cum[_cum.size() - 1] if _cum.size() > 0 else 0.0


func _seg(s: float) -> int:
	var i: int = 1
	while i < _cum.size() - 1 and _cum[i] < s:
		i += 1
	return i


## World position at distance s along the lane.
func pos_at(s: float) -> Vector3:
	if points.size() < 2:
		return Vector3.ZERO
	s = clampf(s, 0.0, length())
	var i: int = _seg(s)
	var seg_len: float = maxf(_cum[i] - _cum[i - 1], 0.0001)
	return points[i - 1].lerp(points[i], (s - _cum[i - 1]) / seg_len)


## Unit travel direction (horizontal) at distance s.
func dir_at(s: float) -> Vector3:
	if points.size() < 2:
		return Vector3.FORWARD
	var i: int = _seg(clampf(s, 0.0, length()))
	var d: Vector3 = points[i] - points[i - 1]
	d.y = 0.0
	return d.normalized()


func register(car: OOTTrafficCar) -> void:
	if not cars.has(car):
		cars.append(car)


## The nearest car in this lane that is further along than `car` (null if none).
func car_ahead(car: OOTTrafficCar) -> OOTTrafficCar:
	var best: OOTTrafficCar = null
	for c: OOTTrafficCar in cars:
		if c == car or c.s <= car.s:
			continue
		if best == null or c.s < best.s:
			best = c
	return best


## True when no car's rear is within `min_gap` metres of the start of the lane.
func is_start_clear(min_gap: float) -> bool:
	for c: OOTTrafficCar in cars:
		if c.s - c.length * 0.5 < min_gap and c.s > -1.0:
			return false
	return true
