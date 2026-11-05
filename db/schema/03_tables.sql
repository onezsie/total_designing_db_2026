set search_path to ziganshin_food, exts;

--таблицы и поля по docs/erd.md
--здесь только первичные и внешние ключи из ERD и генерация uuid (BR-11.1)
--not null, unique, check, default по бизнес-правилам ещё не расставлены

create table client (
	client_id uuid primary key default exts.uuid_generate_v4(),
	login varchar(50),
	password varchar(32),
	phone_number char(12)
);

create table address (
	address_id uuid primary key default exts.uuid_generate_v4(),
	street varchar(100),
	house_number varchar(10),
	apartment_office varchar(10)
);

create table client_address (
	client_id uuid references client(client_id),
	address_id uuid references address(address_id),
	primary key (client_id, address_id)
);

create table restaurant (
	restaurant_id uuid primary key default exts.uuid_generate_v4(),
	restaurant_name varchar(100),
	address_id uuid references address(address_id),
	description text,
	work_start time,
	work_end time,
	company_details text,
	rating numeric(3, 2),
	status restaurant_status
);

create table courier (
	courier_id uuid primary key default exts.uuid_generate_v4(),
	fio varchar(150),
	phone_number char(12),
	status courier_status,
	hire_date date,
	dismissal_date date,
	coefficient numeric(2, 1)
);

create table courier_pay (
	year int,
	month int,
	courier_id uuid references courier(courier_id),
	amount numeric(12, 2),
	coefficient_used numeric(2, 1),
	primary key (year, month, courier_id)
);

create table product_category (
	product_category_id uuid primary key default exts.uuid_generate_v4(),
	product_category_name varchar(100)
);

create table product (
	product_id uuid primary key default exts.uuid_generate_v4(),
	product_name varchar(100),
	product_category_id uuid references product_category(product_category_id),
	price numeric(10, 2),
	restaurant_id uuid references restaurant(restaurant_id),
	photo_url text,
	rating numeric(3, 2),
	status product_status,
	description text
);

create table "order" (
	order_id uuid primary key default exts.uuid_generate_v4(),
	courier_id uuid references courier(courier_id),
	client_id uuid references client(client_id),
	address_id uuid references address(address_id),
	restaurant_id uuid references restaurant(restaurant_id),
	order_timestamp timestamp,
	delivery_timestamp timestamp,
	order_amount numeric(10, 2),
	commission numeric(10, 2),
	total_amount numeric(10, 2),
	status order_status,
	pay_status order_pay_status,
	description text
);

--в ERD у payment только ключи, атрибуты попытки оплаты по BR-8.2 нужно добавить
create table payment (
	payment_id uuid primary key default exts.uuid_generate_v4(),
	order_id uuid references "order"(order_id)
);

create table order_structure (
	order_id uuid references "order"(order_id),
	product_id uuid references product(product_id),
	quantity numeric(8, 3),
	primary key (order_id, product_id)
);

create table review (
	review_id uuid primary key default exts.uuid_generate_v4(),
	client_id uuid references client(client_id),
	review_timestamp timestamp,
	entity_id uuid,
	entity_type review_entity_type,
	order_id uuid references "order"(order_id),
	description text,
	photo_url text,
	rating numeric(2, 1)
);
