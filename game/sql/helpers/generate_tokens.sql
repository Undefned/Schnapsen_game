CREATE OR REPLACE FUNCTION schnapsen.generate_tokens(p_login VARCHAR(30))
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, schnapsen, pg_temp AS $$
DECLARE
    access_token TEXT := encode(gen_random_bytes(32), 'hex');
    refresh_token TEXT := encode(gen_random_bytes(32), 'hex');
    access_expires_at TIMESTAMP := clock_timestamp() + interval '1 hour';
    refresh_expires_at TIMESTAMP := clock_timestamp() + interval '7 days';
BEGIN
    INSERT INTO Tokens (login, access_token, refresh_token, access_expires, refresh_expires)
    VALUES (p_login, access_token, refresh_token, access_expires_at, refresh_expires_at);

    RETURN jsonb_build_object(
        'access_token', access_token,
        'refresh_token', refresh_token,
        'access_expires', access_expires_at,
        'refresh_expires', refresh_expires_at
    );
END
$$;
