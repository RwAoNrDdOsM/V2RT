local mod = get_mod("V2RT")

return {
	name = "V2RT",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id    = "CareerAbilityDRSlayer",
				type          = "dropdown",
				default_value = false,
				options = {	
					{text = "disabled",   value = false, show_widgets = {}},
					{text = "old_leap",   value = "old_leap", show_widgets = {}},			
					{text = "old_targetting",   value = "old_targetting", show_widgets = {}},
					{text = "old_both", value = "old_both", show_widgets = {}},
				},
			},
			{
				setting_id    = "CareerAbilityBWAdept",
				type          = "dropdown",
				default_value = false,
				options = {	
					{text = "disabled",   value = false, show_widgets = {}},
					{text = "old_blink",   value = "old_blink", show_widgets = {}},			
					{text = "old_targetting",   value = "old_targetting", show_widgets = {}},
					{text = "old_both", value = "old_both", show_widgets = {}},
				},
			},
		},
	},
}
