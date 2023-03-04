-- SQL Project Manuscript
-- Data – https://www.samhsa.gov/data/data-we-collect/mh-cld-mental-health-client-level-data
-- Data Composition Dashboard 
-- Tables not shown here were automatically transported from key code and joined with table above (in the link). 

-- Race/Ethnicity 
-- The process shown here is streamlined later on. 

-- Cleaning tables and adjusting to correct data types
UPDATE ethnic
SET frequency = REPLACE(frequency, ',','');

UPDATE ethnic
SET percentage = REPLACE(percentage, '%','');

ALTER TABLE ethnic
MODIFY COLUMN frequency INT;

ALTER TABLE ethnic
MODIFY COLUMN percentage DOUBLE;

-- Creating table to export to Excel for race/Ethnicity bar chart 
SELECT race.value AS race_no, 
ethnic.value AS ethnic_no, 
race.label AS race, 
ethnic.label AS ethnic, 
COUNT(ethnic.value) AS race_ethnic
FROM god
LEFT JOIN ethnic ON god.ethnic = ethnic.value 
LEFT JOIN race ON god.race = race.value
GROUP BY ethnic.value, ethnic.label, race.value, race.label
ORDER BY race.label ASC, ethnic.value ASC;

-- Employment Status 

-- Cleaning Employment Data
UPDATE detnlf
SET frequency = REPLACE(frequency, ',',''),
       percentage = RTRIM(REPLACE(percentage,'%',''));

ALTER TABLE detnlf
MODIFY COLUMN frequency INT;

ALTER TABLE detnlf
MODIFY COLUMN percentage DOUBLE;

-- Getting a general view of the joined tables/patterns
SELECT god.employ, employ.label, god.detnlf, detnlf.label, COUNT(detnlf.label)
FROM god
RIGHT JOIN employ ON employ.value = god.employ
RIGHT JOIN detnlf ON detnlf.value = god.detnlf
GROUP BY god.employ, employ.label, god.detnlf, detnlf.label;

-- Creating a temporary table to do the analyses 
CREATE TEMPORARY TABLE temp_employment 
SELECT employ.value AS employ_value, 
employ.label AS employ_label, 
detnlf.value AS detnlf_value, 
detnlf.label AS detnlf_label
FROM god 
RIGHT JOIN employ ON employ.value = god.employ
RIGHT JOIN detnlf ON detnlf.value = god.detnlf;

-- Adding a column that will do the final labelling of employment status
ALTER TABLE temp_employment
ADD COLUMN employ_final VARCHAR(200);

-- Setting unemployed to the more specific labels & other minor tweaks below
UPDATE temp_employment
SET employ_final = 
(CASE 
		WHEN employ_value = 5 THEN detnlf_label
		ELSE employ_label 
		END);

UPDATE temp_employment
SET employ_final = 'Not in labor force - Other'
WHERE employ_value =5 AND detnlf_value = 5;

UPDATE temp_employment
SET employ_final = CONCAT('Not in labor force',' - ', employ_final)
WHERE employ_value = 5 AND detnlf_value BETWEEN 1 AND 4;

-- Creating the percent of total/final summation table 
SELECT DISTINCT 
employ_value, 
detnlf_value, 
employ_final, 
COUNT(employ_final) OVER (PARTITION BY employ_final) AS amount_by_employ,
CONCAT(ROUND(((COUNT(employ_final) OVER (PARTITION BY employ_final)/.     COUNT(employ_final) OVER())*100),2),'%') AS peroftotal
FROM temp_employment;

-- Education
-- Cleaning education set (Found an error, 0-11 year olds with 12+ years of education)

UPDATE educ
JOIN god ON educ.value = god.educ
JOIN Age ON age.value = god.age
SET educ.value = -9, educ.label = 'Missing/unknown/not collected/invalid'
WHERE age.value =1 AND educ.value IN (4,5);

UPDATE educ 
SET frequency = TRIM(REPLACE(frequency,',','')), percentage			=TRIM(REPLACE(percentage,'%',''));

ALTER TABLE educ
MODIFY COLUMN frequency INT;

ALTER TABLE educ
MODIFY COLUMN percentage DOUBLE;

SELECT value, label, SUM(frequency) AS frequency, SUM(percentage) AS percentage
FROM educ
GROUP BY label, value
ORDER BY value ASC;

-- Mental Health Dashboard  

-- Most common mental health diagnoses 
SELECT 
mh1.label, 
mh1.frequency, 
mh2.frequency, 
mh3.frequency, 
(mh1.frequency + mh2.frequency +mh3.frequency) AS total 
FROM mh1
	JOIN mh2 ON mh1.value = mh2.value
	JOIN mh3 ON mh2.value = mh3.value
GROUP BY mh1.label, mh1.frequency, mh2.frequency, mh3.frequency, total 
ORDER BY total DESC;

-- Most common mental health diagnoses for those with trauma 
-- Create temporary table 
DROP IF EXISTS
CREATE TEMPORARY TABLE temp_top_trauma_mh

SELECT mh1.label, mh1.frequency
FROM god 
	JOIN mh1 ON god.mh1 = mh1.value
WHERE god.traustreflg = 1

UNION ALL

SELECT mh2.label, mh2.frequency 
FROM god 
	JOIN mh2 ON god.mh2 = mh2.value
WHERE god.traustreflg = 1
	
UNION ALL

SELECT mh3.label, mh3.frequency 
FROM god
	JOIN mh3 ON god.mh3 = mh3.value 
WHERE god.traustreflg = 1;

-- Create final table to export to excel
SELECT label, COUNT(label) AS Total
FROM temp_top_trauma_MH
GROUP BY label
ORDER BY total DESC;

-- Substance abuse and trauma correlation 

-- Cleaning alcflg table 
DELETE FROM alcflg
WHERE label = "Total";

UPDATE alcflg
SET frequency = REPLACE(frequency,',',''), 
       percentage = REPLACE(percentage, '%','');

ALTER TABLE alcflg
MODIFY COLUMN frequency INT;

ALTER TABLE alcflg
MODIFY COLUMN percentage DOUBLE;
	
-- Taking a look at the overlap between substance and alcflg tables (Conclusion - everything is covered by Substance so I don't need alcflg)
SELECT DISTINCT alcflg.value AS alcflg_no, 
     alcflg.label AS alcflg, 
     substance.value AS substance_no, 
     substance.label AS substance
FROM GOD
RIGHT JOIN alcflg ON god.alcsubflg = alcflg.value 
RIGHT JOIN substance ON god.sap = substance.value;

-- Designing table for substance abuse x and trauma/stress correlation (aka % of substance abuse that is tied to a trauma/stress flag)
SELECT substance.label AS substance_abuse, 
	count(substance.label) AS num_people, 
	substance.frequency AS total_per_substance, 
CONCAT(ROUND((COUNT(substance.label)/substance.frequency)*100,2),'%') AS trauma_per_substance from god
JOIN substance ON substance.value = god.sub
JOIN trauma ON trauma.value = god.traustreflg
	WHERE trauma.value = 1 AND substance.value <> -9
	GROUP BY substance.label, trauma.label, substance.frequency
	ORDER BY substance_abuse ASC;

-- Looking at all flags in the data set 
-- Creating a view of all flags and a count for each line of how many flags that person has
CREATE VIEW all_flags AS
SELECT adhdflg, alcsubflg, anxietyflg, bipolarflg, conductflg, delirdemflg, depressflg, oddflg, otherdisflg, pddflg, personflg, schizoflg, traustreflg, (adhdflg + alcsubflg +anxietyflg + bipolarflg + conductflg + delirdemflg + depressflg + oddflg + otherdisflg + pddflg + personflg + schizoflg + traustreflg) AS total
FROM GOD;

-- Adding in a summation, groupings by # of flags
SELECT total, COUNT(total)
FROM all_flags
GROUP BY total
ORDER BY total ASC;

-- Make a chart of most common mental illness for various groups of different # of flags 
SELECT adhdflg, alcsubflg, anxietyflg, bipolarflg, conductflg, delirdemflg, depressflg, oddflg, otherdisflg, pddflg, personflg, schizoflg, traustreflg, mh1.label
FROM god
JOIN mh1 ON god.mh1 = mh1.value 

UNION ALL

SELECT adhdflg, alcsubflg, anxietyflg, bipolarflg, conductflg, delirdemflg, depressflg, oddflg, otherdisflg, pddflg, personflg, schizoflg, traustreflg, mh2.label
FROM god
JOIN mh2 ON god.mh2 = mh2.value 

UNION ALL

SELECT adhdflg, alcsubflg, anxietyflg, bipolarflg, conductflg, delirdemflg, depressflg, oddflg, otherdisflg, pddflg, personflg, schizoflg, traustreflg, mh3.label
FROM god
JOIN mh3 ON god.mh3 = mh3.value

-- Race Dashboard

-- Top Mental Health Illnesses by Race and Ethnicity
SELECT race, race.label, ethnic, ethnic.label, mh1.label, COUNT(race) AS total
FROM god
LEFT JOIN race ON god.race = race.value
LEFT JOIN ethnic ON god.ethnic = ethnic.value 
LEFT JOIN mh1 ON god.mh1 = mh1.value
GROUP BY race, race.label, ethnic, ethnic.label, mh1.label

UNION ALL 

SELECT race, race.label, ethnic, ethnic.label, mh2.label, COUNT(race) AS total
FROM god
LEFT JOIN race ON god.race = race.value
LEFT JOIN ethnic ON god.ethnic = ethnic.value
LEFT JOIN mh2 ON god.mh2 = mh2.value 
GROUP BY race, race.label, ethnic, ethnic.label, mh2.label

UNION ALL 

SELECT race, race.label, ethnic, ethnic.label, mh3.label, COUNT(race)AS Total
FROM god
LEFT JOIN race ON god.race = race.value
LEFT JOIN ethnic ON god.ethnic = ethnic.value 
LEFT JOIN mh3 ON god.mh3 = mh3.value 
GROUP BY race, race.label, ethnic, ethnic.label, mh3.label;

-- Trauma by Race 
SELECT DISTINCT ethnic,
     ethnic.label, 
     race, 
     race.label, 
     sap, 
     substance.label, 
     COUNT(ethnic.label) OVER (PARTITION BY ethnic, substance.label),  
     COUNT(race.label) OVER (PARTITION BY race, substance.label), 
(COUNT(ethnic.label) OVER (PARTITION BY ethnic.label)) AS ethnic_total, 
(COUNT(race.label) OVER (PARTITION BY race.label)) AS race_total
FROM GOD
LEFT JOIN ethnic ON god.ethnic = ethnic.value
LEFT JOIN race ON god.race = race.value
LEFT JOIN Substance ON god.sap = substance.value;

-- Substance Abuse by Race 
SELECT ethnic.value, ethnic.label, race.value, race.label, substance.value, substance.label, 
	COUNT(ethnic.value) OVER (PARTITION BY ethnic.value, race.value, substance.value),
FROM God
	LEFT JOIN ethnic ON god.ethnic = ethnic.value
	LEFT JOIN race ON god.race = race.value 
	LEFT JOIN substance ON god.sap = substance.value; 

-- Gender Dashboard 
-- Top Mental Health Diagnoses by Gender 
SELECT god.gender AS gender_no, 
	gender.label AS gender, 
	mh1.label AS mental_illness, 
	COUNT(gender.label) AS no_people
FROM god
JOIN gender ON god.gender = gender.value
JOIN mh1 ON god.mh1 = mh1.value 
GROUP BY god.gender, gender.label, mh1.label

UNION ALL 

SELECT god.gender, gender.label, mh2.label, COUNT(gender.label)
FROM god
JOIN Gender ON god.gender = gender.value
JOIN mh2 ON god.mh2 = mh2.value 
GROUP BY god.gender, gender.label, mh2.label

UNION ALL

SELECT god.gender, gender.label, mh3.label, COUNT(gender.label)
FROM god
JOIN gender ON god.gender = gender.value
JOIN mh3 ON god.mh3 = mh3.value 
GROUP BY god.gender, gender.label, mh3.label;

-- Gender and Race, the most common Mental Health Disorders for Each Combination
-- copying the above and adding in the race factor 
SELECT god.gender AS gender_no, 
	gender.label AS gender, 
	mh1.label AS mental_illness, 
	race.label AS race, 
	COUNT(gender.label) AS no_people
FROM god
	JOIN gender ON god.gender = gender.value
	JOIN mh1 ON god.mh1 = mh1.value 
	JOIN race ON god.race = race.value
GROUP BY god.gender, gender.label, race.label, mh1.label

UNION ALL 

SELECT god.gender, gender.label, mh2.label, race.label, COUNT(gender.label)
FROM god
	JOIN Gender ON god.gender = gender.value
	JOIN mh2 ON god.mh2 = mh2.value 
	JOIN race ON god.race = race.value
GROUP BY god.gender, gender.label, race.label, mh2.label

UNION ALL

SELECT god.gender, gender.label, mh3.label, race.label, COUNT(gender.label)
FROM god
	JOIN gender ON god.gender = gender.value
	JOIN mh3 ON god.mh3 = mh3.value 
	JOIN race ON god.race = race.value
GROUP BY god.gender, gender.label, race.label, mh3.label;

-- Top Mental Health Issues - Gender, Marital Status, Employment
-- Cleaning marital status table (‘mar)
UPDATE mar
SET frequency = REPLACE(frequency, ',',''), 
percentage = REPLACE(percentage, '%','');

ALTER TABLE mar
MODIFY COLUMN frequency INT;

ALTER TABLE mar
MODIFY COLUMN percentage DOUBLE;

-- Using same as before, pulling gender, marital status, employment and summing it by those categories. Unfortunately also linking in detlnf took too long (query ran for 50 minutes and I finally canceled it).

SELECT god.gender AS gender_no, 
	gender.label AS gender, 
	mh1.label AS mental_illness, 
	mar.label AS marital_status, 
	employ.label AS employment,
	COUNT(gender.label) AS no_people
FROM god
	JOIN gender ON god.gender = gender.value
	JOIN mh1 ON god.mh1 = mh1.value 
	JOIN mar ON god.race = mar.value
	JOIN employ ON god.employ = employ.value
GROUP BY god.gender, gender.label, mar.label, employ.label, mh1.label

UNION ALL 

SELECT god.gender AS gender_no, 
	gender.label AS gender, 
	mh2.label AS mental_illness, 
	mar.label AS marital_status, 
	employ.label AS employment,
	COUNT(gender.label) AS no_people
FROM god
	JOIN gender ON god.gender = gender.value
	JOIN mh2 ON god.mh2 = mh2.value 
	JOIN mar ON god.race = mar.value
	JOIN employ ON god.employ = employ.value
GROUP BY god.gender, gender.label, mar.label, employ.label, mh2.label

UNION ALL 

SELECT god.gender AS gender_no, 
	gender.label AS gender, 
	mh3.label AS mental_illness, 
	mar.label AS marital_status, 
	employ.label AS employment,
	COUNT(gender.label) AS no_people
FROM god
	JOIN gender ON god.gender = gender.value
	JOIN mh3 ON god.mh3 = mh3.value 
	JOIN mar ON god.race = mar.value
	JOIN employ ON god.employ = employ.value
GROUP BY god.gender, gender.label, mar.label, employ.label, mh3.label;

-- % of Gender that has Trauma 
SELECT gender.value AS gender_value, 
gender.label AS gender, 
trauma.label AS trauma, 
COUNT(gender.value) AS no_people
FROM god
	JOIN gender ON god.gender = gender.value
	JOIN trauma ON god.traustreflg = trauma.value
GROUP BY gender.value, gender.label, trauma.label;

-- Gender, Race, and Trauma
-- Applying the above, but adding in race 
SELECT gender.value AS gender_value, 
	gender.label AS gender, 
	race.label AS race,
	trauma.label AS trauma, 
	COUNT(gender.value) AS no_people
FROM god
	JOIN gender ON god.gender = gender.value
	JOIN race ON god.race = race.value
	JOIN trauma ON god.traustreflg = trauma.value
GROUP BY gender.value, gender.label, race.label, trauma.label;
