SELECT pg.id,
       pg.name AS "Automatically Populated Congregation Attendance Group"
FROM _person_group pg
JOIN congregation_group cg ON pg.id=cg.groupid;
