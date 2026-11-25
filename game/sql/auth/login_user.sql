CREATE OR REPLACE FUNCTION schnapsen.login_user(
    p_login TEXT,
    p_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM Users
        WHERE login = p_login
          AND password = md5(p_password)
    ) THEN
        RETURN jsonb_build_object('error', 403, 'message', 'Неверный логин или пароль');
    END IF;

    RETURN generate_tokens(p_login);
END
$$;
