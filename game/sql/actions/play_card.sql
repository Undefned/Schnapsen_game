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
    user_login VARCHAR(30);
    player_id INT;
    round_id INT;
    trick_id INT;
    card_count INT;
    trick_points INT;
BEGIN
    user_login := check_token(p_access_token);

    SELECT id
    INTO player_id
    FROM Players
    WHERE game_id = p_game_id
      AND login = user_login;

    SELECT id
    INTO round_id
    FROM Rounds
    WHERE game_id = p_game_id
    ORDER BY round_number DESC
    LIMIT 1;

    IF player_id IS NULL OR round_id IS NULL THEN
        RETURN jsonb_build_object('error', 404, 'message', 'Игра или игрок не найдены');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM Cards_in_hand h
        JOIN Cards c ON c.id = h.card_id
        WHERE h.player_id = player_id
          AND c.id = p_card_id
    ) THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Этой карты нет на руке игрока');
    END IF;

    SELECT trick_id.id, count(h.card_id)
    INTO trick_id, card_count
    FROM Tricks trick_id
    LEFT JOIN Cards_in_trick h ON h.trick_id = trick_id.id
    WHERE trick_id.round_id = round_id
    GROUP BY trick_id.id
    ORDER BY trick_id.id DESC
    LIMIT 1;

    IF trick_id IS NULL OR card_count >= 2 THEN
        INSERT INTO Tricks (round_id, winner_id)
        VALUES (round_id, player_id)
        RETURNING id INTO trick_id;
    END IF;

    INSERT INTO Moves (player_id)
    VALUES (player_id);

    INSERT INTO Cards_in_trick (card_id, trick_id)
    VALUES (p_card_id, trick_id);

    DELETE FROM Cards_in_hand
    WHERE player_id = player_id
      AND card_id = p_card_id;

    SELECT count(*)
    INTO card_count
    FROM Cards_in_trick
    WHERE trick_id = trick_id;

    IF card_count = 1 THEN
        RETURN jsonb_build_object('status', 'waiting_for_opponent', 'card_played', p_card_id);
    END IF;

    SELECT COALESCE(sum(rk.points), 0)
    INTO trick_points
    FROM Cards_in_trick h
    JOIN Cards c ON c.id = h.card_id
    JOIN Ranks rk ON rk.rank = c.rank
    WHERE h.trick_id = trick_id;

    UPDATE Players
    SET round_score = round_score + trick_points
    WHERE id = (SELECT winner_id FROM Tricks WHERE id = trick_id);

    RETURN jsonb_build_object(
        'status', 'trick_completed',
        'winner_player_id', (SELECT winner_id FROM Tricks WHERE id = trick_id),
        'points', trick_points
    );
END
$$;
