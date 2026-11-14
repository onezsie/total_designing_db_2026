--пользователь inspector для проверки

create role inspector with login password 'NetoSQL2025';

grant all on schema ziganshin_food to inspector;

grant all on all tables in schema ziganshin_food to inspector;

grant usage on schema exts to inspector;

grant usage on schema information_schema to inspector;

grant usage on schema pg_catalog to inspector;
