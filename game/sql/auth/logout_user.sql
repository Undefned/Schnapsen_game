-- Выход из приложения (удаление токенов текущего устройства)
CREATE OR REPLACE FUNCTION schnapsen.logout_user(p_access_token TEXT)
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

    -- Удаляем токены текущей сессии
    DELETE FROM Tokens
    WHERE access_token = p_access_token;

    RETURN jsonb_build_object('message', 'Вы вышли из системы');
END;
$$;
