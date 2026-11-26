CREATE OR REPLACE FUNCTION schnapsen.get_game_state(
    p_access_token TEXT,
    p_game_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen, pg_temp AS $$
DECLARE
    user_login VARCHAR(30);
    player_id INT;
    current_round Rounds%ROWTYPE;
    player_cards JSONB;
    players_state JSONB;
    current_trick JSONB;
    last_completed_trick JSONB;
BEGIN
    user_login := check_token(p_access_token);

    SELECT id
    INTO player_id
    FROM Players
    WHERE game_id = p_game_id
      AND login = user_login;

    SELECT *
    INTO current_round
    FROM Rounds
    WHERE game_id = p_game_id
    ORDER BY round_number DESC
    LIMIT 1;

    IF user_login IS NULL THEN
        RETURN jsonb_build_object('error', 401, 'message', 'Невалидный токен');
    END IF;

    IF player_id IS NULL OR current_round.id IS NULL THEN
        RETURN jsonb_build_object('error', 404, 'message', 'Игра или игрок не найдены');
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'card_id', c.id,
                'rank', c.rank,
                'suit', c.suit,
                'points', rk.points
            )
            ORDER BY c.id
        ),
        '[]'::jsonb
    )
    INTO player_cards
    FROM Cards_in_hand h
    JOIN Cards c ON c.id = h.card_id
    JOIN Ranks rk ON rk.rank = c.rank
    WHERE h.player_id = player_id;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'player_id', pl.id,
        'login', pl.login,
        'seat_number', pl.seat_number,
        'round_score', pl.round_score,
        'cards_count', (SELECT count(*) FROM Cards_in_hand h WHERE h.player_id = pl.id),
        'rounds_won', (SELECT count(*) FROM Round_winner rw
                       JOIN Rounds rr ON rr.id = rw.round_id
                       WHERE rr.game_id = p_game_id AND rw.player_id = pl.id)
    ) ORDER BY pl.seat_number), '[]'::jsonb)
    INTO players_state
    FROM Players pl WHERE pl.game_id = p_game_id;

    -- A trick with fewer than two player_cards is shown as unfinished, not won.
    SELECT jsonb_build_object(
        'trick_id', t.id,
        'cards', COALESCE((SELECT jsonb_agg(jsonb_build_object(
            'card_id', c.id, 'rank', c.rank, 'suit', c.suit, 'points', rk.points
        ) ORDER BY c.id) FROM Cards_in_trick ct
        JOIN Cards c ON c.id = ct.card_id
        JOIN Ranks rk ON rk.rank = c.rank
        WHERE ct.trick_id = t.id), '[]'::jsonb)
    ) INTO current_trick
    FROM Tricks t WHERE t.round_id = current_round.id
      AND (SELECT count(*) FROM Cards_in_trick ct WHERE ct.trick_id = t.id) = 1
    ORDER BY t.id DESC LIMIT 1;

    SELECT jsonb_build_object(
        'trick_id', t.id,
        'winner_player_id', t.winner_id,
        'cards', (SELECT jsonb_agg(jsonb_build_object(
            'card_id', c.id, 'rank', c.rank, 'suit', c.suit, 'points', rk.points
        ) ORDER BY c.id) FROM Cards_in_trick ct
        JOIN Cards c ON c.id = ct.card_id
        JOIN Ranks rk ON rk.rank = c.rank
        WHERE ct.trick_id = t.id)
    ) INTO last_completed_trick
    FROM Tricks t WHERE t.round_id = current_round.id
      AND (SELECT count(*) FROM Cards_in_trick ct WHERE ct.trick_id = t.id) >= 2
    ORDER BY t.id DESC LIMIT 1;

    RETURN jsonb_build_object(
        'game_id', p_game_id,
        'round_id', current_round.id,
        'round_number', current_round.round_number,
        'trump_suit', current_round.trump_suit,
        'move_time_limit', (SELECT move_time_limit FROM Games WHERE id = p_game_id),
        'points_to_win', (SELECT points_to_win FROM Games WHERE id = p_game_id),
        'my_player_id', player_id,
        'my_cards', player_cards,
        'my_score', (SELECT round_score FROM Players WHERE id = player_id),
        'players', players_state,
        'current_trick', current_trick,
        'last_completed_trick', last_completed_trick,
        'round_winner_player_id', (SELECT player_id FROM Round_winner WHERE round_id = current_round.id)
    );
END
$$;
