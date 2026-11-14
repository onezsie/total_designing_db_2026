set search_path to ziganshin_food, exts;

create table client (
	client_id uuid primary key default exts.uuid_generate_v4(),
	login varchar(50) not null unique,
	password varchar(32) not null,
	phone_number char(12) not null unique
);

create table address (
	address_id uuid primary key default exts.uuid_generate_v4(),
	street varchar(100) not null,
	house_number varchar(10) not null,
	apartment_office varchar(10)
);

create table client_address (
	client_id uuid not null references client(client_id),
	address_id uuid not null references address(address_id),
	primary key (client_id, address_id)
);

create table restaurant (
	restaurant_id uuid primary key default exts.uuid_generate_v4(),
	restaurant_name varchar(100) not null,
	address_id uuid not null unique references address(address_id),
	description text not null,
	work_start time not null,
	work_end time not null check (work_end > work_start),
	company_details text not null,
	rating numeric(3, 2) check (rating between 0 and 5),
	status restaurant_status not null
);

create table courier (
	courier_id uuid primary key default exts.uuid_generate_v4(),
	fio varchar(150) not null,
	phone_number char(12) not null,
	status courier_status not null check (status != 'уволен' or dismissal_date is not null),
	hire_date date not null,
	dismissal_date date check (dismissal_date >= hire_date),
	coefficient numeric(2, 1) not null check (coefficient between 0.1 and 0.5) default 0.1
);

create table courier_pay (
	year int not null,
	month int not null,
	courier_id uuid not null references courier(courier_id),
	amount numeric(12, 2) not null check (amount >= 0),
	coefficient_used numeric(2, 1) not null check (coefficient_used between 0.1 and 0.5),
	primary key (year, month, courier_id)
);

create table product_category (
	product_category_id uuid primary key default exts.uuid_generate_v4(),
	product_category_name varchar(100) not null
);

create table product (
	product_id uuid primary key default exts.uuid_generate_v4(),
	product_name varchar(100) not null,
	product_category_id uuid not null references product_category(product_category_id),
	price numeric(10, 2) not null check (price >= 0),
	restaurant_id uuid not null references restaurant(restaurant_id),
	photo_url text,
	rating numeric(3, 2) check (rating between 0 and 5),
	status product_status not null,
	description text not null
);

create table "order" (
	order_id uuid primary key default exts.uuid_generate_v4(),
	courier_id uuid not null references courier(courier_id),
	client_id uuid not null references client(client_id),
	address_id uuid not null references address(address_id),
	restaurant_id uuid not null references restaurant(restaurant_id),
	order_timestamp timestamp not null,
	delivery_timestamp timestamp check (delivery_timestamp >= order_timestamp),
	order_amount numeric(10, 2) not null,
	commission numeric(10, 2) not null generated always as (round(order_amount * 0.10, 2)) stored,
	total_amount numeric(10, 2) not null generated always as (order_amount + round(order_amount * 0.10, 2)) stored check (total_amount >= 1000),
	status order_status not null check (status != 'доставлен' or delivery_timestamp is not null),
	pay_status order_pay_status not null,
	description text not null
);

--адрес доставки должен быть одним из адресов клиента
alter table "order" add constraint order_client_address_fkey foreign key (client_id, address_id) references client_address(client_id, address_id);

create table payment (
	payment_id uuid primary key default exts.uuid_generate_v4(),
	order_id uuid not null references "order"(order_id),
	payment_type payment_type not null,
	amount numeric(10, 2) not null,
	transaction_number varchar(64) not null unique,
	transaction_timestamp timestamp not null,
	status payment_status not null
);

--у заказа не больше одной успешной оплаты
create unique index payment_order_id_idx on payment (order_id) where status = 'успех';

create table order_structure (
	order_id uuid not null references "order"(order_id),
	product_id uuid not null references product(product_id),
	quantity numeric(8, 3) not null check (quantity > 0),
	primary key (order_id, product_id)
);

create table review (
	review_id uuid primary key default exts.uuid_generate_v4(),
	client_id uuid not null references client(client_id),
	review_timestamp timestamp not null,
	entity_id uuid not null,
	entity_type review_entity_type not null,
	order_id uuid not null references "order"(order_id) check (entity_type != 'заказ' or entity_id = order_id),
	description text not null,
	photo_url text,
	rating numeric(2, 1) not null check (rating between 1 and 5),
	unique (order_id, entity_type, entity_id)
);
