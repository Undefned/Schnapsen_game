SET search_path TO schnapsen;

-- Полный сценарий Schnapsen 66. Запускается на отдельной тестовой БД.
TRUNCATE Schnapsen_declarations, Round_winner, Cards_in_trick, Tricks,
         Cards_in_hand, Moves, Cards, Rounds, Players, Games, Tokens, Users
RESTART IDENTITY CASCADE;

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
-- 1. USERS AND AUTHENTICATION
-- =====================================================================

SELECT schnapsen.register_user('anna', 'pass123') AS anna_registration;
SELECT schnapsen.register_user('boris', 'pass456') AS boris_registration;

SELECT login, name, length(password) AS password_hash_length
FROM schnapsen.Users
ORDER BY login;

INSERT INTO test_tokens(player, token)
SELECT 'anna', (schnapsen.login_user('anna', 'pass123')->>'access_token');
INSERT INTO test_tokens(player, token)
SELECT 'boris', (schnapsen.login_user('boris', 'pass456')->>'access_token');

SELECT login,
       access_expires > clock_timestamp() AS access_token_valid,
       refresh_expires > clock_timestamp() AS refresh_token_valid
FROM schnapsen.Tokens
ORDER BY login, created_at;

SELECT schnapsen.login_user('anna', 'pass123') AS anna_second_device;
SELECT login, count(*) AS token_count
FROM schnapsen.Tokens
GROUP BY login
ORDER BY login;

-- =====================================================================
-- 2. GAME CREATION AND ROUND START
-- =====================================================================

INSERT INTO test_game(id)
SELECT (schnapsen.create_game(
    (SELECT token FROM test_tokens WHERE player = 'anna'),
    60,
    7
)->>'game_id')::INT;

SELECT g.id, g.move_time_limit, g.points_to_win
FROM schnapsen.Games g
WHERE g.id = (SELECT id FROM test_game);

SELECT schnapsen.join_game(
    (SELECT token FROM test_tokens WHERE player = 'boris'),
    (SELECT id FROM test_game)
) AS join_result;

SELECT p.id AS player_id, p.login, p.seat_number, p.round_score
FROM schnapsen.Players p
WHERE p.game_id = (SELECT id FROM test_game)
ORDER BY p.seat_number;

SELECT r.id AS round_id, r.round_number, r.trump_suit, r.game_id
FROM schnapsen.Rounds r
WHERE r.game_id = (SELECT id FROM test_game)
ORDER BY r.round_number;

-- =====================================================================
-- 3. DEAL AND GAME STATE
-- =====================================================================

SELECT c.id, c.suit, c.rank, r.points
FROM schnapsen.Cards c
JOIN schnapsen.Ranks r ON r.rank = c.rank
WHERE c.game_id = (SELECT id FROM test_game)
ORDER BY c.id;

SELECT p.login, c.id AS card_id, c.suit, c.rank, r.points
FROM schnapsen.Cards_in_hand h
JOIN schnapsen.Players p ON p.id = h.player_id
JOIN schnapsen.Cards c ON c.id = h.card_id
JOIN schnapsen.Ranks r ON r.rank = c.rank
WHERE p.game_id = (SELECT id FROM test_game)
ORDER BY p.seat_number, c.id;

SELECT schnapsen.get_game_state(
    (SELECT token FROM test_tokens WHERE player = 'anna'),
    (SELECT id FROM test_game)
) AS anna_state;

SELECT schnapsen.get_game_state(
    (SELECT token FROM test_tokens WHERE player = 'boris'),
    (SELECT id FROM test_game)
) AS boris_state;

-- =====================================================================
-- 4. FIRST TRICK
-- =====================================================================

-- The first six cards belong to Anna and the next six to Boris.
-- Select cards by the actual hand instead of relying on SERIAL values.
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

SELECT schnapsen.play_card(
    (SELECT token FROM test_tokens WHERE player = 'anna'),
    (SELECT id FROM test_game),
    (SELECT card_id FROM test_cards WHERE player = 'anna')
) AS anna_first_card;

SELECT schnapsen.play_card(
    (SELECT token FROM test_tokens WHERE player = 'boris'),
    (SELECT id FROM test_game),
    (SELECT card_id FROM test_cards WHERE player = 'boris')
) AS boris_response;

SELECT m.id, p.login, m.start_time
FROM schnapsen.Moves m
JOIN schnapsen.Players p ON p.id = m.player_id
WHERE p.game_id = (SELECT id FROM test_game)
ORDER BY m.id;

SELECT t.id AS trick_id, t.round_id, winner.login AS winner,
       c.suit, c.rank
FROM schnapsen.Tricks t
JOIN schnapsen.Players winner ON winner.id = t.winner_id
JOIN schnapsen.Cards_in_trick cit ON cit.trick_id = t.id
JOIN schnapsen.Cards c ON c.id = cit.card_id
WHERE t.round_id = (SELECT id FROM schnapsen.Rounds WHERE game_id = (SELECT id FROM test_game))
ORDER BY t.id, c.id;

SELECT p.login, p.round_score
FROM schnapsen.Players p
WHERE p.game_id = (SELECT id FROM test_game)
ORDER BY p.seat_number;

-- =====================================================================
-- 5. MARRIAGE AND SCHNAPSEN
-- =====================================================================

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

SELECT d.round_id, p.login, d.point_declared
FROM schnapsen.Schnapsen_declarations d
JOIN schnapsen.Players p ON p.id = d.player_id
WHERE d.round_id = (SELECT id FROM schnapsen.Rounds WHERE game_id = (SELECT id FROM test_game));

SELECT schnapsen.declare_schnapsen(
    (SELECT token FROM test_tokens WHERE player = 'anna'),
    (SELECT id FROM test_game)
) AS schnapsen_result;

-- =====================================================================
-- 6. FINAL DATABASE STATE
-- =====================================================================

SELECT * FROM schnapsen.Games
WHERE id = (SELECT id FROM test_game);

SELECT p.login, p.seat_number, p.round_score
FROM schnapsen.Players p
WHERE p.game_id = (SELECT id FROM test_game)
ORDER BY p.seat_number;

SELECT * FROM schnapsen.Rounds
WHERE game_id = (SELECT id FROM test_game)
ORDER BY round_number;

SELECT * FROM schnapsen.Cards_in_hand
ORDER BY player_id, card_id;

SELECT * FROM schnapsen.Cards_in_trick
ORDER BY trick_id, card_id;

SELECT * FROM schnapsen.Tricks
ORDER BY id;

SELECT schnapsen.leave_game(
    (SELECT token FROM test_tokens WHERE player = 'boris'),
    (SELECT id FROM test_game)
) AS leave_result;

SELECT schnapsen.logout_user(
    (SELECT token FROM test_tokens WHERE player = 'anna')
) AS anna_logout;

SELECT schnapsen.logout_user(
    (SELECT token FROM test_tokens WHERE player = 'boris')
) AS boris_logout;

DROP TABLE test_cards;
DROP TABLE test_tokens;
DROP TABLE test_game;
