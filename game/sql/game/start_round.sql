-- Начало нового раунда (автоматически стартует при подключении второго игрока)
CREATE OR REPLACE FUNCTION schnapsen.start_round(p_game_id INT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp
SET timezone = 'UTC'
AS $$
DECLARE
    v_game Games%ROWTYPE;
    v_round_id INT;
    v_round_number INT;
    v_player1_id INT;
    v_player2_id INT;
    v_dealer_id INT;
    v_first_player_id INT;
    v_trump_suits TEXT[] := ARRAY['hearts', 'diamonds', 'clubs', 'spades'];
    v_random_trump VARCHAR(10);
BEGIN
    -- Получаем игру
    SELECT * INTO v_game
    FROM Games
    WHERE id = p_game_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 404, 'message', 'Игра не найдена');
    END IF;

    -- Проверяем, что игра открыта
    IF v_game.status <> 'открыта' AND v_game.status <> 'идёт игра' THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Игра уже завершена');
    END IF;

    -- Получаем игроков
    SELECT id INTO v_player1_id FROM Players WHERE game_id = p_game_id AND seat_number = 1;
    SELECT id INTO v_player2_id FROM Players WHERE game_id = p_game_id AND seat_number = 2;

    IF v_player1_id IS NULL OR v_player2_id IS NULL THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Недостаточно игроков для начала раунда');
    END IF;

    -- Определяем номер раунда
    SELECT COALESCE(MAX(round_number), 0) + 1 INTO v_round_number
    FROM Rounds
    WHERE game_id = p_game_id;

    -- Определяем дилера (чередуем игроков)
    IF v_round_number % 2 = 1 THEN
        v_dealer_id := v_player1_id;
        v_first_player_id := v_player2_id; -- не дилер ходит первым
    ELSE
        v_dealer_id := v_player2_id;
        v_first_player_id := v_player1_id;
    END IF;

    -- Случайная козырная масть (будет перезаписана после раздачи)
    v_random_trump := v_trump_suits[1 + floor(random() * 4)::int];

    -- Создаём раунд
    INSERT INTO Rounds(game_id, round_number, trump_suit, dealer_player_id, status)
    VALUES (p_game_id, v_round_number, v_random_trump, v_dealer_id, 'активный')
    RETURNING id INTO v_round_id;

    -- Инициализируем счёт игроков в раунде
    INSERT INTO Round_Scores(player_id, round_id, round_score, schnapsen_declared)
    VALUES 
        (v_player1_id, v_round_id, 0, FALSE),
        (v_player2_id, v_round_id, 0, FALSE);

    -- Раздаём карты (функция deal_cards создаст колоду, раздаст карты и установит козырь)
    PERFORM deal_cards(v_round_id, v_player1_id, v_player2_id);

    -- Устанавливаем текущий ход (первым ходит не-дилер)
    INSERT INTO Current_Move(round_id, player_id, date_time_start)
    VALUES (v_round_id, v_first_player_id, clock_timestamp());

    -- Обновляем статус игры
    IF v_game.status = 'открыта' THEN
        UPDATE Games
        SET status = 'идёт игра', date_time_start = clock_timestamp()
        WHERE id = p_game_id;
    END IF;

    -- Возвращаем состояние раунда
    RETURN jsonb_build_object(
        'round_id', v_round_id,
        'round_number', v_round_number,
        'trump_suit', (SELECT trump_suit FROM Rounds WHERE id = v_round_id),
        'dealer_player_id', v_dealer_id,
        'current_player_id', v_first_player_id,
        'status', 'активный'
    );
END;
$$;
