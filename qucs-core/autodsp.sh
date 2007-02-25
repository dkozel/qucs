#! /usr/bin/perl
#
# autodsp -- Run this script to re-generate all Windows projects.
#
# Copyright (C) 2001, 2002, 2005 Stefan Jahn <stefan@lkcc.org>
#
# This is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
# 
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this package; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 51 Franklin Street - Fifth Floor,
# Boston, MA 02110-1301, USA.  
#
# $Id: autodsp.sh,v 1.1 2007-02-25 16:57:35 ela Exp $
#

use strict;

# package constants
my $VERSION = "1.0.2";
my $PACKAGE = "autodsp";

# options
my $verbose = 0;
my $version = "5.00";
my $codepage = "0x409";
my $extradefs = " /D \"__MINGW32__\" /D \"HAVE_CONFIG_H\" /D __STDC__=0";

my @input_files = find_input_files ();

check_arguments (@ARGV);

foreach (@input_files) {
    my $file = $_;
    create_ap ($file, read_ap ($file));
}

#
# find input files
#
sub find_input_files {

    my @files = `find . -name "*.ap" -type f`;
    foreach (@files) {
        chop $_;
        s/^\.\/(.*)$/$1/;
    }
    return @files;
}

#
# check the command line
#
sub check_arguments {

    my (@args) = @_;

    while (@args) {

	if (@args[0] eq "--verbose" || @args[0] eq "-v") {
	    $verbose = 1;
	} elsif (@args[0] eq "--vc5" || @args[0] eq "-5") {
	    $version = "5.00";
	} elsif (@args[0] eq "--vc6" || @args[0] eq "-6") {
	    $version = "6.00";
	} elsif (@args[0] eq "--version" || @args[0] eq "-V") {
	    print "$PACKAGE $VERSION\n";
	    exit 0;
	} elsif (@args[0] eq "--help" || @args[0] eq "-h") {
	    print "Usage: autodsp [options]
Options:
  -h, --help           display this help message
  -v, --verbose        list processed file(s)
  -5, --vc5            generate version 5.00 files (default)
  -6, --vc6            generate version 6.00 files
  -V, --version        print version number, then exit\n";
	    exit 0;
	}
	shift @args;
    }
}

#
# convert -l linker flags
#
sub replace_libs {

    my ($prefix) = @_;
    my $libs = "";
    foreach (split (/ /, shift @_)) {
	if (m/^.*\.lib$/) {
	    s/^-l(\S+)$/$1/;
	} else {
	    s/^-l(\S+)$/lib$1\.lib/;
	}
	$libs .= " " . $_;
    }
    return $libs;
}

#
# convert -L linker flags
#
sub replace_ldflags {

    my ($ldflags, $prefix) = @_;
    my $flags = "";
    foreach (split (/ /, $ldflags)) {
	if ($prefix =~ m/^$/) {
	    s/^-L(\S+)$/\/libpath:\"$1\"/;
	} else {
	    s/^-L(\S+)$/\/libpath:\"$1\/$prefix\"/;
	}
	$flags .= " " . $_;
    }
    return $flags;
}

#
# convert -D cpp flags
#
sub replace_defs {

    my $defs = "";
    foreach (split (/ /, shift @_)) {
	if (/^-D(\S+)=(.*)$/) {
	    $_ = "/D $1=$2";
	} else {
	    s/^-D(\S+)$/\/D \"$1\"/;
	}
	$defs .= " " . $_;
    }
    return $defs;
}

#
# convert -I cpp flags
#
sub replace_includes {

    my $includes = "";
    foreach (split (/ /, shift @_)) {
	s/^-I(\S+)$/\/I \"$1\"/;
	$includes .= " " . $_;
    }
    return $includes;
}

#
# creates DSP (Developer Studio Project) file or DSW (Developer Studio 
# Workspace) file depending on the target type
#
sub create_ap {

    my ($file, %variables) = @_;

    die "autodsp: No TARGET_TYPE specified\n" unless 
	defined $variables{'TARGET_TYPE'};

    if ($variables{'TARGET_TYPE'} =~ /project/i) {
	create_dsw ($file, %variables);
    } else {
	create_dsp ($file, %variables);
    }
}

#
# creates a Workspace file
#
sub create_dsw {

    my ($infile, %variables) = @_;
    local (*OUT_FILE);
    my ($f, $s, $orgfile, $p, $file, $suffix);
    
    # create output file
    $suffix = ".dsw";
    $file = $infile;
    $orgfile = $file;
    $file =~ s/^(.*)\.ap$/$1$suffix/;
    open (OUT_FILE, ">".$file) || 
	die "autodsp: couldn't create \`$file': $!\n";
    print "autodsp: creating $file\n" if $verbose;

    # check OWNER; then print file header
    die "autodsp: $orgfile: No OWNER specified\n"
	unless defined $variables{'OWNER'};
    print OUT_FILE 
	"Microsoft Developer Studio Workspace File, " .
	"Format Version ". $version ."\r\n";

    # print autodsp header
    $orgfile = `basename $orgfile`; chop $orgfile;
    $file = `basename $file`; chop $file;
    print OUT_FILE
	"#\r\n" .
	"# $file generated by $PACKAGE $VERSION from $orgfile\r\n" .
	"#\r\n\r\n";

    # check PROJECTS; then print all
    die "autodsp: $orgfile: No PROJECTS specified\n" 
	unless defined $variables{'PROJECTS'};
    foreach $s (split (/ /, $variables{'PROJECTS'})) {

	$p = `basename $s`;
	chop $p;
	$f = $s;
	$f =~ s/\\/\//g;
	$f .= ".dsp";

	print OUT_FILE
	    "Project: \"" . $p . "\"=\"" . $f . "\"" .
	    " - Package Owner=" . $variables{'OWNER'} . "\r\n\r\n";

	# check dependencies
	if (defined ($variables{$p."_DEPENDENCIES"})) {

	    print OUT_FILE
		"Package=" . $variables{'OWNER'} . "\r\n" .
		"{{{\r\n";
	    # output each dependency
	    foreach (split (/ /, $variables{$p."_DEPENDENCIES"})) {
		print OUT_FILE 
		    "    Begin Project Dependency\r\n" .
		    "    Project_Dep_Name " . $_ . "\r\n" .
		    "    End Project Dependency\r\n";
	    }
	    print OUT_FILE "}}}\r\n";
	}
    }

    close (OUT_FILE);
    return;
}

#
# creates a Project file
#
sub create_dsp {

    my ($infile, %variables) = @_;
    local (*OUT_FILE);
    my ($o, $b, $s, $type, %types, $orgfile, $file, $suffix, $special, $c, $d);

    # types of targets
    %types = (
	      "0x0103" => "\"Win32 (x86) Console Application\"",
	      "0x0102" => "\"Win32 (x86) Dynamic-Link Library\"",
	      "0x0104" => "\"Win32 (x86) Static Library\"",
	      "0x0101" => "\"Win32 (x86) Application\"",
	      );

    # create output file
    $suffix = ".dsp";
    $file = $infile;
    $orgfile = $file;
    $file =~ s/^(.*)\.ap$/$1$suffix/;
    open (OUT_FILE, ">".$file) || 
	die "autodsp: couldn't create \`$file': $!\n";
    print "autodsp: creating $file\n" if $verbose;

    # check OWNER and NAME; then print file header
    die "autodsp: $orgfile: No OWNER specified\n"
	unless defined $variables{'OWNER'};
    die "autodsp: $orgfile: No NAME specified\n"
	unless defined $variables{'NAME'};
    die "autodsp: $orgfile: Invalid OWNER specified\n" 
	unless $variables{'OWNER'} =~ m/^<[0-9]>$/;
    die "autodsp: $orgfile: Invalid NAME specified\n" 
	unless $variables{'NAME'} =~ m/^[a-zA-Z0-9]*$/;
    print OUT_FILE 
	"# Microsoft Developer Studio Project File - Name=\"" . 
	$variables{'NAME'} . 
	"\" - Package Owner=" . $variables{'OWNER'} . "\r\n";
    print OUT_FILE
	"# Microsoft Developer Studio Generated Build File, " .
	"Format Version ". $version ."\r\n";

    # print autodsp header
    $orgfile = `basename $orgfile`; chop $orgfile;
    $file = `basename $file`; chop $file;
    print OUT_FILE
	"#\r\n" .
	"# $file generated by $PACKAGE $VERSION from $orgfile\r\n" .
	"#\r\n\r\n";

    # check TARGET_TYPE; then print it
    $s = $variables{'TARGET_TYPE'};
    if ($s =~ /console.*app/i) {
	$type = "0x0103";
    } elsif ($s =~ /dll/i) {
	$type = "0x0102";
    } elsif ($s =~ /static.*lib/i) {
	$type = "0x0104";
    } elsif ($s =~ /win32.*app/i) {
	$type = "0x0101";
    } else {
	die "autodsp: $orgfile: Invalid TARGET_TYPE specified\n";
    }
    print OUT_FILE "# TARGTYPE " . $types{$type} . " " . $type . "\r\n\r\n";

    # check special App/Lib type
    if ($s =~ /Qt/) {
	$special = "Qt";
    }
    else {
	$special = "";
    }

    # these !MESSAGE's are necessary
    print OUT_FILE "!MESSAGE There are 2 configurations.\r\n";
    print OUT_FILE
	"!MESSAGE \"" . $variables{'NAME'} . " - Win32 Release\" " .
	"(based on " . $types{$type} . ")\r\n";
    print OUT_FILE
	"!MESSAGE \"" . $variables{'NAME'} . " - Win32 Debug\" " .
	"(based on " . $types{$type} . ")\r\n";

    # output project header
    print OUT_FILE "\r\n# Begin Project\r\n";
    print OUT_FILE 
	"CPP=cl.exe\r\n" . 
	"RSC=rc.exe\r\n" . 
	"BSC32=bscmake.exe\r\n" . 
	"LINK32=link.exe\r\n" . 
	"LIB32=link.exe -lib\r\n" . 
	"MTL=midl.exe\r\n";

    # generate release target
    print OUT_FILE 
	"\r\n!IF \"\$(CFG)\" == \"" . $variables{'NAME'} . 
	" - Win32 Release\"\r\n\r\n";
    print OUT_FILE create_opt ($type, $special, %variables);

    # generate debug target
    print OUT_FILE 
	"\r\n!ELSEIF \"\$(CFG)\" == \"" . $variables{'NAME'} . 
	" - Win32 Debug\"\r\n\r\n";
    print OUT_FILE create_dbg ($type, $special, %variables);

    print OUT_FILE "\r\n!ENDIF\r\n\r\n";

    # print target header
    print OUT_FILE 
	"# Begin Target\r\n" .
	"# Name \"" . $variables{'NAME'} . " - Win32 Release\"\r\n" .
	"# Name \"" . $variables{'NAME'} . " - Win32 Debug\"\r\n\r\n";

    # check SOURCES; then print all
    die "autodsp: No SOURCES specified\n" 
	unless defined $variables{'SOURCES'};
    foreach $s (split (/ /, $variables{'SOURCES'})) {
	$s =~ s/\\/\//g;
	print OUT_FILE
	    "# Begin Source File\r\n" .
	    "SOURCE=\"" . $s . "\"\r\n" .
	    "# End Source File\r\n\r\n";
    }

    foreach $s (split (/ /, $variables{'MOCHEADERS'})) {
	$s =~ s/\\/\//g;
	$o = $s;
        $o =~ s/\.h/.moc.cpp/g;
	$b = $s;
        $b =~ s/\.h//g;
	$d = $b;
	$d =~ s/[^a-zA-Z]/_/g;
	$c =
	    "# Begin Custom Build - MOC'ing " . $s . " ...\r\n" .
	    "InputPath=" . $s . "\r\n" .
            "InputName=" . $b . "\r\n" .
            "\"\$(InputName).moc.cpp\" : " .
	    "\$(SOURCE) \"\$(INTDIR)\" \"\$(OUTDIR)\"" . "\r\n" .
            "\t%QTDIR%\\bin\\moc -o \$(InputName).moc.cpp \$(InputName).h\r\n".
	    "# End Custom Build\r\n";

	print OUT_FILE
	    "# Begin Source File\r\n" .
	    "SOURCE=\"" . $s . "\"\r\n" .
	    "\r\n!IF \"\$(CFG)\" == \"" . $variables{'NAME'} . 
	    " - Win32 Release\"\r\n\r\n" .
	    $c .
	    "\r\n!ELSEIF \"\$(CFG)\" == \"" . $variables{'NAME'} . 
	    " - Win32 Debug\"\r\n\r\n" .
	    $c .
	    "\r\n!ENDIF\r\n\r\n" .
	    "# End Source File\r\n\r\n" .
	    "# Begin Source File\r\n" .
	    "SOURCE=\"" . $o . "\"\r\n" .
 	    "USERDEP_" . $d . "=\"" . $s . "\"\r\n" .
	    "# End Source File\r\n\r\n";
    }

    # print target and project footer
    print OUT_FILE
	"# End Target\r\n" .
	"# End Project\r\n";

    close (OUT_FILE);
    return;
}

#
# returns linker and cflags depending on the $debugdef variable and the 
# target type (DLL or Application)
#
sub check_target_type {

    my ($type, $debugdef) = @_;
    my ($submode, $mktyplib, $subsys, $suffix);

    if ($type eq "0x0102") {
	$submode = "/D " . $debugdef . " /D \"_WINDOWS\"";
	$mktyplib = "# ADD MTL /nologo /D " . $debugdef . 
	    " /mktyplib203 /o NUL /win32\r\n";
	$subsys = "/subsystem:windows /dll";
	$suffix = ".dll";
    } elsif ($type eq "0x0103") {
	$submode = "/D " . $debugdef . " /D \"_CONSOLE\" /D \"_MBCS\"";
	$mktyplib = "";
	$subsys = "/subsystem:console";
	$suffix = ".exe";
    } elsif ($type eq "0x0104") {
	$submode = "/D " . $debugdef . " /D \"_WINDOWS\"";
	$mktyplib = "";
	$subsys = "/subsystem:windows /dll";
	$suffix = ".lib";
    } elsif ($type eq "0x0101") {
	$submode = "/D " . $debugdef . " /D \"_CONSOLE\" /D \"_MBCS\"";
	$mktyplib = "";
	$subsys = "/subsystem:windows";
	$suffix = ".exe";
    }
    return ($submode, $mktyplib, $subsys, $suffix);
}

#
# generates `General' dialog
#
sub create_general {

    my ($builddir, $debuglib) = @_;
    return
	"# PROP Use_MFC 0\r\n" .
	"# PROP Use_Debug_Libraries " . $debuglib . "\r\n" .
	"# PROP Output_Dir \"" . $builddir . "\"\r\n" .
	"# PROP Intermediate_Dir \"" . $builddir . "\"\r\n" .
	"# PROP Ignore_Export_Lib 0\r\n" .
	"# PROP Target_Dir \"\"\r\n";
}

#
# generates `Other' dialogs
#
sub create_others {

    my ($mktyplib, $debugdef) = @_;
    return
	$mktyplib .
	"# ADD RSC /l " . $codepage . " /d " . $debugdef . "\r\n" .
	"# ADD BSC32 /nologo\r\n" .
	"# ADD LIB32 /nologo\r\n" ;
}

#
# generates the Release target
#
sub create_opt {

    my ($type, $special, %variables) = @_;
    my ($debugdef, $debugldflag, $ret, $s, $submode, $mktyplib, $subsys,
	$suffix, $builddir, $debuglib, $cflags);

    $debugdef = "\"NDEBUG\"";
    $debugldflag = " ";
    $builddir = "Opt";
    $debuglib = "0";
    if ($special eq "Qt") {
	$cflags = "/MD ";
    } else {
	$cflags = "/MD ";
    }
    $cflags .= "/W3 /GX /O2 /Ob2";

    ($submode, $mktyplib, $subsys, $suffix) = 
	check_target_type ($type, $debugdef);

    $ret = create_general ($builddir, $debuglib);

    $ret .= "# ADD CPP /nologo " . $cflags;
    if (defined $variables{'INCLUDES'}) {
	$ret .= replace_includes ($variables{'INCLUDES'});
    }
    $ret .= " /D \"WIN32\" " . $submode;
    $ret .= $extradefs;
    if (defined $variables{'DEFS'}) {
	$ret .= replace_defs ($variables{'DEFS'});
    }
    if (defined $variables{'opt_DEFS'}) {
	$ret .= replace_defs ($variables{'opt_DEFS'});
    }
    $ret .= " /FD /c\r\n";

    $ret .= create_others ($mktyplib, $debugdef);
    
    $ret .= "# ADD LINK32 kernel32.lib";
    if (defined $variables{'LIBS'}) {
	$ret .= replace_libs ($variables{'LIBS'});
    }
    $ret .= " /nologo " . $subsys . " /pdb:none /incremental:no" . 
	$debugldflag . "/machine:I386";
    if ($special eq "Qt") {
	$ret .= " /nodefaultlib:\"msvcrtd\"";
    }
    if (defined $variables{'TARGET'}) {
	$ret .= " /out:\"". $variables{'TARGET'} . $suffix . "\"";
    }
    if (defined $variables{'LDFLAGS'}) {
	$ret .= replace_ldflags ($variables{'LDFLAGS'}, $builddir);
    }
    if (defined $variables{'all_LDFLAGS'}) {
	$ret .= replace_ldflags ($variables{'all_LDFLAGS'}, "");
    }
    $ret .= "\r\n";
    
    return $ret;
}

#
# generates the Debug target
#
sub create_dbg {

    my ($type, $special, %variables) = @_;
    my ($debugdef, $ret, $s, $submode, $mktyplib, $subsys, $suffix, 
	$debugldflag, $builddir, $debuglib, $cflags);

    $debugdef = "\"_DEBUG\"";
    $debugldflag = " /debug ";
    $builddir = "Dbg";
    $debuglib = "1";
    if ($special eq "Qt") {
	$cflags = "/MDd ";
    } else {
	$cflags = "/MDd ";
    }
    $cflags .= "/W3 /GX /Zi /Od";

    ($submode, $mktyplib, $subsys, $suffix) = 
	check_target_type ($type, $debugdef);
    
    $ret = create_general ($builddir, $debuglib);

    $ret .= "# ADD CPP /nologo " . $cflags;
    if (defined $variables{'INCLUDES'}) {
	$ret .= replace_includes ($variables{'INCLUDES'});
    }
    $ret .= " /D \"WIN32\" " . $submode;
    $ret .= $extradefs;
    if (defined $variables{'DEFS'}) {
	$ret .= replace_defs ($variables{'DEFS'});
    }
    if (defined $variables{'dbg_DEFS'}) {
	$ret .= replace_defs ($variables{'dbg_DEFS'});
    }
    $ret .= " /FD /c\r\n";

    $ret .= create_others ($mktyplib, $debugdef);
    
    $ret .= "# ADD LINK32 kernel32.lib";
    if (defined $variables{'LIBS'}) {
	$ret .= replace_libs ($variables{'LIBS'});
    }
    $ret .= " /nologo " . $subsys . " /pdb:none /incremental:no" . 
	$debugldflag . "/machine:I386";
    if ($special eq "Qt") {
	#$ret .= " /nodefaultlib:\"msvcrtd\"";
	$ret .= "";
    }
    if (defined $variables{'TARGET'}) {
	$ret .= " /out:\"". $variables{'TARGET'} . $suffix . "\"";
    }
    if (defined $variables{'LDFLAGS'}) {
	$ret .= replace_ldflags ($variables{'LDFLAGS'}, $builddir);
    }
    if (defined $variables{'all_LDFLAGS'}) {
	$ret .= replace_ldflags ($variables{'all_LDFLAGS'}, "");
    }
    $ret .= "\r\n";
    
    return $ret;
}

#
# read a single .ap file and return a var->value hash
#
sub read_ap {

    my ($file) = @_;
    local (*IN_FILE);
    my ($line, $var, $value, %ret);

    open (IN_FILE, $file) || die "autodsp: couldn't open \`$file': $!\n";
    print "autodsp: reading $file\n" if $verbose;

    while (<IN_FILE>) {

	# clear end of lines; skips comments
	$line = $_;
	$line =~ s/[\r\n]//g;
	$line =~ s/^(.*)\#.*/$0/;

	# continues reading after trailing '\'
	while ($line =~ m/^.*\\$/) {
	    chop $line;
	    $line .= " " . <IN_FILE>;
	    $line =~ s/[\r\n]//g;
	    $line =~ s/^([^\#]*)\#.*/$1/;
	}

	# drop tabs and replace double spaces
	$line =~ s/\t/ /g;
	$line =~ s/[ ]+/ /g;

	# parse VAR=VALUE assignments
	if ($line =~ m/^([^=]*)=(.*)$/) {
	    $var = $1;
	    $value = $2;
	    $var =~ s/^\s*(\S*)/$1/;
	    $var =~ s/(\S*)\s*$/$1/;
	    $value =~ s/^\s*(\S*)/$1/;
	    $value =~ s/(\S*)\s*$/$1/;
	    $ret{$var} = $value;
	}
    }
    close (IN_FILE);
    return %ret;
}
