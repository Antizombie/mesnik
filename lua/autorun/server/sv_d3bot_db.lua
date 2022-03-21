local status, error = pcall( function() require('mysqloo') end )
if not status or not D3bot then print( "No load mysqloo." ) return end
local db
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

function savedbnav(GetMap)
	local query = db:query(string.format("SELECT * FROM `d3botNuv` WHERE map = '%s'", GetMap)) -- In mysqloo 9 a query can be started before the database is connected
	function query:onSuccess(data)
		local row = data[1]
		local navmesh = file.Read(D3bot.MapNavMeshPath, "DATA")
		local timefile = file.Time(D3bot.MapNavMeshPath, "DATA")
		if row == nil or (row["date_unix"] < timefile) and row["nav"] ~= navmesh then
			local savetobase = db:query(string.format("INSERT INTO `d3botNuv` (map, date_unix, nav) VALUES ('%s', '%s', '%s') ON DUPLICATE KEY UPDATE date_unix = VALUES(date_unix), nav = VALUES(nav)", GetMap, timefile, navmesh))
			function savetobase:onSuccess(data)
				print( "Save nav map to db!" )
			end
			function savetobase:onError(err)
				print("An error occured while executing the query: " .. err)
			end
			savetobase:start()
		elseif row["nav"] == navmesh then print("Nav db = file") return
		else
			file.Write( D3bot.MapNavMeshPath, row["nav"] )
			print("Save nav map to file!")
			D3bot.LoadMapNavMesh()
			D3bot.UpdateMapNavMeshUiSubscribers()
			print("Reload nav map!")
		end
	end

	function query:onError(err)
		print("An error occured while executing the query: " .. err)
	end

	query:start()

end

local D3bot_SaveMapNavMesh = D3bot.SaveMapNavMesh

function D3bot.SaveMapNavMesh()
	D3bot_SaveMapNavMesh()

	local savetobase = db:query(string.format("INSERT INTO `d3botNuv` (map, date_unix, nav) VALUES ('%s', '%s', '%s') ON DUPLICATE KEY UPDATE date_unix = VALUES(date_unix), nav = VALUES(nav)", game.GetMap(), file.Time(D3bot.MapNavMeshPath, "DATA"), file.Read(D3bot.MapNavMeshPath, "DATA")))
	function savetobase:onSuccess(data)
		print( "Save nav map to db!" )
	end
	function savetobase:onError(err)
		print("An error occured while executing the query: " .. err)
	end
	savetobase:start()
	
end

function db:onConnected()
	print('stas MySQL: Connected!')
	local q = db:query("CREATE TABLE IF NOT EXISTS `d3botNuv` ( map varchar(225) NOT NULL PRIMARY KEY, date_unix INT UNSIGNED NOT NULL, nav BLOB NOT NULL ); SELECT 1")
	function q:onSuccess(data)
		print( "Query successful!" )
		savedbnav(game.GetMap())
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
