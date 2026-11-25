-- Проверяет валидность access_token
CREATE OR REPLACE FUNCTION schnapsen.check_token(p_access_token TEXT)
RETURNS VARCHAR(30)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp
SET timezone = 'UTC'
AS $$
DECLARE
    v_login VARCHAR(30);
BEGIN
    IF p_access_token IS NULL OR btrim(p_access_token) = '' THEN
        RETURN NULL;
    END IF;

    SELECT login
    INTO v_login
    FROM Tokens
    WHERE access_token = p_access_token
      AND access_expires > clock_timestamp();

    RETURN v_login;
END;
$$;
