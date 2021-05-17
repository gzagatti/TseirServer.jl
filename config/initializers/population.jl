using Base.Filesystem
using JLD2

import Tseir
import LibPQ

population = begin
    cache_dir = abspath("$(@__DIR__)/../../cache")
    mkpath(cache_dir)
    population_cache = "$(cache_dir)/population.jld2"
    @info "Looking for cached population at $(population_cache)"
    if !isfile(population_cache)
        @info "Population cache not found, compiling population object..."
        conn = LibPQ.Connection(dbpath)
        transition_stmt = LibPQ.prepare(
            conn, """
            SELECT
                building_key,
                GREATEST(EXTRACT(EPOCH FROM d.min_time), EXTRACT(EPOCH from arrival_time)::INT),
                LEAST(EXTRACT(EPOCH FROM d.max_time), EXTRACT(EPOCH FROM departure_time)::INT)
            FROM 
              views.bdg_transition b,
              (
                SELECT MIN(day)::TIMESTAMP AS min_time, (MAX(day)::TIMESTAMP + '23:59:59') AS max_time
                FROM dimension.day WHERE pull_hours_missing = 0
              ) d
            WHERE userid_key = \$1
            AND departure_time >= d.min_time
            AND arrival_time <= d.max_time
            ORDER BY arrival_time
        """)
        contact_stmt = LibPQ.prepare(
            conn, """
            SELECT
                c.userid_key,
                c.userid_key_other,
                GREATEST(EXTRACT(EPOCH FROM d.min_time)::INT, EXTRACT(EPOCH from c.overlap_start)::INT),
                LEAST(EXTRACT(EPOCH FROM d.max_time)::INT, EXTRACT(EPOCH FROM c.overlap_end)::INT)
            FROM
              views.contact_list c,
              (
                SELECT MIN(day)::TIMESTAMP AS min_time, (MAX(day)::TIMESTAMP + '23:59:59') AS max_time
                FROM dimension.day WHERE pull_hours_missing = 0
              ) d
            WHERE c.overlap_end >= d.min_time
            AND c.overlap_start <= d.max_time
        """)
        p = Tseir.eager_init_population(transition_stmt, contact_stmt)
        close(conn)
        # we save as group as JLD2 is not able to save the contact list for
        # each individual
        jldopen(population_cache, "w") do file
            for i in p
                i_group = JLD2.Group(file, "$(i.id)")
                i_group["contact_list"] = i.contact_list
                i_group["transition_list"] = i.transition_list
            end
        end
    else
        @info "Population cache found, loading population object..."
        p = Tseir.Population()
        file = jldopen(population_cache, "r")
        for i_group in keys(file)
            i = Tseir.Individual(parse(Int32, i_group))
            i.contact_list = file[i_group]["contact_list"]
            i.transition_list = file[i_group]["transition_list"]
            push!(p, i)
        end
    end
    p
end
