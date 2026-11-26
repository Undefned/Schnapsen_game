CREATE OR REPLACE FUNCTION schnapsen.declare_schnapsen(
    p_access_token TEXT,
    p_game_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
DECLARE
    user_login VARCHAR(30);
    player_id INT;
    round_id INT;
    player_score INT;
BEGIN
    user_login := check_token(p_access_token);

    SELECT id, round_score
    INTO player_id, player_score
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

    INSERT INTO Schnapsen_declarations (round_id, point_declared, player_id)
    VALUES (round_id, player_score, player_id)
    ON CONFLICT (round_id) DO NOTHING;

    RETURN jsonb_build_object(
        'status', CASE WHEN player_score >= 66 THEN 'honest_schnapsen' ELSE 'false_schnapsen' END,
        'score', player_score
    );
END
$$;
