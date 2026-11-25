-- Раздаёт карты в начале раунда
-- Создаёт 20 карт (6 мастей × 4 масти минус 4 карты удаляются случайно)
-- Раздаёт по 3 карты каждому игроку, одна карта открывается как козырь
CREATE OR REPLACE FUNCTION schnapsen.deal_cards(p_round_id INT, p_player1_id INT, p_player2_id INT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = pg_catalog, schnapsen, pg_temp
SET timezone = 'UTC'
AS $$
DECLARE
    v_card_id INT;
    v_cards INT[] := ARRAY[]::INT[];
    v_trump_card_id INT;
    i INT;
BEGIN
    -- Создаём все 24 карты колоды (6 рангов × 4 масти)
    -- Ранги: 9, 10, J, Q, K, A
    -- Стоимость: 9=0, J=2, Q=3, K=4, 10=10, A=11
    INSERT INTO Cards(round_id, rank, suit, card_value, status)
    SELECT p_round_id, rank, suit, card_value, 'в колоде'
    FROM (VALUES
        ('9', 'hearts', 0), ('9', 'diamonds', 0), ('9', 'clubs', 0), ('9', 'spades', 0),
        ('10', 'hearts', 10), ('10', 'diamonds', 10), ('10', 'clubs', 10), ('10', 'spades', 10),
        ('J', 'hearts', 2), ('J', 'diamonds', 2), ('J', 'clubs', 2), ('J', 'spades', 2),
        ('Q', 'hearts', 3), ('Q', 'diamonds', 3), ('Q', 'clubs', 3), ('Q', 'spades', 3),
        ('K', 'hearts', 4), ('K', 'diamonds', 4), ('K', 'clubs', 4), ('K', 'spades', 4),
        ('A', 'hearts', 11), ('A', 'diamonds', 11), ('A', 'clubs', 11), ('A', 'spades', 11)
    ) AS deck(rank, suit, card_value);

    -- Собираем все id карт в массив и перемешиваем
    SELECT array_agg(id ORDER BY random())
    INTO v_cards
    FROM Cards
    WHERE round_id = p_round_id;

    -- Раздаём по 3 карты первому игроку (индексы 1-3)
    FOR i IN 1..3 LOOP
        INSERT INTO Cards_on_Hands(player_id, card_id)
        VALUES (p_player1_id, v_cards[i]);
        
        UPDATE Cards SET status = 'на руках' WHERE id = v_cards[i];
    END LOOP;

    -- Раздаём по 3 карты второму игроку (индексы 4-6)
    FOR i IN 4..6 LOOP
        INSERT INTO Cards_on_Hands(player_id, card_id)
        VALUES (p_player2_id, v_cards[i]);
        
        UPDATE Cards SET status = 'на руках' WHERE id = v_cards[i];
    END LOOP;

    -- 7-я карта становится открытым козырем
    v_trump_card_id := v_cards[7];
    UPDATE Cards 
    SET status = 'козырь открыт' 
    WHERE id = v_trump_card_id;

    -- Обновляем козырную масть в раунде
    UPDATE Rounds r
    SET trump_suit = (SELECT suit FROM Cards WHERE id = v_trump_card_id)
    WHERE r.id = p_round_id;

    -- Остальные карты (8-24) остаются в колоде для добора
END;
$$;
