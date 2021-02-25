module TseirServer

using Genie
using Genie.Renderer.Json
using Genie.Requests
using Logging
using LoggingExtras
using LibPQ
using Tseir
using HTTP
using DelimitedFiles

mutable struct ConnectionPool

  N::Int
  in_use::Set{Int}
  available::Set{Int}
  pool::Vector{LibPQ.Connection}

  function ConnectionPool(N::Int)
    return new(N, Set{Int}(), Set{Int}(), Vector{LibPQ.Connection}())
  end

end

function get_conn!(pool::ConnectionPool)
  conn = nothing
  conn_id = nothing
  if length(pool.in_use) < pool.N
    if length(pool.available) > 0
      conn_id = pop!(pool.available)
      push!(pool.in_use, conn_id)
      conn = pool.pool[conn_id]
    else
      conn = LibPQ.Connection(TseirServer.dbpath)
      conn_id = length(pool.pool) + 1
      push!(pool.pool, conn)
      push!(pool.in_use, conn_id)
    end
  end
  return conn, conn_id
end

function return_conn!(pool::ConnectionPool, conn_id)
  if conn_id in pool.in_use
    pop!(pool.in_use, conn_id)
  end
  push!(pool.available, conn_id)
end

function main()
  Base.eval(Main, :(const UserApp = TseirServer))
  Genie.genie(; context = @__MODULE__)
  Base.eval(Main, :(const Genie = TseirServer.Genie))
  Base.eval(Main, :(using Genie))
end

end
