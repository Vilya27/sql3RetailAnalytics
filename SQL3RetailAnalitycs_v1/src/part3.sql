DROP OWNED BY Administrator CASCADE;
DROP USER IF EXISTS Administrator;
DROP OWNED BY Visitor CASCADE;
DROP USER IF EXISTS Visitor;

CREATE USER Administrator WITH PASSWORD '111';
CREATE USER Visitor WITH PASSWORD '222';

GRANT pg_write_all_data TO Administrator;
GRANT pg_read_all_data TO Administrator;
GRANT pg_read_all_data TO Visitor;

-- \du -- all users
-- \dp -- table with all permissions

-- set role Administrator;
-- select * from product_grid;
-- insert into personal_information (customer_id, customer_name, customer_surname, customer_primary_email, customer_primary_phone)
-- values ((select MAX(customer_id)+1 from personal_information), 'Custom-name', 'Custom-surname', 'email@email.com', '+78965432145');
-- delete from personal_information where customer_name LIKE 'Custom-name';

-- set role Visitor;
-- select * from sku_group;
-- insert into personal_information (customer_id, customer_name, customer_surname, customer_primary_email, customer_primary_phone)
-- values ((select MAX(customer_id)+1 from personal_information), 'Custom-name', 'Custom-surname', 'email@email.com', '+78965432145');
-- delete from personal_information where customer_name LIKE 'Custom-name';
