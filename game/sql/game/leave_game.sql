-- Выход из игры
CREATE OR REPLACE FUNCTION schnapsen.leave_game(
    p_access_token TEXT,
    p_game_id INT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp
SET timezone = 'UTC'
AS $$
DECLARE
    v_login VARCHAR(30);
    v_game Games%ROWTYPE;
    v_player_id INT;
    v_opponent_id INT;
BEGIN
    -- Проверяем токен
    v_login := check_token(p_access_token);
    
    IF v_login IS NULL THEN
        RETURN jsonb_build_object('error', 401, 'message', 'Невалидный токен');
    END IF;

    -- Получаем игру
    SELECT * INTO v_game FROM Games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 404, 'message', 'Игра не найдена');
    END IF;

    -- Получаем игрока
    SELECT id INTO v_player_id FROM Players WHERE game_id = p_game_id AND login = v_login;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 403, 'message', 'Вы не участник этой игры');
    END IF;

    -- Если игра уже завершена, просто подтверждаем выход
    IF v_game.status = 'завершена' THEN
        RETURN jsonb_build_object('message', 'Вы вышли из игры');
    END IF;

    -- Получаем соперника
    v_opponent_id := get_opponent(v_player_id);

    -- Если игра открыта (второй игрок ещё не подключился), просто удаляем игрока
    IF v_game.status = 'открыта' THEN
        DELETE FROM Players WHERE id = v_player_id;
        -- Если это был создатель, удаляем всю игру
        IF v_game.creator_login = v_login THEN
            DELETE FROM Games WHERE id = p_game_id;
            RETURN jsonb_build_object('message', 'Игра удалена');
        END IF;
        RETURN jsonb_build_object('message', 'Вы вышли из игры');
    END IF;

    -- Если игра идёт, соперник побеждает технической победой
    IF v_game.status = 'идёт игра' AND v_opponent_id IS NOT NULL THEN
        -- Завершаем активный раунд
        UPDATE Rounds 
        SET status = 'завершён', date_time_end = clock_timestamp()
        WHERE game_id = p_game_id AND status = 'активный';

        -- Соперник получает максимум поинтов для победы
        UPDATE Players
        SET game_points = v_game.points_to_win
        WHERE id = v_opponent_id;

        -- Завершаем игру
        UPDATE Games 
        SET status = 'завершена', date_time_end = clock_timestamp()
        WHERE id = p_game_id;

        RETURN jsonb_build_object(
            'message', 'Вы вышли из игры. Соперник победил технической победой.'
        );
    END IF;

    RETURN jsonb_build_object('message', 'Вы вышли из игры');
END;
$$;
