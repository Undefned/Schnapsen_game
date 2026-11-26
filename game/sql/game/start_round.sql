CREATE OR REPLACE FUNCTION schnapsen.start_round(p_game_id INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
DECLARE
    round_id INT;
    round_number INT;
    first_player_id INT;
    second_player_id INT;
BEGIN
    SELECT id
    INTO first_player_id
    FROM Players
    WHERE game_id = p_game_id
      AND seat_number = 1;

    SELECT id
    INTO second_player_id
    FROM Players
    WHERE game_id = p_game_id
      AND seat_number = 2;

    IF first_player_id IS NULL OR second_player_id IS NULL THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Для начала раунда нужны два игрока');
    END IF;

    SELECT COALESCE(max(round_number), 0) + 1
    INTO round_number
    FROM Rounds
    WHERE game_id = p_game_id;

    INSERT INTO Rounds (round_number, trump_suit, game_id)
    VALUES (round_number, 'hearts', p_game_id)
    RETURNING id INTO round_id;

    PERFORM deal_cards(p_game_id, first_player_id, second_player_id);

    RETURN jsonb_build_object(
        'round_id', round_id,
        'round_number', round_number,
        'trump_suit', 'hearts',
        'first_player_id', first_player_id
    );
END
$$;
