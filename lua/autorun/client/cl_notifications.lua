local colors = {
    [ 1 ] = Color( 255, 220, 100 ), -- Yellow
    [ 2 ] = Color( 214, 74, 65 ), -- Red
    [ 3 ] = Color( 43, 123, 167 ), -- Blue
    [ 4 ] = Color( 16, 140, 73 ), -- Green
    [ 5 ] = Color( 43, 123, 167 ), -- Blue
}

function notification.AddLegacy( msg, type )
    if type == 5 then
        local heckStart, heckEnd = string.find( msg, ":" )
        if heckStart then
            chat.AddText( colors[ type ] or Color( 43, 123, 167 ), '[RZS-Discord] ', Color( 255, 220, 100 ), string.sub( msg, 1, heckStart ), Color( 255, 255, 255 ), string.sub( msg, heckEnd + 1 ) )
        end
        return
    end
    chat.AddText( colors[ type ] or Color( 255, 220, 100 ), '[RZS] ', Color( 250, 250, 200 ), msg )
    surface.PlaySound 'buttons/lightswitch2.wav'
end

net.Receive( 'Notification', function()
    local msg = net.ReadString()
    local type = net.ReadUInt( 3 )

    notification.AddLegacy( msg, type )
end )

hook.Add( 'ChatText', 'Notifications', function( index, name, text, type )
    if type == 'joinleave' then
        return true
    end
end )
