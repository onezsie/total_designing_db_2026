set search_path to ziganshin_food, exts;

--доходы и выплаты курьерам по месяцам
create view how_much_money as
	with recursive orders_by_month as (
		select date_trunc('month', order_timestamp) as month, sum(order_amount) as sum_no_commission, sum(total_amount) as sum_with_commission
		from "order"
		where status = 'доставлен'
		group by date_trunc('month', order_timestamp)),
	months as (
		--стартовая часть
		select min(month) as month
		from orders_by_month
		union all
		--рекурсивная часть
		select month + interval '1 month' as month
		from months
		where month < (select max(month) from orders_by_month)),
	pay_by_month as (
		select year, month, sum(amount) as courier_pay
		from courier_pay
		group by year, month),
	report as (
		select m.month, coalesce(o.sum_no_commission, 0) as sum_no_commission, coalesce(o.sum_with_commission, 0) as sum_with_commission,
			coalesce(o.sum_with_commission, 0) - coalesce(o.sum_no_commission, 0) as commission,
			coalesce(p.courier_pay, 0) as courier_pay
		from months m
		left join orders_by_month o on o.month = m.month
		left join pay_by_month p on p.year = date_part('year', m.month) and p.month = date_part('month', m.month)
		where m.month is not null)
	select date_part('year', month) || '-' || right('0' || date_part('month', month), 2) as year_month,
		sum_no_commission,
		sum_with_commission,
		commission,
		lag(commission) over (order by month) as prev_commission,
		commission - lag(commission) over (order by month) as commission_diff,
		courier_pay,
		commission - courier_pay as net_profit
	from report
	order by month;
