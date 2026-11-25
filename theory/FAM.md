# Полная атрибутивная модель (FAM)

Построена на основе итоговой декомпозированной схемы (после декомпозиции Карт по правилу Хеза): 12 отношений → 12 таблиц. Типы даны в общем SQL-стиле (легко адаптируются под конкретную СУБД). Для FK указан ON DELETE / ON UPDATE только там, где он отличается от стандартного RESTRICT.

---

## Users (Пользователи)

| Атрибут | Тип | NULL | Ключ |
|---|---|---|---|
| login | VARCHAR(30) | NOT NULL | PK |
| password | VARCHAR(255) | NOT NULL | |
| name | VARCHAR(20) | NOT NULL | |

`password` — здесь и далее подразумевается хэш пароля, поэтому длина с запасом.

---

## Games (Игры)

| Атрибут | Тип | NULL | Ключ |
|---|---|---|---|
| id | SERIAL | NOT NULL | PK |
| move_time_limit | SMALLINT | NOT NULL | |
| points_to_win | SMALLINT | NOT NULL | |

---

## Players (Игроки)

| Атрибут | Тип | NULL | Ключ |
|---|---|---|---|
| id | SERIAL | NOT NULL | PK |
| seat_number | SMALLINT | NOT NULL | AK1 |
| round_score | SMALLINT | NOT NULL DEFAULT 0 | |
| game_id | INT | NOT NULL | AK1, FK1 → Games(id) |
| user_login | VARCHAR(30) | *NULL* | AK2, FK2 → Users(login) |

- FK1 (game_id → Games.id): **ON DELETE CASCADE** — при удалении игры удаляются все её игроки.
- FK2 (user_login → Users.login): **ON DELETE SET NULL, ON UPDATE CASCADE** — если пользователь удалён посреди партии, запись игрока не удаляется (чтобы не сломать идущую игру), а ссылка обнуляется; при смене логина она обновляется каскадно.
- Из-за SET NULL атрибут user_login допускает NULL, поэтому альтернативный ключ AK2 {game_id, user_login} реально работает только для строк с непустым user_login — это осознанный компромисс ради корректности ON DELETE, а не нарушение модели: как только пользователь удалён, гарантия «не может играть дважды в одной игре» для него уже не актуальна.

---

## Moves (Ходы)

| Атрибут | Тип | NULL | Ключ |
|---|---|---|---|
| player_id | INT | NOT NULL | PK, FK → Players(id) |
| start_time | TIMESTAMP | NOT NULL | |

- FK (player_id → Players.id): **ON DELETE CASCADE** — запись о текущем ходе не нужна без самого игрока.

---

## Rounds (Раунды)

| Атрибут | Тип | NULL | Ключ |
|---|---|---|---|
| id | SERIAL | NOT NULL | PK |
| round_number | SMALLINT | NOT NULL | AK |
| trump_suit | ENUM('spades','hearts','diamonds','clubs') | NOT NULL | |
| game_id | INT | NOT NULL | AK, FK → Games(id) |

- FK (game_id → Games.id): **ON DELETE CASCADE**.

---

## Round_winner (Победитель в раунде)

| Атрибут | Тип | NULL | Ключ |
|---|---|---|---|
| round_id | INT | NOT NULL | PK, FK1 → Rounds(id) |
| player_id | INT | NOT NULL | FK2 → Players(id) |

- FK1 (round_id → Rounds.id): **ON DELETE CASCADE**.
- FK2 (player_id → Players.id): **ON DELETE CASCADE**.

---

## Tricks (Взятки)

| Атрибут | Тип | NULL | Ключ |
|---|---|---|---|
| id | SERIAL | NOT NULL | PK |
| round_id | INT | NOT NULL | FK1 → Rounds(id) |
| winner_id | INT | NOT NULL | FK2 → Players(id) |

- FK1 (round_id → Rounds.id): **ON DELETE CASCADE**.
- FK2 (winner_id → Players.id): **ON DELETE CASCADE**.

---

## Schnapsen_declarations (Шнапсы)

| Атрибут | Тип | NULL | Ключ |
|---|---|---|---|
| round_id | INT | NOT NULL | PK, FK1 → Rounds(id) |
| points_declared | SMALLINT | NOT NULL | |
| player_id | INT | NOT NULL | FK2 → Players(id) |

- FK1 (round_id → Rounds.id): **ON DELETE CASCADE**.
- FK2 (player_id → Players.id): **ON DELETE CASCADE**.

---

## Ranks (Номиналы)

| Атрибут | Тип | NULL | Ключ |
|---|---|---|---|
| rank | ENUM('9','J','Q','K','10','A') | NOT NULL | PK |
| points | SMALLINT | NOT NULL | |

Справочная таблица, значения фиксированы правилами игры (9=0, J=2, Q=3, K=4, 10=10, A=11) — по сути статичное перечисление, но вынесена отдельной таблицей именно для соблюдения 2НФ (см. декомпозицию Карт).

---

## Cards (Карты)

| Атрибут | Тип | NULL | Ключ |
|---|---|---|---|
| id | SERIAL | NOT NULL | PK |
| suit | ENUM('spades','hearts','diamonds','clubs') | NOT NULL | AK |
| rank | ENUM('9','J','Q','K','10','A') | NOT NULL | AK, FK1 → Ranks(rank) |
| game_id | INT | NOT NULL | AK, FK2 → Games(id) |

- FK1 (rank → Ranks.rank): **ON UPDATE CASCADE** (если бы менялось обозначение номинала — синхронизируется); ON DELETE оставлен стандартным RESTRICT — удалить номинал, пока на него ссылаются карты, нельзя.
- FK2 (game_id → Games.id): **ON DELETE CASCADE**.

---

## Cards_in_trick (Карты во взятке)

| Атрибут | Тип | NULL | Ключ |
|---|---|---|---|
| card_id | INT | NOT NULL | PK, FK1 → Cards(id) |
| trick_id | INT | NOT NULL | FK2 → Tricks(id) |

- FK1 (card_id → Cards.id): **ON DELETE CASCADE**.
- FK2 (trick_id → Tricks.id): **ON DELETE CASCADE**.

---

## Cards_in_hand (Карты в руках)

| Атрибут | Тип | NULL | Ключ |
|---|---|---|---|
| card_id | INT | NOT NULL | PK, FK1 → Cards(id) |
| player_id | INT | NOT NULL | FK2 → Players(id) |

- FK1 (card_id → Cards.id): **ON DELETE CASCADE**.
- FK2 (player_id → Players.id): **ON DELETE CASCADE**.

---

## Сводка по нестандартным ON DELETE / ON UPDATE

| Таблица | FK | ON DELETE | ON UPDATE |
|---|---|---|---|
| Players | user_login → Users.login | SET NULL | CASCADE |
| Cards | rank → Ranks.rank | RESTRICT (по умолчанию) | CASCADE |
| Все остальные FK | — | CASCADE | — (стандартный RESTRICT) |

Логика: почти всё каскадно удаляется вслед за игрой/раундом/взяткой/картой, потому что вне этих родительских сущностей дочерние записи не имеют смысла. Единственное исключение — связь Players с Users: удаление аккаунта пользователя не должно ломать идущую партию, поэтому там SET NULL, как в примере с крестиками-ноликами из лекции.