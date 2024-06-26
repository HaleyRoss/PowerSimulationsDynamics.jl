function get_init_values_for_comparison(sim::Simulation)
    bus_size = PSID.get_bus_count(sim.inputs)
    system = PSID.get_system(sim)
    V_R = Vector{Float64}(undef, bus_size)
    V_I = Vector{Float64}(undef, bus_size)
    Vm = Vector{Float64}(undef, bus_size)
    θ = Vector{Float64}(undef, bus_size)
    for bus in PSY.get_components(PSY.Bus, system)
        bus_n = PSY.get_number(bus)
        bus_ix = PSID.get_lookup(sim.inputs)[bus_n]
        V_R[bus_ix] = sim.x0_init[bus_ix]
        V_I[bus_ix] = sim.x0_init[bus_ix + bus_size]
        Vm[bus_ix] = sqrt(V_R[bus_ix]^2 + V_I[bus_ix]^2)
        θ[bus_ix] = angle(V_R[bus_ix] + V_I[bus_ix] * 1im)
    end
    results =
        Dict{String, Vector{Float64}}("V_R" => V_R, "V_I" => V_I, "Vm" => Vm, "θ" => θ)
    for device in PSID.get_dynamic_injectors(sim.inputs)
        states = PSY.get_states(device)
        name = PSY.get_name(device)
        global_index = PSID.get_global_index(device)
        x0_device = Vector{Float64}(undef, length(states))
        for (i, s) in enumerate(states)
            x0_device[i] = sim.x0_init[global_index[s]]
        end
        results[name] = x0_device
    end
    for br in PSID.get_dynamic_branches(sim.inputs)
        states = PSY.get_states(br)
        name = PSY.get_name(br)
        global_index = PSID.get_global_index(br)
        x0_br = Vector{Float64}(undef, length(states))
        for (i, s) in enumerate(states)
            x0_br[i] = sim.x0_init[global_index[s]]
        end
        printed_name = "Line " * name
        results[printed_name] = x0_br
    end

    return results
end

function clean_extra_timestep!(t::Vector{Float64}, δ::Vector{Float64})
    idx = unique(i -> t[i], 1:length(t))
    return t[idx], δ[idx]
end

function get_csv_delta(str::AbstractString)
    M = readdlm(str, ',')
    return clean_extra_timestep!(M[:, 1], M[:, 2])
end

function get_csv_data(str::AbstractString)
    M_ = readdlm(str, ',')
    if !(diff(M_[1:10, 1])[1] > 0.0)
        @warn "First column can't be identified as time, skipping clean up step"
        return M_
    end
    idx = unique(i -> M_[i, 1], 1:length(M_[:, 1]))
    return M_[idx, :]
end

function _compute_total_load_parameters(load::PSY.StandardLoad)
    # Constant Power Data
    constant_active_power = PSY.get_constant_active_power(load)
    constant_reactive_power = PSY.get_constant_reactive_power(load)
    max_constant_active_power = PSY.get_max_constant_active_power(load)
    max_constant_reactive_power = PSY.get_max_constant_reactive_power(load)
    # Constant Current Data
    current_active_power = PSY.get_current_active_power(load)
    current_reactive_power = PSY.get_current_reactive_power(load)
    max_current_active_power = PSY.get_max_current_active_power(load)
    max_current_reactive_power = PSY.get_max_current_reactive_power(load)
    # Constant Admittance Data
    impedance_active_power = PSY.get_impedance_active_power(load)
    impedance_reactive_power = PSY.get_impedance_reactive_power(load)
    max_impedance_active_power = PSY.get_max_impedance_active_power(load)
    max_impedance_reactive_power = PSY.get_max_impedance_reactive_power(load)
    # Total Load Calculations
    active_power = constant_active_power + current_active_power + impedance_active_power
    reactive_power =
        constant_reactive_power + current_reactive_power + impedance_reactive_power
    max_active_power =
        max_constant_active_power + max_current_active_power + max_impedance_active_power
    max_reactive_power =
        max_constant_reactive_power +
        max_current_reactive_power +
        max_impedance_reactive_power
    return active_power, reactive_power, max_active_power, max_reactive_power
end

function transform_load_to_constant_impedance(load::PSY.StandardLoad)
    # Total Load Calculations
    active_power, reactive_power, max_active_power, max_reactive_power =
        _compute_total_load_parameters(load)
    # Set Impedance Power
    PSY.set_impedance_active_power!(load, active_power)
    PSY.set_impedance_reactive_power!(load, reactive_power)
    PSY.set_max_impedance_active_power!(load, max_active_power)
    PSY.set_max_impedance_reactive_power!(load, max_reactive_power)
    # Set everything else to zero
    PSY.set_constant_active_power!(load, 0.0)
    PSY.set_constant_reactive_power!(load, 0.0)
    PSY.set_max_constant_active_power!(load, 0.0)
    PSY.set_max_constant_reactive_power!(load, 0.0)
    PSY.set_current_active_power!(load, 0.0)
    PSY.set_current_reactive_power!(load, 0.0)
    PSY.set_max_current_active_power!(load, 0.0)
    PSY.set_max_current_reactive_power!(load, 0.0)
    return
end

function transform_load_to_constant_current(load::PSY.StandardLoad)
    # Total Load Calculations
    active_power, reactive_power, max_active_power, max_reactive_power =
        _compute_total_load_parameters(load)
    # Set Impedance Power
    PSY.set_current_active_power!(load, active_power)
    PSY.set_current_reactive_power!(load, reactive_power)
    PSY.set_max_current_active_power!(load, max_active_power)
    PSY.set_max_current_reactive_power!(load, max_reactive_power)
    # Set everything else to zero
    PSY.set_constant_active_power!(load, 0.0)
    PSY.set_constant_reactive_power!(load, 0.0)
    PSY.set_max_constant_active_power!(load, 0.0)
    PSY.set_max_constant_reactive_power!(load, 0.0)
    PSY.set_impedance_active_power!(load, 0.0)
    PSY.set_impedance_reactive_power!(load, 0.0)
    PSY.set_max_impedance_active_power!(load, 0.0)
    PSY.set_max_impedance_reactive_power!(load, 0.0)
    return
end

function transform_load_to_constant_power(load::PSY.StandardLoad)
    # Total Load Calculations
    active_power, reactive_power, max_active_power, max_reactive_power =
        _compute_total_load_parameters(load)
    # Set Impedance Power
    PSY.set_constant_active_power!(load, active_power)
    PSY.set_constant_reactive_power!(load, reactive_power)
    PSY.set_max_constant_active_power!(load, max_active_power)
    PSY.set_max_constant_reactive_power!(load, max_reactive_power)
    # Set everything else to zero
    PSY.set_current_active_power!(load, 0.0)
    PSY.set_current_reactive_power!(load, 0.0)
    PSY.set_max_current_active_power!(load, 0.0)
    PSY.set_max_current_reactive_power!(load, 0.0)
    PSY.set_impedance_active_power!(load, 0.0)
    PSY.set_impedance_reactive_power!(load, 0.0)
    PSY.set_max_impedance_active_power!(load, 0.0)
    PSY.set_max_impedance_reactive_power!(load, 0.0)
    return
end
