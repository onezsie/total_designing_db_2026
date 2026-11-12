set search_path to ziganshin_food, exts;

--FOOD-107: зарплата курьеров за текущий месяц (BR-10.2)
create or replace procedure courier_salary() as $$
declare
	i record;
	v_month date = date_trunc('month', current_date);
	v_coefficient numeric;
begin
	for i in
		select c.courier_id, c.coefficient, c.status, count(o.order_id), coalesce(sum(o.commission), 0) as commission
		from courier c
		left join "order" o on o.courier_id = c.courier_id and o.status = 'доставлен' and o.order_timestamp >= v_month and o.order_timestamp < v_month + interval '1 month'
		group by c.courier_id
	loop
		if exists (select 1 from courier_pay where year = extract(year from v_month) and month = extract(month from v_month) and courier_id = i.courier_id) then
			update courier_pay
			set amount = round(coefficient_used * i.commission, 2)
			where year = extract(year from v_month) and month = extract(month from v_month) and courier_id = i.courier_id;
		else
			insert into courier_pay (year, month, courier_id, amount, coefficient_used)
			values (extract(year from v_month), extract(month from v_month), i.courier_id, round(i.coefficient * i.commission, 2), i.coefficient);
		end if;
		--коэффициент на следующий месяц
		if i.status != 'уволен' then
			if i.count <= 150 then
				v_coefficient = 0.1;
			elseif i.count <= 250 then
				v_coefficient = 0.2;
			elseif i.count <= 500 then
				v_coefficient = 0.3;
			else
				v_coefficient = 0.5;
			end if;
			update courier
			set coefficient = v_coefficient
			where courier_id = i.courier_id;
		end if;
	end loop;
end;
$$ language plpgsql;
