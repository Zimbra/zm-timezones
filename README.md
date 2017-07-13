## Overview

The `zm-timezones` package allows for frequent updating of timezone information
without having to build and reinstall the webapps that use this information.
The new `TzMsg*.properties` files were created by extracting the timezone
strings from the `AjxMsg*.properties` files. Following projects are using 
`TzMsg*.properties`:

- `zm-web-client`
- `zm-admin-console`

## Update Zimbra's *timezones.ics* File

The `/opt/zimbra/conf/timezones.ics` file lists all time zones known to ZCS.
When a calendar object references a time zone, the name is looked up in this
file to find the zone definition, including GMT offset and daylight savings
rules.  Some of the time zones are marked as primary.  The primary time zones
are those that are shown in the UI's time zone selection list.

`timezones.ics` is generated by running the `zmtzdata2ical` utility.
This utility takes the Olson time zone database files and some supplemental
data files and generates the `timezones.ics` file.

`timezones.ics` is a valid iCalendar object consisting of `VTIMEZONE`
sub-objects.  Each time zone in the Olson data is output as a `VTIMEZONE`.
While the time zones in Olson data files define historical data, the time
zones generated to timezones.ics file strip away the historical info and only
contain a single-year rule.  That is, each time zone in `timezones.ics` assumes
the daylight savings time policy remains the same every year.  For example, in
the US the DST policies changed over the years, but the generated `VTIMEZONE` for
`America/Los_Angeles` will say **DST starts on the 2nd Sunday of March and end on
the 1st Sunday of November, in every single year**.  This simplification was
originally adopted to avoid breaking the Microsoft Outlook client.

### Running the Converter

To generate an updated `timezones.ics`, follow these steps.

1. Move to the best work directory:

		$ cd conf/tz
2. Download the archive of the latest Olson tzdata files to this
directory.  As of October 2014, these were obtainable from:
<http://www.iana.org/time-zones> The latest version at that date was
`tzdata2014i.tar.gz`  A full list of *all* Olson tzdata files are available [here](ftp://ftp.iana.org/tz/releases/).
3. Update the URL contained in the file `tz-src-url.txt` with the URL of the file that you downloaded.
3. Extract the data from these archives into the `tzdata` sub-directory.
   (substitute the correct letters for **?????** in this command)

		$ rm -rf tzdata;mkdir tzdata;tar zxvpf tzdata?????.tar.gz -C tzdata
4. Update the `windows-names` file based on the latest time zone names used in
   Windows operating system(s). (more on this later)
5. Update the `extra-data` file accordingly after updating windows-names.
   (more on this later)
6. Run the generator.

		$ ./zmtzdata2ical -o timezones.ics --old-timezones-file ../timezones.ics -e extra-data -t tzdata windows-names

   For information on other options, use `zmtzdata2ical --help`
7. Review the generated `timezones.ics` and make any fixes as necessary.  There
   may be errors in the generated file because of bugs in the generator utility
   or the data files themselves.  Look at the diff from the previous version of
   timezones.ics and compare the changes against the published time zone policy
   changes.
8. Convert the generated `timezones.ics` from using `\r\n` line endings to `\n`
   line endings (Although `\r\n` endings are technically more correct for
   `.ics` files, some tools, such as `zmsetup.pl` require `\n` line endings)

		$ perl -i.org -pe 's/\r\n/\n/' timezones.ics
		$ mv timezones.ics ../timezones.ics
9. Re-build Zimbra and run tests.  e.g.  Check that can change the time zone
   associated with a user in ZWC preferences.
10. Commit changes to `ZimbraServer/conf/timezone.ics`,
    `ZimbraServer/conf/tz/windows-names` and `ZimbraServer/conf/tz/extra-data`.

## The windows-names File

See `tools/updateWindowsNames.py` for how updates were gathered in October 2014.
<http://www.microsoft.com/time> can be a good starting point for finding
out about recent time zone definition updates but isn't guaranteed to be up to date.

`windows-names` maps Windows time zone names to Olson equivalents.  Microsoft
publishes updates to Windows time zones via Microsoft Update, the automatic
software update mechanism for Microsoft products.  Run Microsoft Update to
get the latest time zones before updating the windows-name file.  The Windows
names include both current and past names.  Past names must be kept because
calendar objects created in the past may use these time zone names.  **The
mapping for past names may have to be updated as existing time zones are split
to multiple zones or multiple zones are merged.**

The time zone names from Windows 7 contain "UTC" in the offset section.
Windows XP names contain "GMT" in the offset section.  It is assumed Windows
Vista names are identical to Windows 7 names.  In almost all cases each time
zone should appear twice, once with "UTC" and again with "GMT".

Each line in the windows-names file has three columns (separated by 1 or more
tabs (**NOT spaces**)):

```
Link  <olson TZ name>  <windows TZ name>
```

The Link command maps the Windows name to the nearest equivalent Olson name.

Here are some thoughts on why is it important to maintain these mappings:

* The authorities responsible for a time zone (usually governments)
  can and frequently do change the rules for their time zone.
* At any one time, there are often several time zones that share the same
  simplified (or even full) rules.
* Just because the rules for 2 time zones happen to be the same at one point
  in time does not mean they always will.
* If we discard region/other information and use time zones based solely on
  rules, we cannot differentiate between calendar items which should be
  updated when rules for a region change and those which should not be
  updated because the region they are homed in has not changed their rules.

To get a report of what needs changing do:

```
(cd tools && ./updateWindowsNames.py)
```

Note that TZIDs used in Windows originated ICAL tend to have UTC offsets with
"." instead of ":" in the name, which differs from what is in
`tools/WindowsTimeZoneInfo.txt`


## The extra-data File

`extra-data` feeds extra data to the TZ converter after the Olson data files
have been processed.  The main purpose of this file is to indicate **the
primary time zones to list in the UI**, and to indicate default choice if a
given time zone offset has multiple primary zones.

The file has two sections.  The first `PrimaryZone` section and the
`ZoneMatchScore` section

### PrimaryZone section

The `PrimaryZone` section has 2 **tab separated** columns - the 2nd column
lists the **Olson names** associated with time zones that can be shown in ZWC's
time zone selection UIs:

```
PrimaryZone	<olson TZ name>
```

Note that ZWC tends to show the Windows time zone names corresponding to the
Olson names rather than the Olson names - presumably because it is easier to
navigate to the correct name in a drop down list if you know the rough GMT
offset...

To do a sanity check on whether this section needs additional entries, do:

```
(cd tools && ./checkPrimaryZones.py)
```

Note that `messages/TzMsg.properties` will need updating for any changes to
the PrimaryZone section.  Also, if any UTC offsets are mentioned in the values
for timezones listed in that file and those have changed, those should be
updated there.

Potentially a new bug should be raised to ensure localizations of those
properties happens.  For an example previous bug, see [Bug 96974](https://bugzilla.zimbra.com/show_bug.cgi?id=96974).

This tool may help determine if any of the offsets in the main `TzMsg.properties` file are incorrect.

        (cd tools && ./TzMsgCheck.pl -t ../../timezones.ics)

### ZoneMatchScore section

The second section contains `ZoneMatchScore` lines.  Each time zone is given a
match score.  By default a time zone's match score is 0.  A time zone chosen as
PrimaryZone has the match score of 100.  When there are multiple primary zones
for a given GMT offset it becomes ambiguous which one should be used as a
default choice in a time zone detection algorithm.  To resolve this, choose one
of the primary zones and raise its match score.  For example, **Korea** and
**Japan** have the same time zones but the primary list includes both
**Asia/Seoul** and **Asia/Tokyo**.  To give higher priority to Japan as default
choice, add a ZoneMatchScore line with **3 tab separated columns** like this:

        ZoneMatchScore  Asia/Tokyo  200

### Testing notes

See [Time Zones in Zimbra Collaboration]
(https://wiki.zimbra.com/wiki/Time_Zones_in_ZCS) Some important things to note
from that:

1. Accounts can have a timezone associated with them (inherited from COS if
   not specifically set)
2. The simple web client uses the account specified timezone to choose how to
   display the calendar
3. Most other clients use the client OS timezone to choose how to display the
   calendar
4. Some client OSes don't have a proper understanding of timezones and this
   can result in some behavior quirks, especially with all day events - which
   may display as 24 hours which don't start at the start of the day in the
   local timezone.

## HTML client - uses JRE timezone definitions.

These can be updated using Oracle's Timezone Updater Tool See [Timezone Updater Tool]
(http://www.oracle.com/technetwork/java/javase/tzupdater-readme-136440.html). To download see [Download Oracle tzupdater]
(http://www.oracle.com/technetwork/java/javase/downloads/tzupdater-download-513681.html).

When I last did this, the resulting file was **tzupdater-2_0_0-2015a.zip**.  It
doesn't matter that it is based on an old tzdata release as there is a command
line option to provide the latest definitions.

The steps to update Zimbra's JVM are Note, requires **Zimbra restart**

        zmcontrol stop
        unzip tzupdater-2_0_0-2015a.zip
        cd tzupdater-2.0.0-2015a/
        zmcontrol stop # as the "zimbra" user
        sudo /opt/zimbra/java/bin/java -jar tzupdater.jar \
            -l http://www.iana.org/time-zones/repository/tzdata-latest.tar.gz -v
        zmcontrol start

## Packaging Notes

The following artifacts from the `build` directory should be packaged so that
they are installed to one of the standard locations, such as
`/opt/zimbra/common/share/zm-timezones`.

- `bin`
- `conf`
- `messages`
- `js`

After installation, the post-install hook should run the `deploy-timezones`
script located in `<package-dir>/src/bin`.  This will copy the timezone-related
files to the proper locations and set ownership and permissions appropriately.

In addition, the post-install hooks for `zm-web-client` and `zm-admin-console`
must *also* run the `deploy-timezones` script.  If the UI team is able to
update the webapps that require timezone support to load them from paths that
are outside of the *WebRoot*, then the `deploy-timezones` hook will no longer
be required.

## Import Specification

### Inputs from Perforce

- `ZimbraServer/conf/tz`
- `ZimbraServer/conf/timezones.ics`
- `ZimbraWebClient/src/com/zimbra/kabuki/tools/tz/*`
- Timezone strings from the `AjxMsg*.properties` files located in
  `ZimbraWebClient/WebRoot/messages/AjxMsg.properties`

### Dependencies

- `zm-common`

### Artifacts

- `timezones.ics`
- `Localized timezone names`
- `AjxTimezoneData.js`
- `deploy-timezones` script


## Build Status
[![Build Status](https://travis-ci.org/Zimbra/zm-timezones.svg)](https://travis-ci.org/Zimbra/zm-timezones)