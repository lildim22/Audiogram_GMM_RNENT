/*======================================================================*
    COMPLETE SQL CODE FOR DATASET GENERATION
    Schema: hic_hh

This is from data exported from Auditbase and uses the Auditbase schema. 
*======================================================================*/

SET search_path TO hic_hh;


/*======================================================================*
    SECTION 1: INITIAL CHECKS & PRE-STAGE EXPLORATION
*======================================================================*/

-- Count total audiogram curve records
SELECT COUNT(*) FROM hic_hh.ab_audiogramcurve;   -- 417478

-- Inspect distinct curve types
SELECT DISTINCT(curve) FROM ab_audiogramcurve;
-- Curves present: 40, 43, 48, 1, 2, 10, 41, 11, 20, 30, 4, 49, 13, 50, 0

-- Only curves 0 (AC) and 10 (BC) are needed → create audio_val table
DROP TABLE IF EXISTS audio_val;

CREATE TABLE audio_val AS
SELECT 
    curve, patient_id, audindex, investdate,
    l250t, l250tm, l500t, l500tm, l1000t, l1000tm,
    l2000t, l2000tm, l4000t, l4000tm, l8000t, l8000tm,
    r250t, r250tm, r500t, r500tm, r1000t, r1000tm,
    r2000t, r2000tm, r4000t, r4000tm, r8000t, r8000tm
FROM audiogram_values
WHERE curve = 0 OR curve = 10;

-- Count
SELECT COUNT(*) FROM audio_val;   -- 349060


/*======================================================================*
    SECTION 2: DUPLICATE EVALUATION
*======================================================================*/


-- Duplicate checks
SELECT COUNT(DISTINCT audio_val.*) FROM audio_val;        -- 348851
SELECT COUNT(*) FROM (SELECT DISTINCT * FROM audio_val) x;  -- 348851

-- Store distinct records
DROP TABLE IF EXISTS audio_val_nodup;
CREATE TABLE audio_val_nodup AS (SELECT DISTINCT * FROM audio_val);

SELECT COUNT(*) FROM audio_val_nodup; -- 348851


/*======================================================================*
    SECTION 3: JOIN WITH PATIENT TABLE (ADD SEX & DOB to each record)
*======================================================================*/

DROP TABLE IF EXISTS audio_val_nodups;

CREATE TABLE audio_val_nodups AS
SELECT 
    ad.patient_id, ad.investdate, ad.audindex, ad.curve,
    pat.sex, pat.dateofbirth,
    ad.l250t, ad.l250tm, ad.l500t, ad.l500tm, ad.l1000t, ad.l1000tm,
    ad.l2000t, ad.l2000tm, ad.l4000t, ad.l4000tm, ad.l8000t, ad.l8000tm,
    ad.r250t, ad.r250tm, ad.r500t, ad.r500tm, ad.r1000t, ad.r1000tm,
    ad.r2000t, ad.r2000tm, ad.r4000t, ad.r4000tm, ad.r8000t, ad.r8000tm
FROM audio_val_nodup ad
LEFT JOIN ab_patient pat ON ad.patient_id = pat.patient_id;

SELECT COUNT(*) FROM hic_hh.audio_val_nodups;  -- 348851


/*======================================================================*
    SECTION 4: EXPLORING SEX VALUES
*======================================================================*/

-- Identify all sex codes present
SELECT DISTINCT sex FROM audio_val_nodups;
-- Values: (null), ' ', U, S, Y, C, O, M, F, B, P

-- Frequency of each
SELECT COUNT(*) FROM audio_val_nodups WHERE sex IS NULL;     -- 18350
SELECT COUNT(*) FROM audio_val_nodups WHERE sex = ' ';       -- 6
SELECT COUNT(*) FROM audio_val_nodups WHERE sex = 'U';       -- 48
SELECT COUNT(*) FROM audio_val_nodups WHERE sex = 'S';       -- 27
SELECT COUNT(*) FROM audio_val_nodups WHERE sex = 'Y';       -- 2
SELECT COUNT(*) FROM audio_val_nodups WHERE sex = 'C';       -- 6
SELECT COUNT(*) FROM audio_val_nodups WHERE sex = 'O';       -- 8
SELECT COUNT(*) FROM audio_val_nodups WHERE sex = 'M';       -- 151670
SELECT COUNT(*) FROM audio_val_nodups WHERE sex = 'F';       -- 178730
SELECT COUNT(*) FROM audio_val_nodups WHERE sex = 'B';       -- 2
SELECT COUNT(*) FROM audio_val_nodups WHERE sex = 'P';       -- 2

-- Summary checks
SELECT 18350 + 6 + 48 + 27 + 2 + 6 + 8 + 151670 + 178730 + 4 AS "Addition";   -- 348851
SELECT 151670 + 178730 AS "M+F";                                               -- 330400
SELECT 18350 + 6 + 48 + 27 + 2 + 6 + 8 + 4 AS "Non-sensible";                  -- 18451


/*======================================================================*
    SECTION 5: CROSS-CHECK SEX USING CABOODLE (DEMOGRAPHICS SOURCE from Electronic Health Record system used at the hospital)
*======================================================================*/

DROP TABLE IF EXISTS audio_val_sex_checked;

CREATE TABLE audio_val_sex_checked AS 
SELECT
    ads.patient_id AS patient_id_from_dataset,
    lp.subject_id AS subject_id_from_lookup_table,
    cd.gender AS code_from_caboodle_demographics,
    CASE cd.gender
        WHEN 1 THEN 'Male'
        WHEN 2 THEN 'Female'
        WHEN 9 THEN 'Not Specified'
        ELSE NULL
    END AS text_value_of_caboodle_code
FROM hic_hh.audio_val_nodups ads
LEFT JOIN hic_hh.zz_lookup_patient_cab lp 
    ON ads.patient_id = lp.patient_id
LEFT JOIN hic_hh.cab_demographics cd 
    ON lp.subject_id = cd.subject_id
WHERE ads.sex IS NULL 
   OR ads.sex LIKE ' %' 
   OR ads.sex IN ('S','U','P','C','O','Y','B');

SELECT COUNT(*) FROM audio_val_sex_checked;  -- 18448

-- Inspect caboodle-derived sex values
SELECT DISTINCT text_value_of_caboodle_code FROM audio_val_sex_checked;  -- Female, Male, null
SELECT COUNT(*) FROM audio_val_sex_checked WHERE code_from_caboodle_demographics IS NULL; -- 14776


/*======================================================================*
    SECTION 6: MATCH NON-SENSIBLE SEX VALUES WITH CABOODLE SEX
*======================================================================*/

-- Check overlap with original table
SELECT COUNT(*) FROM (
    SELECT patient_id_from_dataset
    FROM audio_val_sex_checked
    WHERE patient_id_from_dataset IN (
        SELECT patient_id FROM audio_val_nodups
        WHERE sex IS NULL OR sex IN ('P','C','O','U','S','Y','B') OR sex = ' '
    )
) lily;  -- 18448

-- Distinct patients
SELECT COUNT(DISTINCT patient_id_from_dataset)
FROM audio_val_sex_checked
WHERE patient_id_from_dataset IN (
    SELECT patient_id FROM audio_val_nodups
    WHERE sex IS NULL OR sex IN ('P','C','O','U','S','Y','B') OR sex = ' '
);  -- 6638

-- Incorrect → female
SELECT COUNT(*) FROM audio_val_sex_checked
WHERE text_value_of_caboodle_code = 'Female'
AND patient_id_from_dataset IN (
    SELECT patient_id FROM audio_val_nodups
    WHERE sex IS NULL OR sex IN ('P','C','O','U','S','Y','B') OR sex LIKE ' %'
);  -- 2060

-- Incorrect → male
SELECT COUNT(*) FROM audio_val_sex_checked
WHERE text_value_of_caboodle_code = 'Male'
AND patient_id_from_dataset IN (
    SELECT patient_id FROM audio_val_nodups
    WHERE sex IS NULL OR sex IN ('P','C','O','U','S','Y','B') OR sex LIKE ' %'
);  -- 1612


/*======================================================================*
    SECTION 7: UPDATE SEX VALUES IN MAIN TABLE
*======================================================================*/

DROP TABLE IF EXISTS audio_val_nodups_sex;
CREATE TABLE audio_val_nodups_sex AS SELECT * FROM audio_val_nodups;

-- Replace sex using caboodle-derived values
UPDATE audio_val_nodups_sex
SET sex = text_value_of_caboodle_code
FROM audio_val_sex_checked
WHERE audio_val_sex_checked.patient_id_from_dataset = audio_val_nodups_sex.patient_id;

-- Standardise to M/F
UPDATE audio_val_nodups_sex SET sex = 'F' WHERE sex = 'Female';
UPDATE audio_val_nodups_sex SET sex = 'M' WHERE sex = 'Male';

-- Retain only complete sex cases
DROP TABLE IF EXISTS audio_val_nodups_sexed;

CREATE TABLE audio_val_nodups_sexed AS
SELECT * FROM audio_val_nodups_sex
WHERE sex IN ('M', 'F');


/*======================================================================*
    SECTION 8: DATE OF BIRTH (DOB) QUALITY CHECKS
*======================================================================*/

-- Identify DOB issues
SELECT COUNT(*) FROM audio_val_nodups_sexed WHERE dateofbirth IS NULL;  -- 1878

-- Out-of-range DOBs
SELECT * FROM audio_val_nodups_sexed WHERE dateofbirth < '1901-01-01';  -- 25
SELECT * FROM audio_val_nodups_sexed WHERE dateofbirth = '1901-01-01';  -- 54


/*======================================================================*
    SECTION 9: HANDLE DUPLICATES IN LOOKUP TABLES (CAB & ADS)
*======================================================================*/

-- Detect duplicate patient_ids in zz_lookup_patient_cab
DROP VIEW IF EXISTS zz_lookup_patient_cab_dup;

CREATE VIEW zz_lookup_patient_cab_dup AS
SELECT patient_id, COUNT(*) AS freq
FROM zz_lookup_patient_cab
GROUP BY patient_id
HAVING COUNT(*) = 2;

-- Create de-duplicated lookup table
CREATE TABLE zz_lookup_patient_cab_lily AS
SELECT DISTINCT ON (patient_id)
    subject_id, patient_id, match_probability, local_patient_identifier
FROM zz_lookup_patient_cab
ORDER BY patient_id, match_probability DESC;


-- Same duplicate-handling for ADS lookup
DROP TABLE IF EXISTS zz_lookup_patient_ads_lily;

CREATE TABLE zz_lookup_patient_ads_lily AS
SELECT DISTINCT ON (patient_id)
    primary_mrn, nhs_number, patient_id, match_probability
FROM zz_lookup_patient_ads
ORDER BY patient_id, match_probability DESC;


/*======================================================================*
    SECTION 10: RETRIEVE MISSING DOB FROM CAB & ADS
*======================================================================*/

-- Identify missing DOB cases matched in CAB
CREATE TABLE audio_val_nodups_sexed_dob_cab AS
SELECT ab.*, cab.birth_date
FROM audio_val_nodups_sexed ab
JOIN zz_lookup_patient_cab_lily lc ON ab.patient_id = lc.patient_id
JOIN cab_demographics cab ON lc.subject_id = cab.subject_id
WHERE ab.dateofbirth IS NULL AND cab.birth_date IS NOT NULL;

ALTER TABLE audio_val_nodups_sexed_dob_cab
ALTER COLUMN birth_date TYPE date;

-- Identify missing DOB cases matched in ADS
CREATE TABLE audio_val_nodups_sexed_dob_ads AS
SELECT ab.*, ads.date_of_birth
FROM audio_val_nodups_sexed ab
JOIN zz_lookup_patient_ads_lily lc ON ab.patient_id = lc.patient_id
JOIN ads_pmi ads ON lc.primary_mrn = ads.primary_mrn
WHERE ab.dateofbirth IS NULL AND ads.date_of_birth IS NOT NULL;

ALTER TABLE audio_val_nodups_sexed_dob_ads
ALTER COLUMN date_of_birth TYPE date;


/*======================================================================*
    SECTION 11: UPDATE DOB VALUES & CLEAN DATA
*======================================================================*/

-- Apply ADS DOB corrections
UPDATE audio_val_nodups_sexed
SET dateofbirth = ads.date_of_birth
FROM audio_val_nodups_sexed_dob_ads ads
WHERE audio_val_nodups_sexed.patient_id = ads.patient_id
  AND audio_val_nodups_sexed.dateofbirth IS NULL;

-- Apply CAB DOB corrections
UPDATE audio_val_nodups_sexed
SET dateofbirth = cab.birth_date
FROM audio_val_nodups_sexed_dob_cab cab
WHERE audio_val_nodups_sexed.patient_id = cab.patient_id
  AND audio_val_nodups_sexed.dateofbirth IS NULL;


-- Remove DOB ≤ 1901
DROP TABLE IF EXISTS audio_val_nodups_sexed_dob;

CREATE TABLE audio_val_nodups_sexed_dob AS
SELECT * FROM audio_val_nodups_sexed;

DELETE FROM audio_val_nodups_sexed_dob
WHERE dateofbirth <= TO_DATE('01/01/1901', 'DD/MM/YYYY');

-- Remove remaining null DOBs
DELETE FROM audio_val_nodups_sexed_dob
WHERE dateofbirth IS NULL;


/*======================================================================*
    SECTION 12: CALCULATE AGE
*======================================================================*/

ALTER TABLE audio_val_nodups_sexed_dob ADD COLUMN ag INTERVAL;

UPDATE audio_val_nodups_sexed_dob
SET ag = AGE(investdate, dateofbirth);

ALTER TABLE audio_val_nodups_sexed_dob ADD COLUMN age INT;

UPDATE audio_val_nodups_sexed_dob
SET age = DATE_PART('year', ag)::INT;

-- Remove records where investdate < dateofbirth
DELETE FROM audio_val_nodups_sexed_dob
WHERE investdate < dateofbirth;


/*======================================================================*
    SECTION 13: DATASET with complete Age and Sex info
*======================================================================*/

DROP TABLE IF EXISTS audio;

CREATE TABLE audio AS
SELECT * FROM audio_val_nodups_sexed_dob;

SELECT COUNT(*) FROM audio;   -- 332229
SELECT * FROM audio WHERE dateofbirth IS NULL; -- 0
SELECT * FROM audio WHERE sex IS NULL;         -- 0

/*======================================================================*
    SECTION 14: REMOVE RECORDS WITH ALL-NULL THRESHOLDS i.e. audiograms without any values
*======================================================================*/

-- Count AC (curve = 10) rows where ALL thresholds are NULL
SELECT COUNT(*) 
FROM audio
WHERE curve = 10 AND
    l250t  IS NULL AND l250tm IS NULL AND
    l500t  IS NULL AND l500tm IS NULL AND
    l1000t IS NULL AND l1000tm IS NULL AND
    l2000t IS NULL AND l2000tm IS NULL AND
    l4000t IS NULL AND l4000tm IS NULL AND
    l8000t IS NULL AND l8000tm IS NULL AND
    r250t  IS NULL AND r250tm IS NULL AND
    r500t  IS NULL AND r500tm IS NULL AND
    r1000t IS NULL AND r1000tm IS NULL AND
    r2000t IS NULL AND r2000tm IS NULL AND
    r4000t IS NULL AND r4000tm IS NULL AND
    r8000t IS NULL AND r8000tm IS NULL;   -- 17,490


-- Count BC (curve = 0) rows where ALL thresholds are NULL
SELECT COUNT(*) 
FROM audio
WHERE curve = 0 AND
    l250t  IS NULL AND l250tm IS NULL AND
    l500t  IS NULL AND l500tm IS NULL AND
    l1000t IS NULL AND l1000tm IS NULL AND
    l2000t IS NULL AND l2000tm IS NULL AND
    l4000t IS NULL AND l4000tm IS NULL AND
    l8000t IS NULL AND l8000tm IS NULL AND
    r250t  IS NULL AND r250tm IS NULL AND
    r500t  IS NULL AND r500tm IS NULL AND
    r1000t IS NULL AND r1000tm IS NULL AND
    r2000t IS NULL AND r2000tm IS NULL AND
    r4000t IS NULL AND r4000tm IS NULL AND
    r8000t IS NULL AND r8000tm IS NULL;   -- 567

-- Total NULL-curves
SELECT 17490 + 567 AS "Addition";          -- 18057
SELECT 332229 - 18057 AS "Subtraction";    -- 314172 remaining


/*======================================================================*
    SECTION 15: REMOVE NULL-FREQUENCY RECORDS FROM COPY TABLE
*======================================================================*/

DROP TABLE IF EXISTS audio_nn;

CREATE TABLE audio_nn AS
SELECT * FROM audio;

-- Delete NULL-only threshold records (curve 10)
DELETE FROM audio_nn
WHERE curve = 10 AND
    l250t  IS NULL AND l250tm IS NULL AND
    l500t  IS NULL AND l500tm IS NULL AND
    l1000t IS NULL AND l1000tm IS NULL AND
    l2000t IS NULL AND l2000tm IS NULL AND
    l4000t IS NULL AND l4000tm IS NULL AND
    l8000t IS NULL AND l8000tm IS NULL AND
    r250t  IS NULL AND r250tm IS NULL AND
    r500t  IS NULL AND r500tm IS NULL AND
    r1000t IS NULL AND r1000tm IS NULL AND
    r2000t IS NULL AND r2000tm IS NULL AND
    r4000t IS NULL AND r4000tm IS NULL AND
    r8000t IS NULL AND r8000tm IS NULL;

-- Delete NULL-only threshold records (curve 0)
DELETE FROM audio_nn
WHERE curve = 0 AND
    l250t  IS NULL AND l250tm IS NULL AND
    l500t  IS NULL AND l500tm IS NULL AND
    l1000t IS NULL AND l1000tm IS NULL AND
    l2000t IS NULL AND l2000tm IS NULL AND
    l4000t IS NULL AND l4000tm IS NULL AND
    l8000t IS NULL AND l8000tm IS NULL AND
    r250t  IS NULL AND r250tm IS NULL AND
    r500t  IS NULL AND r500tm IS NULL AND
    r1000t IS NULL AND r1000tm IS NULL AND
    r2000t IS NULL AND r2000tm IS NULL AND
    r4000t IS NULL AND r4000tm IS NULL AND
    r8000t IS NULL AND r8000tm IS NULL;

SELECT COUNT(*) FROM audio_nn;   -- 314,172


/*======================================================================*
    SECTION 16: IDENTIFY DUPLICATE AUDIOGRAMS (IGNORE audindex)
*======================================================================*/

-- Count DISTINCT audiograms ignoring audindex
SELECT COUNT(*) 
FROM (
    SELECT DISTINCT
        patient_id, investdate, curve, age, sex,
        l250t, l250tm, l500t, l500tm, l1000t, l1000tm,
        l2000t, l2000tm, l4000t, l4000tm, l8000t, l8000tm,
        r250t, r250tm, r500t, r500tm, r1000t, r1000tm,
        r2000t, r2000tm, r4000t, r4000tm, r8000t, r8000tm
    FROM audio_nn
) lily;   -- 301,546

SELECT 314172 - 301546 AS "Duplicates_due_to_audindex"; -- 12,626

/*Audindex is an index of an audiogram per date - some people in the database have multiple audiograms on the same day. Some of these audiograms 
are actually duplicates - so the values are all but for whatever reason they have been logged twice or more and therefore differ by the audindex only.
This corresponds to 12626 records - in this case those records which differ by the audindex only - only the first record is retained (see Section 17)
*/

/*======================================================================*
    SECTION 17: REMOVE DUPLICATES BY MINIMUM audindex
*======================================================================*/

DROP TABLE IF EXISTS audio_audindex;

CREATE TABLE audio_audindex AS
SELECT
    MIN(audindex) AS audindex,
    patient_id, investdate, curve, age, sex,
    l250t, l250tm, l500t, l500tm, l1000t, l1000tm,
    l2000t, l2000tm, l4000t, l4000tm, l8000t, l8000tm,
    r250t, r250tm, r500t, r500tm, r1000t, r1000tm,
    r2000t, r2000tm, r4000t, r4000tm, r8000t, r8000tm
FROM audio_nn
GROUP BY
    patient_id, investdate, curve, age, sex,
    l250t, l250tm, l500t, l500tm, l1000t, l1000tm,
    l2000t, l2000tm, l4000t, l4000tm, l8000t, l8000tm,
    r250t, r250tm, r500t, r500tm, r1000t, r1000tm,
    r2000t, r2000tm, r4000t, r4000tm, r8000t, r8000tm;

SELECT COUNT(*) FROM audio_audindex;   -- 301,546


/*======================================================================*
    SECTION 18: IDENTIFY REMAINING MULTIPLE-AUDINDEX CASES
*======================================================================*/

/* after removing duplicate audiograms that differ only by the audindex we know look at those who have multiple audiograms on a given day that do differ.
*/

-- audindex counts
SELECT COUNT(*) FROM audio_audindex WHERE audindex >= 2;  -- 6,789

SELECT COUNT(*) FROM audio_audindex WHERE audindex = 2;   -- 6458
SELECT COUNT(*) FROM audio_audindex WHERE audindex = 3;   -- 283
SELECT COUNT(*) FROM audio_audindex WHERE audindex = 4;   -- 40
SELECT COUNT(*) FROM audio_audindex WHERE audindex = 5;   -- 6
SELECT COUNT(*) FROM audio_audindex WHERE audindex = 6;   -- 1
SELECT COUNT(*) FROM audio_audindex WHERE audindex = 8;   -- 1

-- How many unique patient–date–curve groups exist?
SELECT COUNT(*) 
FROM (
    SELECT patient_id, investdate, curve
    FROM audio_audindex
    GROUP BY patient_id, investdate, curve
) lil;   -- 295,912

SELECT 301546 - 295912 AS "Remaining_audindex_duplicates"; -- 5,634


/*======================================================================*
    SECTION 19: RESOLVE DUPLICATE audiograms VIA NULL-COUNT RANKING
*======================================================================*/

-- Count NULL thresholds for each audiogram
DROP TABLE IF EXISTS audio_audindex_nill;

CREATE TABLE audio_audindex_nill AS
SELECT
    audio_audindex.*,
    (l250t IS NULL)::INT +
    (l250tm IS NULL)::INT +
    (l500tm IS NULL)::INT +
    (l500t IS NULL)::INT +
    (l1000tm IS NULL)::INT +
    (l1000t IS NULL)::INT +
    (l2000tm IS NULL)::INT +
    (l2000t IS NULL)::INT +
    (l4000tm IS NULL)::INT +
    (l4000t IS NULL)::INT +
    (l8000tm IS NULL)::INT +
    (l8000t IS NULL)::INT +
    (r250tm IS NULL)::INT +
    (r250t IS NULL)::INT +
    (r500tm IS NULL)::INT +
    (r500t IS NULL)::INT +
    (r1000tm IS NULL)::INT +
    (r1000t IS NULL)::INT +
    (r2000tm IS NULL)::INT +
    (r2000t IS NULL)::INT +
    (r4000tm IS NULL)::INT +
    (r4000t IS NULL)::INT AS null_number
FROM audio_audindex;


-- Rank within each patient_id + date + curve
DROP TABLE IF EXISTS audio_aud1;

CREATE TABLE audio_aud1 AS
SELECT *
FROM (
    SELECT
        audio_audindex_nill.*,
        RANK() OVER (
            PARTITION BY patient_id, investdate, curve
            ORDER BY null_number, audindex DESC
        ) AS rank
    FROM audio_audindex_nill
) ranked
WHERE rank = 1;

SELECT COUNT(*) FROM audio_aud1;  -- 295,913


/*======================================================================*
    SECTION 20: PREPARE CURVE DATA FOR AC + BC MERGE - this step recreates a single audiogram from its composite curves into 1 row
*======================================================================*/

DROP TABLE IF EXISTS data_curves;

CREATE TABLE data_curves AS
SELECT 
    curve, patient_id, audindex, investdate, age, sex,
    l250t, l250tm, l500t, l500tm, l1000t, l1000tm,
    l2000t, l2000tm, l4000t, l4000tm, l8000t, l8000tm,
    r250t, r250tm, r500t, r500tm, r1000t, r1000tm,
    r2000t, r2000tm, r4000t, r4000tm, r8000t, r8000tm
FROM audio_aud1;

SELECT COUNT(*) FROM data_curves;  -- 295,913


/*======================================================================*
    SECTION 21: CHECK FOR EMPTY FREQUENCY ROWS AGAIN
*======================================================================*/

-- AC curves
SELECT COUNT(*) 
FROM data_curves 
WHERE curve = 10 AND
    l250t  IS NULL AND l250tm IS NULL AND
    l500t  IS NULL AND l500tm IS NULL AND
    l1000t IS NULL AND l1000tm IS NULL AND
    l2000t IS NULL AND l2000tm IS NULL AND
    l4000t IS NULL AND l4000tm IS NULL AND
    l8000t IS NULL AND l8000tm IS NULL AND
    r250t  IS NULL AND r250tm IS NULL AND
    r500t  IS NULL AND r500tm IS NULL AND
    r1000t IS NULL AND r1000tm IS NULL AND
    r2000t IS NULL AND r2000tm IS NULL AND
    r4000t IS NULL AND r4000tm IS NULL AND
    r8000t IS NULL AND r8000tm IS NULL;   -- 0


-- BC curves
SELECT COUNT(*) 
FROM data_curves 
WHERE curve = 0 AND
    l250t  IS NULL AND l250tm IS NULL AND
    l500t  IS NULL AND l500tm IS NULL AND
    l1000t IS NULL AND l1000tm IS NULL AND
    l2000t IS NULL AND l2000tm IS NULL AND
    l4000t IS NULL AND l4000tm IS NULL AND
    l8000t IS NULL AND l8000tm IS NULL AND
    r250t  IS NULL AND r250tm IS NULL AND
    r500t  IS NULL AND r500tm IS NULL AND
    r1000t IS NULL AND r1000tm IS NULL AND
    r2000t IS NULL AND r2000tm IS NULL AND
    r4000t IS NULL AND r4000tm IS NULL AND
    r8000t IS NULL AND r8000tm IS NULL;   -- 0


/*======================================================================*
    SECTION 22: CHECK FOR OUT-OF-RANGE THRESHOLDS
*======================================================================*/

DROP TABLE IF EXISTS data_curves_outrange;

CREATE TABLE data_curves_outrange AS
SELECT *
FROM data_curves
WHERE 
    l250t < -10 OR l250t > 120 OR
    l250tm < -10 OR l250tm > 120 OR
    l500t < -10 OR l500t > 120 OR
    l500tm < -10 OR l500tm > 120 OR
    l1000t < -10 OR l1000t > 120 OR
    l1000tm < -10 OR l1000tm > 120 OR
    l2000t < -10 OR l2000t > 120 OR
    l2000tm < -10 OR l2000tm > 120 OR
    l4000t < -10 OR l4000t > 120 OR
    l4000tm < -10 OR l4000tm > 120 OR
    l8000t < -10 OR l8000t > 120 OR
    l8000tm < -10 OR l8000tm > 120 OR
    r250t < -10 OR r250t > 120 OR
    r250tm < -10 OR r250tm > 120 OR
    r500t < -10 OR r500t > 120 OR
    r500tm < -10 OR r500tm > 120 OR
    r1000t < -10 OR r1000t > 120 OR
    r1000tm < -10 OR r1000tm > 120 OR
    r2000t < -10 OR r2000t > 120 OR
    r2000tm < -10 OR r2000tm > 120 OR
    r4000t < -10 OR r4000t > 120 OR
    r4000tm < -10 OR r4000tm > 120 OR
    r8000t < -10 OR r8000t > 120 OR
    r8000tm < -10 OR r8000tm > 120;


/*======================================================================*
    SECTION 23: CHECK FOR NON-MULTIPLE-OF-5 THRESHOLDS
*======================================================================*/

-- How many audiograms contain at least one threshold divisible by 5?
SELECT COUNT(*)
FROM (
    SELECT *
    FROM data_curves
    WHERE
        (l250t  % 5 = 0 AND l250t  IS NOT NULL) OR
        (l250tm % 5 = 0 AND l250tm IS NOT NULL) OR
        (l500t  % 5 = 0 AND l500t  IS NOT NULL) OR
        (l500tm % 5 = 0 AND l500tm IS NOT NULL) OR
        (l1000t % 5 = 0 AND l1000t IS NOT NULL) OR
        (l1000tm % 5 = 0 AND l1000tm IS NOT NULL) OR
        (l2000t % 5 = 0 AND l2000t IS NOT NULL) OR
        (l2000tm % 5 = 0 AND l2000tm IS NOT NULL) OR
        (l4000t % 5 = 0 AND l4000t IS NOT NULL) OR
        (l4000tm % 5 = 0 AND l4000tm IS NOT NULL) OR
        (l8000t % 5 = 0 AND l8000t IS NOT NULL) OR
        (l8000tm % 5 = 0 AND l8000tm IS NOT NULL) OR
        (r250t  % 5 = 0 AND r250t  IS NOT NULL) OR
        (r250tm % 5 = 0 AND r250tm IS NOT NULL) OR
        (r500t  % 5 = 0 AND r500t  IS NOT NULL) OR
        (r500tm % 5 = 0 AND r500tm IS NOT NULL) OR
        (r1000t % 5 = 0 AND r1000t IS NOT NULL) OR
        (r1000tm % 5 = 0 AND r1000tm IS NOT NULL) OR
        (r2000t % 5 = 0 AND r2000t IS NOT NULL) OR
        (r2000tm % 5 = 0 AND r2000tm IS NOT NULL) OR
        (r4000t % 5 = 0 AND r4000t IS NOT NULL) OR
        (r4000tm % 5 = 0 AND r4000tm IS NOT NULL) OR
        (r8000t % 5 = 0 AND r8000t IS NOT NULL) OR
        (r8000tm % 5 = 0 AND r8000tm IS NOT NULL)
) lil;   -- 295,891

SELECT COUNT(*) FROM data_curves;  -- 295,913
SELECT 295913 - 295891 AS "Num_not_multiple_of_5"; -- 22


-- Store audiograms with ANY thresholds that are NOT multiples of 5
DROP TABLE IF EXISTS data_curves_not5;

CREATE TABLE data_curves_not5 AS
SELECT *
FROM data_curves
WHERE
    (l250t  % 5 != 0 AND l250t  IS NOT NULL) OR
    (l250tm % 5 != 0 AND l250tm IS NOT NULL) OR
    (l500t  % 5 != 0 AND l500t  IS NOT NULL) OR
    (l500tm % 5 != 0 AND l500tm IS NOT NULL) OR
    (l1000t % 5 != 0 AND l1000t IS NOT NULL) OR
    (l1000tm % 5 != 0 AND l1000tm IS NOT NULL) OR
    (l2000t % 5 != 0 AND l2000t IS NOT NULL) OR
    (l2000tm % 5 != 0 AND l2000tm IS NOT NULL) OR
    (l4000t % 5 != 0 AND l4000t IS NOT NULL) OR
    (l4000tm % 5 != 0 AND l4000tm IS NOT NULL) OR
    (l8000t % 5 != 0 AND l8000t IS NOT NULL) OR
    (l8000tm % 5 != 0 AND l8000tm IS NOT NULL) OR
    (r250t  % 5 != 0 AND r250t  IS NOT NULL) OR
    (r250tm % 5 != 0 AND r250tm IS NOT NULL) OR
    (r500t  % 5 != 0 AND r500t  IS NOT NULL) OR
    (r500tm % 5 != 0 AND r500tm IS NOT NULL) OR
    (r1000t % 5 != 0 AND r1000t IS NOT NULL) OR
    (r1000tm % 5 != 0 AND r1000tm IS NOT NULL) OR
    (r2000t % 5 != 0 AND r2000t IS NOT NULL) OR
    (r2000tm % 5 != 0 AND r2000tm IS NOT NULL) OR
    (r4000t % 5 != 0 AND r4000t IS NOT NULL) OR
    (r4000tm % 5 != 0 AND r4000tm IS NOT NULL) OR
    (r8000t % 5 != 0 AND r8000t IS NOT NULL) OR
    (r8000tm % 5 != 0 AND r8000tm IS NOT NULL);
-- Expected ~330 rows

/*======================================================================*
    SECTION 24: JOIN AC + BC AUDIOGRAMS (CURVE 0 WITH CURVE 10)
*======================================================================*/

DROP TABLE IF EXISTS data_join;

CREATE TABLE data_join AS
SELECT
    val_1.patient_id AS ac_patient_id,
    val_2.patient_id AS bc_patient_id,
    val_1.investdate AS ac_investdate,
    val_2.investdate AS bc_investdate,
    val_1.audindex AS ac_audindex,
    val_2.audindex AS bc_audindex,
    val_1.curve AS ac_curve,
    val_2.curve AS bc_curve,
    val_1.sex   AS ac_sex,
    val_2.sex   AS bc_sex,
    val_1.age   AS ac_age,
    val_2.age   AS bc_age,

    -- Left thresholds (AC)
    val_1.l250t   AS ac_l250t,
    val_1.l250tm  AS ac_l250tm,
    val_1.l500t   AS ac_l500t,
    val_1.l500tm  AS ac_l500tm,
    val_1.l1000t  AS ac_l1000t,
    val_1.l1000tm AS ac_l1000tm,
    val_1.l2000t  AS ac_l2000t,
    val_1.l2000tm AS ac_l2000tm,
    val_1.l4000t  AS ac_l4000t,
    val_1.l4000tm AS ac_l4000tm,
    val_1.l8000t  AS ac_l8000t,
    val_1.l8000tm AS ac_l8000tm,

    -- Right thresholds (AC)
    val_1.r250t   AS ac_r250t,
    val_1.r250tm  AS ac_r250tm,
    val_1.r500t   AS ac_r500t,
    val_1.r500tm  AS ac_r500tm,
    val_1.r1000t  AS ac_r1000t,
    val_1.r1000tm AS ac_r1000tm,
    val_1.r2000t  AS ac_r2000t,
    val_1.r2000tm AS ac_r2000tm,
    val_1.r4000t  AS ac_r4000t,
    val_1.r4000tm AS ac_r4000tm,
    val_1.r8000t  AS ac_r8000t,
    val_1.r8000tm AS ac_r8000tm,

    -- Bone conduction thresholds (BC)
    val_2.l500t   AS bc_l500t,
    val_2.l500tm  AS bc_l500tm,
    val_2.l1000t  AS bc_l1000t,
    val_2.l1000tm AS bc_l1000tm,
    val_2.l2000t  AS bc_l2000t,
    val_2.l2000tm AS bc_l2000tm,
    val_2.r500t   AS bc_r500t,
    val_2.r500tm  AS bc_r500tm,
    val_2.r1000t  AS bc_r1000t,
    val_2.r1000tm AS bc_r1000tm,
    val_2.r2000t  AS bc_r2000t,
    val_2.r2000tm AS bc_r2000tm
FROM
    data_curves val_1
INNER JOIN
    data_curves val_2
ON  val_1.patient_id  = val_2.patient_id
AND val_1.investdate  = val_2.investdate
WHERE
    val_1.curve = 0    -- BC
AND val_2.curve = 10;  -- AC


/*======================================================================*
    SECTION 25: COUNT AC + BC MATCHES AND AC-ONLY / BC-ONLY CASES
*======================================================================*/

-- Records with both AC + BC
SELECT COUNT(*) FROM data_join;                                   -- 121,478
SELECT COUNT(*) FROM (SELECT DISTINCT * FROM data_join) x;        -- 121,478

-- Create a working copy of all curves
DROP TABLE IF EXISTS data_nojoin;
CREATE TABLE data_nojoin AS SELECT * FROM data_curves;

-- Remove rows that appear in AC+BC join
DELETE FROM data_nojoin
WHERE (patient_id, investdate) IN (
    SELECT ac_patient_id, ac_investdate
    FROM data_join
);

SELECT COUNT(*) FROM data_nojoin;                                 -- 52,958


/*--------------------------------------------------------------------*
    Split remaining into AC-only and BC-only tables
*--------------------------------------------------------------------*/

DROP TABLE IF EXISTS data_ac;
CREATE TABLE data_ac AS
SELECT *
FROM data_nojoin
WHERE curve = 0;

SELECT COUNT(*) FROM data_ac;                                     -- 52,614


DROP TABLE IF EXISTS data_bc;
CREATE TABLE data_bc AS
SELECT *
FROM data_nojoin
WHERE curve = 10;

SELECT COUNT(*) FROM data_bc;                                     -- 344

SELECT 344 + 52614 AS "Addition";                                 -- 52,958
SELECT 121478 + 344 + 52614 + 121478 AS addition;                 -- 295,914


/*======================================================================*
    SECTION 26: REMOVE NON-MULTIPLE-OF-5 AND OUT-OF-RANGE VALUES
*======================================================================*/

-- Identify values not multiples of 5 in BC-only
SELECT *
FROM data_bc b
WHERE EXISTS (
    SELECT FROM data_curves_not5 n5
    WHERE b.patient_id = n5.patient_id
      AND b.investdate = n5.investdate
      AND b.audindex  = n5.audindex
);  -- 1 record


-- Identify AC-only records not multiples of 5
SELECT *
FROM data_ac b
WHERE EXISTS (
    SELECT FROM data_curves_not5 n5
    WHERE b.patient_id = n5.patient_id
      AND b.investdate = n5.investdate
      AND b.audindex  = n5.audindex
);  -- 112 records


/*--------------------------------------------------------------------*
    Find non-multiple-of-5 values in AC+BC joined table
*--------------------------------------------------------------------*/

SELECT *
FROM data_join b
WHERE EXISTS (
    SELECT FROM data_curves_not5 n5
    WHERE b.ac_patient_id = n5.patient_id
      AND b.ac_investdate = n5.investdate
      AND b.ac_audindex   = n5.audindex
      AND b.ac_curve      = n5.curve
);  -- 113


SELECT *
FROM data_join b
WHERE EXISTS (
    SELECT FROM data_curves_not5 n5
    WHERE b.ac_patient_id = n5.patient_id
      AND b.ac_investdate = n5.investdate
      AND b.bc_audindex   = n5.audindex
      AND b.bc_curve      = n5.curve
);  -- 104

SELECT 104 + 113 + 112 + 1 AS addition;                           -- 330


/*======================================================================*
    SECTION 27: DELETE BAD MULTIPLE-OF-5 RECORDS
*======================================================================*/

-- Remove from AC-only
DELETE FROM data_ac b
WHERE EXISTS (
    SELECT FROM data_curves_not5 n5
    WHERE b.patient_id = n5.patient_id
      AND b.investdate = n5.investdate
      AND b.audindex  = n5.audindex
);

SELECT COUNT(*) FROM data_ac;                                     -- 52,502
SELECT 52614 - 52502 AS subtraction;                              -- 112


-- Remove from AC+BC join (AC side)
DELETE FROM data_join b
WHERE EXISTS (
    SELECT FROM data_curves_not5 n5
    WHERE b.ac_patient_id = n5.patient_id
      AND b.ac_investdate = n5.investdate
      AND b.ac_audindex   = n5.audindex
      AND b.ac_curve      = n5.curve
);

-- Remove from AC+BC join (BC side)
DELETE FROM data_join b
WHERE EXISTS (
    SELECT FROM data_curves_not5 n5
    WHERE b.ac_patient_id = n5.patient_id
      AND b.ac_investdate = n5.investdate
      AND b.bc_audindex   = n5.audindex
      AND b.bc_curve      = n5.curve
);

SELECT COUNT(*) FROM data_join;                                   -- 121,355
SELECT 121355 - 121478 AS subtraction;                            -- 123


-- Remove from BC-only
DELETE FROM data_bc b
WHERE EXISTS (
    SELECT FROM data_curves_not5 n5
    WHERE b.patient_id = n5.patient_id
      AND b.investdate = n5.investdate
      AND b.audindex  = n5.audindex
);

SELECT COUNT(*) FROM data_bc;                                     -- 343


/*======================================================================*
    SECTION 28: REMOVE OUT-OF-RANGE VALUES (-10 TO 120)
*======================================================================*/

SELECT COUNT(*) FROM data_curves_outrange;                        -- 221


-- BC-only
SELECT *
FROM data_bc b
WHERE EXISTS (
    SELECT FROM data_curves_outrange n5
    WHERE b.patient_id = n5.patient_id
      AND b.investdate = n5.investdate
      AND b.audindex  = n5.audindex
);  -- 0


-- AC-only
SELECT *
FROM data_ac b
WHERE EXISTS (
    SELECT FROM data_curves_outrange n5
    WHERE b.patient_id = n5.patient_id
      AND b.investdate = n5.investdate
      AND b.audindex  = n5.audindex
);  -- 81 records

DELETE FROM data_ac b
WHERE EXISTS (
    SELECT FROM data_curves_outrange n5
    WHERE b.patient_id = n5.patient_id
      AND b.investdate = n5.investdate
      AND b.audindex  = n5.audindex
);

SELECT COUNT(*) FROM data_ac;                                     -- 52,433
SELECT 52502 - 52433 AS subtraction;                              -- 69


-- AC+BC join (AC side)
SELECT *
FROM data_join b
WHERE EXISTS (
    SELECT FROM data_curves_outrange n5
    WHERE b.ac_patient_id = n5.patient_id
      AND b.ac_investdate = n5.investdate
      AND b.ac_audindex   = n5.audindex
      AND b.ac_curve      = n5.curve
);  -- 137

DELETE FROM data_join b
WHERE EXISTS (
    SELECT FROM data_curves_outrange n5
    WHERE b.ac_patient_id = n5.patient_id
      AND b.ac_investdate = n5.investdate
      AND b.ac_audindex   = n5.audindex
      AND b.ac_curve      = n5.curve
);


-- AC+BC join (BC side)
SELECT *
FROM data_join b
WHERE EXISTS (
    SELECT FROM data_curves_outrange n5
    WHERE b.ac_patient_id = n5.patient_id
      AND b.ac_investdate = n5.investdate
      AND b.bc_audindex   = n5.audindex
      AND b.bc_curve      = n5.curve
);  -- 3

DELETE FROM data_join b
WHERE EXISTS (
    SELECT FROM data_curves_outrange n5
    WHERE b.ac_patient_id = n5.patient_id
      AND b.ac_investdate = n5.investdate
      AND b.bc_audindex   = n5.audindex
      AND b.bc_curve      = n5.curve
);

SELECT 3 + 81 + 137 AS addition;                                  -- 221

SELECT COUNT(*) FROM data_join;                                   -- 121,218
SELECT 121355 - 121218 AS subtraction;                            -- 137


/*======================================================================*
    SECTION 29: FINAL INTEGRITY CHECKS
*======================================================================*/

SELECT COUNT(*) FROM data_ac;                                     -- 52,433
SELECT COUNT(*) FROM data_bc;                                     -- 343
SELECT COUNT(*) FROM data_join;                                   -- 121,218

-- Confirm no non-multiple-of-5 values remain (AC and BC)
-- Confirm no out-of-range thresholds remain
-- All checks return zero rows

/*======================================================================*
    STAGE 2: PROCESS AUDIOGRAMS WITH AC-ONLY (CURVE = 0)
    NOTE: Stage 3 (next section) will repeat this pipeline for AC+BC pairs.
*======================================================================*/


/*======================================================================*
    SECTION 30: IDENTIFY AC-ONLY PATIENTS WHO ALSO APPEAR IN BC/AC+BC GROUPS
*======================================================================*/

-- All AC-only patients appear in data_join (they previously had BC or matched AC+BC pairs)
SELECT COUNT(*)
FROM (
    SELECT *
    FROM data_ac
    WHERE patient_id IN (SELECT patient_id FROM data_join)
) x;     -- 52,433


/*======================================================================*
    SECTION 31: FILTER AC-ONLY RECORDS WITH COMPLETE 250–8000 Hz DATA (BOTH EARS)
*======================================================================*/

DROP TABLE IF EXISTS data_ac_250to8000_bl;

CREATE TABLE data_ac_250to8000_bl AS
SELECT *
FROM data_ac
WHERE
    (l250tm  IS NOT NULL OR l250t  IS NOT NULL) AND
    (l500tm  IS NOT NULL OR l500t  IS NOT NULL) AND
    (l1000tm IS NOT NULL OR l1000t IS NOT NULL) AND
    (l2000tm IS NOT NULL OR l2000t IS NOT NULL) AND
    (l4000tm IS NOT NULL OR l4000t IS NOT NULL) AND
    (l8000tm IS NOT NULL OR l8000t IS NOT NULL) AND
    (r250tm  IS NOT NULL OR r250t  IS NOT NULL) AND
    (r500tm  IS NOT NULL OR r500t  IS NOT NULL) AND
    (r1000tm IS NOT NULL OR r1000t IS NOT NULL) AND
    (r2000tm IS NOT NULL OR r2000t IS NOT NULL) AND
    (r4000tm IS NOT NULL OR r4000t IS NOT NULL) AND
    (r8000tm IS NOT NULL OR r8000t IS NOT NULL);

SELECT COUNT(*) FROM data_ac_250to8000_bl;     -- 41,522


/*======================================================================*
    SECTION 32: FILTER AC-ONLY WITH COMPLETE LEFT EAR ONLY
*======================================================================*/

DROP TABLE IF EXISTS data_ac_250to8000_l;

CREATE TABLE data_ac_250to8000_l AS
SELECT *
FROM data_ac
WHERE
    -- Left ear complete
    (l250tm  IS NOT NULL OR l250t  IS NOT NULL) AND
    (l500tm  IS NOT NULL OR l500t  IS NOT NULL) AND
    (l1000tm IS NOT NULL OR l1000t IS NOT NULL) AND
    (l2000tm IS NOT NULL OR l2000t IS NOT NULL) AND
    (l4000tm IS NOT NULL OR l4000t IS NOT NULL) AND
    (l8000tm IS NOT NULL OR l8000t IS NOT NULL)
    AND
    -- Right ear incomplete
    (
        (r250tm  IS NULL AND r250t  IS NULL) OR
        (r500tm  IS NULL AND r500t  IS NULL) OR
        (r1000tm IS NULL AND r1000t IS NULL) OR
        (r2000tm IS NULL AND r2000t IS NULL) OR
        (r4000tm IS NULL AND r4000t IS NULL) OR
        (r8000tm IS NULL AND r8000t IS NULL)
    );

SELECT COUNT(*) FROM data_ac_250to8000_l;      -- 1,746


/*======================================================================*
    SECTION 33: FILTER AC-ONLY WITH COMPLETE RIGHT EAR ONLY
*======================================================================*/

DROP TABLE IF EXISTS data_ac_250to8000_r;

CREATE TABLE data_ac_250to8000_r AS
SELECT *
FROM data_ac
WHERE
    -- Right ear complete
    (r250tm  IS NOT NULL OR r250t  IS NOT NULL) AND
    (r500tm  IS NOT NULL OR r500t  IS NOT NULL) AND
    (r1000tm IS NOT NULL OR r1000t IS NOT NULL) AND
    (r2000tm IS NOT NULL OR r2000t IS NOT NULL) AND
    (r4000tm IS NOT NULL OR r4000t IS NOT NULL) AND
    (r8000tm IS NOT NULL OR r8000t IS NOT NULL)
    AND
    -- Left ear incomplete
    (
        (l250tm  IS NULL AND l250t  IS NULL) OR
        (l500tm  IS NULL AND l500t  IS NULL) OR
        (l1000tm IS NULL AND l1000t IS NULL) OR
        (l2000tm IS NULL AND l2000t IS NULL) OR
        (l4000tm IS NULL AND l4000t IS NULL) OR
        (l8000tm IS NULL AND l8000t IS NULL)
    );

SELECT COUNT(*) FROM data_ac_250to8000_r;      -- 1,600


/*======================================================================*
    SECTION 34: FILTER AC-ONLY WITH BOTH EARS INCOMPLETE
*======================================================================*/

DROP TABLE IF EXISTS data_ac_250to8000_none;

CREATE TABLE data_ac_250to8000_none AS
SELECT *
FROM data_ac
WHERE
    -- Right ear incomplete
    (
        (r250tm  IS NULL AND r250t  IS NULL) OR
        (r500tm  IS NULL AND r500t  IS NULL) OR
        (r1000tm IS NULL AND r1000t IS NULL) OR
        (r2000tm IS NULL AND r2000t IS NULL) OR
        (r4000tm IS NULL AND r4000t IS NULL) OR
        (r8000tm IS NULL AND r8000t IS NULL)
    )
    AND
    -- Left ear incomplete
    (
        (l250tm  IS NULL AND l250t  IS NULL) OR
        (l500tm  IS NULL AND l500t  IS NULL) OR
        (l1000tm IS NULL AND l1000t IS NULL) OR
        (l2000tm IS NULL AND l2000t IS NULL) OR
        (l4000tm IS NULL AND l4000t IS NULL) OR
        (l8000tm IS NULL AND l8000t IS NULL)
    );

SELECT COUNT(*) FROM data_ac_250to8000_none;   -- 7,565


SELECT 41522 + 1746 + 1600 + 7565 AS "Addition";  -- 52,433 (sanity check)


/*======================================================================*
    SECTION 35: BUILD CLEANED AC-ONLY TABLE (BINAURAL)
*======================================================================*/

DROP TABLE IF EXISTS data_ac_bl;

CREATE TABLE data_ac_bl (
    patient_id INT,
    audindex SMALLINT,
    investdate DATE,
    sex VARCHAR,
    age SMALLINT,
    l250 SMALLINT, l500 SMALLINT, l1000 SMALLINT,
    l2000 SMALLINT, l4000 SMALLINT, l8000 SMALLINT,
    r250 SMALLINT, r500 SMALLINT, r1000 SMALLINT,
    r2000 SMALLINT, r4000 SMALLINT, r8000 SMALLINT
);

INSERT INTO data_ac_bl (
    patient_id, audindex, investdate, sex, age,
    l250, l500, l1000, l2000, l4000, l8000,
    r250, r500, r1000, r2000, r4000, r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    COALESCE(l250tm,  l250t),
    COALESCE(l500tm,  l500t),
    COALESCE(l1000tm, l1000t),
    COALESCE(l2000tm, l2000t),
    COALESCE(l4000tm, l4000t),
    COALESCE(l8000tm, l8000t),
    COALESCE(r250tm,  r250t),
    COALESCE(r500tm,  r500t),
    COALESCE(r1000tm, r1000t),
    COALESCE(r2000tm, r2000t),
    COALESCE(r4000tm, r4000t),
    COALESCE(r8000tm, r8000t)
FROM data_ac_250to8000_bl;

SELECT COUNT(*) FROM data_ac_bl;     -- 41,522


/*======================================================================*
    SECTION 36: BUILD CLEANED AC-ONLY LEFT-EAR-ONLY TABLE
*======================================================================*/

DROP TABLE IF EXISTS data_ac_l;

CREATE TABLE data_ac_l (
    patient_id INT,
    audindex SMALLINT,
    investdate DATE,
    sex VARCHAR,
    age SMALLINT,
    l250 SMALLINT, l500 SMALLINT, l1000 SMALLINT,
    l2000 SMALLINT, l4000 SMALLINT, l8000 SMALLINT,
    r250 SMALLINT, r500 SMALLINT, r1000 SMALLINT,
    r2000 SMALLINT, r4000 SMALLINT, r8000 SMALLINT
);

INSERT INTO data_ac_l (
    patient_id, audindex, investdate, sex, age,
    l250, l500, l1000, l2000, l4000, l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    COALESCE(l250tm,  l250t),
    COALESCE(l500tm,  l500t),
    COALESCE(l1000tm, l1000t),
    COALESCE(l2000tm, l2000t),
    COALESCE(l4000tm, l4000t),
    COALESCE(l8000tm, l8000t)
FROM data_ac_250to8000_l;

SELECT COUNT(*) FROM data_ac_l;      -- 1,746


/*======================================================================*
    SECTION 37: BUILD CLEANED AC-ONLY RIGHT-EAR-ONLY TABLE
*======================================================================*/

DROP TABLE IF EXISTS data_ac_r;

CREATE TABLE data_ac_r (
    patient_id INT,
    audindex SMALLINT,
    investdate DATE,
    sex VARCHAR,
    age SMALLINT,
    l250 SMALLINT, l500 SMALLINT, l1000 SMALLINT,
    l2000 SMALLINT, l4000 SMALLINT, l8000 SMALLINT,
    r250 SMALLINT, r500 SMALLINT, r1000 SMALLINT,
    r2000 SMALLINT, r4000 SMALLINT, r8000 SMALLINT
);

INSERT INTO data_ac_r (
    patient_id, audindex, investdate, sex, age,
    r250, r500, r1000, r2000, r4000, r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    COALESCE(r250tm,  r250t),
    COALESCE(r500tm,  r500t),
    COALESCE(r1000tm, r1000t),
    COALESCE(r2000tm, r2000t),
    COALESCE(r4000tm, r4000t),
    COALESCE(r8000tm, r8000t)
FROM data_ac_250to8000_r;

SELECT COUNT(*) FROM data_ac_r;      -- 1,600

/*======================================================================*
    STAGE 3: PROCESS AUDIOGRAMS WITH BOTH AC AND BC (AC+BC PAIRS)
    NOTE: This stage mirrors Stage 2 but operates on AC/BC joined data.
*======================================================================*/


/*======================================================================*
    SECTION 40: STARTING AC+BC TABLE — REQUIRE COMPLETE AC FREQUENCIES
*======================================================================*/

-- Initial AC+BC dataset size
SELECT COUNT(*) FROM data_join;      -- 121,218

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl;

-- Keep only records with COMPLETE AC thresholds for ALL required frequencies
CREATE TABLE data_acbc_ac250to8000_bl AS
SELECT *
FROM data_join
WHERE
    (ac_l250tm  IS NOT NULL OR ac_l250t  IS NOT NULL) AND
    (ac_l500tm  IS NOT NULL OR ac_l500t  IS NOT NULL) AND
    (ac_l1000tm IS NOT NULL OR ac_l1000t IS NOT NULL) AND
    (ac_l2000tm IS NOT NULL OR ac_l2000t IS NOT NULL) AND
    (ac_l4000tm IS NOT NULL OR ac_l4000t IS NOT NULL) AND
    (ac_l8000tm IS NOT NULL OR ac_l8000t IS NOT NULL) AND
    (ac_r250tm  IS NOT NULL OR ac_r250t  IS NOT NULL) AND
    (ac_r500tm  IS NOT NULL OR ac_r500t  IS NOT NULL) AND
    (ac_r1000tm IS NOT NULL OR ac_r1000t IS NOT NULL) AND
    (ac_r2000tm IS NOT NULL OR ac_r2000t IS NOT NULL) AND
    (ac_r4000tm IS NOT NULL OR ac_r4000t IS NOT NULL) AND
    (ac_r8000tm IS NOT NULL OR ac_r8000t IS NOT NULL);

SELECT COUNT(*) FROM data_acbc_ac250to8000_bl;    -- 114,146


/*======================================================================*
    SECTION 41: AC+BC — COMPLETE LEFT EAR ONLY (INCOMPLETE RIGHT)
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_l;

CREATE TABLE data_acbc_ac250to8000_l AS
SELECT *
FROM data_join
WHERE
    -- Left ear complete
    (ac_l250tm  IS NOT NULL OR ac_l250t  IS NOT NULL) AND
    (ac_l500tm  IS NOT NULL OR ac_l500t  IS NOT NULL) AND
    (ac_l1000tm IS NOT NULL OR ac_l1000t IS NOT NULL) AND
    (ac_l2000tm IS NOT NULL OR ac_l2000t IS NOT NULL) AND
    (ac_l4000tm IS NOT NULL OR ac_l4000t IS NOT NULL) AND
    (ac_l8000tm IS NOT NULL OR ac_l8000t IS NOT NULL)
    AND
    -- Right ear incomplete
    (
        (ac_r250tm  IS NULL AND ac_r250t  IS NULL) OR
        (ac_r500tm  IS NULL AND ac_r500t  IS NULL) OR
        (ac_r1000tm IS NULL AND ac_r1000t IS NULL) OR
        (ac_r2000tm IS NULL AND ac_r2000t IS NULL) OR
        (ac_r4000tm IS NULL AND ac_r4000t IS NULL) OR
        (ac_r8000tm IS NULL AND ac_r8000t IS NULL)
    );

SELECT COUNT(*) FROM data_acbc_ac250to8000_l;     -- 1,797


/*======================================================================*
    SECTION 42: AC+BC — COMPLETE RIGHT EAR ONLY (INCOMPLETE LEFT)
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_r;

CREATE TABLE data_acbc_ac250to8000_r AS
SELECT *
FROM data_join
WHERE
    -- Right ear complete
    (ac_r250tm  IS NOT NULL OR ac_r250t  IS NOT NULL) AND
    (ac_r500tm  IS NOT NULL OR ac_r500t  IS NOT NULL) AND
    (ac_r1000tm IS NOT NULL OR ac_r1000t IS NOT NULL) AND
    (ac_r2000tm IS NOT NULL OR ac_r2000t IS NOT NULL) AND
    (ac_r4000tm IS NOT NULL OR ac_r4000t IS NOT NULL) AND
    (ac_r8000tm IS NOT NULL OR ac_r8000t IS NOT NULL)
    AND
    -- Left ear incomplete
    (
        (ac_l250tm  IS NULL AND ac_l250t  IS NULL) OR
        (ac_l500tm  IS NULL AND ac_l500t  IS NULL) OR
        (ac_l1000tm IS NULL AND ac_l1000t IS NULL) OR
        (ac_l2000tm IS NULL AND ac_l2000t IS NULL) OR
        (ac_l4000tm IS NULL AND ac_l4000t IS NULL) OR
        (ac_l8000tm IS NULL AND ac_l8000t IS NULL)
    );

SELECT COUNT(*) FROM data_acbc_ac250to8000_r;     -- 1,663


/*======================================================================*
    SECTION 43: AC+BC — INCOMPLETE LEFT AND RIGHT EARS
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_none;

CREATE TABLE data_acbc_ac250to8000_none AS
SELECT *
FROM data_join
WHERE
    -- Right ear incomplete
    (
        (ac_r250tm  IS NULL AND ac_r250t  IS NULL) OR
        (ac_r500tm  IS NULL AND ac_r500t  IS NULL) OR
        (ac_r1000tm IS NULL AND ac_r1000t IS NULL) OR
        (ac_r2000tm IS NULL AND ac_r2000t IS NULL) OR
        (ac_r4000tm IS NULL AND ac_r4000t IS NULL) OR
        (ac_r8000tm IS NULL AND ac_r8000t IS NULL)
    )
    AND
    -- Left ear incomplete
    (
        (ac_l250tm  IS NULL AND ac_l250t  IS NULL) OR
        (ac_l500tm  IS NULL AND ac_l500t  IS NULL) OR
        (ac_l1000tm IS NULL AND ac_l1000t IS NULL) OR
        (ac_l2000tm IS NULL AND ac_l2000t IS NULL) OR
        (ac_l4000tm IS NULL AND ac_l4000t IS NULL) OR
        (ac_l8000tm IS NULL AND ac_l8000t IS NULL)
    );

SELECT COUNT(*) FROM data_acbc_ac250to8000_none;  -- 3,612


/*======================================================================*
    SECTION 44: SANITY CHECK — GROUP TOTALS MATCH ORIGINAL AC+BC COUNT
*======================================================================*/

SELECT
    114146 + 1797 + 1663 + 3612 AS "Addition";   -- 121,218

/*======================================================================*
    STAGE 5: DETAILED PROCESSING OF AC+BC (JOINED) AUDIOGRAMS
    Subsection 5A: Analyse BC completeness within AC-complete records
*======================================================================*/


/*======================================================================*
    SECTION 50: STARTING GROUP — AC COMPLETE IN BOTH EARS (FROM JOIN)
    NOTE: This subsection only operates on patients in the AC+BC join group.
*======================================================================*/

-- All records here have complete AC thresholds 250–8000 Hz in both ears
SELECT COUNT(*) FROM data_acbc_ac250to8000_bl;     -- 114,146

-- Sanity check: confirm no remaining AC-incomplete entries
SELECT COUNT(*)
FROM data_acbc_ac250to8000_bl
WHERE
    (
        (ac_r250tm  IS NULL AND ac_r250t  IS NULL) OR
        (ac_r500tm  IS NULL AND ac_r500t  IS NULL) OR
        (ac_r1000tm IS NULL AND ac_r1000t IS NULL) OR
        (ac_r2000tm IS NULL AND ac_r2000t IS NULL) OR
        (ac_r4000tm IS NULL AND ac_r4000t IS NULL) OR
        (ac_r8000tm IS NULL AND ac_r8000t IS NULL)
    )
    AND
    (
        (ac_l250tm  IS NULL AND ac_l250t  IS NULL) OR
        (ac_l500tm  IS NULL AND ac_l500t  IS NULL) OR
        (ac_l1000tm IS NULL AND ac_l1000t IS NULL) OR
        (ac_l2000tm IS NULL AND ac_l2000t IS NULL) OR
        (ac_l4000tm IS NULL AND ac_l4000t IS NULL) OR
        (ac_l8000tm IS NULL AND ac_l8000t IS NULL)
    );     -- 0 records (as expected)


/*======================================================================*
    SECTION 51: BC COMPLETE IN BOTH EARS (AT LEAST 2 OF 500/1000/2000 Hz)
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_bl;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_bl AS
SELECT *
FROM data_acbc_ac250to8000_bl
WHERE
    (
        (COALESCE(bc_l500t,  bc_l500tm)  IS NOT NULL AND COALESCE(bc_l1000t, bc_l1000tm) IS NOT NULL) OR
        (COALESCE(bc_l1000t, bc_l1000tm) IS NOT NULL AND COALESCE(bc_l2000t, bc_l2000tm) IS NOT NULL) OR
        (COALESCE(bc_l500t,  bc_l500tm)  IS NOT NULL AND COALESCE(bc_l2000t, bc_l2000tm) IS NOT NULL)
    )
    AND
    (
        (COALESCE(bc_r500t,  bc_r500tm)  IS NOT NULL AND COALESCE(bc_r1000t, bc_r1000tm) IS NOT NULL) OR
        (COALESCE(bc_r1000t, bc_r1000tm) IS NOT NULL AND COALESCE(bc_r2000t, bc_r2000tm) IS NOT NULL) OR
        (COALESCE(bc_r500t,  bc_r500tm)  IS NOT NULL AND COALESCE(bc_r2000t, bc_r2000tm) IS NOT NULL)
    );

SELECT COUNT(*) FROM data_acbc_ac250to8000_bl_bc2freq_bl;   -- 27,512


/*======================================================================*
    SECTION 52: BC COMPLETE LEFT ONLY — RIGHT INCOMPLETE
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_rincom;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_rincom AS
SELECT *
FROM data_acbc_ac250to8000_bl
WHERE
    -- Left has ≥2 BC frequencies
    (
        (COALESCE(bc_l500t,  bc_l500tm)  IS NOT NULL AND COALESCE(bc_l1000t, bc_l1000tm) IS NOT NULL) OR
        (COALESCE(bc_l1000t, bc_l1000tm) IS NOT NULL AND COALESCE(bc_l2000t, bc_l2000tm) IS NOT NULL) OR
        (COALESCE(bc_l500t,  bc_l500tm)  IS NOT NULL AND COALESCE(bc_l2000t, bc_l2000tm) IS NOT NULL)
    )
    AND
    -- Right has ≤1 BC frequency (incomplete)
    (
        (COALESCE(bc_r500t,  bc_r500tm)  IS NULL AND COALESCE(bc_r1000t, bc_r1000tm) IS NULL) OR
        (COALESCE(bc_r1000t, bc_r1000tm) IS NULL AND COALESCE(bc_r2000t, bc_r2000tm) IS NULL) OR
        (COALESCE(bc_r500t,  bc_r500tm)  IS NULL AND COALESCE(bc_r2000t, bc_r2000tm) IS NULL)
    );

SELECT COUNT(*) FROM data_acbc_ac250to8000_bl_bc2freq_l_rincom;  -- 39,711


/*======================================================================*
    SECTION 53: BC COMPLETE RIGHT ONLY — LEFT INCOMPLETE
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_lincom;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_lincom AS
SELECT *
FROM data_acbc_ac250to8000_bl
WHERE
    -- Right has ≥2 BC frequencies
    (
        (COALESCE(bc_r500t,  bc_r500tm)  IS NOT NULL AND COALESCE(bc_r1000t, bc_r1000tm) IS NOT NULL) OR
        (COALESCE(bc_r1000t, bc_r1000tm) IS NOT NULL AND COALESCE(bc_r2000t, bc_r2000tm) IS NOT NULL) OR
        (COALESCE(bc_r500t,  bc_r500tm)  IS NOT NULL AND COALESCE(bc_r2000t, bc_r2000tm) IS NOT NULL)
    )
    AND
    -- Left incomplete
    (
        (COALESCE(bc_l500t,  bc_l500tm)  IS NULL AND COALESCE(bc_l1000t, bc_l1000tm) IS NULL) OR
        (COALESCE(bc_l1000t, bc_l1000tm) IS NULL AND COALESCE(bc_l2000t, bc_l2000tm) IS NULL) OR
        (COALESCE(bc_l500t,  bc_l500tm)  IS NULL AND COALESCE(bc_l2000t, bc_l2000tm) IS NULL)
    );

SELECT COUNT(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_lincom;   -- 43,106


/*======================================================================*
    SECTION 54: BC INCOMPLETE IN BOTH EARS (≤1 BC FREQUENCY LEFT & RIGHT)
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_rlincom;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_rlincom AS
SELECT *
FROM data_acbc_ac250to8000_bl
WHERE
    -- Left incomplete
    (
        (COALESCE(bc_l500t,  bc_l500tm)  IS NULL AND COALESCE(bc_l1000t, bc_l1000tm) IS NULL) OR
        (COALESCE(bc_l1000t, bc_l1000tm) IS NULL AND COALESCE(bc_l2000t, bc_l2000tm) IS NULL) OR
        (COALESCE(bc_l500t,  bc_l500tm)  IS NULL AND COALESCE(bc_l2000t, bc_l2000tm) IS NULL)
    )
    AND
    -- Right incomplete
    (
        (COALESCE(bc_r500t,  bc_r500tm)  IS NULL AND COALESCE(bc_r1000t, bc_r1000tm) IS NULL) OR
        (COALESCE(bc_r1000t, bc_r1000tm) IS NULL AND COALESCE(bc_r2000t, bc_r2000tm) IS NULL) OR
        (COALESCE(bc_r500t,  bc_r500tm)  IS NULL AND COALESCE(bc_r2000t, bc_r2000tm) IS NULL)
    );

SELECT COUNT(*) FROM data_acbc_ac250to8000_bl_bc2freq_rlincom;   -- 3,817


/*======================================================================*
    SECTION 55: SANITY CHECK — GROUP TOTALS RECONCILE
*======================================================================*/

SELECT
    27512 + 39711 + 43106 + 3817 AS "addition";   -- 114,146


/*======================================================================*
    SECTION 56: RECORDS WITH ZERO BC FREQUENCIES (AC COMPLETE BUT NO BC)
*======================================================================*/

SELECT COUNT(*)
FROM (
    SELECT *
    FROM data_acbc_ac250to8000_bl_bc2freq_rlincom
    WHERE
        bc_l500t  IS NULL AND bc_l500tm  IS NULL AND
        bc_l1000t IS NULL AND bc_l1000tm IS NULL AND
        bc_l2000t IS NULL AND bc_l2000tm IS NULL AND
        bc_r500t  IS NULL AND bc_r500tm  IS NULL AND
        bc_r1000t IS NULL AND bc_r1000tm IS NULL AND
        bc_r2000t IS NULL AND bc_r2000tm IS NULL
) lil;     -- 1,818

/*======================================================================*
    STAGE 5B: AC+BC PROCESSING — AC COMPLETE IN LEFT EAR ONLY
    NOTE: These records cannot contribute bilaterally and will NOT
          be included in the final dataset. Left ear is analysed alone.
*======================================================================*/

-- Starting group: AC complete for all 250–8000 Hz frequencies in LEFT ear only
SELECT COUNT(*) FROM data_acbc_ac250to8000_l;   -- 1,797

-- Confirm that right-ear AC is missing for all of these
SELECT COUNT(*)
FROM data_acbc_ac250to8000_l
WHERE
    (ac_r250tm  IS NULL AND ac_r250t  IS NULL) OR
    (ac_r500tm  IS NULL AND ac_r500t  IS NULL) OR
    (ac_r1000tm IS NULL AND ac_r1000t IS NULL) OR
    (ac_r2000tm IS NULL AND ac_r2000t IS NULL) OR
    (ac_r4000tm IS NULL AND ac_r4000t IS NULL) OR
    (ac_r8000tm IS NULL AND ac_r8000t IS NULL);     -- 1,797 (as expected)


/*======================================================================*
    SECTION 5B-1: BC COMPLETE IN LEFT EAR — ≥2 OF 500/1000/2000 Hz
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_l_bc2freq_l;

CREATE TABLE data_acbc_ac250to8000_l_bc2freq_l AS
SELECT *
FROM data_acbc_ac250to8000_l
WHERE
    (COALESCE(bc_l500t,  bc_l500tm)  IS NOT NULL AND COALESCE(bc_l1000t, bc_l1000tm) IS NOT NULL) OR
    (COALESCE(bc_l1000t, bc_l1000tm) IS NOT NULL AND COALESCE(bc_l2000t, bc_l2000tm) IS NOT NULL) OR
    (COALESCE(bc_l500t,  bc_l500tm)  IS NOT NULL AND COALESCE(bc_l2000t, bc_l2000tm) IS NOT NULL);

SELECT COUNT(*) FROM data_acbc_ac250to8000_l_bc2freq_l;   -- 1,519


/*======================================================================*
    SECTION 5B-2: BC INCOMPLETE IN LEFT EAR — ≤1 OF 500/1000/2000 Hz
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_l_bc_lincom;

CREATE TABLE data_acbc_ac250to8000_l_bc_lincom AS
SELECT *
FROM data_acbc_ac250to8000_l
WHERE
    (COALESCE(bc_l500t,  bc_l500tm)  IS NULL AND COALESCE(bc_l1000t, bc_l1000tm) IS NULL) OR
    (COALESCE(bc_l1000t, bc_l1000tm) IS NULL AND COALESCE(bc_l2000t, bc_l2000tm) IS NULL) OR
    (COALESCE(bc_l500t,  bc_l500tm)  IS NULL AND COALESCE(bc_l2000t, bc_l2000tm) IS NULL);

SELECT COUNT(*) FROM data_acbc_ac250to8000_l_bc_lincom;   -- 278

-- Check total
SELECT 1519 + 278 AS addition;   -- 1,797


/*======================================================================*
    STAGE 5C: AC+BC PROCESSING — AC COMPLETE IN RIGHT EAR ONLY
    NOTE: These records cannot contribute bilaterally and will NOT
          be included in the final dataset. Right ear is analysed alone.
*======================================================================*/

-- Starting group: AC complete for all 250–8000 Hz frequencies in RIGHT ear only
SELECT COUNT(*) FROM data_acbc_ac250to8000_r;   -- 1,663


/*======================================================================*
    SECTION 5C-1: BC COMPLETE IN RIGHT EAR — ≥2 OF 500/1000/2000 Hz
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_r_bc2freq_r;

CREATE TABLE data_acbc_ac250to8000_r_bc2freq_r AS
SELECT *
FROM data_acbc_ac250to8000_r
WHERE
    (COALESCE(bc_r500t,  bc_r500tm)  IS NOT NULL AND COALESCE(bc_r1000t, bc_r1000tm) IS NOT NULL) OR
    (COALESCE(bc_r1000t, bc_r1000tm) IS NOT NULL AND COALESCE(bc_r2000t, bc_r2000tm) IS NOT NULL) OR
    (COALESCE(bc_r500t,  bc_r500tm)  IS NOT NULL AND COALESCE(bc_r2000t, bc_r2000tm) IS NOT NULL);

SELECT COUNT(*) FROM data_acbc_ac250to8000_r_bc2freq_r;   -- 1,431


/*======================================================================*
    SECTION 5C-2: BC INCOMPLETE IN RIGHT EAR — ≤1 OF 500/1000/2000 Hz
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_r_bc_rincom;

CREATE TABLE data_acbc_ac250to8000_r_bc_rincom AS
SELECT *
FROM data_acbc_ac250to8000_r
WHERE
    (COALESCE(bc_r500t,  bc_r500tm)  IS NULL AND COALESCE(bc_r1000t, bc_r1000tm) IS NULL) OR
    (COALESCE(bc_r1000t, bc_r1000tm) IS NULL AND COALESCE(bc_r2000t, bc_r2000tm) IS NULL) OR
    (COALESCE(bc_r500t,  bc_r500tm)  IS NULL AND COALESCE(bc_r2000t, bc_r2000tm) IS NULL);

SELECT COUNT(*) FROM data_acbc_ac250to8000_r_bc_rincom;   -- 232

-- Check total
SELECT 1431 + 232 AS addition;   -- 1,663


--------------------------------------------------------------------------------
--                         STAGE 5D – BILATERAL AC + BC
--   This entire section refers ONLY to the subset defined in Section 51B:
--   `data_acbc_ac250to8000_bl_bc2freq_bl` 
--   (AC complete both ears + BC at ≥2 frequencies both ears)
--------------------------------------------------------------------------------

-- 5D-1. Confirm starting population ------------------------------------------
SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_bl;   -- 27,512


-- 5D-2. Build "1 value per frequency" AC+BC table -----------------------------
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq;

CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq (
    patient_id INT,
    audindex SMALLINT,
    investdate DATE,
    sex VARCHAR,
    age INT,
    ac_l250 SMALLINT, ac_l500 SMALLINT, ac_l1000 SMALLINT, ac_l2000 SMALLINT,
    ac_l4000 SMALLINT, ac_l8000 SMALLINT,
    ac_r250 SMALLINT, ac_r500 SMALLINT, ac_r1000 SMALLINT, ac_r2000 SMALLINT,
    ac_r4000 SMALLINT, ac_r8000 SMALLINT,
    bc_l500 SMALLINT, bc_l1000 SMALLINT, bc_l2000 SMALLINT,
    bc_r500 SMALLINT, bc_r1000 SMALLINT, bc_r2000 SMALLINT
);


-- save the masked AC preferentially if both masked and unmasked performed
INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
SELECT 
    ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
    COALESCE(ac_l250tm, ac_l250t),
    COALESCE(ac_l500tm, ac_l500t),
    COALESCE(ac_l1000tm, ac_l1000t),
    COALESCE(ac_l2000tm, ac_l2000t),
    COALESCE(ac_l4000tm, ac_l4000t),
    COALESCE(ac_l8000tm, ac_l8000t),
    COALESCE(ac_r250tm, ac_r250t),
    COALESCE(ac_r500tm, ac_r500t),
    COALESCE(ac_r1000tm, ac_r1000t),
    COALESCE(ac_r2000tm, ac_r2000t),
    COALESCE(ac_r4000tm, ac_r4000t),
    COALESCE(ac_r8000tm, ac_r8000t),
    COALESCE(bc_l500tm, bc_l500t),
    COALESCE(bc_l1000tm, bc_l1000t),
    COALESCE(bc_l2000tm, bc_l2000t),
    COALESCE(bc_r500tm, bc_r500t),
    COALESCE(bc_r1000tm, bc_r1000t),
    COALESCE(bc_r2000tm, bc_r2000t)
FROM data_acbc_ac250to8000_bl_bc2freq_bl;

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq;  -- 27,512


-- 5D-3. Add ABG (air–bone gap) values ----------------------------------------
ALTER TABLE data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
ADD COLUMN l500_abg SMALLINT,
ADD COLUMN l1000_abg SMALLINT,
ADD COLUMN l2000_abg SMALLINT,
ADD COLUMN r500_abg SMALLINT,
ADD COLUMN r1000_abg SMALLINT,
ADD COLUMN r2000_abg SMALLINT;

UPDATE data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
SET 
    l500_abg  = ac_l500  - bc_l500,
    l1000_abg = ac_l1000 - bc_l1000,
    l2000_abg = ac_l2000 - bc_l2000,
    r500_abg  = ac_r500  - bc_r500,
    r1000_abg = ac_r1000 - bc_r1000,
    r2000_abg = ac_r2000 - bc_r2000;


-- 5D-4. Bilateral CHL (ABG ≥ 25 at two frequencies) --------------------------
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_bl_abg;

CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_bl_abg AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
WHERE
    ((l500_abg >= 25 AND l1000_abg >= 25) OR
     (l500_abg >= 25 AND l2000_abg >= 25) OR
     (l1000_abg >= 25 AND l2000_abg >= 25))
AND
    ((r500_abg >= 25 AND r1000_abg >= 25) OR
     (r500_abg >= 25 AND r2000_abg >= 25) OR
     (r1000_abg >= 25 AND r2000_abg >= 25));

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_abg;  -- 3,393


-- 5D-5. Bilateral SNHL (ABG < 25 at ≥2 frequencies) --------------------------
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_bl_noabg;

CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_bl_noabg AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
WHERE
    ((l500_abg < 25 AND l1000_abg < 25) OR
     (l500_abg < 25 AND l2000_abg < 25) OR
     (l1000_abg < 25 AND l2000_abg < 25))
AND
    ((r500_abg < 25 AND r1000_abg < 25) OR
     (r500_abg < 25 AND r2000_abg < 25) OR
     (r1000_abg < 25 AND r2000_abg < 25));

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg;  -- 17,441


-- 5D-6. SNHL/CHL mixed combinations ------------------------------------------

-- Left SNHL + Right CHL
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l;
CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
WHERE
    ((l500_abg < 25 AND l1000_abg < 25) OR
     (l500_abg < 25 AND l2000_abg < 25) OR
     (l1000_abg < 25 AND l2000_abg < 25))
AND
    ((r500_abg >= 25 AND r1000_abg >= 25) OR
     (r500_abg >= 25 AND r2000_abg >= 25) OR
     (r1000_abg >= 25 AND r2000_abg >= 25));

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l;  -- 3,328


-- Right SNHL + Left CHL
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r;
CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
WHERE
    ((r500_abg < 25 AND r1000_abg < 25) OR
     (r500_abg < 25 AND r2000_abg < 25) OR
     (r1000_abg < 25 AND r2000_abg < 25))
AND
    ((l500_abg >= 25 AND l1000_abg >= 25) OR
     (l500_abg >= 25 AND l2000_abg >= 25) OR
     (l1000_abg >= 25 AND l2000_abg >= 25));

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r;  -- 3,130


-- Right SNHL + Left “1 freq only” CHL i.e. criteria for CHL of 2 or more frequencies with ABG >=25 is not met
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r_1freql;
CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r_1freql AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
WHERE
    ((r500_abg < 25 AND r1000_abg < 25) OR
     (r500_abg < 25 AND r2000_abg < 25) OR
     (r1000_abg < 25 AND r2000_abg < 25))
AND
    ((l500_abg >= 25 AND l1000_abg < 25 AND l2000_abg IS NULL) OR
     (l500_abg >= 25 AND l1000_abg IS NULL AND l2000_abg < 25) OR
     (l500_abg IS NULL AND l1000_abg >= 25 AND l2000_abg < 25) OR
     (l500_abg IS NULL AND l1000_abg <25 AND l2000_abg >= 25) OR
     (l500_abg < 25 AND l1000_abg >= 25 AND l2000_abg IS NULL) OR
     (l500_abg < 25 AND l1000_abg IS NULL AND l2000_abg >= 25));

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r_1freql;  -- 59


-- Left SNHL + Right “1 freq only” CHL
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqr;
CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqr AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
WHERE
    ((l500_abg < 25 AND l1000_abg < 25) OR
     (l500_abg < 25 AND l2000_abg < 25) OR
     (l1000_abg < 25 AND l2000_abg < 25))
AND
    ((r500_abg >= 25 AND r1000_abg < 25 AND r2000_abg IS NULL) OR
     (r500_abg >= 25 AND r1000_abg IS NULL AND r2000_abg < 25) OR
     (r500_abg IS NULL AND r1000_abg >= 25 AND r2000_abg < 25) OR
     (r500_abg IS NULL AND r1000_abg <25 AND r2000_abg >= 25) OR
     (r500_abg < 25 AND r1000_abg >= 25 AND r2000_abg IS NULL) OR
     (r500_abg < 25 AND r1000_abg IS NULL AND r2000_abg >= 25));

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqr;  -- 75


-- Mixed insufficient CHL bilateral
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqbl;
CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqbl AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
WHERE
    (left-ear “1 freq only” CHL)
AND (right-ear “1 freq only” CHL);

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqbl;  -- 11


-- Right ≥25 CHL + Left insufficient
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_bl_abg_r_1freql;
CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_bl_abg_r_1freql AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
WHERE
    (right-ear CHL)
AND (left-ear insufficient);

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_abg_r_1freql;  -- 35


-- Left ≥25 CHL + Right insufficient
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_bl_abg_l_1freqr;
CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_bl_abg_l_1freqr AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
WHERE
    (left-ear CHL)
AND (right-ear insufficient);

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_abg_l_1freqr;  -- 40


-- 5D-7. Build final SNHL dataset ---------------------------------------------
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_SNHL;

CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_SNHL (
    patient_id INT,
    audindex SMALLINT,
    investdate DATE,
    sex VARCHAR,
    age INT,
    ac_l250 SMALLINT, ac_l500 SMALLINT, ac_l1000 SMALLINT, ac_l2000 SMALLINT,
    ac_l4000 SMALLINT, ac_l8000 SMALLINT,
    ac_r250 SMALLINT, ac_r500 SMALLINT, ac_r1000 SMALLINT, ac_r2000 SMALLINT,
    ac_r4000 SMALLINT, ac_r8000 SMALLINT
);

-- Insert bilateral SNHL
INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_SNHL
SELECT * FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg;

-- Insert left-only SNHL
INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_SNHL
(patient_id, audindex, investdate, sex, age,
 ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000)
SELECT 
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l;

-- Insert right-only SNHL
INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_SNHL
(patient_id, audindex, investdate, sex, age,
 ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000)
SELECT 
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r;

-- Insert right-only SNHL with 1 freq left CHL
INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_SNHL
(patient_id, audindex, investdate, sex, age,
 ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000)
SELECT 
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r_1freql;

-- Insert left-only SNHL with 1 freq right CHL
INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_SNHL
(patient_id, audindex, investdate, sex, age,
 ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000)
SELECT 
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqr;

-- Check total
SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_SNHL; 


/*======================================================================*
    STAGE 5E / SECTION 52
    AC COMPLETE IN BOTH EARS, BC ONLY MEASURED IN LEFT EAR
    (SUBSET OF STAGE 5A GROUP FROM SECTION 51)
*======================================================================*/

-- Starting group:
--   data_acbc_ac250to8000_bl_bc2freq_l_rincom
--   = Bilateral AC (all required frequencies present in both ears)
--     AND left BC present at ≥2 frequencies (500/1000/2000 Hz)
--     AND right BC has none or only one of these frequencies

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_rincom;   -- 39,711


/*======================================================================*
    52.1 CREATE AC + BC TABLE (LEFT-ONLY BC, AC BOTH EARS)
    - AC: collapse masked/unmasked to a single threshold per frequency
    - BC LEFT: keep t and tm for now (logic depends on them)
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_bc2freq_l_oneperfreq;

CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_bc2freq_l_oneperfreq (
    patient_id   INT,
    audindex     SMALLINT,
    investdate   DATE,
    sex          VARCHAR,
    age          INT,
    ac_l250      SMALLINT,
    ac_l500      SMALLINT,
    ac_l1000     SMALLINT,
    ac_l2000     SMALLINT,
    ac_l4000     SMALLINT,
    ac_l8000     SMALLINT,
    ac_r250      SMALLINT,
    ac_r500      SMALLINT,
    ac_r1000     SMALLINT,
    ac_r2000     SMALLINT,
    ac_r4000     SMALLINT,
    ac_r8000     SMALLINT,
    bc_l500t     SMALLINT,
    bc_l1000t    SMALLINT,
    bc_l2000t    SMALLINT,
    bc_l500tm    SMALLINT,
    bc_l1000tm   SMALLINT,
    bc_l2000tm   SMALLINT
);

INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_bc2freq_l_oneperfreq (
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    bc_l500t, bc_l1000t, bc_l2000t,
    bc_l500tm, bc_l1000tm, bc_l2000tm
)
SELECT 
    ac_patient_id,
    ac_audindex,
    ac_investdate,
    ac_sex,
    ac_age,
    CASE WHEN ac_l250tm  NOTNULL THEN ac_l250tm  ELSE ac_l250t  END,
    CASE WHEN ac_l500tm  NOTNULL THEN ac_l500tm  ELSE ac_l500t  END,
    CASE WHEN ac_l1000tm NOTNULL THEN ac_l1000tm ELSE ac_l1000t END,
    CASE WHEN ac_l2000tm NOTNULL THEN ac_l2000tm ELSE ac_l2000t END,
    CASE WHEN ac_l4000tm NOTNULL THEN ac_l4000tm ELSE ac_l4000t END,
    CASE WHEN ac_l8000tm NOTNULL THEN ac_l8000tm ELSE ac_l8000t END,
    CASE WHEN ac_r250tm  NOTNULL THEN ac_r250tm  ELSE ac_r250t  END,
    CASE WHEN ac_r500tm  NOTNULL THEN ac_r500tm  ELSE ac_r500t  END,
    CASE WHEN ac_r1000tm NOTNULL THEN ac_r1000tm ELSE ac_r1000t END,
    CASE WHEN ac_r2000tm NOTNULL THEN ac_r2000tm ELSE ac_r2000t END,
    CASE WHEN ac_r4000tm NOTNULL THEN ac_r4000tm ELSE ac_r4000t END,
    CASE WHEN ac_r8000tm NOTNULL THEN ac_r8000tm ELSE ac_r8000t END,
    bc_l500t, bc_l1000t, bc_l2000t,
    bc_l500tm, bc_l1000tm, bc_l2000tm
FROM data_acbc_ac250to8000_bl_bc2freq_l_rincom;

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_bc2freq_l_oneperfreq;  -- 39,711


/*======================================================================*
    52.2 SPLIT BY MASKED (tm) VS UNMASKED (t) LEFT BC
    - tm_notnull  : at least two masked (tm) BC thresholds among 500/1000/2000
    - tm_null     : masked values absent at the pair(s) of interest
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bc2freq_l_oneperfreq
WHERE
    (bc_l500tm NOTNULL AND bc_l1000tm NOTNULL) OR
    (bc_l1000tm NOTNULL AND bc_l2000tm NOTNULL) OR
    (bc_l500tm NOTNULL AND bc_l2000tm NOTNULL);

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull;  -- 15,095


DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_null;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_null AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bc2freq_l_oneperfreq
WHERE
    (bc_l500tm IS NULL AND bc_l1000tm IS NULL) OR
    (bc_l1000tm IS NULL AND bc_l2000tm IS NULL) OR
    (bc_l500tm IS NULL AND bc_l2000tm IS NULL);

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null;  -- 24,616

SELECT 24616 + 15095 AS "Addition_Stage52_split";  -- 39,711


/*======================================================================*
    52.3 GROUP A: MASKED LEFT BC (tm NOT NULL) BUT UNMASKED t MISSING
    - Can only make conclusions about the left ear
    - Use tm for ABG; ignore right ear for ABG
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull
WHERE
    (bc_l500t IS NULL AND bc_l1000t IS NULL) OR
    (bc_l1000t IS NULL AND bc_l2000t IS NULL) OR
    (bc_l500t IS NULL AND bc_l2000t IS NULL);

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null;  -- 9,525


-- Add ABG columns (left ear only here; right ABG not meaningful with masked-left only)
ALTER TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null
    ADD COLUMN l500_abg SMALLINT,
    ADD COLUMN l1000_abg SMALLINT,
    ADD COLUMN l2000_abg SMALLINT,
    ADD COLUMN r500_abg SMALLINT,
    ADD COLUMN r1000_abg SMALLINT,
    ADD COLUMN r2000_abg SMALLINT;

UPDATE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null
SET
    l500_abg = (ac_l500  - bc_l500tm),
    l1000_abg = (ac_l1000 - bc_l1000tm),
    l2000_abg = (ac_l2000 - bc_l2000tm);


-- Left SNHL (no CHL pattern in left ear)
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LSNHL;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LSNHL AS 
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null
WHERE 
    ( (l500_abg  < 25 AND l1000_abg < 25) OR
      (l500_abg  < 25 AND l2000_abg < 25) OR
      (l1000_abg < 25 AND l2000_abg < 25) );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LSNHL;  -- 6,284


-- Left CHL (clear ABG at ≥2 frequencies)
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LCHL;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LCHL AS 
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null
WHERE 
    ( (l500_abg  >= 25 AND l1000_abg >= 25) OR
      (l500_abg  >= 25 AND l2000_abg >= 25) OR
      (l1000_abg >= 25 AND l2000_abg >= 25) );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LCHL;  -- 2,857


-- Left ABG only at 1 frequency (does not meet CHL criteria)
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_l1freq;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_l1freq AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null
WHERE
    ( (l500_abg >= 25 AND l1000_abg < 25 AND l2000_abg IS NULL) OR
      (l500_abg >= 25 AND l1000_abg IS NULL AND l2000_abg < 25) OR
      (l500_abg IS NULL AND l1000_abg >= 25 AND l2000_abg < 25) OR
      (l500_abg IS NULL AND l1000_abg < 25 AND l2000_abg >= 25) OR
      (l500_abg < 25 AND l1000_abg >= 25 AND l2000_abg IS NULL) OR
      (l500_abg < 25 AND l1000_abg IS NULL AND l2000_abg >= 25)
    );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_l1freq;  -- 384

SELECT 
    384 + 2857 + 6284 AS "GroupA_total";  -- 9,525


/*======================================================================*
    52.4 GROUP B: MASKED LEFT BC (tm NOT NULL) AND UNMASKED t ALSO PRESENT
    - Now both left and right ABGs can be evaluated (right uses unmasked left BC)
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull
WHERE
    ( (bc_l500t NOTNULL AND bc_l1000t NOTNULL) OR
      (bc_l1000t NOTNULL AND bc_l2000t NOTNULL) OR
      (bc_l500t NOTNULL AND bc_l2000t NOTNULL) );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull;  -- 5,570


ALTER TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
    ADD COLUMN l500_abg SMALLINT,
    ADD COLUMN l1000_abg SMALLINT,
    ADD COLUMN l2000_abg SMALLINT,
    ADD COLUMN r500_abg SMALLINT,
    ADD COLUMN r1000_abg SMALLINT,
    ADD COLUMN r2000_abg SMALLINT;

-- Use masked BC (tm) for left ABG; unmasked left BC (t) as proxy for right BC
UPDATE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
SET 
    l500_abg = (ac_l500  - bc_l500tm),
    l1000_abg = (ac_l1000 - bc_l1000tm),
    l2000_abg = (ac_l2000 - bc_l2000tm),
    r500_abg = (ac_r500  - bc_l500t),
    r1000_abg = (ac_r1000 - bc_l1000t),
    r2000_abg = (ac_r2000 - bc_l2000t);


-- Left SNHL, right CHL (clear CHL pattern on right)
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LSNHL;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LSNHL AS 
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
WHERE 
    ( (l500_abg < 25 AND l1000_abg < 25) OR
      (l500_abg < 25 AND l2000_abg < 25) OR
      (l1000_abg < 25 AND l2000_abg < 25) )
    AND
    ( (r500_abg >= 25 AND r1000_abg >= 25) OR
      (r500_abg >= 25 AND r2000_abg >= 25) OR
      (r1000_abg >= 25 AND r2000_abg >= 25) );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LSNHL;  -- 87


-- SNHL in both ears (no CHL criteria met on either side)
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRSNHL;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRSNHL AS 
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
WHERE 
    (
        (l500_abg < 25 AND l1000_abg < 25) OR
        (l500_abg < 25 AND l2000_abg < 25) OR
        (l1000_abg < 25 AND l2000_abg < 25)
    )
    AND
    (
        (r500_abg < 25 AND r1000_abg < 25) OR
        (r500_abg < 25 AND r2000_abg < 25) OR
        (r1000_abg < 25 AND r2000_abg < 25)
    );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRSNHL;  -- 3,551


-- Right-only SNHL (no CHL pattern right, CHL left)
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_RSNHL;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_RSNHL AS 
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
WHERE 
    (
        (r500_abg < 25 AND r1000_abg < 25) OR
        (r500_abg < 25 AND r2000_abg < 25) OR
        (r1000_abg < 25 AND r2000_abg < 25)
    )
    AND
    (
        (l500_abg >= 25 AND l1000_abg >= 25) OR
        (l500_abg >= 25 AND l2000_abg >= 25) OR
        (l1000_abg >= 25 AND l2000_abg >= 25)
    );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_RSNHL;  -- 1,471


-- CHL both sides
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRCHL;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRCHL AS 
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
WHERE 
    (
        (r500_abg >= 25 AND r1000_abg >= 25) OR
        (r500_abg >= 25 AND r2000_abg >= 25) OR
        (r1000_abg >= 25 AND r2000_abg >= 25)
    )
    AND
    (
        (l500_abg >= 25 AND l1000_abg >= 25) OR
        (l500_abg >= 25 AND l2000_abg >= 25) OR
        (l1000_abg >= 25 AND l2000_abg >= 25)
    );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRCHL;  -- 176


-- Incomplete CHL patterns: either side has only 1-frequency ABG pattern
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_incomplete;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_incomplete AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
WHERE
    (
        (l500_abg >= 25 AND l1000_abg < 25 AND l2000_abg IS NULL) OR
        (l500_abg >= 25 AND l1000_abg IS NULL AND l2000_abg < 25) OR
        (l500_abg IS NULL AND l1000_abg >= 25 AND l2000_abg < 25) OR
        (l500_abg IS NULL AND l1000_abg < 25 AND l2000_abg >= 25) OR
        (l500_abg < 25 AND l1000_abg >= 25 AND l2000_abg IS NULL) OR
        (l500_abg < 25 AND l1000_abg IS NULL AND l2000_abg >= 25)
    )
    OR
    (
        (r500_abg >= 25 AND r1000_abg < 25 AND r2000_abg IS NULL) OR
        (r500_abg >= 25 AND r1000_abg IS NULL AND r2000_abg < 25) OR
        (r500_abg IS NULL AND r1000_abg >= 25 AND r2000_abg < 25) OR
        (r500_abg IS NULL AND r1000_abg < 25 AND r2000_abg >= 25) OR
        (r500_abg < 25 AND r1000_abg >= 25 AND r2000_abg IS NULL) OR
        (r500_abg < 25 AND r1000_abg IS NULL AND r2000_abg >= 25)
    );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_incomplete;  -- 285

SELECT 
    87 + 3551 + 1471 + 176 + 285 AS "GroupB_total";  -- 5,570


/*======================================================================*
    52.5 SUBCLASSIFY INCOMPLETE GROUP (285 RECORDS)
    - Build small diagnostic subgroups a, b, c, d, e, dd, ee, eee
      (kept as named tables for traceability)
*======================================================================*/

-- a = all 285 incomplete cases (already created above)
DROP TABLE IF EXISTS a;

CREATE TABLE a AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_incomplete;

SELECT COUNT(*) FROM a;  -- 285


-- b = from 'a', left ear SNHL (abg < 25 pattern)
DROP TABLE IF EXISTS b;

CREATE TABLE b AS
SELECT *
FROM a
WHERE 
    ( (l500_abg < 25 AND l1000_abg < 25) OR
      (l500_abg < 25 AND l2000_abg < 25) OR
      (l1000_abg < 25 AND l2000_abg < 25) );

SELECT COUNT(*) FROM b;  -- 3


-- c = from 'a', right ear SNHL
DROP TABLE IF EXISTS c;

CREATE TABLE c AS
SELECT *
FROM a
WHERE 
    ( (r500_abg < 25 AND r1000_abg < 25) OR
      (r500_abg < 25 AND r2000_abg < 25) OR
      (r1000_abg < 25 AND r2000_abg < 25) );

SELECT COUNT(*) FROM c;  -- 258


-- bb = left CHL, right incomplete
DROP TABLE IF EXISTS bb;

CREATE TABLE bb AS
SELECT *
FROM a
WHERE
    ( (l500_abg >= 25 AND l1000_abg >= 25) OR
      (l500_abg >= 25 AND l2000_abg >= 25) OR
      (l1000_abg >= 25 AND l2000_abg >= 25) )
    AND
    (
        (r500_abg >= 25 AND r1000_abg < 25 AND r2000_abg IS NULL) OR
        (r500_abg >= 25 AND r1000_abg IS NULL AND r2000_abg < 25) OR
        (r500_abg IS NULL AND r1000_abg >= 25 AND r2000_abg < 25) OR
        (r500_abg IS NULL AND r1000_abg < 25 AND r2000_abg >= 25) OR
        (r500_abg < 25 AND r1000_abg >= 25 AND r2000_abg IS NULL) OR
        (r500_abg < 25 AND r1000_abg IS NULL AND r2000_abg >= 25)
    );

SELECT COUNT(*) FROM bb;  -- 5


-- cc = right CHL, left incomplete
DROP TABLE IF EXISTS cc;

CREATE TABLE cc AS
SELECT *
FROM a
WHERE
    (r500_abg >= 25 AND r1000_abg >= 25) OR
    (r500_abg >= 25 AND r2000_abg >= 25) OR
    (r1000_abg >= 25 AND r2000_abg >= 25);

SELECT COUNT(*) FROM cc;  -- 16


-- aa = both ears incomplete (no clear CHL or SNHL classification)
DROP TABLE IF EXISTS aa;

CREATE TABLE aa AS
SELECT *
FROM a
WHERE
    (
        (r500_abg >= 25 AND r1000_abg < 25 AND r2000_abg IS NULL) OR
        (r500_abg >= 25 AND r1000_abg IS NULL AND r2000_abg < 25) OR
        (r500_abg IS NULL AND r1000_abg >= 25 AND r2000_abg < 25) OR
        (r500_abg IS NULL AND r1000_abg < 25 AND r2000_abg >= 25) OR
        (r500_abg < 25 AND r1000_abg >= 25 AND r2000_abg IS NULL) OR
        (r500_abg < 25 AND r1000_abg IS NULL AND r2000_abg >= 25)
    )
    AND
    (
        (l500_abg >= 25 AND l1000_abg < 25 AND l2000_abg IS NULL) OR
        (l500_abg >= 25 AND l1000_abg IS NULL AND l2000_abg < 25) OR
        (l500_abg IS NULL AND l1000_abg >= 25 AND l2000_abg < 25) OR
        (l500_abg IS NULL AND l1000_abg < 25 AND l2000_abg >= 25) OR
        (l500_abg < 25 AND l1000_abg >= 25 AND l2000_abg IS NULL) OR
        (l500_abg < 25 AND l1000_abg IS NULL AND l2000_abg >= 25)
    );

SELECT COUNT(*) FROM aa;  -- 3


/*======================================================================*
    52.6 BUILD SNHL-ONLY DATASET FOR LEFT-BC-ONLY CASES
    - data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL
    - Contains AC thresholds only (BC used only for classification)
*======================================================================*/

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL;

CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL (
    patient_id INT,
    audindex   SMALLINT,
    investdate DATE,
    sex        VARCHAR,
    age        INT,
    ac_l250    SMALLINT,
    ac_l500    SMALLINT,
    ac_l1000   SMALLINT,
    ac_l2000   SMALLINT,
    ac_l4000   SMALLINT,
    ac_l8000   SMALLINT,
    ac_r250    SMALLINT,
    ac_r500    SMALLINT,
    ac_r1000   SMALLINT,
    ac_r2000   SMALLINT,
    ac_r4000   SMALLINT,
    ac_r8000   SMALLINT
);

-- 1) Left masked-only SNHL group
INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL (
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT 
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LSNHL;

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL;  -- 6,284


-- 2) Right SNHL from tm-notnull+t-notnull group (RSNHL)
INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL (
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_RSNHL;

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL;  -- 7,755 (6,284 + 1,471)


-- 3) Left SNHL from tm-notnull+t-notnull group (LSNHL)
INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL (
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LSNHL;

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL;  -- 7,842 (7,755 + 87)


-- 4) Bilateral SNHL from tm-notnull+t-notnull group (LRSNHL)
INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL (
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRSNHL;

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL;  -- 11,393 (7,842 + 3,551)


-- 5) From 'b' (left SNHL, incomplete patterns)
INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL (
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM b;

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL;  -- 11,396 (11,393 + 3)


-- 6) From 'c' (right SNHL, incomplete patterns)
INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL (
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM c;

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL;  -- 11,654


/*======================================================================*
    52.7 GROUP C: LEFT BC UNMASKED ONLY (tm NULL), BC USED FOR LEFT AND RIGHT
    - Unmasked left BC is used as a proxy for right BC
    - Evaluate SNHL/CHL patterns similarly
*======================================================================*/

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null;  -- 24,616


ALTER TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_null
    ADD COLUMN l500_abg SMALLINT,
    ADD COLUMN l1000_abg SMALLINT,
    ADD COLUMN l2000_abg SMALLINT,
    ADD COLUMN r500_abg SMALLINT,
    ADD COLUMN r1000_abg SMALLINT,
    ADD COLUMN r2000_abg SMALLINT;

UPDATE data_acbc_ac250to8000_bl_bc2freq_l_tm_null
SET 
    l500_abg  = (ac_l500  - bc_l500t),
    l1000_abg = (ac_l1000 - bc_l1000t),
    l2000_abg = (ac_l2000 - bc_l2000t),
    r500_abg  = (ac_r500  - bc_l500t),
    r1000_abg = (ac_r1000 - bc_l1000t),
    r2000_abg = (ac_r2000 - bc_l2000t);


-- L+R SNHL
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LRSNHL;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LRSNHL AS
SELECT 
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    bc_l500t, bc_l1000t, bc_l2000t
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null
WHERE
    (
        (l500_abg < 25 AND l1000_abg < 25) OR
        (l500_abg < 25 AND l2000_abg < 25) OR
        (l1000_abg < 25 AND l2000_abg < 25)
    )
    AND
    (
        (r500_abg < 25 AND r1000_abg < 25) OR
        (r500_abg < 25 AND r2000_abg < 25) OR
        (r1000_abg < 25 AND r2000_abg < 25)
    );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LRSNHL;  -- 20,808


-- Left SNHL, right CHL
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LSNHL;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LSNHL AS
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    bc_l500t, bc_l1000t, bc_l2000t
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null
WHERE
    (
        (l500_abg < 25 AND l1000_abg < 25) OR
        (l500_abg < 25 AND l2000_abg < 25) OR
        (l1000_abg < 25 AND l2000_abg < 25)
    )
    AND
    (
        (r500_abg >= 25 AND r1000_abg >= 25) OR
        (r500_abg >= 25 AND r2000_abg >= 25) OR
        (r1000_abg >= 25 AND r2000_abg >= 25)
    );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LSNHL;  -- 1,081


-- Right SNHL, left CHL
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RSNHL;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RSNHL AS
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    bc_l500t, bc_l1000t, bc_l2000t
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null
WHERE
    (
        (r500_abg < 25 AND r1000_abg < 25) OR
        (r500_abg < 25 AND r2000_abg < 25) OR
        (r1000_abg < 25 AND r2000_abg < 25)
    )
    AND
    (
        (l500_abg >= 25 AND l1000_abg >= 25) OR
        (l500_abg >= 25 AND l2000_abg >= 25) OR
        (l1000_abg >= 25 AND l2000_abg >= 25)
    );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RSNHL;  -- 608


-- L+R CHL
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RLCHL;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RLCHL AS
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    bc_l500t, bc_l1000t, bc_l2000t
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null
WHERE
    (
        (r500_abg >= 25 AND r1000_abg >= 25) OR
        (r500_abg >= 25 AND r2000_abg >= 25) OR
        (r1000_abg >= 25 AND r2000_abg >= 25)
    )
    AND
    (
        (l500_abg >= 25 AND l1000_abg >= 25) OR
        (l500_abg >= 25 AND l2000_abg >= 25) OR
        (l1000_abg >= 25 AND l2000_abg >= 25)
    );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RLCHL;  -- 1,821


-- Incomplete CHL patterns (1-frequency ABG)
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null
WHERE
    (
        (l500_abg >= 25 AND l1000_abg < 25 AND l2000_abg IS NULL) OR
        (l500_abg >= 25 AND l1000_abg IS NULL AND l2000_abg < 25) OR
        (l500_abg IS NULL AND l1000_abg >= 25 AND l2000_abg < 25) OR
        (l500_abg IS NULL AND l1000_abg < 25 AND l2000_abg >= 25) OR
        (l500_abg < 25 AND l1000_abg >= 25 AND l2000_abg IS NULL) OR
        (l500_abg < 25 AND l1000_abg IS NULL AND l2000_abg >= 25)
    )
    OR
    (
        (r500_abg >= 25 AND r1000_abg < 25 AND r2000_abg IS NULL) OR
        (r500_abg >= 25 AND r1000_abg IS NULL AND r2000_abg < 25) OR
        (r500_abg IS NULL AND r1000_abg >= 25 AND r2000_abg < 25) OR
        (r500_abg IS NULL AND r1000_abg < 25 AND r2000_abg >= 25) OR
        (r500_abg < 25 AND r1000_abg >= 25 AND r2000_abg IS NULL) OR
        (r500_abg < 25 AND r1000_abg IS NULL AND r2000_abg >= 25)
    );

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq;  -- 186


-- d = from bl1freq, left SNHL
DROP TABLE IF EXISTS d;

CREATE TABLE d AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq
WHERE 
    ( (l500_abg < 25 AND l1000_abg < 25) OR
      (l500_abg < 25 AND l2000_abg < 25) OR
      (l1000_abg < 25 AND l2000_abg < 25) );

SELECT COUNT(*) FROM d;  -- 35


-- e = from bl1freq, right SNHL
DROP TABLE IF EXISTS e;

CREATE TABLE e AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq
WHERE 
    ( (r500_abg < 25 AND r1000_abg < 25) OR
      (r500_abg < 25 AND r2000_abg < 25) OR
      (r1000_abg < 25 AND r2000_abg < 25) );

SELECT COUNT(*) FROM e;  -- 72


-- dd = from bl1freq, left CHL (right incomplete)
DROP TABLE IF EXISTS dd;

CREATE TABLE dd AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq
WHERE 
    ( (l500_abg >= 25 AND l1000_abg >= 25) OR
      (l500_abg >= 25 AND l2000_abg >= 25) OR
      (l1000_abg >= 25 AND l2000_abg >= 25) );

SELECT COUNT(*) FROM dd;  -- 16


-- ee = from bl1freq, right CHL (left incomplete)
DROP TABLE IF EXISTS ee;

CREATE TABLE ee AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq
WHERE 
    ( (r500_abg >= 25 AND r1000_abg >= 25) OR
      (r500_abg >= 25 AND r2000_abg >= 25) OR
      (r1000_abg >= 25 AND r2000_abg >= 25) );

SELECT COUNT(*) FROM ee;  -- 16 (note: earlier comment said 18; keeping logic)


-- eee = both ears incomplete (no clear CHL / SNHL)
DROP TABLE IF EXISTS eee;

CREATE TABLE eee AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq
WHERE 
    (
        (l500_abg >= 25 AND l1000_abg < 25 AND l2000_abg IS NULL) OR
        (l500_abg >= 25 AND l1000_abg IS NULL AND l2000_abg < 25) OR
        (l500_abg IS NULL AND l1000_abg >= 25 AND l2000_abg < 25) OR
        (l500_abg IS NULL AND l1000_abg < 25 AND l2000_abg >= 25) OR
        (l500_abg < 25 AND l1000_abg >= 25 AND l2000_abg IS NULL) OR
        (l500_abg < 25 AND l1000_abg IS NULL AND l2000_abg >= 25)
    )
    AND
    (
        (r500_abg >= 25 AND r1000_abg < 25 AND r2000_abg IS NULL) OR
        (r500_abg >= 25 AND r1000_abg IS NULL AND r2000_abg < 25) OR
        (r500_abg IS NULL AND r1000_abg >= 25 AND r2000_abg < 25) OR
        (r500_abg IS NULL AND r1000_abg < 25 AND r2000_abg >= 25) OR
        (r500_abg < 25 AND r1000_abg >= 25 AND r2000_abg IS NULL) OR
        (r500_abg < 25 AND r1000_abg IS NULL AND r2000_abg >= 25)
    );

SELECT COUNT(*) FROM eee;  -- 47


-- Cases where ABG is entirely NULL (no ABG info at all)
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_l_tm_null_null;

CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_l_tm_null_null AS
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    bc_l500t, bc_l1000t, bc_l2000t
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null
WHERE
    (l500_abg  IS NULL AND l2000_abg IS NULL) OR
    (l500_abg  IS NULL AND l1000_abg IS NULL) OR
    (l1000_abg IS NULL AND l2000_abg IS NULL);

SELECT COUNT(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_null;  -- 112


SELECT 
    20808 + 1081 + 608 + 1821 + 186 + 112 AS "GroupC_total";  -- 24,616 (consistency check)

------------------------------------------------------------
------------------------  STAGE 5f  -------------------------
--   PROCESSING FOR PATIENTS WITH AC IN BOTH EARS AND
--   BONE-CONDUCTION AVAILABLE **ONLY IN THE RIGHT EAR**
--
--   This section mirrors Stage 5e (left-ear only), but now
--   examines cases where right-ear BC is present while left
--   is incomplete or absent.
------------------------------------------------------------


------------------------------------------------------------
-- 5f-1 : Starting group — AC complete bilaterally, but BC
--        at required 2 frequencies ONLY for the right ear
------------------------------------------------------------

SELECT count(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_r_lincom; 
-- 43106


------------------------------------------------------------
-- 5f-2 : Create unified AC table + raw BC-right values
--        (t + tm kept separately here)
------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc500to2000_bc2freq_r_oneperfreq;

CREATE TABLE data_acbc_ac250to8000_bl_bc500to2000_bc2freq_r_oneperfreq
(
  patient_id int,
  audindex smallint,
  investdate date,
  sex varchar,
  age int,
  ac_l250 smallint, ac_l500 smallint, ac_l1000 smallint, ac_l2000 smallint,
  ac_l4000 smallint, ac_l8000 smallint,
  ac_r250 smallint, ac_r500 smallint, ac_r1000 smallint, ac_r2000 smallint,
  ac_r4000 smallint, ac_r8000 smallint,
  bc_r500t smallint, bc_r1000t smallint, bc_r2000t smallint,
  bc_r500tm smallint, bc_r1000tm smallint, bc_r2000tm smallint
);

INSERT INTO data_acbc_ac250to8000_bl_bc500to2000_bc2freq_r_oneperfreq
(
  patient_id, audindex, investdate, sex, age,
  ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
  ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
  bc_r500t, bc_r1000t, bc_r2000t,
  bc_r500tm, bc_r1000tm, bc_r2000tm
)
SELECT
  ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
  CASE WHEN ac_l250tm NOTNULL THEN ac_l250tm ELSE ac_l250t END,
  CASE WHEN ac_l500tm NOTNULL THEN ac_l500tm ELSE ac_l500t END,
  CASE WHEN ac_l1000tm NOTNULL THEN ac_l1000tm ELSE ac_l1000t END,
  CASE WHEN ac_l2000tm NOTNULL THEN ac_l2000tm ELSE ac_l2000t END,
  CASE WHEN ac_l4000tm NOTNULL THEN ac_l4000tm ELSE ac_l4000t END,
  CASE WHEN ac_l8000tm NOTNULL THEN ac_l8000tm ELSE ac_l8000t END,
  CASE WHEN ac_r250tm NOTNULL THEN ac_r250tm ELSE ac_r250t END,
  CASE WHEN ac_r500tm NOTNULL THEN ac_r500tm ELSE ac_r500t END,
  CASE WHEN ac_r1000tm NOTNULL THEN ac_r1000tm ELSE ac_r1000t END,
  CASE WHEN ac_r2000tm NOTNULL THEN ac_r2000tm ELSE ac_r2000t END,
  CASE WHEN ac_r4000tm NOTNULL THEN ac_r4000tm ELSE ac_r4000t END,
  CASE WHEN ac_r8000tm NOTNULL THEN ac_r8000tm ELSE ac_r8000t END,
  bc_r500t, bc_r1000t, bc_r2000t,
  bc_r500tm, bc_r1000tm, bc_r2000tm
FROM data_acbc_ac250to8000_bl_bc2freq_r_lincom;

SELECT count(*) 
FROM data_acbc_ac250to8000_bl_bc500to2000_bc2freq_r_oneperfreq;
-- 43106


------------------------------------------------------------
-- 5f-3 : Split into masked (tm) vs. unmasked (t) availability
------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bc2freq_r_oneperfreq
WHERE 
      (bc_r500tm NOTNULL AND bc_r1000tm NOTNULL)
   OR (bc_r1000tm NOTNULL AND bc_r2000tm NOTNULL)
   OR (bc_r500tm NOTNULL AND bc_r2000tm NOTNULL);

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull;  -- 14803


DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_null;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_null AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc500to2000_bc2freq_r_oneperfreq
WHERE 
      (bc_r500tm IS NULL AND bc_r1000tm IS NULL)
   OR (bc_r1000tm IS NULL AND bc_r2000tm IS NULL)
   OR (bc_r500tm IS NULL AND bc_r2000tm IS NULL);

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null; -- 28303

SELECT 28303 + 14803 AS addition; -- 43106


------------------------------------------------------------
-- 5f-4 : Within masked-BC group, split by availability of T
------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull
WHERE 
      (bc_r500t IS NULL AND bc_r1000t IS NULL)
   OR (bc_r1000t IS NULL AND bc_r2000t IS NULL)
   OR (bc_r500t IS NULL AND bc_r2000t IS NULL);

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null; -- 9644


DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull
WHERE 
      (bc_r500t NOTNULL AND bc_r1000t NOTNULL)
   OR (bc_r1000t NOTNULL AND bc_r2000t NOTNULL)
   OR (bc_r500t NOTNULL AND bc_r2000t NOTNULL);

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull; -- 5159

SELECT 9644 + 5159 AS addition; -- 14803


------------------------------------------------------------
-- 5f-5 : Compute ABGs (masked only, since T missing)
------------------------------------------------------------

ALTER TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null
ADD COLUMN l500_abg smallint,
ADD COLUMN l1000_abg smallint,
ADD COLUMN l2000_abg smallint,
ADD COLUMN r500_abg smallint,
ADD COLUMN r1000_abg smallint,
ADD COLUMN r2000_abg smallint;

-- Right-ear ABG uses masked TM values
UPDATE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null
SET
  r500_abg = (ac_r500  - bc_r500tm),
  r1000_abg = (ac_r1000 - bc_r1000tm),
  r2000_abg = (ac_r2000 - bc_r2000tm);


------------------------------------------------------------
-- 5f-6 : Categorise masked-T-null group:
--        SNHL-R, CHL-R, incomplete-R
------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rSNHL;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rSNHL AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null
WHERE
      (r500_abg <25 AND r1000_abg <25)
   OR (r500_abg <25 AND r2000_abg <25)
   OR (r1000_abg <25 AND r2000_abg <25);

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rSNHL; -- 6278


DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rCHL;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rCHL AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null
WHERE
      (r500_abg >=25 AND r1000_abg >=25)
   OR (r500_abg >=25 AND r2000_abg >=25)
   OR (r1000_abg >=25 AND r2000_abg >=25);

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rCHL; -- 2984


DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_r1freq;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_r1freq AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null
WHERE
      (r500_abg >=25 AND r1000_abg <25 AND r2000_abg IS NULL)
   OR (r500_abg >=25 AND r1000_abg IS NULL AND r2000_abg <25)
   OR (r500_abg IS NULL AND r1000_abg >=25 AND r2000_abg <25)
   OR (r500_abg IS NULL AND r1000_abg <25 AND r2000_abg >=25)
   OR (r500_abg <25 AND r1000_abg >=25 AND r2000_abg IS NULL)
   OR (r500_abg <25 AND r1000_abg IS NULL AND r2000_abg >=25);

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_r1freq; -- 388

SELECT 388 + 2984 + 6278 AS Addition; -- 9644


------------------------------------------------------------
-- 5f-7 : Now process tm-notnull + t-notnull group
--        (True bilateral ABG evaluation possible)
------------------------------------------------------------

ALTER TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
ADD COLUMN l500_abg smallint,
ADD COLUMN l1000_abg smallint,
ADD COLUMN l2000_abg smallint,
ADD COLUMN r500_abg smallint,
ADD COLUMN r1000_abg smallint,
ADD COLUMN r2000_abg smallint;

-- Right uses t; Left uses tm (right-masked)
UPDATE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
SET
  l500_abg = (ac_l500 - bc_r500tm),
  l1000_abg = (ac_l1000 - bc_r1000tm),
  l2000_abg = (ac_l2000 - bc_r2000tm),
  r500_abg = (ac_r500 - bc_r500t),
  r1000_abg = (ac_r1000 - bc_r1000t),
  r2000_abg = (ac_r2000 - bc_r2000t);


-- SNHL-R + CHL-L
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_rSNHL;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_rSNHL AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
WHERE
      ((r500_abg <25 AND r1000_abg <25)
    OR (r500_abg <25 AND r2000_abg <25)
    OR (r1000_abg <25 AND r2000_abg <25))
  AND
      ((l500_abg >=25 AND l1000_abg >=25)
    OR (l500_abg >=25 AND l2000_abg >=25)
    OR (l1000_abg >=25 AND l2000_abg >=25));

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_rSNHL; -- 5


-- SNHL-L + SNHL-R
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRSNHL;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRSNHL AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
WHERE
      ((l500_abg <25 AND l1000_abg <25)
    OR (l500_abg <25 AND l2000_abg <25)
    OR (l1000_abg <25 AND l2000_abg <25))
  AND
      ((r500_abg <25 AND r1000_abg <25)
    OR (r500_abg <25 AND r2000_abg <25)
    OR (r1000_abg <25 AND r2000_abg <25));

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRSNHL; -- 1809


-- SNHL-L only
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_lSNHL;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_lSNHL AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
WHERE
      ((l500_abg <25 AND l1000_abg <25)
    OR (l500_abg <25 AND l2000_abg <25)
    OR (l1000_abg <25 AND l2000_abg <25))
  AND
      ((r500_abg >=25 AND r1000_abg >=25)
    OR (r500_abg >=25 AND r2000_abg >=25)
    OR (r1000_abg >=25 AND r2000_abg >=25));

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_lSNHL; -- 3144


-- CHL-L + CHL-R
DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRCHL;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRCHL AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
WHERE
      ((r500_abg >=25 AND r1000_abg >=25)
    OR (r500_abg >=25 AND r2000_abg >=25)
    OR (r1000_abg >=25 AND r2000_abg >=25))
  AND
      ((l500_abg >=25 AND l1000_abg >=25)
    OR (l500_abg >=25 AND l2000_abg >=25)
    OR (l1000_abg >=25 AND l2000_abg >=25));

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRCHL; -- 89


-- Incomplete patterns (1-freq criteria failures)
DROP TABLE IF EXISTS f;
CREATE TABLE f AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
WHERE
      (
         (l500_abg >=25 AND l1000_abg <25 AND l2000_abg IS NULL)
      OR (l500_abg >=25 AND l1000_abg IS NULL AND l2000_abg <25)
      OR (l500_abg IS NULL AND l1000_abg >=25 AND l2000_abg <25)
      OR (l500_abg IS NULL AND l1000_abg <25 AND l2000_abg >=25)
      OR (l500_abg <25 AND l1000_abg >=25 AND l2000_abg IS NULL)
      OR (l500_abg <25 AND l1000_abg IS NULL AND l2000_abg >=25)
      )
   OR
      (
         (r500_abg >=25 AND r1000_abg <25 AND r2000_abg IS NULL)
      OR (r500_abg >=25 AND r1000_abg IS NULL AND r2000_abg <25)
      OR (r500_abg IS NULL AND r1000_abg >=25 AND r2000_abg <25)
      OR (r500_abg IS NULL AND r1000_abg <25 AND r2000_abg >=25)
      OR (r500_abg <25 AND r1000_abg >=25 AND r2000_abg IS NULL)
      OR (r500_abg <25 AND r1000_abg IS NULL AND r2000_abg >=25)
      );

SELECT count(*) FROM f; -- 119


------------------------------------------------------------
-- 5f-8 : From the 119 incomplete cases, split into all
--        possible SNHL/CHL/incomplete combinations
------------------------------------------------------------

DROP TABLE IF EXISTS g;
CREATE TABLE g AS 
SELECT * FROM f
WHERE 
      (l500_abg <25 AND l1000_abg <25)
   OR (l500_abg <25 AND l2000_abg <25)
   OR (l1000_abg <25 AND l2000_abg <25);

SELECT count(*) FROM g; -- 53


DROP TABLE IF EXISTS h;
CREATE TABLE h AS 
SELECT * FROM f
WHERE 
      (r500_abg <25 AND r1000_abg <25)
   OR (r500_abg <25 AND r2000_abg <25)
   OR (r1000_abg <25 AND r2000_abg <25);

SELECT count(*) FROM h; -- 20


DROP TABLE IF EXISTS gg;
CREATE TABLE gg AS 
SELECT * FROM f
WHERE 
      (l500_abg >=25 AND l1000_abg >=25)
   OR (l500_abg >=25 AND l2000_abg >=25)
   OR (l1000_abg >=25 AND l2000_abg >=25);

SELECT count(*) FROM gg; -- 43


DROP TABLE IF EXISTS hh;
CREATE TABLE hh AS 
SELECT * FROM f
WHERE 
      (r500_abg >=25 AND r1000_abg >=25)
   OR (r500_abg >=25 AND r2000_abg >=25)
   OR (r1000_abg >=25 AND r2000_abg >=25);

SELECT count(*) FROM hh; -- 43


DROP TABLE IF EXISTS fff;
CREATE TABLE fff AS 
SELECT *
FROM f
WHERE
      (
         (l500_abg >=25 AND l1000_abg <25 AND l2000_abg IS NULL)
      OR (l500_abg >=25 AND l1000_abg IS NULL AND l2000_abg <25)
      OR (l500_abg IS NULL AND l1000_abg >=25 AND l2000_abg <25)
      OR (l500_abg IS NULL AND l1000_abg <25 AND l2000_abg >=25)
      OR (l500_abg <25 AND l1000_abg >=25 AND l2000_abg IS NULL)
      OR (l500_abg <25 AND l1000_abg IS NULL AND l2000_abg >=25)
      )
  AND
      (
         (r500_abg >=25 AND r1000_abg <25 AND r2000_abg IS NULL)
      OR (r500_abg >=25 AND r1000_abg IS NULL AND r2000_abg <25)
      OR (r500_abg IS NULL AND r1000_abg >=25 AND r2000_abg <25)
      OR (r500_abg IS NULL AND r1000_abg <25 AND r2000_abg >=25)
      OR (r500_abg <25 AND r1000_abg >=25 AND r2000_abg IS NULL)
      OR (r500_abg <25 AND r1000_abg IS NULL AND r2000_abg >=25)
      );

SELECT count(*) FROM fff; -- 1


SELECT 1 + 43 + 20 + 53; -- 119


------------------------------------------------------------
-- 5f-9 : Right-ear BC group with unmasked-only BC (tm null)
------------------------------------------------------------

SELECT count(*) 
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null; -- 28303

SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null
WHERE 
     (bc_r500t IS NULL AND bc_r1000t IS NULL)
  OR (bc_r1000t IS NULL AND bc_r2000t IS NULL)
  OR (bc_r500t IS NULL AND bc_r2000t IS NULL);
-- 100 rows


------------------------------------------------------------
-- Add ABG using unmasked BC
------------------------------------------------------------

ALTER TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_null
ADD COLUMN l500_abg smallint,
ADD COLUMN l1000_abg smallint,
ADD COLUMN l2000_abg smallint,
ADD COLUMN r500_abg smallint,
ADD COLUMN r1000_abg smallint,
ADD COLUMN r2000_abg smallint;

UPDATE data_acbc_ac250to8000_bl_bc2freq_r_tm_null
SET
  l500_abg = (ac_l500 - bc_r500t),
  l1000_abg = (ac_l1000 - bc_r1000t),
  l2000_abg = (ac_l2000 - bc_r2000t),
  r500_abg = (ac_r500 - bc_r500t),
  r1000_abg = (ac_r1000 - bc_r1000t),
  r2000_abg = (ac_r2000 - bc_r2000t);


------------------------------------------------------------
-- 5f-10 : SNHL-L + SNHL-R
------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_null_LRSNHL;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_null_LRSNHL AS
SELECT
  patient_id, audindex, investdate, sex, age,
  ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
  ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
  bc_r500t, bc_r1000t, bc_r2000t
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null
WHERE
      ((l500_abg <25 AND l1000_abg <25)
    OR (l500_abg <25 AND l2000_abg <25)
    OR (l1000_abg <25 AND l2000_abg <25))
  AND
      ((r500_abg <25 AND r1000_abg <25)
    OR (r500_abg <25 AND r2000_abg <25)
    OR (r1000_abg <25 AND r2000_abg <25));

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_LRSNHL; -- 23445


------------------------------------------------------------
-- 5f-11 : CHL-L + SNHL-R
------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_null_rSNHL;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_null_rSNHL AS
SELECT
  patient_id, audindex, investdate, sex, age,
  ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
  bc_r500t, bc_r1000t, bc_r2000t
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null
WHERE
      ((r500_abg <25 AND r1000_abg <25)
    OR (r500_abg <25 AND r2000_abg <25)
    OR (r1000_abg <25 AND r2000_abg <25))
  AND 
      ((l500_abg >=25 AND l1000_abg >=25)
    OR (l500_abg >=25 AND l2000_abg >=25)
    OR (l1000_abg >=25 AND l2000_abg >=25));

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_rSNHL; -- 1200


------------------------------------------------------------
-- 5f-12 : SNHL-L + CHL-R
------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_null_lSNHL;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_null_lSNHL AS
SELECT
  patient_id, audindex, investdate, sex, age,
  ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
  bc_r500t, bc_r1000t, bc_r2000t
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null
WHERE
      ((l500_abg <25 AND l1000_abg <25)
    OR (l500_abg <25 AND l2000_abg <25)
    OR (l1000_abg <25 AND l2000_abg <25))
  AND 
      ((r500_abg >=25 AND r1000_abg >=25)
    OR (r500_abg >=25 AND r2000_abg >=25)
    OR (r1000_abg >=25 AND r2000_abg >=25));

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_lSNHL; -- 753


------------------------------------------------------------
-- 5f-13 : CHL-L + CHL-R
------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_null_RLCHL;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_null_RLCHL AS
SELECT
  patient_id, audindex, investdate, sex, age,
  ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
  ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
  bc_r500t, bc_r1000t, bc_r2000t
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null
WHERE
      ((r500_abg >=25 AND r1000_abg >=25)
    OR (r500_abg >=25 AND r2000_abg >=25)
    OR (r1000_abg >=25 AND r2000_abg >=25))
  AND 
      ((l500_abg >=25 AND l1000_abg >=25)
    OR (l500_abg >=25 AND l2000_abg >=25)
    OR (l1000_abg >=25 AND l2000_abg >=25));

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_RLCHL; -- 2618


------------------------------------------------------------
-- 5f-14 : Both sides incomplete patterns (1-freq)
------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null
WHERE
      (
         (l500_abg >=25 AND l1000_abg <25 AND l2000_abg IS NULL)
      OR (l500_abg >=25 AND l1000_abg IS NULL AND l2000_abg <25)
      OR (l500_abg IS NULL AND l1000_abg >=25 AND l2000_abg <25)
      OR (l500_abg IS NULL AND l1000_abg <25 AND l2000_abg >=25)
      OR (l500_abg <25 AND l1000_abg >=25 AND l2000_abg IS NULL)
      OR (l500_abg <25 AND l1000_abg IS NULL AND l2000_abg >=25)
      )
   OR
      (
         (r500_abg >=25 AND r1000_abg <25 AND r2000_abg IS NULL)
      OR (r500_abg >=25 AND r1000_abg IS NULL AND r2000_abg <25)
      OR (r500_abg IS NULL AND r1000_abg >=25 AND r2000_abg <25)
      OR (r500_abg IS NULL AND r1000_abg <25 AND r2000_abg >=25)
      OR (r500_abg <25 AND r1000_abg >=25 AND r2000_abg IS NULL)
      OR (r500_abg <25 AND r1000_abg IS NULL AND r2000_abg >=25)
      );

SELECT count(*) FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq; -- 187

SELECT 187 + 2618 + 753 + 1200 + 23445 + 100; -- 28303


------------------------------------------------------------
-- 5f-15 : Further split of incomplete 187 cases into
--         SNHL-L, CHL-L, SNHL-R, CHL-R, incomplete-both
------------------------------------------------------------

DROP TABLE IF EXISTS i;
CREATE TABLE i AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq
WHERE
      (l500_abg <25 AND l1000_abg <25)
   OR (l500_abg <25 AND l2000_abg <25)
   OR (l1000_abg <25 AND l2000_abg <25);

SELECT count(*) FROM i; -- 94


DROP TABLE IF EXISTS ii;
CREATE TABLE ii AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq
WHERE
      (l500_abg >=25 AND l1000_abg >=25)
   OR (l500_abg >=25 AND l2000_abg >=25)
   OR (l1000_abg >=25 AND l2000_abg >=25);

SELECT count(*) FROM ii; -- 14


DROP TABLE IF EXISTS j;
CREATE TABLE j AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq
WHERE
      (r500_abg <25 AND r1000_abg <25)
   OR (r500_abg <25 AND r2000_abg <25)
   OR (r1000_abg <25 AND r2000_abg <25);

SELECT count(*) FROM j; -- 39


DROP TABLE IF EXISTS jj;
CREATE TABLE jj AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq
WHERE
      (r500_abg >=25 AND r1000_abg >=25)
   OR (r500_abg >=25 AND r2000_abg >=25)
   OR (r1000_abg >=25 AND r2000_abg >=25);

SELECT count(*) FROM jj; -- 7


DROP TABLE IF EXISTS iii;
CREATE TABLE iii AS
SELECT *
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq
WHERE
      (
         (l500_abg >=25 AND l1000_abg <25 AND l2000_abg IS NULL)
      OR (l500_abg >=25 AND l1000_abg IS NULL AND l2000_abg <25)
      OR (l500_abg IS NULL AND l1000_abg >=25 AND l2000_abg <25)
      OR (l500_abg IS NULL AND l1000_abg <25 AND l2000_abg >=25)
      OR (l500_abg <25 AND l1000_abg >=25 AND l2000_abg IS NULL)
      OR (l500_abg <25 AND l1000_abg IS NULL AND l2000_abg >=25)
      )
  AND
      (
         (r500_abg >=25 AND r1000_abg <25 AND r2000_abg IS NULL)
      OR (r500_abg >=25 AND r1000_abg IS NULL AND r2000_abg <25)
      OR (r500_abg IS NULL AND r1000_abg >=25 AND r2000_abg <25)
      OR (r500_abg IS NULL AND r1000_abg <25 AND r2000_abg >=25)
      OR (r500_abg <25 AND r1000_abg >=25 AND r2000_abg IS NULL)
      OR (r500_abg <25 AND r1000_abg IS NULL AND r2000_abg >=25)
      );

SELECT count(*) FROM iii; -- 33


------------------------------------------------------------
-- 5f-16 : Final null-ABG category (right only)
------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_bl_bc2freq_r_tm_null_null;
CREATE TABLE data_acbc_ac250to8000_bl_bc2freq_r_tm_null_null AS
SELECT
  patient_id, audindex, investdate, sex, age,
  ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
  ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
  bc_r500t, bc_r1000t, bc_r2000t
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null
WHERE 
     (r500_abg IS NULL AND r2000_abg IS NULL)
  OR (r500_abg IS NULL AND r1000_abg IS NULL)
  OR (r1000_abg IS NULL AND r2000_abg IS NULL);

---------------------------------------------------------------------
------------------------------  STAGE 5g  ----------------------------
--   LEFT EAR AC-ONLY CASES
--   This stage continues exactly from Stage 5b, but now placed 
--   after Stage 5f for correct logical ordering.
--
--   These are patients with complete AC in the LEFT ear only.
--   BC may be complete or incomplete on left OR (in later parts)
--   right-ear BC may be used as a proxy for absent left BC.
---------------------------------------------------------------------


-------------------------------
-- 5g-1 : Counts of left-AC group
-------------------------------
SELECT count(*) FROM data_acbc_ac250to8000_l;           -- 1797
SELECT count(*) FROM data_acbc_ac250to8000_l_bc2freq_l; -- 1519
SELECT count(*) FROM data_acbc_ac250to8000_l_bc_lincom; -- 280


---------------------------------------------------------------------
-- 5g-2 : Create unified AC+BC table for those with complete left BC
---------------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq;

CREATE TABLE data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
(
  patient_id int,
  audindex smallint,
  investdate date,
  sex varchar,
  age int,
  ac_l250 smallint, ac_l500 smallint, ac_l1000 smallint,
  ac_l2000 smallint, ac_l4000 smallint, ac_l8000 smallint,
  bc_l500 smallint, bc_l1000 smallint, bc_l2000 smallint
);

INSERT INTO data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
(
  patient_id, audindex, investdate, sex, age,
  ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
  bc_l500, bc_l1000, bc_l2000
)
SELECT
  ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
  CASE WHEN ac_l250tm NOTNULL THEN ac_l250tm ELSE ac_l250t END,
  CASE WHEN ac_l500tm NOTNULL THEN ac_l500tm ELSE ac_l500t END,
  CASE WHEN ac_l1000tm NOTNULL THEN ac_l1000tm ELSE ac_l1000t END,
  CASE WHEN ac_l2000tm NOTNULL THEN ac_l2000tm ELSE ac_l2000t END,
  CASE WHEN ac_l4000tm NOTNULL THEN ac_l4000tm ELSE ac_l4000t END,
  CASE WHEN ac_l8000tm NOTNULL THEN ac_l8000tm ELSE ac_l8000t END,
  CASE WHEN bc_l500tm NOTNULL THEN bc_l500tm ELSE bc_l500t END,
  CASE WHEN bc_l1000tm NOTNULL THEN bc_l1000tm ELSE bc_l1000t END,
  CASE WHEN bc_l2000tm NOTNULL THEN bc_l2000tm ELSE bc_l2000t END
FROM data_acbc_ac250to8000_l_bc2freq_l;

SELECT count(*) FROM data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq; -- 1519


------------------------------------------------------
-- Add ABG (masked or unmasked consolidated BC)
------------------------------------------------------

ALTER TABLE data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
ADD COLUMN l500_abg smallint,
ADD COLUMN l1000_abg smallint,
ADD COLUMN l2000_abg smallint;

UPDATE data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
SET 
  l500_abg = (ac_l500 - bc_l500),
  l1000_abg = (ac_l1000 - bc_l1000),
  l2000_abg = (ac_l2000 - bc_l2000);


------------------------------------------------------
-- 5g-3 : Categorise left-ear BC results
------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_l_bc500to2000_bc2freq_LSNHL;
CREATE TABLE data_acbc_ac250to8000_l_bc500to2000_bc2freq_LSNHL AS
SELECT *
FROM data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
WHERE
      (l500_abg <25 AND l1000_abg <25)
   OR (l500_abg <25 AND l2000_abg <25)
   OR (l1000_abg <25 AND l2000_abg <25);

SELECT count(*) FROM data_acbc_ac250to8000_l_bc500to2000_bc2freq_LSNHL; -- 1050


DROP TABLE IF EXISTS data_acbc_ac250to8000_l_bc500to2000_bc2freq_LCHL;
CREATE TABLE data_acbc_ac250to8000_l_bc500to2000_bc2freq_LCHL AS
SELECT *
FROM data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
WHERE
      (l500_abg >=25 AND l1000_abg >=25)
   OR (l500_abg >=25 AND l2000_abg >=25)
   OR (l1000_abg >=25 AND l2000_abg >=25);

SELECT count(*) FROM data_acbc_ac250to8000_l_bc500to2000_bc2freq_LCHL; -- 466


-- Incomplete patterns (1-frequency)
DROP TABLE IF EXISTS data_acbc_ac250to8000_l_bc500to2000_bc2freq_Lincom;
CREATE TABLE data_acbc_ac250to8000_l_bc500to2000_bc2freq_Lincom AS
SELECT *
FROM data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
WHERE
      (l500_abg >=25 AND l1000_abg <25 AND l2000_abg IS NULL)
   OR (l500_abg >=25 AND l1000_abg IS NULL AND l2000_abg <25)
   OR (l500_abg IS NULL AND l1000_abg >=25 AND l2000_abg <25)
   OR (l500_abg IS NULL AND l1000_abg <25 AND l2000_abg >=25)
   OR (l500_abg <25 AND l1000_abg >=25 AND l2000_abg IS NULL)
   OR (l500_abg <25 AND l1000_abg IS NULL AND l2000_abg >=25);

SELECT count(*) FROM data_acbc_ac250to8000_l_bc500to2000_bc2freq_Lincom; -- 3

SELECT 466 + 1050 + 3 AS addition; -- 1519


-----------------------------------------------------------------
-- 5g-4 : Now examine those with INCOMPLETE LEFT BC (bc_lincom)
-----------------------------------------------------------------

-- Right-ear BC exists at ≥2 frequencies
SELECT *
FROM data_acbc_ac250to8000_l_bc_lincom
WHERE
      (bc_r1000t NOTNULL AND bc_r500t NOTNULL)
   OR (bc_r1000t NOTNULL AND bc_r2000t NOTNULL)
   OR (bc_r2000t NOTNULL AND bc_r500t NOTNULL); -- 169

-- Right-ear BC missing at ≥2 frequencies
SELECT *
FROM data_acbc_ac250to8000_l_bc_lincom
WHERE
      (bc_r1000t IS NULL AND bc_r500t IS NULL)
   OR (bc_r1000t IS NULL AND bc_r2000t IS NULL)
   OR (bc_r2000t IS NULL AND bc_r500t IS NULL); -- 109

SELECT 169 + 109; -- 278


------------------------------------------------------------------
-- 5g-5 : Create table using RIGHT BC as proxy for LEFT BC
------------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq;

CREATE TABLE data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
(
  patient_id int,
  audindex smallint,
  investdate date,
  sex varchar,
  age int,
  ac_l250 smallint, ac_l500 smallint, ac_l1000 smallint,
  ac_l2000 smallint, ac_l4000 smallint, ac_l8000 smallint,
  bc_r500 smallint, bc_r1000 smallint, bc_r2000 smallint
);

INSERT INTO data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
(
  patient_id, audindex, investdate, sex, age,
  ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
  bc_r500, bc_r1000, bc_r2000
)
SELECT
  ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
  CASE WHEN ac_l250tm NOTNULL THEN ac_l250tm ELSE ac_l250t END,
  CASE WHEN ac_l500tm NOTNULL THEN ac_l500tm ELSE ac_l500t END,
  CASE WHEN ac_l1000tm NOTNULL THEN ac_l1000tm ELSE ac_l1000t END,
  CASE WHEN ac_l2000tm NOTNULL THEN ac_l2000tm ELSE ac_l2000t END,
  CASE WHEN ac_l4000tm NOTNULL THEN ac_l4000tm ELSE ac_l4000t END,
  CASE WHEN ac_l8000tm NOTNULL THEN ac_l8000tm ELSE ac_l8000t END,
  bc_r500t, bc_r1000t, bc_r2000t
FROM data_acbc_ac250to8000_l_bc_lincom
WHERE
      (bc_r1000t NOTNULL AND bc_r500t NOTNULL)
   OR (bc_r1000t NOTNULL AND bc_r2000t NOTNULL)
   OR (bc_r2000t NOTNULL AND bc_r500t NOTNULL);

SELECT count(*) FROM data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq; -- 169


------------------------------------------------------
-- Add ABGs using RIGHT BC for LEFT ear
------------------------------------------------------

ALTER TABLE data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
ADD COLUMN l500_abg smallint,
ADD COLUMN l1000_abg smallint,
ADD COLUMN l2000_abg smallint;

UPDATE data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
SET
  l500_abg = (ac_l500 - bc_r500),
  l1000_abg = (ac_l1000 - bc_r1000),
  l2000_abg = (ac_l2000 - bc_r2000);


------------------------------------------------------
-- 5g-6 : Categorise left-ear hearing using right BC
------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LSNHL;
CREATE TABLE data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LSNHL AS
SELECT *
FROM data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
WHERE
      (l500_abg <25 AND l1000_abg <25)
   OR (l500_abg <25 AND l2000_abg <25)
   OR (l1000_abg <25 AND l2000_abg <25);

SELECT count(*) FROM data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LSNHL; -- 126


DROP TABLE IF EXISTS data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LCHL;
CREATE TABLE data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LCHL AS
SELECT *
FROM data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
WHERE
      (l500_abg >=25 AND l1000_abg >=25)
   OR (l500_abg >=25 AND l2000_abg >=25)
   OR (l1000_abg >=25 AND l2000_abg >=25);

SELECT count(*) FROM data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LCHL; -- 40


DROP TABLE IF EXISTS data_acbc_ac250to8000_l_bc500to2000_bc2freqr_Lincom;
CREATE TABLE data_acbc_ac250to8000_l_bc500to2000_bc2freqr_Lincom AS
SELECT *
FROM data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
WHERE
      (l500_abg >=25 AND l1000_abg <25 AND l2000_abg IS NULL)
   OR (l500_abg >=25 AND l1000_abg IS NULL AND l2000_abg <25)
   OR (l500_abg IS NULL AND l1000_abg >=25 AND l2000_abg <25)
   OR (l500_abg IS NULL AND l1000_abg <25 AND l2000_abg >=25)
   OR (l500_abg <25 AND l1000_abg >=25 AND l2000_abg IS NULL)
   OR (l500_abg <25 AND l1000_abg IS NULL AND l2000_abg >=25);

SELECT count(*) FROM data_acbc_ac250to8000_l_bc500to2000_bc2freqr_Lincom; -- 3

---------------------------------------------------------------------
------------------------------  STAGE 5h  ----------------------------
--   RIGHT EAR AC-ONLY CASES
--   This stage mirrors Stage 5g (left-only AC) but applies to the 
--   RIGHT ear and follows from Stage 5c. 
---------------------------------------------------------------------


-------------------------------
-- 5h-1 : Counts of right-AC group
-------------------------------
SELECT COUNT(*) FROM data_acbc_ac250to8000_r;           -- 1663
SELECT COUNT(*) FROM data_acbc_ac250to8000_r_bc2freq_r; -- 1431
SELECT COUNT(*) FROM data_acbc_ac250to8000_r_bc_rincom; -- 232


---------------------------------------------------------------------
-- 5h-2 : Create unified AC+BC table for those with complete RIGHT BC
---------------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq;

CREATE TABLE data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
(
  patient_id int,
  audindex smallint,
  investdate date,
  sex varchar,
  age int,
  ac_r250 smallint, ac_r500 smallint, ac_r1000 smallint,
  ac_r2000 smallint, ac_r4000 smallint, ac_r8000 smallint,
  bc_r500 smallint, bc_r1000 smallint, bc_r2000 smallint
);

INSERT INTO data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
(
  patient_id, audindex, investdate, sex, age,
  ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
  bc_r500, bc_r1000, bc_r2000
)
SELECT
  ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
  CASE WHEN ac_r250tm NOTNULL THEN ac_r250tm ELSE ac_r250t END,
  CASE WHEN ac_r500tm NOTNULL THEN ac_r500tm ELSE ac_r500t END,
  CASE WHEN ac_r1000tm NOTNULL THEN ac_r1000tm ELSE ac_r1000t END,
  CASE WHEN ac_r2000tm NOTNULL THEN ac_r2000tm ELSE ac_r2000t END,
  CASE WHEN ac_r4000tm NOTNULL THEN ac_r4000tm ELSE ac_r4000t END,
  CASE WHEN ac_r8000tm NOTNULL THEN ac_r8000tm ELSE ac_r8000t END,
  CASE WHEN bc_r500tm NOTNULL THEN bc_r500tm ELSE bc_r500t END,
  CASE WHEN bc_r1000tm NOTNULL THEN bc_r1000tm ELSE bc_r1000t END,
  CASE WHEN bc_r2000tm NOTNULL THEN bc_r2000tm ELSE bc_r2000t END
FROM data_acbc_ac250to8000_r_bc2freq_r;

SELECT COUNT(*) FROM data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq; -- 1431


------------------------------------------------------
-- Add ABG using unified right BC values
------------------------------------------------------

ALTER TABLE data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
ADD COLUMN r500_abg smallint,
ADD COLUMN r1000_abg smallint,
ADD COLUMN r2000_abg smallint;

UPDATE data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
SET
  r500_abg = ac_r500 - bc_r500,
  r1000_abg = ac_r1000 - bc_r1000,
  r2000_abg = ac_r2000 - bc_r2000;


------------------------------------------------------
-- 5h-3 : Categorise right-ear BC results
------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_r_bc500to2000_bc2freq_rSNHL;
CREATE TABLE data_acbc_ac250to8000_r_bc500to2000_bc2freq_rSNHL AS
SELECT *
FROM data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
WHERE
      (r500_abg <25 AND r1000_abg <25)
   OR (r500_abg <25 AND r2000_abg <25)
   OR (r1000_abg <25 AND r2000_abg <25);

SELECT COUNT(*) FROM data_acbc_ac250to8000_r_bc500to2000_bc2freq_rSNHL; -- 959


DROP TABLE IF EXISTS data_acbc_ac250to8000_r_bc500to2000_bc2freq_RCHL;
CREATE TABLE data_acbc_ac250to8000_r_bc500to2000_bc2freq_RCHL AS
SELECT *
FROM data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
WHERE
      (r500_abg >=25 AND r1000_abg >=25)
   OR (r500_abg >=25 AND r2000_abg >=25)
   OR (r1000_abg >=25 AND r2000_abg >=25);

SELECT COUNT(*) FROM data_acbc_ac250to8000_r_bc500to2000_bc2freq_RCHL; -- 469


-- Incomplete patterns (1-frequency)
DROP TABLE IF EXISTS data_acbc_ac250to8000_r_bc500to2000_bc2freq_Rincomp;
CREATE TABLE data_acbc_ac250to8000_r_bc500to2000_bc2freq_Rincomp AS
SELECT *
FROM data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
WHERE
      (r500_abg >=25 AND r1000_abg <25 AND r2000_abg IS NULL)
   OR (r500_abg >=25 AND r1000_abg IS NULL AND r2000_abg <25)
   OR (r500_abg IS NULL AND r1000_abg >=25 AND r2000_abg <25)
   OR (r500_abg IS NULL AND r1000_abg <25 AND r2000_abg >=25)
   OR (r500_abg <25 AND r1000_abg >=25 AND r2000_abg IS NULL)
   OR (r500_abg <25 AND r1000_abg IS NULL AND r2000_abg >=25);

SELECT COUNT(*) FROM data_acbc_ac250to8000_r_bc500to2000_bc2freq_Rincomp; -- 3

SELECT 469 + 959 + 3 AS addition; -- 1428


-----------------------------------------------------------------
-- 5h-4 : Examine incomplete RIGHT BC (r_bc_rincom)
-----------------------------------------------------------------

-- Left BC available at ≥2 frequencies
SELECT *
FROM data_acbc_ac250to8000_r_bc_rincom
WHERE
      (bc_l1000t NOTNULL AND bc_l500t NOTNULL)
   OR (bc_l1000t NOTNULL AND bc_l2000t NOTNULL)
   OR (bc_l2000t NOTNULL AND bc_l500t NOTNULL); -- 120

-- Left BC missing ≥2 frequencies
SELECT *
FROM data_acbc_ac250to8000_r_bc_rincom
WHERE
      (bc_l1000t IS NULL AND bc_l500t IS NULL)
   OR (bc_l1000t IS NULL AND bc_l2000t IS NULL)
   OR (bc_l2000t IS NULL AND bc_l500t IS NULL); -- 112


------------------------------------------------------------------
-- 5h-5 : Create table using LEFT BC as proxy for RIGHT BC
------------------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq;

CREATE TABLE data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
(
  patient_id int,
  audindex smallint,
  investdate date,
  sex varchar,
  age int,
  ac_r250 smallint, ac_r500 smallint, ac_r1000 smallint,
  ac_r2000 smallint, ac_r4000 smallint, ac_r8000 smallint,
  bc_l500 smallint, bc_l1000 smallint, bc_l2000 smallint
);

INSERT INTO data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
(
  patient_id, audindex, investdate, sex, age,
  ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
  bc_l500, bc_l1000, bc_l2000
)
SELECT
  ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
  CASE WHEN ac_r250tm NOTNULL THEN ac_r250tm ELSE ac_r250t END,
  CASE WHEN ac_r500tm NOTNULL THEN ac_r500tm ELSE ac_r500t END,
  CASE WHEN ac_r1000tm NOTNULL THEN ac_r1000tm ELSE ac_r1000t END,
  CASE WHEN ac_r2000tm NOTNULL THEN ac_r2000tm ELSE ac_r2000t END,
  CASE WHEN ac_r4000tm NOTNULL THEN ac_r4000tm ELSE ac_r4000t END,
  CASE WHEN ac_r8000tm NOTNULL THEN ac_r8000tm ELSE ac_r8000t END,
  bc_l500t, bc_l1000t, bc_l2000t
FROM data_acbc_ac250to8000_r_bc_rincom
WHERE
      (bc_l1000t NOTNULL AND bc_l500t NOTNULL)
   OR (bc_l1000t NOTNULL AND bc_l2000t NOTNULL)
   OR (bc_l2000t NOTNULL AND bc_l500t NOTNULL);

SELECT COUNT(*) FROM data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq; -- 120


------------------------------------------------------
-- Add ABGs using LEFT BC for RIGHT ear
------------------------------------------------------

ALTER TABLE data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
ADD COLUMN r500_abg smallint,
ADD COLUMN r1000_abg smallint,
ADD COLUMN r2000_abg smallint;

UPDATE data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
SET
  r500_abg = ac_r500 - bc_l500,
  r1000_abg = ac_r1000 - bc_l1000,
  r2000_abg = ac_r2000 - bc_l2000;


------------------------------------------------------
-- 5h-6 : Categorise RIGHT-ear hearing using left BC
------------------------------------------------------

DROP TABLE IF EXISTS data_acbc_ac250to8000_r_bc500to2000_bc2freql_rSNHL;
CREATE TABLE data_acbc_ac250to8000_r_bc500to2000_bc2freql_rSNHL AS
SELECT *
FROM data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
WHERE
      (r500_abg <25 AND r1000_abg <25)
   OR (r500_abg <25 AND r2000_abg <25)
   OR (r1000_abg <25 AND r2000_abg <25);

SELECT COUNT(*) FROM data_acbc_ac250to8000_r_bc500to2000_bc2freql_rSNHL; -- 95


DROP TABLE IF EXISTS data_acbc_ac250to8000_r_bc500to2000_bc2freql_rCHL;
CREATE TABLE data_acbc_ac250to8000_r_bc500to2000_bc2freql_rCHL AS
SELECT *
FROM data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
WHERE
      (r500_abg >=25 AND r1000_abg >=25)
   OR (r500_abg >=25 AND r2000_abg >=25)
   OR (r1000_abg >=25 AND r2000_abg >=25);

SELECT COUNT(*) FROM data_acbc_ac250to8000_r_bc500to2000_bc2freql_rCHL; -- 24


DROP TABLE IF EXISTS data_acbc_ac250to8000_r_bc500to2000_bc2freql_rincom;
CREATE TABLE data_acbc_ac250to8000_r_bc500to2000_bc2freql_rincom AS
SELECT *
FROM data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
WHERE
      (r500_abg >=25 AND r1000_abg <25 AND r2000_abg IS NULL)
   OR (r500_abg >=25 AND r1000_abg IS NULL AND r2000_abg <25)
   OR (r500_abg IS NULL AND r1000_abg >=25 AND r2000_abg <25)
   OR (r500_abg IS NULL AND r1000_abg <25 AND r2000_abg >=25)
   OR (r500_abg <25 AND r1000_abg >=25 AND r2000_abg IS NULL)
   OR (r500_abg <25 AND r1000_abg IS NULL AND r2000_abg >=25);

SELECT COUNT(*) FROM data_acbc_ac250to8000_r_bc500to2000_bc2freql_rincom; -- 1


-- Left BC missing at ≥2 frequencies
SELECT *
FROM data_acbc_ac250to8000_r_bc_rincom
WHERE
      (bc_l1000t IS NULL AND bc_l500t IS NULL)
   OR (bc_l1000t IS NULL AND bc_l2000t IS NULL)
   OR (bc_l2000t IS NULL AND bc_l500t IS NULL); --112

-- ====================================================
-- STAGE 6: BUILD FINAL SNHL TABLE
-- ====================================================

DROP TABLE IF EXISTS snhl;

CREATE TABLE SNHL
(
    patient_id INT,
    audindex SMALLINT,
    investdate DATE,
    sex VARCHAR,
    age INT,
    ac_l250 SMALLINT,
    ac_l500 SMALLINT,
    ac_l1000 SMALLINT,
    ac_l2000 SMALLINT,
    ac_l4000 SMALLINT,
    ac_l8000 SMALLINT,
    ac_r250 SMALLINT,
    ac_r500 SMALLINT,
    ac_r1000 SMALLINT,
    ac_r2000 SMALLINT,
    ac_r4000 SMALLINT,
    ac_r8000 SMALLINT
);

-- ====================================================
-- 6.1 AC ONLY: BILATERAL, LEFT-ONLY, RIGHT-ONLY
-- ====================================================

-- 6.1.1 Insert bilateral AC-only records (L + R AC) = 41,655

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    l250, l500, l1000, l2000, l4000, l8000,
    r250, r500, r1000, r2000, r4000, r8000
FROM data_ac_bl;

SELECT COUNT(*) FROM SNHL;    -- 41522


-- 6.1.2 Insert left-only AC records = 1,746

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    l250, l500, l1000, l2000, l4000, l8000
FROM data_ac_l;

SELECT 1746 + 41522 AS addition;   -- 43268
SELECT COUNT(*) FROM SNHL;         -- 43268


-- 6.1.3 Insert right-only AC records = 1,600

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    r250, r500, r1000, r2000, r4000, r8000
FROM data_ac_r;

SELECT 43268 + 1600 AS addition;   -- 44868
SELECT COUNT(*) FROM snhl;         -- 44868


-- ====================================================
-- 6.2 LEFT-ONLY AC COMPLETE WITH JOINED BC
-- ====================================================

-- Now consider those with a join but only AC complete for left = 1799

-- 6.2.1 L SNHL where left BC done = 1050

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_l_bc500to2000_bc2freq_LSNHL;

SELECT 44868 + 1050 AS addition;   -- 45918
SELECT COUNT(*) FROM snhl;         -- 45918


-- 6.2.2 Left incomplete where left BC done = 3

SELECT * FROM data_acbc_ac250to8000_l_bc500to2000_bc2freq_Lincom;

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_l_bc500to2000_bc2freq_Lincom;

SELECT COUNT(*) FROM snhl;         -- 45921 (45918 + 3)


-- 6.2.3 L SNHL where BC was done on right (used as proxy) = 126

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LSNHL;

SELECT 45921 + 126 AS addition;    -- 46047
SELECT COUNT(*) FROM snhl;         -- 46047


-- 6.2.4 Left incomplete where BC was done on right = 3

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_l_bc500to2000_bc2freqr_Lincom;

SELECT COUNT(*) FROM snhl;         -- 46050 = 46407 + 3 (comment from original)


-- ====================================================
-- 6.3 RIGHT-ONLY AC COMPLETE WITH JOINED BC
-- ====================================================

-- Now consider those with a join but only AC complete for right = 1671

-- 6.3.1 R SNHL where right BC done = 959

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_r_bc500to2000_bc2freq_rSNHL;

SELECT 46050 + 959 AS addition;    -- 47009
SELECT COUNT(*) FROM snhl;         -- 47009


-- 6.3.2 Right incomplete where right BC done = 3

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_r_bc500to2000_bc2freq_Rincomp;

SELECT COUNT(*) FROM snhl;         -- 47012 (47009 + 3)


-- 6.3.3 R SNHL where BC was done on left (used as proxy) = 95

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_r_bc500to2000_bc2freql_rSNHL;

SELECT 47012 + 95 AS addition;     -- 47107
SELECT COUNT(*) FROM snhl;         -- 47107


-- 6.3.4 Right incomplete where BC was done on left = 1

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_r_bc500to2000_bc2freql_rincom;

SELECT COUNT(*) FROM snhl;         -- 47108


-- ====================================================
-- 6.4 BILATERAL AC WITH BC (NO ABG ON EITHER SIDE)
-- ====================================================

-- 6.4.1 Insert L + R with SNHL but no ABG (both sides SNHL pattern) = 17,441

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg;

SELECT 17441 + 47108 AS addition;  -- 64549
SELECT COUNT(*) FROM snhl;         -- 64549


-- 6.4.2 Insert L + R with L SNHL and R incomplete = 75

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqr;

SELECT 64549 + 75 AS addition;     -- 64624
SELECT COUNT(*) FROM snhl;         -- 64624


-- 6.4.3 Insert L + R with R SNHL and L incomplete = 59

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r_1freql;

SELECT 64624 + 59 AS addition;     -- 64683
SELECT COUNT(*) FROM snhl;         -- 64683


-- 6.4.4 Insert L + R with L + R incomplete = 11

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqbl;

SELECT COUNT(*) FROM snhl;         -- 64694 (64683 + 11)


-- ====================================================
-- 6.5 BILATERAL AC WITH BC (LEFT-ONLY BC BRANCH)
-- ====================================================

-- 6.5.1 Insert left-only with L SNHL and R CHL = 3328

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l;

SELECT 64694 + 3328 AS addition;   -- 68022
SELECT COUNT(*) FROM snhl;         -- 68022


-- 6.5.2 Insert left-only with L incomplete and R CHL = 35

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_abg_r_1freql;

SELECT 68022 + 35 AS addition;     -- 68057
SELECT COUNT(*) FROM snhl;         -- 68057


-- 6.5.3 Insert right-only with R SNHL and L CHL = 3130

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r;

SELECT 68057 + 3130 AS addition;   -- 71187
SELECT COUNT(*) FROM snhl;         -- 71187


-- 6.5.4 Insert right-only with R incomplete and L CHL = 40

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc500to2000_bl_abg_l_1freqr;

SELECT 71187 + 40 AS addition;     -- 71227
SELECT COUNT(*) FROM snhl;         -- 71227


-- ====================================================
-- 6.6 BILATERAL AC WITH BC (LEFT-ONLY BC: tm NOT NULL / NULL)
-- ====================================================

-- AC BL BC L total = 39711

-- 6.6.1 BC L only, tm NOT NULL and t NULL = L SNHL = 6284

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LSNHL;

SELECT 71227 + 6284 AS addition;   -- 77511
SELECT COUNT(*) FROM snhl;         -- 77511


-- 6.6.2 BC L only, tm NOT NULL and t NULL = L incomplete = 384

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_l1freq;

SELECT 77511 + 384 AS addition;    -- 77895
SELECT COUNT(*) FROM snhl;         -- 77895


-- 6.6.3 BC L only, tm NOT NULL and t NOT NULL = L SNHL, R CHL = 87

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LSNHL;

SELECT 77895 + 87 AS addition;     -- 77982
SELECT COUNT(*) FROM snhl;         -- 77982


-- 6.6.4 BC L only, tm NOT NULL and t NOT NULL = L incomplete, R CHL = 16  (table cc)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM cc;

SELECT 77982 + 16 AS addition;     -- 77998
SELECT COUNT(*) FROM snhl;         -- 77998


-- 6.6.5 BC L only, tm NOT NULL and t NOT NULL = L CHL, R SNHL = 1471

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_RSNHL;

SELECT 77998 + 1471 AS addition;   -- 79469
SELECT COUNT(*) FROM snhl;         -- 79469


-- 6.6.6 BC L only, tm NOT NULL and t NOT NULL = L CHL, R incomplete = 5 (table bb)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM bb;

SELECT 79469 + 5 AS addition;      -- 79474
SELECT COUNT(*) FROM snhl;         -- 79474


-- 6.6.7 BC L only, tm NOT NULL and t NOT NULL = L + R SNHL = 3551

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRSNHL;

SELECT 3551 + 79474 AS addition;   -- 83025
SELECT COUNT(*) FROM snhl;         -- 83025


-- 6.6.8 BC L only, tm NOT NULL and t NOT NULL = L + R incomplete = 3 (table aa)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM aa;

SELECT 83025 + 3 AS addition;      -- 83028
SELECT COUNT(*) FROM snhl;         -- 83028


-- 6.6.9 BC L only, tm NOT NULL and t NOT NULL = L SNHL + R incomplete = 3 (table b)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM b;

SELECT 83028 + 3 AS addition;      -- 83031
SELECT COUNT(*) FROM snhl;         -- 83031


-- 6.6.10 BC L only, tm NULL, t NOT NULL = L + R SNHL = 20808

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LRSNHL;

SELECT 83031 + 20808 AS addition;  -- 103839
SELECT COUNT(*) FROM snhl;         -- 103839


-- 6.6.11 BC L only, tm NULL, t NOT NULL = L + R incomplete = 47 (table aaa)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM aaa;

SELECT 103839 + 47 AS addition;    -- 103886
SELECT COUNT(*) FROM snhl;         -- 103886


-- 6.6.12 BC L only, tm NULL, t NOT NULL = L incomplete + R SNHL = 72 (table e)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM e;

SELECT 103886 + 72 AS addition;    -- 103958
SELECT COUNT(*) FROM snhl;         -- 103958


-- 6.6.13 BC L only, tm NULL, t NOT NULL = R incomplete + L SNHL = 35 (table d)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM d;

SELECT 103958 + 35 AS addition;    -- 103993
SELECT COUNT(*) FROM snhl;         -- 103993


-- 6.6.14 BC L only, tm NULL, t NOT NULL = R CHL + L SNHL = 1081

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LSNHL;

SELECT 103993 + 1081 AS addition;  -- 105074
SELECT COUNT(*) FROM snhl;         -- 105074


-- 6.6.15 BC L only, tm NULL, t NOT NULL = R CHL + L incomplete = 16 (table ee)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM ee;

SELECT 105074 + 16 AS addition;    -- 105090
SELECT COUNT(*) FROM snhl;         -- 105090


-- 6.6.16 BC L only, tm NULL, t NOT NULL = R SNHL + L CHL = 608

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RSNHL;

SELECT 105090 + 608 AS addition;   -- 105698
SELECT COUNT(*) FROM snhl;         -- 105698


-- 6.6.17 BC L only, tm NULL, t NOT NULL = R incomplete + L CHL = 16 (table dd)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM dd;

SELECT 105698 + 16 AS addition;    -- 105714
SELECT COUNT(*) FROM snhl;         -- 105714


-- ====================================================
-- 6.7 BILATERAL AC WITH BC (RIGHT-ONLY BC BRANCH)
-- ====================================================

-- AC BL BC R total = 43106

-- 6.7.1 BC R only, tm NOT NULL and t NULL = R SNHL = 6272

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rSNHL;

SELECT 105714 + 6272 AS addition;  -- 111986
SELECT COUNT(*) FROM snhl;         -- 111986


-- 6.7.2 BC R only, tm NOT NULL and t NULL = R incomplete = 388

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_r1freq;

SELECT 111986 + 388 AS addition;   -- 112374
SELECT COUNT(*) FROM snhl;         -- 112374


-- 6.7.3 BC R only, tm NOT NULL and t NOT NULL = R SNHL, L CHL = 5

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_rSNHL;

SELECT 5 + 112374 AS addition;     -- 112379
SELECT COUNT(*) FROM snhl;         -- 112379


-- 6.7.4 BC R only, tm NOT NULL and t NOT NULL = R incomplete, L CHL = 2 (table gg)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM gg;

SELECT COUNT(*) FROM snhl;         -- 112381


-- 6.7.5 BC R only, tm NOT NULL and t NOT NULL = L SNHL, R CHL = 3138

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_lSNHL;

SELECT 3138 + 112381 AS addition;  -- 115519
SELECT COUNT(*) FROM snhl;         -- 115519


-- 6.7.6 BC R only, tm NOT NULL and t NOT NULL = L incomplete, R CHL = 43 (table hh)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM hh;

SELECT 115519 + 43 AS addition;    -- 115562
SELECT COUNT(*) FROM snhl;         -- 115562


-- 6.7.7 BC R only, tm NOT NULL and t NOT NULL = L + R SNHL = 1808

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRSNHL;

SELECT 115562 + 1808 AS addition;  -- 117370
SELECT COUNT(*) FROM snhl;         -- 117370


-- 6.7.8 BC R only, tm NOT NULL and t NOT NULL = L + R incomplete = 1 (table fff)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM fff;

SELECT COUNT(*) FROM snhl;         -- 117371


-- 6.7.9 BC R only, tm NOT NULL and t NOT NULL = L SNHL + R incomplete = 53 (table G)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM G;

SELECT 117371 + 53 AS addition;    -- 117424
SELECT COUNT(*) FROM snhl;         -- 117424


-- 6.7.10 BC R only, tm NOT NULL and t NOT NULL = L incomplete + R SNHL = 20 (table h)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM h;

SELECT 117424 + 20 AS addition;    -- 117444
SELECT COUNT(*) FROM snhl;         -- 117444


-- 6.7.11 BC R only, tm NULL, t NOT NULL = L + R SNHL = 23445

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_LRSNHL;

SELECT 117444 + 23445 AS addition; -- 140889
SELECT COUNT(*) FROM snhl;         -- 140889


-- 6.7.12 BC R only, tm NULL, t NOT NULL = L + R incomplete = 33 (table iii)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM iii;

SELECT 140889 + 33 AS addition;    -- 140922
SELECT COUNT(*) FROM snhl;         -- 140922


-- 6.7.13 BC R only, tm NULL, t NOT NULL = L SNHL + R incomplete = 94 (table i)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM i;

SELECT 140922 + 94 AS addition;    -- 141016
SELECT COUNT(*) FROM snhl;         -- 141016


-- 6.7.14 BC R only, tm NULL, t NOT NULL = L incomplete + R SNHL = 39 (table j)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM j;

SELECT 141016 + 39 AS addition;    -- 141055
SELECT COUNT(*) FROM snhl;         -- 141055


-- 6.7.15 BC R only, tm NULL, t NOT NULL = R SNHL + L CHL = 1200

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_rSNHL;

SELECT 141055 + 1200 AS addition;  -- 142255
SELECT COUNT(*) FROM snhl;         -- 142255


-- 6.7.16 BC R only, tm NULL, t NOT NULL = R incomplete + L CHL = 14 (table ii)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_r250, ac_r500, ac_r1000, ac_r2000, ac_r4000, ac_r8000
FROM ii;

SELECT 142255 + 14 AS addition;    -- 142269
SELECT COUNT(*) FROM snhl;         -- 142269


-- 6.7.17 BC R only, tm NULL, t NOT NULL = R CHL + L SNHL = 753

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM data_acbc_ac250to8000_bl_bc2freq_r_tm_null_lSNHL;

SELECT 142269 + 753 AS addition;   -- 143022
SELECT COUNT(*) FROM snhl;         -- 143022


-- 6.7.18 BC R only, tm NULL, t NOT NULL = R CHL + L incomplete = 7 (table jj)

INSERT INTO SNHL
(
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
)
SELECT
    patient_id, audindex, investdate, sex, age,
    ac_l250, ac_l500, ac_l1000, ac_l2000, ac_l4000, ac_l8000
FROM jj;

SELECT 143022 + 7 AS addition;     -- 143029
SELECT COUNT(*) FROM snhl;         -- 143029


-- ====================================================
-- 6.8 FINAL AC DATASET FOR KIDS AND ADULTS
-- ====================================================

SELECT COUNT(*) FROM snhl;         -- 143029

SELECT COUNT(*)
FROM (SELECT DISTINCT * FROM snhl) l;   -- 143029

----------------- FINAL AC DATASET FOR ADULTS

select count(*) from snhl where age >=18; --125991

-- ----------------------------------------------------
-- 6.9 Create adults-only SNHL table
-- ----------------------------------------------------

DROP TABLE IF EXISTS snhl_adults;

CREATE TABLE snhl_adults AS
SELECT *
FROM snhl
WHERE age >= 18;

SELECT COUNT(*) FROM snhl_adults;
SELECT * FROM snhl_adults;


-- ----------------------------------------------------
-- 6.10 Identify adults with COMPLETE BILATERAL AC (BL SNHL candidates)
-- ----------------------------------------------------

DROP TABLE IF EXISTS snhl_adults_bl;

CREATE TABLE snhl_adults_bl AS
SELECT *
FROM snhl_adults
WHERE 
    ac_l250  NOTNULL AND ac_l500  NOTNULL AND ac_l1000 NOTNULL AND 
    ac_l2000 NOTNULL AND ac_l4000 NOTNULL AND ac_l8000 NOTNULL AND
    ac_r250  NOTNULL AND ac_r500  NOTNULL AND ac_r1000 NOTNULL AND 
    ac_r2000 NOTNULL AND ac_r4000 NOTNULL AND ac_r8000 NOTNULL;

SELECT COUNT(*) FROM snhl_adults_bl;   -- 95253


-- ----------------------------------------------------
-- 6.11 Add side label (BL_RIGHT)
-- ----------------------------------------------------

ALTER TABLE snhl_adults_bl
    ADD COLUMN side VARCHAR;

UPDATE snhl_adults_bl
SET side = 'bl_right';

SELECT * FROM snhl_adults_bl;



