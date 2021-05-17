import JSON

route("/api/simulator", method = POST) do

  io = IOBuffer()
  t = nothing
  N = nothing

  params = jsonpayload()

  if haskey(params, "N")
    N = pop!(params, "N")
  else
    @info "Missing parameter N"
    return Genie.Renderer.respond(
      "Missing parameter N",
      400,
      Dict("Content-Type" => "text/plain; charset=utf-8", "Access-Control-Allow-Origin" => "*")
    )
  end

  allowed_keys = ["T", "i0", "end", "beta", "seed", "gamma", "model", "start", "theta", "save_interval"]

  for k in keys(params)
    if params[k] == "" 
      delete!(params, k)
    end
    if !(k in allowed_keys)
      delete!(params, k)
    end
  end

  @info "Query params: $(params)"

  conn = nothing

  try

    @info "Used connections: $(length(connection_pool.in_use))"
    conn = TseirServer.get_conn!(connection_pool)

    params_key = -1
    params_result = LibPQ.execute(conn.conn, "SELECT key, n, status FROM simulation.params WHERE params = \$1 AND n >= \$2;", (JSON.json(params), N))
    if length(params_result) > 0
        if (getindex(params_result, 1, 3) != "error")
          params_key = getindex(params_result, 1, 1)
        end
    end

    if params_key < 0
      t = @async begin
        Tseir.simulate(params, N, conn.conn, false, TseirServer.population, nothing)
        TseirServer.return_conn!(conn)
      end
      @info "Simulation triggered, sleeping 180 seconds while waiting for completion."
      timedwait(() -> istaskdone(t), 180.0)
      if istaskfailed(t)
        TseirServer.return_conn!(conn)
        @info "Simulation failed, $(t.result)"
        return Genie.Renderer.respond(
          "Simulation failed",
          500,
          Dict("Content-Type" => "text/plain; charset=utf-8", "Access-Control-Allow-Origin" => "*")
        )
      elseif istaskdone(t)
        conn = TseirServer.get_conn!(connection_pool)
        params_result = LibPQ.execute(conn.conn, "SELECT key, n, status FROM simulation.params WHERE params = \$1;", (JSON.json(params),))
        if length(params_result) > 0
            if (getindex(params_result, 1, 3) != "error")
              params_key = getindex(params_result, 1, 1)
            end
        end
      else
        @info "Simulation triggered, but not completed within 180 seconds",
        return Genie.Renderer.respond(
          "Simulation triggered, but not completed within 180 seconds",
          504,
          Dict("Content-Type" => "text/plain; charset=utf-8", "Access-Control-Allow-Origin" => "*")
        )
      end
    end

    if params_key > -1
      @info "Data for params_key $(params_key) ready for fetching."
      results = LibPQ.execute(
          conn.conn,
          """
          SELECT
            location,
            SUM(value) as value,
            EXTRACT(EPOCH FROM (\$1::TIMESTAMP + elapsed))::INTEGER AS start
          FROM simulation.results
          WHERE params_key = \$2 AND metric = 'infection'
          GROUP BY location, elapsed;
          """,
          (params["start"], params_key,)
      )
      writedlm(io, [["building_key", "floor", "layer_key", "session_interval_start", "session_count"]])
      for i in results
        writedlm(io, [[i.location, 1, "$(i.location) 1", i.start, i.value]])
      end
      TseirServer.return_conn!(conn)
      @info "Data for params_key $(params_key) retrieved succesfully."
      return Genie.Renderer.respond(
        String(take!(io)),
        200,
        Dict("Content-Type" => "text/tab-separated-values; charset=utf-8", "Access-Control-Allow-Origin" => "*")
      )
    end

  catch

    if !isnothing(conn)
      TseirServer.return_conn!(conn)
    end
    @info "Simulation failed."
    return Genie.Renderer.respond(
      "Simulation failed.",
      500,
      Dict("Content-Type" => "text/plain; charset=utf-8", "Access-Control-Allow-Origin" => "*")
    )

  end

end

route("/test") do
    response = HTTP.request(
        "POST",
        "http://localhost:8000/api/simulator",
        [("Content-Type", "application/json")],
        """
{"T": "2020-04-06 23:59:59", "i0": "138", "end": "2020-01-24 23:59:59", "beta": "3.85802469e-06", "seed": 5921, "gamma": "8.26719577e-07", "model": "sir", "start": "2020-01-13 00:00:00", "save_interval": 900, "N": 10}
        """
  )
  return Genie.Renderer.respond(
    String(response.body),
    200,
    Dict("Content-Type" => "text/tab-separated-values; charset=utf-8", "Access-Control-Allow-Origin" => "*")
  )

end

route("/hello") do
  "Welcome to Genie!"
end

route("/conn") do
  @info "Connection pool: $(connection_pool)"
  @info "Connections in use: $(length(connection_pool.in_use))"
end
