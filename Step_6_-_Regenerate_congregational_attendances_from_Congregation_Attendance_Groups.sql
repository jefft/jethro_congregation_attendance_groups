SELECT 'Congregation attendance records have been regenerated for Congregational Attendance Groups' AS outcome;

-- This view returns all the attendance groups whose attendances will be rolled up and combined into Congregational attendances.
-- This example returns the CAGs plus 3 hand-populated groups ('Infants Sunday School', 'Youth Sunday School').

CREATE VIEW if not exists rolledup_attendance_groups AS
SELECT groupid
FROM congregation_group
UNION
SELECT 22
UNION
SELECT 23
UNION
SELECT 24;

-- Nuke all existing congregation (groupid=0) attendance records


DELETE
FROM attendance_record
WHERE groupid=0;

-- Insert congregation attendance records for each CAG attendance record, bit_or()'ing the attendance bit.

INSERT INTO attendance_record (date, personid, groupid, present, checkinid)
SELECT DISTINCT date, personid,
                      0 AS groupid,
                      bit_or(present) AS present,
                      NULL AS checkinid
FROM attendance_record
JOIN rolledup_attendance_groups USING (groupid)
GROUP BY date, personid;

-- Nuke the headcounts

DELETE
FROM congregation_headcount;

-- Aggregating headcounts is tricky. If 50 people attended group A and 20 people attended group B, it doesn't mean 70 people attended overall - there was probably some overlap. But if there were 5 'extras' in A and 5 'extras' in B, we can assume we had 10 extras overall as 'extras' are unlikely to double-attend. Given this assumption we can calculate the aggregate headcount.
--
-- For each group g, we do know:
-- - the headcount HC(g)
-- - the total present TP(g)
-- - the number of extras X(g) = HC(g)-TP(g).
-- For the congregation c:
-- - We can calculate total present TP(c)
-- - We can assume extras are additive, i.e. X(c) = Σ X(g)
-- - we want to know HC(c)
-- So we can use the formula:
--       X(c) = HC(c)-TP(c)
-- i.e.  HC(c) = X(c) + TP(c)
-- i.e.  HC(c) = Σ X(g) + TP(c)
 
INSERT INTO congregation_headcount -- 
 -- First calculate TP(g):
-- +------------+---------+---------------+
-- | date       | groupid | total_present |
-- +------------+---------+---------------+
-- | 2024-06-09 |      55 |            96 |
-- | 2024-06-09 |      56 |            21 |
-- | 2024-06-09 |      57 |            19 |
-- +------------+---------+---------------+
 WITH tp AS 
  (SELECT date,groupid, 
               count(*) AS total_present 
   FROM attendance_record ar 
   JOIN congregation_group cg USING (groupid) 
   WHERE present=1 
   GROUP BY groupid,date 
   ), --
-- Calculate HG(c)
-- +------------+---------+-----------+
-- | date       | groupid | headcount |
-- +------------+---------+-----------+
-- | 2024-06-09 |      23 |        17 |
-- | 2024-06-09 |      55 |       102 |
-- | 2024-06-09 |      56 |        19 |
-- | 2024-06-09 |      57 |        28 |
-- +------------+---------+-----------+
 headcount AS 
  (SELECT date, person_groupid AS groupid, 
                number AS headcount 
   FROM person_group_headcount), -- Calculate X(g)
-- +------------+---------+-----------+---------------+--------+
-- | date       | groupid | headcount | total_present | extras |
-- +------------+---------+-----------+---------------+--------+
-- | 2024-06-09 |      55 |       102 |            96 |      6 |
-- | 2024-06-09 |      56 |        19 |            21 |     -2 |
-- | 2024-06-09 |      57 |        28 |            19 |      9 |
-- +------------+---------+-----------+---------------+--------+
 extras AS 
  (SELECT *, 
          headcount-total_present AS extras 
   FROM headcount 
   JOIN tp USING (date,groupid)), -- Calculate Σ X(g)
-- +------------+------------+--------------------+
-- | date       | sum_extras | sum_extras_explain |
-- +------------+------------+--------------------+
-- | 2024-06-09 |         13 | 6+-2+9             |
-- +------------+------------+--------------------+
 summedextras AS 
  (SELECT date, sum(extras) AS sum_extras, 
                group_concat(extras separator '+') AS sum_extras_explain 
   FROM extras 
   GROUP BY date), -- Calculate TP(c)
-- +------------+----------------+-------------------+
-- | date       | congregationid | cong_totalpresent |
-- +------------+----------------+-------------------+
-- | 2024-06-09 |              1 |                88 |
-- | 2024-06-09 |              2 |                20 |
-- | 2024-06-09 |              3 |                18 |
-- +------------+----------------+-------------------+
 congregation_totalpresent AS 
  (SELECT date,congregationid, 
               count(*) AS cong_totalpresent 
   FROM attendance_record ar 
   JOIN _person p ON p.id=ar.personid 
   WHERE groupid=0 
     AND present=1 
   GROUP BY date,congregationid), -- Join TP(c) and Σ X(g), and calculate HC(c)
-- +------------+----------------+------------+--------------------+-------------------+----------------+
-- | date       | congregationid | sum_extras | sum_extras_explain | cong_totalpresent | cong_headcount |
-- +------------+----------------+------------+--------------------+-------------------+----------------+
-- | 2024-06-09 |              3 |         13 | 6+-2+9             |                18 |             31 |
-- | 2024-06-09 |              2 |         13 | 6+-2+9             |                20 |             33 |
-- | 2024-06-09 |              1 |         13 | 6+-2+9             |                88 |            101 |
-- +------------+----------------+------------+--------------------+-------------------+----------------+
 x AS 
  (SELECT date, congregationid, 
                sum_extras, 
                sum_extras_explain, 
                cong_totalpresent, 
                sum_extras + cong_totalpresent AS cong_headcount 
   FROM congregation_totalpresent 
   JOIN summedextras USING (date)), -- Get HC(c) into the right format for congregation_headcount. 
-- We have some attendance_records for Contacts with no congregation, which isn't normally possible in Jethro - it is an artifact of rolling up CAGs to the congregation (a congregationless person can be in a CAG). We cannot attribute these to any particular congregation, so exclude them (IS NOT NULL).
 FINAL AS
  (SELECT date,congregationid,
               cong_headcount AS number
   FROM x
   WHERE congregationid IS NOT NULL )
SELECT *
FROM FINAL;
