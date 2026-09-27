-- Medical appointment no-show analysis | BigQuery GoogleSQL
-- Each row is an appointment, not a unique patient.
-- Highlight one complete query (through its semicolon) to run it separately.
-- These SELECT queries do not modify the source table.
-- no_show = 'Yes' means missed; 'No' means attended.

-- 1. Confirm the imported row count. Expected: 110527.
SELECT COUNT(*) AS total_appointments
FROM `practicing-508021.medical_appointments.appointments`;

-- 2. Establish the overall baseline. Expected: 22319 missed, 20.19%.
SELECT
  COUNT(*) AS total_appointments,
  COUNTIF(no_show = 'Yes') AS missed_appointments,
  COUNTIF(no_show = 'No') AS attended_appointments,
  ROUND(100.0 * COUNTIF(no_show = 'Yes') / COUNT(*), 2)
    AS no_show_percentage
FROM `practicing-508021.medical_appointments.appointments`;

-- 3. Check known quality issues. Expected: 0, 1, 7, 5.
-- Duplicate calculation assumes non-null IDs, verified in the source.
-- Ages over 100 are review flags, not proven errors.
SELECT
  COUNT(*) - COUNT(DISTINCT appointment_id) AS duplicate_appointment_ids,
  COUNTIF(age < 0) AS negative_ages,
  COUNTIF(age > 100) AS ages_over_100,
  COUNTIF(DATE(appointment_day) < DATE(scheduled_day))
    AS appointments_before_booking
FROM `practicing-508021.medical_appointments.appointments`;

-- 4. Inspect booking lead time, measured in calendar days (UTC).
-- This is not time spent in the waiting room.
SELECT
  appointment_id,
  DATE(scheduled_day) AS booking_date,
  DATE(appointment_day) AS appointment_date,
  DATE_DIFF(DATE(appointment_day), DATE(scheduled_day), DAY) AS waiting_days,
  no_show
FROM `practicing-508021.medical_appointments.appointments`
ORDER BY waiting_days DESC, appointment_id
LIMIT 20;

-- 5. Compare booking lead-time bands. Eligible denominator: 110522.
-- WITH names intermediate results; CASE assigns bands; GROUP BY aggregates.
WITH appointment_waits AS (
  SELECT
    no_show,
    DATE_DIFF(DATE(appointment_day), DATE(scheduled_day), DAY) AS waiting_days
  FROM `practicing-508021.medical_appointments.appointments`
), grouped_appointments AS (
  SELECT
    no_show,
    waiting_days,
    CASE
      WHEN waiting_days = 0 THEN 'Same day'
      WHEN waiting_days <= 7 THEN '1-7 days'
      WHEN waiting_days <= 14 THEN '8-14 days'
      WHEN waiting_days <= 30 THEN '15-30 days'
      ELSE '31+ days'
    END AS waiting_band
  FROM appointment_waits
  WHERE waiting_days >= 0
)
SELECT
  waiting_band,
  COUNT(*) AS total_appointments,
  COUNTIF(no_show = 'Yes') AS missed_appointments,
  ROUND(100.0 * COUNTIF(no_show = 'Yes') / COUNT(*), 2) AS no_show_percentage
FROM grouped_appointments
GROUP BY waiting_band
ORDER BY MIN(waiting_days);

-- 6. Compare age groups. Eligible denominator: 110526.
-- Exclude the negative age only here; retain ages over 100.
WITH age_groups AS (
  SELECT
    age,
    no_show,
    CASE
      WHEN age <= 17 THEN '0-17'
      WHEN age <= 34 THEN '18-34'
      WHEN age <= 49 THEN '35-49'
      WHEN age <= 64 THEN '50-64'
      ELSE '65+'
    END AS age_group
  FROM `practicing-508021.medical_appointments.appointments`
  WHERE age >= 0
)
SELECT
  age_group,
  COUNT(*) AS total_appointments,
  COUNTIF(no_show = 'Yes') AS missed_appointments,
  ROUND(100.0 * COUNTIF(no_show = 'Yes') / COUNT(*), 2) AS no_show_percentage
FROM age_groups
GROUP BY age_group
ORDER BY MIN(age);

-- 7. Compare recorded SMS status overall (0 = no, 1 = yes).
-- Recorded SMS does not establish that a patient read the message.
SELECT
  sms_received,
  COUNT(*) AS total_appointments,
  COUNTIF(no_show = 'Yes') AS missed_appointments,
  ROUND(100.0 * COUNTIF(no_show = 'Yes') / COUNT(*), 2) AS no_show_percentage
FROM `practicing-508021.medical_appointments.appointments`
GROUP BY sms_received
ORDER BY sms_received;

-- 8. Compare SMS status within lead-time bands.
-- This returns 9 observed combinations. No same-day SMS=1 group exists.
-- Grouping reduces lead-time differences but does not establish causality.
WITH appointment_waits AS (
  SELECT
    sms_received,
    no_show,
    DATE_DIFF(DATE(appointment_day), DATE(scheduled_day), DAY) AS waiting_days
  FROM `practicing-508021.medical_appointments.appointments`
), grouped_appointments AS (
  SELECT
    sms_received,
    no_show,
    waiting_days,
    CASE
      WHEN waiting_days = 0 THEN 'Same day'
      WHEN waiting_days <= 7 THEN '1-7 days'
      WHEN waiting_days <= 14 THEN '8-14 days'
      WHEN waiting_days <= 30 THEN '15-30 days'
      ELSE '31+ days'
    END AS waiting_band
  FROM appointment_waits
  WHERE waiting_days >= 0
)
SELECT
  waiting_band,
  sms_received,
  COUNT(*) AS total_appointments,
  COUNTIF(no_show = 'Yes') AS missed_appointments,
  ROUND(100.0 * COUNTIF(no_show = 'Yes') / COUNT(*), 2) AS no_show_percentage
FROM grouped_appointments
GROUP BY waiting_band, sms_received
ORDER BY MIN(waiting_days), sms_received;

-- 9. Compare recorded gender categories using rates, not just counts.
SELECT
  gender,
  COUNT(*) AS total_appointments,
  COUNTIF(no_show = 'Yes') AS missed_appointments,
  ROUND(100.0 * COUNTIF(no_show = 'Yes') / COUNT(*), 2) AS no_show_percentage
FROM `practicing-508021.medical_appointments.appointments`
GROUP BY gender
ORDER BY gender;
