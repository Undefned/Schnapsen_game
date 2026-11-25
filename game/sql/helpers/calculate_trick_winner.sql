CREATE OR REPLACE FUNCTION schnapsen.calculate_trick_winner(
    p_first_card INT,
    p_second_card INT,
    p_trump_suit VARCHAR(10)
)
RETURNS INT
LANGUAGE SQL
SECURITY DEFINER
SET search_path = pg_catalog, schnapsen AS $$
    SELECT CASE
        WHEN c1.suit = p_trump_suit AND c2.suit <> p_trump_suit THEN p_first_card
        WHEN c2.suit = p_trump_suit AND c1.suit <> p_trump_suit THEN p_second_card
        WHEN c1.suit = c2.suit AND r1.points >= r2.points THEN p_first_card
        WHEN c1.suit = c2.suit THEN p_second_card
        ELSE p_first_card
    END
    FROM Cards c1
    JOIN Cards c2 ON c2.id = p_second_card
    JOIN Ranks r1 ON r1.rank = c1.rank
    JOIN Ranks r2 ON r2.rank = c2.rank
    WHERE c1.id = p_first_card
$$;
