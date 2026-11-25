SET search_path TO schnapsen;

-- Этап 1. Авторизация. Сценарий рассчитан на отдельную тестовую БД.
TRUNCATE Schnapsen_declarations, Cards_in_trick, Tricks, Cards_in_hand,
         Moves, Cards, Rounds, Players, Games, Tokens, Users
RESTART IDENTITY CASCADE;

CREATE TEMP TABLE test_tokens (
    player TEXT PRIMARY KEY,
    token TEXT NOT NULL
);

-- 1. Регистрация пользователей.
SELECT schnapsen.register_user('anna', 'pass123') AS anna_registration;
SELECT schnapsen.register_user('boris', 'pass456') AS boris_registration;

-- 2. Проверка сохранённых пользователей.
SELECT login, name, length(password) AS password_hash_length
FROM schnapsen.Users
ORDER BY login;

-- 3. Авторизация и сохранение access token для следующих этапов.
INSERT INTO test_tokens (player, token)
SELECT 'anna', (schnapsen.login_user('anna', 'pass123')->>'access_token');

INSERT INTO test_tokens (player, token)
SELECT 'boris', (schnapsen.login_user('boris', 'pass456')->>'access_token');

-- 4. Проверка действующих токенов.
SELECT login, access_expires > clock_timestamp() AS access_token_valid,
       refresh_expires > clock_timestamp() AS refresh_token_valid
FROM schnapsen.Tokens
ORDER BY login, created_at;

-- 5. Второй вход Anna создаёт отдельное устройство/токен.
SELECT schnapsen.login_user('anna', 'pass123') AS anna_second_login;

-- 6. Проверка количества устройств.
SELECT login, count(*) AS active_tokens
FROM schnapsen.Tokens
GROUP BY login
ORDER BY login;

-- 7. Проверка logout одного токена Boris.
SELECT schnapsen.logout_user(
    (SELECT token FROM test_tokens WHERE player = 'boris')
) AS boris_logout;

SELECT count(*) AS boris_tokens_after_logout
FROM schnapsen.Tokens
WHERE login = 'boris';

DROP TABLE test_tokens;
