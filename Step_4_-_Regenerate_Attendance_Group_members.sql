SELECT 'The Congregation Attendance Group memberships have been wiped and repopulated to contain EVERYONE, but with group membership status set to Member/Leader/Fringe for native members (mapped from person status), and ''Other Congregation'' for everyone else' AS "Action Taken";

-- Insert 'Fringe' as a group membership status, if it doesn't exist
 
INSERT INTO person_group_membership_status (label, rank, is_default)
SELECT 'Fringe' AS label, 
       max(rank)+1 AS rank, 
       0 AS is_default
FROM person_group_membership_status
HAVING NOT EXISTS 
  (SELECT 1 
   FROM person_group_membership_status 
   WHERE label='Fringe'); -- Insert 'Other Congregation' as a group membership status, if it doesn't exist. This will be our default membership for people not in the CAG's associated congregation.


INSERT INTO person_group_membership_status (label, rank, is_default)
SELECT 'Other Congregation' AS label,
       max(rank)+1 AS rank,
       0 AS is_default
FROM person_group_membership_status
HAVING NOT EXISTS
  (SELECT 1
   FROM person_group_membership_status
   WHERE label='Other Congregation');


SET @pgms_othercongregation :=
  (SELECT id
   FROM person_group_membership_status
   WHERE label='Other Congregation');


SET @pgms_fringe :=
  (SELECT id
   FROM person_group_membership_status
   WHERE label='Fringe'); -- Delete all existing Congregation Attendance Group memberships. If your CAGs were hand-rolled up till now, any information they contained _should_ have been captured in the 'Secondary Congregations' custom fields in the earlier step.


DELETE pgm
FROM person_group_membership pgm
INNER JOIN congregation_group cg USING (groupid);


SET @cf :=
  (SELECT id
   FROM custom_field
   WHERE name='Secondary Congregations'); --

-- This is where we populate CAGs and decide what membership status each has.
-- YOU WILL LIKELY NEED TO CUSTOMIZE THIS! Your Person Statuses and Group Membership Status Options will likely be different from those assumed below. Both can be seen in the System Configuration page of Jethro.
-- - You will see 'Person Status Options' listed (e.g. 'Core' ,'Crowd', 'Newcomer') without numbers. They begin at index 1 (i.e. 1 = Core).
-- - You will see Group Membership Status Options' listed with numbers. E.g. Member = 1
 

INSERT INTO person_group_membership (personid, groupid, membership_status, created)
SELECT _person.id AS personid, 
       cg.groupid, 
       (CASE 
            WHEN _person.congregationid = cg.congregationid 
                 OR secondarycongregation.id = cg.congregationid THEN CASE person_status.id 
                                                                          WHEN 1 THEN 4 -- Regular -> Regular
 
                                                                          WHEN 2 THEN 11 -- Irregular -> Irregular
 
                                                                          WHEN 3 THEN 9 -- Visitor -> Visitor
 
                                                                          WHEN 4 THEN 36 -- Tourist -> Tourist
 
                                                                          WHEN 5 THEN 43 -- Contact -> Irregular
 
                                                                          WHEN 6 THEN 11 -- Archived -> Irregular
 
                                                                          ELSE @pgms_othercongregation -- * -> Other
 
                                                                      END 
            ELSE @pgms_othercongregation -- Other Congregation
 
        END) AS membership_status, 
       _person.created AS created
FROM _person
JOIN 
  (SELECT *
   FROM congregation 
   WHERE attendance_recording_days>0) c ON c.id=_person.congregationid   -- CAGs only include people who attend an attendance-recording congregation, not e.g. a 'supporters' congregation
JOIN (select * from person_status where require_congregation=1) person_status ON person_status.id = _person.status
CROSS JOIN congregation_group cg -- cross join because we want a new person_group_membership record for EACH congregation group
LEFT JOIN -- Pull in the 'Secondary Congregations'
 
  (SELECT cfv.personid, 
          congregation.id 
   FROM custom_field_value cfv 
   JOIN custom_field cf ON cf.id=cfv.fieldid 
   JOIN custom_field_option cfo ON cfo.id=cfv.value_optionid 
   JOIN congregation ON congregation.name=cfo.value 
   WHERE cf.id=@cf) AS secondarycongregation ON secondarycongregation.personid=_person.id
AND secondarycongregation.id=cg.congregationid;
