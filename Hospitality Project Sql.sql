#---------------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------Hospitality Project-----------------------------------------------------------------#

Create database if not exists Hospitality;
use hospitality;

show tables;
Select * from fact_bookings;
Select * from fact_aggregated_bookings;
Select * from dim_rooms;
Select * from dim_hotels;
Select * from dim_date;
desc fact_bookings;

#-------------------Total Revenue----------------------#
select 
concat(Round(sum(revenue_realized)/1000000000,2),' B') as Total_Revenue
from fact_bookings;

#------------Total Bookings------------------------#
select 
concat(Round(count(booking_id)/1000,2),' K') as Total_bookings
from fact_bookings;

#---------------Total Capacity---------------------#
select
Concat(Round(sum(capacity)/1000,2),' K') as Total_Capacity
from fact_aggregated_bookings;

#-----------------Total Successful Booking------------------#
select
Concat(Round(sum(successful_bookings)/1000,2),' K') as Total_successful_Bookings
from fact_aggregated_bookings;

#--------------------Occupancy %--------------------------#
select 
Concat(Round(sum(successful_bookings)/sum(capacity)*100,2),'%') as `Occupancy %`
from fact_aggregated_bookings;

#-------------------Average Ratings-----------------------#
SELECT 
CONCAT('⭐ ', ROUND(AVG(ratings_given),1)) AS Avg_rating
FROM fact_bookings
WHERE ratings_given BETWEEN 1 AND 5; 

#-----------------No_of_Days -----------------------#

ALTER TABLE dim_date
ADD new_date DATE;

UPDATE dim_date
SET new_date = STR_TO_DATE(date,'%d-%m-%Y');

SELECT 
DATEDIFF(MAX(date), MIN(date)) + 1 AS no_of_days
FROM dim_date;

#--------------Total Cancelled Bookings----------------#

select count(booking_id) as Cancelled_bookings
from fact_bookings
where booking_status = "Cancelled";

#-----------------Cancellation % -----------------------#
SELECT 
Concat(ROUND(
COUNT(CASE WHEN booking_status = 'Cancelled' THEN 1 END) 
/ COUNT(*) * 100,2),' %') AS `cancellation %`
FROM fact_bookings;

#---------------------Total Checkout----------------------#
select count(*) as total_checkout
from fact_bookings
where booking_status = "checked out";

#---------------------Utilize capacity ----------------#
select sum(capacity) as Total_Capacity, sum(successful_bookings) as utilized_capacity, 
(SELECT 
concat(ROUND(
    SUM(successful_bookings) / SUM(capacity) * 100,
2),' %')) AS utilized_capacity_percentage
from fact_aggregated_bookings;

#---------------------Month wise Revenue--------------------#
SELECT 
MONTHNAME(STR_TO_DATE(check_in_date,'%d-%m-%Y')) AS Month,
CONCAT(ROUND(SUM(revenue_realized)/1000000,1),' M') AS Total_Revenue
FROM fact_bookings
GROUP BY MONTHNAME(STR_TO_DATE(check_in_date,'%d-%m-%Y'));

#-------------------Total no show bookings---------------#
select 
concat(round(count(booking_status)/1000,2),' K') as No_show_Bookings
from fact_bookings
where booking_status = "No Show";

#------------------No Show rate %--------------------------#
Select concat(round(
    (Count(Case When booking_status = 'No Show' then 1 end) * 100.0) 
    / Count(*),2),'%') as "No Show Rate %"
FROM fact_bookings;

#-----------------------Booking % by Platform-----------------#
SELECT 
booking_platform,
CONCAT(ROUND(COUNT(booking_id) * 100.0 
/ (SELECT COUNT(*) FROM fact_bookings),2),' %') AS booking_percentage
FROM fact_bookings
GROUP BY booking_platform;

#------------------Booking % by Room class-----------------------#
SELECT 
r.room_class,
COUNT(f.booking_id) AS total_bookings,
concat(ROUND(COUNT(f.booking_id) * 100.0
    / (SELECT COUNT(*) FROM fact_bookings),2),' %') AS booking_percentage
FROM fact_bookings f
JOIN dim_rooms r
ON f.room_category = r.room_id
GROUP BY r.room_class;

#-----------------------ADR-(Average Daily Rate)------------------------#
SELECT 
ROUND(SUM(revenue_realized) 
    / count(*),2) AS ADR
from fact_bookings;

#----------------------Realization %------------------------------#
Select concat(round(
    (Count(Case When booking_status = 'Checked Out' then 1 end) * 100.0) 
    / Count(*),2),'%') as "Realization %"
FROM fact_bookings;

#--------------RevPar-(Revenue Per Available Room)--------------#
SELECT 
ROUND(
    (SELECT SUM(revenue_realized) FROM fact_bookings)
    /
    (SELECT SUM(capacity) FROM fact_aggregated_bookings),
2) AS RevPAR;

#---------------DBRN-(Daily Booked Room Nights)----------------#
select 
count(fb.booking_id) / count(distinct dd.date) as DBRN
from fact_bookings fb
join dim_date dd 
on STR_TO_DATE(fb.check_in_date,'%d-%m-%Y') = dd.date;

#---------------------- DSRN (Daily Sellable Room Nights)-----------------------#
select
sum(ag.capacity) / count(distinct dd.date) as DSRN
from fact_aggregated_bookings ag
join dim_date dd 
on str_to_date(ag.check_in_date,'%d-%m-%Y') = dd.date;

#----------------------DURN (Daily Utilized Room Nights)-----------------------#

select round((count(fb.booking_status)/count(distinct dd.date)),2) as 'DURN'
from fact_bookings fb
join dim_date dd 
on str_to_date(fb.check_in_date,'%d-%m-%Y') = dd.date
where booking_status = 'Checked Out';

#----------------------Weekend/Weekday wise Revenue -------------------------#
  select dd.day_type,
  concat(round((sum(fb.revenue_realized)/1000000),2),' M') as Total_Revenue,
  concat(round(sum(fb.revenue_realized) * 100.0 / (SELECT sum(revenue_realized) FROM fact_bookings), 2),'%') as 'Revenue%'
  from dim_date dd
  inner join fact_bookings fb on dd.date = str_to_date(fb.check_in_date,'%d-%m-%Y')
  group by dd.Day_type;
  
#-----------------------------Revenue WoW change %----------------------------#
SELECT 
week_no,
CONCAT(ROUND(total_revenue/1000000,2),'M') AS total_revenue,
CONCAT(ROUND((total_revenue - LAG(total_revenue) 
OVER(ORDER BY week_no))
/
LAG(total_revenue) OVER(ORDER BY week_no)*100,2),'%') AS WoW_change
FROM
(SELECT 
    dd.week_no, 
    SUM(fb.revenue_realized) AS total_revenue
    FROM fact_bookings fb
    JOIN dim_date dd
    ON STR_TO_DATE(fb.check_in_date,'%d-%m-%Y') = dd.date
    GROUP BY dd.week_no) t;
    
#---------------------------ADR WoW change %---------------------------#
SELECT 
week_no,
CONCAT(ROUND(ADR/1000,2),' K') AS ADR,
CONCAT(ROUND((ADR - LAG(ADR) OVER(ORDER BY week_no))
/
LAG(ADR) OVER(ORDER BY week_no)*100,2),'%') AS ADR_WoW_change
FROM
(SELECT dd.week_no,
    SUM(fb.revenue_realized) 
    /
    COUNT(CASE 
            WHEN fb.booking_status='Checked Out' 
            THEN 1 
         END) AS ADR
    FROM fact_bookings fb
    JOIN dim_date dd
    ON STR_TO_DATE(fb.check_in_date,'%d-%m-%Y') = dd.date
    GROUP BY dd.week_no) t;

#------------------Revpar WoW change % ------------------------#
SELECT 
week_no,RevPAR,
CONCAT(ROUND(
(RevPAR - LAG(RevPAR) OVER(ORDER BY CAST(SUBSTRING(week_no,2) AS UNSIGNED)))
/
LAG(RevPAR) OVER(ORDER BY CAST(SUBSTRING(week_no,2) AS UNSIGNED))*100,2),'%') AS WoW_change_percentage
FROM
(SELECT rev.week_no,
    ROUND(revenue / capacity,2) AS RevPAR
    FROM
    (SELECT dd.week_no,
        SUM(fb.revenue_realized) revenue
        FROM fact_bookings fb
        JOIN dim_date dd
        ON STR_TO_DATE(fb.check_in_date,'%d-%m-%Y') = dd.date
        GROUP BY dd.week_no) rev
    JOIN
    (SELECT dd.week_no,
        SUM(ag.capacity) capacity
        FROM fact_aggregated_bookings ag
        JOIN dim_date dd
        ON STR_TO_DATE(ag.check_in_date,'%d-%m-%Y') = dd.date
        GROUP BY dd.week_no) cap
    ON rev.week_no = cap.week_no) t;

#---------------------Realisation WoW change %-----------------------#

SELECT 
week_no,
Realisation_pct,
CONCAT(
ROUND(
(Realisation_pct - LAG(Realisation_pct) 
OVER(ORDER BY CAST(SUBSTRING(week_no,2) AS UNSIGNED)))
/
LAG(Realisation_pct) 
OVER(ORDER BY CAST(SUBSTRING(week_no,2) AS UNSIGNED))
*100,2),' %') AS WoW_change
FROM
(SELECT dd.week_no,
CONCAT(ROUND(SUM(fb.revenue_realized) 
/
SUM(fb.revenue_generated) * 100,2),' %') AS Realisation_pct
    FROM fact_bookings fb
    JOIN dim_date dd
    ON STR_TO_DATE(fb.check_in_date,'%d-%m-%Y') = dd.date
    GROUP BY dd.week_no) t;

#----------------------DSRN WoW change %-----------------------#
SELECT 
week_no,
DSRN,
CONCAT(ROUND(
(DSRN - LAG(DSRN) OVER(ORDER BY CAST(SUBSTRING(week_no,2) AS UNSIGNED)))
/
LAG(DSRN) OVER(ORDER BY CAST(SUBSTRING(week_no,2) AS UNSIGNED))*100,2),'%') AS WoW_change_percentage
FROM
(SELECT week_no,
    ROUND(AVG(daily_capacity),0) AS DSRN
    FROM
    (SELECT dd.week_no,dd.date,
        SUM(ag.capacity) AS daily_capacity
        FROM fact_aggregated_bookings ag
        JOIN dim_date dd
        ON STR_TO_DATE(ag.check_in_date,'%d-%m-%Y') = dd.date
        GROUP BY dd.week_no, dd.date) x
    GROUP BY week_no) t;
    
#-----------------Revenue & Bookings by Property--------------------------#
  select dh.property_name, concat(round((sum(fb.revenue_realized)/1000000),2),'M') as Tot_Revenue,
  concat(round((count(fb.booking_id)/1000),2),' K') as Tot_Bookings
  from dim_hotels dh
  join fact_bookings fb on dh.property_id = fb.property_id
  group by dh.property_name
  order by dh.property_name asc;
  
   #------------------Revenue and Bookings by City---------------------------#
  select dh.city, concat(round((sum(fb.revenue_realized)/1000000),2),' M') as Total_Revenue,
  concat(round((count(fb.booking_id)/1000),2),' K') as Total_Bookings
  from dim_hotels dh
  join fact_bookings fb on dh.property_id = fb.property_id
  group by dh.city
  order by dh.city;
  
  #---------------------Booking status % ------------------------------#
Select booking_status , concat (Round(Count(booking_status) * 100.0 / (Select Count(*) from fact_bookings), 2), '%') as "Booking_status % "
from fact_bookings 
group by booking_status;
  
#--------------------------------------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------------------------------#