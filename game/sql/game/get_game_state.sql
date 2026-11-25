CREATE OR REPLACE FUNCTION schnapsen.get_game_state(
    p_access_token TEXT,
    p_game_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
DECLARE
    u VARCHAR(30);
    p INT;
    r Rounds%ROWTYPE;
    cards JSONB;
BEGIN
    u := check_token(p_access_token);

    SELECT id
    INTO p
    FROM Players
    WHERE game_id = p_game_id
      AND login = u;

    SELECT *
    INTO r
    FROM Rounds
    WHERE game_id = p_game_id
    ORDER BY round_number DESC
    LIMIT 1;

    IF u IS NULL OR p IS NULL OR r.id IS NULL THEN
        RETURN jsonb_build_object('error', 404, 'message', 'Игра или игрок не найдены');
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'card_id', c.id,
                'rank', c.rank,
                'suit', c.suit,
                'points', rk.points
            )
            ORDER BY c.id
        ),
        '[]'::jsonb
    )
    INTO cards
    FROM Cards_in_hand h
    JOIN Cards c ON c.id = h.card_id
    JOIN Ranks rk ON rk.rank = c.rank
    WHERE h.player_id = p;

    RETURN jsonb_build_object(
        'game_id', p_game_id,
        'round_id', r.id,
        'round_number', r.round_number,
        'trump_suit', r.trump_suit,
        'my_cards', cards,
        'my_score', (SELECT round_score FROM Players WHERE id = p)
    );
END
$$;
