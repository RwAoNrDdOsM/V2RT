local mod = get_mod("V2RT")

--Pre 2.0
CareerAbilityBWAdept.old_ballistic_raycast = function(self, physics_world, max_steps, max_time, position, velocity, gravity, collision_filter)
	local time_step = max_time / max_steps
	local radius = 0.85
	local max_hits = 10

	for i = 1, max_steps, 1 do
		local new_position = position + velocity * time_step
		local result = PhysicsWorld.linear_sphere_sweep(physics_world, position, new_position, radius, max_hits, "collision_filter", collision_filter, "report_initial_overlap")

		if result then
			local num_hits = #result

			for j = 1, num_hits, 1 do
				local hit = result[j]
				local hit_actor = hit.actor
				local hit_position = hit.position
				local hit_normal = hit.normal
				local hit_distance = hit.distance
				local hit_unit = Actor.unit(hit_actor)

				if hit_unit ~= self.owner_unit then
					return true, hit_position, hit_distance, hit_normal, hit_actor
				end
			end
		end

		velocity = velocity + gravity * time_step
		position = new_position
	end

	return false, position
end

local function old_landing_postion_valid(start_pos, end_pos, data, t)
	local valid_pos = false
	local astar = data.astar

	if astar then
		local done = GwNavAStar.processing_finished(astar)

		if done then

			local path_found = GwNavAStar.path_found(astar)

			if path_found then

				valid_pos = true
			end

			GwNavAStar.destroy(astar)

			data.astar = nil
			data.astar_timer = t + 0.01
		end
	elseif data.astar_timer < t then
		local nav_world = Managers.state.entity:system("ai_system"):nav_world()
		local new_astar = GwNavAStar.create(nav_world)
		local box_half_width = data.box_half_width
		local traverse_logic = Managers.state.bot_nav_transition:traverse_logic()

		GwNavAStar.start_with_propagation_box(new_astar, nav_world, start_pos, end_pos, box_half_width, traverse_logic)

		data.astar = new_astar
		data.astar_timer = t + 0.01
	end

	return valid_pos
end

--2.0
local function new_ballistic_raycast(physics_world, max_steps, max_time, position, velocity, gravity, collision_filter)
	local time_step = max_time / max_steps

	for i = 1, max_steps, 1 do
		local new_position = position + velocity * time_step
		local delta = new_position - position
		local direction = Vector3.normalize(delta)
		local distance = Vector3.length(delta)
		local result, hit_position, _, normal, _ = PhysicsWorld.immediate_raycast(physics_world, position, direction, distance, "closest", "collision_filter", collision_filter)

		if result then
			if Vector3.dot(normal, Vector3.up()) < 0.95 then
				local step_back_distance = 1.5
				local step_back = Vector3.normalize(hit_position - position) * step_back_distance
				local step_back_position = hit_position - step_back
				local new_result, new_hit_position, _, _, _ = PhysicsWorld.immediate_raycast(physics_world, step_back_position, Vector3.down(), 10, "closest", "collision_filter", collision_filter)

				if new_result then
					return true, new_hit_position
				end
			end

			return true, hit_position
		end

		velocity = velocity + gravity * time_step
		position = new_position
	end

	return false, position
end

local EPSILON = 0.01
local SEGMENT_LIST = {}

local function get_leap_data(physics_world, own_position, target_position)
	local flat_distance = Vector3.length(Vector3.flat(own_position - target_position))

	if flat_distance < EPSILON then
		return Vector3.zero(), 0, own_position
	end

	local gravity = PlayerUnitMovementSettings.gravity_acceleration
	local jump_angle = math.degrees_to_radians(45)
	local sections = 8
	local target_velocity = Vector3.zero()
	local acceptable_accuracy = 0.1
	local jump_speed, hit_pos = WeaponHelper.speed_to_hit_moving_target(own_position, target_position, jump_angle, target_velocity, gravity, acceptable_accuracy)
	local in_los, velocity, _ = WeaponHelper.test_angled_trajectory(physics_world, own_position, target_position, -gravity, jump_speed, jump_angle, SEGMENT_LIST, sections, nil, true)

	fassert(in_los, "no landing location for leap")

	local direction = Vector3.normalize(velocity)

	return direction, jump_speed, hit_pos
end

mod:hook(CareerAbilityBWAdept, "_update_priming", function (func, self, dt, t)
    -- Pre 2.0 Targetting
    if mod:get("CareerAbilityBWAdept") == "old_targetting" or mod:get("CareerAbilityBWAdept") == "old_both" then
        local effect_id = self._effect_id
        local owner_unit = self._owner_unit
        local world = self._world
        local game = Managers.state.network:game()
        local network_manager = Managers.state.network
        local physics_world = World.get_data(world, "physics_world")
        local unit_id = network_manager:unit_game_object_id(owner_unit)
        local player_position = GameSession.game_object_field(game, unit_id, "aim_position")
        local up = Vector3(0, 0, 1)
        local player_rotation = Quaternion.look(GameSession.game_object_field(game, unit_id, "aim_direction"), up)
        local max_steps = 10
        local max_time = 0.9
        local speed = 12
        local angle = 0
        local velocity = Quaternion.forward(Quaternion.multiply(player_rotation, Quaternion(Vector3.right(), angle))) * speed
        local gravity = Vector3(0, 0, -2)
        local collision_filter = "filter_adept_teleport"
        local result, hit_position, _, normal = self:old_ballistic_raycast(physics_world, max_steps, max_time, player_position, velocity, gravity, collision_filter, false)

        if result and Vector3.dot(normal, Vector3.up()) < 0.75 then
            local step_back = Vector3.normalize(hit_position - player_position) * 1.5
            local step_back_position = hit_position - step_back
            local new_result, new_hit_position, _, _ = PhysicsWorld.immediate_raycast(physics_world, step_back_position, Vector3.down(), 100, "closest", "collision_filter", collision_filter)

            if new_result then
                hit_position = new_hit_position
            end
        end

        local nav_world = Managers.state.entity:system("ai_system"):nav_world()
        local new_hit_position = get_target_pos_on_navmesh(hit_position, nav_world)
        hit_position = new_hit_position or hit_position
        local data = self.old_astar_data

        if not data then
            data = {
                astar_timer = 0,
                box_half_width = 20
            }
            self.old_astar_data = data
        end

        local valid_pos = old_landing_postion_valid(player_position, hit_position, data, t)

        if valid_pos then
            if effect_id then
                World.move_particles(world, effect_id, hit_position)
            end

            if self._last_valid_position then
                self._last_valid_position:store(hit_position)
            else
                self._last_valid_position = Vector3Box(hit_position)
            end
        end
        return
    end
    func(self, dt, t)
end)

mod:hook(CareerAbilityBWAdept, "_run_ability", function(func, self)
    -- Pre 2.0 Blink
    if mod:get("CareerAbilityBWAdept") == "old_blink" or mod:get("CareerAbilityBWAdept") == "old_both" then
        self:_stop_priming()

        local end_position = self._last_valid_landing_position and self._last_valid_landing_position:unbox()

        if not end_position then
            return
        end

        local owner_unit = self._owner_unit
        local is_server = self._is_server
        local local_player = self._local_player
        local bot_player = self._bot_player
        local network_manager = self._network_manager
        local career_extension = self._career_extension
        local talent_extension = ScriptUnit.extension(owner_unit, "talent_system")

        if local_player or (is_server and bot_player) then
            local start_pos = POSITION_LOOKUP[owner_unit]
            local nav_world = Managers.state.entity:system("ai_system"):nav_world()
            local projected_start_pos = LocomotionUtils.pos_on_mesh(nav_world, start_pos, 2, 30)

            if projected_start_pos then
                local damage_wave_template_name = "sienna_adept_ability_trail"

                if talent_extension:has_talent("sienna_adept_ability_trail_increased_duration") then
                    damage_wave_template_name = "sienna_adept_ability_trail_increased_duration"
                end

                local damage_wave_template_id = NetworkLookup.damage_wave_templates[damage_wave_template_name]
                local invalid_game_object_id = NetworkConstants.invalid_game_object_id

                network_manager.network_transmit:send_rpc_server("rpc_create_damage_wave", invalid_game_object_id, projected_start_pos, end_position, damage_wave_template_id)
            end
        end

        if local_player then
            local first_person_extension = self._first_person_extension

            first_person_extension:animation_event("battle_wizard_active_ability_blink")

            MOOD_BLACKBOARD.skill_adept = true

            career_extension:set_state("sienna_activate_adept")
        end

        local locomotion_extension = self._locomotion_extension

        locomotion_extension:teleport_to(end_position)

        local position = end_position
        local rotation = Unit.local_rotation(owner_unit, 0)
        local explosion_template = "sienna_adept_activated_ability_end_stagger"
        local scale = 1
        local career_power_level = career_extension:get_career_power_level()
        local area_damage_system = Managers.state.entity:system("area_damage_system")

        area_damage_system:create_explosion(owner_unit, position, rotation, explosion_template, scale, "career_ability", career_power_level, false)

        if talent_extension:has_talent("sienna_adept_ability_trail_double") then
            if local_player or (is_server and bot_player) then
                local buff_extension = self._buff_extension

                if buff_extension and buff_extension:has_buff_type("sienna_adept_ability_trail_double") then
                    career_extension:start_activated_ability_cooldown()

                    local buff_id = self._double_ability_buff_id

                    if buff_id then
                        buff_extension:remove_buff(buff_id)
                    end
                elseif buff_extension then
                    self._double_ability_buff_id = buff_extension:add_buff("sienna_adept_ability_trail_double")
                end
            end
        else
            career_extension:start_activated_ability_cooldown()
        end

        self:_play_vo()
        return
    end
    func(self)
end)