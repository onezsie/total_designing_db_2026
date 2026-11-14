set search_path to ziganshin_food, exts;

--все блюда в заказе должны быть из ресторана заказа
create or replace function order_structure_restaurant_check() returns trigger as $$
declare
	v_order_restaurant uuid;
	v_product_restaurant uuid;
begin
	select restaurant_id into v_order_restaurant
	from "order"
	where order_id = new.order_id;
	select restaurant_id into v_product_restaurant
	from product
	where product_id = new.product_id;
	if v_order_restaurant != v_product_restaurant then
		raise exception 'блюдо % не из ресторана заказа %', new.product_id, new.order_id;
	end if;
	return new;
end;
$$ language plpgsql;

create trigger order_structure_restaurant_check
before insert or update on order_structure
for each row execute procedure order_structure_restaurant_check();
