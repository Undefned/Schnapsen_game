CREATE OR REPLACE FUNCTION schnapsen.generate_tokens(p_login VARCHAR(30))
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, schnapsen, pg_temp AS $$
DECLARE
    a TEXT := encode(gen_random_bytes(32), 'hex');
    r TEXT := encode(gen_random_bytes(32), 'hex');
    ae TIMESTAMP := clock_timestamp() + interval '1 hour';
    re TIMESTAMP := clock_timestamp() + interval '7 days';
BEGIN
    INSERT INTO Tokens (login, access_token, refresh_token, access_expires, refresh_expires)
    VALUES (p_login, a, r, ae, re);

    RETURN jsonb_build_object(
        'access_token', a,
        'refresh_token', r,
        'access_expires', ae,
        'refresh_expires', re
    );
END
$$;
