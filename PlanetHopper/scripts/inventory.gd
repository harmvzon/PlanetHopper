extends Node

enum Item { BIOMASS, RAW_ORE, PYRESTONE, CRYSITE, FERRITE }

var _stock: Dictionary = {
	Item.BIOMASS:   0,
	Item.RAW_ORE:   0,
	Item.PYRESTONE: 0,
	Item.CRYSITE:   0,
	Item.FERRITE:   0,
}
var star_energy: int = 0

signal inventory_changed(resource: Item, new_amount: int)
signal star_energy_changed(new_amount: int)

func add(resource: Item, amount: int = 1) -> void:
	_stock[resource] += amount
	inventory_changed.emit(resource, _stock[resource])
	print("Invertory: ", Item.keys()[resource], "=", _stock[resource])

func add_star_energy(amount: int = 1) -> void:
	star_energy += amount
	star_energy_changed.emit(star_energy)

func get_amount(resource: Item) -> int:
	return _stock[resource]

func clear_on_death() -> void:
	for key in _stock:
		_stock[key] = 0
		inventory_changed.emit(key, 0)
		
