-- Deletes everything related to CAGs: CAG groups, CAG attendance records / headcounts, CAG group memberships.
 BEGIN;


DELETE
FROM attendance_record
WHERE groupid IN
    (SELECT groupid
     FROM congregation_group);


DELETE
FROM person_group_headcount
WHERE person_groupid IN
    (SELECT groupid
     FROM congregation_group);


DELETE
FROM person_group_membership
WHERE groupid IN
    (SELECT groupid
     FROM congregation_group);


DELETE
FROM _person_group
WHERE id IN
    (SELECT groupid
     FROM congregation_group);

-- Delete group category

DELETE
FROM person_group_category
WHERE name='Congregation Attendance Groups'
  AND NOT EXISTS
    (SELECT *
     FROM _person_group
     WHERE categoryid=person_group_category.id);


DROP VIEW IF EXISTS congregation_group;

-- Delete 'Secondary Congregations', first printing them for later reference.

SELECT concat(first_name, ' ', last_name, ' was in ', cfname, ': ', value)
FROM
  (SELECT p.id,
          p.first_name,
          p.last_name,
          cf.name AS cfname,
          cfo.value
   FROM custom_field cf
   JOIN custom_field_option cfo ON cfo.fieldid=cf.id
   JOIN custom_field_value cfv ON (cfv.fieldid=cf.id
                                   AND cfv.value_optionid=cfo.id)
   JOIN _person p ON p.id=cfv.personid
   AND cf.name='Secondary Congregations') x;


DELETE
FROM custom_field_value
WHERE fieldid=
    (SELECT id
     FROM custom_field
     WHERE name='Secondary Congregations');


DELETE
FROM custom_field_option
WHERE fieldid =
    (SELECT id
     FROM custom_field
     WHERE name='Secondary Congregations');


DELETE
FROM custom_field
WHERE name='Secondary Congregations';


SELECT 'CAGs, their members, attendances, and ''Secondary Congregations'' custom field have been successfully deleted';


COMMIT;
