pwd() == joinpath(@__DIR__, "bin") && cd(@__DIR__)

using TseirServer
TseirServer.main()
