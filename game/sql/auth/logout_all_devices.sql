CREATE OR REPLACE FUNCTION schnapsen.logout_all_devices(p_access_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
DECLARE
    user_login VARCHAR(30);
BEGIN
    user_login := check_token(p_access_token);

    IF user_login IS NULL THEN
        RETURN jsonb_build_object('error', 401, 'message', 'Невалидный токен');
    END IF;

    DELETE FROM Tokens
    WHERE login = user_login;

    RETURN jsonb_build_object('message', 'Вы вышли из системы на всех устройствах');
END
$$;
