CREATE OR REPLACE FUNCTION schnapsen.play_card(
    p_access_token TEXT,
    p_game_id INT,
    p_card_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
DECLARE
    u VARCHAR(30);
    p INT;
    r INT;
    t INT;
    n INT;
    pts INT;
BEGIN
    u := check_token(p_access_token);

    SELECT id
    INTO p
    FROM Players
    WHERE game_id = p_game_id
      AND login = u;

    SELECT id
    INTO r
    FROM Rounds
    WHERE game_id = p_game_id
    ORDER BY round_number DESC
    LIMIT 1;

    IF p IS NULL OR r IS NULL THEN
        RETURN jsonb_build_object('error', 404, 'message', 'Игра или игрок не найдены');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM Cards_in_hand h
        JOIN Cards c ON c.id = h.card_id
        WHERE h.player_id = p
          AND c.id = p_card_id
    ) THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Этой карты нет на руке игрока');
    END IF;

    SELECT t.id, count(h.card_id)
    INTO t, n
    FROM Tricks t
    LEFT JOIN Cards_in_trick h ON h.trick_id = t.id
    WHERE t.round_id = r
    GROUP BY t.id
    ORDER BY t.id DESC
    LIMIT 1;

    IF t IS NULL OR n >= 2 THEN
        INSERT INTO Tricks (round_id, winner_id)
        VALUES (r, p)
        RETURNING id INTO t;
    END IF;

    INSERT INTO Moves (player_id)
    VALUES (p);

    INSERT INTO Cards_in_trick (card_id, trick_id)
    VALUES (p_card_id, t);

    DELETE FROM Cards_in_hand
    WHERE player_id = p
      AND card_id = p_card_id;

    SELECT count(*)
    INTO n
    FROM Cards_in_trick
    WHERE trick_id = t;

    IF n = 1 THEN
        RETURN jsonb_build_object('status', 'waiting_for_opponent', 'card_played', p_card_id);
    END IF;

    SELECT COALESCE(sum(rk.points), 0)
    INTO pts
    FROM Cards_in_trick h
    JOIN Cards c ON c.id = h.card_id
    JOIN Ranks rk ON rk.rank = c.rank
    WHERE h.trick_id = t;

    UPDATE Players
    SET round_score = round_score + pts
    WHERE id = (SELECT winner_id FROM Tricks WHERE id = t);

    RETURN jsonb_build_object(
        'status', 'trick_completed',
        'winner_player_id', (SELECT winner_id FROM Tricks WHERE id = t),
        'points', pts
    );
END
$$;
