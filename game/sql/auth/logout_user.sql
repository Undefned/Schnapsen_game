CREATE OR REPLACE FUNCTION schnapsen.logout_user(p_access_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
BEGIN
    DELETE FROM Tokens
    WHERE access_token = p_access_token;

    RETURN jsonb_build_object('message', 'Вы вышли из системы');
END
$$;
