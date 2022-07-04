#!/usr/bin/perl

# ================================================================================
# "rpmsnap.pl": Take an audit snapshot of the current RPM package list installed
# on your machine and print the results to STDOUT. Also run "rpm --verify" if
# so demanded (in case the parameter --verify has been passed)
#
# Maintainer: David Tonhofer <ronerycoder@gluino.name>
# ================================================================================
# Distributed under the MIT License.
# See http://www.opensource.org/licenses/mit-license.php
#
# Copyright (c) 2011 by M-PLIFY S.A.
#                       21, rue Glesener
#                       L-1631 Luxembourg
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# ================================================================================
# 2022-06-25 - Code reorganized. Added parameter handling via Getopt::Long.
#              Made it possible to handle caret character in package version
#              string
# ================================================================================

use strict;
use warnings;

use Getopt::Long;   # Perl core module (to process long options)
use File::Basename; # Perl core module

use utf8;         # Meaning "This lexical scope (i.e. file) contains utf8"

my $RPM = "/bin/rpm";

my $params  = handleCmdlineArgs();
my $verify  = $$params{verify};
my $verbose = $$params{verbose}; # a numeric value 0 = off, 1 = more, 2 = even more
my $dotify  = $$params{dotify};

# ---
# Slurp overall list of RPMs into @rpmlines; each package gives rise to several lines of attribute = value pairs.
# ---

my $rpmlines = slurpPackageList();

if ($verbose > 0) {
   print STDERR "Collected " . int(@$rpmlines) . " lines from the 'rpm' command.\n";
}

# ---
# For each RPM named in the above list, get details
# ---

my $packages        = {}; # Map "package key" (a composite key) to "reference-to-hash", where the hash details the package
my $missingStuff    = {}; # Map "package key" (a composite key) to "reference-to-array", where the array contains names of files that are missing
my $packageProblems = []; # Array of strings: problems during processing

makePackageHashes($rpmlines,$packages,$missingStuff,$packageProblems,$verify,$verbose);

if ($verbose > 0) {
   print STDERR "Obtained " . int(keys %$packages) . " packages.\n";
}

# ---
# OUTPUT: Any problems encountered while querying packages go to STDERR
# ---

for my $problem (@$packageProblems) {
   print STDERR "$problem\n"
}

# ---
# OUTPUT: Print "missing stuff" to STDERR
# (formerly to STDOUT, but it's no use found inside a file of records, so STDERR it is)
# ---

{
   my $missingCount = 0;
   foreach my $pkgKey (sort keys %$missingStuff) {
      my $missingFiles = $$missingStuff{$pkgKey};
      foreach my $file (@$missingFiles) {
         $missingCount++;
         my $pkgHash  = $$packages{$pkgKey};
         my $pkgName  = $$pkgHash{NAME};
         my $pkgDesig = $$pkgHash{DESIGNATOR};
         print STDERR sprintf("Missing file %-30s from %s\n","'$file'",$pkgDesig)
      }
   }
   print STDERR sprintf("Total files missing: %d\n",$missingCount)
}

# ---
# OUTPUT: Determine field widths for good formatting based on contents of "packages"
# ---

{
   my $maxWidths = findMaxWidths($packages);
   my $formatL   = "%-$$maxWidths{NAME}s   %-$$maxWidths{VERSION}s   %-$$maxWidths{RELEASE}s   %-$$maxWidths{ARCH}s   %-$$maxWidths{VENDOR}s";
   my $formatS   = "%s";
   my $formatV   = "%15s  %5i  %s";
   foreach my $pkgKey (sort { lc($a) cmp lc($b) } keys %$packages) {
      my $pkgHash    = $$packages{$pkgKey};
      my $pkgName    = $$pkgHash{NAME};
      my $pkgVersion = $$pkgHash{VERSION};
      my $pkgRelease = $$pkgHash{RELEASE};
      my $pkgArch    = $$pkgHash{ARCH};
      my $pkgVendor  = $$pkgHash{VENDOR};
      my $buildDate  = $$pkgHash{BUILDDATE};
      my $left;
      my $right;
      if ($verify) {
         my $verifySums   = $$pkgHash{VERIFYSUMS};
         my $verifyString = makeVerifyString($verifySums);
         my $numLines     = $$pkgHash{NUMLINES};
         $left  = sprintf($formatL,$pkgName,$pkgVersion,$pkgRelease,$pkgArch,$pkgVendor);
         $right = sprintf($formatV,$verifyString,$numLines,$buildDate);
      }
      else {
         $left  = sprintf($formatL,$pkgName,$pkgVersion,$pkgRelease,$pkgArch,$pkgVendor);
         $right = sprintf($formatS,$buildDate);
      }
      if ($dotify) {
         $left =~ s/ /./g; # replace space by a dot for better legibility
      }
      print "${left}:  ${right}\n"
   }
}

# -------------------------------------------------
# Functions below
# -------------------------------------------------

# ---
# Helper to create package designator from package hash.
# Result must be what "rpm" expects as input for package retrieval.
# ---

sub makePackageDesignator {
   my($pkgHash) = @_;
   my $res = "$$pkgHash{NAME}-$$pkgHash{VERSION}-$$pkgHash{RELEASE}";
   # When to add the architecture?
   # RPM does not take kindly to a "(none)" when used in a query...
   my $arch = $$pkgHash{ARCH};
   if ($arch ne '(none)') {
      $res = "$res.$arch" # just append, do not add "-"
   }
   return $res
}

# ---
# Create the string which represents the result of package verification from the
# previously processed rpm result, it is already a summary over all files of the
# package.
# ---

sub makeVerifyString {
   my($verifySums) = @_;
   my $res = "";
   for my $flag ('S','M','5','D','L','U','G','T','P') {
      if (exists $$verifySums{$flag}) {
         if ($$verifySums{$flag}==1)     { $res .= $flag; } # There is at least one file for which this test failed
         elsif ($$verifySums{$flag}==-1) { $res .= '?';   } # There is at least one file on which the test was not performed
         else                            { $res .= '.';   } # For all the files, the test passed
      }
      else {
         $res .= 'x'; # missing flag
      }
   }
   return $res;
}

# ---
# Create a hash containing info about some package.
# If "verbose" is >= 3 you get a lot of additional messages on STDERR.
# ---

sub makeSinglePackageHashInner {
   my($pkgProblems,$theName,$theVersion,$theRelease,$theBuildDate,$theVendor,$theArch,$verify,$verbose) = @_;
   #
   # If not all filled, die. Check whether "defined", not just truthyness, because values may be "0"
   #
   my $txt = "Name=[$theName] Version=[$theVersion] Release=[$theRelease] Vendor=[$theVendor] Arch=[$theArch] BuildDate=[$theBuildDate]";
   {
      my $stop = 0;
      if (!defined($theName))      { print STDERR "NAME is missing for $txt\n";      $stop = 1 }
      if (!defined($theVersion))   { print STDERR "VERSION is missing for $txt\n";   $stop = 1 }
      if (!defined($theRelease))   { print STDERR "RELEASE is missing for $txt\n";   $stop = 1 }
      if (!defined($theBuildDate)) { print STDERR "BUILDTIME is missing for $txt\n"; $stop = 1 }
      if (!defined($theArch))      { print STDERR "ARCH is missing for $txt\n";      $stop = 1 }
      if (!defined($theVendor))    { print STDERR "VENDOR is missing for $txt\n";    $stop = 1 }
      if ($stop) {
         die "Could not get all the values -- exiting!\n";
      }
   }
   #
   # Prepare response hash
   #
   my $pkgHash = {
      NAME      => $theName,
      VERSION   => $theVersion,
      RELEASE   => $theRelease,
      BUILDDATE => $theBuildDate,
      ARCH      => $theArch,
      VENDOR    => $theVendor
   };
   #
   # Add the unique designator (a string) based on contents in the hash so far, to be used for
   # rpm selection
   #
   $$pkgHash{DESIGNATOR} = makePackageDesignator($pkgHash);
   #
   # "rpm verify" if so asked, adding data
   #
   if ($verify) {
      verifyPackage($pkgHash,$pkgProblems);
      # The above added entries for VERIFYSUMS, MISSINGSTUFF, NUMLINES
      if ($verbose>=3) {
         my $txt2 = makeVerifyString($$pkgHash{VERIFYSUMS});
         print STDERR sprintf("%s: Verify=[%s] Files=[%i]\n", $txt, $txt2, $$pkgHash{NUMLINES});
      }
   }
   return $pkgHash
}

# ---
# Verify package, adding results to the hash representing the packages
# ---

sub verifyPackage {
   my($pkgHash,$pkgProblems) = @_;
   # The "designator" is a string constructed previously to feed back to the rpm query
   my $desig = $$pkgHash{DESIGNATOR};
   if ($desig =~ /\'/) {
      die "There is a \' in the package designator '$desig' -- exiting!\n";
   }
   onlyOneEntryInRpmDatabaseOrDie($desig);
   my $lines = getAllVerifyLinesForPackage($desig);
   setUpFlagValues($desig,$lines,$pkgHash,$pkgProblems)
}

# ---
# For the following two functions:
# 2022-06-22: Carets now appear in package names (preceding a git tag & commit id).
# https://pagure.io/packaging-committee/issue/904
# We need to handle that as they will be interpreted by rpm as metacharacters
# ---

sub escapeDesignator {
   my($desig) = @_;
   # escape any '^' appearing in "desig", otherwise rpm will consider those as metacharacter
   my $escDesig = $desig;
   $escDesig =~ s/\^/\\\^/g;
   # printf STDERR "$desig --> $escDesig\n";
   return $escDesig
}

# ---
# Could there be several entries matching the designator? Unlikely. Still, verify
# this and if it is found not to be the case, bail out.
# ---

sub onlyOneEntryInRpmDatabaseOrDie {
   my($desig) = @_;
   my $escDesig = escapeDesignator($desig);
   # pipe in "list form" here; the parameters are not transformed by a shell
   # https://perldoc.perl.org/functions/open
   open(my $fh,"-|") || exec($RPM,"--query",$escDesig) or die "Could not open RPM pipe: $!\n";
   my @test = <$fh>;
   close($fh) or die "Could not close RPM pipe when querying using designator '$desig'";
   if (@test != 1) {
      my $count = @test * 1;
      die "Got $count lines when querying using designator '$desig' -- exiting\n"
   }
}

# ---
# Do package verification, retrieve all lines resulting from that (one line per file)
#
# "--verify --verbose" should produce one line per file in the package; "verify" alone produces no output.
# If there is prelink problem, there will be an error message on STDERR saying that "one of
# the prerequisites changed". These errors can be fixed by collecting STDERR of this program,
# extracting the executables named in the errors, and running prelink on them, using a pipe like this:
#
# cat OUTERR | perl -n -e 'if (~/prelink: (\S+):/) { print "$1\n" }' | sort --unique | xargs prelink
# ---

sub getAllVerifyLinesForPackage {
   my($desig) = @_;
   my $escDesig = escapeDesignator($desig);
   # pipe in "list form" here; the parameters are not transformed by a shell
   # https://perldoc.perl.org/functions/open
   open(my $fh,"-|") || exec($RPM,"--verify","--verbose",$escDesig) or die "Could not open RPM pipe: $!\n";
   my @lines = <$fh>;
   # Don't care about errors here when closing.
   # Indeed "prelink" warnings lead to non-zero return!
   close($fh); # or die "Could not close RPM pipe when verifying using designator '$desig'\n"
   return \@lines # return reference, not array
}

# ---
# Collect the "rpm verify" flag values over all the files of a package.
#
#  0 == all the tests on the files of the package succeeded
#  1 == at least one of the tests on the files of the package failed
# -1 == at least one of the tests on the files of the package could not be performed, but none failed
#
# From the rpm manpage:
#
# S file Size differs
# M Mode differs (includes permissions and file type)
# 5 MD5 sum differs
# D Device major/minor number mismatch
# L readLink(2) path mismatch
# U User ownership differs
# G Group ownership differs
# T mTime differs
# P caPabilities differ <--- Not on Red Hat 5; it may be missing or be "C" for "C selinux Context differs"
#
# Each of the 8 characters denotes the result of a comparison of attribute(s)  of  the  file  to  the
# value  of  those  attribute(s)  recorded in the database.  A single "." (period) means the test passed,
# while a single "?" (question mark) indicates the test could not be performed (e.g. file permissions
# prevent reading). Otherwise, the (mnemonically emBoldened) character denotes failure of  the  corre-
# sponding --verify test
#
# c %config configuration file.
# d %doc documentation file.
# g %ghost file (i.e. the file contents are not included in the package payload).
# l %license license file.
# r %readme readme file.
# ---

# ---
# $desig       => The designator used in querying RPM database. Used in error messages.
# $lines       => The lines of "rpm verify" to be processed.
# $pkgHash     => The hash of the currently examined package. It will be extended with
#                 entries for VERIFYSUMS, MISSINGSTUFF, NUMLINES
# $pkgProblems => A list of error messages concerning problems, common for all packages.
# ---

sub setUpFlagValues {
   my($desig,$lines,$pkgHash,$pkgProblems) = @_;
   my $missingStuff = [];
   my $verifySums = {};
   my $numLines   = 0;
   foreach my $line (@$lines) {
      chomp $line;
      my $flagValues = {};
      if ($line =~ /^([S\.\?])([M\.\?])([5\.\?])([D\.\?])([L\.\?])([U\.\?])([G\.\?])([T\.\?])\s+([cdglr]\s+)?(.+)$/) {
         # On Red Hat 5 there may be no "capabilities" or "context differs" flag
         $flagValues = { 'S'=>$1,'M'=>$2,'5'=>$3,'D'=>$4,'L'=>$5,'U'=>$6,'G'=>$7,'T'=>$8 };
         $numLines++;
      }
      elsif ($line =~ /^([S\.\?])([M\.\?])([5\.\?])([D\.\?])([L\.\?])([U\.\?])([G\.\?])([T\.\?])([(P|C)\.\?])\s+([cdglr]\s+)?(.+)$/) {
         # On Red Hat 6 or later Red Hat 5, there is a "capabilities" or "context differs" flag
         $flagValues = { 'S'=>$1,'M'=>$2,'5'=>$3,'D'=>$4,'L'=>$5,'U'=>$6,'G'=>$7,'T'=>$8,'P'=>$9 };
         $numLines++;
      }
      elsif ($line =~ /^missing\s+([cdglr]\s+)?(.+)$/) {
         push(@$missingStuff,$2);
         $numLines++;
      }
      else {
         # This will be some additional info written to STDERR or STDOUT by rpm
         push(@$pkgProblems,"Verifying $desig: Could not handle line '$line'");
      }
      # If we acquired any have "flagValuess", sum those into "verifySums"
      foreach my $flag (keys %$flagValues) {
         if (! exists $$verifySums{$flag}) {
            # flag not yet seen, add it
            $$verifySums{$flag} = 0
         }
         my $value = $$flagValues{$flag};
         if ($value eq '?') {
            # test not performed; if the value is still 0 (i.e. "all tests passed")
            # switch to "at least one test not performed"
            if ($$verifySums{$flag} == 0) {
               $$verifySums{$flag} = -1
            }
         }
         elsif ($value eq '.') {
            # test is "ok", keep any previous values
            1 == 1
         }
         else {
            # test is "not ok", i.e. we have "at least one failure", whihc trumps anything
            $$verifySums{$flag} = 1
         }
      }
   }
   $$pkgHash{VERIFYSUMS}   = $verifySums;
   $$pkgHash{MISSINGSTUFF} = $missingStuff;
   $$pkgHash{NUMLINES}     = $numLines;
}

# ---
# Slurp the list of packages into an array of string, where each package yields
# a number of lines, each an attribute-value pair.
# "queryfmt" says how the output of "rpm --query" is formatted: what fields and
# how they are displayed
# Note that the name is the package's software name, e.g. "kernel" and that the
# text output by "rpm --query FOO" is a composite of "name", "version" and
# "release", e.g. "kernel-3.5.2-3.fc17.x86_64".
# List all the available tags by running 'rpm --querytags'
# ---

sub slurpPackageList {
   my $queryfmt = "ARCH: %{ARCH}\\nNAME: %{NAME}\\nVERSION: %{VERSION}\\nRELEASE: %{RELEASE}\\nBUILDTIME: %{BUILDTIME:date}\\nVENDOR: %{VENDOR}\\n";
   # pipe in "list form" here; the parameters are not transformed by a shell
   # https://perldoc.perl.org/functions/open
   open(my $pipe,"-|") || exec($RPM,"--query","--all","--queryformat=$queryfmt") or die "Could not open RPM pipe: $!\n";
   my @rpmlines = <$pipe>;
   close($pipe) or die "Could not close RPM pipe when querying all rpm packages using '$queryfmt'\n";
   return \@rpmlines # return reference not array
}

# ---
# Map the "rpmlines" into a hash of hashes, one has for each package.
# If "$verify", we also call "rpm --verify" on each package (that's the interesting part).
# ---

sub makePackageHashes {
   my ($rpmlines,$packages,$missingStuff,$packageProblems,$verify,$verbose) = @_;
   my ($theArch,$theName,$theVersion,$theRelease,$theBuildDate,$theVendor); # buffer of package attributes
   my $firstBlock = 1;
   my $counter = 0;
   # push a guard onto the rpmlines
   push @$rpmlines, "STOP";
   foreach my $line (@$rpmlines) {
      chomp $line;
      $counter++;
      if ($line =~ /^ARCH\s*:\s*(.*)$/ || $line eq "STOP") {
         # next package start; if it's not the first package encountered, store the current one in progress
         if (!$firstBlock) {
            makeSinglePackageHash($packages,$missingStuff,$packageProblems,$theName,$theVersion,$theRelease,$theBuildDate,$theVendor,$theArch,$verify,$verbose)
         }
         else {
            $firstBlock = 0
         }
         # in any case we have captured the "ARCH" of the next package; reset the rest
         if ($line ne "STOP") {
            $theArch = $1;
            ($theName,$theVersion,$theRelease,$theBuildDate,$theVendor) = (undef,undef,undef,undef,undef);
         }
      }
      elsif ($line =~ /^NAME\s*:\s*(.*)$/) {
         # current block, continued
         $theName = $1;
      }
      elsif ($line =~ /^VERSION\s*:\s*(.*)$/) {
         # current block, continued
         $theVersion = $1;
      }
      elsif ($line =~ /^RELEASE\s*:\s*(.*)$/) {
         # current block, continued
         $theRelease = $1;
      }
      elsif ($line =~ /^BUILDTIME\s*:\s*(.*)$/) {
         # current block, continued
         $theBuildDate = $1;
      }
      elsif ($line =~ /^VENDOR\s*:\s*(.*)$/) {
         # current block, continued
         $theVendor = $1;
      }
      else {
         die "Unexpected line '$line' -- exiting\n"
      }
   }
   die unless $counter == scalar(@$rpmlines);
}

# ---
# Process single package hash
# ---

sub makeSinglePackageHash {
   my ($packages,$missingStuff,$packageProblems,$theName,$theVersion,$theRelease,$theBuildDate,$theVendor,$theArch,$verify,$verbose) = @_;
   my $pkgHash =
      makeSinglePackageHashInner(
         $packageProblems, # an array of text accumulating "problems"; it will be printed lated
         $theName,         # e.g. "abattis-cantarell-fonts"
         $theVersion,      # e.g. "0.301"
         $theRelease,      # e.g. "1.fc33"
         $theBuildDate,    # e.g. "Tue 05 Jan 2021 01:38:57 PM UTC"
         $theVendor,       # e.g. "Fedora·Project"
         $theArch,         # e.g. "noarch"
         $verify,          # boolean saying whether to "verify"
         $verbose);        # verbosity level; 3 leads to lot of messages on STDERR
   # Add the packageHash to the full hash of packages $packages using a special key.
   # This key contains more attributes than the "<name>-<version>-<release>" key as used by RPM
   my $pkgKey  =
      $$pkgHash{NAME} . "|" .
      $$pkgHash{ARCH} . "|" .
      $$pkgHash{VERSION} . "|" .
      $$pkgHash{RELEASE} . "|" .
      $$pkgHash{VENDOR};
   if (!exists $$packages{$pkgKey}) {
      $$packages{$pkgKey} = $pkgHash
   }
   else {
      die "Collision? A package already exists under the key '$pkgKey' -- exiting!\n"
   }
   # Accumulate "missing stuff" (error messages about files found missing during verification
   if (exists $$pkgHash{MISSINGSTUFF}) {
      $$missingStuff{$pkgKey} = $$pkgHash{MISSINGSTUFF}
   }
}

# ---
# Simple max
# ---

sub max {
   my $a = shift;
   my $b = shift;
   return $a > $b ? $a : $b
}

# ---
# Find the max width of certain fields for formatting
# ---

sub findMaxWidths {
   my($packages) = @_;
   my $maxWidths = {};
   my $maxPkgName    = 0;
   my $maxPkgVersion = 0;
   my $maxPkgRelease = 0;
   my $maxPkgArch    = 0;
   my $maxPkgVendor  = 0;
   foreach my $pkgKey (keys %$packages) {
      my $pkgHash = $$packages{$pkgKey};
      $maxPkgName    = max(length($$pkgHash{NAME}),$maxPkgName);
      $maxPkgVersion = max(length($$pkgHash{VERSION}),$maxPkgVersion);
      $maxPkgRelease = max(length($$pkgHash{RELEASE}),$maxPkgRelease);
      $maxPkgArch    = max(length($$pkgHash{ARCH}),$maxPkgArch);
      $maxPkgVendor  = max(length($$pkgHash{VENDOR}),$maxPkgVendor);
   }
   $$maxWidths{NAME}    = $maxPkgName;
   $$maxWidths{VERSION} = $maxPkgVersion;
   $$maxWidths{RELEASE} = $maxPkgRelease;
   $$maxWidths{ARCH}    = $maxPkgArch;
   $$maxWidths{VENDOR}  = $maxPkgVendor;
   return $maxWidths
}



sub handleCmdlineArgs {

   my $help    = 0;   # print help
   my $verify  = 0;   # verify rpm packages
   my $verbose = 0;   # print debugging output
   my $error   = 0;   # processing error occured, leading to help & exit
   my $dotify  = 0;   # replace spaces by dots in output for better legibility

   my @options = (  "verify"   => \$verify
                   ,"verbose+" => \$verbose  # multiple "verbose" allowed
                   ,"dotify"   => \$dotify
                   ,"help"     => \$help);

   if (!GetOptions(@options)) {
      $error = 1;
      $help = 1;
   }

   if ($help) {
      print "\n\n" if ($error);
      {
         my $exe = basename($0);
         print STDERR "$exe\n";
         print STDERR "-" x length($exe), "\n";
      }
      print STDERR <<MSG
Generate a formatted report of the packages in the RPM database.
Optionally verify the packages.

Options:

   --help    Print this message and exit.
   --verify  Run "rpm verify" on each package and print results.
   --dotify  Replace spaces by dots in output for better legibility.
   --verbose Add some (not particularly useful) debugging ouput.
             This option can be used thrice for greater effect.

The report is printed to STDOUT. It contains one line per package. Each line
lists, in this column order:

  package name                e.g. "aajohan-comfortaa-fonts"
  package version             e.g. "3.101"
  package release             e.g. "4.fc36"
  package arichtecture        e.g. "noarch"
  package vendor              e.g. "Fedora Project"
  verification result         e.g. ".M......." (if requested)
  number of files in package  e.g. 18
  package builddate           e.g. "Wed 19 Jan 2022 09:54:02 PM CET"

If "--verify" has been requested, you will see the "verification result"
column in the output. The "verification result" describes whether there was
anything unexpected regarding the files in the package.

RPM verification consists in running a number of tests on each file in the
package. As described in the man page of rpm, there is a mnemonic letter
corresponding to each test which may go wrong:

  S => file Size differs
  M => Mode differs (includes permissions and file type)
  5 => digest (formerly MD5 sum) differs
  D => Device major/minor number mismatch
  L => readLink(2) path mismatch
  U => User ownership differs
  G => Group ownership differs
  T => mTime differs
  P => caPabilities differ

The "verification result" contains one character for each of the above in
a fixed order. That character is:

1) the corresponding mnemonic letter if at least one of the files in the
   package did not pass the corresponding test; otherwise
2) "?" if the test could not be performed on at least one of the files in
   the package (e.g. missing file or permission error); otherwise
3) "." if all the files in the package passed the test.
MSG
   }

   die  if $error;
   exit if $help;

   return {
      verify  => $verify
     ,dotify  => $dotify
     ,verbose => $verbose
   }
}

