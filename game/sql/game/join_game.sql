-- Подключение к игровой комнате
CREATE OR REPLACE FUNCTION schnapsen.join_game(p_access_token TEXT, p_game_id INT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp
SET timezone = 'UTC'
AS $$
DECLARE
    v_login VARCHAR(30);
    v_game Games%ROWTYPE;
    v_players_count INT;
    v_player_id INT;
BEGIN
    -- Проверяем токен
    v_login := check_token(p_access_token);
    
    IF v_login IS NULL THEN
        RETURN jsonb_build_object('error', 401, 'message', 'Невалидный токен');
    END IF;

    -- Получаем игру
    SELECT * INTO v_game
    FROM Games
    WHERE id = p_game_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 404, 'message', 'Игра не найдена');
    END IF;

    -- Проверяем статус игры
    IF v_game.status <> 'открыта' THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Игра уже началась или завершена');
    END IF;

    -- Проверяем, что игрок ещё не в игре
    IF EXISTS (
        SELECT 1 FROM Players
        WHERE game_id = p_game_id AND login = v_login
    ) THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Вы уже в этой игре');
    END IF;

    -- Проверяем количество игроков
    SELECT count(*) INTO v_players_count
    FROM Players
    WHERE game_id = p_game_id;

    IF v_players_count >= 2 THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Игра полностью заполнена');
    END IF;

    -- Проверяем, что игрок не в другой активной игре
    IF EXISTS (
        SELECT 1 FROM Players p
        JOIN Games g ON g.id = p.game_id
        WHERE p.login = v_login AND g.status IN ('открыта', 'идёт игра')
    ) THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Вы уже участвуете в другой игре');
    END IF;

    -- Добавляем игрока на место 2
    INSERT INTO Players(game_id, login, seat_number, game_points)
    VALUES (p_game_id, v_login, 2, 0)
    RETURNING id INTO v_player_id;

    -- Автоматически стартуем раунд, так как второй игрок подключился
    RETURN start_round(p_game_id);
END;
$$;
