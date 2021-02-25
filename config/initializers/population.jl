const population = @async begin
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
    p
end
