CREATE OR REPLACE FUNCTION schnapsen.register_user(
    p_login TEXT,
    p_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
BEGIN
    IF p_login IS NULL
       OR btrim(p_login) = ''
       OR p_password IS NULL
       OR p_password = '' THEN
        RETURN jsonb_build_object('error', 400, 'message', 'Логин и пароль обязательны');
    END IF;

    IF EXISTS (
        SELECT 1
        FROM Users
        WHERE login = p_login
    ) THEN
        RETURN jsonb_build_object('error', 409, 'message', 'Логин уже занят');
    END IF;

    INSERT INTO Users (login, password, name)
    VALUES (p_login, md5(p_password), p_login);

    RETURN generate_tokens(p_login);
END
$$;
