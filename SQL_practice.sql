-- Question 1: Customer Leaderboard
with join_table as
(SELECT document_id, quantity 
	, customer_id
	, ifnull(contact,'Guest') as cus_contact
    , type
from movement
left join document on movement.document_id = document.id 
left join customer on customer_id = customer.id
where type = 'sales_order')

select cus_contact
	, sum(abs(quantity)) as sold
from join_table 
group by cus_contact;


-- Question 2: Inventory Snapshot
declare @date1 Datetime
Set @date = '2021-1-1 00:00:00';
select warehouse
	, sku
    , balance, created_at
from movement
where warehouse = 'HK' and created_at = @date;


-- Question 3: Age of Inventory - FIFO
with infor_table as 
(select warehouse
 	, sku
	, sum(quantity) as available_stock
 	, sum(case when quantity > 0 then quantity end) as total_purchase
from movement
where warehouse = 'HK' and created_at < '2021-4-1 00:00:00'
group by warehouse, sku),

calculate_table as 
(select movement.warehouse
	, movement.sku
	, quantity, available_stock
    , total_purchase - available_stock as sold
    , created_at
    , datediff('2021-4-1 00:00:00', created_at) as age
    , -(total_purchase - available_stock) + sum(quantity) OVER (partition by sku ORDER BY created_at asc ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as remain
        
from movement
left join infor_table on movement.sku = infor_table.sku
where quantity >0 and movement.warehouse = 'HK' ),

transform as
(select sku, available_stock
 	, case 
 		when age <= 30 then 'Age 0-30'
 		when age between 31 and 60 then 'Age 31-60'
 		when age between 61 and 91 then 'Age 61-90'
 		when age > 90 then 'Age 90+'
 	end as age_period
	, case 
    	when remain <= 0 then 0
        when remain > 0 and remain < quantity then remain
        when remain > 0 and remain > quantity then quantity
      end as remain_product_day
from calculate_table)

select sku
	, available_stock
    , ifnull(sum(case when age_period= 'Age 0-30' then remain_product_day end),0) as 'Age 0-30'
    , ifnull(sum(case when age_period= 'Age 31-60' then remain_product_day end),0) as 'Age 31-60'
    , ifnull(sum(case when age_period= 'Age 61-90' then remain_product_day end),0) as 'Age 61-90'
    , ifnull(sum(case when age_period= 'Age 90+' then remain_product_day end),0) as 'Age 90+'
from transform
group by sku, available_stock