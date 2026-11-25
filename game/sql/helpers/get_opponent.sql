CREATE OR REPLACE FUNCTION schnapsen.get_opponent(p_player_id INT)
RETURNS INT
LANGUAGE SQL
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen AS $$
    SELECT p2.id
    FROM Players p1
    JOIN Players p2
      ON p2.game_id = p1.game_id
     AND p2.id <> p1.id
    WHERE p1.id = p_player_id
    LIMIT 1
$$;
