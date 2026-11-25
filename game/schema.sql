BEGIN;
CREATE SCHEMA IF NOT EXISTS schnapsen;
SET search_path TO schnapsen;
SET TIME ZONE 'UTC';

-- Пользователи
CREATE TABLE IF NOT EXISTS Users (
    login VARCHAR(30) PRIMARY KEY,
    password VARCHAR(100) NOT NULL, -- для bcrypt хеша нужно больше места
    name VARCHAR(50),
    registration TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- JWT токены для авторизации
CREATE TABLE IF NOT EXISTS Tokens (
    id SERIAL PRIMARY KEY,
    login VARCHAR(30) NOT NULL REFERENCES Users(login) ON DELETE CASCADE ON UPDATE CASCADE,
    access_token TEXT NOT NULL UNIQUE,
    refresh_token TEXT NOT NULL UNIQUE,
    access_expires TIMESTAMP NOT NULL,
    refresh_expires TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Игровые комнаты
CREATE TABLE IF NOT EXISTS Games (
    id SERIAL PRIMARY KEY,
    creator_login VARCHAR(30) NOT NULL REFERENCES Users(login) ON DELETE CASCADE ON UPDATE CASCADE,
    move_time_limit INT NOT NULL CHECK (move_time_limit > 0), -- секунды на ход
    points_to_win INT NOT NULL CHECK (points_to_win > 0 AND points_to_win <= 7), -- до скольких поинтов играем
    status VARCHAR(15) NOT NULL CHECK (status IN ('открыта', 'идёт игра', 'завершена')),
    date_time_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_time_start TIMESTAMP,
    date_time_end TIMESTAMP
);

-- Игроки в партии
CREATE TABLE IF NOT EXISTS Players (
    id SERIAL PRIMARY KEY,
    game_id INT NOT NULL REFERENCES Games(id) ON DELETE CASCADE ON UPDATE CASCADE,
    login VARCHAR(30) NOT NULL REFERENCES Users(login) ON DELETE CASCADE ON UPDATE CASCADE,
    seat_number INT NOT NULL CHECK (seat_number IN (1, 2)), -- Шнопс только для 2 игроков
    game_points INT NOT NULL DEFAULT 0 CHECK (game_points >= 0), -- накопленные поинты (очки партии)
    UNIQUE (game_id, login),
    UNIQUE (game_id, seat_number)
);

-- Раунды внутри партии
CREATE TABLE IF NOT EXISTS Rounds (
    id SERIAL PRIMARY KEY,
    game_id INT NOT NULL REFERENCES Games(id) ON DELETE CASCADE ON UPDATE CASCADE,
    round_number INT NOT NULL CHECK (round_number > 0),
    trump_suit VARCHAR(10) NOT NULL CHECK (trump_suit IN ('hearts', 'diamonds', 'clubs', 'spades')),
    dealer_player_id INT NOT NULL REFERENCES Players(id) ON DELETE CASCADE ON UPDATE CASCADE,
    status VARCHAR(15) NOT NULL CHECK (status IN ('активный', 'завершён')),
    date_time_start TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_time_end TIMESTAMP,
    UNIQUE (game_id, round_number)
);

-- Карты в раунде (колода)
CREATE TABLE IF NOT EXISTS Cards (
    id SERIAL PRIMARY KEY,
    round_id INT NOT NULL REFERENCES Rounds(id) ON DELETE CASCADE ON UPDATE CASCADE,
    rank VARCHAR(5) NOT NULL CHECK (rank IN ('9', '10', 'J', 'Q', 'K', 'A')),
    suit VARCHAR(10) NOT NULL CHECK (suit IN ('hearts', 'diamonds', 'clubs', 'spades')),
    card_value INT NOT NULL CHECK (card_value >= 0), -- очковая стоимость: A=11, 10=10, K=4, Q=3, J=2, 9=0
    status VARCHAR(15) NOT NULL CHECK (status IN ('в колоде', 'на руках', 'разыграна', 'козырь открыт')),
    UNIQUE (round_id, rank, suit)
);

-- Карты на руках у игроков
CREATE TABLE IF NOT EXISTS Cards_on_Hands (
    player_id INT REFERENCES Players(id) ON DELETE CASCADE ON UPDATE CASCADE,
    card_id INT NOT NULL UNIQUE REFERENCES Cards(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (player_id, card_id)
);

-- Ходы игроков (история)
CREATE TABLE IF NOT EXISTS Moves (
    id SERIAL PRIMARY KEY,
    round_id INT NOT NULL REFERENCES Rounds(id) ON DELETE CASCADE ON UPDATE CASCADE,
    player_id INT NOT NULL REFERENCES Players(id) ON DELETE CASCADE ON UPDATE CASCADE,
    card_id INT NOT NULL REFERENCES Cards(id) ON DELETE CASCADE ON UPDATE CASCADE,
    move_number INT NOT NULL CHECK (move_number > 0), -- порядковый номер хода в раунде
    date_time_start TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (round_id, move_number)
);

-- Текущий ход (кто сейчас ходит)
CREATE TABLE IF NOT EXISTS Current_Move (
    round_id INT PRIMARY KEY REFERENCES Rounds(id) ON DELETE CASCADE ON UPDATE CASCADE,
    player_id INT NOT NULL REFERENCES Players(id) ON DELETE CASCADE ON UPDATE CASCADE,
    date_time_start TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Взятки (кто взял, какие карты, сколько очков)
CREATE TABLE IF NOT EXISTS Tricks (
    id SERIAL PRIMARY KEY,
    round_id INT NOT NULL REFERENCES Rounds(id) ON DELETE CASCADE ON UPDATE CASCADE,
    trick_number INT NOT NULL CHECK (trick_number > 0),
    winner_player_id INT NOT NULL REFERENCES Players(id) ON DELETE CASCADE ON UPDATE CASCADE,
    first_card_id INT NOT NULL REFERENCES Cards(id) ON DELETE CASCADE ON UPDATE CASCADE,
    second_card_id INT NOT NULL REFERENCES Cards(id) ON DELETE CASCADE ON UPDATE CASCADE,
    points_value INT NOT NULL DEFAULT 0 CHECK (points_value >= 0), -- очки за взятку
    date_time_end TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (round_id, trick_number)
);

-- Очки игроков в раунде
CREATE TABLE IF NOT EXISTS Round_Scores (
    player_id INT PRIMARY KEY REFERENCES Players(id) ON DELETE CASCADE ON UPDATE CASCADE,
    round_id INT NOT NULL REFERENCES Rounds(id) ON DELETE CASCADE ON UPDATE CASCADE,
    round_score INT NOT NULL DEFAULT 0 CHECK (round_score >= 0), -- накопленные очки в раунде
    schnapsen_declared BOOLEAN NOT NULL DEFAULT FALSE, -- объявил ли шнапс
    UNIQUE (player_id, round_id)
);

-- Марьяжи (объявления K+Q одной масти)
CREATE TABLE IF NOT EXISTS Marriages (
    id SERIAL PRIMARY KEY,
    round_id INT NOT NULL REFERENCES Rounds(id) ON DELETE CASCADE ON UPDATE CASCADE,
    player_id INT NOT NULL REFERENCES Players(id) ON DELETE CASCADE ON UPDATE CASCADE,
    suit VARCHAR(10) NOT NULL CHECK (suit IN ('hearts', 'diamonds', 'clubs', 'spades')),
    is_trump BOOLEAN NOT NULL, -- козырный марьяж = 40, не козырный = 20
    bonus_points INT NOT NULL CHECK (bonus_points IN (20, 40)),
    date_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Победители раундов
CREATE TABLE IF NOT EXISTS Round_Winners (
    round_id INT PRIMARY KEY REFERENCES Rounds(id) ON DELETE CASCADE ON UPDATE CASCADE,
    winner_player_id INT NOT NULL REFERENCES Players(id) ON DELETE CASCADE ON UPDATE CASCADE,
    points_awarded INT NOT NULL CHECK (points_awarded IN (1, 2, 3)), -- 1/2/3 поинта за раунд
    date_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMIT;
