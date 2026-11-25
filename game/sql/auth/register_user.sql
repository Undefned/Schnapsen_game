-- Регистрация нового пользователя
CREATE OR REPLACE FUNCTION schnapsen.register_user(p_login TEXT, p_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp
SET timezone = 'UTC'
AS $$
DECLARE
    v_tokens JSONB;
BEGIN
    -- Валидация логина
    IF p_login IS NULL OR btrim(p_login) = '' THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Заполните логин');
    END IF;

    IF length(p_login) > 30 THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Логин длиннее 30 символов');
    END IF;

    -- Валидация пароля
    IF p_password IS NULL OR btrim(p_password) = '' THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Заполните пароль');
    END IF;

    IF length(p_password) > 100 THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Пароль длиннее 100 символов');
    END IF;

    -- Создаём пользователя
    INSERT INTO Users(login, password)
    VALUES (p_login, p_password);

    -- Генерируем токены
    v_tokens := generate_tokens(p_login);

    -- Возвращаем токены
    RETURN v_tokens;
EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Логин уже занят');
END;
$$;
