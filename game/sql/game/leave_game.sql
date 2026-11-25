CREATE OR REPLACE FUNCTION schnapsen.leave_game(
    p_access_token TEXT,
    p_game_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
DECLARE
    u VARCHAR(30);
BEGIN
    u := check_token(p_access_token);

    IF u IS NULL THEN
        RETURN jsonb_build_object('error', 401, 'message', 'Невалидный токен');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM Players
        WHERE game_id = p_game_id AND login = u
    ) THEN
        RETURN jsonb_build_object('error', 404, 'message', 'Игрок не найден в игре');
    END IF;

    -- Игрок сохраняется для целостности истории Moves и Tricks.

    RETURN jsonb_build_object('message', 'Вы вышли из игры');
END
$$;
