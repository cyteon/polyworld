extends Node

func set_owner_recursive(owner_: Node, node: Node):
	for c in node.get_children():
		c.owner = owner_
		set_owner_recursive(owner_, c)
