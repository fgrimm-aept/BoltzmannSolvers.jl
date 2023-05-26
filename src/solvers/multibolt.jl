struct MultiBolt <: Solver end


function default_names(::MultiBolt, names=Dict{String,Symbol}();
    replace=false)
    default_names = Dict{String,Symbol}(
        [
        "E_N" => :reduced_field,
        # "RedDiff((ms)^-1)" => :reduced_diffusion_coef,
        "muN_FLUX" => :reduced_mobility,
        # "DriftVelocity(ms^-1)" => :drift_velocity,
        "alpha_eff_N" => :reduced_townsend_alpha_coef,
        # "RedAtt(m^2)" => :reduced_attachment_coef,
        # "RedDiffE(eV(ms)^-1)" => :reduced_energy_diffusion_coef,
        # "RedMobE(eV(msV)^-1)" => :reduced_energy_mobility,
        "avg_en" => :mean_energy,
        # "CharE(eV)" => :characteristic_energy,
        # "EleTemp(eV)" => :electron_temperature,
    ])
    if replace == true
        return names
    else
        return merge(default_names, names)

    end
end


function load_dataframe(::MultiBolt, source;
    names=default_names(MultiBolt()),
    replace_strings=[]
)
    swarm_param_files = [
        "muN_FLUX.txt",
        "avg_en.txt",
        "alpha_eff_N.txt",
    ] .|> x -> joinpath(source, x)

    df = innerjoin(
        CSV.read.(swarm_param_files, DataFrame,
            comment="#",
            delim="\t",
        )...,
        on="E_N"
    )

    rates_directory = joinpath(source, "PerGas")
    gas_list = readdir(rates_directory)
    for gas in gas_list
        rate_filenames = readdir(joinpath(rates_directory, gas))
        df = map(rate_filenames) do x
            file = joinpath(rates_directory, gas, x)
            line = filter(startswith("# Process:"), readlines(file))[1]
            lhs, dir, rhs, type = match(r"(?::\s*)(.*?)(->|<->)(.*?),\s*(.*)$", line)
            if dir != "->"
                error("Only '->' implemented.")
            end
            reaction_name = replace("$(lhs)-->$(rhs)", "E" => "e", " " => "", replace_strings...)
            if startswith(x, "alpha") 
                reaction_name = "alpha($reaction_name)"
            end
            CSV.read(file, DataFrame,
                comment="#",
                delim="\t",
                skipto=7,
                header=["E_N", reaction_name]
            )
        end |> x -> innerjoin(df, x..., on="E_N")
    end

    return rename!(df, names)
end

