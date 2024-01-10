if not engine.ActiveGamemode() == "zombiesurvival" then return end
local jit_os = {
	Windowsx86 = "win32",
	Windowsx64 = "win64",
	Linuxx86 = "linux",
	Linuxx64 = "linux64"
}

if not file.Exists( "bin/gmsv_mysqloo_"..jit_os[jit.os..jit.arch]..".dll", "lsv" ) then return end
require('mysqloo')
_G.DB_GAMEMODE = {}
local db
local PreloadClients = {}

local OptionsDB = { Host = '127.0.0.1', Database = 'test', User = 'user', Password = 'pass', Port = 3306 }
local database_remote_file = 'zombiesurvival/database_remote.txt'
local database_remote_config = file.Read(database_remote_file, 'DATA')

if database_remote_config then
	local ConfigDB = util.JSONToTable(database_remote_config)
	OptionsDB.Host = ConfigDB.Host or OptionsDB.Host
	OptionsDB.Database = ConfigDB.Database or OptionsDB.Database
	OptionsDB.User = ConfigDB.User or OptionsDB.User
	OptionsDB.Password = ConfigDB.Password or OptionsDB.Password
	OptionsDB.Port = ConfigDB.Port or OptionsDB.Port
else
	file.CreateDir('zombiesurvival')
	file.Write(database_remote_file, util.TableToJSON(OptionsDB, true))
end

db = mysqloo.connect(OptionsDB["Host"], OptionsDB["User"], OptionsDB["Password"], OptionsDB["Database"], OptionsDB["Port"])
db:connect()

function DB_GAMEMODE.SetVault( pl, row )
	pl.PointsVault = row.Points

	if row.RemortLevel then
		pl:SetZSRemortLevel(row.RemortLevel)
	end
	if row.XP then
		pl:SetZSXP(row.XP)
	end
	if row.UnlockedSkills then
		pl:SetUnlockedSkills(util.JSONToTable(row.UnlockedSkills), true)
	end
	if row.DesiredActiveSkills then
		pl:SetDesiredActiveSkills(util.JSONToTable(row.DesiredActiveSkills), true)
	end
	if row.NextSkillReset then
		pl.NextSkillReset = row.NextSkillReset
	end
	if not row.Version or row.Version < GAMEMODE.SkillTreeVersion then
		pl:SkillsReset()
		pl.SkillsRefunded = true
	end

	pl.SkillVersion = GAMEMODE.SkillTreeVersion
end

local qzs_vault = [[
	SELECT *
	FROM `zombiesurvival_vault`
	WHERE uniqueid = '%s'
]]

function DB_GAMEMODE:LoadVault( pl )
	if pl:IsBot() then return end
	local SteamID64 = pl:SteamID64()
	if PreloadClients[SteamID64] then
		DB_GAMEMODE.SetVault( pl, PreloadClients[SteamID64] )
		PreloadClients[SteamID64] = nil
		return
	end
	local q = db:query( string.format( qzs_vault, SteamID64 ) )

	function q:onSuccess(data)
		if #data > 0 then
			local row = data[1]
			if row then
				DB_GAMEMODE.SetVault( pl, row )
			end
		else
			GAMEMODE.Old_LoadVault(pl)
		end
	end
	 
	function q:onError(err, sql)
		if db:status() ~= mysqloo.DATABASE_CONNECTED then
			ErrorNoHalt("Re-connection to database server failed.")
		end
		MsgN('ZombieSurvival Vault MySQL: Query Failed: ' .. err .. ' (' .. sql .. ')')
		GAMEMODE.Old_LoadVault(pl)
		MsgN('LoadVault is File')
	end
	 
	q:start()
	q:wait()
end

function DB_GAMEMODE.PreLoadVault( SteamID64 )
	local q = db:query( string.format( qzs_vault, SteamID64 ) )

	function q:onSuccess(data)
		if #data > 0 then
			local row = data[1]
			if row then
				PreloadClients[SteamID64] = {}
				PreloadClients[SteamID64].Points = row.Points
				PreloadClients[SteamID64].RemortLevel = row.RemortLevel
				PreloadClients[SteamID64].XP = row.XP
				PreloadClients[SteamID64].UnlockedSkills = row.UnlockedSkills
				PreloadClients[SteamID64].DesiredActiveSkills = row.DesiredActiveSkills
				PreloadClients[SteamID64].NextSkillReset = row.NextSkillReset
				PreloadClients[SteamID64].Version = row.Version
			end
		end
	end
	q:start()
end

function DB_GAMEMODE:SaveVault( pl )
	if not GAMEMODE:ShouldSaveVault( pl ) then return end

	local tosave = {
		Points = math.floor(pl.PointsVault),
		XP = pl:GetZSXP(),
		RemortLevel = pl:GetZSRemortLevel(),
		DesiredActiveSkills = util.CompressBitTable(pl:GetDesiredActiveSkills()),
		UnlockedSkills = util.CompressBitTable(pl:GetUnlockedSkills()),
		Version = pl.SkillVersion or self.SkillTreeVersion
	}

	if pl.NextSkillReset and os.time() < pl.NextSkillReset then
		tosave.NextSkillReset = pl.NextSkillReset
	end

	if tosave.Points and self.PointSavingLimit > 0 and tosave.Points > self.PointSavingLimit then
		tosave.Points = self.PointSavingLimit
	end

	local filename = GAMEMODE:GetVaultFile(pl)
	file.CreateDir(string.GetPathFromFilename(filename))
	file.Write(filename, Serialize(tosave))

	local qs = [[
	INSERT INTO `zombiesurvival_vault` (uniqueid, Points, XP, RemortLevel, DesiredActiveSkills, UnlockedSkills, Version, NextSkillReset)
	VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')
	ON DUPLICATE KEY UPDATE 
		Points = VALUES(Points),
		XP = VALUES(XP),
		RemortLevel = VALUES(RemortLevel),
		DesiredActiveSkills = VALUES(DesiredActiveSkills),
		UnlockedSkills = VALUES(UnlockedSkills),
		Version = VALUES(Version),
		NextSkillReset = VALUES(NextSkillReset)
	]]
	qs = string.format(qs, pl:SteamID64(), math.floor(pl.PointsVault) or 0, pl:GetZSXP() or 0, pl:GetZSRemortLevel(), util.TableToJSON(pl:GetDesiredActiveSkills()), util.TableToJSON(pl:GetUnlockedSkills()), pl.SkillVersion or self.SkillTreeVersion or 1, tosave.NextSkillReset or 0)
	local q = db:query(qs)
	 
	function q:onError(err, sql)
		if db:status() ~= mysqloo.DATABASE_CONNECTED then
			ErrorNoHalt("Re-connection to database server failed.")
		end
		MsgN('ZombieSurvival Vault MySQL: Query Failed: ' .. err .. ' (' .. sql .. ')')
	end
	 
	q:start()
end

gameevent.Listen( "player_connect" )
hook.Add("player_connect", "PreloadVaultMySQL", function( data )
	if data.bot == 0 then
		DB_GAMEMODE.PreLoadVault( util.SteamIDTo64(data.networkid) )
	end
end)

function db:onConnectionFailed(err)
	MsgN('ZombieSurvival Vault MySQL: Connection Failed, please check your settings: ' .. err)
	--Если нет таблицы: ZombieSurvival Vault MySQL: Connection Failed, please check your settings: Access denied for user 'user'@'localhost' to database 'test'
	if GAMEMODE.Old_LoadVault then
		GAMEMODE.LoadVault = GAMEMODE.Old_LoadVault
		GAMEMODE.SaveVault = GAMEMODE.Old_SaveVault
	end
end

function db:onConnected()
	MsgN('ZombieSurvival Vault MySQL: Connected!')
	local q = db:query([[CREATE TABLE IF NOT EXISTS `zombiesurvival_vault` (
		`uniqueid` VARCHAR(30) NOT NULL COLLATE 'utf8mb4_general_ci',
		`Points` INT(32) NOT NULL DEFAULT '0',
		`XP` INT(11) NOT NULL DEFAULT '0',
		`RemortLevel` SMALLINT(6) NOT NULL DEFAULT '0',
		`DesiredActiveSkills` BLOB NOT NULL DEFAULT '[]',
		`UnlockedSkills` BLOB NOT NULL DEFAULT '[]',
		`Version` TINYINT(4) NOT NULL DEFAULT '0',
		`NextSkillReset` INT(11) NULL DEFAULT '0',
		PRIMARY KEY (`uniqueid`) USING BTREE
		); SELECT 1]])

	function q:onError(err, sql)
		MsgN( "Query errored!" )
		MsgN( "Query: ", sql )
		MsgN( "Error: ", err )
	end
	q:start()
	GAMEMODE.Old_LoadVault = GAMEMODE.LoadVault
	GAMEMODE.Old_SaveVault = GAMEMODE.SaveVault
	GAMEMODE.LoadVault = DB_GAMEMODE.LoadVault
	GAMEMODE.SaveVault = DB_GAMEMODE.SaveVault
end
