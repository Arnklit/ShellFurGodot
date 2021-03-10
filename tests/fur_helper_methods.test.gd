extends WAT.Test

const FurHelperMethods = preload("res://addons/shell_fur/fur_helper_methods.gd")

var test_array = [
	{
		name = "banana_denmark",
		hint_string = "None",
	},
	{
		name = "lemon_ireland",
		hint_string = "None",
	},
	{
		name = "banana_turkey",
		hint_string = "None",
	},
	{
		name = "orange_america",
		hint_string = "None",
	},
	{
		name = "lemon_china",
		hint_string = "None",
	},
	{
		name = "grapes_poland",
		hint_string = "None",
	},
	{
		name = "grapes_spain",
		hint_string = "None",
	},
	{
		name = "lemon_vietnam",
		hint_string = "Texture",
	},
]

func test_reorder_params() -> void:
	describe("reorder_params - When given an unordered array")
	asserts.is_false(test_array[5].name == "lemon_vietnam", "Texture hints are not ordered before")
	var ordered = FurHelperMethods.reorder_params(test_array)
	asserts.is_true(ordered[5].name == "lemon_vietnam", "But they are ordered after")


func test_last_prefix_occurence() -> void:
	describe("last_prefix_occurence - When given an array")
	asserts.is_true(FurHelperMethods.last_prefix_occurence(test_array, "banana") == 3, "Correct last index is returned")
	asserts.is_true(FurHelperMethods.last_prefix_occurence(test_array, "kiwi") == -1, "-1 is returned if search results does not exist in array")
