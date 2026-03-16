extends Resource
class_name OrderData

var customer: Node = null
var food: FoodData = null

func matches_food(food_item: FoodData) -> bool:
	if food == null or food_item == null:
		return false
	return food.id == food_item.id
