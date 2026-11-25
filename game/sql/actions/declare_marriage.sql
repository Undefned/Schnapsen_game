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
    u VARCHAR(30);
    p INT;
    r INT;
    bonus INT;
    s VARCHAR(10);
BEGIN
    u := check_token(p_access_token);

    SELECT id
    INTO p
    FROM Players
    WHERE game_id = p_game_id
      AND login = u;

    SELECT id, trump_suit
    INTO r, s
    FROM Rounds
    WHERE game_id = p_game_id
    ORDER BY round_number DESC
    LIMIT 1;

    IF p IS NULL OR r IS NULL THEN
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
        WHERE player_id = p
          AND card_id IN (p_king_card_id, p_queen_card_id)
    ) THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Карты должны быть на руках');
    END IF;

    SELECT CASE WHEN c.suit = s THEN 40 ELSE 20 END, c.suit
    INTO bonus, s
    FROM Cards c
    WHERE c.id = p_king_card_id;

    INSERT INTO Schnapsen_declarations (round_id, point_declared, player_id)
    VALUES (r, bonus, p)
    ON CONFLICT (round_id) DO NOTHING;

    RETURN jsonb_build_object('status', 'marriage_declared', 'bonus_points', bonus);
END
$$;
