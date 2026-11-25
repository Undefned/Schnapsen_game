-- ===================================================================
-- Тестовый сценарий для игры Шнопс 66 (Schnapsen)
-- ===================================================================
-- Полный цикл игры: регистрация → создание комнаты → игра → победа
-- ===================================================================

SET search_path TO schnapsen;

-- ===================================================================
-- 1. РЕГИСТРАЦИЯ И АВТОРИЗАЦИЯ
-- ===================================================================

-- Шаг 1: Регистрация первого игрока (Анна)
SELECT schnapsen.register_user('anna', 'pass123') AS "1. Регистрация Anna";

-- Шаг 2: Регистрация второго игрока (Борис)
SELECT schnapsen.register_user('boris', 'pass456') AS "2. Регистрация Boris";

-- Шаг 3: Повторная регистрация (должна вернуть ошибку)
SELECT schnapsen.register_user('anna', 'pass123') AS "3. Повторная регистрация (ошибка)";

-- Шаг 4: Логин Анны
SELECT schnapsen.login_user('anna', 'pass123') AS "4. Логин Anna";

-- Шаг 5: Логин с неверным паролем (должна вернуть ошибку)
SELECT schnapsen.login_user('boris', 'wrongpass') AS "5. Неверный пароль (ошибка)";

-- Шаг 6: Правильный логин Бориса
SELECT schnapsen.login_user('boris', 'pass456') AS "6. Логин Boris";

-- Шаг 7: Смотрим созданные токены
SELECT login, 
       LEFT(access_token, 20) || '...' as access_token_preview,
       access_expires > clock_timestamp() as token_valid
FROM schnapsen.Tokens 
ORDER BY created_at AS "7. Токены пользователей";

-- ===================================================================
-- 2. СОЗДАНИЕ ИГРЫ И ПОДКЛЮЧЕНИЕ
-- ===================================================================

-- Сохраняем токены Анны и Бориса во временную таблицу
CREATE TEMP TABLE IF NOT EXISTS test_tokens (
    player VARCHAR(10),
    token TEXT
);

INSERT INTO test_tokens (player, token)
SELECT 'anna', access_token FROM schnapsen.Tokens WHERE login = 'anna' LIMIT 1;

INSERT INTO test_tokens (player, token)
SELECT 'boris', access_token FROM schnapsen.Tokens WHERE login = 'boris' LIMIT 1;

-- Шаг 8: Анна создаёт игру (60 секунд на ход, до 7 поинтов)
SELECT schnapsen.create_game(
    (SELECT token FROM test_tokens WHERE player = 'anna'),
    60,  -- move_time_limit (секунды)
    7    -- points_to_win
) AS "8. Anna создает игру";

-- Сохраняем game_id
CREATE TEMP TABLE IF NOT EXISTS test_game_id (id INT);
INSERT INTO test_game_id (id)
SELECT (result->>'game_id')::INT 
FROM (
    SELECT schnapsen.create_game(
        (SELECT token FROM test_tokens WHERE player = 'anna'),
        60, 7
    ) as result
) subq
WHERE result->>'game_id' IS NOT NULL
ON CONFLICT DO NOTHING;

-- Шаг 9: Борис подключается к игре (должен автостартовать раунд)
SELECT schnapsen.join_game(
    (SELECT token FROM test_tokens WHERE player = 'boris'),
    (SELECT id FROM test_game_id LIMIT 1)
) AS "9. Boris подключается к игре";

-- Шаг 10: Смотрим статус игры
SELECT id, status, creator_login, move_time_limit, points_to_win, date_time_start
FROM schnapsen.Games AS "10. Статус игры";

-- Шаг 11: Смотрим игроков
SELECT p.id as player_id, p.login, p.seat_number, p.game_points
FROM schnapsen.Players p
WHERE p.game_id = (SELECT id FROM test_game_id LIMIT 1)
ORDER BY p.seat_number AS "11. Игроки в партии";

-- ===================================================================
-- 3. ИГРОВОЕ СОСТОЯНИЕ
-- ===================================================================

-- Шаг 12: Анна смотрит состояние игры
SELECT schnapsen.get_game_state(
    (SELECT token FROM test_tokens WHERE player = 'anna'),
    (SELECT id FROM test_game_id LIMIT 1)
) AS "12. Состояние игры (Anna)";

-- Шаг 13: Борис смотрит состояние игры
SELECT schnapsen.get_game_state(
    (SELECT token FROM test_tokens WHERE player = 'boris'),
    (SELECT id FROM test_game_id LIMIT 1)
) AS "13. Состояние игры (Boris)";

-- Шаг 14: Смотрим активный раунд
SELECT r.id as round_id, r.round_number, r.trump_suit, r.status,
       p.login as dealer
FROM schnapsen.Rounds r
JOIN schnapsen.Players p ON p.id = r.dealer_player_id
WHERE r.game_id = (SELECT id FROM test_game_id LIMIT 1)
  AND r.status = 'активный' AS "14. Активный раунд";

-- Шаг 15: Смотрим карты в колоде
SELECT id, rank, suit, card_value, status
FROM schnapsen.Cards
WHERE round_id = (
    SELECT id FROM schnapsen.Rounds 
    WHERE game_id = (SELECT id FROM test_game_id LIMIT 1) 
      AND status = 'активный'
    LIMIT 1
)
ORDER BY status, suit, rank AS "15. Карты в раунде";

-- Шаг 16: Смотрим карты на руках у игроков
SELECT p.login, c.rank, c.suit, c.card_value
FROM schnapsen.Cards_on_Hands ch
JOIN schnapsen.Cards c ON c.id = ch.card_id
JOIN schnapsen.Players p ON p.id = ch.player_id
WHERE p.game_id = (SELECT id FROM test_game_id LIMIT 1)
ORDER BY p.seat_number, c.suit, c.rank AS "16. Карты на руках игроков";

-- Шаг 17: Смотрим козырную карту
SELECT rank, suit, card_value, status
FROM schnapsen.Cards
WHERE round_id = (
    SELECT id FROM schnapsen.Rounds 
    WHERE game_id = (SELECT id FROM test_game_id LIMIT 1) 
      AND status = 'активный'
)
  AND status = 'козырь открыт' AS "17. Козырная карта";

-- Шаг 18: Смотрим текущий ход
SELECT cm.player_id, p.login as current_player, cm.date_time_start
FROM schnapsen.Current_Move cm
JOIN schnapsen.Players p ON p.id = cm.player_id
WHERE cm.round_id = (
    SELECT id FROM schnapsen.Rounds 
    WHERE game_id = (SELECT id FROM test_game_id LIMIT 1) 
      AND status = 'активный'
) AS "18. Текущий ход";

-- ===================================================================
-- 4. ИГРОВЫЕ ДЕЙСТВИЯ (ПРИМЕРЫ)
-- ===================================================================

-- Шаг 19: Текущий игрок играет первую карту
-- (Здесь нужно подставить реальный card_id с руки текущего игрока)
-- Пример: SELECT schnapsen.play_card(token, game_id, card_id);
SELECT 'Для теста игровых действий нужно вручную подставить card_id из шага 16' AS "19. Пример хода";

-- Шаг 20: Пример объявления марьяжа
-- SELECT schnapsen.declare_marriage(token, game_id, king_card_id, queen_card_id);
SELECT 'Для объявления марьяжа нужны K и Q одной масти с руки' AS "20. Пример марьяжа";

-- Шаг 21: Пример объявления шнапса
-- SELECT schnapsen.declare_schnapsen(token, game_id);
SELECT 'Объявить шнапс можно при >= 66 очков' AS "21. Пример шнапса";

-- ===================================================================
-- 5. СТАТИСТИКА И ПРОВЕРКИ
-- ===================================================================

-- Шаг 22: Общий счёт очков в раунде
SELECT p.login, rs.round_score, rs.schnapsen_declared
FROM schnapsen.Round_Scores rs
JOIN schnapsen.Players p ON p.id = rs.player_id
WHERE rs.round_id = (
    SELECT id FROM schnapsen.Rounds 
    WHERE game_id = (SELECT id FROM test_game_id LIMIT 1) 
      AND status = 'активный'
)
ORDER BY p.seat_number AS "22. Счёт игроков в раунде";

-- Шаг 23: История ходов
SELECT m.move_number, p.login, c.rank, c.suit, m.date_time_start
FROM schnapsen.Moves m
JOIN schnapsen.Players p ON p.id = m.player_id
JOIN schnapsen.Cards c ON c.id = m.card_id
WHERE m.round_id = (
    SELECT id FROM schnapsen.Rounds 
    WHERE game_id = (SELECT id FROM test_game_id LIMIT 1) 
      AND status = 'активный'
)
ORDER BY m.move_number AS "23. История ходов";

-- Шаг 24: Взятки
SELECT t.trick_number, p.login as winner, t.points_value,
       c1.rank || c1.suit as first_card,
       c2.rank || c2.suit as second_card
FROM schnapsen.Tricks t
JOIN schnapsen.Players p ON p.id = t.winner_player_id
JOIN schnapsen.Cards c1 ON c1.id = t.first_card_id
JOIN schnapsen.Cards c2 ON c2.id = t.second_card_id
WHERE t.round_id = (
    SELECT id FROM schnapsen.Rounds 
    WHERE game_id = (SELECT id FROM test_game_id LIMIT 1) 
      AND status = 'активный'
)
ORDER BY t.trick_number AS "24. Взятки";

-- Шаг 25: Объявленные марьяжи
SELECT p.login, m.suit, m.is_trump, m.bonus_points, m.date_time
FROM schnapsen.Marriages m
JOIN schnapsen.Players p ON p.id = m.player_id
WHERE m.round_id = (
    SELECT id FROM schnapsen.Rounds 
    WHERE game_id = (SELECT id FROM test_game_id LIMIT 1) 
      AND status = 'активный'
)
ORDER BY m.date_time AS "25. Марьяжи";

-- ===================================================================
-- 6. ЗАВЕРШЕНИЕ И ВЫХОД
-- ===================================================================

-- Шаг 26: Анна выходит из игры (техническая победа Бориса)
SELECT schnapsen.leave_game(
    (SELECT token FROM test_tokens WHERE player = 'anna'),
    (SELECT id FROM test_game_id LIMIT 1)
) AS "26. Anna покидает игру";

-- Шаг 27: Финальное состояние игры
SELECT id, status, date_time_end
FROM schnapsen.Games
WHERE id = (SELECT id FROM test_game_id LIMIT 1) AS "27. Финальное состояние игры";

-- Шаг 28: Финальный счёт игроков
SELECT p.login, p.game_points
FROM schnapsen.Players p
WHERE p.game_id = (SELECT id FROM test_game_id LIMIT 1)
ORDER BY p.game_points DESC AS "28. Финальный счёт";

-- Шаг 29: Выход Бориса из системы
SELECT schnapsen.logout_user(
    (SELECT token FROM test_tokens WHERE player = 'boris')
) AS "29. Boris выходит из системы";

-- ===================================================================
-- CLEANUP (очистка временных таблиц)
-- ===================================================================
DROP TABLE IF EXISTS test_tokens;
DROP TABLE IF EXISTS test_game_id;

-- ===================================================================
-- КОНЕЦ СЦЕНАРИЯ
-- ===================================================================
SELECT 'Тестовый сценарий завершён' AS "Статус";
