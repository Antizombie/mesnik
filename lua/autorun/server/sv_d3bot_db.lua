local status, error = pcall( function() require('mysqloo') end )
if not status or not D3bot then print( "No load mysqloo." ) return end
local MesnikDB = {}
local db = MesnikDB.db
--d3bot to BD module
file.CreateDir('mesnik')

local DefaultOptions = {
	Host = '127.0.0.1',
	Database = 'test',
	User = 'user',
	Password = 'pass',
	Port = 3306,
}

local DefaultConfigString = util.TableToJSON(DefaultOptions, true)

if not file.Exists('mesnik/stasBD.txt', 'DATA') then
	file.Write('mesnik/stasBD.txt', DefaultConfigString)
else
	local read = file.Read('mesnik/stasBD.txt', 'DATA')
	local parse = util.JSONToTable(read)
	if not parse then
		file.Write('mesnik/stasBD.txt', DefaultConfigString)
	else
		DefaultConfigString = read
		DefaultOptions = parse
	end
end

db = mysqloo.connect(DefaultOptions["Host"], DefaultOptions["User"], DefaultOptions["Password"], DefaultOptions["Database"], DefaultOptions["Port"])

function MesnikDB.GetNavMapDB(Map)
	local query = db:query(string.format("SELECT * FROM `d3botNuv` WHERE map = '%s'", Map)) -- In mysqloo 9 a query can be started before the database is connected
	function query:onSuccess(data)
		local row = data[1]
		if row == nil then
			print("No NavMesh map is DB!")
			MesnikDB.SynchronizationMap()
		else
			MesnikDB.SynchronizationMap(row["map"],row["nav"],row["date_unix"])
		end
	end

	function query:onError(err)
		print("An error occured while executing the query: " .. err)
	end

	query:start()
end

function MesnikDB.SaveNavMaptoDB(Map,NavMesh,TimeFile)
	local savetobase = db:query(string.format("INSERT INTO `d3botNuv` (map, date_unix, nav) VALUES ('%s', '%s', '%s') ON DUPLICATE KEY UPDATE date_unix = VALUES(date_unix), nav = VALUES(nav)", Map, TimeFile, NavMesh))
	function savetobase:onSuccess(data)
		print( "Save nav map to db!" )
	end
	function savetobase:onError(err)
		print("An error occured while executing the query: " .. err)
	end
	savetobase:start()
end

function MesnikDB.SaveNavMaptoFile(Map,NavMeshfile,NavMesh)
	file.Write( NavMeshfile, NavMesh )
	print("Save nav map to file!")
	if Map == game.GetMap() then
		D3bot.LoadMapNavMesh()
		D3bot.UpdateMapNavMeshUiSubscribers()
		print("Reload nav map!")
	end
end

function MesnikDB.SynchronizationMap(Map,NavMesh,TimeBD)
	local Map = Map or game.GetMap()
	local filelocal = {}
	filelocal.NavMeshfile = string.gsub(D3bot.MapNavMeshPath, "([%w_]+).txt$", Map..".txt")
	filelocal.NavMesh = file.Read(filelocal.NavMeshfile, "DATA")
	if filelocal.NavMesh == nil and NavMesh == nil then print("No NavMesh local file and no BD") return
	elseif filelocal.NavMesh == nil and NavMesh ~= nil then MesnikDB.SaveNavMaptoFile(Map, filelocal.NavMeshfile, NavMesh) return
	elseif filelocal.NavMesh ~= nil and NavMesh == nil then MesnikDB.SaveNavMaptoDB(Map, filelocal.NavMesh, file.Time(filelocal.NavMeshfile, "DATA")) return
	else
		filelocal.Time = file.Time(filelocal.NavMeshfile, "DATA")
		if TimeBD == filelocal.Time then print("NavMesh Time local file == BD") return
		elseif NavMesh == filelocal.NavMesh then print("NavMesh local file == BD") return
		elseif TimeBD > filelocal.Time then
			MesnikDB.SaveNavMaptoFile(Map, filelocal.NavMeshfile, NavMesh) return
		elseif TimeBD < filelocal.Time then
			MesnikDB.SaveNavMaptoDB(Map, filelocal.NavMesh, filelocal.Time) return
		end	
	end
end

local D3bot_SaveMapNavMesh = D3bot.SaveMapNavMesh

function D3bot.SaveMapNavMesh()
	D3bot_SaveMapNavMesh()
	MesnikDB.SaveNavMaptoDB(game.GetMap(), file.Read(D3bot.MapNavMeshPath, "DATA"), file.Time(D3bot.MapNavMeshPath, "DATA"))
end

function db:onConnected()
	print('stas MySQL: Connected!')
	local q = db:query("CREATE TABLE IF NOT EXISTS `d3botNuv` ( map varchar(225) NOT NULL PRIMARY KEY, date_unix INT UNSIGNED NOT NULL, nav MEDIUMTEXT NOT NULL ); SELECT 1")
	function q:onSuccess(data)
		print( "Query successful!" )
		MesnikDB.GetNavMapDB(game.GetMap())
    end
     
    function q:onError(err, sql)
        print( "Query errored!" )
        print( "Query:", sql )
        print( "Error:", err )
    end
    q:start()
end

function db:onConnectionFailed(err)
	MsgN('stas MySQL: Connection Failed, please check your settings: ' .. err)
end

db:connect()
