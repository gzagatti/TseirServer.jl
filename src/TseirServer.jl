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

mutable struct ConnectionPool{T}

  dbpath::String
  N::Int
  in_use::Dict{Int, T}
  available::Dict{Int, T}

end

struct Connection

  conn::LibPQ.Connection
  pool::ConnectionPool
  id::Int

end

function ConnectionPool(dbpath::String, N::Int)
  return ConnectionPool{Connection}(dbpath, N, Dict{Int, Connection}(), Dict{Int, Connection}())
end


function get_conn!(pool::ConnectionPool)
  if length(pool.in_use) < pool.N
    if length(pool.available) > 0
      id = collect(keys(pool.available))[1]
      conn = pop!(pool.available, id)
      pool.in_use[id] = conn
    else
      id = length(pool.in_use) + 1
      conn = Connection(LibPQ.Connection(pool.dbpath), pool, id)
      pool.in_use[conn.id] = conn
    end
    return conn
  else
    throw(error("No connection available."))
  end
end

function return_conn!(conn::Connection)
  pool = conn.pool
  if haskey(pool.in_use, conn.id)
    pop!(pool.in_use, conn.id)
  end
  pool.available[conn.id] = conn
end

function main()
  Base.eval(Main, :(const UserApp = TseirServer))
  Genie.genie(; context = @__MODULE__)
  Base.eval(Main, :(const Genie = TseirServer.Genie))
  Base.eval(Main, :(using Genie))
end

end
