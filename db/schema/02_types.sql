set search_path to ziganshin_food, exts;

-- BR-4.3
create type restaurant_status as enum ('активен', 'неактивен');

-- BR-5.5
create type product_status as enum ('доступно', 'нет_в_наличии', 'архив');

-- BR-6.2
create type courier_status as enum ('свободен', 'занят', 'на_доставке', 'уволен');

-- BR-7.7
create type order_status as enum ('создан', 'готовится', 'в_доставке', 'доставлен', 'отменён');

-- BR-7.9
create type order_pay_status as enum ('ожидает', 'оплачен', 'ошибка');

-- BR-8.2
create type payment_status as enum ('успех', 'ошибка', 'в_обработке');

-- BR-8.2
create type payment_type as enum ('карта', 'наличные', 'безнал');

-- BR-9.1
create type review_entity_type as enum ('блюдо', 'ресторан', 'заказ');
