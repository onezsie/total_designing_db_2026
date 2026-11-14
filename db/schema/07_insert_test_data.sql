set search_path to ziganshin_food, exts;

--FOOD-102: генератор тестовых данных, распределение строк по BR-11.7
create or replace procedure insert_test_data(value int) as $$
declare
	m record;
	v_categories uuid[];
	v_couriers uuid[];
	v_addresses uuid[];
	v_restaurants uuid[];
	v_clients uuid[];
	v_products uuid[];
	v_prices numeric[];
	v_orders uuid[];
	v_order_products uuid[];
	v_qty numeric[];
	v_id uuid;
	v_login varchar(50);
	v_phone char(12);
	v_courier_status courier_status;
	v_hire_date date;
	v_dismissal_date date;
	v_work_start time;
	v_client_idx int;
	v_restaurant_idx int;
	v_order_status order_status;
	v_order_time timestamp;
	v_delivery_time timestamp;
	v_items int;
	v_amount numeric;
	v_entity_type review_entity_type;
	v_entity_id uuid;
	v_client_id uuid;
	v_restaurant_id uuid;
	v_start timestamp = date_trunc('month', current_date) - interval '5 months';
	v_coefficient numeric;
	v_count int;
	v_commission numeric;
begin
	--product_category: value строк
	select array_agg(exts.uuid_generate_v4()) into v_categories
	from generate_series(1, value);
	for i in 1..value
	loop
		insert into product_category (product_category_id, product_category_name)
		values (v_categories[i], substring(repeat(md5(random()::text), 4), 1, floor(random() * 100)::int + 1));
	end loop;
	--courier: value строк
	select array_agg(exts.uuid_generate_v4()) into v_couriers
	from generate_series(1, value);
	for i in 1..value
	loop
		v_courier_status = (enum_range(null::courier_status))[floor(random() * cardinality(enum_range(null::courier_status)))::int + 1];
		v_hire_date = current_date - floor(random() * 180)::int;
		insert into courier (courier_id, fio, phone_number, status, hire_date, dismissal_date)
		values (v_couriers[i], substring(repeat(md5(random()::text), 5), 1, floor(random() * 150)::int + 1),
			'+7' || right('0000000000' || floor(random() * 10000000000)::int8, 10), v_courier_status, v_hire_date,
			case
				when v_courier_status = 'уволен' then v_hire_date + floor(random() * (current_date - v_hire_date + 1))::int
			end);
	end loop;
	--BR-6.6: хотя бы один активный курьер
	if not exists (select 1 from courier where status != 'уволен') then
		update courier
		set status = 'свободен', dismissal_date = null
		where courier_id = v_couriers[1];
	end if;
	--address: value * 5 строк, первые value под рестораны, остальные value * 4 под клиентов
	select array_agg(exts.uuid_generate_v4()) into v_addresses
	from generate_series(1, value * 5);
	for i in 1..value * 5
	loop
		insert into address (address_id, street, house_number, apartment_office)
		values (v_addresses[i], substring(repeat(md5(random()::text), 4), 1, floor(random() * 100)::int + 1),
			substring(md5(random()::text), 1, floor(random() * 10)::int + 1),
			case
				when random() < 0.5 then substring(md5(random()::text), 1, floor(random() * 10)::int + 1)
			end);
	end loop;
	--restaurant: value строк
	select array_agg(exts.uuid_generate_v4()) into v_restaurants
	from generate_series(1, value);
	for i in 1..value
	loop
		v_work_start = '06:00'::time + floor(random() * 6) * interval '1 hour';
		insert into restaurant (restaurant_id, restaurant_name, address_id, description, work_start, work_end, company_details, rating, status)
		values (v_restaurants[i], substring(repeat(md5(random()::text), 4), 1, floor(random() * 100)::int + 1), v_addresses[i],
			substring(repeat(md5(random()::text), 4), 1, floor(random() * 100)::int + 1),
			v_work_start, v_work_start + (8 + floor(random() * 5)) * interval '1 hour',
			substring(repeat(md5(random()::text), 4), 1, floor(random() * 100)::int + 1), null,
			(enum_range(null::restaurant_status))[floor(random() * cardinality(enum_range(null::restaurant_status)))::int + 1]);
	end loop;
	--client: value строк
	select array_agg(exts.uuid_generate_v4()) into v_clients
	from generate_series(1, value);
	for i in 1..value
	loop
		loop
			v_login = substring(repeat(md5(random()::text), 2), 1, floor(random() * 50)::int + 1);
			exit when not exists (select 1 from client where login = v_login);
		end loop;
		loop
			v_phone = '+7' || right('0000000000' || floor(random() * 10000000000)::int8, 10);
			exit when not exists (select 1 from client where phone_number = v_phone);
		end loop;
		insert into client (client_id, login, password, phone_number)
		values (v_clients[i], v_login, md5(random()::text), v_phone);
	end loop;
	--client_address: у каждого клиента по 4 адреса
	for j in 1..value * 4
	loop
		insert into client_address (client_id, address_id)
		values (v_clients[(j - 1) % value + 1], v_addresses[value + j]);
	end loop;
	--product: value * 5 строк, по 5 блюд на ресторан
	select array_agg(exts.uuid_generate_v4()), array_agg(round((1000 + random() * 1000)::numeric, 2)) into v_products, v_prices
	from generate_series(1, value * 5);
	for i in 1..value * 5
	loop
		insert into product (product_id, product_name, product_category_id, price, restaurant_id, photo_url, rating, status, description)
		values (v_products[i], substring(repeat(md5(random()::text), 4), 1, floor(random() * 100)::int + 1),
			v_categories[floor(random() * value)::int + 1], v_prices[i], v_restaurants[(i - 1) % value + 1],
			case
				when random() < 0.5 then 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
			end,
			null, (enum_range(null::product_status))[floor(random() * cardinality(enum_range(null::product_status)))::int + 1],
			substring(repeat(md5(random()::text), 4), 1, floor(random() * 100)::int + 1));
	end loop;
	--order: value * 5 строк, к каждому заказу позиции и одна попытка оплаты
	select array_agg(exts.uuid_generate_v4()) into v_orders
	from generate_series(1, value * 5);
	for i in 1..value * 5
	loop
		v_client_idx = floor(random() * value)::int + 1;
		v_restaurant_idx = floor(random() * value)::int + 1;
		v_order_status = (enum_range(null::order_status))[floor(random() * cardinality(enum_range(null::order_status)))::int + 1];
		v_order_time = v_start + random() * (localtimestamp - v_start);
		v_delivery_time = null;
		if v_order_status = 'доставлен' then
			v_delivery_time = v_order_time + (20 + random() * 100) * interval '1 minute';
			if v_delivery_time > localtimestamp then
				v_delivery_time = localtimestamp;
			end if;
		end if;
		v_items = floor(random() * 5)::int + 1;
		select array_agg(floor(random() * 5) + 1) into v_qty
		from generate_series(1, v_items);
		v_amount = 0;
		for k in 1..v_items
		loop
			v_amount = v_amount + v_prices[v_restaurant_idx + value * (k - 1)] * v_qty[k];
		end loop;
		insert into "order" (order_id, courier_id, client_id, address_id, restaurant_id, order_timestamp, delivery_timestamp, order_amount, status, pay_status, description)
		values (v_orders[i], v_couriers[floor(random() * value)::int + 1], v_clients[v_client_idx],
			v_addresses[value + v_client_idx + value * floor(random() * 4)::int], v_restaurants[v_restaurant_idx],
			v_order_time, v_delivery_time, v_amount, v_order_status, 'оплачен',
			substring(repeat(md5(random()::text), 4), 1, floor(random() * 100)::int + 1));
		for k in 1..v_items
		loop
			insert into order_structure (order_id, product_id, quantity)
			values (v_orders[i], v_products[v_restaurant_idx + value * (k - 1)], v_qty[k]);
		end loop;
		insert into payment (payment_id, order_id, payment_type, amount, transaction_number, transaction_timestamp, status)
		values (exts.uuid_generate_v4(), v_orders[i],
			(enum_range(null::payment_type))[floor(random() * cardinality(enum_range(null::payment_type)))::int + 1],
			(select total_amount from "order" where order_id = v_orders[i]), md5(random()::text), v_order_time, 'успех');
	end loop;
	--review: value * 5 строк
	for i in 1..value * 5
	loop
		loop
			v_id = v_orders[floor(random() * value * 5)::int + 1];
			v_entity_type = (enum_range(null::review_entity_type))[floor(random() * cardinality(enum_range(null::review_entity_type)))::int + 1];
			select client_id, restaurant_id, order_timestamp into v_client_id, v_restaurant_id, v_order_time
			from "order"
			where order_id = v_id;
			if v_entity_type = 'заказ' then
				v_entity_id = v_id;
			elseif v_entity_type = 'ресторан' then
				v_entity_id = v_restaurant_id;
			else
				select array_agg(product_id) into v_order_products
				from order_structure
				where order_id = v_id;
				v_entity_id = v_order_products[floor(random() * array_length(v_order_products, 1))::int + 1];
			end if;
			exit when not exists (select 1 from review where order_id = v_id and entity_type = v_entity_type and entity_id = v_entity_id);
		end loop;
		insert into review (review_id, client_id, review_timestamp, entity_id, entity_type, order_id, description, photo_url, rating)
		values (exts.uuid_generate_v4(), v_client_id, v_order_time + random() * (localtimestamp - v_order_time), v_entity_id, v_entity_type, v_id,
			substring(repeat(md5(random()::text), 4), 1, floor(random() * 100)::int + 1),
			case
				when random() < 0.5 then 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
			end,
			floor(random() * 5) + 1);
	end loop;
	--courier_pay за последние 6 месяцев
	for i in 1..value
	loop
		select dismissal_date into v_dismissal_date
		from courier
		where courier_id = v_couriers[i];
		v_coefficient = 0.1;
		for m in
			select x::date
			from generate_series(v_start, date_trunc('month', current_date), interval '1 month') x
		loop
			select count(*), coalesce(sum(commission), 0) into v_count, v_commission
			from "order"
			where courier_id = v_couriers[i] and status = 'доставлен' and order_timestamp >= m.x and order_timestamp < m.x + interval '1 month';
			insert into courier_pay (year, month, courier_id, amount, coefficient_used)
			values (extract(year from m.x), extract(month from m.x), v_couriers[i], round(v_coefficient * v_commission, 2), v_coefficient);
			--коэффициент на следующий месяц
			if v_dismissal_date is null or v_dismissal_date >= m.x + interval '1 month' then
				if v_count <= 150 then
					v_coefficient = 0.1;
				elseif v_count <= 250 then
					v_coefficient = 0.2;
				elseif v_count <= 500 then
					v_coefficient = 0.3;
				else
					v_coefficient = 0.5;
				end if;
			end if;
		end loop;
		update courier
		set coefficient = v_coefficient
		where courier_id = v_couriers[i];
	end loop;
end;
$$ language plpgsql;
