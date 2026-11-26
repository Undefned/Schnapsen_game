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
    user_login VARCHAR(30);
    game_id INT;
    player_id INT;
BEGIN
    user_login := check_token(p_access_token);

    IF user_login IS NULL THEN
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
    RETURNING id INTO game_id;

    INSERT INTO Players (seat_number, game_id, login)
    VALUES (1, game_id, user_login)
    RETURNING id INTO player_id;

    RETURN jsonb_build_object('game_id', game_id, 'player_id', player_id, 'status', 'создана');
END
$$;
