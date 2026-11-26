CREATE OR REPLACE FUNCTION schnapsen.declare_marriage(
    p_access_token TEXT,
    p_game_id INT,
    p_king_card_id INT,
    p_queen_card_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
DECLARE
    user_login VARCHAR(30);
    player_id INT;
    round_id INT;
    bonus_points INT;
    trump_suit VARCHAR(10);
BEGIN
    user_login := check_token(p_access_token);

    SELECT id
    INTO player_id
    FROM Players
    WHERE game_id = p_game_id
      AND login = user_login;

    SELECT id, trump_suit
    INTO round_id, trump_suit
    FROM Rounds
    WHERE game_id = p_game_id
    ORDER BY round_number DESC
    LIMIT 1;

    IF player_id IS NULL OR round_id IS NULL THEN
        RETURN jsonb_build_object('error', 404, 'message', 'Игра или игрок не найдены');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM Cards k
        JOIN Cards q ON q.game_id = k.game_id
        WHERE k.id = p_king_card_id
          AND q.id = p_queen_card_id
          AND k.rank = 'K'
          AND q.rank = 'Q'
          AND k.suit = q.suit
    ) THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Нужны король и дама одной масти');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM Cards_in_hand
        WHERE player_id = player_id
          AND card_id IN (p_king_card_id, p_queen_card_id)
    ) THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Карты должны быть на руках');
    END IF;

    SELECT CASE WHEN c.suit = trump_suit THEN 40 ELSE 20 END, c.suit
    INTO bonus_points, trump_suit
    FROM Cards c
    WHERE c.id = p_king_card_id;

    INSERT INTO Schnapsen_declarations (round_id, point_declared, player_id)
    VALUES (round_id, bonus_points, player_id)
    ON CONFLICT (round_id) DO NOTHING;

    RETURN jsonb_build_object('status', 'marriage_declared', 'bonus_points', bonus_points);
END
$$;
