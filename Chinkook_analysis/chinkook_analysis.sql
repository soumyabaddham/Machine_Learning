-- Q1: Top 5 customers who made highest sales
-- outcome: using this data to introduce referal program which can increase user base of the platform
DROP VIEW IF EXISTS invoice_table CASCADE;

CREATE OR REPLACE VIEW invoice_table as 
	select i.invoice_id, i.customer_id,i.billing_country,i.total, 
	   Extract(Year from i.invoice_date) as year,il.quantity,il.unit_price,
	   (il.quantity* il.unit_price) as sale_amount
	from invoice i 
	left join invoice_line il
	on i.invoice_id = il.invoice_id;


Select c.first_name,c.last_name, sum(sale_amount) as sale_amount
from invoice_table as sales_table
left join public.customer c
on sales_table.customer_id = c.customer_id
group by sales_table.customer_id, c.first_name,c.last_name
order by sale_amount desc 
Limit 5;

--Q2: Highest sale per year with country
-- Outcome: can use this data to introduce offers in the countries with highest sales, which can increase sales

select rt.year, rt.billing_country,sum(sale_amount) as total
from invoice_table as rt
group by rt.billing_country, rt.year
order by total desc
limit 5;


-- Q3: Top 5 sales with country per year
-- Outcome: can use this data to introduce offers in the countries with highest sales, which can increase sales


With yearly_sales as(select invoice_table.year, billing_country, sum(sale_amount) as sales
  from invoice_table
 group by billing_country, invoice_table.year
 order by invoice_table.year desc),

ranked_ysales as(
select *, ROW_NUMBER() over(Partition by Year order by sales desc) as rn
from yearly_sales
)

select  year,billing_country as country, sales
from ranked_ysales
where rn <=5;


--Q4: Employees with best sales record
--  Outcome: reward top-performing employees to boost morale and sales
With employee_customer_table as(
						Select employee_id, customer_id,
							   CONCAT(employee.first_name,' ', employee.last_name) as employee_name,
							   employee.reports_to,
		                       CONCAT(customer.first_name, ' ',customer.last_name) as customer_name, 
							   customer.country,customer.support_rep_id
						from public.customer
						Left Join public.employee
						ON public.customer.support_rep_id = public.employee.employee_id
),

res_table as(
			Select st.customer_id, 
			ect.customer_name, 
			ect.employee_name,
			sum(st.sale_amount) over(Partition by ect.support_rep_id) as sales,
			           count(*) over(partition by ect.support_rep_id) as num_of_customers
						   from invoice_table st
						   left join employee_customer_table as ect
						     on st.customer_id = ect.customer_id
)


select distinct(employee_name),num_of_customers,sales
from res_table
order by sales desc;

--Q5: Best-selling genres 

CREATE OR REPLACE VIEW genre_details as
	select genre.genre_id,track_id, genre.name as genre_name,
	track.name as track_name,composer,milliseconds/(1000*60) as minutes,album_id
	from genre
	left join track
	on genre.genre_id = track.genre_id;



CREATE OR REPLACE VIEW genre_sales as
	select il.track_id, i.invoice_id,i.billing_country as country, i.total,g.genre_name,
	(il.unit_price * il.quantity) as sale
	from invoice i
	left join invoice_line il
	on i.invoice_id = il.invoice_id
	left join genre_details g
	on il.track_id = g.track_id;



select genre_name, count(*) as no_of_sales_per_genre,
       sum(sale) as sales_per_genre
from genre_sales
group by genre_name
order by sales_per_genre desc;

--Q6: Top 5 genres per year
DROP VIEW IF EXISTS invoice_details CASCADE;

CREATE OR REPLACE VIEW invoice_details as
	select il.track_id, i.invoice_id,i.billing_country as country, (il.unit_price * il.quantity) as sale,
	       Extract(YEAR from i.invoice_date) as year, g.genre_name
	from invoice i
	left join invoice_line il
	on i.invoice_id = il.invoice_id
	left join genre_sales g
	on g.invoice_id = il.invoice_id and g.track_id = il.track_id;

with res as(
select year, genre_name, sum(sale) as sale_amount, count(distinct(invoice_id)) as sales
  from invoice_details
 group by year, genre_name
 order by sale_amount desc
)

select year, genre_name, sale_amount, sales
from (select *, row_number() over(partition by year order by sale_amount desc) as rn from res)
where rn<=5;


--Q7: Top 5 albums per year
-- Outcome 5,6,7: to maintain the inventory of best-selling albums and genres

CREATE OR REPLACE VIEW album_details AS
	select g.*, a.title as album_title,a.artist_id, artist.name as artist_name
	from genre_details g
	left join album a
	on g.album_id = a.album_id
	left join artist 
	on a.artist_id = artist.artist_id;


with album_sales as(
select i.track_id, i.genre_name,
	    a.track_name, a.composer, a.album_title,
		a.artist_id, a.artist_name, i.sale,i.year
from invoice_details i
left join album_details a
on i.track_id = a.track_id
),
res_table as (
select year, album_title, sum(sale) as sales,
row_number() over(partition by year order by sum(sale) desc) as rn
from album_sales
group by album_title, year
order by year desc,sales desc, rn
)

select year,album_title, sales
from res_table
where rn<=5;
  
