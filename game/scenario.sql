SET search_path TO schnapsen;

-- полный сценарий шнапс 66. гоняем на отдельной тестовой бд
TRUNCATE Schnapsen_declarations, Round_winner, Cards_in_trick, Tricks,
         Cards_in_hand, Moves, Cards, Rounds, Players, Games, Tokens, Users
RESTART IDENTITY CASCADE;

-- временые таблички чтобы таскать токены, id игры и карты между шагами
CREATE TEMP TABLE test_tokens (
    player TEXT PRIMARY KEY,
    token TEXT NOT NULL
);
CREATE TEMP TABLE test_game (id INT PRIMARY KEY);
CREATE TEMP TABLE test_cards (
    player TEXT PRIMARY KEY,
    card_id INT NOT NULL
);

-- =====================================================================
-- 1. юзеры и авторизация
-- =====================================================================

-- регаем двух игроков
SELECT schnapsen.register_user('anna', 'pass123') AS anna_registration;
SELECT schnapsen.register_user('boris', 'pass456') AS boris_registration;

-- смотрим что пароли похешировались (длина хеша должна быть 32)
SELECT login, name, length(password) AS password_hash_length
FROM schnapsen.Users
ORDER BY login;

-- логинимся и сразу складываем access_token в временую таблицу
INSERT INTO test_tokens(player, token)
SELECT 'anna', (schnapsen.login_user('anna', 'pass123')->>'access_token');
INSERT INTO test_tokens(player, token)
SELECT 'boris', (schnapsen.login_user('boris', 'pass456')->>'access_token');

-- проверяем что токены ещё живые
SELECT login,
       access_expires > clock_timestamp() AS access_token_valid,
       refresh_expires > clock_timestamp() AS refresh_token_valid
FROM schnapsen.Tokens
ORDER BY login, created_at;

-- анна заходит со второго устройства - должен появиться ещё один токен
SELECT schnapsen.login_user('anna', 'pass123') AS anna_second_device;
SELECT login, count(*) AS token_count
FROM schnapsen.Tokens
GROUP BY login
ORDER BY login;

-- =====================================================================
-- 2. создаём игру и стартуем раунд
-- =====================================================================

-- анна создаёт игру на 60 сек хода и до 7 поинтов, id сразу в temp
INSERT INTO test_game(id)
SELECT (schnapsen.create_game(
    (SELECT token FROM test_tokens WHERE player = 'anna'),
    60,
    7
)->>'game_id')::INT;

-- смотрим что игра создалась с нужными настройками
SELECT g.id, g.move_time_limit, g.points_to_win
FROM schnapsen.Games g
WHERE g.id = (SELECT id FROM test_game);

-- борис подключается - раунд должен стартануть автоматом
SELECT schnapsen.join_game(
    (SELECT token FROM test_tokens WHERE player = 'boris'),
    (SELECT id FROM test_game)
) AS join_result;

-- оба игрока за столом, у каждого по нулям
SELECT p.id AS player_id, p.login, p.seat_number, p.round_score
FROM schnapsen.Players p
WHERE p.game_id = (SELECT id FROM test_game)
ORDER BY p.seat_number;

-- смотрим какой раунд и какой козырь выпал
SELECT r.id AS round_id, r.round_number, r.trump_suit, r.game_id
FROM schnapsen.Rounds r
WHERE r.game_id = (SELECT id FROM test_game)
ORDER BY r.round_number;

-- =====================================================================
-- 3. раздача и состояние игры
-- =====================================================================

-- все карты этой игры с очками из справочника рангов
SELECT c.id, c.suit, c.rank, r.points
FROM schnapsen.Cards c
JOIN schnapsen.Ranks r ON r.rank = c.rank
WHERE c.game_id = (SELECT id FROM test_game)
ORDER BY c.id;

-- кто что получил на руки
SELECT p.login, c.id AS card_id, c.suit, c.rank, r.points
FROM schnapsen.Cards_in_hand h
JOIN schnapsen.Players p ON p.id = h.player_id
JOIN schnapsen.Cards c ON c.id = h.card_id
JOIN schnapsen.Ranks r ON r.rank = c.rank
WHERE p.game_id = (SELECT id FROM test_game)
ORDER BY p.seat_number, c.id;

-- каждый смотрит своё состояние
SELECT schnapsen.get_game_state(
    (SELECT token FROM test_tokens WHERE player = 'anna'),
    (SELECT id FROM test_game)
) AS anna_state;

SELECT schnapsen.get_game_state(
    (SELECT token FROM test_tokens WHERE player = 'boris'),
    (SELECT id FROM test_game)
) AS boris_state;

-- =====================================================================
-- 4. первая взятка
-- =====================================================================

-- первые шесть карт у анны, следующие шесть у бориса
-- берём карту по реальной руке, а не по serial id
INSERT INTO test_cards(player, card_id)
SELECT 'anna', min(h.card_id)
FROM schnapsen.Cards_in_hand h
JOIN schnapsen.Players p ON p.id = h.player_id
WHERE p.login = 'anna' AND p.game_id = (SELECT id FROM test_game);

INSERT INTO test_cards(player, card_id)
SELECT 'boris', min(h.card_id)
FROM schnapsen.Cards_in_hand h
JOIN schnapsen.Players p ON p.id = h.player_id
WHERE p.login = 'boris' AND p.game_id = (SELECT id FROM test_game);

-- анна ходит первой
SELECT schnapsen.play_card(
    (SELECT token FROM test_tokens WHERE player = 'anna'),
    (SELECT id FROM test_game),
    (SELECT card_id FROM test_cards WHERE player = 'anna')
) AS anna_first_card;

-- борис отбивается
SELECT schnapsen.play_card(
    (SELECT token FROM test_tokens WHERE player = 'boris'),
    (SELECT id FROM test_game),
    (SELECT card_id FROM test_cards WHERE player = 'boris')
) AS boris_response;

-- история ходов
SELECT m.id, p.login, m.start_time
FROM schnapsen.Moves m
JOIN schnapsen.Players p ON p.id = m.player_id
WHERE p.game_id = (SELECT id FROM test_game)
ORDER BY m.id;

-- кто взял взятку и какими картами
SELECT t.id AS trick_id, t.round_id, winner.login AS winner,
       c.suit, c.rank
FROM schnapsen.Tricks t
JOIN schnapsen.Players winner ON winner.id = t.winner_id
JOIN schnapsen.Cards_in_trick cit ON cit.trick_id = t.id
JOIN schnapsen.Cards c ON c.id = cit.card_id
WHERE t.round_id = (SELECT id FROM schnapsen.Rounds WHERE game_id = (SELECT id FROM test_game))
ORDER BY t.id, c.id;

-- счёт после взятки
SELECT p.login, p.round_score
FROM schnapsen.Players p
WHERE p.game_id = (SELECT id FROM test_game)
ORDER BY p.seat_number;

-- =====================================================================
-- 5. марьяж и шнапс
-- =====================================================================

-- пробуем объявить марьяж: ищем K и Q одной масти у анны
SELECT schnapsen.declare_marriage(
    (SELECT token FROM test_tokens WHERE player = 'anna'),
    (SELECT id FROM test_game),
    (SELECT k.id
     FROM schnapsen.Cards_in_hand h
     JOIN schnapsen.Cards k ON k.id = h.card_id AND k.rank = 'K'
     JOIN schnapsen.Cards q ON q.game_id = k.game_id AND q.suit = k.suit AND q.rank = 'Q'
     JOIN schnapsen.Cards_in_hand hq ON hq.card_id = q.id AND hq.player_id = h.player_id
     JOIN schnapsen.Players p ON p.id = h.player_id
     WHERE p.login = 'anna' AND p.game_id = (SELECT id FROM test_game)
     LIMIT 1),
    (SELECT q.id
     FROM schnapsen.Cards_in_hand h
     JOIN schnapsen.Cards k ON k.id = h.card_id AND k.rank = 'K'
     JOIN schnapsen.Cards q ON q.game_id = k.game_id AND q.suit = k.suit AND q.rank = 'Q'
     JOIN schnapsen.Cards_in_hand hq ON hq.card_id = q.id AND hq.player_id = h.player_id
     JOIN schnapsen.Players p ON p.id = h.player_id
     WHERE p.login = 'anna' AND p.game_id = (SELECT id FROM test_game)
     LIMIT 1)
) AS marriage_result;

-- смотрим что записалось в декларации
SELECT d.round_id, p.login, d.point_declared
FROM schnapsen.Schnapsen_declarations d
JOIN schnapsen.Players p ON p.id = d.player_id
WHERE d.round_id = (SELECT id FROM schnapsen.Rounds WHERE game_id = (SELECT id FROM test_game));

-- пробуем объявить шнапс (должен быть ложный, очков мало)
SELECT schnapsen.declare_schnapsen(
    (SELECT token FROM test_tokens WHERE player = 'anna'),
    (SELECT id FROM test_game)
) AS schnapsen_result;

-- =====================================================================
-- 6. финальное состояние бд
-- =====================================================================

-- состояние игры
SELECT * FROM schnapsen.Games
WHERE id = (SELECT id FROM test_game);

-- счёт игроков
SELECT p.login, p.seat_number, p.round_score
FROM schnapsen.Players p
WHERE p.game_id = (SELECT id FROM test_game)
ORDER BY p.seat_number;

-- раунды
SELECT * FROM schnapsen.Rounds
WHERE game_id = (SELECT id FROM test_game)
ORDER BY round_number;

-- что осталось на руках
SELECT * FROM schnapsen.Cards_in_hand
ORDER BY player_id, card_id;

-- карты во взятках
SELECT * FROM schnapsen.Cards_in_trick
ORDER BY trick_id, card_id;

-- сами взятки
SELECT * FROM schnapsen.Tricks
ORDER BY id;

-- борис выходит из игры
SELECT schnapsen.leave_game(
    (SELECT token FROM test_tokens WHERE player = 'boris'),
    (SELECT id FROM test_game)
) AS leave_result;

-- оба разлогиниваются
SELECT schnapsen.logout_user(
    (SELECT token FROM test_tokens WHERE player = 'anna')
) AS anna_logout;

SELECT schnapsen.logout_user(
    (SELECT token FROM test_tokens WHERE player = 'boris')
) AS boris_logout;

-- чистим временые таблицы
DROP TABLE test_cards;
DROP TABLE test_tokens;
DROP TABLE test_game;