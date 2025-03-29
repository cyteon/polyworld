extends Node

const recipes = {
	"wood_axe": {
		"name": "Wooden Axe",
# incase we have recipes that gives diffrent stuff like name: Plastic (oil), gives plastic but diffrent recipe
		"gives": "Wooden Axe",
		"scene": "res://scenes/items/wood_axe.tscn",
		"amount": 1,
		"icon": "res://assets/images/items/wooden_axe.png",
		"requires": {
			"wood": {
				"amount": 8,
				"label": "Wood"
			},
		}
	},
	"wood_pickaxe": {
		"name": "Wooden Pickaxe",
		"gives": "Wood Pickaxe",
		"scene": "res://scenes/items/wood_pickaxe.tscn",
		"amount": 1,
		"icon": "res://assets/images/items/wooden_pickaxe.png",
		"requires": {
			"wood": {
				"amount": 8,
				"label": "Wood"
			},
		}
	}
}
