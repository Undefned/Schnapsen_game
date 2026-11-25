CREATE OR REPLACE FUNCTION schnapsen.deal_cards(
    p_game_id INT,
    p_player1 INT,
    p_player2 INT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen AS $$
BEGIN
    INSERT INTO Cards (suit, rank, game_id)
    SELECT s.suit, r.rank, p_game_id
    FROM unnest(ARRAY['spades', 'hearts', 'diamonds', 'clubs']) s(suit)
    CROSS JOIN Ranks r
    ON CONFLICT (game_id, suit, rank) DO NOTHING;

    INSERT INTO Cards_in_hand (player_id, card_id)
    SELECT p_player1, c.id
    FROM Cards c
    WHERE c.game_id = p_game_id
    ORDER BY c.id
    LIMIT 6;

    INSERT INTO Cards_in_hand (player_id, card_id)
    SELECT p_player2, c.id
    FROM Cards c
    WHERE c.game_id = p_game_id
      AND NOT EXISTS (
          SELECT 1
          FROM Cards_in_hand h
          WHERE h.card_id = c.id
      )
    ORDER BY c.id
    LIMIT 6;
END
$$;
