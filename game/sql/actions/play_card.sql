-- Сыграть карту (основное игровое действие)
CREATE OR REPLACE FUNCTION schnapsen.play_card(
    p_access_token TEXT,
    p_game_id INT,
    p_card_id INT
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
    v_round Rounds%ROWTYPE;
    v_current_move Current_Move%ROWTYPE;
    v_card Cards%ROWTYPE;
    v_first_card_id INT;
    v_second_card_id INT;
    v_winner_card_id INT;
    v_winner_player_id INT;
    v_trick_number INT;
    v_trick_points INT;
    v_opponent_id INT;
    v_deck_empty BOOLEAN;
    v_my_score INT;
    v_opp_score INT;
    v_my_points INT;
    v_opp_points INT;
    v_points_awarded INT;
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

    -- Получаем активный раунд
    SELECT * INTO v_round FROM Rounds WHERE game_id = p_game_id AND status = 'активный';
    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 404, 'message', 'Активный раунд не найден');
    END IF;

    -- Получаем текущий ход
    SELECT * INTO v_current_move FROM Current_Move WHERE round_id = v_round.id;

    -- Проверяем, что сейчас ход этого игрока
    IF v_current_move.player_id <> v_player_id THEN
        RETURN jsonb_build_object('error', 403, 'message', 'Сейчас не ваш ход');
    END IF;

    -- Проверяем, что карта принадлежит игроку
    IF NOT EXISTS (
        SELECT 1 FROM Cards_on_Hands WHERE player_id = v_player_id AND card_id = p_card_id
    ) THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Эта карта не на ваших руках');
    END IF;

    -- Получаем карту
    SELECT * INTO v_card FROM Cards WHERE id = p_card_id;

    -- Получаем соперника
    v_opponent_id := get_opponent(v_player_id);

    -- Проверяем, есть ли уже первая карта на столе
    SELECT card_id INTO v_first_card_id
    FROM Moves
    WHERE round_id = v_round.id
        AND move_number = (SELECT COALESCE(MAX(move_number), 0) FROM Moves WHERE round_id = v_round.id)
        AND player_id <> v_player_id;

    -- Если это первая карта в взятке
    IF v_first_card_id IS NULL THEN
        -- Записываем ход
        INSERT INTO Moves(round_id, player_id, card_id, move_number)
        VALUES (v_round.id, v_player_id, p_card_id, 
            (SELECT COALESCE(MAX(move_number), 0) + 1 FROM Moves WHERE round_id = v_round.id));

        -- Убираем карту с руки
        DELETE FROM Cards_on_Hands WHERE player_id = v_player_id AND card_id = p_card_id;
        UPDATE Cards SET status = 'разыграна' WHERE id = p_card_id;

        -- Передаём ход сопернику
        UPDATE Current_Move
        SET player_id = v_opponent_id, date_time_start = clock_timestamp()
        WHERE round_id = v_round.id;

        RETURN jsonb_build_object('status', 'waiting_for_opponent', 'card_played', p_card_id);
    END IF;

    -- Это вторая карта — завершаем взятку
    v_second_card_id := p_card_id;

    -- ВАЛИДАЦИЯ ПРАВИЛ: проверяем, что игрок отбивается правильно
    DECLARE
        v_first_card Cards%ROWTYPE;
        v_has_trump BOOLEAN;
        v_has_suit BOOLEAN;
    BEGIN
        -- Получаем первую карту
        SELECT * INTO v_first_card FROM Cards WHERE id = v_first_card_id;

        -- Проверяем, есть ли у игрока козыри на руках
        SELECT EXISTS (
            SELECT 1 FROM Cards_on_Hands ch
            JOIN Cards c ON c.id = ch.card_id
            WHERE ch.player_id = v_player_id AND c.suit = v_round.trump_suit
        ) INTO v_has_trump;

        -- Проверяем, есть ли у игрока карты масти первой карты
        SELECT EXISTS (
            SELECT 1 FROM Cards_on_Hands ch
            JOIN Cards c ON c.id = ch.card_id
            WHERE ch.player_id = v_player_id AND c.suit = v_first_card.suit
        ) INTO v_has_suit;

        -- Если первая карта не козырь, а у игрока есть козыри, но он не кроет козырем
        IF v_first_card.suit <> v_round.trump_suit 
           AND v_has_trump 
           AND v_card.suit <> v_round.trump_suit 
           AND NOT v_has_suit THEN
            -- Игрок должен был покрыть козырем
            RETURN jsonb_build_object('error', 400, 'message', 'Нужно отбиваться козырем, если нет карт нужной масти');
        END IF;

        -- Если первая карта козырь, а игрок не отбивается козырем (хотя есть)
        IF v_first_card.suit = v_round.trump_suit 
           AND v_has_trump 
           AND v_card.suit <> v_round.trump_suit THEN
            RETURN jsonb_build_object('error', 400, 'message', 'На козырь нужно отвечать козырем, если он есть');
        END IF;
    END;

    -- Записываем ход
    INSERT INTO Moves(round_id, player_id, card_id, move_number)
    VALUES (v_round.id, v_player_id, v_second_card_id,
        (SELECT COALESCE(MAX(move_number), 0) + 1 FROM Moves WHERE round_id = v_round.id));

    -- Убираем карту с руки
    DELETE FROM Cards_on_Hands WHERE player_id = v_player_id AND card_id = v_second_card_id;
    UPDATE Cards SET status = 'разыграна' WHERE id = v_second_card_id;

    -- Определяем победителя взятки
    v_winner_card_id := calculate_trick_winner(v_first_card_id, v_second_card_id, v_round.trump_suit);

    IF v_winner_card_id = v_first_card_id THEN
        v_winner_player_id := v_opponent_id;
    ELSE
        v_winner_player_id := v_player_id;
    END IF;

    -- Считаем очки за взятку
    SELECT COALESCE(SUM(card_value), 0) INTO v_trick_points
    FROM Cards
    WHERE id IN (v_first_card_id, v_second_card_id);

    -- Сохраняем взятку
    SELECT COALESCE(MAX(trick_number), 0) + 1 INTO v_trick_number FROM Tricks WHERE round_id = v_round.id;
    INSERT INTO Tricks(round_id, trick_number, winner_player_id, first_card_id, second_card_id, points_value)
    VALUES (v_round.id, v_trick_number, v_winner_player_id, v_first_card_id, v_second_card_id, v_trick_points);

    -- Начисляем очки победителю взятки
    UPDATE Round_Scores
    SET round_score = round_score + v_trick_points
    WHERE player_id = v_winner_player_id AND round_id = v_round.id;

    -- Проверяем, пуста ли колода
    SELECT NOT EXISTS (SELECT 1 FROM Cards WHERE round_id = v_round.id AND status = 'в колоде')
    INTO v_deck_empty;

    -- Если колода не пуста, игроки добирают карты
    IF NOT v_deck_empty THEN
        -- Победитель взятки добирает первым
        PERFORM schnapsen.draw_card_from_deck(v_round.id, v_winner_player_id);
        -- Проигравший добирает вторым
        IF v_winner_player_id = v_player_id THEN
            PERFORM schnapsen.draw_card_from_deck(v_round.id, v_opponent_id);
        ELSE
            PERFORM schnapsen.draw_card_from_deck(v_round.id, v_player_id);
        END IF;
    END IF;

    -- Проверяем, закончились ли карты у игроков (раунд завершён)
    IF NOT EXISTS (
        SELECT 1 FROM Cards_on_Hands ch
        JOIN Players p ON p.id = ch.player_id
        WHERE p.game_id = p_game_id
    ) THEN
        -- Раунд завершён
        UPDATE Rounds SET status = 'завершён', date_time_end = clock_timestamp() WHERE id = v_round.id;

        -- Получаем финальные очки
        SELECT round_score INTO v_my_score FROM Round_Scores WHERE player_id = v_player_id AND round_id = v_round.id;
        SELECT round_score INTO v_opp_score FROM Round_Scores WHERE player_id = v_opponent_id AND round_id = v_round.id;

        -- Определяем победителя раунда и начисляем поинты
        IF v_my_score > v_opp_score THEN
            v_winner_player_id := v_player_id;
        ELSIF v_opp_score > v_my_score THEN
            v_winner_player_id := v_opponent_id;
        ELSE
            -- Ничья (редко) — поинты не начисляются
            v_winner_player_id := NULL;
        END IF;

        IF v_winner_player_id IS NOT NULL THEN
            -- Начисляем поинты: 1 если соперник набрал >= 33, 2 если < 33, 3 если 0
            IF (v_winner_player_id = v_player_id AND v_opp_score = 0) OR
               (v_winner_player_id = v_opponent_id AND v_my_score = 0) THEN
                v_points_awarded := 3;
            ELSIF (v_winner_player_id = v_player_id AND v_opp_score < 33) OR
                  (v_winner_player_id = v_opponent_id AND v_my_score < 33) THEN
                v_points_awarded := 2;
            ELSE
                v_points_awarded := 1;
            END IF;

            -- Записываем победителя раунда
            INSERT INTO Round_Winners(round_id, winner_player_id, points_awarded)
            VALUES (v_round.id, v_winner_player_id, v_points_awarded);

            -- Начисляем поинты в общий счёт
            UPDATE Players
            SET game_points = game_points + v_points_awarded
            WHERE id = v_winner_player_id;

            -- Проверяем, достиг ли кто-то points_to_win
            SELECT game_points INTO v_my_points FROM Players WHERE id = v_player_id;
            SELECT game_points INTO v_opp_points FROM Players WHERE id = v_opponent_id;

            IF v_my_points >= v_game.points_to_win OR v_opp_points >= v_game.points_to_win THEN
                -- Игра завершена
                UPDATE Games SET status = 'завершена', date_time_end = clock_timestamp() WHERE id = p_game_id;
                RETURN jsonb_build_object('status', 'game_finished', 'winner_player_id', v_winner_player_id);
            ELSE
                -- Начинаем новый раунд
                DELETE FROM Current_Move WHERE round_id = v_round.id;
                RETURN start_round(p_game_id);
            END IF;
        END IF;
    END IF;

    -- Передаём ход победителю взятки
    UPDATE Current_Move
    SET player_id = v_winner_player_id, date_time_start = clock_timestamp()
    WHERE round_id = v_round.id;

    RETURN jsonb_build_object('status', 'trick_completed', 'winner_player_id', v_winner_player_id, 'points', v_trick_points);
END;
$$;

-- Вспомогательная функция для добора карты из колоды
CREATE OR REPLACE FUNCTION schnapsen.draw_card_from_deck(p_round_id INT, p_player_id INT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = pg_catalog, schnapsen, pg_temp
AS $$
DECLARE
    v_card_id INT;
BEGIN
    -- Берём первую доступную карту из колоды
    SELECT id INTO v_card_id
    FROM Cards
    WHERE round_id = p_round_id AND status = 'в колоде'
    ORDER BY id
    LIMIT 1;

    IF FOUND THEN
        -- Добавляем карту игроку
        INSERT INTO Cards_on_Hands(player_id, card_id) VALUES (p_player_id, v_card_id);
        UPDATE Cards SET status = 'на руках' WHERE id = v_card_id;
    END IF;
END;
$$;
