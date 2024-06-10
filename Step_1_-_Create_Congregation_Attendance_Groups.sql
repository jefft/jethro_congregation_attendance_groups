SELECT 'Create the Congregation Attendance Groups' AS outcome;

-- Create a group category for our new groups

INSERT INTO person_group_category(name, parent_category)
SELECT 'Congregation Attendance Groups',
       NULL
WHERE NOT EXISTS
    (SELECT 1
     FROM person_group_category
     WHERE name='Congregation Attendance Groups');


SET @groupcatid :=
  (SELECT id
   FROM person_group_category
   WHERE name='Congregation Attendance Groups');

-- Create the Attendance Groups, one per congregation

INSERT INTO _person_group (name, categoryid, is_archived, OWNER, show_add_family, share_member_details, attendance_recording_days)
SELECT concat(name, ' Attendance') AS name,
       @groupcatid,
       0,
       NULL,
       'no',
       0,
       attendance_recording_days
FROM congregation
WHERE attendance_recording_days!=0
  AND NOT EXISTS
    (SELECT 1
     FROM _person_group pg
     WHERE pg.name=concat(congregation.name, ' Attendance'));

-- Create a view mapping CAG to congregation. This will be used in most later SQL

CREATE VIEW IF NOT EXISTS congregation_group AS
SELECT pg.id AS groupid,
       c.id AS congregationid
FROM _person_group pg
JOIN congregation c ON pg.name=concat(c.name, ' Attendance');
