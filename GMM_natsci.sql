/*Complete SQL Code for dataset generation */

  set search_path to hic_hh


-- PRE-STAGES
--Check how many duplicates -


select count(*) from hic_hh.ab_audiogramcurve; --417478 

-- check what curves there are 
select distinct(curve) from ab_audiogramcurve; 

--40, 43, 48, 1, 2, 10, 41, 11, 20, 30, 4, 49, 13, 50, 0

-- we are only interested in audiogram curves 0 (AC) and BC (10) so we create table audio_val 

drop table if exists audio_val;

  CREATE TABLE audio_val AS
SELECT 
  curve, patient_id, audindex, investdate,
  l250t, l250tm,
  l500t, l500tm,
  l1000t, l1000tm,
  l2000t, l2000tm,
  l4000t, l4000tm,
  l8000t, l8000tm,
  r250t, r250tm,
  r500t, r500tm,
  r1000t, r1000tm,
  r2000t, r2000tm,
  r4000t, r4000tm,
  r8000t, r8000tm,
  FROM audiogram_values where curve = 0 or curve = 10;

select count(*) from audio_val; --349060 


Select distinct count (*) from audio_val; -- 349060 same as above - no duplicates it seems but this query is wrong!

/*DISTINCT COUNT(*) will return a row for each unique count. What you want is COUNT(DISTINCT <expression>): 
  evaluates expression for each row in a group and returns the number of unique, non-null values.*/

select count (distinct audio_val.*) from audio_val; --348851
select count (*) from (select distinct * from audio_val)x; --348851

-- make non-duplicate table that is essentially a copy - there are no duplicates to remove!
Drop table if exists audio_val_nodup;
Create table audio_val_nodup as (select distinct * from audio_val);

Select count (*) from audio_val_nodup; --348851

--	Link the audio values table with the patient table so that there is both sex and dateofbirth on there
-- i don’t add age here as we change date of births and this is how age is calculated remember 

drop table if exists audio_val_nodups;
create table audio_val_nodups as (SELECT ad.patient_id, ad.investdate, ad.audindex, ad.curve,  pat.sex, pat.dateofbirth,
 ad.l250t, ad.l250tm,
  ad.l500t,   ad.l500tm,
    ad.l1000t,   ad.l1000tm,
    ad.l2000t,   ad.l2000tm,
    ad.l4000t,   ad.l4000tm,
    ad.l8000t,   ad.l8000tm,
    ad.r250t,   ad.r250tm,
    ad.r500t,   ad.r500tm,
    ad.r1000t,   ad.r1000tm,
    ad.r2000t,   ad.r2000tm,
    ad.r4000t,   ad.r4000tm,
   ad.r8000t,   ad.r8000tm
from
audio_val_nodup as ad left join ab_patient as pat on
ad.patient_id = pat.patient_id);

select count(*) from hic_hh.audio_val_nodups; #348851 

--3.	Check sex status of these records

select distinct sex from audio_val_nodups; --this will give me a list of all values for the sex column
--(null), ,  U, S, Y, C, O, M, F, B, P

select count(*)  from audio_val_nodups where sex isnull; --18350
select count(*)  from audio_val_nodups where sex = ' ';  --6
select count(*)  from audio_val_nodups where sex = 'U';  --48
select count(*)  from audio_val_nodups where sex = 'S';  --27
select count(*)  from audio_val_nodups where sex = 'Y';  --2
select count(*)  from audio_val_nodups where sex = 'C';  --6
select count(*)  from audio_val_nodups where sex = 'O';  --8
select count(*)  from audio_val_nodups where sex = 'M';  --151670
select count(*)  from audio_val_nodups where sex = 'F';  --178730
select count(*)  from audio_val_nodups where sex = 'B';  --2
select count(*)  from audio_val_nodups where sex = 'P';  --2

select 18350 + 6 + 48 + 27 +2 +6 + 8 + 151670 + 178730 + 4 as "Addition"; --348851
select 151670 + 178730 as "Addition"; --330400 who are male or female on audibase 
select 18350 + 6 + 48 + 27 +2 +6 + 8 + 4 as "Addition"; --18451 who are non-sensible values

-- #########join tables to cross-check sex

-- zz_lookup_patient_cab patient_id matches to patient_id from auditbase 
-- patient_id from lookup matches to subject_id from caboodle
-- caboodle stores the demographic details

drop table if exists audio_val_sex_checked;
create table audio_val_sex_checked as 
  (select
ads.patient_id patient_id_from_dataset,
lp.subject_id subject_id_from_lookup_table,
cd.gender code_from_caboodle_demographics,
case cd.gender
  when 1 then 'Male'
  when 2 then 'Female'
  when 9 then 'Not Specified'
  else null
end text_value_of_caboodle_code
from hic_hh. audio_val_nodups ads
left join hic_hh.zz_lookup_patient_cab  lp on ads.patient_id = lp.patient_id
left join hic_hh.cab_demographics cd on lp.subject_id = cd.subject_id
  where ads.sex is null or ads.sex like ' %' or ads.sex = 'S' or
ads.sex = 'U' or ads.sex = 'P' or ads.sex = 'C' or ads.sex = 'O');

select count(*) from audio_val_sex_checked; --18448


select * from audio_val_sex_checked; --this contains patient_id from auditbase, s_id from lookup and code/text for sex from caboodle

-- now remember some of these checked ones have null values in caboodle.
--first check what values the sex column can have 
select distinct text_value_of_caboodle_code from audio_val_sex_checked; --Female, null, Male
select count(*) from audio_val_sex_checked  where code_from_caboodle_demographics isnull; 14776

select count(*) from audio_val_sex_checked  where text_value_of_caboodle_code isnull; #14776

--all the cross-checked sex can be found in the megadataset table where has not been corectly completed

-- here we select all the count of all records where the patient_id from the checked table are also in the 
-- megadataset with nonsensical values

select count(*) from 
(select patient_id_from_dataset from audio_val_sex_checked where patient_id_from_dataset in 
(select patient_id from audio_val_nodups where 
sex isnull or sex = 'P' or sex = 'C' or sex = 'O' or  sex = 'U' or sex = 'S' or sex = ' '
or sex = 'Y' or sex = 'B'))lily; #18448

--now just the distinct patients as there are duplicates 
select  count(distinct patient_id_from_dataset) from audio_val_sex_checked where patient_id_from_dataset in 
(select patient_id from audio_val_nodups where sex isnull or sex = 'P' or sex = 'C' or sex = 'O' or  sex = 'U' or sex = 'S' or sex = ' '
or sex = 'Y' or sex = 'B'); 6638





--then look to see how many of these new records are male/female

--how many of the incorrect records are female but remember there are duplicates!
select count(*) from audio_val_sex_checked where patient_id_from_dataset in 
(select patient_id from audio_val_nodups where 
sex isnull or sex = 'P' or sex = 'C' or sex = 'O' or  sex = 'U' or sex = 'S' or sex like ' %'
or sex = 'Y' or sex = 'B') 
and text_value_of_caboodle_code = 'Female'; # 2060records

--how many of the incorrect records belong to distinct female 
select count(distinct patient_id_from_dataset) from audio_val_sex_checked where patient_id_from_dataset in 
(select patient_id from audio_val_nodups where 
 sex isnull or sex = 'P' or sex = 'C' or sex = 'O' or  sex = 'U' or sex = 'S' or sex like ' %'
or sex = 'Y' or sex = 'B' ) 
and text_value_of_caboodle_code = 'Female'; #694

--how many of the incorrect records are male but remember there are duplicates!
select count(*) from audio_val_sex_checked where patient_id_from_dataset in 
(select patient_id from audio_val_nodups where 
 sex isnull or sex = 'P' or sex = 'C' or sex = 'O' or  sex = 'U' or sex = 'S' or sex like ' %'
or sex = 'Y' or sex = 'B')
 and text_value_of_caboodle_code = 'Male'; #1612


--see how many have previously wrong or null sex – should be zero 
select count(*) from audio_val_sex_checked where patient_id_from_dataset in 
(select patient_id from audio_val_nodups where 
sex isnull or sex = 'P' or sex = 'C' or sex = 'O' or  sex = 'U' or sex = 'S' or sex like ' %'
or sex = 'Y' or sex = 'B') 
and text_value_of_caboodle_code = 'Not Specified'; #0

--now what about all of those where the caboodle code is null still


select count(*) from audio_val_sex_checked where patient_id_from_dataset in 
(select patient_id from audio_val_nodups where 
 sex isnull or sex = 'P' or sex = 'C' or sex = 'O' or  sex = 'U' or sex = 'S' or sex like ' %'
or sex = 'Y' or sex = 'B') and text_value_of_caboodle_code isnull; --14776

select 14776 + 1612 + 2060 as "Addition"; --18448

--lets check the count of these now - should be 3672 (1598 + 2047)
select count(*) from (select patient_id_from_dataset, text_value_of_caboodle_code from audio_val_sex_checked where
  patient_id_from_dataset in 
(select patient_id from audio_val_nodups  where 
 sex isnull or sex = 'P' or sex = 'C' or sex = 'O' or  sex = 'U' or sex = 'S' or sex like ' %'
or sex = 'Y' or sex = 'B'  ) and text_value_of_caboodle_code = 'Female' or text_value_of_caboodle_code = 'Male')lil ; #3672


--copy the table and amend this to replace the incorrect sex with correct sex
drop table if exists audio_val_nodups_sex;
create table audio_val_nodups_sex as SELECT * from audio_val_nodups;


--# #confirm correct number of records
select count(*) from audio_val_nodups_sex; #348851

--# now do update command so that the sex column is updated with the new values found from the new table 
UPDATE  audio_val_nodups_sex
SET sex = text_value_of_caboodle_code
FROM audio_val_sex_checked
WHERE audio_val_sex_checked.patient_id_from_dataset = audio_val_nodups_sex.patient_id
;

--####now lets check how many records dont have sex filled out now
select count (*) from audio_val_nodups where sex 
 isnull or sex = 'P' or sex = 'C' or sex = 'O' or  sex = 'U' or sex = 'S' or sex like ' %'
or sex = 'Y' or sex = 'B'   ; -- 18451 is the old count

select count (*) from audio_val_nodups_sex where 
  sex isnull or sex = 'P' or sex = 'C' or sex = 'O' or  sex = 'U' or sex = 'S' or sex like ' %'
or sex = 'Y' or sex = 'B'  ; -- 14780 is the new count (18451 - 3672 - should be 14779)


--now check the values I have for sex
select distinct sex from audio_val_nodups_sex; -- null, Female M, F, B, Y, Male
-- note there are fewer letters here now that we have replace with the correct sex label.

-- #### now lets make all females F and males M

update audio_val_nodups_sex
set sex = 'F' 
WHERE sex = 'Female';

update audio_val_nodups_sex
set sex = 'M' 
WHERE sex = 'Male';

--check this has now worked
select distinct sex from audio_val_nodups_sex; --(null), M, F, B, Y  

--check the new numbers

select count(*)  from audio_val_nodups_sex where sex isnull; --14776 
select count(*)  from audio_val_nodups_sex where sex like ' %'; --0
select count(*)  from audio_val_nodups_sex where sex = 'S'; --0
select count(*)  from audio_val_nodups_sex where sex = 'U'; --0
select count(*)  from audio_val_nodups_sex where sex = 'P'; --0
select count(*)  from audio_val_nodups_sex where sex = 'C'; --0
select count(*)  from audio_val_nodups_sex where sex = 'O'; --8
select count(*)  from audio_val_nodups_sex where sex = 'M'; --153281 (151670: diff 1611) 
select count(*)  from audio_val_nodups_sex where sex = 'F'; --180790 (178730: diff 2060)
select count(*)  from audio_val_nodups_sex where sex = 'B'; --2
select count(*)  from audio_val_nodups_sex where sex = 'Y'; --2

select  14776  + 153281  + 180790 +4  as "Addition"; --348851

select  153281  + 180790  as "Addition"; -- 334071


--now make new table with just records with completed sex 

drop table if exists audio_val_nodups_sexed;
create table audio_val_nodups_sexed as select * from audio_val_nodups_sex where sex = 'F' or sex = 'M';

select * from audio_val_nodups_sex; --334071

------------------------------------------Subsetting for patients with complete DOB



-- see what date of birth colum is named
  select * from audio_val_nodups_sexed limit 100; --dateofbirth is field for DOB

--see how many dob fields are null - this not that helpful as there are patients with incorrectly completed dob
  select count(*) from  audio_val_nodups_sexed where dateofbirth ISNULL; --1878 

--find oldest and youngest patients

  select MIN(dateofbirth) from audio_val_nodups_sexed; 
select MAX(dateofbirth) from audio_val_nodups_sexed;

select * from audio_val_nodups_sexed order by dateofbirth asc ;

--how many records with birthdates before 1901
select * from audio_val_nodups_sexed where dateofbirth < '01/01/1901'; --25

-- records with birthdates 01/01/1901
select * from audio_val_nodups_sexed where dateofbirth = '01/01/1901'; -- 54

---now the question is should we bother matching to caboodle and ADS? I dont think so. 

  - we can just see if the null values are in the table or not. 

   --find all the patients where the null dateorbirth patient_id are in the lookup table cab


   
--check count of the dataset

select count(*) FROM hic_hh.audio_val_nodups_sexed ab; --334071

-- single join only using left 

select count(*) from (select ab.* 
    FROM hic_hh.audio_val_nodups_sexed ab
left JOIN hic_hh.zz_lookup_patient_cab 
  ON ab.patient_id = hic_hh.zz_lookup_patient_cab.patient_id)lil; --334195 

--there are 124 more records which implies there are duplicates in the lookup table

drop view if exists zz_lookup_patient_cab_dup;
create view zz_lookup_patient_cab_dup 
  as
(select patient_id, count(*) as freq from 
zz_lookup_patient_cab group by patient_id having count(*) =2);

select * from zz_lookup_patient_cab_dup; --87


--there are 87 records in the lookup table that are duplicates 

SELECT distinct on (patient_id)
 subject_id, patient_id, match_probability, local_patient_identifier
from zz_lookup_patient_cab
order by patient_id, match_probability desc --72795


select count(*) from zz_lookup_patient_cab; --72882


--therefore my query has reoved 117 records where the patient_id was down twice.

--now create a new lookuptable 
create table  zz_lookup_patient_cab_lily as
(SELECT distinct on (patient_id)
 subject_id, patient_id, match_probability, local_patient_identifier
from zz_lookup_patient_cab
order by patient_id, match_probability desc);

--check no duplicate patient_id records 

select patient_id, count(*) as freq from 
zz_lookup_patient_cab_lily group by patient_id order by freq desc;

--now re-run my finding of patients with null dob 

    select count(*) from (select ab.patient_id 
    FROM hic_hh.audio_val_nodups_sexed ab
left JOIN hic_hh.zz_lookup_patient_cab_lily ON ab.patient_id = hic_hh.zz_lookup_patient_cab_lily.patient_id
inner JOIN hic_hh.cab_demographics cab ON hic_hh.zz_lookup_patient_cab_lily.subject_id = cab.subject_id
    where ab.dateofbirth is null 
    and cab.birth_date notnull)lil; --395 

   -- so 395 of the null records can be matched in caboodle 



--- now the ads table 
select count(*) from zz_lookup_patient_ads; --111661
select * from zz_lookup_patient_ads;


select count(*) from (SELECT distinct on (patient_id)
 primary_mrn, nhs_number, patient_id, match_probability
from zz_lookup_patient_ads
order by patient_id, match_probability desc)lily --97707

  drop table if exists zz_lookup_patient_ads_lily;
  create table zz_lookup_patient_ads_lily
    as 
    (SELECT distinct on (patient_id)
 primary_mrn, nhs_number, patient_id, match_probability
from zz_lookup_patient_ads
order by patient_id, match_probability desc);

  select count(*) from zz_lookup_patient_ads_lily; --97707 

-- now lets see if this changes anything


   select count(*) from (select ab.*
    FROM hic_hh.audio_val_nodups_sexed ab
left JOIN hic_hh.zz_lookup_patient_ads_lily ON ab.patient_id = hic_hh.zz_lookup_patient_ads_lily.patient_id
INNER JOIN hic_hh.ads_pmi ads ON hic_hh.zz_lookup_patient_ads_lily.primary_mrn = ads.primary_mrn 
    where ab.dateofbirth is null 
    and ads.date_of_birth notnull)lil; #372

  --make this into a view
  drop table audio_val_nodups_sexed_dob_ads
  create table audio_val_nodups_sexed_dob_ads
    as
    select ab.*, ads.date_of_birth
    FROM hic_hh.audio_val_nodups_sexed ab
left JOIN hic_hh.zz_lookup_patient_ads_lily ON ab.patient_id = hic_hh.zz_lookup_patient_ads_lily.patient_id
INNER JOIN hic_hh.ads_pmi ads ON hic_hh.zz_lookup_patient_ads_lily.primary_mrn = ads.primary_mrn 
    where ab.dateofbirth is null 
    and ads.date_of_birth notnull;

  select count(*) from audio_val_nodups_sexed_dob_ads; --372

ALTER TABLE audio_val_nodups_sexed_dob_ads --convert timestamp date to date
ALTER COLUMN date_of_birth TYPE date;

select * from audio_val_nodups_sexed_dob_ads;

  drop table if exists  audio_val_nodups_sexed_dob_cab;
  create table audio_val_nodups_sexed_dob_cab as
select ab.* , cab.birth_date
    FROM hic_hh.audio_val_nodups_sexed ab
inner JOIN hic_hh.zz_lookup_patient_cab_lily  ON ab.patient_id = hic_hh.zz_lookup_patient_cab_lily.patient_id
inner JOIN hic_hh.cab_demographics cab ON hic_hh.zz_lookup_patient_cab_lily.subject_id = cab.subject_id
    where ab.dateofbirth is null 
    and cab.birth_date notnull;

  ALTER TABLE audio_val_nodups_sexed_dob_cab --convert timestamp date to date
ALTER COLUMN birth_date TYPE date;

  select * from audio_val_nodups_sexed_dob_cab; 

--now see which records are in the cab and ads table  

select * from audio_val_nodups_sexed_dob_cab
  where patient_id in 
  (select patient_id from audio_val_nodups_sexed_dob_ads); #356

select * from audio_val_nodups_sexed_dob_ads
  where patient_id in 
  (select patient_id from audio_val_nodups_sexed_dob_cab); --356 finally they match

select * from audio_val_nodups_sexed_dob_ads
  where patient_id not in 
  (select patient_id from audio_val_nodups_sexed_dob_cab); --16 (356 + 16 = 372)

select * from audio_val_nodups_sexed_dob_cab
  where patient_id not in 
  (select patient_id from audio_val_nodups_sexed_dob_ads); --39 (356 +39 = 395)

select count(*) from 
hic_hh.audio_val_nodups_sexed  where dateofbirth is null; --1878

--now update for the ads values 


  update audio_val_nodups_sexed 
  set  dateofbirth = audio_val_nodups_sexed_dob_ads.date_of_birth 
  from audio_val_nodups_sexed_dob_ads
  where audio_val_nodups_sexed.patient_id = audio_val_nodups_sexed_dob_ads.patient_id 
  AND audio_val_nodups_sexed.dateofbirth is null; 

select * from audio_val_nodups_sexed_dob_ads;

  select count(*) from 
hic_hh.audio_val_nodups_sexed  where dateofbirth is null; --1506

  --now update for the additional 39 cab records

  select * from audio_val_nodups_sexed_dob_cab; --birthdate is the column from caboodle


  update audio_val_nodups_sexed 
  set  dateofbirth = audio_val_nodups_sexed_dob_cab.birth_date 
  from audio_val_nodups_sexed_dob_cab
  where audio_val_nodups_sexed.patient_id = audio_val_nodups_sexed_dob_cab.patient_id 
  AND audio_val_nodups_sexed.dateofbirth is null; 

  select count(*) from 
hic_hh.audio_val_nodups_sexed  where dateofbirth is null; --1467

select * from hic_hh.audio_val_nodups_sexed order by dateofbirth asc;

--now delete the very early birthdays

drop table if exists audio_val_nodups_sexed_dob;
create table audio_val_nodups_sexed_dob
  as select * from audio_val_nodups_sexed;


delete from hic_hh.audio_val_nodups_sexed_dob 
  where dateofbirth <= to_date('01/01/1901', 'DD/MM/YYYY');

SELECT count(*) from hic_hh.audio_val_nodups_sexed_dob; #333992 that deleted 79 records as expected 

----- now lets create final table without null dateofbirth

delete from hic_hh.audio_val_nodups_sexed_dob
  where dateofbirth is null;

select count(*) from hic_hh.audio_val_nodups_sexed_dob # 332525


  ---- now add age column 


  alter table hic_hh.audio_val_nodups_sexed_dob add column ag interval;
update hic_hh.audio_val_nodups_sexed_dob
  set ag = 
age(investdate, dateofbirth);


--include column with age
alter table hic_hh.audio_val_nodups_sexed_dob add column age int;
  update hic_hh.audio_val_nodups_sexed_dob 
  set age= 
date_part('year', ag)::int;


Select min(age) from audio_val_nodups_sexed_dob; -1806
Select max(age) from audio_val_nodups_sexed_dob; =1027

select * from hic_hh.audio_val_nodups_sexed_dob order by age asc
select * from hic_hh.audio_val_nodups_sexed_dob
where investdate < dateofbirth; -- 296 

delete from hic_hh.audio_val_nodups_sexed_dob 
  where investdate < dateofbirth;

select count(*) from hic_hh.audio_val_nodups_sexed_dob -- 332229

  drop table if exists audio_val_nodups_sexed_dob;
  create table audio as select * from hic_hh.audio_val_nodups_sexed_dob;

select * from audio where dateofbirth is null; --0
select * from audio where sex is null; --0



  -- our dataset with complete dob and sex for all ages

  select count(*) from audio --332229

  select distinct(curve) from audio -- 0 and 10 only


    -- remove records with null values 


select count(*) from audio
  where curve = 10 and 
l250t is null and
  l250tm is null and
  l500t is null and
    l500tm is null and
  l1000t is null and
   l1000tm is null and
  l2000t is null and
   l2000tm is null and
  l4000t is null and
   l4000tm is null and
  l8000t is null and
  l8000tm is null and
  r250t is null and
  r250tm is null and
  r500t is null and
    r500tm is null and
  r1000t is null and
   r1000tm is null and
  r2000t is null and
   r2000tm is null and
  r4000t is null and
   r4000tm is null and
  r8000t is null and
  r8000tm is null; #17490

  select count(*) from audio
  where curve = 0 and 
l250t is null and
  l250tm is null and
  l500t is null and
    l500tm is null and
  l1000t is null and
   l1000tm is null and
  l2000t is null and
   l2000tm is null and
  l4000t is null and
   l4000tm is null and
  l8000t is null and
  l8000tm is null and
  r250t is null and
  r250tm is null and
  r500t is null and
    r500tm is null and
  r1000t is null and
   r1000tm is null and
  r2000t is null and
   r2000tm is null and
  r4000t is null and
   r4000tm is null and
  r8000t is null and
  r8000tm is null; --567

  select 17490 + 567 as addition; --18057
 select  332229 - 18057  as substraction; 314172

drop table if exists audio_nn;
  create table audio_nn
    as select * from audio; 
 
   delete from audio_nn
  where curve = 10 and 
l250t is null and
  l250tm is null and
  l500t is null and
    l500tm is null and
  l1000t is null and
   l1000tm is null and
  l2000t is null and
   l2000tm is null and
  l4000t is null and
   l4000tm is null and
  l8000t is null and
  l8000tm is null and
  r250t is null and
  r250tm is null and
  r500t is null and
    r500tm is null and
  r1000t is null and
   r1000tm is null and
  r2000t is null and
   r2000tm is null and
  r4000t is null and
   r4000tm is null and
  r8000t is null and
  r8000tm is null;

delete from audio_nn
  where curve = 0 and 
l250t is null and
  l250tm is null and
  l500t is null and
    l500tm is null and
  l1000t is null and
   l1000tm is null and
  l2000t is null and
   l2000tm is null and
  l4000t is null and
   l4000tm is null and
  l8000t is null and
  l8000tm is null and
  r250t is null and
  r250tm is null and
  r500t is null and
    r500tm is null and
  r1000t is null and
   r1000tm is null and
  r2000t is null and
   r2000tm is null and
  r4000t is null and
   r4000tm is null and
  r8000t is null and
  r8000tm is null;

  select count(*) from audio_nn --314172

-- now some patients have had multiple audiograms performed on same side indicated by audindex value of >1. 
-- unfortunately all the repeated measures are not just null 
-- but maybe some are duplicates

select count(*) from (select distinct patient_id, investdate, curve, age, sex,
    l250t, l250tm,
  l500t, l500tm,
  l1000t, l1000tm,
  l2000t, l2000tm,
  l4000t, l4000tm,
  l8000t, l8000tm,
  r250t, r250tm,
  r500t, r500tm,
  r1000t, r1000tm,
  r2000t, r2000tm,
  r4000t, r4000tm,
  r8000t, r8000tm from audio_nn)lily; --301546

select 314172 - 301546 as subtraction --12626

----so there are 12626 (314172 - 301546) that are the same except for audindex so 
--we can delete those with duplicate entries under different audindexes

drop table if exists audio_audindex;
create table audio_audindex as select min(audindex), patient_id, investdate, curve, age, sex,
    l250t, l250tm,
  l500t, l500tm,
  l1000t, l1000tm,
  l2000t, l2000tm,
  l4000t, l4000tm,
  l8000t, l8000tm,
  r250t, r250tm,
  r500t, r500tm,
  r1000t, r1000tm,
  r2000t, r2000tm,
  r4000t, r4000tm,
  r8000t, r8000tm from audio_nn
group by patient_id, investdate, curve, age, sex,
    l250t, l250tm,
  l500t, l500tm,
  l1000t, l1000tm,
  l2000t, l2000tm,
  l4000t, l4000tm,
  l8000t, l8000tm,
  r250t, r250tm,
  r500t, r500tm,
  r1000t, r1000tm,
  r2000t, r2000tm,
  r4000t, r4000tm,
  r8000t, r8000tm;

  select count(*) from audio_audindex #301546


  select * from audio_audindex; -- now audindex is called min - rename it to audindex
alter table audio_audindex rename min to audindex;


  --now after that lets see how many have 2 or more 
 select count(*) from audio_audindex where audindex >=2 #6789 

   select * from audio_audindex where audindex >=2 order by audindex desc -- 8 is max

select count(*) from audio_audindex where audindex =2 --6458
select count(*) from audio_audindex where audindex =3 --283
select count(*) from audio_audindex where audindex =4 --40
select count(*) from audio_audindex where audindex =5 --6
select count(*) from audio_audindex where audindex =6 --1
select count(*) from audio_audindex where audindex =7 --0
select count(*) from audio_audindex where audindex =8 --1

  select 6458 + 283 + 40 + 6 + 1 + 1 --6789 -- adds up out of 301546 records

----- however there are still 5634  (301546 - 295912) records with more than 1 audindex 

select count(*) from
  (select patient_id, investdate, curve from audio_audindex group by
  patient_id, investdate, curve)lil #295912

select 301546 - 295912 as subtraction #5634

-- however when we see how many have audindex >=2 it is 6789


   select count(*) from audio_audindex where audindex >=2 #6789

--- we need to make a rule to keep one 

--- our rule will be to rank all audiograms with same patient_id, curve and investdate using the number of null values and the audindex
 -- you want to keep the record with the smallest number of nulls
 -- if the number of nulls are the same then you keen the most recent audiogram i.e. the one with the biggest audindex
 -- you want to assign all the keepers as 1 so that you automoatically keep the ones without more than 1 audinex
-

-- now create a new table that counts up the number of null fields for the frequencies

drop table if exists audio_audindex_nill;

create table audio_audindex_nill as 
select audio_audindex.*,
  (l250t is null)::int + (l250tm is null)::int  +
  (l500tm is NULL)::int + (l500t is  NULL)::int +
  (l1000tm is NULL)::int + ( l1000t is  NULL)::int +
  (l2000tm is NULl)::int + ( l2000t is NULL)::int +
  (l4000tm is NULL)::int + ( l4000t is NULL)::int +
(l8000tm is  NULL)::int + (l8000t is  NULL)::int +
  (r250tm is NULL)::int + (r250t is  NULL)::int +
 (r500tm is  NULL)::int + ( r500t is  NULL)::int +
  (r1000tm is NULL)::int + ( r1000t is  NULL)::int+
  (r2000tm is NULL)::int + (r2000t is NULL)::int+
  (r4000tm is  NULL)::int + (r4000t is  NULL)::int as null_number
  from audio_audindex;

--lets find people with multiple audindex to ensure my rule is working


select audio_audindex_nill.*, rank()
  OVER(partition by patient_id, investdate, curve order by
 null_number, audindex desc) as rank
  from audio_audindex_nill where patient_id=  715


  --- create my table to just include audindex with rank 1 

  drop table if exists audio_aud1;
  create table audio_aud1
    as select * from (select audio_audindex_nill.*, rank()
  OVER(partition by patient_id, investdate, curve order by
 null_number, audindex desc) as rank
  from audio_audindex_nill)lily where lily.rank = 1;

select * from audio_aud1 where rank !=1; --0 it works !

select count(*) from audio_aud1; --295913



------------- NOW WE HAVE ONLY GOT 1 AUDINDEX FOR EVERY AUDIOGRAM ----------------------------------------

--Join the audiograms so that curves 0 and 10 performed for the same audiogram are in 1 row. This makes an audiogram per row. 

drop table if exists data_curves;
CREATE TABLE data_curves AS SELECT 
  curve, patient_id, audindex, investdate, age, sex,
  l250t, l250tm,
  l500t, l500tm,
  l1000t, l1000tm,
  l2000t, l2000tm,
  l4000t, l4000tm,
  l8000t, l8000tm,
  r250t, r250tm,
  r500t, r500tm,
  r1000t, r1000tm,
  r2000t, r2000tm,
  r4000t, r4000tm,
  r8000t, r8000tm
    FROM audio_aud1;

select * from data_curves;

select count(*) from data_curves # 295913

---- before we do the join lets check there are no records with completely empty fields for the frequencies --------

select count(*) from data_curves 
  where curve = 10 and 
l250t is null and
  l250tm is null and
  l500t is null and
    l500tm is null and
  l1000t is null and
   l1000tm is null and
  l2000t is null and
   l2000tm is null and
  l4000t is null and
   l4000tm is null and
  l8000t is null and
  l8000tm is null and
  r250t is null and
  r250tm is null and
  r500t is null and
    r500tm is null and
  r1000t is null and
   r1000tm is null and
  r2000t is null and
   r2000tm is null and
  r4000t is null and
   r4000tm is null and
  r8000t is null and
  r8000tm is null; --0



select count(*) from data_curves 
  where curve = 0 and 
l250t is null and
  l250tm is null and
  l500t is null and
    l500tm is null and
  l1000t is null and
   l1000tm is null and
  l2000t is null and
   l2000tm is null and
  l4000t is null and
   l4000tm is null and
  l8000t is null and
  l8000tm is null and
  r250t is null and
  r250tm is null and
  r500t is null and
    r500tm is null and
  r1000t is null and
   r1000tm is null and
  r2000t is null and
   r2000tm is null and
  r4000t is null and
   r4000tm is null and
  r8000t is null and
  r8000tm is null; -- 0 

--check that there are no thresholds < -10 or >120

  drop table if exists data_curves_outrange;
  create table data_curves_outrange
    as
select * from data_curves
  where 
  l250t < -10 or l250t >120 or 
  l250tm < -10 or l250tm >120 or 
  l500t < -10 or l500t >120 or 
    l500tm < -10 or l500tm >120 or 
  l1000t < -10 or l1000t >120 or 
   l1000tm < -10 or l1000tm >120 or 
  l2000t < -10 or l2000t >120 or 
   l2000tm < -10 or l2000tm >120 or 
  l4000t < -10 or l4000t >120 or 
   l4000tm < -10 or l4000tm >120 or 
  l8000t < -10 or l8000t >120 or 
  l8000tm < -10 or l8000tm >120 or 
   r250t < -10 or r250t >120 or 
  r250tm < -10 or r250tm >120 or 
  r500t < -10 or r500t >120 or 
    r500tm < -10 or r500tm >120 or 
  r1000t < -10 or r1000t >120 or 
   r1000tm < -10 or r1000tm >120 or 
  r2000t < -10 or r2000t >120 or 
   r2000tm < -10 or r2000tm >120 or 
  r4000t < -10 or r4000t >120 or 
   r4000tm < -10 or r4000tm >120 or 
  r8000t < -10 or r8000t >120 or 
  r8000tm < -10 or r8000tm >120; 


************* now see how many curves are not multiples of 5 
  
  select count(*) from
 (select * from data_curves
  where 
  (l250t % 5 = 0 and l250t is not null) or
  (l250tm % 5 = 0 and l250tm is not null) or  
  (l500t % 5 = 0 and l500t is not null) or
    (l500tm % 5 = 0 and l500tm is not null) or
  (l1000t % 5 = 0 and l1000t is not null) or
   (l1000tm % 5 = 0 and l1000tm is not null) or
  (l2000t % 5 = 0 and l2000t is not null) or
   (l2000tm % 5 = 0 and l2000tm is not null) or
  (l4000t % 5 = 0 and l4000t is not null) or
   (l4000tm % 5 = 0 and l4000tm is not null) or
  (l8000t % 5 = 0 and l8000t is not null) or
  (l8000tm % 5 = 0 and l8000tm is not null) or
   (r250t % 5 = 0 and r250t is not null) or
  (r250tm % 5 = 0 and r250tm is not null) or
  (r500t % 5 = 0 and r500t is not null) or
    (r500tm % 5 = 0 and r500tm is not null) or
  (r1000t % 5 = 0 and r1000t is not null) or
   (r1000tm % 5 = 0 and r1000tm is not null) or
  (r2000t % 5 = 0 and r2000t is not null) or
   (r2000tm % 5 = 0 and r2000tm is not null) or
  (r4000t % 5 = 0 and r4000t is not null) or
   (r4000tm % 5 = 0 and r4000tm is not null) or
  (r8000t % 5 = 0 and r8000t is not null) or
  (r8000tm % 5 = 0 and r8000tm is not null))lil; --295891

select count(*) from data_curves; --295913

select 295913 - 295891 as subtraction --22

  drop table if exists data_curves_not5;
  create table data_curves_not5 as
  select * from data_curves
  where 
  (l250t % 5 != 0 and l250t is not null) or
  (l250tm % 5 != 0 and l250tm is not null) or  
  (l500t % 5 != 0 and l500t is not null) or
    (l500tm % 5 != 0 and l500tm is not null) or
  (l1000t % 5 != 0 and l1000t is not null) or
   (l1000tm % 5 != 0 and l1000tm is not null) or
  (l2000t % 5 != 0 and l2000t is not null) or
   (l2000tm % 5 != 0 and l2000tm is not null) or
  (l4000t % 5 != 0 and l4000t is not null) or
   (l4000tm % 5 != 0 and l4000tm is not null) or
  (l8000t % 5 != 0 and l8000t is not null) or
  (l8000tm % 5 != 0 and l8000tm is not null) or
   (r250t % 5 != 0 and r250t is not null) or
  (r250tm % 5 != 0 and r250tm is not null) or
  (r500t % 5 != 0 and r500t is not null) or
    (r500tm % 5 != 0 and r500tm is not null) or
  (r1000t % 5 != 0 and r1000t is not null) or
   (r1000tm % 5 != 0 and r1000tm is not null) or
  (r2000t % 5 != 0 and r2000t is not null) or
   (r2000tm % 5 != 0 and r2000tm is not null) or
  (r4000t % 5 != 0 and r4000t is not null) or
   (r4000tm % 5 != 0 and r4000tm is not null) or
  (r8000t % 5 != 0 and r8000t is not null) or
  (r8000tm % 5 != 0 and r8000tm is not null) --330 have non multiple of 5 answers


  --- NOW DO THE JOIN TO FIND RECORDS WITH BOTH AC AND BC ----------


  drop table if exists data_join;
create table data_join as 
    select
val_1.patient_id ac_patient_id,val_2.patient_id as bc_patient_id,
val_1.investdate ac_investdate,val_2.investdate as bc_investdate,
  val_1.audindex ac_audindex, val_2.audindex as bc_audindex,
  val_1.curve ac_curve, val_2.curve as bc_curve,
  val_1.sex ac_sex, val_2.sex as bc_sex,
  val_1.age ac_age, val_2.age as bc_age,
   val_1.l250t ac_l250t,
  val_1.l250tm ac_l250tm,
    val_1.l500t ac_l500t, val_2.l500t as bc_l500t,
  val_1.l500tm ac_l500tm, val_2.l500tm as bc_l500tm,
  val_1.l1000t ac_l1000t, val_2.l1000t as bc_l1000t,
  val_1.l1000tm ac_l1000tm, val_2.l1000tm as bc_l1000tm, 
  val_1.l2000t ac_l2000t, val_2.l2000t as bc_l2000t, 
  val_1.l2000tm ac_l2000tm, val_2.l2000tm as bc_l2000tm, 
  val_1.l4000t ac_l4000t, 
  val_1.l4000tm  ac_l4000tm,
  val_1.l8000t ac_l8000t, 
  val_1.l8000tm  ac_l8000tm,
  val_1.r250t ac_r250t, 
  val_1.r250tm ac_r250tm,
  val_1.r500t ac_r500t,  val_2.r500t as bc_r500t,
  val_1.r500tm ac_r500tm, val_2.r500tm as bc_r500tm,
  val_1.r1000t ac_r1000t, val_2.r1000t as bc_r1000t,
  val_1.r1000tm ac_r1000tm, val_2.r1000tm as bc_r1000tm, 
  val_1.r2000t ac_r2000t, val_2.r2000t as bc_r2000t, 
  val_1.r2000tm ac_r2000tm, val_2.r2000tm as bc_r2000tm, 
  val_1.r4000t ac_r4000t, 
  val_1.r4000tm ac_r4000tm,
  val_1.r8000t ac_r8000t, 
  val_1.r8000tm ac_r8000tm
from
  data_curves val_1
inner join data_curves val_2 on val_1.patient_id = val_2.patient_id and val_1.investdate = val_2.investdate
where
    val_1.curve = 0
and val_2.curve = 10;


--2.	Find the number with AC and BC 

select count(*) from data_join; --121478

select count(*) from (select distinct * from data_join)x; --121478


  
--3.	Find the number with AC only  

drop table if exists data_nojoin;
Create table data_nojoin as select * from data_curves;

delete from  data_nojoin
  where (patient_id, investdate) IN
  (select
ac_patient_id,
ac_investdate
from data_join);

select count(*) from data_nojoin; --52958

--now this has both ac and bc in there 
drop  table  if exists data_ac;
create table data_ac as 
  (select * from data_nojoin where curve =0);

select count(*) from data_ac; --52614

drop table if exists data_bc;
create table data_bc as 
  (select * from data_nojoin where curve =10);
select count(*) from data_bc; --344

select 344 + 52614 as "Addition"; --52958

select 121478 + 344 + 52614 + 121478 as addition --295914 

  ----------------------- now remove from these 3 tables the records which are not multiples of 5 and are outside range -10 to +120
---first remove those without multiples of 5 

  select * from data_bc b
  where
  exists (
  select from data_curves_not5 n5
    where
b.patient_id = n5.patient_id
  and b.investdate = n5.investdate
  and b.audindex = n5.audindex) --1 record

    select * from data_ac b
  where
  exists (
  select from data_curves_not5 n5
    where
b.patient_id = n5.patient_id
  and b.investdate = n5.investdate
  and b.audindex = n5.audindex) --112 records

    

          select * from data_join b
  where
  exists (
  select from data_curves_not5 n5
    where
b.ac_patient_id = n5.patient_id
  and b.ac_investdate = n5.investdate
  and b.ac_audindex = n5.audindex
    and b.ac_curve = n5.curve) --113

             select * from data_join b
  where
  exists (
  select from data_curves_not5 n5
    where
b.ac_patient_id = n5.patient_id
  and b.ac_investdate = n5.investdate
  and b.bc_audindex = n5.audindex
    and b.bc_curve = n5.curve) --104

               select * from data_join b
  where
  exists (
  select from data_curves_not5 n5
    where
b.ac_patient_id = n5.patient_id
  and b.ac_investdate = n5.investdate
  and b.ac_audindex = n5.audindex
    and b.bc_curve = n5.curve
    and b.ac_curve = n5.curve); 

              select 104 + 113 + 112 + 1 as addition; --330
                
/* now do the deletions!  */          

  delete from  data_ac b
                where
  exists (
  select from data_curves_not5 n5
    where
b.patient_id = n5.patient_id
  and b.investdate = n5.investdate
  and b.audindex = n5.audindex);

                select count(*) from data_ac; --52502

                  select 52614 - 52502 as subtraction; --#112

delete from data_join b  where
  exists (
  select from data_curves_not5 n5
    where
b.ac_patient_id = n5.patient_id
  and b.ac_investdate = n5.investdate
  and b.ac_audindex = n5.audindex
    and b.ac_curve = n5.curve);

   delete from data_join b
   where
  exists (
  select from data_curves_not5 n5
    where
b.ac_patient_id = n5.patient_id
  and b.ac_investdate = n5.investdate
  and b.bc_audindex = n5.audindex
    and b.bc_curve = n5.curve);

    select count(*) from data_join; --121355 

   select 121355 - 121478 as subtraction --123

     delete from data_bc b
  where
  exists (
  select from data_curves_not5 n5
    where
b.patient_id = n5.patient_id
  and b.investdate = n5.investdate
  and b.audindex = n5.audindex);

    select count (*) from data_bc; --343

  -- now for those outside of range

              select count(*) from data_curves_outrange; --221


  select * from data_bc b
  where
  exists (
  select from data_curves_outrange n5
    where
b.patient_id = n5.patient_id
  and b.investdate = n5.investdate
  and b.audindex = n5.audindex); --0 record

    select * from data_ac b
  where
  exists (
  select from data_curves_outrange n5
    where
b.patient_id = n5.patient_id
  and b.investdate = n5.investdate
  and b.audindex = n5.audindex); --81 records

    delete from data_ac b 
 where
  exists (
  select from data_curves_outrange n5
    where
b.patient_id = n5.patient_id
  and b.investdate = n5.investdate
  and b.audindex = n5.audindex);

      select count(*) from data_ac;

select 52502 - 52433 as subtraction;   --69

          select * from data_join b
  where
  exists (
  select from data_curves_outrange n5
    where
b.ac_patient_id = n5.patient_id
  and b.ac_investdate = n5.investdate
  and b.ac_audindex = n5.audindex
    and b.ac_curve = n5.curve); --137

                delete from data_join b
  where
  exists (
  select from data_curves_outrange n5
    where
b.ac_patient_id = n5.patient_id
  and b.ac_investdate = n5.investdate
  and b.ac_audindex = n5.audindex
    and b.ac_curve = n5.curve);
     

             select * from data_join b
  where
  exists (
  select from data_curves_outrange n5
    where
b.ac_patient_id = n5.patient_id
  and b.ac_investdate = n5.investdate
  and b.bc_audindex = n5.audindex
    and b.bc_curve = n5.curve); -- 3 

    delete from data_join b
  where
  exists (
  select from data_curves_outrange n5
    where
b.ac_patient_id = n5.patient_id
  and b.ac_investdate = n5.investdate
  and b.bc_audindex = n5.audindex
    and b.bc_curve = n5.curve);

               select * from data_join b
  where
  exists (
  select from data_curves_outrange n5
    where
b.ac_patient_id = n5.patient_id
  and b.ac_investdate = n5.investdate
  and b.ac_audindex = n5.audindex
    and b.bc_curve = n5.curve
    and b.ac_curve = n5.curve); --0

                select 3 + 81 + 137 as addition; --221

                select count (*) from data_join; --121218

select 121355 - 121218 as subtraction; --137



--Final Count 

 select count(*) from data_ac; --52433
 select count(*) from data_bc; --343 
 select count(*) from data_join; --121218 

-- final check no multiples of 5 

select * from data_join 
                where
                 (ac_l250t % 5 != 0 and ac_l250t is not null) or
  (ac_l250tm % 5 != 0 and ac_l250tm is not null) or  
  (ac_l500t % 5 != 0 and ac_l500t is not null) or
    (ac_l500tm % 5 != 0 and ac_l500tm is not null) or
  (ac_l1000t % 5 != 0 and ac_l1000t is not null) or
   (ac_l1000tm % 5 != 0 and ac_l1000tm is not null) or
  (ac_l2000t % 5 != 0 and ac_l2000t is not null) or
   (ac_l2000tm % 5 != 0 and ac_l2000tm is not null) or
  (ac_l4000t % 5 != 0 and ac_l4000t is not null) or
   (ac_l4000tm % 5 != 0 and ac_l4000tm is not null) or
  (ac_l8000t % 5 != 0 and ac_l8000t is not null) or
  (ac_l8000tm % 5 != 0 and ac_l8000tm is not null) or
   (ac_r250t % 5 != 0 and ac_r250t is not null) or
  (ac_r250tm % 5 != 0 and ac_r250tm is not null) or
  (ac_r500t % 5 != 0 and ac_r500t is not null) or
    (ac_r500tm % 5 != 0 and ac_r500tm is not null) or
  (ac_r1000t % 5 != 0 and ac_r1000t is not null) or
   (ac_r1000tm % 5 != 0 and ac_r1000tm is not null) or
  (ac_r2000t % 5 != 0 and ac_r2000t is not null) or
   (ac_r2000tm % 5 != 0 and ac_r2000tm is not null) or
  (ac_r4000t % 5 != 0 and ac_r4000t is not null) or
   (ac_r4000tm % 5 != 0 and ac_r4000tm is not null) or
  (ac_r8000t % 5 != 0 and ac_r8000t is not null) or
  (ac_r8000tm % 5 != 0 and ac_r8000tm is not null)or
               
  (bc_l500t % 5 != 0 and bc_l500t is not null) or
    (bc_l500tm % 5 != 0 and bc_l500tm is not null) or
  (bc_l1000t % 5 != 0 and bc_l1000t is not null) or
   (bc_l1000tm % 5 != 0 and bc_l1000tm is not null) or
  (bc_l2000t % 5 != 0 and bc_l2000t is not null) or
   (bc_l2000tm % 5 != 0 and bc_l2000tm is not null); --0
  

select * from data_ac
                where
(l250t % 5 != 0 and l250t is not null) or
  (l250tm % 5 != 0 and l250tm is not null) or  
  (l500t % 5 != 0 and l500t is not null) or
    (l500tm % 5 != 0 and l500tm is not null) or
  (l1000t % 5 != 0 and l1000t is not null) or
   (l1000tm % 5 != 0 and l1000tm is not null) or
  (l2000t % 5 != 0 and l2000t is not null) or
   (l2000tm % 5 != 0 and l2000tm is not null) or
  (l4000t % 5 != 0 and l4000t is not null) or
   (l4000tm % 5 != 0 and l4000tm is not null) or
  (l8000t % 5 != 0 and l8000t is not null) or
  (l8000tm % 5 != 0 and l8000tm is not null) or
   (r250t % 5 != 0 and r250t is not null) or
  (r250tm % 5 != 0 and r250tm is not null) or
  (r500t % 5 != 0 and r500t is not null) or
    (r500tm % 5 != 0 and r500tm is not null) or
  (r1000t % 5 != 0 and r1000t is not null) or
   (r1000tm % 5 != 0 and r1000tm is not null) or
  (r2000t % 5 != 0 and r2000t is not null) or
   (r2000tm % 5 != 0 and r2000tm is not null) or
  (r4000t % 5 != 0 and r4000t is not null) or
   (r4000tm % 5 != 0 and r4000tm is not null) or
  (r8000t % 5 != 0 and r8000t is not null) or
  (r8000tm % 5 != 0 and r8000tm is not null) --0

                select * from data_bc
                where
(l250t % 5 != 0 and l250t is not null) or
  (l250tm % 5 != 0 and l250tm is not null) or  
  (l500t % 5 != 0 and l500t is not null) or
    (l500tm % 5 != 0 and l500tm is not null) or
  (l1000t % 5 != 0 and l1000t is not null) or
   (l1000tm % 5 != 0 and l1000tm is not null) or
  (l2000t % 5 != 0 and l2000t is not null) or
   (l2000tm % 5 != 0 and l2000tm is not null) or
  (l4000t % 5 != 0 and l4000t is not null) or
   (l4000tm % 5 != 0 and l4000tm is not null) or
  (l8000t % 5 != 0 and l8000t is not null) or
  (l8000tm % 5 != 0 and l8000tm is not null) or
   (r250t % 5 != 0 and r250t is not null) or
  (r250tm % 5 != 0 and r250tm is not null) or
  (r500t % 5 != 0 and r500t is not null) or
    (r500tm % 5 != 0 and r500tm is not null) or
  (r1000t % 5 != 0 and r1000t is not null) or
   (r1000tm % 5 != 0 and r1000tm is not null) or
  (r2000t % 5 != 0 and r2000t is not null) or
   (r2000tm % 5 != 0 and r2000tm is not null) or
  (r4000t % 5 != 0 and r4000t is not null) or
   (r4000tm % 5 != 0 and r4000tm is not null) or
  (r8000t % 5 != 0 and r8000t is not null) or
  (r8000tm % 5 != 0 and r8000tm is not null) --0


--- check no values above or below limits 

                select * from data_ac
  where 
  l250t < -10 or l250t >120 or 
  l250tm < -10 or l250tm >120 or 
  l500t < -10 or l500t >120 or 
    l500tm < -10 or l500tm >120 or 
  l1000t < -10 or l1000t >120 or 
   l1000tm < -10 or l1000tm >120 or 
  l2000t < -10 or l2000t >120 or 
   l2000tm < -10 or l2000tm >120 or 
  l4000t < -10 or l4000t >120 or 
   l4000tm < -10 or l4000tm >120 or 
  l8000t < -10 or l8000t >120 or 
  l8000tm < -10 or l8000tm >120 or 
   r250t < -10 or r250t >120 or 
  r250tm < -10 or r250tm >120 or 
  r500t < -10 or r500t >120 or 
    r500tm < -10 or r500tm >120 or 
  r1000t < -10 or r1000t >120 or 
   r1000tm < -10 or r1000tm >120 or 
  r2000t < -10 or r2000t >120 or 
   r2000tm < -10 or r2000tm >120 or 
  r4000t < -10 or r4000t >120 or 
   r4000tm < -10 or r4000tm >120 or 
  r8000t < -10 or r8000t >120 or 
  r8000tm < -10 or r8000tm >120; --0

                 select * from data_bc
  where 
  l250t < -10 or l250t >120 or 
  l250tm < -10 or l250tm >120 or 
  l500t < -10 or l500t >120 or 
    l500tm < -10 or l500tm >120 or 
  l1000t < -10 or l1000t >120 or 
   l1000tm < -10 or l1000tm >120 or 
  l2000t < -10 or l2000t >120 or 
   l2000tm < -10 or l2000tm >120 or 
  l4000t < -10 or l4000t >120 or 
   l4000tm < -10 or l4000tm >120 or 
  l8000t < -10 or l8000t >120 or 
  l8000tm < -10 or l8000tm >120 or 
   r250t < -10 or r250t >120 or 
  r250tm < -10 or r250tm >120 or 
  r500t < -10 or r500t >120 or 
    r500tm < -10 or r500tm >120 or 
  r1000t < -10 or r1000t >120 or 
   r1000tm < -10 or r1000tm >120 or 
  r2000t < -10 or r2000t >120 or 
   r2000tm < -10 or r2000tm >120 or 
  r4000t < -10 or r4000t >120 or 
   r4000tm < -10 or r4000tm >120 or 
  r8000t < -10 or r8000t >120 or 
  r8000tm < -10 or r8000tm >120; --0

                 select * from data_join
  where 
  ac_l250t < -10 or ac_l250t >120 or 
  ac_l250tm < -10 or ac_l250tm >120 or 
  ac_l500t < -10 or ac_l500t >120 or 
    ac_l500tm < -10 or ac_l500tm >120 or 
  ac_l1000t < -10 or ac_l1000t >120 or 
   ac_l1000tm < -10 or ac_l1000tm >120 or 
  ac_l2000t < -10 or ac_l2000t >120 or 
   ac_l2000tm < -10 or ac_l2000tm >120 or 
  ac_l4000t < -10 or ac_l4000t >120 or 
   ac_l4000tm < -10 or ac_l4000tm >120 or 
  ac_l8000t < -10 or ac_l8000t >120 or 
  ac_l8000tm < -10 or ac_l8000tm >120 or 
   ac_r250t < -10 or ac_r250t >120 or 
  ac_r250tm < -10 or ac_r250tm >120 or 
  ac_r500t < -10 or ac_r500t >120 or 
    ac_r500tm < -10 or ac_r500tm >120 or 
  ac_r1000t < -10 or ac_r1000t >120 or 
   ac_r1000tm < -10 or ac_r1000tm >120 or 
  ac_r2000t < -10 or ac_r2000t >120 or 
   ac_r2000tm < -10 or ac_r2000tm >120 or 
  ac_r4000t < -10 or ac_r4000t >120 or 
   ac_r4000tm < -10 or ac_r4000tm >120 or 
  ac_r8000t < -10 or ac_r8000t >120 or 
  ac_r8000tm < -10 or ac_r8000tm >120 or 
                bc_l500t < -10 or bc_l500t >120 or 
    bc_l500tm < -10 or bc_l500tm >120 or 
  bc_l1000t < -10 or bc_l1000t >120 or 
   bc_l1000tm < -10 or bc_l1000tm >120 or 
  bc_l2000t < -10 or bc_l2000t >120 or 
   bc_l2000tm < -10 or bc_l2000tm >120 or 
 bc_r500t < -10 or bc_r500t >120 or 
    bc_r500tm < -10 or bc_r500tm >120 or 
  bc_r1000t < -10 or bc_r1000t >120 or 
   bc_r1000tm < -10 or bc_r1000tm >120 or 
  bc_r2000t < -10 or bc_r2000t >120 or 
   bc_r2000tm < -10 or bc_r2000tm >120; --0

-----------Stage 2 - Now lets look at those with AC only 

--Find the patients with AC only where the patient_id is also in the BC only and AC/BC group – save this as a separate table 
-- This is to ensure we can include AC only readings. Someone would only have AC done if they have a normal hearing test or if they previously had hearing test and 
--their AC thresholds have not changed 

Select count(*) from (Select * from data_ac where patient_id in (select patient_id from data_join))x; --52433

---ie all those with ac only curves have had previous BC curves 


----------- now out of these I need to see which actually have complete values for the required frequencies

drop table if exists data_ac_250to8000_bl;
Create table data_ac_250to8000_bl as
Select * from data_ac where 
(l250tm NOTNULL OR l250t NOTNULL) AND
 (l500tm NOTNULL OR l500t NOTNULL) AND 
  (l1000tm NOTNULL OR l1000t NOTNULL) AND
  (l2000tm NOTNULL OR l2000t NOTNULL) AND
  (l4000tm NOTNULL OR l4000t NOTNULL) AND 
  (l8000tm NOTNULL OR l8000t NOTNULL) AND 
 (r250tm NOTNULL OR r250t NOTNULL)  AND
 (r500tm NOTNULL OR r500t NOTNULL)  AND
  (r1000tm NOTNULL OR r1000t NOTNULL) AND
  (r2000tm NOTNULL OR r2000t NOTNULL) AND
  (r4000tm NOTNULL OR r4000t NOTNULL) AND
(r8000tm NOTNULL OR r8000t NOTNULL);



Select count (*) from data_ac_250to8000_bl; --41522


--now for those with just complete for left ear
drop table if exists data_ac_250to8000_l;
Create table data_ac_250to8000_l as
Select * from data_ac where 
(l250tm NOTNULL OR l250t NOTNULL) AND
 (l500tm NOTNULL OR l500t NOTNULL) AND 
  (l1000tm NOTNULL OR l1000t NOTNULL) AND
  (l2000tm NOTNULL OR l2000t NOTNULL) AND
  (l4000tm NOTNULL OR l4000t NOTNULL) AND 
  (l8000tm NOTNULL OR l8000t NOTNULL) AND 
((r250tm is NULL and r250t is NULL) OR
 (r500tm is NULL and r500t is NULL) OR
  (r1000tm is NULL and r1000t is NULL) OR
  (r2000tm is NULL and r2000t is NULL) OR
  (r4000tm is NULL and r4000t is NULL) OR
(r8000tm is NULL and r8000t is NULL));

Select count (*) from data_ac_250to8000_l; --1746


--now for those with just complete for right ear
drop table if exists data_ac_250to8000_r;
Create table data_ac_250to8000_r as
Select * from data_ac where 
(r250tm NOTNULL OR r250t NOTNULL) AND
 (r500tm NOTNULL OR r500t NOTNULL) AND 
  (r1000tm NOTNULL OR r1000t NOTNULL) AND
  (r2000tm NOTNULL OR r2000t NOTNULL) AND
  (r4000tm NOTNULL OR r4000t NOTNULL) AND 
  (r8000tm NOTNULL OR r8000t NOTNULL) AND 
((l250tm is NULL and l250t is NULL) OR
 (l500tm is NULL and l500t is NULL) OR
  (l1000tm is NULL and l1000t is NULL) OR
  (l2000tm is NULL and l2000t is NULL) OR
  (l4000tm is NULL and l4000t is NULL) OR
(l8000tm is NULL and l8000t is NULL));

Select count (*) from data_ac_250to8000_r; --1600


--now for those with incomplete for right and left ear
drop table if exists data_ac_250to8000_none;
Create table data_ac_250to8000_none as
Select * from data_ac where 
((r250tm is NULL and r250t is NULL) or
 (r500tm is NULL and r500t is NULL) or 
  (r1000tm is NULL and r1000t is NULL) or
  (r2000tm is NULL and r2000t is NULL) or
  (r4000tm is NULL and r4000t is NULL) or 
  (r8000tm is NULL and r8000t is NULL)) AND 
((l250tm is NULL and l250t is NULL) OR
 (l500tm is NULL and l500t is NULL) OR
  (l1000tm is NULL and l1000t is NULL) OR
  (l2000tm is NULL and l2000t is NULL) OR
  (l4000tm is NULL and l4000t is NULL) OR
(l8000tm is NULL and l8000t is NULL));

Select count (*) from data_ac_250to8000_none; --7565

select 41522 + 1746 + 1600 + 7565 as "Addition"; --52433


--now make these into the dataset for ac only 
drop table if exists data_ac_bl;
create table data_ac_bl
  (patient_id int,
  audindex smallint,
  investdate date, 
  sex varchar, 
  age smallint,
  l250 smallint,
  l500 smallint,
  l1000 smallint,
  l2000 smallint,
  l4000 smallint,
  l8000 smallint,
  r250 smallint,
  r500 smallint,
  r1000 smallint,
  r2000 smallint,
  r4000 smallint,
  r8000 smallint);


insert into data_ac_bl (
  patient_id,audindex,investdate, sex, age,
  l250, l500,l1000,l2000,l4000,l8000,
  r250, r500, r1000, r2000, r4000, r8000)
  select 
  patient_id, audindex,  investdate, sex, age,
    case when l250tm notnull then l250tm else l250t end,
    case when l500tm notnull then l500tm else l500t end, 
    case when l1000tm notnull then l1000tm else l1000t end,
    case when l2000tm notnull then l2000tm else l2000t end,
    case when l4000tm notnull then l4000tm else l4000t end, 
    case when l8000tm notnull then l8000tm else l8000t end,
     case when r250tm notnull then r250tm else r250t end,
    case when r500tm notnull then r500tm else r500t end, 
    case when r1000tm notnull then r1000tm else r1000t end,
    case when r2000tm notnull then r2000tm else r2000t end,
    case when r4000tm notnull then r4000tm else r4000t end, 
    case when r8000tm notnull then r8000tm else r8000t end
    from data_ac_250to8000_bl;

select count(*) from data_ac_bl; --41522


--now insert just the left ear group 

--now make these into the dataset for ac only 
drop table data_ac_l;
create table data_ac_l
  (patient_id int,
  audindex smallint,
  investdate date, 
  sex varchar, 
  age smallint,
  l250 smallint,
  l500 smallint,
  l1000 smallint,
  l2000 smallint,
  l4000 smallint,
  l8000 smallint,
  r250 smallint,
  r500 smallint,
  r1000 smallint,
  r2000 smallint,
  r4000 smallint,
  r8000 smallint);


insert into data_ac_l (
  patient_id,audindex,investdate, sex, age,
  l250, l500,l1000,l2000,l4000,l8000)
  select 
  patient_id, audindex,  investdate, sex, age,
    case when l250tm notnull then l250tm else l250t end,
    case when l500tm notnull then l500tm else l500t end, 
    case when l1000tm notnull then l1000tm else l1000t end,
    case when l2000tm notnull then l2000tm else l2000t end,
    case when l4000tm notnull then l4000tm else l4000t end, 
    case when l8000tm notnull then l8000tm else l8000t end
    from data_ac_250to8000_l;

select count(*) from data_ac_l; --1746


-- now insert the group with right ear only

drop table data_ac_r;
create table data_ac_r
  (patient_id int,
  audindex smallint,
  investdate date, 
  sex varchar, 
  age smallint,
   l250 smallint,
  l500 smallint,
  l1000 smallint,
  l2000 smallint,
  l4000 smallint,
  l8000 smallint,
  r250 smallint,
  r500 smallint,
  r1000 smallint,
  r2000 smallint,
  r4000 smallint,
  r8000 smallint);


insert into data_ac_r (
  patient_id,audindex,investdate, sex, age,
  r250, r500, r1000, r2000, r4000, r8000)
  select 
  patient_id, audindex,  investdate, sex, age,
     case when r250tm notnull then r250tm else r250t end,
    case when r500tm notnull then r500tm else r500t end, 
    case when r1000tm notnull then r1000tm else r1000t end,
    case when r2000tm notnull then r2000tm else r2000t end,
    case when r4000tm notnull then r4000tm else r4000t end, 
    case when r8000tm notnull then r8000tm else r8000t end
    from data_ac_250to8000_r;

select count(*) from data_Ac_r; --1600




---------------Stage 3 – look at those with AC and BC values
--First lets make starting table which includes only records with completed threshold for the AC thresholds required
--First create copy of this table then remove any records where AC values are not complete for the required frequencies as these will never be allowed in the dataset

select count(*) from data_join; --121218
drop table if exists data_acbc_ac250to8000_bl;
Create table data_acbc_ac250to8000_bl as
Select * from data_join where
(ac_l250tm NOTNULL OR ac_l250t NOTNULL) AND
 (ac_l500tm NOTNULL OR ac_l500t NOTNULL) AND 
  (ac_l1000tm NOTNULL OR ac_l1000t NOTNULL) AND
  (ac_l2000tm NOTNULL OR ac_l2000t NOTNULL) AND
  (ac_l4000tm NOTNULL OR ac_l4000t NOTNULL) AND 
  (ac_l8000tm NOTNULL OR ac_l8000t NOTNULL) AND 
 (ac_r250tm NOTNULL OR ac_r250t NOTNULL)  AND
 (ac_r500tm NOTNULL OR ac_r500t NOTNULL)  AND
  (ac_r1000tm NOTNULL OR ac_r1000t NOTNULL) AND
  (ac_r2000tm NOTNULL OR ac_r2000t NOTNULL) AND
  (ac_r4000tm NOTNULL OR ac_r4000t NOTNULL) AND
(ac_r8000tm NOTNULL OR ac_r8000t NOTNULL);


select count(*) from data_acbc_ac250to8000_bl; --114146



--now for those with just complete for left ear
drop table if exists data_acbc_ac250to8000_l;
Create table data_acbc_ac250to8000_l as
Select * from data_join where 
(ac_l250tm NOTNULL OR ac_l250t NOTNULL) AND
 (ac_l500tm NOTNULL OR ac_l500t NOTNULL) AND 
  (ac_l1000tm NOTNULL OR ac_l1000t NOTNULL) AND
  (ac_l2000tm NOTNULL OR ac_l2000t NOTNULL) AND
  (ac_l4000tm NOTNULL OR ac_l4000t NOTNULL) AND 
  (ac_l8000tm NOTNULL OR ac_l8000t NOTNULL) AND 
(
  (ac_r250tm is NULL and ac_r250t is NULL) OR
 (ac_r500tm is NULL and ac_r500t is NULL) OR
  (ac_r1000tm is NULL and ac_r1000t is NULL) OR
  (ac_r2000tm is NULL and ac_r2000t is NULL) OR
  (ac_r4000tm is NULL and ac_r4000t is NULL) OR
(ac_r8000tm is NULL and ac_r8000t is NULL));

Select count (*) from data_acbc_ac250to8000_l; --1797


--now for those with just complete for right ear
drop table if exists data_acbc_ac250to8000_r;
Create table data_acbc_ac250to8000_r as
Select * from data_join where 
(ac_r250tm NOTNULL OR ac_r250t NOTNULL) AND
 (ac_r500tm NOTNULL OR ac_r500t NOTNULL) AND 
  (ac_r1000tm NOTNULL OR ac_r1000t NOTNULL) AND
  (ac_r2000tm NOTNULL OR ac_r2000t NOTNULL) AND
  (ac_r4000tm NOTNULL OR ac_r4000t NOTNULL) AND 
  (ac_r8000tm NOTNULL OR ac_r8000t NOTNULL) AND 
((ac_l250tm is NULL and ac_l250t is NULL) OR
 (ac_l500tm is NULL and ac_l500t is NULL) OR
  (ac_l1000tm is NULL and ac_l1000t is NULL) OR
  (ac_l2000tm is NULL and ac_l2000t is NULL) OR
  (ac_l4000tm is NULL and ac_l4000t is NULL) OR
(ac_l8000tm is NULL and ac_l8000t is NULL));

Select count (*) from data_acbc_ac250to8000_r; --1663


--now for those with incomplete for right and left ear
drop table if exists data_acbc_ac250to8000_none;
Create table data_acbc_ac250to8000_none as
Select * from data_join where 
((ac_r250tm is NULL and ac_r250t is NULL) or
 (ac_r500tm is NULL and ac_r500t is NULL) or 
  (ac_r1000tm is NULL and ac_r1000t is NULL) or
  (ac_r2000tm is NULL and ac_r2000t is NULL) or
  (ac_r4000tm is NULL and ac_r4000t is NULL) or 
  (ac_r8000tm is NULL and ac_r8000t is NULL)) and
((ac_l250tm is NULL and ac_l250t is NULL) OR
 (ac_l500tm is NULL and ac_l500t is NULL) OR
  (ac_l1000tm is NULL and ac_l1000t is NULL) OR
  (ac_l2000tm is NULL and ac_l2000t is NULL) OR
  (ac_l4000tm is NULL and ac_l4000t is NULL) OR
(ac_l8000tm is NULL and ac_l8000t is NULL));

Select count (*) from data_acbc_ac250to8000_none; --3612

select 114146 + 1797 + 1663 + 3612 as "addition"; --121218



  --- our starting group is all those in the data_join_ac250to8000_bl table ie who have AC for all freqs in both ears

Select count(*) from data_acbc_ac250to8000_bl; --114146

  select count(*) from data_acbc_ac250to8000_bl where
((ac_r250tm is NULL and ac_r250t is NULL) or
 (ac_r500tm is NULL and ac_r500t is NULL) or 
  (ac_r1000tm is NULL and ac_r1000t is NULL) or
  (ac_r2000tm is NULL and ac_r2000t is NULL) or
  (ac_r4000tm is NULL and ac_r4000t is NULL) or 
  (ac_r8000tm is NULL and ac_r8000t is NULL)) and
((ac_l250tm is NULL and ac_l250t is NULL) OR
 (ac_l500tm is NULL and ac_l500t is NULL) OR
  (ac_l1000tm is NULL and ac_l1000t is NULL) OR
  (ac_l2000tm is NULL and ac_l2000t is NULL) OR
  (ac_l4000tm is NULL and ac_l4000t is NULL) OR
(ac_l8000tm is NULL and ac_l8000t is NULL)); --0 records where either left or right is not completed for all freqs

  
  
--2.	Then from this group see how many have BC at the 2 thresholds required in both ears – save this as a table

drop table if exists data_acbc_ac250to8000_bl_bc2freq_bl;
Create table data_acbc_ac250to8000_bl_bc2freq_bl
As select * from data_acbc_ac250to8000_bl
Where 
(((bc_l500t NOTNULL OR bc_l500tm NOTNULL) and (bc_l1000t NOTNULL OR bc_l1000tm NOTNULL))
  or
((bc_l1000t NOTNULL OR bc_l1000tm NOTNULL) and (bc_l2000t NOTNULL OR bc_l2000tm NOTNULL)) or
((bc_l500t NOTNULL OR bc_l500tm NOTNULL) and (bc_l2000t NOTNULL OR bc_l2000tm NOTNULL)))
  AND
  (((bc_r500t NOTNULL OR bc_r500tm NOTNULL) and (bc_r1000t NOTNULL OR bc_r1000tm NOTNULL)) 
  or
((bc_r1000t NOTNULL OR bc_r1000tm NOTNULL) and (bc_r2000t NOTNULL OR bc_r2000tm NOTNULL)) or
((bc_r500t NOTNULL OR bc_r500tm NOTNULL) and (bc_r2000t NOTNULL OR bc_r2000tm NOTNULL)));

Select count(*) from data_acbc_ac250to8000_bl_bc2freq_bl;  --27512


-- Then see how many have BC at the freq in the left ear only with either none or 1 in right ear


drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_rincom;
Create table data_acbc_ac250to8000_bl_bc2freq_l_rincom
As select * from data_acbc_ac250to8000_bl
Where 
(((bc_l500t NOTNULL OR bc_l500tm NOTNULL) and (bc_l1000t NOTNULL OR bc_l1000tm NOTNULL))
  or
((bc_l1000t NOTNULL OR bc_l1000tm NOTNULL) and (bc_l2000t NOTNULL OR bc_l2000tm NOTNULL)) or
((bc_l500t NOTNULL OR bc_l500tm NOTNULL) and (bc_l2000t NOTNULL OR bc_l2000tm NOTNULL)))
  AND
(((bc_r500t is NULL and bc_r500tm is NULL) and (bc_r1000t is NULL and bc_r1000tm is NULL))
  or
((bc_r1000t is NULL and bc_r1000tm is NULL) and (bc_r2000t is NULL and bc_r2000tm is NULL)) or
((bc_r500t is NULL and bc_r500tm is NULL) and (bc_r2000t is NULL and bc_r2000tm is NULL)));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_rincom; --39711



-- Then see how many have BC at the freq in the right ear only and none/one BC in left ear 
drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_lincom;
Create table data_acbc_ac250to8000_bl_bc2freq_r_lincom
As select * from data_acbc_ac250to8000_bl
Where 
(((bc_r500t NOTNULL OR bc_r500tm NOTNULL) and (bc_r1000t NOTNULL OR bc_r1000tm NOTNULL))
  or
((bc_r1000t NOTNULL OR bc_r1000tm NOTNULL) and (bc_r2000t NOTNULL OR bc_r2000tm NOTNULL)) or
((bc_r500t NOTNULL OR bc_r500tm NOTNULL) and (bc_r2000t NOTNULL OR bc_r2000tm NOTNULL)))
  AND
  (((bc_l500t is NULL and bc_l500tm is NULL) and (bc_l1000t is NULL and bc_l1000tm is NULL))
  or
((bc_l1000t is NULL and bc_l1000tm is NULL) and (bc_l2000t is NULL and bc_l2000tm is NULL)) or
((bc_l500t is NULL and bc_l500tm is NULL) and (bc_l2000t is NULL and bc_l2000tm is NULL)));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_lincom; 43106



-- then see how many have both ears incomplete (one/ none BC in left and right ear )
drop table if exists data_acbc_ac250to8000_bl_bc2freq_rlincom;
Create table data_acbc_ac250to8000_bl_bc2freq_rlincom
As select * from data_acbc_ac250to8000_bl
Where 
(((bc_l500t is NULL and bc_l500tm is NULL) and (bc_l1000t is NULL and bc_l1000tm is NULL))
  or
((bc_l1000t is NULL and bc_l1000tm is NULL) and (bc_l2000t is NULL and bc_l2000tm is NULL)) or
((bc_l500t is NULL and bc_l500tm is NULL) and (bc_l2000t is NULL and bc_l2000tm is NULL)))
  AND
(((bc_r500t is NULL and bc_r500tm is NULL) and (bc_r1000t is NULL and bc_r1000tm is NULL))
  or
((bc_r1000t is NULL and bc_r1000tm is NULL) and (bc_r2000t is NULL and bc_r2000tm is NULL)) or
((bc_r500t is NULL and bc_r500tm is NULL) and (bc_r2000t is NULL and bc_r2000tm is NULL)));

select count(*)from data_acbc_ac250to8000_bl_bc2freq_rlincom; --3817

select * from data_acbc_ac250to8000_bl_bc2freq_rlincom;

select 27512 + 39711 + 43106 + 3817 as addition;--114146 (correct total)

--of these 1818 actually have no BC in either ear!! 
-- but remember they will have had some values completed otherwise would have deleted them earlier

select count(*) from
(select * from data_acbc_ac250to8000_bl_bc2freq_rlincom
Where 
bc_l500t is NULL and bc_l500tm is NULL and bc_l1000t is NULL and bc_l1000tm is NULL and
  bc_l2000t is NULL and bc_l2000tm is NULL and
 bc_r500t is NULL and bc_r500tm is NULL and bc_r1000t is NULL and bc_r1000tm is NULL and
  bc_r2000t is NULL and bc_r2000tm is NULL)lil ; --1818 



----------------------

  --- our second starting group is all those in the audio_join_ac250to8000_l table ie who have AC for all freqs in left ear only
--here we can only look at the left ear clearly! This wont be included in the final dataset. 


Select count(*) from data_acbc_ac250to8000_l; --1797

  select count(*) from data_acbc_ac250to8000_l where
((ac_r250tm is NULL and ac_r250t is NULL) or
 (ac_r500tm is NULL and ac_r500t is NULL) or 
  (ac_r1000tm is NULL and ac_r1000t is NULL) or
  (ac_r2000tm is NULL and ac_r2000t is NULL) or
  (ac_r4000tm is NULL and ac_r4000t is NULL) or 
  (ac_r8000tm is NULL and ac_r8000t is NULL)); --1797 - confirms what we know already


  
--Then from this group see how many have BC at the 2 thresholds required in left ear only 

--where BC done at 2 freq for left ear
drop table if exists data_acbc_ac250to8000_l_bc2freq_l;

Create table data_acbc_ac250to8000_l_bc2freq_l
As select * from data_acbc_ac250to8000_l
Where 
((bc_l500t NOTNULL OR bc_l500tm NOTNULL) and (bc_l1000t NOTNULL OR bc_l1000tm NOTNULL))
  or
((bc_l1000t NOTNULL OR bc_l1000tm NOTNULL) and (bc_l2000t NOTNULL OR bc_l2000tm NOTNULL)) or
((bc_l500t NOTNULL OR bc_l500tm NOTNULL) and (bc_l2000t NOTNULL OR bc_l2000tm NOTNULL))
  ;

Select count(*) from data_acbc_ac250to8000_l_bc2freq_l;  --1519

--where BC done for one/none freq in left ear 

drop table if exists  data_acbc_ac250to8000_l_bc_lincom;

Create table data_acbc_ac250to8000_l_bc_lincom
As select * from data_acbc_ac250to8000_l
Where 
(((bc_l500t is NULL and bc_l500tm is NULL) and (bc_l1000t is NULL and bc_l1000tm is NULL))
  or
((bc_l1000t is NULL and bc_l1000tm is NULL) and (bc_l2000t is NULL and bc_l2000tm is NULL)) or
((bc_l500t is NULL and bc_l500tm is NULL) and (bc_l2000t is NULL and bc_l2000tm is NULL)));

Select count(*) from data_acbc_ac250to8000_l_bc_lincom; --278

select 278 + 1519 as addition; #1797


  -- our third starting group is all those in the audio_join_ac250to8000_r table ie who have AC for all freqs in right ear only
--here we can only look at the right ear clearly!


Select count(*) from data_acbc_ac250to8000_r; --1663
 
--Then from this group see how many have BC at the 2 thresholds required in right ear only 

--where BC done at 2 freq for right ear
drop table if exists data_acbc_ac250to8000_r_bc2freq_r;
Create table data_acbc_ac250to8000_r_bc2freq_r
As select * from data_acbc_ac250to8000_r
Where 
((bc_r500t NOTNULL OR bc_r500tm NOTNULL) and (bc_r1000t NOTNULL OR bc_r1000tm NOTNULL))
  or
((bc_r1000t NOTNULL OR bc_r1000tm NOTNULL) and (bc_r2000t NOTNULL OR bc_r2000tm NOTNULL)) or
((bc_r500t NOTNULL OR bc_r500tm NOTNULL) and (bc_r2000t NOTNULL OR bc_r2000tm NOTNULL))
  ;

Select count(*) from data_acbc_ac250to8000_r_bc2freq_r;  --1431

--where BC done for one/none freq in right ear 

drop table if exists  data_acbc_ac250to8000_r_bc_rincom;
Create table data_acbc_ac250to8000_r_bc_rincom
As select * from data_acbc_ac250to8000_r
Where 
(((bc_r500t is NULL and bc_r500tm is NULL) and (bc_r1000t is NULL and bc_r1000tm is NULL))
  or
((bc_r1000t is NULL and bc_r1000tm is NULL) and (bc_r2000t is NULL and bc_r2000tm is NULL)) or
((bc_r500t is NULL and bc_r500tm is NULL) and (bc_r2000t is NULL and bc_r2000tm is NULL)));

Select count(*) from data_acbc_ac250to8000_r_bc_rincom; --232

select 232 + 1431 as addition --1663


--------------------------------------- now lets look at those who can be kept who have AC and BC in both ears 

select count(*) from data_acbc_ac250to8000_bl_bc2freq_bl;  27512

drop table if exists data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq;
create table data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
  (patient_id int,
  audindex smallint,
  investdate date, sex varchar, age int,
 ac_l250 smallint,
  ac_l500 smallint,
  ac_l1000 smallint,
  ac_l2000 smallint,
  ac_l4000 smallint,
  ac_l8000 smallint,
  ac_r250 smallint,
  ac_r500 smallint,
  ac_r1000 smallint,
  ac_r2000 smallint,
  ac_r4000 smallint,
  ac_r8000 smallint,
bc_l500 smallint,
  bc_l1000 smallint,
  bc_l2000 smallint,
bc_r500 smallint,
  bc_r1000 smallint,
  bc_r2000 smallint);


insert into data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_l500,   bc_l1000,   bc_l2000,
   bc_r500,   bc_r1000,   bc_r2000
)
select 
ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
case when ac_l250tm notnull then ac_l250tm else ac_l250t end,
    case when ac_l500tm notnull then ac_l500tm else ac_l500t end, 
    case when ac_l1000tm notnull then ac_l1000tm else ac_l1000t end,
    case when ac_l2000tm notnull then ac_l2000tm else ac_l2000t end,
    case when ac_l4000tm notnull then ac_l4000tm else ac_l4000t end, 
    case when ac_l8000tm notnull then ac_l8000tm else ac_l8000t end,
    case when ac_r250tm notnull then ac_r250tm else ac_r250t end,
    case when ac_r500tm notnull then ac_r500tm else ac_r500t end, 
    case when ac_r1000tm notnull then ac_r1000tm else ac_r1000t end,
    case when ac_r2000tm notnull then ac_r2000tm else ac_r2000t end,
 case when ac_r4000tm notnull then ac_r4000tm else ac_r4000t end,
    case when ac_r8000tm notnull then ac_r8000tm else ac_r8000t end,
    case when bc_l500tm notnull then bc_l500tm else bc_l500t end, 
    case when bc_l1000tm notnull then bc_l1000tm else bc_l1000t end,
    case when bc_l2000tm notnull then bc_l2000tm else bc_l2000t end,
case when bc_r500tm notnull then bc_r500tm else bc_r500t end, 
    case when bc_r1000tm notnull then bc_r1000tm else bc_r1000t end,
    case when bc_r2000tm notnull then bc_r2000tm else bc_r2000t end
from data_acbc_ac250to8000_bl_bc2freq_bl;

select count(*) from 
 data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq; --27512


-- just check that ac complete for all 

select * from data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
  where
  ac_l250 is null and  ac_l500 is null and   ac_l1000 is null and    ac_l2000 is null and    ac_l4000 is null and    ac_l8000 is null and 
    ac_r250 is null and   ac_r500 is null and    ac_r1000 is null and   ac_r2000 is null and    ac_r4000 is null and    ac_r8000
  is null; --0 



---- now how many of these have both ears without CHL

-- alter the table to add the abg (air-bone gap)


alter table data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
add column l500_abg smallint,
add column l1000_abg smallint,
add column l2000_abg smallint,
add column r500_abg smallint,
add column r1000_abg smallint,
add column r2000_abg smallint;

update  data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
set l500_abg = (ac_l500 - bc_l500),
l1000_abg = (ac_l1000 - bc_l1000),
l2000_abg = (ac_l2000 - bc_l2000),
r500_abg = (ac_r500 - bc_r500),
r1000_abg = (ac_r1000 - bc_r1000),
r2000_abg = (ac_r2000 - bc_r2000);


select count(*) from data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq; 27512

drop table if exists data_acbc_ac250to8000_bl_bc500to2000_bl_abg;
create table data_acbc_ac250to8000_bl_bc500to2000_bl_abg as 
select * from data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
  where 
  ((l500_abg >= 25 and l1000_abg >= 25) OR
  (l500_abg >= 25 and l2000_abg >= 25) OR
  (l1000_abg >= 25 and l2000_abg >= 25)) AND
  ((r500_abg >= 25 and r1000_abg >= 25) OR
  (r500_abg >= 25 and r2000_abg >= 25) OR
  (r1000_abg >= 25 and r2000_abg >= 25));

select count(*) from data_acbc_ac250to8000_bl_bc500to2000_bl_abg; #3393



--- no abg in both ears 
drop table if exists data_acbc_ac250to8000_bl_bc500to2000_bl_noabg;
create table data_acbc_ac250to8000_bl_bc500to2000_bl_noabg as 
select * from data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
  where 
  ((l500_abg < 25 and l1000_abg < 25) OR
  (l500_abg < 25 and l2000_abg < 25) OR
  (l1000_abg < 25 and l2000_abg < 25)) AND
  ((r500_abg < 25 and r1000_abg < 25) OR
  (r500_abg < 25 and r2000_abg < 25) OR
  (r1000_abg < 25 and r2000_abg < 25));

select count(*) from data_acbc_ac250to8000_bl_bc500to2000_bl_noabg; --17441


 --SNHL in left ear but CHL in right ear

drop table if exists data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l;
create table data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l as 
select * from data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
  where 
  ((l500_abg < 25 and l1000_abg < 25) OR
  (l500_abg < 25 and l2000_abg < 25) OR
  (l1000_abg < 25 and l2000_abg < 25)) AND
  ((r500_abg >= 25 and r1000_abg >= 25) OR
  (r500_abg >= 25 and r2000_abg >= 25) OR
  (r1000_abg >= 25 and r2000_abg >= 25));

select count(*) from data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l; --3328


  --SNHL in right ear but CHL in left ear

drop table if exists data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r;
create table data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r as 
select * from data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
  where 
  ((r500_abg < 25 and r1000_abg < 25) OR
  (r500_abg < 25 and r2000_abg < 25) OR
  (r1000_abg < 25 and r2000_abg < 25)) AND
  ((l500_abg >= 25 and l1000_abg >= 25) OR
  (l500_abg >= 25 and l2000_abg >= 25) OR
  (l1000_abg >= 25 and l2000_abg >= 25));

select count(*) from data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r; --3130



  
 --SNHL in right ear and not meeting criteria for CHL in left ear

  drop table if exists data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r_1freql;
create table data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r_1freql as 
select * from data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
  where 
  ((r500_abg < 25 and r1000_abg < 25) OR
  (r500_abg < 25 and r2000_abg < 25) OR
  (r1000_abg < 25 and r2000_abg < 25)) AND
  ((l500_abg >= 25 and l1000_abg < 25 and l2000_abg is null) OR
  (l500_abg >= 25 and l1000_abg is null and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg >= 25 and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >= 25) OR
(l500_abg < 25 and l1000_abg >= 25 and l2000_abg is null) or
(l500_abg < 25 and l1000_abg is null and l2000_abg >= 25));

select count(*) from  data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r_1freql; --59


  
 --SNHL in left ear and not meeting criteria for CHL in rightt ear

  drop table if exists data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqr;
create table  data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqr as 
select * from data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
  where 
  ((l500_abg < 25 and l1000_abg < 25) OR
  (l500_abg < 25 and l2000_abg < 25) OR
  (l1000_abg < 25 and l2000_abg < 25)) AND
  ((r500_abg >= 25 and r1000_abg < 25 and r2000_abg is null) OR
  (r500_abg >= 25 and r1000_abg is null and r2000_abg < 25) OR
  (r500_abg is null and r1000_abg >= 25 and r2000_abg < 25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >= 25) OR
(r500_abg < 25 and r1000_abg >= 25 and r2000_abg is null) or
(r500_abg < 25 and r1000_abg is null and r2000_abg >= 25));

select count(*) from data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqr; --75


  --- neither meeting criteria
drop table if exists data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqbl;
create table  data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqbl as 
select * from data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
  where 
  ((l500_abg >= 25 and l1000_abg < 25 and l2000_abg is null) OR
  (l500_abg >= 25 and l1000_abg is null and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg >= 25 and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >= 25) OR
(l500_abg < 25 and l1000_abg >= 25 and l2000_abg is null) or
(l500_abg < 25 and l1000_abg is null and l2000_abg >= 25))
 AND
  ((r500_abg >= 25 and r1000_abg < 25 and r2000_abg is null) OR
  (r500_abg >= 25 and r1000_abg is null and r2000_abg < 25) OR
  (r500_abg is null and r1000_abg >= 25 and r2000_abg < 25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >= 25) OR
(r500_abg < 25 and r1000_abg >= 25 and r2000_abg is null) or
(r500_abg < 25 and r1000_abg is null and r2000_abg >= 25));

  select count(*) from data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqbl --11

 ---right >=25, left not enough 
 drop table if exists data_acbc_ac250to8000_bl_bc500to2000_bl_abg_r_1freql;
create table data_acbc_ac250to8000_bl_bc500to2000_bl_abg_r_1freql as 
select * from data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
  where 
  ((r500_abg >= 25 and r1000_abg >= 25) OR
  (r500_abg >=25 and r2000_abg >= 25) OR
  (r1000_abg >= 25 and r2000_abg >= 25)) AND
  ((l500_abg >= 25 and l1000_abg < 25 and l2000_abg is null) OR
  (l500_abg >= 25 and l1000_abg is null and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg >= 25 and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >= 25) OR
(l500_abg < 25 and l1000_abg >= 25 and l2000_abg is null) or
(l500_abg < 25 and l1000_abg is null and l2000_abg >= 25));

  select count(*) from data_acbc_ac250to8000_bl_bc500to2000_bl_abg_r_1freql --35

  
 ---left >=25, right not enough 
 drop table if exists data_acbc_ac250to8000_bl_bc500to2000_bl_abg_l_1freqr;
create table data_acbc_ac250to8000_bl_bc500to2000_bl_abg_l_1freqr as 
select * from data_acbc_ac250to8000_bl_bc500to2000_bl_oneperfreq
  where 
  ((l500_abg >= 25 and l1000_abg >= 25) OR
  (l500_abg >=25 and l2000_abg >= 25) OR
  (l1000_abg >= 25 and l2000_abg >= 25)) AND
  ((r500_abg >= 25 and r1000_abg < 25 and r2000_abg is null) OR
  (r500_abg >= 25 and r1000_abg is null and r2000_abg < 25) OR
  (r500_abg is null and r1000_abg >= 25 and r2000_abg < 25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >= 25) OR
(r500_abg < 25 and r1000_abg >= 25 and r2000_abg is null) or
(r500_abg < 25 and r1000_abg is null and r2000_abg >= 25));

  select count(*) from data_acbc_ac250to8000_bl_bc500to2000_bl_abg_l_1freqr; --40

    select 3130 + 3328 + 17441 + 3393 + 75 + 59 +11 +40 + 35 as additio; --27512

    
-------create table of all those with bl BC that have SNHL loss 

    drop table if exists data_acbc_ac250to8000_bl_bc500to2000_SNHL;
  create table data_acbc_ac250to8000_bl_bc500to2000_SNHL
  (patient_id int,
  audindex smallint,
  investdate date, sex varchar, age int,
 ac_l250 smallint,
  ac_l500 smallint,
  ac_l1000 smallint,
  ac_l2000 smallint,
  ac_l4000 smallint,
  ac_l8000 smallint,
  ac_r250 smallint,
  ac_r500 smallint,
  ac_r1000 smallint,
  ac_r2000 smallint,
  ac_r4000 smallint,
  ac_r8000 smallint
);

insert into data_acbc_ac250to8000_bl_bc500to2000_SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
  patient_id, audindex,  investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from 
    data_acbc_ac250to8000_bl_bc500to2000_bl_noabg;

 select count (*) from data_acbc_ac250to8000_bl_bc500to2000_SNHl; --17441


    
-- now insert data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l left ear only

insert into data_acbc_ac250to8000_bl_bc500to2000_SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
  patient_id, audindex,  investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from 
    data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l;

 select count (*) from data_acbc_ac250to8000_bl_bc500to2000_SNHL; == 20769 (17441 + 3328)

    
-- now insert data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r right ear only

insert into data_acbc_ac250to8000_bl_bc500to2000_SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
  patient_id, audindex,  investdate, sex, age,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from 
   data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r;

 select count (*) from data_acbc_ac250to8000_bl_bc500to2000_SNHL; --23899 (20769 + 3130)

    -- now insert data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r_1freql right only

insert into data_acbc_ac250to8000_bl_bc500to2000_SNHL
(patient_id, audindex, investdate, sex, age,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
  patient_id, audindex,  investdate, sex, age,
 
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from 
    data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r_1freql;

 select count (*) from data_acbc_ac250to8000_bl_bc500to2000_SNHL; --23958 (23958 + 59)

    
-- now insert data_acbc_ac250to8000_bc500to2000_bl_noabg_l_1freqr left ear 

insert into data_acbc_ac250to8000_bl_bc500to2000_SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
  patient_id, audindex,  investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from 
    data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqr;

 select count (*) from data_acbc_ac250to8000_bl_bc500to2000_SNHL; --24033 (23958 + 75)

    
--------------------------------------- now lets look at those who can be kept who have AC both ears and BC in left ear 


select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_rincom; --39711

    
drop table if exists data_acbc_ac250to8000_bl_bc500to2000_bc2freq_l_oneperfreq;
create table data_acbc_ac250to8000_bl_bc500to2000_bc2freq_l_oneperfreq
  (patient_id int,
  audindex smallint,
  investdate date, sex varchar, age int,
 ac_l250 smallint,
  ac_l500 smallint,
  ac_l1000 smallint,
  ac_l2000 smallint,
  ac_l4000 smallint,
  ac_l8000 smallint,
  ac_r250 smallint,
  ac_r500 smallint,
  ac_r1000 smallint,
  ac_r2000 smallint,
  ac_r4000 smallint,
  ac_r8000 smallint,
bc_l500t smallint,
  bc_l1000t smallint,
  bc_l2000t smallint,
bc_l500tm smallint,
  bc_l1000tm smallint,
  bc_l2000tm smallint);


    insert into data_acbc_ac250to8000_bl_bc500to2000_bc2freq_l_oneperfreq
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_l500t,   bc_l1000t,   bc_l2000t,
   bc_l500tm,   bc_l1000tm,   bc_l2000tm
)
select 
ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
case when ac_l250tm notnull then ac_l250tm else ac_l250t end,
    case when ac_l500tm notnull then ac_l500tm else ac_l500t end, 
    case when ac_l1000tm notnull then ac_l1000tm else ac_l1000t end,
    case when ac_l2000tm notnull then ac_l2000tm else ac_l2000t end,
    case when ac_l4000tm notnull then ac_l4000tm else ac_l4000t end, 
    case when ac_l8000tm notnull then ac_l8000tm else ac_l8000t end,
    case when ac_r250tm notnull then ac_r250tm else ac_r250t end,
    case when ac_r500tm notnull then ac_r500tm else ac_r500t end, 
    case when ac_r1000tm notnull then ac_r1000tm else ac_r1000t end,
    case when ac_r2000tm notnull then ac_r2000tm else ac_r2000t end,
 case when ac_r4000tm notnull then ac_r4000tm else ac_r4000t end,
    case when ac_r8000tm notnull then ac_r8000tm else ac_r8000t end,
    bc_l500t, bc_l1000t, bc_l2000t,
    bc_l500tm , bc_l1000tm , bc_l2000tm
from data_acbc_ac250to8000_bl_bc2freq_l_rincom;

select count(*) from data_acbc_ac250to8000_bl_bc500to2000_bc2freq_l_oneperfreq; --39711

    --create table where tm notnul

drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull as
select * from data_acbc_ac250to8000_bl_bc500to2000_bc2freq_l_oneperfreq where 
(bc_l500tm NOTNULL and bc_l1000tm NOTNULL)
  or
(bc_l1000tm NOTNULL and bc_l2000tm NOTNULL) 
  or
( bc_l500tm NOTNULl and  bc_l2000tm NOTNULL); 


select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull;  --15095


    --create table where tm is null 

drop table  if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_null;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_null as
select * from data_acbc_ac250to8000_bl_bc500to2000_bc2freq_l_oneperfreq where 
(bc_l500tm is NULL and bc_l1000tm is NULL)
  or
(bc_l1000tm is NULL and bc_l2000tm is NULL) 
  or
( bc_l500tm is NULl and  bc_l2000tm is NULL); 


select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_null;  --24616

    select 24616 + 15095 as addition --39711


--now those with TM who have no t - can only make conclusions about the left ear in this group 

drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null as
(select * from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull
  where
(bc_l500t is NULL and bc_l1000t is NULL)
  or
(bc_l1000t is NULL and bc_l2000t is NULL) 
  or
( bc_l500t is NULl and  bc_l2000t is NULL)); 

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null; --9525

    
--now those with TM and T - can make conclusions about left and right ears 

drop table  if existsdata_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull as
(select * from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull 
  where 
(bc_l500t NOTNULL and bc_l1000t NOTNULL)
  or
(bc_l1000t NOTNULL and bc_l2000t NOTNULL) 
  or
( bc_l500t NOTNULl and  bc_l2000t NOTNULL));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull; --5570

select 9525 + 5570 as "addition"; --15095 - perfect


---now lets see how many from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null have no abg

alter table data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null
add column l500_abg smallint,
add column l1000_abg smallint,
add column l2000_abg smallint,
add column r500_abg smallint,
add column r1000_abg smallint,
add column r2000_abg smallint;

-- do not include right ABG because this is impossible to have as the bc is masked for left 
update data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null
set l500_abg = (ac_l500 - bc_l500tm),
l1000_abg = (ac_l1000 - bc_l1000tm),
l2000_abg = (ac_l2000 - bc_l2000tm);


select * from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null;

drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LSNHL as 
select * from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null
  where 
  ((l500_abg < 25 and l1000_abg < 25) OR
  (l500_abg < 25 and l2000_abg < 25) OR
  (l1000_abg < 25 and l2000_abg < 25));

    select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LSNHL; --6284

    
drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LCHL;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LCHL as 
select * from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null
  where 
  ((l500_abg >= 25 and l1000_abg >= 25) OR
  (l500_abg >=25 and l2000_abg >= 25) OR
  (l1000_abg >= 25 and l2000_abg >= 25));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LCHL; --2857

---those who dont meet criteria for CHL on left 

drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_l1freq;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_l1freq
  as 
(select * from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null
    where
((l500_abg >= 25 and l1000_abg < 25 and l2000_abg is null) OR
  (l500_abg >= 25 and l1000_abg is null and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg >= 25 and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >= 25) OR
(l500_abg < 25 and l1000_abg >= 25 and l2000_abg is null) or
(l500_abg < 25 and l1000_abg is null and l2000_abg >= 25)));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_l1freq; --384


select 384 + + 2857 + 6284 as "Addition"; --9525 (perfect)



------------------- now lets turn our attention to those with left BC tm (masked) and t (unmasked )
  -- now unlike earlier we can actually keep records with right AC complete as the unmasked BC may correpond to that

---now lets see how many from data_acbc_ac250to8000_bc2freq_l_tm_notnull_t_null have no abg

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull; --5570
alter table data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
add column l500_abg smallint,
add column l1000_abg smallint,
add column l2000_abg smallint,
add column r500_abg smallint,
add column r1000_abg smallint,
add column r2000_abg smallint;

update data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
set l500_abg = (ac_l500 - bc_l500tm),
l1000_abg = (ac_l1000 - bc_l1000tm),
l2000_abg = (ac_l2000 - bc_l2000tm),
r500_abg = (ac_r500 - bc_l500t),
r1000_abg = (ac_r1000 - bc_l1000t),
r2000_abg = (ac_r2000 - bc_l2000t);

--find those with no ABG on left - just use the masked tm 


drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LSNHL as 
select * from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
  where 
  ((l500_abg < 25 and l1000_abg < 25) OR
  (l500_abg < 25 and l2000_abg < 25) OR
  (l1000_abg < 25 and l2000_abg < 25)) and
((r500_abg >= 25 and r1000_abg >= 25) OR
  (r500_abg >= 25 and r2000_abg >= 25) OR
  (r1000_abg >= 25 and r2000_abg >= 25));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LSNHL; --87

    
drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRSNHL as 
select * from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
  where 
  (((l500_abg < 25 and l1000_abg < 25) OR
  (l500_abg < 25 and l2000_abg < 25) OR
  (l1000_abg < 25 and l2000_abg < 25)) AND
((r500_abg <25 and r1000_abg <25 ) OR
  (r500_abg <25  and r2000_abg <25 ) OR
  (r1000_abg <25  and r2000_abg <25 )));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRSNHL; --3551

    
---now where right only has no ABG

    drop table  if existsdata_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_RSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_RSNHL as 
select * from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
  where 
((r500_abg <25 and r1000_abg <25 ) OR
  (r500_abg <25  and r2000_abg <25 ) OR
  (r1000_abg <25  and r2000_abg <25 )) and 
((l500_abg >= 25 and l1000_abg >= 25) OR
  (l500_abg >= 25 and l2000_abg >= 25) OR
  (l1000_abg >= 25 and l2000_abg >= 25));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_RSNHL; --1471

    ---CHL both sides 

        drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRCHL;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRCHL as 
select * from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
  where 
((r500_abg >=25 and r1000_abg >=25 ) OR
  (r500_abg >=25  and r2000_abg >=25 ) OR
  (r1000_abg >=25  and r2000_abg >=25 )) and 
((l500_abg >= 25 and l1000_abg >= 25) OR
  (l500_abg >= 25 and l2000_abg >= 25) OR
  (l1000_abg >= 25 and l2000_abg >= 25));

    select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRCHL; #176

    --- incomplete left and right
drop table a;

create table a
  as
  (select * from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull
    where
((l500_abg >= 25 and l1000_abg < 25 and l2000_abg is null) OR
  (l500_abg >= 25 and l1000_abg is null and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg >= 25 and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >= 25) OR
(l500_abg < 25 and l1000_abg >= 25 and l2000_abg is null) or
(l500_abg < 25 and l1000_abg is null and l2000_abg >= 25)) or
((r500_abg >= 25 and r1000_abg <25 and r2000_abg is null) OR
  (r500_abg >= 25 and r1000_abg is null and r2000_abg <25) OR
  (r500_abg is null and r1000_abg >=25 and r2000_abg <25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >=25) OR
(r500_abg <25 and r1000_abg >=25 and r2000_abg is null) or
(r500_abg <25and r1000_abg is null and r2000_abg >=25)));

  select count(*) from a; --285

    

    select  87 + 3551 + 1471 + 285+ 176 as addition; --5570 bang on 

    ##now from 285 I can take the ones with SNHL on left and right 

drop table if exists b;
create table b 
    as 
select *
from a
  where 
((l500_abg < 25 and l1000_abg <  25) OR
  (l500_abg <  25 and l2000_abg<  25) OR
  (l1000_abg < 25 and l2000_abg <  25));

    select count(*) from b; --3

                drop table c if exists;
    create table c
    as 
select *
from a
  where 
((r500_abg < 25 and r1000_abg <  25) OR
  (r500_abg <  25 and r2000_abg<  25) OR
  (r1000_abg < 25 and r2000_abg <  25));
select count(*) from c; --258

drop table if exists bb;
create table bb as 
select * from a 
where
  (((l500_abg >= 25 and l1000_abg >=  25) OR
  (l500_abg >=  25 and l2000_abg >= 25) OR
  (l1000_abg >= 25 and l2000_abg >= 25)) and
                ((r500_abg >= 25 and r1000_abg <25 and r2000_abg is null) OR
  (r500_abg >= 25 and r1000_abg is null and r2000_abg <25) OR
  (r500_abg is null and r1000_abg >=25 and r2000_abg <25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >=25) OR
(r500_abg <25 and r1000_abg >=25 and r2000_abg is null) or
(r500_abg <25and r1000_abg is null and r2000_abg >=25)));


select count(*) from bb;  --5 = L CHL, R incom
 
drop table if exists cc;
create table cc as 
select * from a 
where
  (r500_abg >= 25 and r1000_abg >=  25) OR
  (r500_abg >=  25 and r2000_abg >= 25) OR
  (r1000_abg >= 25 and r2000_abg >= 25);
select count(*) from cc;  --16 = R CHL, L incom

drop table if exists aa;
create table aa as 
select * from a 
where
     (((r500_abg >= 25 and r1000_abg <25 and r2000_abg is null) OR
  (r500_abg >= 25 and r1000_abg is null and r2000_abg <25) OR
  (r500_abg is null and r1000_abg >=25 and r2000_abg <25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >=25) OR
(r500_abg <25 and r1000_abg >=25 and r2000_abg is null) or
(r500_abg <25and r1000_abg is null and r2000_abg >=25)) 
                and 
                   ((l500_abg >= 25 and l1000_abg <25 and l2000_abg is null) OR
  (l500_abg >= 25 and l1000_abg is null and l2000_abg <25) OR
  (l500_abg is null and l1000_abg >=25 and l2000_abg <25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >=25) OR
(l500_abg <25 and l1000_abg >=25 and l2000_abg is null) or
(l500_abg <25and l1000_abg is null and l2000_abg >=25)));
                ;
select count(*) from aa; --3 = L + R incomp

      

----------------------- now create SNHL for all those with BC only done on left 
-------create table of all those with bl BC that have SNHL loss and create seperate table of those with CHL

drop table if exists data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL;

  create table data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL
  (patient_id int,
  audindex smallint,
  investdate date, sex varchar, age int,
 ac_l250 smallint,
  ac_l500 smallint,
  ac_l1000 smallint,
  ac_l2000 smallint,
  ac_l4000 smallint,
  ac_l8000 smallint,
  ac_r250 smallint,
  ac_r500 smallint,
  ac_r1000 smallint,
  ac_r2000 smallint,
  ac_r4000 smallint,
  ac_r8000 smallint
);

insert into data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
  patient_id, audindex,  investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from 
   data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LSNHL;

 select count (*) from data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL; -- 6284

    

-- now insert data_acbc_join_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_RSNHL ear only

insert into data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
  patient_id, audindex,  investdate, sex, age,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from 
    data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_RSNHL;

 select count (*) from  data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL; -- 7755 (6284 + 1471)
    
-- now insert data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LSNHL left ear only

insert into data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
  patient_id, audindex,  investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from 
 data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LSNHL;

 select count (*) from data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL; --7842 (7755 +87) 


-- now insert data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRSNHL both ears 

insert into  data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
  patient_id, audindex,  investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from 
 data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRSNHL;

 select count (*) from  data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL; --113934 (7842 + 3551) 

     select 11403 - 7852 as subtraction;

    

-- -- now insert b keep left only 
insert into data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
  patient_id, audindex,  investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from 
b;
  

    select count (*) from  data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL; --11396 (11393 + 3)

    insert into data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
  patient_id, audindex,  investdate, sex, age,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from 
c;

    select count (*) from  data_acbc_ac250to8000_bl_bc500to2000_LBC_SNHL; --11654



    
---------------------now lets focus on those with just BC on the left but this time only unmasked has been done

  select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_null;  --24663

    select * from
    data_acbc_ac250to8000_bl_bc2freq_l_tm_null
where 
     (bc_l500t is null and bc_l1000t is null)
    or
    (bc_l1000t is null and bc_l2000t is null)
    or
    (bc_l500t is null and bc_l2000t is null);
  

  alter table  data_acbc_ac250to8000_bl_bc2freq_l_tm_null
add column l500_abg smallint,
add column l1000_abg smallint,
add column l2000_abg smallint,
add column r500_abg smallint,
add column r1000_abg smallint,
add column r2000_abg smallint;

update   data_acbc_ac250to8000_bl_bc2freq_l_tm_null
set l500_abg = (ac_l500 - bc_l500t),
l1000_abg = (ac_l1000 - bc_l1000t),
l2000_abg = (ac_l2000 - bc_l2000t),
r500_abg = (ac_r500 - bc_l500t),
r1000_abg = (ac_r1000 - bc_l1000t),
r2000_abg = (ac_r2000 - bc_l2000t);



-- now look at  where L and R both have SNHL
  drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LRSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LRSNHL as 
select 
  patient_id, audindex, investdate, sex, age,
   ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
   ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_l500t,   bc_l1000t,   bc_l2000t
  from 
    data_acbc_ac250to8000_bl_bc2freq_l_tm_null
  where 
  ((l500_abg < 25 and l1000_abg <25) OR
  (l500_abg < 25 and l2000_abg <25) OR
  (l1000_abg <25 and l2000_abg <25)) and
    ((r500_abg <25and r1000_abg <25) OR
  (r500_abg <25 and r2000_abg <25) OR
  (r1000_abg <25 and r2000_abg <25));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LRSNHL; --20808 


    --- where left SNHL and right CHL

      drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LSNHL as 
select 
  patient_id, audindex, investdate, sex, age,
   ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
   bc_l500t,   bc_l1000t,   bc_l2000t
  from data_acbc_ac250to8000_bl_bc2freq_l_tm_null
  where 
  ((l500_abg <25 and l1000_abg <25) OR
  (l500_abg <25 and l2000_abg <25) OR
  (l1000_abg <25 and l2000_abg <25))AND
    ((r500_abg >=25and r1000_abg >=25) OR
  (r500_abg >=25 and r2000_abg >=25) OR
  (r1000_abg >=25 and r2000_abg >=25)) ;

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LSNHL; --1081

 
        --- where right SNHL and left CHL

      drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RSNHL as 
select 
  patient_id, audindex, investdate, sex, age,
   ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_l500t,   bc_l1000t,   bc_l2000t
  from data_acbc_ac250to8000_bl_bc2freq_l_tm_null
  where 
  ((r500_abg <25 and r1000_abg <25) OR
  (r500_abg <25 and r2000_abg <25) OR
  (r1000_abg <25 and r2000_abg <25))AND
    ((l500_abg >=25and l1000_abg >=25) OR
  (l500_abg >=25 and l2000_abg >=25) OR
  (l1000_abg >=25 and l2000_abg >=25)) ;

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RSNHL; --608

       --- where right CHL and left CHL

      drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RLCHL;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RLCHL as 
select 
  patient_id, audindex, investdate, sex, age,
   ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_l500t,   bc_l1000t,   bc_l2000t
  from data_acbc_ac250to8000_bl_bc2freq_l_tm_null
  where 
  ((r500_abg >=25 and r1000_abg >=25) OR
  (r500_abg >=25 and r2000_abg >=25) OR
  (r1000_abg >=25 and r2000_abg >=25))AND
    ((l500_abg >=25and l1000_abg >=25) OR
  (l500_abg >=25 and l2000_abg >=25) OR
  (l1000_abg >=25 and l2000_abg >=25)) ;

select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RLCHL; --1821

 

    --- now where chl does not meet criteria for left and right 

  drop table if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq;
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq
  as 
(select * from data_acbc_ac250to8000_bl_bc2freq_l_tm_null
    where
((l500_abg >=25 and l1000_abg <25 and l2000_abg is null) OR
  (l500_abg >=25 and l1000_abg is null and l2000_abg <25) OR
  (l500_abg is null and l1000_abg >=25 and l2000_abg <25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >=25) OR
(l500_abg <25 and l1000_abg >=25 and l2000_abg is null) or
(l500_abg <25 and l1000_abg is null and l2000_abg >=25)) or
((r500_abg >=25 and r1000_abg <25 and r2000_abg is null) OR
  (r500_abg >=25 and r1000_abg is null and r2000_abg <25) OR
  (r500_abg is null and r1000_abg >=25 and r2000_abg <25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >=25) OR
(r500_abg <25 and r1000_abg >=25 and r2000_abg is null) or
(r500_abg <25 and r1000_abg is null and r2000_abg >=25))) ;

    select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq #186


    ##now from 188 I can take the ones with SNHL on left and right 

drop table if exists d;
create table d
    as 
select *
from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq
  where 
((l500_abg < 25 and l1000_abg <  25) OR
  (l500_abg <  25 and l2000_abg<  25) OR
  (l1000_abg < 25 and l2000_abg <  25));

    select count(*) from d; --35

                drop table if exists e;
    create table e
    as 
select *
from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq
  where 
((r500_abg < 25 and r1000_abg <  25) OR
  (r500_abg <  25 and r2000_abg<  25) OR
  (r1000_abg < 25 and r2000_abg <  25));
select count(*) from e; --72


drop table if exists dd;
create table dd as 
select *
from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq
  where 
((l500_abg >= 25 and l1000_abg >=  25) OR
  (l500_abg >=   25 and l2000_abg>=   25) OR
  (l1000_abg >=  25 and l2000_abg >=   25));
                                         
select count(*) from dd; --= 16 = L CHL, R incom for L BCt

select count(*) from ee; --18 = R CHL, L incom for L BCt

drop table if exists ee;
create table ee as 
select *
from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq
  where 
((r500_abg >= 25 and r1000_abg >=  25) OR
  (r500_abg >=   25 and r2000_abg>=   25) OR
  (r1000_abg >=  25 and r2000_abg >=   25));
                select count(*) from ee; --= 16 = R CHL, L incom for L BCt


drop table if exists eee;
create table eee as 
select *
from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_bl1freq
  where 
(((l500_abg >=25 and l1000_abg <25 and l2000_abg is null) OR
  (l500_abg >=25 and l1000_abg is null and l2000_abg <25) OR
  (l500_abg is null and l1000_abg >=25 and l2000_abg <25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >=25) OR
(l500_abg <25 and l1000_abg >=25 and l2000_abg is null) or
(l500_abg <25 and l1000_abg is null and l2000_abg >=25)) and
((r500_abg >=25 and r1000_abg <25 and r2000_abg is null) OR
  (r500_abg >=25 and r1000_abg is null and r2000_abg <25) OR
  (r500_abg is null and r1000_abg >=25 and r2000_abg <25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >=25) OR
(r500_abg <25 and r1000_abg >=25 and r2000_abg is null) or
(r500_abg <25 and r1000_abg is null and r2000_abg >=25))) ;

select count(*) from aaa; --47 = R + L incomp for L unmasked


    drop table  if exists data_acbc_ac250to8000_bl_bc2freq_l_tm_null_null
create table data_acbc_ac250to8000_bl_bc2freq_l_tm_null_null
    as 
    select  patient_id, audindex, investdate, sex, age,
   ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_l500t,   bc_l1000t,   bc_l2000t
    from
    data_acbc_ac250to8000_bl_bc2freq_l_tm_null
where 
     (l500_abg isnull and l2000_abg is null) OR
    (l500_abg isnull and l1000_abg is null) OR
    (l1000_abg isnull and l2000_abg is null);



    select count(*) from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_null #112


  select 20808 + 1081 + 608 + 1821 + 186 + 112 as addition --24616

    
   
    -------------------------------------------------------------------------
    --------------------------------------- now lets look at those who can be kept who have AC both ears and BC in right ear 


select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_lincom; --43106

    
drop table if exists data_acbc_ac250to8000_bl_bc500to2000_bc2freq_r_oneperfreq;
create table data_acbc_ac250to8000_bl_bc500to2000_bc2freq_r_oneperfreq
  (patient_id int,
  audindex smallint,
  investdate date, sex varchar, age int,
 ac_l250 smallint,
  ac_l500 smallint,
  ac_l1000 smallint,
  ac_l2000 smallint,
  ac_l4000 smallint,
  ac_l8000 smallint,
  ac_r250 smallint,
  ac_r500 smallint,
  ac_r1000 smallint,
  ac_r2000 smallint,
  ac_r4000 smallint,
  ac_r8000 smallint,
bc_r500t smallint,
  bc_r1000t smallint,
  bc_r2000t smallint,
bc_r500tm smallint,
  bc_r1000tm smallint,
  bc_r2000tm smallint);


    insert into data_acbc_ac250to8000_bl_bc500to2000_bc2freq_r_oneperfreq
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_r500t,   bc_r1000t,   bc_r2000t,
   bc_r500tm,   bc_r1000tm,   bc_r2000tm
)
select 
ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
case when ac_l250tm notnull then ac_l250tm else ac_l250t end,
    case when ac_l500tm notnull then ac_l500tm else ac_l500t end, 
    case when ac_l1000tm notnull then ac_l1000tm else ac_l1000t end,
    case when ac_l2000tm notnull then ac_l2000tm else ac_l2000t end,
    case when ac_l4000tm notnull then ac_l4000tm else ac_l4000t end, 
    case when ac_l8000tm notnull then ac_l8000tm else ac_l8000t end,
    case when ac_r250tm notnull then ac_r250tm else ac_r250t end,
    case when ac_r500tm notnull then ac_r500tm else ac_r500t end, 
    case when ac_r1000tm notnull then ac_r1000tm else ac_r1000t end,
    case when ac_r2000tm notnull then ac_r2000tm else ac_r2000t end,
 case when ac_r4000tm notnull then ac_r4000tm else ac_r4000t end,
    case when ac_r8000tm notnull then ac_r8000tm else ac_r8000t end,
    bc_r500t, bc_r1000t, bc_r2000t,
    bc_r500tm , bc_r1000tm , bc_r2000tm
from data_acbc_ac250to8000_bl_bc2freq_r_lincom;

select count(*) from data_acbc_ac250to8000_bl_bc500to2000_bc2freq_r_oneperfreq; --43106

    --create table where tm notnul

drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull as
select * from data_acbc_ac250to8000_bl_bc500to2000_bc2freq_r_oneperfreq where 
(bc_r500tm NOTNULL and bc_r1000tm NOTNULL)
  or
(bc_r1000tm NOTNULL and bc_r2000tm NOTNULL) 
  or
( bc_r500tm NOTNULl and  bc_r2000tm NOTNULL); 


select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull;  --14803


    --create table where tm is null 

drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_null;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_null as
select * from data_acbc_ac250to8000_bl_bc500to2000_bc2freq_r_oneperfreq where 
(bc_r500tm is NULL and bc_r1000tm is NULL)
  or
(bc_r1000tm is NULL and bc_r2000tm is NULL) 
  or
( bc_r500tm is NULl and  bc_r2000tm is NULL); 


select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_null;  --28303

    select 28303 + 14803 as addition; --43106


--now those with TM who have no t - can only make conclusions about the rightt ear in this group 

drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null as
(select * from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull
  where
(bc_r500t is NULL and bc_r1000t is NULL)
  or
(bc_r1000t is NULL and bc_r2000t is NULL) 
  or
( bc_r500t is NULl and  bc_r2000t is NULL)); 

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null; --9644

    
--now those with TM and T - can make conclusions about left and right ears 

drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull as
(select * from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull 
  where 
(bc_r500t NOTNULL and bc_r1000t NOTNULL)
  or
(bc_r1000t NOTNULL and bc_r2000t NOTNULL) 
  or
( bc_r500t NOTNULl and  bc_r2000t NOTNULL));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull; --5159

select 9644 + 5159 as "addition"; --14803- perfect


---now lets see how many from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null have no abg

alter table data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null
add column l500_abg smallint,
add column l1000_abg smallint,
add column l2000_abg smallint,
add column r500_abg smallint,
add column r1000_abg smallint,
add column r2000_abg smallint;

-- do not include right ABG because this is impossible to have as the bc is masked for left 
update data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null
set r500_abg = (ac_r500 - bc_r500tm),
r1000_abg = (ac_r1000 - bc_r1000tm),
r2000_abg = (ac_r2000 - bc_r2000tm);


drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rSNHL as 
select * from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null
  where 
  ((r500_abg < 25 and r1000_abg < 25) OR
  (r500_abg < 25 and r2000_abg < 25) OR
  (r1000_abg < 25 and r2000_abg < 25));

    select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rSNHL; #6278

    
drop table if exists  data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rCHL;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rCHL as 
select * from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null
  where 
  ((r500_abg >= 25 and r1000_abg >= 25) OR
  (r500_abg >=25 and r2000_abg >= 25) OR
  (r1000_abg >= 25 and r2000_abg >= 25));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rCHL; --2984

---those who dont meet criteria for CHL on right

drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_r1freq;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_r1freq
  as 
(select * from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null
    where
((r500_abg >= 25 and r1000_abg < 25 and r2000_abg is null) OR
  (r500_abg >= 25 and r1000_abg is null and r2000_abg < 25) OR
  (r500_abg is null and r1000_abg >= 25 and r2000_abg < 25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >= 25) OR
(r500_abg < 25 and r1000_abg >= 25 and r2000_abg is null) or
(r500_abg < 25 and r1000_abg is null and r2000_abg >= 25)));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_r1freq; --388


select 388 + + 2984 + 6272 as "Addition"; --9644 (perfect)



------------------- now lets turn our attention to those with left BC tm and t
  -- now unlike earlier we can actually keep records withleft AC complete as the unmasked BC may correpond to that

---now lets see how many from data_acbc_ac250to8000_bc2freq_r_tm_notnull_t_null have no abg

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull;--5159
alter table data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
add column l500_abg smallint,
add column l1000_abg smallint,
add column l2000_abg smallint,
add column r500_abg smallint,
add column r1000_abg smallint,
add column r2000_abg smallint;

update data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
set l500_abg = (ac_l500 - bc_r500tm),
l1000_abg = (ac_l1000 - bc_r1000tm),
l2000_abg = (ac_l2000 - bc_r2000tm),
r500_abg = (ac_r500 - bc_r500t),
r1000_abg = (ac_r1000 - bc_r1000t),
r2000_abg = (ac_r2000 - bc_r2000t);

--find those with no ABG on right - just use the masked tm 


drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_rSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_rSNHL as 
select * from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
  where 
  ((r500_abg < 25 and r1000_abg < 25) OR
  (r500_abg < 25 and r2000_abg < 25) OR
  (r1000_abg < 25 and r2000_abg < 25)) and
((l500_abg >= 25 and l1000_abg >= 25) OR
  (l500_abg >= 25 and l2000_abg >= 25) OR
  (l1000_abg >= 25 and l2000_abg >= 25));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_rSNHL; --5

    
drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRSNHL as 
select * from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
  where 
  (((l500_abg < 25 and l1000_abg < 25) OR
  (l500_abg < 25 and l2000_abg < 25) OR
  (l1000_abg < 25 and l2000_abg < 25)) AND
((r500_abg <25 and r1000_abg <25 ) OR
  (r500_abg <25  and r2000_abg <25 ) OR
  (r1000_abg <25  and r2000_abg <25 )));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRSNHL; --1809

    
---now where left only has no ABG

    drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_lSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_lSNHL as 
select * from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
  where 
((l500_abg <25 and l1000_abg <25 ) OR
  (l500_abg <25  and l2000_abg <25 ) OR
  (l1000_abg <25  and l2000_abg <25 )) and 
((r500_abg >= 25 and r1000_abg >= 25) OR
  (r500_abg >= 25 and r2000_abg >= 25) OR
  (r1000_abg >= 25 and r2000_abg >= 25));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_lSNHL; --3144

    ---CHL both sides 

        drop table if existsdata_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRCHL;
create table data_acbc_ac250 to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRCHL as 
select * from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
  where 
((r500_abg >=25 and r1000_abg >=25 ) OR
  (r500_abg >=25  and r2000_abg >=25 ) OR
  (r1000_abg >=25  and r2000_abg >=25 )) and 
((l500_abg >= 25 and l1000_abg >= 25) OR
  (l500_abg >= 25 and l2000_abg >= 25) OR
  (l1000_abg >= 25 and l2000_abg >= 25));

    select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRCHL; #89

    --- incomplete left and right
drop table if exists f;
create table f
  as
  (select * from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull
    where
((l500_abg >= 25 and l1000_abg < 25 and l2000_abg is null) OR
  (l500_abg >= 25 and l1000_abg is null and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg >= 25 and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >= 25) OR
(l500_abg < 25 and l1000_abg >= 25 and l2000_abg is null) or
(l500_abg < 25 and l1000_abg is null and l2000_abg >= 25)) or
((r500_abg >= 25 and r1000_abg <25 and r2000_abg is null) OR
  (r500_abg >= 25 and r1000_abg is null and r2000_abg <25) OR
  (r500_abg is null and r1000_abg >=25 and r2000_abg <25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >=25) OR
(r500_abg <25 and r1000_abg >=25 and r2000_abg is null) or
(r500_abg <25and r1000_abg is null and r2000_abg >=25)));

  select count(*) from f; --119

    

    select  5 + 1808 + 3138 + 89 + 119 as addition; --5159 bang on 

    --now from 119 I can take the ones with SNHL on left and right 

drop table if exists g;
create table g
    as 
select *
from f
  where 
((l500_abg < 25 and l1000_abg <  25) OR
  (l500_abg <  25 and l2000_abg<  25) OR
  (l1000_abg < 25 and l2000_abg <  25));

    select count(*) from g; --53

    drop table if exists h;
    create table h
    as 
select *
from f
  where 
((r500_abg < 25 and r1000_abg <  25) OR
  (r500_abg <  25 and r2000_abg<  25) OR
  (r1000_abg < 25 and r2000_abg <  25));
select count(*) from h; #20

                 drop table if exists gg;
    create table gg
    as 
select *
from f
  where 
((l500_abg >= 25 and l1000_abg >=  25) OR
  (l500_abg >=  25 and l2000_abg>=  25) OR
  (l1000_abg >= 25 and l2000_abg >=  25));
select count(*) from gg;

              drop table if exists hh;
    create table hh
    as 
select *
from f
  where 
((r500_abg >= 25 and r1000_abg >=  25) OR
  (r500_abg >=  25 and r2000_abg>=  25) OR
  (r1000_abg >= 25 and r2000_abg >=  25));
select count(*) from hh;  --43

     drop table if exists ff;
    create table fff
    as 
select *
from f
  where 
((l500_abg >=25 and l1000_abg <25 and l2000_abg is null) OR
  (l500_abg >=25 and l1000_abg is null and l2000_abg <25) OR
  (l500_abg is null and l1000_abg >=25 and l2000_abg <25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >=25) OR
(l500_abg <25 and l1000_abg >=25 and l2000_abg is null) or
(l500_abg <25 and l1000_abg is null and l2000_abg >=25)) and
((r500_abg >=25 and r1000_abg <25 and r2000_abg is null) OR
  (r500_abg >=25 and r1000_abg is null and r2000_abg <25) OR
  (r500_abg is null and r1000_abg >=25 and r2000_abg <25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >=25) OR
(r500_abg <25 and r1000_abg >=25 and r2000_abg is null) or
(r500_abg <25 and r1000_abg is null and r2000_abg >=25));



 select count(*) from fff; --1     

select 1 + 2 + 43 + 20 + 53; --119

----------------------- now create SNHL for all those with BC only done on right
-------create table of all those with bl BC that have SNHL loss and create seperate table of those with CHL
    
---------------------now lets focus on those with just BC on the right but this time only unmasked has been done

  select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_null;  --28303

    select * from
    data_acbc_ac250to8000_bl_bc2freq_r_tm_null
where 
     (bc_r500t is null and bc_r1000t is null)
    or
    (bc_r1000t is null and bc_r2000t is null)
    or
    (bc_r500t is null and bc_r2000t is null); --100
  

  alter table  data_acbc_ac250to8000_bl_bc2freq_r_tm_null
add column l500_abg smallint,
add column l1000_abg smallint,
add column l2000_abg smallint,
add column r500_abg smallint,
add column r1000_abg smallint,
add column r2000_abg smallint;

update   data_acbc_ac250to8000_bl_bc2freq_r_tm_null
set l500_abg = (ac_l500 - bc_r500t),
l1000_abg = (ac_l1000 - bc_r1000t),
l2000_abg = (ac_l2000 - bc_r2000t),
r500_abg = (ac_r500 - bc_r500t),
r1000_abg = (ac_r1000 - bc_r1000t),
r2000_abg = (ac_r2000 - bc_r2000t);



-- now look at  where L and R both have SNHL
  drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_null_LRSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_null_LRSNHL as 
select 
  patient_id, audindex, investdate, sex, age,
   ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
   ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_r500t,   bc_r1000t,   bc_r2000t
  from 
    data_acbc_ac250to8000_bl_bc2freq_r_tm_null
  where 
  ((l500_abg < 25 and l1000_abg <25) OR
  (l500_abg < 25 and l2000_abg <25) OR
  (l1000_abg <25 and l2000_abg <25)) and
    ((r500_abg <25and r1000_abg <25) OR
  (r500_abg <25 and r2000_abg <25) OR
  (r1000_abg <25 and r2000_abg <25));

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_null_LRSNHL; --23445


    --- where left cHL and right snHL

      drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_null_rSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_null_rSNHL as 
select 
  patient_id, audindex, investdate, sex, age,
   ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_r500t,   bc_r1000t,   bc_r2000t
  from data_acbc_ac250to8000_bl_bc2freq_r_tm_null
  where 
  ((r500_abg <25 and r1000_abg <25) OR
  (r500_abg <25 and r2000_abg <25) OR
  (r1000_abg <25 and r2000_abg <25))AND
    ((l500_abg >=25and l1000_abg >=25) OR
  (l500_abg >=25 and l2000_abg >=25) OR
  (l1000_abg >=25 and l2000_abg >=25)) ;

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_null_rSNHL; --1200

 
        --- where left SNHL and right CHL

      drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_null_lSNHL;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_null_lSNHL as 
select 
  patient_id, audindex, investdate, sex, age,
   ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
   bc_r500t,   bc_r1000t,   bc_r2000t
  from data_acbc_ac250to8000_bl_bc2freq_r_tm_null
  where 
  ((l500_abg <25 and l1000_abg <25) OR
  (l500_abg <25 and l2000_abg <25) OR
  (l1000_abg <25 and l2000_abg <25))AND
    ((r500_abg >=25and r1000_abg >=25) OR
  (r500_abg >=25 and r2000_abg >=25) OR
  (r1000_abg >=25 and r2000_abg >=25)) ;

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_null_lSNHL; --753

       --- where left CHL and left CHL

      drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_null_RLCHL;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_null_RLCHL as 
select 
  patient_id, audindex, investdate, sex, age,
   ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_r500t,   bc_r1000t,   bc_r2000t
  from data_acbc_ac250to8000_bl_bc2freq_r_tm_null
  where 
  ((r500_abg >=25 and r1000_abg >=25) OR
  (r500_abg >=25 and r2000_abg >=25) OR
  (r1000_abg >=25 and r2000_abg >=25))AND
    ((l500_abg >=25and l1000_abg >=25) OR
  (l500_abg >=25 and l2000_abg >=25) OR
  (l1000_abg >=25 and l2000_abg >=25)) ;

select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_null_RLCHL; #2618

 

    --- now where chl does not meet criteria for left and right 

  drop table if exists data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq
  as 
(select * from data_acbc_ac250to8000_bl_bc2freq_r_tm_null
    where
((l500_abg >=25 and l1000_abg <25 and l2000_abg is null) OR
  (l500_abg >=25 and l1000_abg is null and l2000_abg <25) OR
  (l500_abg is null and l1000_abg >=25 and l2000_abg <25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >=25) OR
(l500_abg <25 and l1000_abg >=25 and l2000_abg is null) or
(l500_abg <25 and l1000_abg is null and l2000_abg >=25)) or
((r500_abg >=25 and r1000_abg <25 and r2000_abg is null) OR
  (r500_abg >=25 and r1000_abg is null and r2000_abg <25) OR
  (r500_abg is null and r1000_abg >=25 and r2000_abg <25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >=25) OR
(r500_abg <25 and r1000_abg >=25 and r2000_abg is null) or
(r500_abg <25 and r1000_abg is null and r2000_abg >=25))) ;

    select count(*) from data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq; --187

select 187 + 2618 + 753 + 1200 + 23445 + 100; --28303



 ------now from 187 I can take the ones with SNHL on left and right 

drop table  if exists i;
create table i
    as 
select *
from data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq
  where 
((l500_abg < 25 and l1000_abg <  25) OR
  (l500_abg <  25 and l2000_abg<  25) OR
  (l1000_abg < 25 and l2000_abg <  25));

    select count(*) from i; --94

    drop table if exists ii;
    create table ii
    as 
select *
from data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq
  where 
((l500_abg >= 25 and l1000_abg>= 25) OR
  (l500_abg >=  25 and l2000_abg>=  25) OR
  (l1000_abg >= 25 and l2000_abg >=  25));
select count(*) from ii; --14

                  drop table if exists j;
    create table j
    as 
select *
from data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq
  where 
((r500_abg < 25 and r1000_abg <  25) OR
  (r500_abg <  25 and r2000_abg<  25) OR
  (r1000_abg < 25 and r2000_abg <  25));
select count(*) from j; --39


drop table if exists jj;
    create table jj
    as 
select *
from data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq
  where 
((r500_abg >= 25 and r1000_abg>= 25) OR
  (r500_abg >=  25 and r2000_abg>=  25) OR
  (r1000_abg >= 25 and r2000_abg >=  25));
select count(*) from jj; --7

                drop table if exists iii;
    create table iii
    as 
select *
from data_acbc_ac250to8000_bl_bc2freq_r_tm_null_bl1freq
  where 
((l500_abg >= 25 and l1000_abg < 25 and l2000_abg is null) OR
  (l500_abg >= 25 and l1000_abg is null and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg >= 25 and l2000_abg < 25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >= 25) OR
(l500_abg < 25 and l1000_abg >= 25 and l2000_abg is null) or
(l500_abg < 25 and l1000_abg is null and l2000_abg >= 25)) and
((r500_abg >= 25 and r1000_abg <25 and r2000_abg is null) OR
  (r500_abg >= 25 and r1000_abg is null and r2000_abg <25) OR
  (r500_abg is null and r1000_abg >=25 and r2000_abg <25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >=25) OR
(r500_abg <25 and r1000_abg >=25 and r2000_abg is null) or
(r500_abg <25and r1000_abg is null and r2000_abg >=25));

select count(*) from iii; --33



    drop table if exists  data_acbc_ac250to8000_bl_bc2freq_r_tm_null_null;
create table data_acbc_ac250to8000_bl_bc2freq_r_tm_null_null
    as 
    select  patient_id, audindex, investdate, sex, age,
   ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_r500t,   bc_r1000t,   bc_r2000t
    from
    data_acbc_ac250to8000_bl_bc2freq_r_tm_null
where 
     (r500_abg isnull and r2000_abg is null) OR
    (r500_abg isnull and r1000_abg is null) OR
    (r1000_abg isnull and r2000_abg is null);


 
   
  ----------------------- now create SNHL for all those with BC only done on right 
-------create table of all those with bl BC that have SNHL loss and create seperate table of those with CHL








    -------------------- now just for where AC done on left ear 

    
select count(*) from data_acbc_ac250to8000_l; --1797

select count(*) from data_acbc_ac250to8000_l_bc2freq_l; --1519

Select count(*) from data_acbc_ac250to8000_l_bc_lincom; --280 

    
drop table if exists data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq;
create table data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
  (patient_id int,
  audindex smallint,
  investdate date, sex varchar, age int,
 ac_l250 smallint,
  ac_l500 smallint,
  ac_l1000 smallint,
  ac_l2000 smallint,
  ac_l4000 smallint,
  ac_l8000 smallint,
  bc_l500 smallint,
  bc_l1000 smallint,
  bc_l2000 smallint);

    
insert into data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000, 
                bc_l500, bc_l1000,   bc_l2000)
select 
ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
case when ac_l250tm notnull then ac_l250tm else ac_l250t end,
    case when ac_l500tm notnull then ac_l500tm else ac_l500t end, 
    case when ac_l1000tm notnull then ac_l1000tm else ac_l1000t end,
    case when ac_l2000tm notnull then ac_l2000tm else ac_l2000t end,
    case when ac_l4000tm notnull then ac_l4000tm else ac_l4000t end, 
    case when ac_l8000tm notnull then ac_l8000tm else ac_l8000t end,
    case when bc_l500tm notnull then bc_l500tm else bc_l500t end, 
    case when bc_l1000tm notnull then bc_l1000tm else bc_l1000t end,
    case when bc_l2000tm notnull then bc_l2000tm else bc_l2000t end
from 
    data_acbc_ac250to8000_l_bc2freq_l;

select count(*) from data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq; 1519

    alter table data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
add column l500_abg smallint,
add column l1000_abg smallint,
add column l2000_abg smallint;

 
update data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
set l500_abg = (ac_l500 - bc_l500),
l1000_abg = (ac_l1000 - bc_l1000),
l2000_abg = (ac_l2000 - bc_l2000);


    drop table if exists data_acbc_ac250to8000_l_bc500to2000_bc2freq_LSNHL;
   create table data_acbc_ac250to8000_l_bc500to2000_bc2freq_LSNHL as 
select * from data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
  where 
  ((l500_abg < 25 and l1000_abg < 25) OR
  (l500_abg < 25 and l2000_abg < 25) OR
  (l1000_abg < 25 and l2000_abg < 25));

select count(*) from  data_acbc_ac250to8000_l_bc500to2000_bc2freq_LSNHL; 1050

        drop table if exists data_acbc_ac250to8000_l_bc500to2000_bc2freq_LCHL;
   create table data_acbc_ac250to8000_l_bc500to2000_bc2freq_LCHL as 
select * from data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
  where 
  ((l500_abg >= 25 and l1000_abg >= 25) OR
  (l500_abg >= 25 and l2000_abg >= 25) OR
  (l1000_abg >= 25 and l2000_abg >= 25));

    select count(*) from  data_acbc_ac250to8000_l_bc500to2000_bc2freq_LCHL; --466

    select 466 + 1050 + 3 as addition; --1519

  drop table if exists data_acbc_ac250to8000_l_bc500to2000_bc2freq_Lincom 
        create table data_acbc_ac250to8000_l_bc500to2000_bc2freq_Lincom as 
select * from data_acbc_ac250to8000_l_bc500to2000_bc2freq_oneperfreq
  where
(l500_abg >=25 and l1000_abg <25 and l2000_abg is null) OR
  (l500_abg >=25 and l1000_abg is null and l2000_abg <25) OR
  (l500_abg is null and l1000_abg >=25 and l2000_abg <25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >=25) OR
(l500_abg <25 and l1000_abg >=25 and l2000_abg is null) or
(l500_abg <25 and l1000_abg is null and l2000_abg >=25);

    select count(*) from data_acbc_ac250to8000_l_bc500to2000_bc2freq_Lincom; --3

                   select 466 + 1050 + 3 as addition; --1519

    --- now lets look at those where there is incomplete BC done for the left side 

Select * from data_acbc_ac250to8000_l_bc_lincom
    where 
    (bc_r1000t notnull and bc_r500t notnull) or
(bc_r1000t notnull and bc_r2000t notnull) or
    (bc_r2000t notnull and bc_r500t notnull); --169


        Select * from data_acbc_ac250to8000_l_bc_lincom
    where 
    (bc_r1000t is null and bc_r500t is null) or
(bc_r1000t is null and bc_r2000t is null) or
    (bc_r2000t is null and bc_r500t is null); --109

   select 169 + 109; --278

   ---create a table where abg is calculated using the rbc rathern than the left bc


drop table if exists data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq;
create table data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
  (patient_id int,
  audindex smallint,
  investdate date, sex varchar, age int,
 ac_l250 smallint,
  ac_l500 smallint,
  ac_l1000 smallint,
  ac_l2000 smallint,
  ac_l4000 smallint,
  ac_l8000 smallint,
bc_r500 smallint,
  bc_r1000 smallint,
  bc_r2000 smallint);

    
insert into data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
   bc_r500,   bc_r1000,   bc_r2000
)
select 
ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
case when ac_l250tm notnull then ac_l250tm else ac_l250t end,
    case when ac_l500tm notnull then ac_l500tm else ac_l500t end, 
    case when ac_l1000tm notnull then ac_l1000tm else ac_l1000t end,
    case when ac_l2000tm notnull then ac_l2000tm else ac_l2000t end,
    case when ac_l4000tm notnull then ac_l4000tm else ac_l4000t end, 
    case when ac_l8000tm notnull then ac_l8000tm else ac_l8000t end,
    bc_r500t, bc_r1000t, bc_r2000t
from 
    data_acbc_ac250to8000_l_bc_lincom
    where
       (bc_r1000t notnull and bc_r500t notnull) or
(bc_r1000t notnull and bc_r2000t notnull) or
    (bc_r2000t notnull and bc_r500t notnull);


    select count(*) from data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq; --169

alter table data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
add column l500_abg smallint,
add column l1000_abg smallint,
add column l2000_abg smallint;

 
update data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
set l500_abg = (ac_l500 - bc_r500),
l1000_abg = (ac_l1000 - bc_r1000),
l2000_abg = (ac_l2000 - bc_r2000);


    drop table if exists data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LSNHL;
   create table data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LSNHL as 
select * from data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
  where 
  ((l500_abg < 25 and l1000_abg < 25) OR
  (l500_abg < 25 and l2000_abg < 25) OR
  (l1000_abg < 25 and l2000_abg < 25));

select count(*) from  data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LSNHL; --126

---- how many using R bc that have l chl

     drop table if exists  data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LCHL;
   create table data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LCHL as 
select * from data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
  where 
  ((l500_abg >= 25 and l1000_abg >= 25) OR
  (l500_abg >= 25 and l2000_abg >= 25) OR
  (l1000_abg >= 25 and l2000_abg >= 25));

select count(*) from  data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LCHL; --40

                drop table if exists  data_acbc_ac250to8000_l_bc500to2000_bc2freqr_Lincom;
    create table data_acbc_ac250to8000_l_bc500to2000_bc2freqr_Lincom as 
select * from data_acbc_ac250to8000_l_bc500to2000_bc2freqr_oneperfreq
  where
(l500_abg >=25 and l1000_abg <25 and l2000_abg is null) OR
  (l500_abg >=25 and l1000_abg is null and l2000_abg <25) OR
  (l500_abg is null and l1000_abg >=25 and l2000_abg <25) OR
  (l500_abg is null and l1000_abg <25 and l2000_abg >=25) OR
(l500_abg <25 and l1000_abg >=25 and l2000_abg is null) or
(l500_abg <25 and l1000_abg is null and l2000_abg >=25);

    select count(*) from data_acbc_ac250to8000_l_bc500to2000_bc2freqr_Lincom; --3

    
    -------------------- now just for where AC done on right ear 

    
select count(*) from data_acbc_ac250to8000_r; --1663

select count(*) from data_acbc_ac250to8000_r_bc2freq_r; --1431

Select count(*) from data_acbc_ac250to8000_r_bc_rincom; --232



drop table if exists data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq;
create table data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
  (patient_id int,
  audindex smallint,
  investdate date, sex varchar, age int,
 ac_r250 smallint,
  ac_r500 smallint,
  ac_r1000 smallint,
  ac_r2000 smallint,
  ac_r4000 smallint,
  ac_r8000 smallint,
bc_r500 smallint,
  bc_r1000 smallint,
  bc_r2000 smallint);

    
insert into data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_r500,   bc_r1000,   bc_r2000
)
select 
ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
case when ac_r250tm notnull then ac_r250tm else ac_r250t end,
    case when ac_r500tm notnull then ac_r500tm else ac_r500t end, 
    case when ac_r1000tm notnull then ac_r1000tm else ac_r1000t end,
    case when ac_r2000tm notnull then ac_r2000tm else ac_r2000t end,
    case when ac_r4000tm notnull then ac_r4000tm else ac_r4000t end, 
    case when ac_r8000tm notnull then ac_r8000tm else ac_r8000t end,
    case when bc_r500tm notnull then bc_r500tm else bc_r500t end, 
    case when bc_r1000tm notnull then bc_r1000tm else bc_r1000t end,
    case when bc_r2000tm notnull then bc_r2000tm else bc_r2000t end
from 
    data_acbc_ac250to8000_r_bc2freq_r;

select count(*) from data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq; --1431

    alter table data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
add column r500_abg smallint,
add column r1000_abg smallint,
add column r2000_abg smallint;

 
update data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
set r500_abg = (ac_r500 - bc_r500),
r1000_abg = (ac_r1000 - bc_r1000),
r2000_abg = (ac_r2000 - bc_r2000);


    drop table if exists  data_acbc_ac250to8000_r_bc500to2000_bc2freq_rSNHL;
   create table data_acbc_ac250to8000_r_bc500to2000_bc2freq_rSNHL as 
select * from data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
  where 
  ((r500_abg < 25 and r1000_abg < 25) OR
  (r500_abg < 25 and r2000_abg < 25) OR
  (r1000_abg < 25 and r2000_abg < 25));

select count(*) from  data_acbc_ac250to8000_r_bc500to2000_bc2freq_rSNHL; 959

        drop table if exists  data_acbc_ac250to8000_r_bc500to2000_bc2freq_RCHL;
   create table data_acbc_ac250to8000_r_bc500to2000_bc2freq_RCHL as 
select * from data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
  where 
  ((r500_abg >= 25 and r1000_abg >= 25) OR
  (r500_abg >= 25 and r2000_abg >= 25) OR
  (r1000_abg >= 25 and r2000_abg >= 25));

    select count(*) from  data_acbc_ac250to8000_r_bc500to2000_bc2freq_rCHL; 469



                drop table if exists  data_acbc_ac250to8000_r_bc500to2000_bc2freq_Rincomp;
   create table data_acbc_ac250to8000_r_bc500to2000_bc2freq_Rincomp
    as 
    select * from data_acbc_ac250to8000_r_bc500to2000_bc2freq_oneperfreq
  where 
    (r500_abg >=25 and r1000_abg <25 and r2000_abg is null) OR
  (r500_abg >=25 and r1000_abg is null and r2000_abg <25) OR
  (r500_abg is null and r1000_abg >=25 and r2000_abg <25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >=25) OR
(r500_abg <25 and r1000_abg >=25 and r2000_abg is null) or
(r500_abg <25 and r1000_abg is null and r2000_abg >=25);

    select count(*) from data_acbc_ac250to8000_r_bc500to2000_bc2freq_Rincomp; --3
    select 469 + 959 + 3 as addition; --1428

    --- now lets look at those where there is incomplete BC done for the right side 

Select * from data_acbc_ac250to8000_r_bc_rincom
    where 
    (bc_l1000t notnull and bc_l500t notnull) or
(bc_l1000t notnull and bc_l2000t notnull) or
    (bc_l2000t notnull and bc_l500t notnull); --120


        Select * from data_acbc_ac250to8000_r_bc_rincom
    where 
    (bc_l1000t is null and bc_l500t is null) or
(bc_l1000t is null and bc_l2000t is null) or
    (bc_l2000t is null and bc_l500t is null); --112



   ---create a table where abg is calculated using the lbc rathern than the right bc


drop table if exists  data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq;
create table data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
  (patient_id int,
  audindex smallint,
  investdate date, sex varchar, age int,
 ac_r250 smallint,
  ac_r500 smallint,
  ac_r1000 smallint,
  ac_r2000 smallint,
  ac_r4000 smallint,
  ac_r8000 smallint,
bc_l500 smallint,
  bc_l1000 smallint,
  bc_l2000 smallint);

    
insert into data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
   bc_l500,   bc_l1000,   bc_l2000
)
select 
ac_patient_id, ac_audindex, ac_investdate, ac_sex, ac_age,
case when ac_r250tm notnull then ac_r250tm else ac_r250t end,
    case when ac_r500tm notnull then ac_r500tm else ac_r500t end, 
    case when ac_r1000tm notnull then ac_r1000tm else ac_r1000t end,
    case when ac_r2000tm notnull then ac_r2000tm else ac_r2000t end,
    case when ac_r4000tm notnull then ac_r4000tm else ac_r4000t end, 
    case when ac_r8000tm notnull then ac_r8000tm else ac_r8000t end,
    bc_l500t, bc_l1000t, bc_l2000t
from 
    data_acbc_ac250to8000_r_bc_rincom
    where
       (bc_l1000t notnull and bc_l500t notnull) or
(bc_l1000t notnull and bc_l2000t notnull) or
    (bc_l2000t notnull and bc_l500t notnull);


    select count(*) from data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq; --120

alter table data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
add column r500_abg smallint,
add column r1000_abg smallint,
add column r2000_abg smallint;

 
update data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
set r500_abg = (ac_r500 - bc_l500),
r1000_abg = (ac_r1000 - bc_l1000),
r2000_abg = (ac_r2000 - bc_l2000);


    drop table if exists  data_acbc_ac250to8000_r_bc500to2000_bc2freql_rSNHL;
   create table data_acbc_ac250to8000_r_bc500to2000_bc2freql_rSNHL as 
select * from data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
  where 
  ((r500_abg < 25 and r1000_abg < 25) OR
  (r500_abg < 25 and r2000_abg < 25) OR
  (r1000_abg < 25 and r2000_abg < 25));

select count(*) from  data_acbc_ac250to8000_r_bc500to2000_bc2freql_rSNHL; --95

---- how many using l bc that have r chl

     drop table if exists  data_acbc_ac250to8000_r_bc500to2000_bc2freql_rCHL;
   create table data_acbc_ac250to8000_r_bc500to2000_bc2freql_rCHL as 
select * from data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
  where 
  ((r500_abg >= 25 and r1000_abg >= 25) OR
  (r500_abg >= 25 and r2000_abg >= 25) OR
  (r1000_abg >= 25 and r2000_abg >= 25));

select count(*) from  data_acbc_ac250to8000_r_bc500to2000_bc2freql_rCHL; --24

                drop table  if exists  data_acbc_ac250to8000_r_bc500to2000_bc2freql_rincom; 
    create table data_acbc_ac250to8000_r_bc500to2000_bc2freql_rincom as 
select * from data_acbc_ac250to8000_r_bc500to2000_bc2freql_oneperfreq
  where
(r500_abg >=25 and r1000_abg <25 and r2000_abg is null) OR
  (r500_abg >=25 and r1000_abg is null and r2000_abg <25) OR
  (r500_abg is null and r1000_abg >=25 and r2000_abg <25) OR
  (r500_abg is null and r1000_abg <25 and r2000_abg >=25) OR
(r500_abg <25 and r1000_abg >=25 and r2000_abg is null) or
(r500_abg <25 and r1000_abg is null and r2000_abg >=25);

    select count(*) from data_acbc_ac250to8000_r_bc500to2000_bc2freql_rincom; --1


Select * from data_acbc_ac250to8000_r_bc_rincom
    where 
    (bc_l1000t is null and bc_l500t is null) or
(bc_l1000t is null and bc_l2000t is null) or
    (bc_l2000t is null and bc_l500t is null); --112




drop table if exists  snhl;
    create table SNHL
  (patient_id int,
  audindex smallint,
  investdate date, sex varchar, age int,
 ac_l250 smallint,
  ac_l500 smallint,
  ac_l1000 smallint,
  ac_l2000 smallint,
  ac_l4000 smallint,
  ac_l8000 smallint,
  ac_r250 smallint,
  ac_r500 smallint,
  ac_r1000 smallint,
  ac_r2000 smallint,
  ac_r4000 smallint,
  ac_r8000 smallint
);

-------------------------------------insert L + R for AC only = 41655

 insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
  l250,   l500,   l1000,   l2000,   l4000,   l8000,
    r250,   r500,   r1000,   r2000,   r4000,   r8000
    from 
    data_ac_bl;

select count(*) from SNHL; --41522

    
-------------insert L for AC only = 1746

 insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
  l250,   l500,   l1000,   l2000,   l4000,   l8000
    from 
    data_ac_l;


    select 1746 + 41522 as addition; --43268
    
select count(*) from SNHL; --43268

 ----#insert R for AC only = 1600

     insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
  r250,   r500,   r1000,   r2000,   r4000,   r8000
    from 
    data_ac_r;

select 43268 + 1600 as addition; --44868

    select count(*) from snhl; --44868


--- now lets look at those with a join but only AC complete for left = 1799

--- those with L SNHL where left BC done = 1050

 
 insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
 ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from 
    data_acbc_ac250to8000_l_bc500to2000_bc2freq_LSNHL;

    select 44868 + 1050 as addition; --45918

    select count (*) from snhl; --45918

-----those with incomp l where left BC done = 3 

    select * from data_acbc_ac250to8000_l_bc500to2000_bc2freq_Lincom;

    insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
 ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from 
    data_acbc_ac250to8000_l_bc500to2000_bc2freq_Lincom;

    select count(*) from snhl; --45921 (45918 + 3)

--- those with L SNHL where BC was done on right 

 insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
 ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from 
   data_acbc_ac250to8000_l_bc500to2000_bc2freqr_LSNHL;

    select 45921+ 126 as addition; --46047
   select count(*) from snhl; --46047

---- those with L incom where BC was done on right = 3 

    

 insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
 ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from 
   data_acbc_ac250to8000_l_bc500to2000_bc2freqr_Lincom;


    select count(*) from snhl; -- 46050 = 46407 + 3


------- now lets look at those with a join but only AC complete for right = 1671
---those with R SNHL where right BC done = 962 


 insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from 
    data_acbc_ac250to8000_r_bc500to2000_bc2freq_rSNHL;

    select 46050 + 959 as addition; --47009

    select count(*) from snhl; --47009

--- those with R incom where right BC done = 3

     insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from 
     data_acbc_ac250to8000_r_bc500to2000_bc2freq_Rincomp;

    select count(*) from snhl; --47012 (47009 +3)

----- those with R SNHL where BC was done on left = 95


     insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from  data_acbc_ac250to8000_r_bc500to2000_bc2freql_rSNHL;

    select 47012 + 95 as addition; --47107
    select count(*) from snhl;  --47107

---- those with R incom where BC was done on left = 1

    
     insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from  
    data_acbc_ac250to8000_r_bc500to2000_bc2freql_rincom;

    select count(*) from snhl; --47108


------------------------now for those with join and BL AC done


------- insert L + R with SNHL 17441


         insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from  data_acbc_ac250to8000_bl_bc500to2000_bl_noabg;

    select 17441 + 47108 as addition; --64549
    select count(*) from snhl; --64549

-----insert L + R with L SNHL and r incom = 75


         insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from  data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqr;

    select 64549 + 75 as addition; --64624
    select count(*) from snhl; --64624

------ insert L + R with R SNHL and l incom = 59
 insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from
    data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r_1freql;


    select 64624 + 59 as addition; --64683
    select count(*) from snhl; #64683

-------------------- insert L + R with R + l incom = 11 
 insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from
data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l_1freqbl;

    select count(*) from snhl; --64694 (64683 + 11)

-------------------------insert L with L SNHL RCHL = 3328

    insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from
    data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_l;

    select 64694 + 3328 as addition; -- 68022
      select count(*) from snhl; --68022

-----------------------insert L with L incom RCHL = 35
    
    insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from
    data_acbc_ac250to8000_bl_bc500to2000_bl_abg_r_1freql;
  

    select 68022 + 35 as addition; ---68057
      select count(*) from snhl; --68057
    
-------------------  insert R with R SNHL LCHL = 3130
   
    insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
       ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from
    data_acbc_ac250to8000_bl_bc500to2000_bl_noabg_r;


    select 68057 + 3130 as addition; --71187
      select count(*) from snhl; --71187

    
------------------ insert R incom LCHL =40
    
  insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
       ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from
data_acbc_ac250to8000_bl_bc500to2000_bl_abg_l_1freqr;
  

    select 71187 + 40 as addition; ----71227
      select count(*) from snhl; --71227

-------------------------------- AC BL BC L - 39711
-------------- AC BL, BC L only where tm notnull + t null = L snhl = 6284


insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_LSNHL;
   

    select 71227 + 6284 as addition; --77511
      select count(*) from snhl; --77511

------------ AC BL, BC L only where tm notnull + t null = L INCOM = 384

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_null_l1freq;
   

    select 77511 + 384 as addition; --77895
      select count(*) from snhl; ---77895

-------------------------- AC BL, BC L only where tm notnull + t notnull = L SNHL, R CHL = 87
insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LSNHL;

    select 77895 + 87 as addition; --77982
      select count(*) from snhl; --77982

-------------------AC BL, BC L only where tm notnull + t notnull = L incom, R CHL = 16
insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from cc;
  
    select 77982 + 16 as addition; --77998
      select count(*) from snhl; --77998

----------------------- AC BL, BC L only where tm null + t notnull = L CHL R snhl = 1471
  insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
       ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_RSNHL;
  
    select 77998 + 1471 as addition;--79469
      select count(*) from snhl; --79469

------------------AC BL, BC L only where tm null + t notnull = L CHL R incom = 5

  insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
       ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from bb;
  
    select 79469 + 5  as addition; --79474
      select count(*) from snhl; --79474

------------ AC BL, BC L only where tm null + t notnull = L + R snhl = 3551

    insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from data_acbc_ac250to8000_bl_bc2freq_l_tm_notnull_t_notnull_LRSNHL;

    select 3551 + 79474 as addition; ---83025
    select count(*) from snhl; ---83025

---------AC BL, BC L only where tm null + t notnull = L + R incom = 3 (table aa)

    insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from aa;

    select 83025 + 3 as addition;---83028
    select count(*) from snhl; ---83028

-------------AC BL, BC L only where tm null + t notnull = L SNHL + R incom = 3 (table b )

  insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from b;

    select 83028 + 3 as addition; ---83031
    select count(*) from snhl; ---83031

---------AC BL, BC L tm null l t not null = L + R SNHL = 20808

    insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LRSNHL;

    select 83031 + 20808 as addition; --103839
    select count(*) from snhl; --103839
    
------------------------ AC BL, BC L tm null l t not null = L + R incom = 47 (table aaa)

    insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from aaa;

    select 103839 + 47 as addition; --103886
    select count(*) from snhl; --103886

-----------------AC BL, BC L tm null l t not null = L incom + R snhl = 72 (e)

    insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from e;

    select 103886 + 72 as addition; ---103958
    select count(*) from snhl; --103958

---- AC BL, BC L tm null l t not null = R incom + L snhl = 35 (d)

    insert into SNHL
(patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from d;

    select 103958 + 35 as addition; ---103993
    select count(*) from snhl; ---103993


------ AC BL, BC L tm null l t not null = R chl + L snhl 

    insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_LSNHL;

    select 103993 + 1081 as addition; --105074
    select count(*) from snhl; --105074

------------ AC BL, BC L tm null l t not null = R chl + L incom = 16 (table ee) 

    insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
    ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from ee;

    select 105074 + 16 as addition; --105090
    select count(*) from snhl; --105090

------------AC BL, BC L tm null l t not null = R snhl + L chl = 608 

    insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from data_acbc_ac250to8000_bl_bc2freq_l_tm_null_RSNHL;

    select 105090  + 608 as addition; ---105698
    select count(*) from snhl; ---105698

-------------AC BL, BC L tm null l t not null = R incom + L chl = dd 16

    insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from dd;

    select 105698 + 16 as addition; --105714
    select count(*) from snhl; --105714

-------------- AC BL BC R - 43106

--------- AC BL, BC R only where tm notnull + t null = R snhl = 6272

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_rSNHL;
  
    select 105714 + 6272 as addition; --111986
      select count(*) from snhl; --111986

------------------AC BL, BC R only where tm notnull + t null = R incom = 388 

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_null_r1freq;
   
    select 111986 + 388 as addition; --112374
      select count(*) from snhl;  --112374

-------------AC BL, BC R only where tm notnull + t not null = R SNHL, L CHL = 5

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_rSNHL;
   
    select 5 + 112374 as addition; --112379
select count(*) from snhl; --112379

----------AC BL, BC R only where tm notnull + t not null = R incom, L CHL = 2 (table gg)

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from gg;

select count(*) from snhl; --112381

-------------AC BL, BC R only where tm notnull + t not null = L snhl, R CHL = 3138

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_lSNHL;
   
    select 3138 + 112381 as addition; --115519
select count(*) from snhl; --115519

---------------AC BL, BC R only where tm notnull + t not null = L incom, R CHL = 43 (table hh)

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from hh;
   
    select 115519 +43 as addition; ---115562
select count(*) from snhl;---115562

------------------ AC BL, BC R only where tm notnull + t not null = L + R snhl = 1808

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from
    data_acbc_ac250to8000_bl_bc2freq_r_tm_notnull_t_notnull_LRSNHL;
   
    select 115562 +1808 as addition; --117370
select count(*) from snhl; --117370

---------------- AC BL, BC R only where tm notnull + t not null = L + R incom = 1 (fff)

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from
    fff;
   
select count(*) from snhl; #117371

---------------- AC BL, BC R only where tm notnull + t not null = L snhl + R incom = 53 (G)
insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from
    G;
   
    select 117371 +53 as addition; ---117424
select count(*) from snhl; ---117424

---------- AC BL, BC R only where tm notnull + t not null = L INCOM R snhl = 20 (h)

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from
    h;
   
    select 117424 +20 as addition; --117444
select count(*) from snhl; --117444

---------------AC BL, BC R only where tm null + t not null = L + R snhl = 23445

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from
    data_acbc_ac250to8000_bl_bc2freq_r_tm_null_LRSNHL;
   
    select 117444 + 23445 as addition; --140889
select count(*) from snhl; --140889

------------AC BL, BC R only where tm null + t not null = L + R incom = 33 (table iii)
insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from
    iii;
   
    select 140889+ 33 as addition; --104922
select count(*) from snhl; --104922

------------AC BL, BC R only where tm null + t not null = L snhl + R incom = 94 (table i)

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from
    i;
   
    select 140922 + 94 as addition; #141016
select count(*) from snhl; 141016

-------------------- AC BL, BC R only where tm null + t not null = L incom R snhl = 39 (table i)

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
      ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from
    j;
   
    select 141016 + 39 as addition; --141055
select count(*) from snhl; --141055

---------------- AC BL, BC R only where tm null + t not null = R snhl L CHL = 1200

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from
    data_acbc_ac250to8000_bl_bc2freq_r_tm_null_rSNHL;
   
    select 141055 + 1200 as addition; --142255
select count(*) from snhl; --142255

-------------- AC BL, BC R only where tm null + t not null = R incom L CHL = 14 (table ii)

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000)
  select 
patient_id, audindex, investdate, sex, age,
    ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from
    ii;
   
    select 142255 + 14 as addition; --142269
select count(*) from snhl; #142269

------------ AC BL, BC R only where tm null + t not null = R CHL L SNHL = 753 

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from
    data_acbc_ac250to8000_bl_bc2freq_r_tm_null_lSNHL;
   
    select 142269 + 753 as addition; --143022
select count(*) from snhl; --143022

--------------AC BL, BC R only where tm null + t not null = R CHL L incom = p (table jj) 7

insert into SNHL
(patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000)
  select 
patient_id, audindex, investdate, sex, age,
     ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000
    from
    jj;
   
    select 143022 + 7 as addition; --143029
select count(*) from snhl; --143029

--------------------FINAL AC DATASET FOR KIDS AND ADULTS

    select count(*) from snhl; --143029

    select count(*) from 
    (select distinct * from snhl)l;  --143029

----------------- FINAL AC DATASET FOR ADULTS

select count(*) from snhl where age >=18; --125991

--------------------------FINAL AC DATASET FOR ADULTS with one audiogram per adult

    select count (distinct patient_id) from 
    (select patient_id from snhl where age >=18)lily; --66372


drop table if exists  snhl_adults;
create table snhl_adults
as
select * from 
snhl where age >=18;

                select count(*) from snhl_adults;

                select * from snhl_adults;

drop table if exists  snhl_adults_bl;
create table snhl_adults_bl as select * from snhl_adults
  where 
  ac_l250 notnull and ac_l500 notnull and ac_l1000 notnull and ac_l2000 notnull and ac_l4000 notnull and  
  ac_l8000 notnull and  
 ac_r250 notnull and ac_r500 notnull and ac_r1000 notnull and ac_r2000 notnull and ac_r4000 notnull and  
  ac_r8000 notnull;

 select count(*) from  snhl_adults_bl; --95253

alter table snhl_adults_bl
                add column side varchar; 
               
update snhl_adults_bl
                set side = 'bl_right';

select * from  snhl_adults_bl;


drop table if exists  snhl_adults_l;
create table snhl_adults_l
as
select * from snhl_adults
  where 
  ac_l250 notnull and ac_l500 notnull and ac_l1000 notnull and ac_l2000 notnull and ac_l4000 notnull and  
  ac_l8000 notnull and  
 ac_r250 is null and ac_r500 is null and ac_r1000 is null and ac_r2000 is null and ac_r4000 is null and  
  ac_r8000 is null;

select count(*) from  snhl_adults_l; --16376

                alter table snhl_adults_l
                add column side varchar; 
               
update snhl_adults_l
                set side = 'left';

    drop table if exists  snhl_adults_R;
create table snhl_adults_r as 
  (select * from snhl_adults
  where 
  ac_r250 notnull and ac_r500 notnull and ac_r1000 notnull and ac_r2000 notnull and ac_r4000 notnull and  
  ac_r8000 notnull and  
 ac_l250 is null and ac_l500 is null and ac_l1000 is null and ac_l2000 is null and ac_l4000 is null and  
  ac_l8000 is null); 

    select count(*) from snhl_adults_r; --14462

                alter table snhl_adults_r
                add column side varchar; 
               
update snhl_adults_R
                set side = 'right';

    select 14362+ 16376 + 95253 as addition; --125991 perfect

    drop table if exists  data; 
    create table data
  (patient_id int,
  audindex smallint,
  investdate date, sex varchar, age int, side varchar,
 ac_250 smallint,
 ac_500 smallint,
ac_1000 smallint,
ac_2000 smallint,
ac_4000 smallint,
ac_8000 smallint
);

 insert into data
(patient_id, audindex, investdate, sex, age, ac_250,  ac_500,  ac_1000, ac_2000, ac_4000, ac_8000, side)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000, side
    from 
    snhl_adults_r;


                
 insert into data
(patient_id, audindex, investdate, sex, age, ac_250,  ac_500,  ac_1000, ac_2000, ac_4000, ac_8000, side)
  select 
patient_id, audindex, investdate, sex, age,
  ac_l250,   ac_l500,   ac_l1000,   ac_l2000,   ac_l4000,   ac_l8000, side
    from 
    snhl_adults_l;


  insert into data
(patient_id, audindex, investdate, sex, age, ac_250,  ac_500,  ac_1000, ac_2000, ac_4000, ac_8000, side)
  select 
patient_id, audindex, investdate, sex, age,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000, side
    from 
    snhl_adults_bl;

select count(*) from data; --125991


    ---- now add the means business!



  ---now lets make a table that has 2 columns for mean values for right and left ear


drop table data_means;
  create table data_means as select * from data;

alter table data_means  add column mean int;

update data_means
  set mean = (ac_250 + ac_500 + ac_1000 + ac_2000 + ac_4000 + ac_8000)/6;



 /* select means1.patient_id, means1.mean_l, means1.mean_r, means2.mean_l, means2.mean_r from adult_dataset_means as means1
  inner join adult_means as means2
  on means1.patient_id = means2.patient_id order by means1.patient_id, means1.investdate; 

 select count(*) from adult_means where audindex !=1; #7363 */

drop table data_means_final;
create table data_means_final as 
select * from data_means
order by patient_id asc, investdate asc;

 ---I then want to save it so the means are per per patient_id.

drop view data_means_final_multi;
create view data_means_final_multi as
  select patient_id, array_agg(mean
    order by patient_id asc, investdate asc) as means
    from data_means_final 
    group by patient_id;

     select count(*) from data_means_final_multi; --66372
  select * from data_means_final_multi; --66372
    select cardinality(means) from data_means_final_multi;

---now make it so each individual has their means as seperate row

drop view data_means_individual;
  create view data_means_individual as
  select patient_id, means[1] as results1,
  means[2] as results2,
  means[3] as results3,
 means[4] as results4,
  means[5] as results5,
 means[6] as results6,
  means[7] as results7,
  means[8] as results8,
  means[9] as results9,
  means[10] as results10,
  means[11] as results11,
  means[12] as results12,
  means[13] as results13,
  means[14] as results14,
    means[15] as results15,
   means[16] as results16,
    means[17] as results17,
    means[18] as results18,
    means[19] as results19,
    means[20] as results20,
    means[21] as results21,
     means[22] as results22,
     means[23] as results23,
     means[24] as results24,
     means[25] as results25,
     means[26] as results26,
     means[27] as results27,
     means[28] as results28
  from data_means_final_multi;

select count(*) from data_means_individual ; --66372

select count(*) from
(select distinct patient_id from data)x; --66372
  

select * from data;

----dataset for using patients with complete readings and SNHL for 2 ears 

                 drop table if exists data_2ears; 
    create table data_2ears
  (patient_id int,
  audindex smallint,
  investdate date, sex varchar, age int, side varchar,
 ac_l250 smallint,
 ac_l500 smallint,
ac_l1000 smallint,
ac_l2000 smallint,
ac_l4000 smallint,
ac_l8000 smallint,
ac_r250 smallint,
 ac_r500 smallint,
ac_r1000 smallint,
ac_r2000 smallint,
ac_r4000 smallint,
ac_r8000 smallint);

insert into data_2ears
(patient_id, audindex, investdate, sex, age, side, ac_l250,  ac_l500,  ac_l1000, ac_l2000, ac_l4000, ac_l8000, 
                 ac_r250,  ac_r500,  ac_r1000, ac_r2000, ac_r4000, ac_r8000)
  select 
patient_id, audindex, investdate, sex, age, side,
  ac_l250,  ac_l500,  ac_l1000, ac_l2000, ac_l4000, ac_l8000,
  ac_r250,   ac_r500,   ac_r1000,   ac_r2000,   ac_r4000,   ac_r8000
    from 
    snhl_adults_bl;


