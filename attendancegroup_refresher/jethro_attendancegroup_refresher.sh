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
	local person_checksum person_checksum_old
	person_checksum="$(atl_mysql -sBe "select MD5(GROUP_CONCAT(CONCAT_WS('#',id, congregationid, status) ORDER BY id)) AS person_checksum FROM _person;")"
	if [[ -f person_checksum ]]; then
		person_checksum_old="$(cat person_checksum)"
	fi
	if [[ $person_checksum != "${person_checksum_old:-}" ]]; then
		log "A person's congregation or status has changed. Regenerating attendance group memberships"
		atl_mysql -sB < "$JETHRO_CUSTOMREPORTS"/Step_4_-_Regenerate_Attendance_Group_members.sql
		echo "$person_checksum" > person_checksum
	fi
}

regen_congregation_attendances() {
	local attendance_checksum attendance_checksum_old
	attendance_checksum="$(atl_mysql -sBe "SELECT MD5(GROUP_CONCAT(CONCAT_WS('#', personid, groupid, membership_status, created) ORDER BY created)) AS attendance_checksum FROM person_group_membership where groupid!=0;")"
	if [[ -f attendance_checksum ]]; then
		attendance_checksum_old="$(cat attendance_checksum)"
	fi
	if [[ $attendance_checksum != "${attendance_checksum_old:-}" ]]; then
		log "A group attendance record has changed. Regenerating congregation attendances"
		atl_mysql -sB < "$JETHRO_CUSTOMREPORTS"/Step_6_-_Regenerate_congregational_attendances_from_Congregation_Attendance_Groups.sql
		echo "$attendance_checksum" > attendance_checksum
	fi

}

regen_groupmembers
regen_congregation_attendances
