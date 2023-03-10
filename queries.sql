-- Request 1
/* Provide the list of markets in which customer "Atliq Exclusive" operates its
business in the APAC region.*/

SELECT market, region FROM dim_customer
WHERE customer = 'Atliq Exclusive' AND region = 'APAC'

-- Request 2
/* What is the percentage of unique product increase in 2021 vs. 2020? 
The final output contains these fields: unique_products_2020, unique_products_2021, percentage_chg */

SELECT 
    COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END) AS unique_products_2020,
    COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) AS unique_products_2021,
    100 * 
    (COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) - COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END)) 
    / COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END) 
    AS percentage_chg
FROM 
    fact_sales_monthly
WHERE 
    fiscal_year IN (2020, 2021) 
    
-- Request 3
/* 
Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains
2 fields: segment, product_count
 */

SELECT segment, Count(distinct(product)) AS unique_products 
FROM dim_product
GROUP BY segment
ORDER BY unique_products DESC

-- Request 4
/* Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields:
segment, product_count_2020, product_count_2021, difference */

SELECT 
    segment,
    COUNT(DISTINCT CASE WHEN fm.fiscal_year = 2020 THEN p.product_code END) AS product_count_2020,
    COUNT(DISTINCT CASE WHEN fm.fiscal_year = 2021 THEN p.product_code END) AS product_count_2021,
    COUNT(DISTINCT CASE WHEN fm.fiscal_year = 2021 THEN p.product_code END) - COUNT(DISTINCT CASE WHEN fm.fiscal_year = 2020 THEN p.product_code END) AS difference
FROM 
    dim_product p
    JOIN fact_sales_monthly fm ON p.product_code = fm.product_code
WHERE 
    fm.fiscal_year IN (2020, 2021)
GROUP BY 
    segment
ORDER BY 
    difference DESC

-- Request 5
/* Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields,
product_code
product
manufacturing_cost */

SELECT 
    fmc.product_code,
    dp.product,
    fmc.manufacturing_cost
FROM 
    fact_manufacturing_cost fmc
    JOIN dim_product dp ON fmc.product_code = dp.product_code
WHERE 
    fmc.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost) OR
    fmc.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
    
ORDER BY 
    fmc.manufacturing_cost DESC

-- Request 6
/*  Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. The final output contains these fields:
customer_code
customer
average_discount_percentage */

SELECT 
    fpd.customer_code,
    dc.customer,
    ROUND(AVG(fpd.pre_invoice_discount_pct)*100,2) AS average_discount_percentage
FROM 
    fact_pre_invoice_deductions fpd
    JOIN dim_customer dc ON fpd.customer_code = dc.customer_code
WHERE 
    fpd.fiscal_year = 2021 AND
    dc.market = 'India'
GROUP BY 
    fpd.customer_code,
    dc.customer
ORDER BY 
    average_discount_percentage DESC
LIMIT 5

-- Request 7
/* Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. 
This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
The final report contains these columns: Month, Year, Gross sales Amount */
SELECT 
    MONTHNAME(fs.date) AS Month,
    YEAR(fs.date) AS Year,
    ROUND(SUM(fg.gross_price * fs.sold_quantity)/1000000, 2) AS Gross_sales_Amount_mln
FROM 
    fact_sales_monthly fs
    JOIN dim_customer dc ON fs.customer_code = dc.customer_code
    JOIN fact_gross_price fg ON fs.product_code = fg.product_code AND fs.fiscal_year = fg.fiscal_year
WHERE 
    dc.customer = 'Atliq Exclusive'
GROUP BY 
    YEAR(fs.date),
    MONTHNAME(fs.date)
ORDER BY 
    YEAR(fs.date),
    MONTHNAME(fs.date)


-- Request 8
/* In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity,
Quarter
total_sold_quantity */
SELECT ROUND(SUM(s.sold_quantity)/1000000, 2) AS total_quantity_sold_mln, -- In millions
CASE 
  WHEN s.date BETWEEN '2019-09-01' AND '2019-11-01' THEN "Q1"
  WHEN s.date BETWEEN '2019-12-01' AND '2020-02-01' THEN "Q2"
  WHEN s.date BETWEEN '2020-03-01' AND '2020-05-01' THEN "Q3"
  WHEN s.date BETWEEN '2020-06-01' AND '2020-08-01' THEN "Q4"
END AS quarter
FROM fact_sales_monthly s
WHERE s.fiscal_year = '2020'
GROUP BY quarter
ORDER BY quarter;  


-- Request 9
/* Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields: channel, gross_sales_mln, percentage */
WITH CTE1 AS
(SELECT dc.channel AS channel, ROUND(SUM(fg.gross_price * fs.sold_quantity)/1000000,2) AS gross_sales_mln
FROM fact_sales_monthly fs
JOIN dim_customer dc ON dc.customer_code = fs.customer_code 
JOIN fact_gross_price fg ON fg.fiscal_year = fs.fiscal_year AND fg.product_code = fs.product_code
WHERE fs.fiscal_year = '2021'
GROUP BY channel
ORDER BY gross_sales_mln DESC
),
CTE2 AS (SELECT SUM(gross_sales_mln) AS total_gross_sales_mln
		  FROM CTE1)
SELECT CTE1.*, ROUND((gross_sales_mln*100/total_gross_sales_mln), 2) AS percentage
FROM CTE1 
JOIN CTE2;

-- Request 10
/* Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these fields:
Division, product_code, product, total_sold_quantity,rank_order 
*/

WITH sales_2021 AS (
    SELECT *
    FROM fact_sales_monthly
    WHERE fiscal_year = 2021
),
sales_by_product AS (
    SELECT 
        dp.division, 
        dp.product_code, 
        dp.product,
        SUM(s2021.sold_quantity) AS total_sold_quantity
    FROM sales_2021 s2021
    JOIN dim_product dp ON s2021.product_code = dp.product_code
    GROUP BY dp.division, dp.product_code, dp.product
),
ranked_products AS (
    SELECT 
        division,
        product_code,
        product,
        total_sold_quantity,
        RANK() OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order
    FROM sales_by_product
)
SELECT 
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM ranked_products
WHERE rank_order <= 3
ORDER BY division, rank_order;
Footer
© 2023 GitHub, Inc.
Footer navigation
Terms
Privacy
