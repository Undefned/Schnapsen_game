-- Объявление марьяжа (K+Q одной масти)
CREATE OR REPLACE FUNCTION schnapsen.declare_marriage(
    p_access_token TEXT,
    p_game_id INT,
    p_king_card_id INT,
    p_queen_card_id INT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp
SET timezone = 'UTC'
AS $$
DECLARE
    v_login VARCHAR(30);
    v_player_id INT;
    v_round Rounds%ROWTYPE;
    v_current_move Current_Move%ROWTYPE;
    v_king Cards%ROWTYPE;
    v_queen Cards%ROWTYPE;
    v_bonus_points INT;
    v_deck_empty BOOLEAN;
BEGIN
    -- Проверяем токен
    v_login := check_token(p_access_token);
    
    IF v_login IS NULL THEN
        RETURN jsonb_build_object('error', 401, 'message', 'Невалидный токен');
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

    -- Проверяем, что колода не пуста (марьяж можно объявлять только пока есть колода)
    SELECT NOT EXISTS (SELECT 1 FROM Cards WHERE round_id = v_round.id AND status = 'в колоде')
    INTO v_deck_empty;

    IF v_deck_empty THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Марьяж можно объявлять только пока в колоде есть карты');
    END IF;

    -- Проверяем, что обе карты принадлежат игроку
    IF NOT EXISTS (
        SELECT 1 FROM Cards_on_Hands WHERE player_id = v_player_id AND card_id = p_king_card_id
    ) THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Король не на ваших руках');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM Cards_on_Hands WHERE player_id = v_player_id AND card_id = p_queen_card_id
    ) THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Дама не на ваших руках');
    END IF;

    -- Получаем карты
    SELECT * INTO v_king FROM Cards WHERE id = p_king_card_id;
    SELECT * INTO v_queen FROM Cards WHERE id = p_queen_card_id;

    -- Проверяем, что это действительно король и дама
    IF v_king.rank <> 'K' THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Первая карта должна быть королём');
    END IF;

    IF v_queen.rank <> 'Q' THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Вторая карта должна быть дамой');
    END IF;

    -- Проверяем, что масти совпадают
    IF v_king.suit <> v_queen.suit THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Король и дама должны быть одной масти');
    END IF;

    -- Проверяем, что марьяж этой масти ещё не был объявлен
    IF EXISTS (
        SELECT 1 FROM Marriages 
        WHERE round_id = v_round.id AND player_id = v_player_id AND suit = v_king.suit
    ) THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Марьяж этой масти уже был объявлен');
    END IF;

    -- Определяем бонус: 40 за козырный марьяж, 20 за обычный
    IF v_king.suit = v_round.trump_suit THEN
        v_bonus_points := 40;
    ELSE
        v_bonus_points := 20;
    END IF;

    -- Записываем марьяж
    INSERT INTO Marriages(round_id, player_id, suit, is_trump, bonus_points)
    VALUES (v_round.id, v_player_id, v_king.suit, v_king.suit = v_round.trump_suit, v_bonus_points);

    -- Начисляем очки
    UPDATE Round_Scores
    SET round_score = round_score + v_bonus_points
    WHERE player_id = v_player_id AND round_id = v_round.id;

    RETURN jsonb_build_object(
        'status', 'marriage_declared',
        'suit', v_king.suit,
        'is_trump', v_king.suit = v_round.trump_suit,
        'bonus_points', v_bonus_points,
        'message', CASE 
            WHEN v_king.suit = v_round.trump_suit THEN 'Козырный марьяж! +40 очков'
            ELSE 'Марьяж! +20 очков'
        END
    );
END;
$$;
