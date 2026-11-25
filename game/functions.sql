-- Загружает все функции из отдельных файлов
\ir sql/helpers/check_token.sql
\ir sql/helpers/generate_tokens.sql
\ir sql/helpers/get_opponent.sql
\ir sql/helpers/deal_cards.sql
\ir sql/helpers/calculate_trick_winner.sql

\ir sql/auth/register_user.sql
\ir sql/auth/login_user.sql
\ir sql/auth/logout_user.sql
\ir sql/auth/logout_all_devices.sql

\ir sql/game/create_game.sql
\ir sql/game/join_game.sql
\ir sql/game/start_round.sql
\ir sql/game/get_game_state.sql

\ir sql/actions/play_card.sql
\ir sql/actions/declare_marriage.sql
\ir sql/actions/declare_schnapsen.sql

\ir sql/game/leave_game.sql
