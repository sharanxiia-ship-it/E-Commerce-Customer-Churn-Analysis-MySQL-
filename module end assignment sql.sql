USE ecomm;
SELECT COUNT(*) FROM customer_churn;

USE ecomm;
SET SQL_SAFE_UPDATES = 0;   -- allow UPDATE/DELETE without a key in WHERE

-- 1.1 Impute MEAN (rounded to nearest integer) ------------------------
-- (the derived table avoids MySQL error 1093: can't update & select same table)
UPDATE customer_churn
SET WarehouseToHome = (SELECT m FROM (SELECT ROUND(AVG(WarehouseToHome)) AS m FROM customer_churn) t)
WHERE WarehouseToHome IS NULL;

UPDATE customer_churn
SET HourSpendOnApp = (SELECT m FROM (SELECT ROUND(AVG(HourSpendOnApp)) AS m FROM customer_churn) t)
WHERE HourSpendOnApp IS NULL;

UPDATE customer_churn
SET OrderAmountHikeFromlastYear = (SELECT m FROM (SELECT ROUND(AVG(OrderAmountHikeFromlastYear)) AS m FROM customer_churn) t)
WHERE OrderAmountHikeFromlastYear IS NULL;

UPDATE customer_churn
SET DaySinceLastOrder = (SELECT m FROM (SELECT ROUND(AVG(DaySinceLastOrder)) AS m FROM customer_churn) t)
WHERE DaySinceLastOrder IS NULL;

-- 1.2 Impute MODE ------------------------------------------------------
UPDATE customer_churn
SET Tenure = (SELECT v FROM (SELECT Tenure AS v FROM customer_churn
                             WHERE Tenure IS NOT NULL
                             GROUP BY Tenure ORDER BY COUNT(*) DESC LIMIT 1) t)
WHERE Tenure IS NULL;

UPDATE customer_churn
SET CouponUsed = (SELECT v FROM (SELECT CouponUsed AS v FROM customer_churn
                                 WHERE CouponUsed IS NOT NULL
                                 GROUP BY CouponUsed ORDER BY COUNT(*) DESC LIMIT 1) t)
WHERE CouponUsed IS NULL;

UPDATE customer_churn
SET OrderCount = (SELECT v FROM (SELECT OrderCount AS v FROM customer_churn
                                 WHERE OrderCount IS NOT NULL
                                 GROUP BY OrderCount ORDER BY COUNT(*) DESC LIMIT 1) t)
WHERE OrderCount IS NULL;

-- 1.3 Outliers : delete rows where WarehouseToHome > 100 ---------------
DELETE FROM customer_churn WHERE WarehouseToHome > 100;

-- 1.4 Inconsistencies --------------------------------------------------
UPDATE customer_churn SET PreferredLoginDevice = 'Mobile Phone' WHERE PreferredLoginDevice = 'Phone';
UPDATE customer_churn SET PreferedOrderCat      = 'Mobile Phone' WHERE PreferedOrderCat      = 'Mobile';

UPDATE customer_churn SET PreferredPaymentMode = 'Cash on Delivery' WHERE PreferredPaymentMode = 'COD';
UPDATE customer_churn SET PreferredPaymentMode = 'Credit Card'      WHERE PreferredPaymentMode = 'CC';

-- 2.1 Rename columns ---------------------------------------------------
ALTER TABLE customer_churn RENAME COLUMN PreferedOrderCat TO PreferredOrderCat;
ALTER TABLE customer_churn RENAME COLUMN HourSpendOnApp   TO HoursSpentOnApp;

-- 2.2 New columns ------------------------------------------------------
ALTER TABLE customer_churn ADD COLUMN ComplaintReceived VARCHAR(3);
UPDATE customer_churn SET ComplaintReceived = CASE WHEN Complain = 1 THEN 'Yes' ELSE 'No' END;

ALTER TABLE customer_churn ADD COLUMN ChurnStatus VARCHAR(10);
UPDATE customer_churn SET ChurnStatus = CASE WHEN Churn = 1 THEN 'Churned' ELSE 'Active' END;

-- 2.3 Drop columns -----------------------------------------------------
ALTER TABLE customer_churn DROP COLUMN Churn, DROP COLUMN Complain;

DESCRIBE customer_churn;
SELECT * FROM customer_churn LIMIT 10;

-- Q1. Count of churned and active customers
SELECT ChurnStatus, COUNT(*) AS CustomerCount
FROM customer_churn
GROUP BY ChurnStatus;

-- Q2. Average tenure and total cashback of churned customers
SELECT ROUND(AVG(Tenure), 2) AS AvgTenure,
       SUM(CashbackAmount)   AS TotalCashback
FROM customer_churn
WHERE ChurnStatus = 'Churned';

-- Q3. Percentage of churned customers who complained
SELECT ROUND(SUM(ComplaintReceived = 'Yes') * 100.0 / COUNT(*), 2) AS ChurnedComplainedPct
FROM customer_churn
WHERE ChurnStatus = 'Churned';

-- Q4. City tier with most churned customers whose order category is Laptop & Accessory
SELECT CityTier, COUNT(*) AS ChurnedCustomers
FROM customer_churn
WHERE ChurnStatus = 'Churned' AND PreferredOrderCat = 'Laptop & Accessory'
GROUP BY CityTier
ORDER BY ChurnedCustomers DESC
LIMIT 1;

-- Q5. Most preferred payment mode among active customers
SELECT PreferredPaymentMode, COUNT(*) AS CustomerCount
FROM customer_churn
WHERE ChurnStatus = 'Active'
GROUP BY PreferredPaymentMode
ORDER BY CustomerCount DESC
LIMIT 1;

-- Q6. Total order amount hike from last year : single customers who prefer Mobile Phone
SELECT SUM(OrderAmountHikeFromlastYear) AS TotalOrderAmountHike
FROM customer_churn
WHERE MaritalStatus = 'Single' AND PreferredOrderCat = 'Mobile Phone';

-- Q7. Average number of devices registered : UPI users
SELECT ROUND(AVG(NumberOfDeviceRegistered), 2) AS AvgDevicesRegistered
FROM customer_churn
WHERE PreferredPaymentMode = 'UPI';

-- Q8. City tier with the highest number of customers
SELECT CityTier, COUNT(*) AS CustomerCount
FROM customer_churn
GROUP BY CityTier
ORDER BY CustomerCount DESC
LIMIT 1;

-- Q9. Gender that used the highest number of coupons
SELECT Gender, SUM(CouponUsed) AS TotalCoupons
FROM customer_churn
GROUP BY Gender
ORDER BY TotalCoupons DESC
LIMIT 1;

-- Q10. Number of customers and max hours spent on app, per order category
SELECT PreferredOrderCat,
       COUNT(*)             AS CustomerCount,
       MAX(HoursSpentOnApp) AS MaxHoursSpentOnApp
FROM customer_churn
GROUP BY PreferredOrderCat;

-- Q11. Total order count : credit-card users with the maximum satisfaction score
SELECT SUM(OrderCount) AS TotalOrderCount
FROM customer_churn
WHERE PreferredPaymentMode = 'Credit Card'
  AND SatisfactionScore = (SELECT MAX(SatisfactionScore) FROM customer_churn);

-- Q12. Average satisfaction score of customers who complained
SELECT ROUND(AVG(SatisfactionScore), 2) AS AvgSatisfactionScore
FROM customer_churn
WHERE ComplaintReceived = 'Yes';

-- Q13. Preferred order category among customers who used more than 5 coupons
SELECT PreferredOrderCat, COUNT(*) AS CustomerCount
FROM customer_churn
WHERE CouponUsed > 5
GROUP BY PreferredOrderCat
ORDER BY CustomerCount DESC;

-- Q14. Top 3 order categories by average cashback amount
SELECT PreferredOrderCat, ROUND(AVG(CashbackAmount), 2) AS AvgCashback
FROM customer_churn
GROUP BY PreferredOrderCat
ORDER BY AvgCashback DESC
LIMIT 3;

-- Q15. Payment modes whose customers have average tenure of 10 months and > 500 orders
SELECT PreferredPaymentMode,
       ROUND(AVG(Tenure), 2) AS AvgTenure,
       SUM(OrderCount)       AS TotalOrders
FROM customer_churn
GROUP BY PreferredPaymentMode
HAVING ROUND(AVG(Tenure)) = 10 AND SUM(OrderCount) > 500;

-- Q16. Distance categories and churn-status breakdown
SELECT CASE
           WHEN WarehouseToHome <= 5  THEN 'Very Close Distance'
           WHEN WarehouseToHome <= 10 THEN 'Close Distance'
           WHEN WarehouseToHome <= 15 THEN 'Moderate Distance'
           ELSE 'Far Distance'
       END AS DistanceCategory,
       ChurnStatus,
       COUNT(*) AS CustomerCount
FROM customer_churn
GROUP BY DistanceCategory, ChurnStatus
ORDER BY FIELD(DistanceCategory, 'Very Close Distance', 'Close Distance',
                                 'Moderate Distance', 'Far Distance'),
         ChurnStatus;

-- Q17. Order details : married, City Tier-1, order count above the overall average
SELECT CustomerID, MaritalStatus, CityTier, OrderCount,
       OrderAmountHikeFromlastYear, CouponUsed, DaySinceLastOrder, CashbackAmount
FROM customer_churn
WHERE MaritalStatus = 'Married'
  AND CityTier = 1
  AND OrderCount > (SELECT AVG(OrderCount) FROM customer_churn);

-- Q18 (a). Create customer_returns and insert the data
CREATE TABLE customer_returns (
    ReturnID     INT PRIMARY KEY,
    CustomerID   INT,
    ReturnDate   DATE,
    RefundAmount INT
);

INSERT INTO customer_returns (ReturnID, CustomerID, ReturnDate, RefundAmount) VALUES
(1001, 50022, '2023-01-01', 2130),
(1002, 50316, '2023-01-23', 2000),
(1003, 51099, '2023-02-14', 2290),
(1004, 52321, '2023-03-08', 2510),
(1005, 52928, '2023-03-20', 3000),
(1006, 53749, '2023-04-17', 1740),
(1007, 54206, '2023-04-21', 3250),
(1008, 54838, '2023-04-30', 1990);

SELECT * FROM customer_returns;

-- Q18 (b). Return details with customer details : churned customers who complained
SELECT r.ReturnID, r.ReturnDate, r.RefundAmount, c.*
FROM customer_returns r
JOIN customer_churn c ON c.CustomerID = r.CustomerID
WHERE c.ChurnStatus = 'Churned'
  AND c.ComplaintReceived = 'Yes';