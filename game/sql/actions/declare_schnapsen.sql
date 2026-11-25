CREATE OR REPLACE FUNCTION schnapsen.declare_schnapsen(
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
    r INT;
    score INT;
BEGIN
    u := check_token(p_access_token);

    SELECT id, round_score
    INTO p, score
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

    INSERT INTO Schnapsen_declarations (round_id, point_declared, player_id)
    VALUES (r, score, p)
    ON CONFLICT (round_id) DO NOTHING;

    RETURN jsonb_build_object(
        'status', CASE WHEN score >= 66 THEN 'honest_schnapsen' ELSE 'false_schnapsen' END,
        'score', score
    );
END
$$;
