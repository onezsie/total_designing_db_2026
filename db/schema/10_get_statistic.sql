set search_path to ziganshin_food, exts;

--FOOD-106: статистика по ресторанам, только доставленные заказы, одна строка на ресторан
create or replace function get_statistic() returns table (restaurant_name varchar, best_product_name varchar, total_amount numeric, avg_amount numeric, best_user varchar) as $$
begin
	return query
		with delivered as (
			select o.order_id, o.restaurant_id, o.client_id, o.total_amount
			from "order" o
			where o.status = 'доставлен'),
		totals as (
			select d.restaurant_id, sum(d.total_amount), avg(d.total_amount)
			from delivered d
			group by d.restaurant_id),
		best_product as (
			select distinct on (d.restaurant_id) d.restaurant_id, os.product_id
			from delivered d
			join order_structure os on os.order_id = d.order_id
			group by d.restaurant_id, os.product_id
			order by d.restaurant_id, sum(os.quantity) desc, random()),
		best_client as (
			select distinct on (d.restaurant_id) d.restaurant_id, d.client_id
			from delivered d
			group by d.restaurant_id, d.client_id
			order by d.restaurant_id, count(*) desc, random())
		select r.restaurant_name, p.product_name, t.sum, t.avg, c.login
		from restaurant r
		left join totals t on t.restaurant_id = r.restaurant_id
		left join best_product bp on bp.restaurant_id = r.restaurant_id
		left join product p on p.product_id = bp.product_id
		left join best_client bc on bc.restaurant_id = r.restaurant_id
		left join client c on c.client_id = bc.client_id;
end;
$$ language plpgsql;
