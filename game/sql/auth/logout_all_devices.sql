-- Выход из всех устройств (удаление всех токенов пользователя)
CREATE OR REPLACE FUNCTION schnapsen.logout_all_devices(p_access_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp
SET timezone = 'UTC'
AS $$
DECLARE
    v_login VARCHAR(30);
BEGIN
    -- Проверяем токен
    v_login := check_token(p_access_token);
    
    IF v_login IS NULL THEN
        RETURN jsonb_build_object('error', 401, 'message', 'Невалидный токен');
    END IF;

    -- Удаляем ВСЕ токены пользователя
    DELETE FROM Tokens
    WHERE login = v_login;

    RETURN jsonb_build_object('message', 'Вы вышли из системы на всех устройствах');
END;
$$;
