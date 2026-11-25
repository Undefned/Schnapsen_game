CREATE OR REPLACE FUNCTION schnapsen.create_game(
    p_access_token TEXT,
    p_move_time_limit INT,
    p_points_to_win INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
DECLARE
    u VARCHAR(30);
    g INT;
    p INT;
BEGIN
    u := check_token(p_access_token);

    IF u IS NULL THEN
        RETURN jsonb_build_object('error', 401, 'message', 'Невалидный токен');
    END IF;

    IF p_move_time_limit IS NULL OR p_move_time_limit <= 0 THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Лимит времени хода должен быть положительным');
    END IF;

    IF p_points_to_win IS NULL OR p_points_to_win < 1 OR p_points_to_win > 7 THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Количество очков должно быть от 1 до 7');
    END IF;

    INSERT INTO Games (move_time_limit, points_to_win)
    VALUES (p_move_time_limit, p_points_to_win)
    RETURNING id INTO g;

    INSERT INTO Players (seat_number, game_id, login)
    VALUES (1, g, u)
    RETURNING id INTO p;

    RETURN jsonb_build_object('game_id', g, 'player_id', p, 'status', 'создана');
END
$$;
