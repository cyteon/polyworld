extends Node

const recipes = {
	"wood_axe": {
		"name": "Wooden Axe",
		"gives": "Wood Axe",
		"scene": "res://scenes/items/wood_axe.tscn",
		"amount": 1,
		"icon": "res://assets/placeholders/placeholder_64.png",
		"requires": {
			"wood": {
				"amount": 8,
				"label": "Wood"
			},
		}
	}
}
