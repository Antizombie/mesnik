rzs = rzs or {}

util.AddNetworkString 'Notification'

function rzs.Notify( player, msg, type )
	net.Start 'Notification'
		net.WriteString( msg )
		net.WriteUInt( type, 3 )
    net.Send( player )
end

function rzs.NotifyAll( msg, type )
	net.Start 'Notification'
		net.WriteString( msg )
		net.WriteUInt( type, 3 )
    net.Broadcast()
end


local function say_discord_mesnik(sender, command, arguments, argStr)
    if sender:IsPlayer() then
        return
    else
        rzs.NotifyAll( argStr, 5 )
    end
end

concommand.Add( "sdm", say_discord_mesnik)

if game.GetMap() == "zs_minecraft_oasis_v3" then

	local ActHurt = ActHurt or 1

	hook.Add( "EntityTakeDamage", "DamageHurtzs_minecraft_oasis_v3", function( target, dmginfo )
		if ( target:IsPlayer() and dmginfo:GetAttacker() == ents.GetByIndex( 425 )) and target:Team() == 4 then
			dmginfo:ScaleDamage( ActHurt ) -- Damage is now half of what you would normally take.
			ActHurt = ActHurt + 0.2
		elseif ( target:IsPlayer() and dmginfo:GetAttacker() == ents.GetByIndex( 425 )) and target:Team() == 3 then
			dmginfo:ScaleDamage( 0 )
		end

	end )

end

hook.Add( 'PlayerInitialSpawn', 'BanCheckFamilySharing', function( ply )
    if not ply:IsBot() then
        local steamid = ply:SteamID()
        local steamidOWNER = util.SteamIDFrom64( ply:OwnerSteamID64() )
        local banData = ULib.bans[ steamidOWNER ]
        if banData then ULib.ban( ply, banData.time, "Обход бана через FamilySharing "..steamid) end
    end
end)

hook.Add('ULib.ban', 'BanFamilySharing', function( ply, time, reason, admin )
    print('BanFamilySharing', ply, time, reason, admin)
    if not ply:IsBot() then
        if ply:OwnerSteamID64() ~= ply:SteamID64() then
            if not time or type( time ) ~= "number" then
                time = 0
            end
            if ply:IsListenServerHost() then
                return
            end
            ULib.addBan( ply:OwnerSteamID64(), time, reason, ply:Name(), admin )
        end
    end
end)