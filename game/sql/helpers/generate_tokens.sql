-- Генерирует пару JWT токенов (access + refresh)
-- В реальной системе JWT должны генериться на уровне приложения с подписью
-- Здесь упрощённая версия: используем gen_random_uuid() + login
CREATE OR REPLACE FUNCTION schnapsen.generate_tokens(p_login VARCHAR(30))
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp
SET timezone = 'UTC'
AS $$
DECLARE
    v_access_token TEXT;
    v_refresh_token TEXT;
    v_access_expires TIMESTAMP;
    v_refresh_expires TIMESTAMP;
BEGIN
    -- Генерируем токены (в реальности — JWT с подписью)
    v_access_token := encode(gen_random_bytes(32), 'base64');
    v_refresh_token := encode(gen_random_bytes(32), 'base64');
    
    -- Access token живёт 1 час, refresh — 7 дней
    v_access_expires := clock_timestamp() + interval '1 hour';
    v_refresh_expires := clock_timestamp() + interval '7 days';

    -- Сохраняем в БД
    INSERT INTO Tokens(login, access_token, refresh_token, access_expires, refresh_expires)
    VALUES (p_login, v_access_token, v_refresh_token, v_access_expires, v_refresh_expires);

    RETURN jsonb_build_object(
        'access_token', v_access_token,
        'refresh_token', v_refresh_token,
        'access_expires', v_access_expires,
        'refresh_expires', v_refresh_expires
    );
END;
$$;
