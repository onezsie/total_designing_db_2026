set search_path to ziganshin_food, exts;

--удаление тестовых данных
create or replace procedure erase_test_data() as $$
begin
	delete from review;
	delete from payment;
	delete from order_structure;
	delete from courier_pay;
	delete from "order";
	delete from client_address;
	delete from product;
	delete from restaurant;
	delete from client;
	delete from courier;
	delete from product_category;
	delete from address;
end;
$$ language plpgsql;
