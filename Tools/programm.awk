BEGIN {
	while ( getline cha < "/etc/vdr/channels.conf" > 0 ) {
		split ( cha, acha, /:/ );
		channels[(acha[1])] = acha[1];
	}
	SUBSEP="_";
	abendvon = mktime ( strftime ( "%Y %m %d 00 00 00", systime() ) );
	abendbis = abendvon + 24 * 60 * 60 - 1;
#	print "Programmliste: " strftime( "%d.%m.%Y %H:%M", abendvon ) " - " strftime( "%d.%m.%Y %H:%M", abendbis );
}
/^C / {
	kanalid = $2;
	kanal = $3;
}
/^D / {
	beschreibung = substr($0, 3);
}
/^E / {
	eventid = $2;
	starttime = $3;
#	print strftime( "%d.%m.%Y %H:%M", starttime );
	laenge = $4;
}
/^T / {
	titel = substr($0, 3);
}
/^NUR_HEUTE_e/ {
	if ( (kanal in channels) && starttime >= abendvon && starttime <= abendbis ) {
		laengem = laenge / 60;
		sendeliste[starttime,kanal] = "<tr><td valign=top>" strftime("%H:%M", starttime) "</td><td valign=top>" kanal "</td><td valign=top>" laengem "</td><td valign=top>" titel "</td><td valign=top>" beschreibung "</td></tr>";
	}
}
/^e/ {
	if ( (kanal in channels) ) {
		laengem = laenge / 60;
		sendeliste[starttime,kanal] = "<tr><td valign=top nowrap>" strftime("%d.%m. %H:%M", starttime) "</td><td valign=top>" kanal "</td><td valign=top>" laengem " min</td><td valign=top>" titel "</td><td valign=top>" beschreibung "</td></tr>";
	}
}
END {
#	for ( i in sendeliste )
#		print sendeliste[i];
#	print "============================================================================================================";
	n = asort ( sendeliste, neu );
	print "<html><head><style type=text/css>td { font-size: 8pt; }</style></head><body><table border=1>";
	for ( i = 0; i <= n; i++ )
		print neu[i];
	print "</table></body></html>";
}
