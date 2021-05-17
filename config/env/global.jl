dbpath = "postgres://$(ENV["WIFI_USER"]):$(ENV["WIFI_PW"])@$(ENV["WIFI_HOST"]):$(ENV["WIFI_PORT"])/wifidb"
const connection_pool = TseirServer.ConnectionPool(dbpath, 5)
