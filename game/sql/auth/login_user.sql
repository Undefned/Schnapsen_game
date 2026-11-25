-- Авторизация (вход) пользователя
CREATE OR REPLACE FUNCTION schnapsen.login_user(p_login TEXT, p_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp
SET timezone = 'UTC'
AS $$
DECLARE
    v_tokens JSONB;
    v_stored_password VARCHAR(100);
BEGIN
    -- Проверяем логин
    IF p_login IS NULL OR btrim(p_login) = '' THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Заполните логин');
    END IF;

    -- Проверяем пароль
    IF p_password IS NULL OR btrim(p_password) = '' THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Заполните пароль');
    END IF;

    -- Получаем сохранённый пароль
    SELECT password INTO v_stored_password
    FROM Users
    WHERE login = p_login;

    IF NOT FOUND OR v_stored_password <> p_password THEN
        RETURN jsonb_build_object('error', 403, 'message', 'Неверный логин или пароль');
    END IF;

    -- Генерируем новые токены
    v_tokens := generate_tokens(p_login);

    RETURN v_tokens;
END;
$$;
