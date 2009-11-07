#!/bin/sh
# $Id$
. ./utils.sh
OPTION=`lookupkey "$QUERY_STRING" option`
if test "$OPTION" = Reset; then
    INPUT=
else
    INPUT=`lookupcheckkey "$QUERY_STRING" input`
    ZONE=`lookupkey "$QUERY_STRING" zone`
    PREC=`lookupkey "$QUERY_STRING" prec`
fi
test "$ZONE" || ZONE=-3
test "$PREC" || PREC=0
INPUTENC=`encodevalue "$INPUT"`
COMMAND=GeoConvert
EXECDIR=../bin
F='<font color="blue">'
G='</font>'
test $PREC = 0 || COMMAND="$COMMAND -p $PREC"
LOCG=
LOCD=
LOCU=
LOCM=
if test "$INPUT"; then
    LOCG=`echo $INPUT | $EXECDIR/$COMMAND`
    if test $? -eq 0; then
	LOCD=\(`echo $INPUT | $EXECDIR/$COMMAND -d`\)
	case $ZONE in
	    -3 ) ;;
	    -2 ) COMMAND="$COMMAND -t";;
	    -1 ) COMMAND="$COMMAND -s";;
	    * ) COMMAND="$COMMAND -z $ZONE"
	esac
	LOCU=`echo $INPUT | $EXECDIR/$COMMAND -u`
	LOCM=`echo $INPUT | $EXECDIR/$COMMAND -m`
    fi
    echo `date +"%F %T"` "$COMMAND: $INPUT" >> ../persistent/utilities.log
fi

echo Content-type: text/html
echo
cat <<EOF
<html>
  <header>
    <title>
      Online geographic coordinate converter
    </title>
  </header>
  <body>
    <h3>
      Online geographic coordinate conversions using the
      <a href="http://geographiclib.sourceforge.net/html/utilities.html#geoconvert">
	GeoConvert</a> utility
    </h3>
    <form action="/cgi-bin/GeoConvert" method="get">
      <p>
        Location (ex. "<tt>33.33 44.4</tt>", "<tt>33d19'47"N 44d23.9'E</tt>", "<tt>38SMB4488</tt>", "<tt>38N 444000 3688000</tt>"):<br>
        &nbsp;&nbsp;&nbsp;
        <input type=text name="input" size=40 value="$INPUTENC">
      </p>
      <table>
        <tr>
          <td>
            &nbsp;&nbsp;&nbsp;
            Output zone:<br>
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <select name="zone" size=1>
EOF
(
    cat <<EOF
-3 Match input or standard
-1 Standard UPS/UTM zone
0 UPS
-2 Standard UTM zone
EOF
) | while read z name; do
    SELECTED=
    test "$z" = "$ZONE" && SELECTED=SELECTED
    echo "<option $SELECTED value=\"$z\">$name"
done
for ((z=1; z<=60; ++z)); do
    SELECTED=
    test "$z" = "$ZONE" && SELECTED=SELECTED
    name="UTM zone $z"
    echo "<option $SELECTED value=\"$z\">$name"
done
cat <<EOF
            </select>
          </td>
          <td>
            &nbsp;&nbsp;&nbsp;
            Output precision:<br>
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <select name="prec" size=1>
EOF
(
    cat <<EOF
-5 100km 1d
-4 10km 0.1d
-3 1km 0.01d 1'
-2 100m 0.001d 0.1'
-1 10m 0.0001d 1"
0 1m 0.00001d 0.1"
1 100mm 0.01"
2 10mm 0.001"
3 1mm 0.0001"
4 100um 0.00001"
5 10um 0.000001"
6 1um 0.0000001"
7 100nm 0.00000001"
8 10nm 0.000000001"
9 1nm 0.0000000001"
10 0.00000000001"
EOF
) | while read p desc; do
    SELECTED=
    test "$p" = "$PREC" && SELECTED=SELECTED
    echo "<option $SELECTED value=\"$p\">$desc"
done
cat <<EOF
            </select>
          </td>
        </tr>
      </table>
      <p>
        Select action:<br>
        &nbsp;&nbsp;&nbsp;
        <input type="submit" name="option" value="Submit">
        <input type="submit" name="option" value="Reset">
      </p>
      <p>
        Results:
<font size="4"><pre>
    input   = `encodevalue "$INPUT"`
    lat lon = $F`encodevalue "$LOCG"` `encodevalue "$LOCD"`$G
    <a href="http://en.wikipedia.org/wiki/Universal_Transverse_Mercator_coordinate_system">UTM</a>/<a href="http://en.wikipedia.org/wiki/Universal_Polar_Stereographic">UPS</a> = $F`encodevalue "$LOCU"`$G
    <a href="http://en.wikipedia.org/wiki/Military_grid_reference_system">MGRS</a>    = $F`encodevalue "$LOCM"`$G</pre></font>
      </p>
    </form>
    <hr>
    <p>
      <a href="http://geographiclib.sourceforge.net/html/utilities.html#geoconvert">
        GeoConvert</a>
      converts between geographic (latitude and longitude) coordinates,
      <a href="http://en.wikipedia.org/wiki/Universal_Transverse_Mercator_coordinate_system">
        universal transverse Mercator (UTM)</a> or
      <a href="http://en.wikipedia.org/wiki/Universal_Polar_Stereographic">
        universal polar stereographic (UPS)</a> coordinates, and the
      <a href="http://en.wikipedia.org/wiki/Military_grid_reference_system">
        military grid reference system (MGRS)</a>.
      Examples of legal geographic locations are (these all refer to the
      same place, Cape Morris Jesup on the northern tip of Greenland):
      <pre>
    Latitude and longitude:       MGRS:
        83.627 -32.664                24XWT783908
        W32d40 N83d37.6               YUB17770380
        83d37'39"N 32d39'52"W     UTM:
    UPS:                              25N 504158 9286521
        N 1617772 1403805             430000 9290000 26N</pre>
      <b>Notes:</b>
      <ul>
	<li>
	  The letter in following the zone number in the UTM position is a
	  hemisphere designator (N or S) and <em>not</em> the MGRS latitude
	  band letter.
	<li>
	  MGRS coordinates are taken to refer to <em>grid squares</em>
	  (<em>not</em> to the intersections of grid lines).  Thus in UTM
	  zone 38N, the square area with easting in [444 km, 445 km) and
	  northing in [3688 km, 3689 km) corresponds to the MGRS square
	  38SMB4488 (at 1 km precision).
	  <ul>
	    <li>
	      When an MGRS coordinate is read, it is treated as the
	      <em>center</em> of the grid square.
	    <li>
	      The MGRS easting and northing are obtained
	      by <em>truncation</em> to the requested precision
	      (<em>not</em> rounding).
	  </ul>
	<li>
	  Usually <em>Output zone</em> should be <em>Match input or
	  standard</em>.  If the latitude and longitude are given, the
	  standard UPS and UTM zone rules are applied; otherwise the
	  UPS/UTM selection and the UTM zone match the input.  The other
	  choices let you override this selection.
      </ul>
    </p>
    <p>
      <a href="http://geographiclib.sourceforge.net/html/utilities.html#geoconvert">
        GeoConvert</a>,
      which is a simple wrapper of the
      <a href="http://geographiclib.sourceforge.net/html/classGeographicLib_1_1GeoCoords.html">
        GeographicLib::GeoCoords</a> class,
      is one of the utilities provided
      with <a href="http://geographiclib.sourceforge.net/">
        GeographicLib</a>.
      This web interface illustrates a subset of its capabilities.  If
      you wish to use GeoConvert directly,
      <a href="http://sourceforge.net/projects/geographiclib/files/distrib">
        download</a>
      and compile GeographicLib.
    </p>
    <hr>
    <address><a href="http://charles.karney.info/">Charles Karney</a>
      <a href="mailto:charles@karney.com">&lt;charles@karney.com&gt;</a>
      (2009-10-27)</address>
  </body>
</html>
EOF
