-- Получение текущего состояния игры
CREATE OR REPLACE FUNCTION schnapsen.get_game_state(p_access_token TEXT, p_game_id INT)
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
    v_limit INT;
    v_elapsed NUMERIC;
    v_remaining INT;
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

    -- Проверяем, что пользователь участник игры
    SELECT id INTO v_player_id
    FROM Players
    WHERE game_id = p_game_id AND login = v_login;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 403, 'message', 'Вы не участник этой игры');
    END IF;

    -- Получаем соперника
    v_opponent_id := get_opponent(v_player_id);

    -- Если игра ещё не началась
    IF v_game.status = 'открыта' THEN
        RETURN jsonb_build_object(
            'game_id', p_game_id,
            'status', 'открыта',
            'waiting_for_opponent', TRUE,
            'players', (
                SELECT jsonb_agg(jsonb_build_object(
                    'login', p.login,
                    'seat_number', p.seat_number,
                    'game_points', p.game_points
                ) ORDER BY p.seat_number)
                FROM Players p
                WHERE p.game_id = p_game_id
            )
        );
    END IF;

    -- Если игра завершена
    IF v_game.status = 'завершена' THEN
        RETURN jsonb_build_object(
            'game_id', p_game_id,
            'status', 'завершена',
            'winner', (
                SELECT p.login
                FROM Players p
                WHERE p.game_id = p_game_id
                ORDER BY p.game_points DESC
                LIMIT 1
            ),
            'final_scores', (
                SELECT jsonb_agg(jsonb_build_object(
                    'login', p.login,
                    'game_points', p.game_points
                ) ORDER BY p.game_points DESC)
                FROM Players p
                WHERE p.game_id = p_game_id
            ),
            'date_time_end', v_game.date_time_end
        );
    END IF;

    -- Получаем активный раунд
    SELECT * INTO v_round
    FROM Rounds
    WHERE game_id = p_game_id AND status = 'активный'
    ORDER BY round_number DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 500, 'message', 'Активный раунд не найден');
    END IF;

    -- Получаем текущий ход
    SELECT * INTO v_current_move
    FROM Current_Move
    WHERE round_id = v_round.id;

    -- Считаем оставшееся время
    v_limit := v_game.move_time_limit;
    v_elapsed := extract(epoch FROM (clock_timestamp() - v_current_move.date_time_start));
    v_remaining := v_limit - floor(v_elapsed)::INT;
    IF v_remaining < 0 THEN
        v_remaining := 0;
    END IF;

    -- Возвращаем полное состояние
    RETURN jsonb_build_object(
        'game_id', p_game_id,
        'status', v_game.status,
        'round_number', v_round.round_number,
        'trump_suit', v_round.trump_suit,
        'current_player_id', v_current_move.player_id,
        'my_turn', v_current_move.player_id = v_player_id,
        'remaining_seconds', v_remaining,
        'my_cards', (
            SELECT jsonb_agg(jsonb_build_object(
                'card_id', c.id,
                'rank', c.rank,
                'suit', c.suit,
                'card_value', c.card_value
            ) ORDER BY c.suit, c.rank)
            FROM Cards_on_Hands ch
            JOIN Cards c ON c.id = ch.card_id
            WHERE ch.player_id = v_player_id
        ),
        'opponent_cards_count', (
            SELECT count(*)
            FROM Cards_on_Hands ch
            WHERE ch.player_id = v_opponent_id
        ),
        'my_score', (
            SELECT round_score FROM Round_Scores WHERE player_id = v_player_id AND round_id = v_round.id
        ),
        'opponent_score', (
            SELECT round_score FROM Round_Scores WHERE player_id = v_opponent_id AND round_id = v_round.id
        ),
        'deck_cards_left', (
            SELECT count(*)
            FROM Cards
            WHERE round_id = v_round.id AND status = 'в колоде'
        ),
        'trump_card', (
            SELECT jsonb_build_object(
                'card_id', c.id,
                'rank', c.rank,
                'suit', c.suit,
                'card_value', c.card_value
            )
            FROM Cards c
            WHERE c.round_id = v_round.id AND c.status = 'козырь открыт'
            LIMIT 1
        ),
        'game_points', (
            SELECT jsonb_object_agg(p.login, p.game_points)
            FROM Players p
            WHERE p.game_id = p_game_id
        )
    );
END;
$$;