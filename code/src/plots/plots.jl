#=function plot_multimode(m::AbstractModel, cloud::ParticleCloud,
                        para_key1::Symbol, para_key2::Symbol,
                        savepath::String, vint::String;
                        color_scale_limits::Tuple = Tuple{}(),
                        xlims::Tuple = Tuple{}(),
                        ylims::Tuple = Tuple{}(),
                        tickfontsize = 3pt)
    vals = DSGE.get_vals(cloud)
    para_names = map(x -> x.key, m.parameters)
    tex_names = map(x -> replace(x.tex_label, "\\" => ""), m.parameters)

    ind1 = findall(para_names .== para_key1)
    ind2 = findall(para_names .== para_key2)
    param1 = dropdims(vals[ind1, :], dims = 1)
    param2 = dropdims(vals[ind2, :], dims = 1)

    dens = kde((param1, param2))
    p = Gadfly.plot(z = Matrix{Float64}(dens.density), x = dens.x, y = dens.y,
                    Guide.xlabel(tex_names[ind1][1]), Guide.ylabel(tex_names[ind2][1]),
                #Guide.xticks(true, collect(xlims[1]:.1:xlims[2]), :horizontal),
                #Guide.yticks(true, collect(ylims[1]:.1:ylims[2]), :horizontal),
                Geom.contour)
    #=Plots.plot(kde((param1, param2)), #clims = color_scale_limits,
               xlims = xlims, ylims = ylims, tickfontsize = tickfontsize)=#

    fig_name = "kdensity_vint=$(vint)_param1=$(tex_names[ind1][1])_param2=$(tex_names[ind2][1])"
    draw(SVG("$savepath/$fig_name.svg"), p)
    #savefig("$savepath/$fig_name.pdf")
    println("Saved $savepath/$fig_name.svg")

end=#

function plot_multimode_nongadfly(m::AbstractModel, cloud::ParticleCloud,
                        para_key1::Symbol, para_key2::Symbol,
                        savepath::String, vint::String;
                        color_scale_limits::Tuple = Tuple{}(),
                        xlims::Tuple = Tuple{}(),
                        ylims::Tuple = Tuple{}(),
                        tickfontsize = 3)
    vals = DSGE.get_vals(cloud)
    para_names = map(x -> x.key, m.parameters)
    tex_names = map(x -> replace(x.tex_label, "\\" => ""), m.parameters)

    ind1 = findall(para_names .== para_key1)
    ind2 = findall(para_names .== para_key2)
    param1 = dropdims(vals[ind1, :], dims = 1)
    param2 = dropdims(vals[ind2, :], dims = 1)

    dens = kde((param1, param2))
    p = contourf(Matrix{Float64}(dens.density)', color = :heat,
                 xlabel = tex_names[ind1][1], ylabel = tex_names[ind2][1],
                 tickfontsize = tickfontsize)
    #=Plots.plot(kde((param1, param2)), #clims = color_scale_limits,
               xlims = xlims, ylims = ylims, tickfontsize = tickfontsize)=#

    fig_name = "kdensity_vint=$(vint)_param1=$(tex_names[ind1][1])_param2=$(tex_names[ind2][1])"
    savefig("$savepath/$fig_name.pdf")
    println("Saved $savepath/$fig_name.pdf")

end

# This is the new method to be called from the top level in simulation_section.jl
# so we don't need to load all of the clouds into memory
function plot_tempering_schedules(m::AbstractModel, run_date::String,
                                  T::Date, exercise_specifications::OrderedDict{Symbol},
                                  print_strings::OrderedDict{Symbol, String};
                                  est_specs_to_plot::S = 1:0,
                                  tempers::Vector{Symbol} = [:whole, :plus, :new, :old],
                                  T_star::Date = Date(1), T_star1::Date = Date(1),
                                  plotroot::String = "", file_name::String = "tempering_schedules",
                                  title::String = "Tempering Schedules",
                                  xlabel::String = "Stage n",
                                  ylabel::String = "Tempering Parameter  \\phi_n",
                                  linecolor::Symbol = :black) where S<:Union{AbstractRange, Vector}
    cloud_db = load_clouds(m, T, exercise_specifications, print_strings,
                           outputs = [:clouds, :alphas],
                           tempers = tempers, T_star = T_star, T_star1 = T_star1)
    # If there is a subset of est_specs that you want to plot
    # instead of all that are loaded by default in load_clouds.
    # Practically, since we have a range of n_mhs = 1, 3, 5
    # we only want to plot the tempering schedules for n_mh = 1 for instance.
    if !isempty(est_specs_to_plot)
        cloud_db = cloud_db[map(x -> x in est_specs_to_plot, cloud_db[!,:est_specs]), :]
    end

    # Following the assumption above, we enforce unique alphas. If you want to plot
    # the tempering schedule for non-unique alphas (say plotting α = 0.95, for n_mh = 1, 3, 5)
    # this will have to be changed
    clouds = Dict{Float64, Vector{ParticleCloud}}()
    for α in unique(cloud_db[!,:alphas])
        clouds[α] = map(y -> ParticleCloud(y, map(x->x.key, m.parameters)), cloud_db[map(x -> x == α, cloud_db[!,:alphas]), :clouds])
    end

    plot_tempering_schedules(clouds, plotroot = plotroot, file_name = file_name,
                             title = title, linecolor = linecolor,
                             xlabel = xlabel, ylabel = ylabel)
end

function plot_tempering_schedules(clouds::Dict{Float64, Vector{ParticleCloud}};
                                  plotroot::String = "",
                                  file_name::String = "tempering_schedules",
                                  title::String = "Tempering Schedules",
                                  xlabel::String = "Stage n",
                                  ylabel::String = "Tempering Parameter \\phi_n",
                                  linecolor::Symbol = :black)
    p = Plots.plot(; title = title, legend = :bottomright, xlabel = xlabel, ylabel = ylabel)
    adaptive_label_set = false
    for target in keys(clouds)
        schedule_lengths = [clouds[target][i].stage_index for i in 1:length(clouds[target])]

        median_length = floor(median(schedule_lengths))
        median_length_clouds = Base.filter(x -> x.stage_index == median_length, clouds[target])
        average_schedule = mean(map(x -> x.tempering_schedule, median_length_clouds))

        if target == 0.0
            plot!(p, average_schedule, linecolor = linecolor, linewidth = 2, label = "Fixed")
        else
            if adaptive_label_set
                plot!(p, average_schedule, linecolor = linecolor, linestyle = :dash, label = "")
            else
                plot!(p, average_schedule, linecolor = linecolor, linestyle = :dash, label = "Adaptive")
                adaptive_label_set = true
            end
        end
    end
    if !isempty(plotroot)
        filepath = plotroot*"/$(file_name).pdf"
        savefig(p, filepath)
        println("Wrote $filepath")
    else
        return p
    end
end

function drop_fixed_row(x)
    return x[map(y -> y != 0.0, x[!,:alpha]), :]
end

#=function plot_time_std_scatter(dfs::Dict{Symbol, DataFrame};
                               drop_fixed::Bool = true,
                               file_name::String = "scatter",
                               title1::String = "", title2::String = "",
                               plotroot::String = "",
                               tempers::Vector{Symbol} = [:plus, :whole],
                               xticks_time = 0:2:10,
                               yticks_time = 0:0.5:1.5,
                               xticks_schedlength = 0:2:10,
                               yticks_schedlength = 0:0.5:1.5,
                               font_size = 15pt,
                               point_size = 3pt,
                               axis_font_size = 10pt,
                               tick_font_size = 6pt,
                               n_mh = 1)

    @assert length(tempers) == 2 "For now, we only support a two temper-type smc statistics table comparison"
    df1, df2 = deepcopy(dfs[tempers[1]]), deepcopy(dfs[tempers[2]])
    df1[!, :temper_type] .= tempers[1]
    df2[!, :temper_type] .= tempers[2]

    if drop_fixed
        df1, df2 = drop_fixed_row(df1), drop_fixed_row(df2)
    end

    df_plot = vcat(df1, df2)
    df_plot = Base.filter(row -> row.nmh==n_mh, df_plot)
    num_types = size(df_plot, 1)
    text_new = (temper_phi, orientation,size) -> text(temper_phi, orientation, size)
    x_upper = 1.5*maximum(Vector(df_plot[!,:mean_min]))
    xlims = (0,x_upper)
    if length(unique(df_plot[!,:nmh]))==1
        df_plot[!,:temper_string] = map(string, repeat(["α="], num_types), df_plot[!,:alpha])
    elseif length(unique(df_plot[!,:alpha]))==1
        df_plot[!,:temper_string] = map(string, repeat(["nmh="], num_types), df_plot[!,:nmh])
    else
        df_plot[!,:temper_string] = map(string, repeat(["α="], num_types), df_plot[!,:alpha], repeat(["_nmh="], num_types), df_plot[!,:nmh])
    end

    df_plot[!,:temper_string] = map(x -> replace(x, "α=0.0" => "Fixed"), df_plot[!,:temper_string])

    if num_types < 32
        font_size = font_size * 2
        point_size = point_size * 2
    end

    p1 = Gadfly.plot(df_plot, x = :mean_min, y = :std_logmdd, label = :temper_string, Guide.title(title1),
                     Guide.ylabel("StdD log(MDD)"), Guide.xlabel("Average Runtime [Min]"),
                     Guide.xticks(ticks = collect(xticks_time)), Guide.yticks(ticks = collect(yticks_time)),
                     shape = :temper_type, color = :temper_type,
                     Geom.point, Geom.line, Geom.label,
                     Scale.color_discrete_manual("blue", "gold"),
                     Theme(point_label_font_size = font_size,
                           point_size = point_size,
                           major_label_font_size = axis_font_size,
                           minor_label_font_size = tick_font_size,
                           key_position = :none));

    if !isempty(plotroot)
        filepath = "$plotroot/$(file_name)_StdVsTime.svg"
        draw(SVG(filepath, 8inch, 6inch), p1)
        println("Saved $filepath")
    end

    p2 = Gadfly.plot(df_plot, x = :mean_schedlength, y = :std_logmdd, label = :temper_string, Guide.title(title2),
                     Guide.ylabel("StdD log(MDD)"), Guide.xlabel("Schedule Length"),
                     Guide.xticks(ticks = collect(xticks_schedlength)), Guide.yticks(ticks = collect(yticks_schedlength)),
                     shape = :temper_type, color = :temper_type,
                     Geom.point, Geom.label,
                     Theme(point_label_font_size = font_size,
                           point_size = point_size,
                           major_label_font_size = axis_font_size,
                           minor_label_font_size = tick_font_size,
                           key_position = :none));

    if !isempty(plotroot)
        filepath = "$plotroot/$(file_name)_StdVsSched.svg"
        draw(SVG(filepath, 8inch, 6inch), p2)
        println("Saved $filepath")
    end

    if isempty(plotroot)
        return p1, p2
    else
        nothing
    end
end=#

function plot_time_std_scatter_nongadfly(dfs::Dict{Symbol, DataFrame};
                               drop_fixed::Bool = true,
                               file_name::String = "scatter",
                               title1::String = "", title2::String = "",
                               plotroot::String = "",
                               tempers::Vector{Symbol} = [:plus, :whole],
                               xlims = (0,1),
                               ylims = (0,1),
                               font_size = 15,
                               tick_size = 15,
                               colors = [:blue, :orange],
                               shapes = [:circle, :square],
                               n_mh = 1)


    @assert length(tempers) == 2 "For now, we only support a two temper-type smc statistics table comparison"
    df1, df2 = deepcopy(dfs[tempers[1]]), deepcopy(dfs[tempers[2]])
    df1 = sort(df1, (:nmh, :alpha))
    df2 = sort(df2, (:nmh, :alpha))

    df1[!, :temper_type] .= tempers[1]
    df2[!, :temper_type] .= tempers[2]

    if drop_fixed
        df1, df2 = drop_fixed_row(df1), drop_fixed_row(df2)
    end

    df_plot = vcat(df1, df2)
    df_plot = Base.filter(row -> row.nmh==n_mh, df_plot)
    num_types = size(df_plot, 1)
    text_new = (temper_phi, orientation,size) -> text(temper_phi, orientation, size)
    x_upper = 1.5*maximum(Vector(df_plot[!,:mean_min]))
    xlims = (0,x_upper)
    if length(unique(df_plot[!,:nmh]))==1
        df_plot[!,:temper_string] = map(string, repeat([""], num_types), df_plot[!,:alpha])
    elseif length(unique(df_plot[!,:alpha]))==1
        df_plot[!,:temper_string] = map(string, repeat(["nmh="], num_types), df_plot[!,:nmh])
    else
        df_plot[!,:temper_string] = map(string, repeat([""], num_types), df_plot[!,:alpha], repeat(["_nmh="], num_types), df_plot[!,:nmh])
    end

    df_plot[!,:temper_string] = map(x -> replace(x, "α=0.0" => "Fixed"), df_plot[!,:temper_string])

 #=   if num_types < 32
        font_size = font_size * 2
        point_size = point_size * 2
    end=#

  ###
    annotations = Vector()
    for i=1:length(df_plot[:, :temper_string])
        push!(annotations, Plots.text(df_plot[i, :temper_string], :top, :right, font_size))
    end
    p1 = plot()
    for (i, temper) in enumerate(tempers)
        to_plot = (df_plot[:, :temper_type] .== temper)
        plot!(p1, df_plot[to_plot, :mean_min], df_plot[to_plot, :std_logmdd],
                  series_annotations = annotations,
                  color = colors[i],
                  title = title1, xlabel = "Average Runtime [Min]", ylabel = "StdD log(MDD)",
                  xlims = xlims, ylims = ylims,
              xtickfontsize=tick_size, ytickfontsize=tick_size,
              xguidefontsize=tick_size, yguidefontsize=tick_size)
        scatter!(p1, df_plot[to_plot, :mean_min], df_plot[to_plot, :std_logmdd], color = colors[i], shape = shapes[i], legend = false)
    end

####
    if !isempty(plotroot)
        filepath = "$plotroot/$(file_name)_StdVsTime.pdf"
        savefig(p1, filepath)
        println("Saved $filepath")
    end

  #=  p2 = Gadfly.plot(df_plot, x = :mean_schedlength, y = :std_logmdd, label = :temper_string, Guide.title(title2),
                     Guide.ylabel("StdD log(MDD)"), Guide.xlabel("Schedule Length"),
                     Guide.xticks(ticks = collect(xticks_schedlength)), Guide.yticks(ticks = collect(yticks_schedlength)),
                     shape = :temper_type, color = :temper_type,
                     Geom.point, Geom.label,
                     Theme(point_label_font_size = font_size,
                           point_size = point_size,
                           major_label_font_size = axis_font_size,
                           minor_label_font_size = tick_font_size,
                           key_position = :none));

    if !isempty(plotroot)
        filepath = "$plotroot/$(file_name)_StdVsSched.svg"
        draw(SVG(filepath, 8inch, 6inch), p2)
        println("Saved $filepath")
    end=#

    if isempty(plotroot)
        return p1, p2
    else
        nothing
    end
end

#=function plot_time_std_scatter(df; file_name::String = "scatter",
                               title1::String = "", title2::String = "",
                               drop_fixed::Bool = false,
                               plotroot::String = "",
                               xticks_time = 0:2:10,
                               yticks_time = 0:0.5:1.5,
                               xticks_schedlength = 0:2:10,
                               yticks_schedlength = 0:0.5:1.5,
                               font_size = 15pt,
                               point_size = 3pt,
                               axis_font_size = 10pt,
                               tick_font_size = 6pt,
                               nmhs = [1,3,5],
                               colors = ["blue"])

    #=if drop_fixed
        df = drop_fixed_row(df)
    end =#

    df_plot = deepcopy(df)
    num_types = size(df_plot, 1)
    text_new = (temper_phi, orientation,size) -> text(temper_phi, orientation, size)
    x_upper = 1.5*maximum(Vector(df_plot[!,:mean_min]))
    xlims = (0,x_upper)

    df_plot[!,:temper_string] = map(string, repeat(["α="], num_types), df_plot[!,:alpha])
    df_plot[!,:temper_string] = map(x -> replace(x, "α=0.0" => "Fixed"), df_plot[!,:temper_string])

    df_plot = Base.filter(row -> row.nmh ∈ nmhs, df_plot)
    if length(nmhs) == 1
        p1 = Gadfly.plot(layer(drop_fixed_row(df_plot), x = :mean_min, y = :std_logmdd, label = :temper_string,
                               Geom.point, Geom.label,
                               Theme(default_color = colors[1],
                                     point_label_font_size = font_size,
                                     point_size = point_size,
                                     major_label_font_size = axis_font_size,
                                     minor_label_font_size = tick_font_size)),
                         Guide.title(title1),
                         Guide.ylabel("StdD log(MDD)"), Guide.xlabel("Average Runtime [Min]"),
                         Guide.xticks(ticks = collect(xticks_time)), Guide.yticks(ticks = collect(yticks_time)));
        if !drop_fixed
            Gadfly.append!(p1.layers,
                           layer(df_plot[(df_plot[!, :alpha] .== 0.0), :], x = :mean_min, y = :std_logmdd, label = :temper_string, Geom.point, Geom.label, Theme(default_color = colors[1],
                                                                                                                 point_label_font_size = font_size,
                                                                                                                 point_size = point_size,)))
        end
    else
        p1 = Gadfly.plot(layer(drop_fixed_row(df_plot), x = :mean_min, y = :std_logmdd, label = :temper_string,
                               color=:nmh, shape = :alpha,
                               Geom.point, Geom.label,
                               Theme(point_label_font_size = font_size,
                                     point_size = point_size,
                                     major_label_font_size = axis_font_size,
                                     minor_label_font_size = tick_font_size)),
                         Scale.color_discrete_manual("blue", "black", "green", "red", "orange"),
                         Guide.colorkey(title = "N<sub>MH</sub>"),
                         Guide.shapekey(title = "α"),
                         Guide.title(title1),
                         Guide.ylabel("StdD log(MDD)"), Guide.xlabel("Average Runtime [Min]"),
                         Guide.xticks(ticks = collect(xticks_time)), Guide.yticks(ticks = collect(yticks_time)));
    end
    for i=1:length(nmhs)
        Gadfly.append!(p1.layers,
                       layer(drop_fixed_row(df_plot[(df_plot[!, :nmh] .== nmhs[i]), :]), x = :mean_min, y = :std_logmdd, Geom.line, Theme(default_color = colors[i])))
    end

    if !isempty(plotroot)
        filepath = "$plotroot/$(file_name)_StdVsTime.svg"
        draw(SVG(filepath, 8inch, 6inch), p1)
        println("Saved $filepath")
    end

    p2 = Gadfly.plot(df_plot, x = :mean_schedlength, y = :std_logmdd, label = :temper_string, Guide.title(title2),
                     Guide.ylabel("StdD log(MDD)"), Guide.xlabel("Schedule Length"),
                     Guide.xticks(ticks = collect(xticks_schedlength)), Guide.yticks(ticks = collect(yticks_schedlength)),
                     Geom.point, Geom.line, Geom.label,
                     Theme(point_label_font_size = font_size,
                           point_size = point_size,
                           major_label_font_size = axis_font_size,
                           minor_label_font_size = tick_font_size));

    if !isempty(plotroot)
        filepath = "$plotroot/$(file_name)_StdVsSched.svg"
        draw(SVG(filepath, 8inch, 6inch), p2)
        println("Saved $filepath")
    end

    if isempty(plotroot)
        return p1, p2
    else
        nothing
    end
end=#


function plot_time_std_scatter_nongadfly(df; file_name::String = "scatter",
                               title1::String = "", title2::String = "",
                               drop_fixed::Bool = false,
                               plotroot::String = "",
                               xlims::Tuple = (0,1),
                               ylims::Tuple = (0,1),
                               tick_size = 15,
                               font_size = 15,
                               nmhs = [1,3,5],
                               colors = ["blue"])

    #=if drop_fixed
        df = drop_fixed_row(df)
    end =#

    df_plot = deepcopy(df)
    num_types = size(df_plot, 1)
    text_new = (temper_phi, orientation,size) -> text(temper_phi, orientation, size)

    df_plot[!,:temper_string] = map(string, repeat([""], num_types), df_plot[!,:alpha])
    df_plot[!,:temper_string] = map(x -> replace(x, "0.0" => "Fixed"), df_plot[!,:temper_string])

    df_plot = Base.filter(row -> row.nmh ∈ nmhs, df_plot)
    if length(nmhs) == 1
        annotations = Vector()
        for i=1:length(drop_fixed_row(df_plot)[:, :temper_string])
            push!(annotations, Plots.text(drop_fixed_row(df_plot)[i, :temper_string], :top, :right, "serif", font_size))
        end
        p1 = plot(drop_fixed_row(df_plot)[:, :mean_min], drop_fixed_row(df_plot)[:, :std_logmdd],
                  series_annotations = annotations,
                  color = colors[1],
                  title = title1, xlabel = "Average Runtime [Min]", ylabel = "StdD log(MDD)",
                  xtickfontsize=tick_size, ytickfontsize=tick_size,
                  xguidefontsize=tick_size, yguidefontsize=tick_size,
                  xlims = xlims, ylims = ylims, margin=2mm)
        p1 = scatter!(drop_fixed_row(df_plot)[:, :mean_min], drop_fixed_row(df_plot)[:, :std_logmdd], color = colors[1], legend = false)

        if !drop_fixed
            annotations = Vector()
            for i=1:length(df_plot[:, :temper_string])
                push!(annotations, Plots.text(df_plot[i, :temper_string], :top, :right, "serif", font_size))
            end
            scatter!(p1, df_plot[(df_plot[!, :alpha] .== 0.0), :mean_min], df_plot[(df_plot[!, :alpha] .== 0.0), :std_logmdd], series_annotations = annotations, legend = false, color = colors[1])
        end
    else
        p1 = plot(xlims = xlims, ylims = ylims, legend = false,
                  title = title1, xlabel = "Average Runtime [Min]", ylabel = "StdD log(MDD)",
                  xtickfontsize=tick_size, ytickfontsize=tick_size,
                  xguidefontsize=tick_size, yguidefontsize=tick_size, margin=2mm)
        for (i, nmh) in enumerate(nmhs)
            to_plot = drop_fixed_row(df_plot)[!, :nmh] .== nmh
            annotations = Vector()
            for i=1:length(drop_fixed_row(df_plot)[to_plot, :temper_string])
                push!(annotations, Plots.text(drop_fixed_row(df_plot)[i, :temper_string], :top, :right, font_size))
            end
            @show annotations
            plot!(p1, drop_fixed_row(df_plot)[to_plot, :mean_min], drop_fixed_row(df_plot)[to_plot, :std_logmdd],
                      series_annotations = annotations, color = colors[i], label = "N_MH = $nmh")
            alps = drop_fixed_row(df_plot)[to_plot, :alpha]
            @show alps
                p1 = scatter!(drop_fixed_row(df_plot)[to_plot, :mean_min], drop_fixed_row(df_plot)[to_plot, :std_logmdd], color = colors[i], legend = true, label = "")
        end
    end

    if !isempty(plotroot)
        filepath = "$plotroot/$(file_name)_StdVsTime.pdf"
        savefig(p1, filepath) #draw(SVG(filepath, 8inch, 6inch), p1)
        println("Saved $filepath")
    end


    #=    else
        p1 = Gadfly.plot(layer(drop_fixed_row(df_plot), x = :mean_min, y = :std_logmdd, label = :temper_string,
                               color=:nmh, shape = :alpha,
                               Geom.point, Geom.label,
                               Theme(point_label_font_size = font_size,
                                     point_size = point_size,
                                     major_label_font_size = axis_font_size,
                                     minor_label_font_size = tick_font_size)),
                         Scale.color_discrete_manual("blue", "black", "green", "red", "orange"),
                         Guide.colorkey(title = "N<sub>MH</sub>"),
                         Guide.shapekey(title = "α"),
                         Guide.title(title1),
                         Guide.ylabel("StdD log(MDD)"), Guide.xlabel("Average Runtime [Min]"),
                         Guide.xticks(ticks = collect(xticks_time)), Guide.yticks(ticks = collect(yticks_time)));
    end
    for i=1:length(nmhs)
        Gadfly.append!(p1.layers,
                       layer(drop_fixed_row(df_plot[(df_plot[!, :nmh] .== nmhs[i]), :]), x = :mean_min, y = :std_logmdd, Geom.line, Theme(default_color = colors[i])))
    end

    if !isempty(plotroot)
        filepath = "$plotroot/$(file_name)_StdVsTime.svg"
        draw(SVG(filepath, 8inch, 6inch), p1)
        println("Saved $filepath")
    end

    p2 = Gadfly.plot(df_plot, x = :mean_schedlength, y = :std_logmdd, label = :temper_string, Guide.title(title2),
                     Guide.ylabel("StdD log(MDD)"), Guide.xlabel("Schedule Length"),
                     Guide.xticks(ticks = collect(xticks_schedlength)), Guide.yticks(ticks = collect(yticks_schedlength)),
                     Geom.point, Geom.line, Geom.label,
                     Theme(point_label_font_size = font_size,
                           point_size = point_size,
                           major_label_font_size = axis_font_size,
                           minor_label_font_size = tick_font_size));=#

   #= if !isempty(plotroot)
        filepath = "$plotroot/$(file_name)_StdVsSched.pdf"
        savefig(p1, filepath) #draw(SVG(filepath, 8inch, 6inch), p2)
        println("Saved $filepath")
    end

    if isempty(plotroot)
        return p1, p2
    else
        nothing
    end =#
end

# This function was written for an exercise that Frank Schorfheide
# recommended where we estimate AnSchorfheide 20 times in 1 year increments
# from an initial estimation up to 1991-Q4 to see the evolution of the
# first and second moments of the MDDs.
#=function plot_mdd_means_and_stds_over_time(model_name::Symbol, run_date::String,
                                           Ts::Vector{Date}, exercise_specifications::OrderedDict{Symbol},
                                           print_strings::OrderedDict{Symbol, String};
                                           plotroot::String = "",
                                           filename_means::String = "means_over_time",
                                           filename_stds::String = "stds_over_time",
                                           xticks::StepRange = 1995:5:2015,
                                           font_size = 15pt, point_size = 5pt,
                                           axis_font_size = 15pt, tick_font_size = 15pt)
    n_periods = length(Ts)

    mdds_mean = Vector{Float64}(undef, n_periods - 1)
    mdds_std = Vector{Float64}(undef, n_periods - 1)
    times_mean = Vector{Float64}(undef, n_periods - 1)

    for i in 2:n_periods
        T_star, T = Ts[i-1], Ts[i]
        df = load_smc_statistics_dfs(model_name, run_date,
                                     T, exercise_specifications, print_strings,
                                     T_star = T_star, tempers = [:new])
        mdds_mean[i-1] = df[:new][!,:mean_logmdd][1]
        mdds_std[i-1]  = df[:new][!,:std_logmdd][1]
        times_mean[i-1] = df[:new][!,:mean_min][1]
    end

    df_plot = DataFrame()
    df_plot[!,:date]  = Ts[2:end]
    df_plot[!,:datenum] = map(quarter_date_to_number, Ts[2:end])
    df_plot[!,:means] = mdds_mean
    df_plot[!,:stds]  = mdds_std

    p1 = Gadfly.plot(df_plot, x = :datenum, y = :means,
                     Guide.ylabel(""), Guide.xlabel("Year"),
                     Guide.xticks(ticks = collect(1995:5:2015)),
                     Theme(point_label_font_size = font_size,
                           point_size = point_size,
                           major_label_font_size = axis_font_size,
                           minor_label_font_size = tick_font_size))
    p2 = Gadfly.plot(df_plot, x = :datenum, y = :stds,
                     Guide.ylabel(""), Guide.xlabel("Year"),
                     Guide.xticks(ticks = collect(1995:5:2015)),
                     Theme(point_label_font_size = font_size,
                           point_size = point_size,
                           major_label_font_size = axis_font_size,
                           minor_label_font_size = tick_font_size))

    if !isempty(plotroot)
        draw(SVG("$plotroot/$filename_means.svg", 8inch, 6inch), p1)
        draw(SVG("$plotroot/$filename_stds.svg", 8inch, 6inch), p2)
    end

    return p1, p2
end=#

function plot_mdd_means_and_stds_over_time_nongadfly(model_name::Symbol, run_date::String,
                                           Ts::Vector{Date}, exercise_specifications::OrderedDict{Symbol},
                                           print_strings::OrderedDict{Symbol, String};
                                           plotroot::String = "",
                                           filename_means::String = "means_over_time",
                                           filename_stds::String = "stds_over_time",
                                           xticks::StepRange = 1995:5:2015,
                                           font_size = 15pt, point_size = 5pt,
                                           axis_font_size = 15pt, tick_font_size = 15pt)
    n_periods = length(Ts)

    mdds_mean = Vector{Float64}(undef, n_periods - 1)
    mdds_std = Vector{Float64}(undef, n_periods - 1)
    times_mean = Vector{Float64}(undef, n_periods - 1)

    for i in 2:n_periods
        T_star, T = Ts[i-1], Ts[i]
        df = load_smc_statistics_dfs(model_name, run_date,
                                     T, exercise_specifications, print_strings,
                                     T_star = T_star, tempers = [:new])
        mdds_mean[i-1] = df[:new][!,:mean_logmdd][1]
        mdds_std[i-1]  = df[:new][!,:std_logmdd][1]
        times_mean[i-1] = df[:new][!,:mean_min][1]
    end

    df_plot = DataFrame()
    df_plot[!,:date]  = Ts[2:end]
    df_plot[!,:datenum] = map(quarter_date_to_number, Ts[2:end])
    df_plot[!,:means] = mdds_mean
    df_plot[!,:stds]  = mdds_std

    p1 = scatter(df_plot[:datenum], df_plot[:means], xlabel = "Year", ylabel = "",
              xticks = collect(1995:5:2015), label = "", color = :lightblue)
    p2 = scatter(df_plot[:datenum], df_plot[:stds], xlabel = "Year", ylabel = "",
              xticks = collect(1995:5:2015), label = "", color = :lightblue)

                 #=    Guide.xticks(ticks = collect(1995:5:2015)),
                     Theme(point_label_font_size = font_size,
                           point_size = point_size,
                           major_label_font_size = axis_font_size,
                           minor_label_font_size = tick_font_size))=#
   #= p2 = Gadfly.plot(df_plot, x = :datenum, y = :stds,
                     Guide.ylabel(""), Guide.xlabel("Year"),
                     Guide.xticks(ticks = collect(1995:5:2015)),
                     Theme(point_label_font_size = font_size,
                           point_size = point_size,
                           major_label_font_size = axis_font_size,
                           minor_label_font_size = tick_font_size))=#

    if !isempty(plotroot)
        savefig(p1, "$plotroot/$filename_means.pdf")
        savefig(p2, "$plotroot/$filename_stds.pdf")
    end

    return p1, p2
end

# This function was written for an exercise that Frank Schorfheide
# recommended where we estimate AnSchorfheide 20 times in 1 year increments
# from an initial estimation up to 1991-Q4 to see the evolution of the
# first and second moments of the MDDs.
# Additionally, plots of the evolution of the individual parameter's posterior
# means were requested.
function plot_posterior_means_over_time(m_input::AbstractModel, Ts::Vector{Date},
                                        exercise_specifications::OrderedDict{Symbol},
                                        print_strings::OrderedDict{Symbol, String};
                                        plotroot::String = "",
                                        filename_addl::String = "",
                                        ub_quantile::Float64 = .9, lb_quantile::Float64 = .1)
    iteration_range = exercise_specifications[:smc_iteration]
    n_periods       = length(Ts)

    post_means_all = Matrix{Float64}(undef, n_parameters(m_input), n_periods)
    post_ub_all    = Matrix{Float64}(undef, n_parameters(m_input), n_periods)
    post_lb_all    = Matrix{Float64}(undef, n_parameters(m_input), n_periods)

    for i in 1:n_periods
        m = deepcopy(m_input)
        if i == 1
            T = Ts[i]
            m <= Setting(:data_vintage, forecast_vintage(T))
        else
            T_star, T = Ts[i-1], Ts[i]
            m <= Setting(:data_vintage, forecast_vintage(T))
            m <= Setting(:previous_data_vintage, forecast_vintage(T_star), true, "prev", "")
        end

        db = load_clouds(m, exercise_specifications, print_strings)

        # Calculate the posterior means and stds for each period
        post_means_all_for_nth_period = Matrix{Float64}(undef, n_parameters(m), length(iteration_range))
        post_ubs_all_for_nth_period   = Matrix{Float64}(undef, n_parameters(m), length(iteration_range))
        post_lbs_all_for_nth_period   = Matrix{Float64}(undef, n_parameters(m), length(iteration_range))

        for j in iteration_range
            post_means_all_for_nth_period[:, j] = mean(SMC.get_vals(db[!,:clouds][j]),
                                                       Weights(SMC.get_weights(db[!,:clouds][j])), dims = 2)
            for k in 1:n_parameters(m)
                post_ubs_all_for_nth_period[k, j]   = quantile(SMC.get_vals(db[!,:clouds][j])[k, :],
                                                               Weights(SMC.get_weights(db[!,:clouds][j])), .9)
                post_lbs_all_for_nth_period[k, j]   = quantile(SMC.get_vals(db[!,:clouds][j])[k, :],
                                                               Weights(SMC.get_weights(db[!,:clouds][j])), .1)
            end
        end

        # Take the mean of the posterior mean and std for a given period across iterations
        # to be the posterior mean/std from that period (later to be used in calculating the temporally demeaned
        # series to be plotted)
        post_means_all[:, i] = mean(post_means_all_for_nth_period, dims = 2)
        post_ub_all[:, i]    = mean(post_ubs_all_for_nth_period, dims = 2)
        post_lb_all[:, i]    = mean(post_lbs_all_for_nth_period, dims = 2)
    end

    # Demean the posterior means averaged across draws and iterations by the temporal mean (across n_periods)
    # and normalize by dividing by the posterior stds averaged across iterations
    post_means_all_temporally_demeaned = (post_means_all .- mean(post_means_all, dims = 2))./std(post_means_all, dims = 2)
    post_ubs_all_temporally_demeaned   = (post_ub_all .- mean(post_means_all, dims = 2))./std(post_means_all, dims = 2)
    post_lbs_all_temporally_demeaned   = (post_lb_all .- mean(post_means_all, dims = 2))./std(post_means_all, dims = 2)

    # Plotting setup
    free_para_inds = findall(θ -> !θ.fixed, m_input.parameters)

    # Titles and x-axis labels
    para_labels = map(θ -> θ.tex_label, m_input.parameters)
    datenums    = map(quarter_date_to_number, Ts)

    clean_string(x) = replace(replace(x, "\\"=>""), "*"=>"star")

    ps = OrderedDict{String, Plots.Plot}()
    for (i, para_label) in zip(free_para_inds, para_labels)
        # Individual plots with 90% coverage bands
        ps[clean_string(para_label)] = Plots.plot(datenums, post_means_all[i, :], label = "", linecolor = :red, linewidth = 2)
        plot!(ps[clean_string(para_label)], datenums, post_ub_all[i, :], linecolor = :black, linewidth = 2, label = "")
        plot!(ps[clean_string(para_label)], datenums, post_lb_all[i, :], linecolor = :black, linewidth = 2, label = "")
        plot!(ps[clean_string(para_label)], datenums, fill(mean(post_means_all, dims = 2)[i], length(datenums)), linecolor = :grey,
              linewidth = 2, linestyle = :dash, label = "")
    end

    if !isempty(plotroot)
        for (para, para_plot) in ps
            savefig(para_plot, "$plotroot/$(para)_mean_and_coverage_bands_$(filename_addl).pdf")
        end
    end

    return ps
end
