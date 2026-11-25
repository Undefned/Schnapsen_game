CREATE OR REPLACE FUNCTION schnapsen.join_game(
    p_access_token TEXT,
    p_game_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
DECLARE
    u VARCHAR(30);
    n INT;
BEGIN
    u := check_token(p_access_token);

    IF u IS NULL THEN
        RETURN jsonb_build_object('error', 401, 'message', 'Невалидный токен');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM Games
        WHERE id = p_game_id
    ) THEN
        RETURN jsonb_build_object('error', 404, 'message', 'Игра не найдена');
    END IF;

    IF EXISTS (
        SELECT 1
        FROM Players
        WHERE game_id = p_game_id
          AND login = u
    ) THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Вы уже в этой игре');
    END IF;

    SELECT COALESCE(max(seat_number), 0) + 1
    INTO n
    FROM Players
    WHERE game_id = p_game_id;

    IF n > 2 THEN
        RETURN jsonb_build_object('error', 409, 'message', 'В игре уже достаточно игроков');
    END IF;

    INSERT INTO Players (seat_number, game_id, login)
    VALUES (n, p_game_id, u);

    IF n = 2 THEN
        RETURN start_round(p_game_id);
    END IF;

    RETURN jsonb_build_object('status', 'waiting_for_opponent');
END
$$;
