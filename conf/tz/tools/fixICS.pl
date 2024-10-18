#!/usr/bin/perl -w

use Getopt::Std;
use Env;
use File::Basename;

$sc_name              = basename("$0");
$usage                = "usage: $sc_name -t ../../timezones.ics -o ../../timezones_modified.ics\n";

getopts('t:o:') or die "$usage";

die "$usage" if (!$opt_t || !$opt_o);

$src = "$opt_t";
$dst = "$opt_o";

die "values of -t and -o must be different" if $src eq $dst;

open(SRC, "$src") || die "No $src file - exit";
open(DST, ">", "$dst") || die "$dst could not open - exit";

while (my $line = <SRC>)
{
    print DST $line;
    if ($line eq "TZID:Europe/Dublin\n") {
        updateDublin();
    }
}
close(SRC);
close(DST);

sub updateDublin {
    my $inStandard = 0;
    my $inDaylight = 0;
    my @standardBlock = ("BEGIN:STANDARD\n");
    my @daylightBlock = ("BEGIN:DAYLIGHT\n");

    while (my $line = <SRC>) {
        if ($line =~ /^TZID:/) {
            print DST $line;
            last;
        }

        if ($line eq "BEGIN:STANDARD\n") {
            $inStandard = 1;
            next;
        } elsif ($line eq "BEGIN:DAYLIGHT\n") {
            $inDaylight = 1;
            next;
        }

        if ($inStandard) {
            if ($line eq "END:STANDARD\n") {
                $inStandard = 0;
                push @daylightBlock, "END:DAYLIGHT\n";
            } else {
                push @daylightBlock, $line;
            }
        } elsif ($inDaylight) {
            if ($line eq "END:DAYLIGHT\n") {
                $inDaylight = 0;
                push @standardBlock, "END:STANDARD\n";

                # Write opposite data
                print DST @standardBlock;
                print DST @daylightBlock;
            } else {
                push @standardBlock, $line;
            }
        } else {
            print DST $line;
        }
    }
}
