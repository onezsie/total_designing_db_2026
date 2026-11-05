set search_path to ziganshin_food, exts;

-- Таблицы и поля по docs/erd.md.
-- Здесь только PK, FK из ERD и генерация UUID (BR-11.1).
-- NOT NULL, UNIQUE, CHECK, DEFAULT по бизнес-правилам ещё не расставлены.

create table client (
    client_id    uuid        default exts.uuid_generate_v4(),
    login        varchar(50),
    password     varchar(32),
    phone_number char(12),
    constraint client_pk primary key (client_id)
);

create table address (
    address_id       uuid         default exts.uuid_generate_v4(),
    street           varchar(100),
    house_number     varchar(10),
    apartment_office varchar(10),
    constraint address_pk primary key (address_id)
);

create table client_address (
    client_id  uuid,
    address_id uuid,
    constraint client_address_pk primary key (client_id, address_id),
    constraint client_address_client_fk foreign key (client_id) references client (client_id),
    constraint client_address_address_fk foreign key (address_id) references address (address_id)
);

create table restaurant (
    restaurant_id   uuid         default exts.uuid_generate_v4(),
    restaurant_name varchar(100),
    address_id      uuid,
    description     text,
    work_start      time,
    work_end        time,
    company_details text,
    rating          numeric(3, 2),
    status          restaurant_status,
    constraint restaurant_pk primary key (restaurant_id),
    constraint restaurant_address_fk foreign key (address_id) references address (address_id)
);

create table courier (
    courier_id     uuid         default exts.uuid_generate_v4(),
    fio            varchar(150),
    phone_number   char(12),
    status         courier_status,
    hire_date      date,
    dismissal_date date,
    coefficient    numeric(2, 1),
    constraint courier_pk primary key (courier_id)
);

create table courier_pay (
    year             int,
    month            int,
    courier_id       uuid,
    amount           numeric(12, 2),
    coefficient_used numeric(2, 1),
    constraint courier_pay_pk primary key (year, month, courier_id),
    constraint courier_pay_courier_fk foreign key (courier_id) references courier (courier_id)
);

create table product_category (
    product_category_id   uuid         default exts.uuid_generate_v4(),
    product_category_name varchar(100),
    constraint product_category_pk primary key (product_category_id)
);

create table product (
    product_id          uuid         default exts.uuid_generate_v4(),
    product_name        varchar(100),
    product_category_id uuid,
    price               numeric(10, 2),
    restaurant_id       uuid,
    photo_url           text,
    rating              numeric(3, 2),
    status              product_status,
    description         text,
    constraint product_pk primary key (product_id),
    constraint product_category_fk foreign key (product_category_id) references product_category (product_category_id),
    constraint product_restaurant_fk foreign key (restaurant_id) references restaurant (restaurant_id)
);

-- order — зарезервированное слово, имя таблицы в кавычках (BR-13.1).
create table "order" (
    order_id           uuid           default exts.uuid_generate_v4(),
    courier_id         uuid,
    client_id          uuid,
    address_id         uuid,
    restaurant_id      uuid,
    order_timestamp    timestamp,
    delivery_timestamp timestamp,
    order_amount       numeric(10, 2),
    commission         numeric(10, 2),
    total_amount       numeric(10, 2),
    status             order_status,
    pay_status         order_pay_status,
    description        text,
    constraint order_pk primary key (order_id),
    constraint order_courier_fk foreign key (courier_id) references courier (courier_id),
    constraint order_client_fk foreign key (client_id) references client (client_id),
    constraint order_address_fk foreign key (address_id) references address (address_id),
    constraint order_restaurant_fk foreign key (restaurant_id) references restaurant (restaurant_id)
);

-- В ERD у payment только ключи. Атрибуты попытки оплаты по BR-8.2 нужно добавить.
create table payment (
    payment_id uuid default exts.uuid_generate_v4(),
    order_id   uuid,
    constraint payment_pk primary key (payment_id),
    constraint payment_order_fk foreign key (order_id) references "order" (order_id)
);

create table order_structure (
    order_id   uuid,
    product_id uuid,
    quantity   numeric(8, 3),
    constraint order_structure_pk primary key (order_id, product_id),
    constraint order_structure_order_fk foreign key (order_id) references "order" (order_id),
    constraint order_structure_product_fk foreign key (product_id) references product (product_id)
);

create table review (
    review_id        uuid               default exts.uuid_generate_v4(),
    client_id        uuid,
    review_timestamp timestamp,
    entity_id        uuid,
    entity_type      review_entity_type,
    order_id         uuid,
    description      text,
    photo_url        text,
    rating           numeric(2, 1),
    constraint review_pk primary key (review_id),
    constraint review_client_fk foreign key (client_id) references client (client_id),
    constraint review_order_fk foreign key (order_id) references "order" (order_id)
);
