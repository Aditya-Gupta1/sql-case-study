-- Q1: What is the total amount each customer spent at the restaurant?

select prices.customer_id, sum(prices.price) as total_amount_spent
from (sales s join menu m on s.product_id = m.product_id) prices
group by prices.customer_id
order by prices.customer_id;

-- Q2: How many days has each customer visited the restaurant?

explain select customer_id, count(distinct order_date)
from sales
group by customer_id
order by customer_id;

-- Q3: What was the first item from the menu purchased by each customer?

-- Initial Solution
with first_orders as 
	(
	select customer_id, min(order_date) as first_ordered_on 
	from (sales s join menu m on s.product_id = m.product_id) prices
	group by prices.customer_id
	),
first_products as 
	(
	select distinct s.customer_id, s.product_id
	from sales s join first_orders f 
		on s.customer_id = f.customer_id and s.order_date = f.first_ordered_on
	),
first_product_names as 
	(
	select f.customer_id, m.product_name
	from first_products f join menu m on f.product_id = m.product_id
	)
select customer_id, string_agg(distinct product_name, ', ') as firstProducts
from first_product_names
group by customer_id;

-- Final Solution
with sale_rankings as 
	(
	select customer_id, order_date, product_name,
	dense_rank() over (partition by sales.customer_id order by sales.order_date) as order_rank
	from sales join menu on sales.product_id = menu.product_id
	),
temp_view as 
	(
	select customer_id, product_name
	from sale_rankings
	where order_rank = 1
	group by customer_id, product_name
	)
select customer_id, string_agg(product_name, ', ') as products
from temp_view
group by customer_id;

-- Q4: What is the most purchased item on the menu and how many times was it purchased by all customers?

-- most purchased item
select product_id from sales group by product_id order by count(*) desc limit 1;

--times purchased:
select customer_id, count(*)
from sales
where product_id = (select product_id from sales group by product_id order by count(*) desc limit 1)
group by customer_id;

-- Q5: Which item was the most popular for each customer

with popular_products as 
(
	select customer_id, product_id,
	dense_rank() over (partition by customer_id order by count(*) desc) as popularity
	from sales
	group by customer_id, product_id
)
select pp.customer_id, 
string_agg(m.product_name, ', ' order by m.product_name) as popular_products_per_customer
from popular_products pp join menu m using(product_id)
where pp.popularity = 1
group by pp.customer_id;

-- Q6: Which item was purchased first by the customer after they became a member

select customer_id , product_name from 
(
	select s.customer_id, s.product_id, 
	dense_rank() over (partition by s.customer_id 
		order by s.order_date) as days_after_joining
	from sales s join members m 
	on s.customer_id = m.customer_id 
	and s.order_date >= m.join_date
) orders_after_joining 
join menu using(product_id)
where days_after_joining = 1;

-- Q7: Which item was purchased just before the customer became a member?

select customer_id, string_agg(product_name, ', ') as item_purchased_before_membership
from (
select s.customer_id, s.product_id, 
dense_rank() over (partition by s.customer_id order by s.order_date desc) as days_after_joining
from sales s join members m 
on s.customer_id = m.customer_id 
and s.order_date < m.join_date
) orders_after_joining join menu using(product_id)
where days_after_joining = 1
group by customer_id;

-- Q8: What is the total items and amount spent for each member before they became a member?

select s.customer_id, 
count(product_id) as no_of_products, 
sum(price) as total_amount_spent
from sales s join members m 
on s.customer_id = m.customer_id 
and s.order_date < m.join_date
join menu using(product_id)
group by s.customer_id;

-- Q9: If each $1 spent equates to 10 points and sushi has a 2x points multiplier,
-- how many points would each customer have?

select customer_id,
SUM(case when product_id = 1 then 20*price else 10*price end) as points
from sales s join menu m using(product_id)
group by customer_id ;

-- Q10: In the first week after a customer joins the program (including their join date) they 
-- earn 2x points on all items, not just sushi - how many points do 
-- customer A and B have at the end of January?
select customer_id,
sum(
case
	when order_date between join_date and join_date + interval '7 day' 
		then 20*price
	when product_id = 1 then 20*price
	else 10*price
end
) as points
from sales s join members m using(customer_id) join menu using(product_id)
where s.order_date <= '2021-01-31'
group by customer_id;

-- Bonus Questions

-- 1. Join all the things
select customer_id, 
order_date, 
product_name, 
price,
(case 
	when join_date is null then 'N'
	when order_date >= join_date then 'Y'
	else 'N'
end) as member
from sales s join menu using(product_id) left join members using(customer_id);


-- 2. Rank all the things

-- Approach-1
with all_things as (
	select customer_id, 
	order_date, 
	product_name, 
	price,
	(case 
		when join_date is null then 'N'
		when order_date >= join_date then 'Y'
		else 'N'
	end) as member
	from sales s join menu using(product_id) 
	left join members using(customer_id)
)
select customer_id, 
order_date, 
product_name, 
price,
member,
case when member = 'N' then null
	else dense_rank() over (
	partition by case when member = 'Y' 
	then customer_id else null end order by order_date)
end as ranking
from all_things;

-- Approach-2: Doing everything at once without using CTE

select customer_id, 
order_date, 
product_name, 
price,
(case 
	when join_date is null then 'N'
	when order_date >= join_date then 'Y'
	else 'N'
end) as member,
case 
	when join_date is null or order_date < join_date then null
	else dense_rank() over ( partition by 
	case 
		when join_date is null or order_date < join_date then null 
		else customer_id end order by order_date)
	end as ranking
from sales s join menu using(product_id) 
left join members using(customer_id);