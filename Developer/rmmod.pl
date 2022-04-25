#!/usr/bin/perl
use strict;
use File::Find;

my %depend;      # the modules a given module depends on
my @modlist;     # the modules in this directory
my %reqmodules;  # the modules not in this directory
my %loaded;      # the currently loaded modules
my @selected;    # the selection of modules to load

# Device debug parameters
#		Module name		   Debug option
my %debug = (	"tuner"			=> "tuner_debug=1",
		"dvb-core"		=> "cam_debug=1",
		"dvb-ttpci"		=> "debug=247",
		"b2c2-flexcop"		=> "debug=0x01",
		"b2c2-flexcop-usb"	=> "debug=0x01",
		"b2c2-flexcop-pci"	=> "debug=0x01",
		"dvb-usb"		=> "debug=0x33",
		"dvb-usb-gp8psk"	=> "debug=0x03",
		"dvb-usb-vp7045"	=> "debug=0x03",
		"dvb-usb-dtt200u"	=> "debug=0x03",
		"dvb-usb-dibusb-common"	=> "debug=0x03",
	    );

sub findprog($)
{
# Find the given program file.

	foreach(split(/:/, $ENV{PATH}),qw(/sbin /usr/sbin /usr/local/sbin)) {
		return "$_/$_[0]" if(-x "$_/$_[0]");
	}
	die "Can't find needed utility '$_[0]'";
}

# All necessary external programs:

my $modinfo  = findprog('modinfo');
my $modprobe = findprog('modprobe');
my $insmod   = findprog('insmod');
my $rmmod    = findprog('rmmod');

sub execprog($)
{
# Execute the given program call.

	my $cmd = shift;
	print "$cmd\n";
	system $cmd;
}

sub getdeps($)
{
# Store the dependencies of the given module in the global %depend.

	my $module = shift;

	my @m = ();
	for (`$modinfo -F depends $module.ko`) {
		chomp;
		push @m, split(',');
	}
	$depend{$module} = join(' ', @m);
}

sub completedeps()
{
# Check for any module dependencies that are not yet in the global %depend.

	my $found;
	do {
		$found = 0;
		while (my ($k, $v) = each(%depend)) {
			for (split(' ', $v)) {
				if (!exists($depend{$_}) && -e "$_.ko") {
					getdeps($_);
					$found = 1;
				}
			}
		}
	} while ($found);
}

sub parse_dir()
{
	my $file = $File::Find::name;
	return unless ($file =~ /\.ko$/);
	$file =~ s/^[.\/]*(.*)\.ko/$1/;
	getdeps($file);
}

sub parse_loaded()
{
# Detect all loaded modules and store them in the global @loaded.

	open IN,  "/proc/modules";
	while (<IN>) {
		m/^([\w\d_-]+)/;
		$loaded{$1} = 1;
	}
	close IN;
}

sub cleandep()
{
# Extract those modules from the dependencies that are not already in %depend
# and store them in the global %reqmodules.

	my %depend2 = ();

	while (my ($k, $v) = each(%depend)) {
		my @v2 = ();
		for (split(' ', $v)) {
			if (exists($depend{$_})) {
				push @v2, $_;
			} else {
				$reqmodules{$_} = 1;
			}
		}
		$depend2{$k} = join(' ', @v2);
	}
	%depend = %depend2;
}

sub contains($@)
{
	my ($s, @a) = @_;
        for (@a) {
        	return 1 if $s eq $_;
        }
	return 0;
}

sub rmdep(@)
{
# Remove the given dependencies from the global %depend.

	for my $dep (@_) {
		while (my ($k, $v) = each(%depend)) {
			while ($v =~ s/(\A|\s+)$dep(\s+|\z)/ /) {}; # there may be multiple occurrences
			$v =~ s/^\s*(.*)\s*$/$1/; # strip leading and trailing blanks
			$depend{$k} = $v;
		}
	}
}

sub orderdep()
{
# Find every module that has no more dependencies and add it to the
# global @modlist.

	my $found;
	do {
		my @nodep = ();
		$found = 0;
		while (my ($k, $v) = each(%depend)) {
			if (!$v) {
				push @nodep, $k;
				push @modlist, $k unless contains($k, @selected);
				delete $depend{$k};
				$found = 1;
			}
		}
		rmdep(@nodep);
	} while ($found);
        push @modlist, @selected; # selected modules shall be loaded in the given sequence
	while (my ($k, $v) = each(%depend)) {
		print "ERROR: bad dependencies - $k ($v)\n";
	}
}

sub insmod($)
{
# Load all necessary modules with optional debug parameters.

	my $debug = shift;

	for (keys %reqmodules) {
		execprog("$modprobe $_");
	}

	for (@modlist) {
		my $dbg = $debug ? " $debug{$_}" : "";
		execprog("$insmod ./$_.ko$dbg");
	}
}

sub rmmod()
{
# Remove all loaded modules.

	for (reverse @modlist) {
		(my $m = $_) =~ s/\-/_/g;
		if (exists($loaded{$m})) {
			execprog("$rmmod $m");
		}
	}
}

sub prepare_cmd()
{
# Find all modules in this directory and order them by dependencies.

	if (@selected) {
		for (@selected) {
			getdeps($_);
		}
		completedeps();
	}
	else {
		find(\&parse_dir, ".");
	}
	my $n = keys %depend;
	print "found $n modules\n";
	cleandep();
	orderdep();
}

# main

my $mode = shift;
@selected = @ARGV;

if ($mode eq "load") {
	prepare_cmd;
	insmod(0);
} elsif ($mode eq "unload") {
	prepare_cmd;
	parse_loaded;
	rmmod;
} elsif ($mode eq "reload") {
	prepare_cmd;
	parse_loaded;
	rmmod;
	insmod(0);
} elsif ($mode eq "debug") {
	prepare_cmd;
	parse_loaded;
	insmod(1);
} elsif ($mode eq "check") {
	prepare_cmd;
	parse_loaded;
} else {
	print "Usage: $0 load|unload|reload|debug|check [modules...]\n";
}
