SELECT 'Backported attendance records marked on the soon-to-be-wiped congregation to their equivalent rollup groups' AS Outcome;

-- Run this if you have historically marked attendance against congregations, but now have Congregation Attendance Groups (CAGs) defined and would like to backport your historical congregation attendance records to your CAGs.
-- This is idempotent and safe to re-run repeatedly. If, historically, hand-populated groups *and* congregations have been marked each Sunday, these ORed together, so attendance in in either group or congregation results in attendance in the group being recorded.
-- This should NOT be run after Step 6 has been run. Step 6 takes e.g. attendances from 'Sun 9am', 'Sun 5pm' and 'Sun 7pm' CAGs and bit_or()s them into the congregation attendance. Say a native 9am'er attended 5pm one day: you then ran Step 6 (setting congregational attendance), and then this step 5 (setting the 'Sun 9am' CAG attendance). You've now got this person marked as attending both 9am and 5pm, which is wrong.
 BEGIN;


INSERT INTO attendance_record (date, personid, groupid, present, checkinid)
SELECT ar.date,
       ar.personid,
       cg.groupid,
       ar.present,
       ar.checkinid
FROM attendance_record ar
JOIN _person p ON p.id=ar.personid
JOIN congregation_group cg USING (congregationid)
WHERE ar.groupid=0 ON duplicate KEY
  UPDATE present = attendance_record.present |
  VALUES(present);

--  AND ar.personid=468 AND ar.date='2024-05-12'

COMMIT;
