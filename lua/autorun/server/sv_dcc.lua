local JoinMessages = {
	[[Это %s! Восславьте солнце! \[T]/]],
	'Добро пожаловать, %s. Оставь своё оружие у двери.',
	'Дикий %s появился.',
	'Эй, друзья! %s уже здесь!',
	'Мы ждали вас, %s...',
	'%s садится в боевой автобус.',
	'%s запрыгивает на сервер, как кенгуру!',
	'%s присоединяется к серверу! Это суперэффективно!',
	'Добро пожаловать, %s. Располагайся и слушай.',
	'%s присоединяется к серверу — вжух!',
	'Добро пожаловать, %s. Мы ждали тебя ( ͡° ͜ʖ ͡°)',
	'Привет, а не %s ли вы ищете?',
	'О боже мой! %s здесь.',
	'Вжух. Приземляется %s.',
	'Игроку %s приготовиться',
	'Держитесь. %s уже на сервере.',
	'Это птица! Это самолёт! Да нет, это просто %s.',
	'В одиночку идти опасно, %s идёт с нами!',
	'%s присоединился. Нужно больше зиккуратов.',
	'Розовые розы, фиалки голубые, «%s идёт на сервер», — сказали часовые.',
	'А вот и %s... Вечеринка окончена.',
	'Эй! Слушайте! %s уже с нами!',
	'Добро пожаловать, %s. Надеемся, ты к нам не без пиццы!',
	'%s присоединяется... но это не точно.',
	'%s здесь, как и было предсказано.',
	'%s прибывает. Вот это силища. Пожалуйста, понерфите.',
	'%s спавнится на сервере.',
	'%s присоединяется. Все сделайте вид, что заняты!',
	'%s здесь, чтобы жевать жвачку и выдавать в табло. Жвачка дожёвана, %s готовится ко второму пункту программы...',
	'Это птица! Это самолёт! Да нет, это просто %s.',
	'%s присоединяется к вашей пати.',
	'%s проскальзывает на сервер.',
	'%s к нам на огонёк. Подержите моё пиво.',
	'Где же %s? На сервере!',
	'%s подключается. Постойте немного и послушайте!',
	'%s присоединяется. Меня могут похилить?',
	'%s в сердце со мной, за %s мы все стеной!',
	'%s уже с нами!',
	'Вызов брошен — появляется %s!'
}

if not sql.TableExists('authorized_players') then
	sql.Query("CREATE TABLE authorized_players( SteamID NUMBER , name TEXT )")
end

hook.Add( 'PlayerDisconnected', 'dcc', function( player )
	rzs.NotifyAll( player:Nick() .. ' покинул нас.', 2 )
end )

hook.Add( 'PlayerInitialSpawn', 'dcc', function( player )
	if player:IsBot() then return end
	local info = {
		[ 'nick' ] = player:Nick(),
		[ 'sid64' ] = player:SteamID64()
	}

	local fileFormat = string.Replace( player:SteamID(), ':', '_' )

	if file.Exists( 'authorized_players/' .. fileFormat .. '.txt', 'DATA' ) then
		sql.Query( "INSERT INTO authorized_players ( SteamID, name ) VALUES( " .. sql.SQLStr( info['sid64'] ) .. ", '" .. info[ 'nick' ] .. "' )" )
		file.Delete( 'authorized_players/' .. fileFormat .. '.txt')
	end

	local data = sql.Query( "SELECT * FROM authorized_players WHERE SteamID = " .. sql.SQLStr( info['sid64'] ) .. ";")
	if ( data ) then
		rzs.NotifyAll( string.format( JoinMessages[ math.random( 1, #JoinMessages ) ], info[ 'nick' ], info[ 'nick' ] ), 3 )
	else
		rzs.NotifyAll( 'У нас новенький! Это ' .. info[ 'nick' ], 4 )
		sql.Query( "INSERT INTO authorized_players ( SteamID, name ) VALUES( " .. sql.SQLStr( info['sid64'] ) .. ", '" .. info[ 'nick' ] .. "' )" )
	end
end )