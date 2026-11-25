CREATE OR REPLACE FUNCTION schnapsen.start_round(p_game_id INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
DECLARE
    r INT;
    n INT;
    p1 INT;
    p2 INT;
BEGIN
    SELECT id
    INTO p1
    FROM Players
    WHERE game_id = p_game_id
      AND seat_number = 1;

    SELECT id
    INTO p2
    FROM Players
    WHERE game_id = p_game_id
      AND seat_number = 2;

    IF p1 IS NULL OR p2 IS NULL THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Для начала раунда нужны два игрока');
    END IF;

    SELECT COALESCE(max(round_number), 0) + 1
    INTO n
    FROM Rounds
    WHERE game_id = p_game_id;

    INSERT INTO Rounds (round_number, trump_suit, game_id)
    VALUES (n, 'hearts', p_game_id)
    RETURNING id INTO r;

    PERFORM deal_cards(p_game_id, p1, p2);

    RETURN jsonb_build_object(
        'round_id', r,
        'round_number', n,
        'trump_suit', 'hearts',
        'first_player_id', p1
    );
END
$$;
