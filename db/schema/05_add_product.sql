set search_path to ziganshin_food, exts;

--добавление блюда
create or replace procedure add_product(p_restaurant_id uuid, p_product_category_id uuid, p_name varchar, p_price numeric, p_rating numeric, p_status product_status, p_description text, p_photo_url text default null) as $$
begin
	if not exists (select 1 from restaurant where restaurant_id = p_restaurant_id) then
		raise exception 'ресторан % не найден', p_restaurant_id;
	end if;
	if not exists (select 1 from product_category where product_category_id = p_product_category_id) then
		raise exception 'категория блюда % не найдена', p_product_category_id;
	end if;
	if p_price < 0 then
		raise exception 'цена блюда не может быть отрицательной';
	end if;
	if p_rating < 0 or p_rating > 5 then
		raise exception 'рейтинг блюда должен быть от 0 до 5';
	end if;
	insert into product (product_id, product_name, product_category_id, price, restaurant_id, photo_url, rating, status, description)
	values (exts.uuid_generate_v4(), p_name, p_product_category_id, p_price, p_restaurant_id, p_photo_url, p_rating, p_status, p_description);
end;
$$ language plpgsql;
