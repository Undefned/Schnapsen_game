CREATE OR REPLACE FUNCTION schnapsen.logout_all_devices(p_access_token TEXT)
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

    DELETE FROM Tokens
    WHERE login = u;

    RETURN jsonb_build_object('message', 'Вы вышли из системы на всех устройствах');
END
$$;
