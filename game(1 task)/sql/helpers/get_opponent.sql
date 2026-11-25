-- Находит соперника игрока в партии
CREATE OR REPLACE FUNCTION schnapsen.get_opponent(p_player_id INT)
RETURNS INT
LANGUAGE plpgsql
SET search_path = pg_catalog, schnapsen, pg_temp
AS $$
DECLARE
    v_game_id INT;
    v_opponent_id INT;
BEGIN
    SELECT game_id INTO v_game_id
    FROM Players
    WHERE id = p_player_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT id INTO v_opponent_id
    FROM Players
    WHERE game_id = v_game_id AND id <> p_player_id
    LIMIT 1;

    RETURN v_opponent_id;
END;
$$;