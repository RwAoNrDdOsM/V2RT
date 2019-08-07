local mod = get_mod("V2RT")
local function setting()return mod:get("CareerAbilityDRSlayer") end

mod:hook(CareerAbilityDRSlayer, "_update_priming", function (func, self)
    if setting() == "old_targetting" or setting() == "old_both" then
        local effect_id = self._effect_id
        local world = self._world
        local physics_world = World.get_data(world, "physics_world")
        local first_person_extension = self._first_person_extension
        local player_position = first_person_extension:current_position()
        local player_rotation = first_person_extension:current_rotation()
        local player_direction = Vector3.normalize(Quaternion.forward(player_rotation))
        local player_direction_flat = Vector3.normalize(Vector3.flat(player_direction))
        local cross = Vector3.cross(player_direction, Vector3.forward())
    
        if cross.x < 0 then
            player_direction = player_direction_flat or player_direction
        end
    
        local range = 10

        if talent_extension:has_talent("bardin_slayer_activated_ability_leap_range") then
            range = 15
        end

        local landing_position = nil
        local collision_filter = "filter_adept_teleport"
        local result, hit_position, _, normal = PhysicsWorld.immediate_raycast(physics_world, player_position, player_direction, range, "closest", "collision_filter", collision_filter)
    
        if result then
            landing_position = hit_position
    
            if Vector3.dot(normal, Vector3.up()) < 0.75 then
                local step_back = Vector3.normalize(hit_position - player_position) * 1
                local step_back_position = hit_position - step_back
                local new_result, new_hit_position, _, _ = PhysicsWorld.immediate_raycast(physics_world, step_back_position, Vector3.down(), range * 10, "closest", "collision_filter", collision_filter)
    
                if new_result then
                    landing_position = new_hit_position
                end
            end
        else
            landing_position = hit_position
            local new_result, new_hit_position, _, _ = PhysicsWorld.immediate_raycast(physics_world, player_position + player_direction * range, Vector3.down(), 100, "closest", "collision_filter", collision_filter)
    
            if new_result then
                landing_position = new_hit_position
            end
        end
    
        if landing_position and Vector3.length(landing_position - player_position) <= 0.1 then
            landing_position = nil
        end
    
        if effect_id and landing_position then
            World.move_particles(world, effect_id, landing_position)
        end

        return landing_position, 3 -- Removes Stop
    else
        func(self)
    end
end)

mod:hook(CareerAbilityDRSlayer, "_do_common_stuff", function (func, self)
    if setting() == "old_leap" or setting() == "old_both" then

    else
        func(self)
    end
end)