-- HEALTH & FITNESS CLUB MEMBERSHIP DATABASE
CREATE DATABASE IF NOT EXISTS health_fitness_club;
USE health_fitness_club;

CREATE TABLE IF NOT EXISTS Members (
    member_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(100) NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(15),
    gender VARCHAR(20),
    date_of_birth DATE,
    city VARCHAR(50),
    join_date DATE,
    status VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS Plans (
    plan_id INT PRIMARY KEY AUTO_INCREMENT,
    plan_name VARCHAR(50) NOT NULL,
    duration_months INT,
    monthly_fee DECIMAL(10,2),
    description VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS Member_Plans (
    membership_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT,
    plan_id INT,
    start_date DATE,
    end_date DATE,
    membership_status VARCHAR(20),
    FOREIGN KEY (member_id) REFERENCES Members(member_id),
    FOREIGN KEY (plan_id) REFERENCES Plans(plan_id)
);

CREATE TABLE IF NOT EXISTS Payment_History (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT,
    plan_id INT,
    payment_date DATE,
    amount DECIMAL(10,2),
    payment_method VARCHAR(30),
    payment_status VARCHAR(20),
    FOREIGN KEY (member_id) REFERENCES Members(member_id),
    FOREIGN KEY (plan_id) REFERENCES Plans(plan_id)
);

CREATE TABLE IF NOT EXISTS Attendance (
    attendance_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT,
    attendance_date DATE,
    check_in_time TIME,
    check_out_time TIME,
    FOREIGN KEY (member_id) REFERENCES Members(member_id)
);

-- FIX 1: create gym_membership properly from the supplied raw table
CREATE TABLE IF NOT EXISTS gym_membership_raw (
    id INT,
    gender VARCHAR(20),
    birthday DATE,
    Age INT,
    abonoment_type VARCHAR(50),
    visit_per_week DECIMAL(5,2),
    days_per_week DECIMAL(5,2),
    attend_group_lesson VARCHAR(20),
    avg_time_check_in TIME,
    avg_time_check_out TIME,
    avg_time_in_gym DECIMAL(10,2),
    personal_training VARCHAR(20),
    uses_sauna VARCHAR(20)
);

DROP TABLE IF EXISTS gym_membership;
CREATE TABLE gym_membership AS
SELECT * FROM gym_membership_raw;

SELECT * FROM gym_membership LIMIT 10;
SELECT COUNT(*) AS total_records FROM gym_membership;

-- Plans
INSERT INTO Plans (plan_name, duration_months, monthly_fee, description)
VALUES
('Premium', 12, 5000.00, 'Premium Gym Membership'),
('Standard', 12, 3000.00, 'Standard Gym Membership');

SELECT * FROM Plans;

-- FIX 2: ONE Members INSERT ONLY
INSERT INTO Members (member_id, gender, date_of_birth, status)
SELECT id, gender, birthday, 'Active'
FROM gym_membership;

SELECT COUNT(*) AS total_members FROM Members;

-- Member plans
INSERT INTO Member_Plans
(member_id, plan_id, start_date, end_date, membership_status)
SELECT
    m.member_id,
    CASE
        WHEN g.abonoment_type = 'Premium' THEN 1
        WHEN g.abonoment_type = 'Standard' THEN 2
    END,
    CURDATE(),
    DATE_ADD(CURDATE(), INTERVAL 12 MONTH),
    'Active'
FROM Members m
JOIN gym_membership g ON m.member_id = g.id
WHERE g.abonoment_type IN ('Premium','Standard');

SELECT COUNT(*) AS total_memberships FROM Member_Plans;

-- Attendance
INSERT INTO Attendance
(member_id, attendance_date, check_in_time, check_out_time)
SELECT id, CURDATE(), avg_time_check_in, avg_time_check_out
FROM gym_membership
WHERE avg_time_check_in IS NOT NULL
AND avg_time_check_out IS NOT NULL;

SELECT COUNT(*) AS total_attendance FROM Attendance;

-- Payments
INSERT INTO Payment_History
(member_id, plan_id, payment_date, amount, payment_method, payment_status)
SELECT
    mp.member_id,
    mp.plan_id,
    mp.start_date,
    p.monthly_fee,
    CASE
        WHEN MOD(mp.member_id,3)=0 THEN 'UPI'
        WHEN MOD(mp.member_id,3)=1 THEN 'Card'
        ELSE 'Cash'
    END,
    'Paid'
FROM Member_Plans mp
JOIN Plans p ON mp.plan_id = p.plan_id;

SELECT COUNT(*) AS total_payments FROM Payment_History;

-- Basic analysis
SELECT COUNT(*) AS total_members FROM Members;

SELECT gender, COUNT(*) AS total_members
FROM Members GROUP BY gender;

SELECT p.plan_name, COUNT(mp.member_id) AS total_members
FROM Member_Plans mp
JOIN Plans p ON mp.plan_id=p.plan_id
GROUP BY p.plan_name;

SELECT p.plan_name, COUNT(ph.payment_id) AS total_payments,
       SUM(ph.amount) AS total_revenue
FROM Payment_History ph
JOIN Plans p ON ph.plan_id=p.plan_id
GROUP BY p.plan_name;

SELECT payment_method, COUNT(*) AS total_payments,
       SUM(amount) AS total_revenue
FROM Payment_History
GROUP BY payment_method;

-- FIX 3: MRR = monthly fee of active memberships
SELECT SUM(p.monthly_fee) AS MRR
FROM Member_Plans mp
JOIN Plans p ON mp.plan_id=p.plan_id
WHERE mp.membership_status='Active';

SELECT p.plan_name, COUNT(*) AS active_memberships,
       SUM(p.monthly_fee) AS MRR
FROM Member_Plans mp
JOIN Plans p ON mp.plan_id=p.plan_id
WHERE mp.membership_status='Active'
GROUP BY p.plan_name;

-- Monthly payment revenue (not MRR)
SELECT DATE_FORMAT(payment_date,'%Y-%m') AS month,
       SUM(amount) AS monthly_revenue
FROM Payment_History
WHERE payment_status='Paid'
GROUP BY DATE_FORMAT(payment_date,'%Y-%m')
ORDER BY month;

-- Engagement
SELECT m.member_id, m.gender,
       g.abonoment_type AS plan_name,
       g.visit_per_week,
       g.attend_group_lesson
FROM Members m
JOIN gym_membership g ON m.member_id=g.id
WHERE g.visit_per_week <= 1
ORDER BY g.visit_per_week;

SELECT
    CASE
        WHEN visit_per_week=0 THEN 'No Visit'
        WHEN visit_per_week=1 THEN 'Low Engagement'
        WHEN visit_per_week BETWEEN 2 AND 3 THEN 'Moderate Engagement'
        ELSE 'High Engagement'
    END AS engagement_level,
    COUNT(*) AS total_members
FROM gym_membership
GROUP BY
    CASE
        WHEN visit_per_week=0 THEN 'No Visit'
        WHEN visit_per_week=1 THEN 'Low Engagement'
        WHEN visit_per_week BETWEEN 2 AND 3 THEN 'Moderate Engagement'
        ELSE 'High Engagement'
    END
ORDER BY total_members DESC;

SELECT abonoment_type AS plan_name,
       ROUND(AVG(visit_per_week),2) AS avg_visits_per_week,
       MIN(visit_per_week) AS minimum_visits,
       MAX(visit_per_week) AS maximum_visits,
       COUNT(*) AS total_members
FROM gym_membership
GROUP BY abonoment_type;

-- Churn risk (risk segmentation, NOT actual churn rate)
SELECT
    CASE
        WHEN visit_per_week <= 1 THEN 'High Risk'
        WHEN visit_per_week = 2 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS churn_risk_level,
    COUNT(*) AS total_members
FROM gym_membership
GROUP BY
    CASE
        WHEN visit_per_week <= 1 THEN 'High Risk'
        WHEN visit_per_week = 2 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END
ORDER BY total_members DESC;

-- FIX 4: ACTUAL CHURN RATE
-- Churn Rate = Cancelled/Expired memberships / Total memberships * 100
SELECT
    COUNT(*) AS total_memberships,
    SUM(CASE WHEN membership_status IN ('Cancelled','Expired')
             THEN 1 ELSE 0 END) AS churned_memberships,
    ROUND(
        100.0 * SUM(CASE WHEN membership_status IN ('Cancelled','Expired')
                          THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0), 2
    ) AS churn_rate_percent
FROM Member_Plans;

SELECT
    p.plan_name,
    COUNT(*) AS total_memberships,
    SUM(CASE WHEN mp.membership_status IN ('Cancelled','Expired')
             THEN 1 ELSE 0 END) AS churned_memberships,
    ROUND(
        100.0 * SUM(CASE WHEN mp.membership_status IN ('Cancelled','Expired')
                          THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0), 2
    ) AS churn_rate_percent
FROM Member_Plans mp
JOIN Plans p ON mp.plan_id=p.plan_id
GROUP BY p.plan_name;

-- Top members
SELECT id AS member_id, gender,
       abonoment_type AS plan_name,
       visit_per_week,
       attend_group_lesson,
       avg_time_check_in
FROM gym_membership
ORDER BY visit_per_week DESC
LIMIT 10;

-- FIX 5: DO NOT ADD ANOTHER PRIMARY KEY HERE.
-- membership_id is already the PRIMARY KEY of Member_Plans.

DESCRIBE Members;
DESCRIBE Plans;
DESCRIBE Member_Plans;
DESCRIBE Payment_History;
DESCRIBE Attendance;
SHOW TABLES;
USE health_fitness_club;

SHOW TABLES;
USE health_fitness_club;

SELECT COUNT(*) AS total_records
FROM gym_membership;
SELECT *
FROM gym_membership
LIMIT 10;
USE health_fitness_club;

SELECT COUNT(*) AS total_records
FROM gym_membership_raw;
USE health_fitness_club;

SELECT 
    'gym_membership' AS table_name,
    COUNT(*) AS total_records
FROM gym_membership

UNION ALL

SELECT 
    'members' AS table_name,
    COUNT(*) AS total_records
FROM members

UNION ALL

SELECT 
    'member_plans' AS table_name,
    COUNT(*) AS total_records
FROM member_plans

UNION ALL

SELECT 
    'plans' AS table_name,
    COUNT(*) AS total_records
FROM plans

UNION ALL

SELECT 
    'payment_history' AS table_name,
    COUNT(*) AS total_records
FROM payment_history

UNION ALL

SELECT 
    'attendance' AS table_name,
    COUNT(*) AS total_records
FROM attendance;
USE health_fitness_club;

SELECT COUNT(*) AS total_records
FROM gym_membership;

SELECT *
FROM gym_membership
LIMIT 10;
USE health_fitness_club;

SHOW TABLES;

SELECT COUNT(*) FROM Members;
SELECT COUNT(*) FROM Plans;
SELECT COUNT(*) FROM Member_Plans;
SELECT COUNT(*) FROM Payment_History;
SELECT COUNT(*) FROM Attendance;
USE health_fitness_club;

SHOW TABLES;
SELECT 'Members' AS Table_Name, COUNT(*) AS Total_Records FROM Members
UNION ALL
SELECT 'Plans', COUNT(*) FROM Plans
UNION ALL
SELECT 'Member_Plans', COUNT(*) FROM Member_Plans
UNION ALL
SELECT 'Payment_History', COUNT(*) FROM Payment_History
UNION ALL
SELECT 'Attendance', COUNT(*) FROM Attendance
UNION ALL
SELECT 'gym_membership_raw', COUNT(*) FROM gym_membership_raw
UNION ALL
SELECT 'gym_membership', COUNT(*) FROM gym_membership;
USE health_fitness_club;

-- 1. Check plans
SELECT * FROM Plans;

-- 2. Check membership records
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT member_id) AS unique_members,
    COUNT(DISTINCT membership_id) AS unique_membership_ids
FROM Member_Plans;

-- 3. Membership count by member
SELECT
    member_id,
    COUNT(*) AS membership_count
FROM Member_Plans
GROUP BY member_id
HAVING COUNT(*) > 1
LIMIT 20;

-- 4. Payment records
SELECT
    COUNT(*) AS total_payments,
    COUNT(DISTINCT payment_id) AS unique_payment_ids,
    COUNT(DISTINCT member_id) AS unique_paying_members
FROM Payment_History;

-- 5. Check payment distribution
SELECT
    payment_status,
    COUNT(*) AS total_records,
    SUM(amount) AS total_amount
FROM Payment_History
GROUP BY payment_status;

-- 6. Check membership plan distribution
SELECT
    plan_id,
    COUNT(*) AS total_memberships
FROM Member_Plans
GROUP BY plan_id;
USE health_fitness_club;

SELECT *
FROM Member_Plans
WHERE member_id IN (1, 2, 20)
ORDER BY membership_id
LIMIT 15;

SELECT *
FROM Payment_History
WHERE member_id IN (1, 2, 20)
ORDER BY payment_id
LIMIT 15;
SELECT
    plan_id,
    plan_name,
    COUNT(*) AS total
FROM Plans
GROUP BY plan_id, plan_name;

