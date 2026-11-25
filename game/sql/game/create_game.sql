-- Создание новой игровой комнаты
CREATE OR REPLACE FUNCTION schnapsen.create_game(
    p_access_token TEXT,
    p_move_time_limit INT,
    p_points_to_win INT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp
SET timezone = 'UTC'
AS $$
DECLARE
    v_login VARCHAR(30);
    v_game_id INT;
    v_player_id INT;
BEGIN
    -- Проверяем токен
    v_login := check_token(p_access_token);
    
    IF v_login IS NULL THEN
        RETURN jsonb_build_object('error', 401, 'message', 'Невалидный токен');
    END IF;

    -- Валидация параметров
    IF p_move_time_limit IS NULL OR p_move_time_limit <= 0 THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Время хода должно быть больше нуля');
    END IF;

    IF p_points_to_win IS NULL OR p_points_to_win <= 0 OR p_points_to_win > 7 THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Очков до победы должно быть от 1 до 7');
    END IF;

    -- Проверяем, что игрок не в другой активной игре
    IF EXISTS (
        SELECT 1 FROM Players p
        JOIN Games g ON g.id = p.game_id
        WHERE p.login = v_login AND g.status IN ('открыта', 'идёт игра')
    ) THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Вы уже участвуете в другой игре');
    END IF;

    -- Создаём игру
    INSERT INTO Games(creator_login, move_time_limit, points_to_win, status)
    VALUES (v_login, p_move_time_limit, p_points_to_win, 'открыта')
    RETURNING id INTO v_game_id;

    -- Добавляем создателя как первого игрока
    INSERT INTO Players(game_id, login, seat_number, game_points)
    VALUES (v_game_id, v_login, 1, 0)
    RETURNING id INTO v_player_id;

    -- Возвращаем данные созданной игры
    RETURN jsonb_build_object(
        'game_id', v_game_id,
        'move_time_limit', p_move_time_limit,
        'points_to_win', p_points_to_win,
        'status', 'открыта',
        'creator_login', v_login,
        'date_time_creation', (SELECT date_time_creation FROM Games WHERE id = v_game_id)
    );
END;
$$;
