/*  CREDIT CARD DATA ANALYSIS  */  

-- Select data that we will be using

SELECT *
FROM [Portfolio Project]..BankCustomers;


-- Average credit card limit and salary for each card category

SELECT  card_category, income_category, AVG(credit_limit) AS avg_credit
FROM [Portfolio Project]..BankCustomers
GROUP BY card_category, income_category
ORDER BY 1,2 DESC;


-- Average utilisation ratio, highest utilisation ratio by card category

SELECT TOP 1 AVG(avg_utilization_ratio) as avg_card_utilization_ratio, card_category
FROM [Portfolio Project]..BankCustomers
GROUP BY card_category
ORDER BY avg_card_utilization_ratio DESC;


-- Percentage married customers per card category

SELECT card_category, 
	COUNT(CASE WHEN marital_status = 'Married' THEN 1 END) AS married_customers, 
	COUNT(*) AS total_customers, 
	(COUNT(CASE WHEN marital_status = 'Married' THEN 1 END) * 100.0 / COUNT(*)) AS percentage_married
FROM [Portfolio Project]..BankCustomers
GROUP BY card_category
--ORDER BY percentage_married;


-- Customer ranking based on their credit card limit within their marital status

SELECT clientnum, marital_status, credit_limit, RANK() OVER (PARTITION BY marital_status ORDER BY credit_limit DESC) AS customer_ranking
FROM [Portfolio Project]..BankCustomers
ORDER BY marital_status, credit_limit DESC;


--  Identify customers who have been inactive for more than 3 months and calculate their average total transaction amount before they became inactive

SELECT clientnum, AVG(total_trans_amt) as avg_total_trans_amt
FROM [Portfolio Project]..BankCustomers
WHERE months_inactive_12_mon > 3
GROUP BY clientnum
HAVING COUNT(total_trans_amt) > 0;


-- months_on_book vs avg_transaction_amount

SELECT months_on_book, AVG(total_trans_amt) AS avg_transaction_amount
FROM [Portfolio Project]..BankCustomers
GROUP BY months_on_book
ORDER BY months_on_book;


-- Customers who have greater credit limits than the average credit limit

SELECT COUNT(clientnum) AS num_clients_above_avg_credit_limit
FROM [Portfolio Project]..BankCustomers
WHERE credit_limit > 
(
SELECT AVG(credit_limit)
FROM [Portfolio Project]..BankCustomers
)
;


-- Age group that has the highest average credit limit

SELECT TOP 1 
    CASE 
        WHEN customer_age < 20 THEN 'Under 20'
        WHEN customer_age BETWEEN 20 AND 29 THEN '20-29'
        WHEN customer_age BETWEEN 30 AND 39 THEN '30-39'
        WHEN customer_age BETWEEN 40 AND 49 THEN '40-49'
        WHEN customer_age BETWEEN 50 AND 59 THEN '50-59'
        ELSE '60 and above'
    END AS age_group,AVG(credit_limit) AS average_credit_limit
FROM [Portfolio Project]..BankCustomers
GROUP BY 
    CASE 
        WHEN customer_age < 20 THEN 'Under 20'
        WHEN customer_age BETWEEN 20 AND 29 THEN '20-29'
        WHEN customer_age BETWEEN 30 AND 39 THEN '30-39'
        WHEN customer_age BETWEEN 40 AND 49 THEN '40-49'
        WHEN customer_age BETWEEN 50 AND 59 THEN '50-59'
        ELSE '60 and above'
    END
ORDER BY average_credit_limit DESC;


-- Most common credit card category for high earners

With high_earning_card_holders AS
(
SELECT COUNT(card_category) as num_card_holders, card_category
FROM [Portfolio Project]..BankCustomers
WHERE income_category = '$120K +'
GROUP BY card_category
)
SELECT num_card_holders, card_category 
FROM high_earning_card_holders
WHERE num_card_holders = (SELECT MAX(num_card_holders) FROM high_earning_card_holders);


-- Segment customers based on their total transaction amount and average utilization ratio into 'High', 'Medium', and 'Low' categories

WITH transaction_segments AS 
(
SELECT clientnum, total_trans_amt, avg_utilization_ratio,
        CASE 
            WHEN total_trans_amt > PERCENTILE_CONT(0.66) WITHIN GROUP (ORDER BY total_trans_amt) OVER ()
                THEN 'High'
            WHEN total_trans_amt > PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY total_trans_amt) OVER ()
                THEN 'Medium'
            ELSE 'Low'
        END AS transaction_segment
    FROM 
        [Portfolio Project]..BankCustomers -- Agg transaction data based on percentile of total transaction data
),
utilization_segments AS 
(
SELECT *,
        CASE 
            WHEN avg_utilization_ratio > 0.7
                THEN 'High'
            WHEN avg_utilization_ratio BETWEEN 0.3 AND 0.7
                THEN 'Medium'
            ELSE 'Low'
        END AS utilization_segment
    FROM 
        transaction_segments -- Agg transaction data based on Low  = <30%, Medium =  30-70%, High = >70%
)
SELECT 
    clientnum, total_trans_amt, avg_utilization_ratio, transaction_segment, utilization_segment,
    CASE 
        WHEN transaction_segment = 'High' AND utilization_segment = 'High' THEN 'High Value High Risk'
        WHEN transaction_segment = 'High' AND utilization_segment = 'Low' THEN 'High Value Low Risk'
        WHEN transaction_segment = 'Low' AND utilization_segment = 'High' THEN 'Low Value High Risk'
        WHEN transaction_segment = 'Low' AND utilization_segment = 'Low' THEN 'Low Value Low Risk'
        ELSE 'Medium'
    END AS overall_segment
FROM utilization_segments
ORDER BY total_trans_amt DESC,
avg_utilization_ratio DESC;


-- Creating View to store data later for visualisations

CREATE VIEW v_AvgCardLimitSalaryByCard AS
SELECT card_category, income_category, AVG(credit_limit) AS avg_credit
FROM [Portfolio Project]..BankCustomers
GROUP BY card_category, income_category;


CREATE VIEW v_MonthsOnBookvsTransactionCorr AS
SELECT months_on_book, AVG(total_trans_amt) AS avg_transaction_amount
FROM [Portfolio Project]..BankCustomers
GROUP BY months_on_book;
--ORDER BY months_on_book; -- Determine if there is a specific range of months where customers are most active or if there's a decline in activity over time.


CREATE VIEW v_CustomerSegmentDistribution AS
WITH transaction_segments AS 
(
SELECT clientnum, total_trans_amt, avg_utilization_ratio,
        CASE 
            WHEN total_trans_amt > PERCENTILE_CONT(0.66) WITHIN GROUP (ORDER BY total_trans_amt) OVER ()
                THEN 'High'
            WHEN total_trans_amt > PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY total_trans_amt) OVER ()
                THEN 'Medium'
            ELSE 'Low'
        END AS transaction_segment
    FROM 
        [Portfolio Project]..BankCustomers -- Agg transaction data based on percentile of total transaction data
),
utilization_segments AS 
(
SELECT *,
        CASE 
            WHEN avg_utilization_ratio > 0.7
                THEN 'High'
            WHEN avg_utilization_ratio BETWEEN 0.3 AND 0.7
                THEN 'Medium'
            ELSE 'Low'
        END AS utilization_segment
    FROM 
        transaction_segments -- Agg transaction data based on Low  = <30%, Medium =  30-70%, High = >70%
)
SELECT 
    clientnum, total_trans_amt, avg_utilization_ratio, transaction_segment, utilization_segment,
    CASE 
        WHEN transaction_segment = 'High' AND utilization_segment = 'High' THEN 'High Value High Risk'
        WHEN transaction_segment = 'High' AND utilization_segment = 'Low' THEN 'High Value Low Risk'
        WHEN transaction_segment = 'Low' AND utilization_segment = 'High' THEN 'Low Value High Risk'
        WHEN transaction_segment = 'Low' AND utilization_segment = 'Low' THEN 'Low Value Low Risk'
        ELSE 'Medium'
    END AS overall_segment
FROM utilization_segments;
--ORDER BY total_trans_amt DESC,
--avg_utilization_ratio DESC;
