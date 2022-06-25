-- Tableau Dashboard above.

-- inspecting data
select * from sales_data_sample

-- checking unique values
select distinct status from sales_data_sample -- nice one to plot
select distinct year_id from sales_data_sample 
select distinct PRODUCTLINE from sales_data_sample -- nice to plot
select distinct COUNTRY from sales_data_sample -- nice to plot
select distinct DEALSIZE from sales_data_sample -- nice to plot
select distinct TERRITORY from sales_data_sample -- nice to plot


-- Analysis
-- Lets start by grouping sales by productline

select PRODUCTLINE, sum(sales) as Revenue
from sales_data_sample
group by PRODUCTLINE
order by 2 desc
-- Classic cars are the best selling.

-- Grouping sales by year

select YEAR_ID, sum(sales) as Revenue
from sales_data_sample
group by YEAR_ID
order by 2 desc

-- 2005 seems a little low. Lets check if the data set has the data for the full year.

select distinct MONTH_ID from sales_data_sample
where year_id = 2005
-- seems like in 2005, they only have data till the month of May.

-- Grouping sales by deal sizes

select DEALSIZE, sum(sales) as Revenue
from sales_data_sample
group by DEALSIZE
order by 2 desc
-- Medium sized deals are generating the most revenue.

-- What was the best month for sales in a specific year? How much was earned that month?
select MONTH_ID, sum(sales) as Revenue, count(ORDERNUMBER) as Frequency
from sales_data_sample
where YEAR_ID = 2003
group by MONTH_ID
order by 2 desc
-- November was the best month for year 2003
select MONTH_ID, sum(sales) as Revenue, count(ORDERNUMBER) as Frequency
from sales_data_sample
where YEAR_ID = 2004
group by MONTH_ID
order by 2 desc
-- November was the best month for year 2004

-- November seems to be the best month, let us check what products are sold in the month of November.
select MONTH_ID, PRODUCTLINE, sum(sales) as Revenue, count(ORDERNUMBER) as Frequency
from sales_data_sample
where YEAR_ID = 2003 and MONTH_ID = 11
group by MONTH_ID, PRODUCTLINE
order by 3 desc

-- Who is our best customer? (This can be answered by RFM) RFM is Recency-Frequency-Monetary analysis.
select
	CUSTOMERNAME,
	sum(sales) as MonetaryValue,
	avg(sales) as AvgMonetaryValue,
	count(ORDERNUMBER) as Frequency,
	max(ORDERDATE) as last_order_date,
	(select max(ORDERDATE) from sales_data_sample) as max_order_date,
	DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from sales_data_sample)) as Recency

from sales_data_sample
group by CUSTOMERNAME

-- Put the dataset into a CTE
;with rfm as
(
	select
		CUSTOMERNAME,
		sum(sales) as MonetaryValue,
		avg(sales) as AvgMonetaryValue,
		count(ORDERNUMBER) as Frequency,
		max(ORDERDATE) as last_order_date,
		(select max(ORDERDATE) from sales_data_sample) as max_order_date,
		DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from sales_data_sample)) as Recency

	from sales_data_sample
	group by CUSTOMERNAME
)
select r.*,
	NTILE(4) OVER (order by Recency desc) rfm_recency,
	NTILE(4) OVER (order by Frequency) rfm_frequency,
	NTILE(4) OVER (order by AvgMonetaryValue) rfm_monetary
from rfm r

-- 2nd CTE
;with rfm as
(
	select
		CUSTOMERNAME,
		sum(sales) as MonetaryValue,
		avg(sales) as AvgMonetaryValue,
		count(ORDERNUMBER) as Frequency,
		max(ORDERDATE) as last_order_date,
		(select max(ORDERDATE) from sales_data_sample) as max_order_date,
		DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from sales_data_sample)) as Recency

	from sales_data_sample
	group by CUSTOMERNAME
),
rfm_calc as
(
	select r.*,
		NTILE(4) OVER (order by Recency desc) rfm_recency,
		NTILE(4) OVER (order by Frequency) rfm_frequency,
		NTILE(4) OVER (order by AvgMonetaryValue) rfm_monetary
	from rfm r
)
select 
	c.*, rfm_recency + rfm_frequency + rfm_monetary as rfm_cell,
	cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary as varchar) as rfm_cell_string
from rfm_calc as c

-- create a new table for the dataset from the CTE
DROP TABLE IF EXISTS #rfm
;with rfm as
(
	select
		CUSTOMERNAME,
		sum(sales) as MonetaryValue,
		avg(sales) as AvgMonetaryValue,
		count(ORDERNUMBER) as Frequency,
		max(ORDERDATE) as last_order_date,
		(select max(ORDERDATE) from sales_data_sample) as max_order_date,
		DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from sales_data_sample)) as Recency

	from sales_data_sample
	group by CUSTOMERNAME
),
rfm_calc as
(
	select r.*,
		NTILE(4) OVER (order by Recency desc) rfm_recency,
		NTILE(4) OVER (order by Frequency) rfm_frequency,
		NTILE(4) OVER (order by MonetaryValue) rfm_monetary
	from rfm r
)
select 
	c.*, rfm_recency + rfm_frequency + rfm_monetary as rfm_cell,
	cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary as varchar) as rfm_cell_string
into #rfm
from rfm_calc as c

-- testing the rfm table
select * from #rfm

-- doing the analysis
select CUSTOMERNAME, rfm_recency, rfm_frequency, rfm_monetary,
	case
		when rfm_cell_string in (111, 112, 121, 122, 123, 132, 211, 212, 114, 141) then 'lost customers' -- lost customers
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344) then 'slipping away, cannot lose' -- big spenders who havent purchased lately, cannot lose
		when rfm_cell_string in (311, 411, 331) then 'new customers'
		when rfm_cell_string in (222, 223, 233, 322) then 'potential churners'
		when rfm_cell_string in (323, 333, 321, 422, 332, 432) then 'active' -- customers who buy often and recently, but at low price points
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
	end rfm_segment

from #rfm

-- what products are most often sold together?
	
select distinct ORDERNUMBER, stuff(

	(select ',' + PRODUCTCODE
	from sales_data_sample as p
	where ORDERNUMBER in 
		(

		select ORDERNUMBER
		from (
			select ORDERNUMBER, count(*) as rn
			from sales_data_sample
			where STATUS = 'Shipped'
			group by ORDERNUMBER
		) as m
		where rn = 2 -- this number is to show how many products bought together
		)
		and p.ORDERNUMBER = s.ORDERNUMBER
	-- xml path
		for xml path ('')), 1, 1, '') as ProductCodes

from sales_data_sample as s
order by 2 desc
-- line 11 and 12 shows different order number (which means different customer) but they bought the same product codes for rn value of 2
-- line 12 and 13 shows different order number (which means different customer) but they bought the same product codes for rn value of 3