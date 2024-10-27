#!/bin/bash -eu
## Run periodically, this will keep Jethro's Congregation Attendance Groups and Congregation attendances up-to-date. See https://github.com/jefft/jethro_congregation_attendance_groups

basedir="$(dirname "$(readlink -f "$0")")"
JETHRO_CUSTOMREPORTS="$basedir/.."    # Assume we're in customreports/attendancegroup_refresher/
STATEDIR=/var/tmp/jethro_attendance_group_refresher

mkdir -p "$STATEDIR"
cd "$STATEDIR"

log() {
	echo "$(date): $*"
}

regen_groupmembers() {
	local person_checksum person_checksum_old checksumfile
	echo "WITH relevant AS 
	  (SELECT _person.id,
			  congregationid,
			  status,
			  cfo.value AS secondcong
	   FROM _person
	   LEFT JOIN custom_field_value cfv ON cfv.personid=_person.id
	   LEFT JOIN custom_field_option cfo ON cfo.id=cfv.value_optionid
	   LEFT JOIN custom_field cf ON cf.id=cfo.fieldid
	   WHERE cf.name='Secondary Congregations')
	SELECT MD5(GROUP_CONCAT(CONCAT_WS(id, congregationid, status, secondcong) ORDER BY id)), database() FROM relevant;" | atl_mysql -sB |
	while read -r person_checksum database; do
		checksumfile="$database"-person_checksum
		if [[ -f $checksumfile ]]; then
			person_checksum_old="$(cat "$checksumfile")"
		fi
		if [[ $person_checksum != "${person_checksum_old:-}" ]]; then
			log "A person's congregation or status has changed. Regenerating attendance group memberships"
			atl_mysql -sB < "$JETHRO_CUSTOMREPORTS"/Step_4_-_Regenerate_Attendance_Group_members.sql
			echo "$person_checksum" > "$checksumfile"
		fi
	done
}

regen_congregation_attendances() {
	local attendance_checksum attendance_checksum_old checksumfile
	atl_mysql -sBe "SELECT MD5(GROUP_CONCAT(CONCAT_WS('#', personid, groupid, membership_status, created) ORDER BY created)) AS attendance_checksum, database() FROM person_group_membership where groupid!=0;" | while read -r attendance_checksum database; do
		checksumfile="$database"-attendance_checksum
		if [[ -f $checksumfile ]]; then
			attendance_checksum_old="$(cat "$checksumfile")"
		fi
		if [[ $attendance_checksum != "${attendance_checksum_old:-}" ]]; then
			log "A group attendance record has changed. Regenerating congregation attendances"
			atl_mysql -sB < "$JETHRO_CUSTOMREPORTS"/Step_6_-_Regenerate_congregational_attendances_from_Congregation_Attendance_Groups.sql
			echo "$attendance_checksum" > "$checksumfile"
		fi
	done

}

regen_groupmembers
regen_congregation_attendances
