#
# Die ersten zwei Variablen gegen die echten pfade ersetzen
# NURHEUTE sollte selbsterklaerend sein
#
# Aufruf mit: awk -f programm.awk epg.data > programm.html
# dann mit vernuenftigen Browser (nicht konqueror) ansehen.
#
# Viel Vergnuegen; matthias.huber@wollishausen.de 
#
BEGIN {

CHANNELSCONF="/etc/vdr/channels.conf";
NURHEUTE = 0;

	if ( getline < CHANNELSCONF == -1 ) {
		print "Bitte den Pfad fuer die CHANNELSCONF anpassen!" > "/dev/stderr";
		exit 1;
	}

	nchannels = 0;
	while ( getline cha < CHANNELSCONF > 0 ) {
		split ( cha, acha, /:/ );
		if ( acha[1] != "" && !(acha[1] in channels_index) ) {
			channels[nchannels] = acha[1];
			channels_index[(acha[1])] = acha[1];
			channels_nr[(acha[1])] = nchannels;
			nchannels++;
		}
	}
	SUBSEP="_";

	abendvon = mktime ( strftime ( "%Y %m %d 00 00 00", systime() ) );
	abendbis = abendvon + 24 * 60 * 60 - 1;

	init();
}

function init() {
	eventid="";
	starttime=0;
	laenge=0;
	beschreibung="";
	titel="";
}

/^C / {
	kanalid = $2;
	kanal = substr($0, index($0, $3));
}

/^D / {
	beschreibung = substr($0, 3);
}

/^E / {
	eventid = $2;
	starttime = $3;
	laenge = $4;
}

/^T / {
	titel = substr($0, 3);
}

/^e/ {
	if ( (kanal in channels_index) && ( !NURHEUTE || ( NURHEUTE && starttime >= abendvon && starttime <= abendbis ) ) ) {
		sendeliste[starttime,kanal] = titel "|" laenge "|" beschreibung;
		startarr[starttime] = starttime;
	}
	init();
}

END {
	n = asort( startarr, startarr_sort );
	
# Kanaele aussortieren, die kein Programm haben
	for ( x in channels_index ) {
		found = 0;
		for ( i = 1; i <=  n; i++ ) {
			if ( sendeliste[startarr_sort[i], channels_index[x]] ) {
				found = 1;
				break;
			}
		}
		if ( !found ) {
			y = channels_nr[x];
			channels_leer[y] = 1;
		}
	}

	print "<html><head><style type=text/css>td { font-size: 8pt; }</style></head><body>";

	print "<table border=1>"
	
	print "<tr><td width=150><b>Datum</b></td><td width=150><b>Zeit</b></td>";
	for ( j = 0; j < nchannels; j++ ) {
		if ( !channels_leer[j] )
			print "<td nowrap width=250><b>" channels[j] "</b></td>";
	}
	print "</tr>\n";

	for ( i = 1; i <= n; i++ ) {
		print "<tr>";
		print "<td valign=top width=150><b>" strftime("%d.%m.", startarr_sort[i] ) "</b></td>";
		print "<td valign=top width=150><b>" strftime("%H:%M", startarr_sort[i] ) "</b></td>";
		for ( j = 0; j < nchannels; j++ ) {
			if ( channels_leer[j] )
				continue;
			c = channels[j];
			s = startarr_sort[i];
			if ( sendeliste[s, c] ) {
				split( sendeliste[s, c], sl, "|" );
				nspan = 1;
				for ( k = i + 1; k <= n && !sendeliste[(startarr_sort[k]), c]; k++ )
					nspan++;
				print "<td valign=top width=250 rowspan=" nspan "><b>" sl[1] " (" c ", " int(sl[2]/60) " min)</b><br>" sl[3] "</td>";
				habs[c] = 1;
			}
			else {
				if ( !habs[c] ) {
					nspan = 1;
					for ( k = i + 1; k <= n && !sendeliste[(startarr_sort[k]), c]; k++ )
						nspan++;
					print "<td valign=top width=250 rowspan=" nspan "></td>";
					habs[c] = 1;
				}
			}
		}
		print "</tr>\n";
	}
	print "</table>";

	print "</body></html>";
}
