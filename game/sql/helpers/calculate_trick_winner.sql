-- Определяет победителя взятки по правилам Шнопса
-- Сильнее: козырь > масть первой карты > старшинство (A > 10 > K > Q > J > 9)
CREATE OR REPLACE FUNCTION schnapsen.calculate_trick_winner(
    p_first_card_id INT,
    p_second_card_id INT,
    p_trump_suit VARCHAR(10)
)
RETURNS INT
LANGUAGE plpgsql
SET search_path = pg_catalog, schnapsen, pg_temp
AS $$
DECLARE
    v_first_card Cards%ROWTYPE;
    v_second_card Cards%ROWTYPE;
    v_rank_priority INT;
BEGIN
    -- Загружаем обе карты
    SELECT * INTO v_first_card FROM Cards WHERE id = p_first_card_id;
    SELECT * INTO v_second_card FROM Cards WHERE id = p_second_card_id;

    -- Функция приоритета ранга: A=6, 10=5, K=4, Q=3, J=2, 9=1
    v_rank_priority := CASE v_first_card.rank
        WHEN 'A' THEN 6
        WHEN '10' THEN 5
        WHEN 'K' THEN 4
        WHEN 'Q' THEN 3
        WHEN 'J' THEN 2
        WHEN '9' THEN 1
    END;

    -- 1. Если вторая карта — козырь, а первая нет → вторая побеждает
    IF v_second_card.suit = p_trump_suit AND v_first_card.suit <> p_trump_suit THEN
        RETURN p_second_card_id;
    END IF;

    -- 2. Если обе козыри → побеждает старшая
    IF v_first_card.suit = p_trump_suit AND v_second_card.suit = p_trump_suit THEN
        IF (CASE v_second_card.rank WHEN 'A' THEN 6 WHEN '10' THEN 5 WHEN 'K' THEN 4 WHEN 'Q' THEN 3 WHEN 'J' THEN 2 ELSE 1 END) > v_rank_priority THEN
            RETURN p_second_card_id;
        ELSE
            RETURN p_first_card_id;
        END IF;
    END IF;

    -- 3. Если первая козырь, а вторая нет → первая побеждает
    IF v_first_card.suit = p_trump_suit AND v_second_card.suit <> p_trump_suit THEN
        RETURN p_first_card_id;
    END IF;

    -- 4. Если вторая карта не той же масти, что первая → первая побеждает (не отбилась)
    IF v_second_card.suit <> v_first_card.suit THEN
        RETURN p_first_card_id;
    END IF;

    -- 5. Обе одной масти (не козырь) → побеждает старшая
    IF (CASE v_second_card.rank WHEN 'A' THEN 6 WHEN '10' THEN 5 WHEN 'K' THEN 4 WHEN 'Q' THEN 3 WHEN 'J' THEN 2 ELSE 1 END) > v_rank_priority THEN
        RETURN p_second_card_id;
    ELSE
        RETURN p_first_card_id;
    END IF;
END;
$$;
