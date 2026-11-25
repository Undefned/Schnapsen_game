-- Объявление шнапса (у игрока >= 66 очков)
CREATE OR REPLACE FUNCTION schnapsen.declare_schnapsen(
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
    v_round Rounds%ROWTYPE;
    v_current_move Current_Move%ROWTYPE;
    v_my_score INT;
    v_opponent_score INT;
    v_points_awarded INT;
    v_my_points INT;
    v_opp_points INT;
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

    v_opponent_id := get_opponent(v_player_id);

    -- Получаем активный раунд
    SELECT * INTO v_round FROM Rounds WHERE game_id = p_game_id AND status = 'активный';
    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 404, 'message', 'Активный раунд не найден');
    END IF;

    -- Получаем текущий ход
    SELECT * INTO v_current_move FROM Current_Move WHERE round_id = v_round.id;

    -- Шнапс можно объявить в любой момент (даже не в свой ход), если есть взятка
    -- Проверяем, что у игрока есть хотя бы одна взятка
    IF NOT EXISTS (
        SELECT 1 FROM Tricks WHERE round_id = v_round.id AND winner_player_id = v_player_id
    ) THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Шнапс можно объявлять только после взятия хотя бы одной взятки');
    END IF;

    -- Проверяем, что шнапс ещё не был объявлен
    SELECT schnapsen_declared INTO v_my_score
    FROM Round_Scores
    WHERE player_id = v_player_id AND round_id = v_round.id;

    IF v_my_score THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Вы уже объявили шнапс в этом раунде');
    END IF;

    -- Получаем текущие очки игроков
    SELECT round_score INTO v_my_score
    FROM Round_Scores
    WHERE player_id = v_player_id AND round_id = v_round.id;

    SELECT round_score INTO v_opponent_score
    FROM Round_Scores
    WHERE player_id = v_opponent_id AND round_id = v_round.id;

    -- Проверяем, набрал ли игрок >= 66 очков
    IF v_my_score >= 66 THEN
        -- Шнапс правильный! Игрок победил в раунде
        UPDATE Round_Scores
        SET schnapsen_declared = TRUE
        WHERE player_id = v_player_id AND round_id = v_round.id;

        -- Завершаем раунд
        UPDATE Rounds SET status = 'завершён', date_time_end = clock_timestamp() WHERE id = v_round.id;
        DELETE FROM Current_Move WHERE round_id = v_round.id;

        -- Начисляем поинты: 3 если соперник набрал 0, 2 если < 33, 1 если >= 33
        IF v_opponent_score = 0 THEN
            v_points_awarded := 3;
        ELSIF v_opponent_score < 33 THEN
            v_points_awarded := 2;
        ELSE
            v_points_awarded := 1;
        END IF;

        -- Записываем победителя раунда
        INSERT INTO Round_Winners(round_id, winner_player_id, points_awarded)
        VALUES (v_round.id, v_player_id, v_points_awarded);

        -- Начисляем поинты в общий счёт
        UPDATE Players
        SET game_points = game_points + v_points_awarded
        WHERE id = v_player_id;

        -- Проверяем, достиг ли победитель points_to_win
        SELECT game_points INTO v_my_points FROM Players WHERE id = v_player_id;

        IF v_my_points >= v_game.points_to_win THEN
            -- Игра завершена
            UPDATE Games SET status = 'завершена', date_time_end = clock_timestamp() WHERE id = p_game_id;
            RETURN jsonb_build_object(
                'status', 'game_finished',
                'schnapsen_success', TRUE,
                'points_awarded', v_points_awarded,
                'message', 'Шнапс! Игра завершена, вы победили!'
            );
        ELSE
            -- Начинаем новый раунд
            RETURN jsonb_build_object(
                'status', 'round_finished',
                'schnapsen_success', TRUE,
                'points_awarded', v_points_awarded,
                'new_round', start_round(p_game_id),
                'message', 'Шнапс! Вы выиграли раунд.'
            );
        END IF;
    ELSE
        -- Шнапс неправильный! Соперник получает поинт
        UPDATE Round_Scores
        SET schnapsen_declared = TRUE
        WHERE player_id = v_player_id AND round_id = v_round.id;

        -- Завершаем раунд
        UPDATE Rounds SET status = 'завершён', date_time_end = clock_timestamp() WHERE id = v_round.id;
        DELETE FROM Current_Move WHERE round_id = v_round.id;

        -- Соперник получает 1 поинт за ложный шнапс
        v_points_awarded := 1;

        INSERT INTO Round_Winners(round_id, winner_player_id, points_awarded)
        VALUES (v_round.id, v_opponent_id, v_points_awarded);

        UPDATE Players
        SET game_points = game_points + v_points_awarded
        WHERE id = v_opponent_id;

        -- Проверяем, достиг ли соперник points_to_win
        SELECT game_points INTO v_opp_points FROM Players WHERE id = v_opponent_id;

        IF v_opp_points >= v_game.points_to_win THEN
            -- Игра завершена
            UPDATE Games SET status = 'завершена', date_time_end = clock_timestamp() WHERE id = p_game_id;
            RETURN jsonb_build_object(
                'status', 'game_finished',
                'schnapsen_success', FALSE,
                'points_awarded', 0,
                'message', 'Ложный шнапс! У вас ' || v_my_score || ' очков (нужно >= 66). Соперник выиграл игру.'
            );
        ELSE
            -- Начинаем новый раунд
            RETURN jsonb_build_object(
                'status', 'round_finished',
                'schnapsen_success', FALSE,
                'points_awarded', 0,
                'new_round', start_round(p_game_id),
                'message', 'Ложный шнапс! У вас ' || v_my_score || ' очков (нужно >= 66). Соперник получил 1 поинт.'
            );
        END IF;
    END IF;
END;
$$;
