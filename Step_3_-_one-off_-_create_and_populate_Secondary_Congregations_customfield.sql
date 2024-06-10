SELECT '''Secondary Congregations'' custom field created and populated with people in Congregation Groups that aren''t their native congregation. Also created a ''People in Secondary Congregations'' report' AS outcome;

-- Create 'Secondary Congregations' custom field, if not already existing, populated with the names of the existing congregations.
--
-- Normally people are just added to the Congregation Group (CG) their native congregation implies. But some people, like church staff, regularly attend more than their one 'native' congregation, and must be present in 'secondary' CGs so their attendance can be marked there.
--
-- This SQL also sets the 'Secondary Congregations' field for people whom the legacy hand-managed CGs imply should have it.
-- This script is safe to re-run at any time. If 'Secondary Congregations' already exists and has already been populated, there will be no changes.
-- This SQL depends on the `congregation_group` View from Step_0_-_Create_CAGs.sql being defined.

INSERT INTO `custom_field` (name, rank, TYPE, allow_multiple, show_add_family, searchable, heading_before, divider_before, params, tooltip)
SELECT 'Secondary Congregations',
       max(rank)+1,
       'select',
       '1',
       '',
       '',
       '',
       '',
       'a:5:{s:10:\"allow_note\";b:0;s:16:\"allow_blank_year\";b:0;s:5:\"regex\";s:0:\"\";s:8:\"template\";s:0:\"\";s:11:\"allow_other\";b:0;}',
       'Makes the person a \'Member\' in the associated Congregation Group
	, and thus has a label printed'
FROM custom_field
HAVING NOT EXISTS
  (SELECT 1
   FROM custom_field
   WHERE name='Secondary Congregations');

-- Store id of 'Secondary Congregations' custom field
SET @cf :=
  (SELECT id
   FROM custom_field
   WHERE name='Secondary Congregations');

-- Generate a 'Secondary Congregations' option for each Congregation

INSERT INTO custom_field_option (value, rank, fieldid)
SELECT name AS value,
       (row_number() OVER ())-1 AS rank, -- Generate 0,1,2..
 @cf AS fieldid
FROM congregation
WHERE attendance_recording_days>0
  AND NOT EXISTS
    (SELECT 1
     FROM custom_field_option
     WHERE fieldid=@cf
       AND value=name);


INSERT INTO custom_field_value(personid, fieldid, value_optionid) --
-- Populate 'Secondary Congregations' with, successively, people in the 930am CG who aren't natively in the 930am congregation, then 5pm, then 7pm
-- First, identify CG members, along with their CG id and equivalent congregation id. E.g. person 1 is in 3 congregation groups:
-- +---------+----------+--------------+-------------+
-- | groupid | personid | personcongid | groupcongid |
-- |      55 |        1 |            1 |           1 |
-- |      56 |        1 |            1 |           2 |
-- |      57 |        1 |            1 |           3 |
-- +---------+----------+--------------+-------------+
WITH rollupmembers AS 
  (SELECT groupid, 
          personid, 
          p.congregationid AS personcongid, 
          cg.congregationid AS groupcongid 
   FROM _person p 
   JOIN person_group_membership pgm ON pgm.personid=p.id 
   JOIN congregation_group cg USING (groupid)), -- 
-- 
-- Identify 'foreign' rollup group members. E.g. someone whose native congregation is '9am' but is in the '7pm' rollup group.
-- Also, replace 'foreign' congregation id ('groupcongid') with equivalent name, as that's what our custom field uses. E.g. person 1 is in 'foreign' congregation groups 'Sun 5pm' (group 56) and 'Sun 7pm' (group 57). Group 55 (9am) is not 'foreign' as it is person 1's native congregatoin
-- +----------+----------+
-- | personid | congname |
-- +----------+----------+
-- |        1 | Sun 5pm  |
-- |        1 | Sun 7pm  |
-- +----------+----------+
 foreignrollupmembers AS 
  (SELECT personid, 
          c.name AS congname 
   FROM rollupmembers 
   JOIN congregation c ON rollupmembers.groupcongid=c.id 
   WHERE personcongid != groupcongid ), --
--
-- Translate from congregation name to equivalent 'Secondary Congregation' option id. Also LEFT JOIN on existing custom_field_values and include a column for any existing values set by previous runs of this SQL.
-- +----------+---------+----------------+--------------+
-- | personid | fieldid | value_optionid | existing_cfv |
-- +----------+---------+----------------+--------------+
-- |        1 |      21 |              8 |          585 |
-- |        1 |      21 |              9 |          586 |
-- +----------+---------+----------------+--------------+
 foreignrollupmembercfv AS 
  (SELECT f.personid, 
          cf.id AS fieldid, 
          cfo.id AS value_optionid, 
          cfv.id AS existing_cfv 
   FROM foreignrollupmembers f 
   JOIN custom_field_option cfo ON f.congname = cfo.value 
   JOIN custom_field cf ON cfo.fieldid = cf.id 
   LEFT JOIN custom_field_value cfv ON (cfv.personid = f.personid 
                                        AND cfv.fieldid=cf.id 
                                        AND cfv.value_optionid=cfo.id) 
   WHERE cf.id=@cf ) -- Print custom_field_value rows that don't already exist, which will be INSERTed (right at the top)

SELECT personid,
       fieldid,
       value_optionid
FROM foreignrollupmembercfv
WHERE existing_cfv IS NULL;

-- Create 'People in Secondary Congregations' report

INSERT INTO `person_query` (name, creator, created, OWNER, params, mailchimp_list_id, show_on_homepage)
SELECT 'People In Secondary Congregations',
       1,
       '2024-06-04 03:19:36',
       NULL,
       concat('a:17:{s:5:\"rules\";a:0:{}s:11:\"show_fields\";a:5:{i:0;s:12:\"p.first_name\";i:1;s:11:\"p.last_name\";i:2;s:16:\"p.congregationid\";i:3;s:',length(concat('CUSTOMFIELD---',@cf)),':\"CUSTOMFIELD---', @cf, '\";i:4;s:8:\"checkbox\";}s:8:\"group_by\";s:0:\"\";s:7:\"sort_by\";s:11:\"p.last_name\";s:14:\"include_groups\";a:0:{}s:14:\"exclude_groups\";a:0:{}s:13:\"custom_fields\";a:1:{i:',@cf,';a:2:{s:8:\"criteria\";s:3:\"any\";s:3:\"val\";N;}}s:18:\"custom_field_logic\";s:3:\"AND\";s:23:\"group_membership_status\";a:0:{}s:20:\"group_join_date_from\";N;s:18:\"group_join_date_to\";N;s:31:\"exclude_group_membership_status\";a:0:{}s:11:\"note_phrase\";s:0:\"\";s:18:\"attendance_groupid\";s:0:\"\";s:19:\"attendance_operator\";N;s:18:\"attendance_percent\";N;s:16:\"attendance_weeks\";N;}'),   -- Our report embeds the custom field id, and at one point in PHP's serialization we need to calculate the length of a string including the custom field id.
       '',
       ''
WHERE NOT EXISTS
    (SELECT 1
     FROM person_query
     WHERE name='People In Secondary Congregations');
