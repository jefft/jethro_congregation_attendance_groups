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
