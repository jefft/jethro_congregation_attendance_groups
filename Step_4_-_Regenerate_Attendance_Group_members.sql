SELECT 'The Congregation Attendance Group memberships have been wiped and repopulated to contain EVERYONE, but with group membership status set to Member/Leader/etc for native members (mapped from person status), and ''Other Congregation'' for everyone else' AS "Action Taken";

-- Make every 'person status' a legitimate 'group member status'

INSERT INTO person_group_membership_status (label, is_default, rank)
SELECT ps.label,
       ps.is_default,
       ps.rank
FROM person_status ps
LEFT JOIN person_group_membership_status pgms ON ps.label = pgms.label
WHERE pgms.label IS NULL
  AND ps.require_congregation=1;

-- Add 'Other Congregation' group member status

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
                 OR secondarycongregation.id = cg.congregationid THEN coalesce(pgms.id, 1)
            ELSE @pgms_othercongregation -- Other Congregation
 
        END) AS membership_status, 
       _person.created AS created
FROM _person
JOIN 
  (SELECT * 
   FROM congregation 
   WHERE attendance_recording_days>0) c ON c.id=_person.congregationid -- CAGs only include people who attend an attendance-recording congregation, not e.g. a 'supporters' congregation
JOIN 
  (SELECT * 
   FROM person_status 
   WHERE require_congregation=1) person_status ON person_status.id = _person.status
CROSS JOIN congregation_group cg -- cross join because we want a new person_group_membership record for EACH congregation group
LEFT JOIN person_group_membership_status pgms ON pgms.label = person_status.label  -- A matching pgms should always exist, per the INSERTs above, but just in case let's left join and coalesce()
LEFT JOIN -- Pull in the 'Secondary Congregations'

  (SELECT cfv.personid,
          congregation.id
   FROM custom_field_value cfv
   JOIN custom_field cf ON cf.id=cfv.fieldid
   JOIN custom_field_option cfo ON cfo.id=cfv.value_optionid
   JOIN congregation ON congregation.name=cfo.value
   WHERE cf.id=@cf) AS secondarycongregation ON secondarycongregation.personid=_person.id
AND secondarycongregation.id=cg.congregationid;
