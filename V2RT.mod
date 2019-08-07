return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`V2RT` mod must be lower than Vermintide Mod Framework in your launcher's load order.")

		new_mod("V2RT", {
			mod_script       = "scripts/mods/V2RT/V2RT",
			mod_data         = "scripts/mods/V2RT/V2RT_data",
			mod_localization = "scripts/mods/V2RT/V2RT_localization",
		})
	end,
	packages = {
		"resource_packages/V2RT/V2RT",
	},
}
