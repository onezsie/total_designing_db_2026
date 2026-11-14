set search_path to ziganshin_food, exts;

--пересчёт рейтинга блюда и ресторана по отзывам
create or replace function rating_change() returns trigger as $$
begin
	--старая сущность: при изменении и удалении отзыва
	if tg_op in ('UPDATE', 'DELETE') then
		if old.entity_type = 'блюдо' then
			update product
			set rating = (select avg(rating) from review where entity_type = 'блюдо' and entity_id = old.entity_id)
			where product_id = old.entity_id;
		elseif old.entity_type = 'ресторан' then
			update restaurant
			set rating = (select avg(rating) from review where entity_type = 'ресторан' and entity_id = old.entity_id)
			where restaurant_id = old.entity_id;
		end if;
	end if;
	--новая сущность: при добавлении и изменении отзыва
	if tg_op in ('INSERT', 'UPDATE') then
		if new.entity_type = 'блюдо' then
			update product
			set rating = (select avg(rating) from review where entity_type = 'блюдо' and entity_id = new.entity_id)
			where product_id = new.entity_id;
		elseif new.entity_type = 'ресторан' then
			update restaurant
			set rating = (select avg(rating) from review where entity_type = 'ресторан' and entity_id = new.entity_id)
			where restaurant_id = new.entity_id;
		end if;
	end if;
	return null;
end;
$$ language plpgsql;

create trigger rating_change
after insert or update or delete on review
for each row execute procedure rating_change();
