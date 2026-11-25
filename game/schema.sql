BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS schnapsen;
SET search_path TO schnapsen;
SET TIME ZONE 'UTC';

-- Пользователи приложения. Таблица Tokens оставлена отдельно для API/JWT.
CREATE TABLE Users (
    login VARCHAR(30) PRIMARY KEY,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(30) NOT NULL
);

CREATE TABLE Tokens (
    id SERIAL PRIMARY KEY,
    login VARCHAR(30) NOT NULL
        REFERENCES Users(login) ON DELETE CASCADE ON UPDATE CASCADE,
    access_token TEXT NOT NULL UNIQUE,
    refresh_token TEXT NOT NULL UNIQUE,
    access_expires TIMESTAMP NOT NULL,
    refresh_expires TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Games (
    id SERIAL PRIMARY KEY,
    move_time_limit SMALLINT NOT NULL CHECK (move_time_limit > 0),
    points_to_win SMALLINT NOT NULL CHECK (points_to_win > 0 AND points_to_win <= 7)
);

CREATE TABLE Players (
    id SERIAL PRIMARY KEY,
    seat_number SMALLINT NOT NULL CHECK (seat_number IN (1, 2)),
    round_score SMALLINT NOT NULL DEFAULT 0 CHECK (round_score >= 0),
    game_id INT NOT NULL REFERENCES Games(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    login VARCHAR(30) NOT NULL REFERENCES Users(login)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    UNIQUE (game_id, login),
    UNIQUE (game_id, seat_number)
);

CREATE TABLE Rounds (
    id SERIAL PRIMARY KEY,
    round_number SMALLINT NOT NULL CHECK (round_number > 0),
    trump_suit VARCHAR(10) NOT NULL
        CHECK (trump_suit IN ('hearts', 'diamonds', 'clubs', 'spades')),
    game_id INT NOT NULL REFERENCES Games(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE (game_id, round_number)
);

CREATE TABLE Ranks (
    rank VARCHAR(2) PRIMARY KEY
        CHECK (rank IN ('9', 'J', 'Q', 'K', '10', 'A')),
    points SMALLINT NOT NULL CHECK (points >= 0)
);

CREATE TABLE Cards (
    id SERIAL PRIMARY KEY,
    suit VARCHAR(10) NOT NULL
        CHECK (suit IN ('spades', 'hearts', 'diamonds', 'clubs')),
    rank VARCHAR(2) NOT NULL REFERENCES Ranks(rank)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    game_id INT NOT NULL REFERENCES Games(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE (game_id, suit, rank)
);

CREATE TABLE Tricks (
    id SERIAL PRIMARY KEY,
    round_id INT NOT NULL REFERENCES Rounds(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    winner_id INT NOT NULL REFERENCES Players(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    UNIQUE (round_id, id)
);

CREATE TABLE Cards_in_trick (
    card_id INT NOT NULL REFERENCES Cards(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    trick_id INT NOT NULL REFERENCES Tricks(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (card_id, trick_id)
);

CREATE TABLE Cards_in_hand (
    card_id INT NOT NULL REFERENCES Cards(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    player_id INT NOT NULL REFERENCES Players(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (card_id, player_id),
    UNIQUE (card_id)
);

CREATE TABLE Moves (
    id SERIAL PRIMARY KEY,
    player_id INT NOT NULL REFERENCES Players(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    start_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Round_winner (
    round_id INT PRIMARY KEY REFERENCES Rounds(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    player_id INT NOT NULL REFERENCES Players(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Schnapsen_declarations (
    round_id INT PRIMARY KEY REFERENCES Rounds(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    point_declared SMALLINT NOT NULL CHECK (point_declared >= 0),
    player_id INT NOT NULL REFERENCES Players(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

COMMIT;
