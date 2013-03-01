#!/usr/bin/perl -w

# ================================================================================
# "rpmsnap.pl": Take an audit snapshot of the current RPM package list installed 
# on your machine and print the results to STDOUT. Also run "rpm --verify" if
# so demanded (in case the parameter --verify has been passed)
# Maintainer: d.tonhofer@m-plify.com
# ================================================================================
# Distributed under the MIT License,
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

use strict;

# ----
# Simple command line processing; use perl package Getopt::Long for more complex things
# ----

my $verify = 0;

if ($ARGV[0]) {
   if (lc($ARGV[0]) eq "--verify") {
      $verify = 1;
   }
   else {
      print "List the packages registered in the RPM database\n";
      print "  --verify : Also do an 'rpm --verify' on each package\n";
      exit 0;
   }
}

# ----
# "queryfmt" says how the output of "rpm --query" is formatted: what fields and how they are displayed
# Note that the name is the package's software name, e.g. "kernel" and that the text output by
# "rpm --query FOO" is a composite of "name", "version" and "release", e.g. "kernel-3.5.2-3.fc17.x86_64"
# ----

my $queryfmt = "ARCH: %{ARCH}\\nNAME: %{NAME}\\nVERSION: %{VERSION}\\nRELEASE: %{RELEASE}\\nBUILDTIME: %{BUILDTIME:date}\\nVENDOR: %{VENDOR}\\n";

# ----
# Hoover overall list of RPMs into @rpmlines
# ----
# 

my @rpmlines = ();

{
   open(my $pipe,"/bin/rpm --query --all --queryformat='$queryfmt' 2>&1 |") or die "Could not open RPM pipe: $!\n";
   @rpmlines = <$pipe>;
   close($pipe) or die "Could not close RPM pipe when querying all rpm packages using '$queryfmt'\n"
}

# For each RPM named in the above list, get details

my $packages        = {}; # Map "package key" (a composite key) to "reference-to-hash", where the hash details the package
my $missingStuff    = {}; # Map "package key" (a composite key) to "reference-to-array", where the array contains names of files that are missing
my $packageProblems = []; # Problems during processing            

# ----
# Add a guard to the rpmlines to simplify loop
# ----

push(@rpmlines,"STOP");

# ----
# Map the results into a hash, if "$verify", we also call "rpm --verify" on each package.
# ----

{
   my ($theArch,$theName,$theVersion,$theRelease,$theBuildDate,$theVendor);
   my $state = "OUTSIDE";
   my $counter = 0;
   my $verbose = 0;
   foreach my $line (@rpmlines) {      
      chomp $line;
      if ($line =~ /^ARCH\s*:\s*(.*)$/ || $line eq "STOP") {
         if ($state eq "OUTSIDE" && $line ne "STOP") {
            $theArch = $1;
            $state   = "INSIDE";
         }
         elsif ($state eq "INSIDE") {
            $counter++;
            # last if ($counter == 10); # used when testing to terminate early
            my $packageHash = makePackageHash($packageProblems,$theName,$theVersion,$theRelease,$theBuildDate,$theVendor,$theArch,$verify,$verbose);
            ($theName,$theVersion,$theRelease,$theBuildDate,$theVendor,$theArch) = (undef,undef,undef,undef,undef,$1);
            #
            # Add the packageHash to the hash of packages using a special key; this is larger than the "<name>-<version>-<release>" key used by RPM
            # 
            my $packageKey  = $$packageHash{NAME} . "|" . $$packageHash{ARCH} . "|" . $$packageHash{VERSION} . "|" . $$packageHash{RELEASE} . "|" . $$packageHash{VENDOR};
            if (!exists $$packages{$packageKey}) {
               $$packages{$packageKey} = $packageHash ;
            }
            else {
               print STDERR "A package already exists under the key '$packageKey' -- skipping\n";
            }
            #
            # Accumulate "missing stuff", if any
            #
            if (exists $$packageHash{MISSINGSTUFF}) {
               $$missingStuff{$packageKey} = $$packageHash{MISSINGSTUFF}
            }            
         }
         else {
            die "State is '$state' and line is '$line' -- Cannot happen\n";
         }
      }
      elsif ($line =~ /^NAME\s*:\s*(.*)$/ && $state eq "INSIDE") {
         $theName = $1;
      }
      elsif ($line =~ /^VERSION\s*:\s*(.*)$/ && $state eq "INSIDE") {
         $theVersion = $1;
      }
      elsif ($line =~ /^RELEASE\s*:\s*(.*)$/ && $state eq "INSIDE") {
         $theRelease = $1;
      }
      elsif ($line =~ /^BUILDTIME\s*:\s*(.*)$/ && $state eq "INSIDE") {
         $theBuildDate = $1;
      }
      elsif ($line =~ /^VENDOR\s*:\s*(.*)$/ && $state eq "INSIDE") {
         $theVendor = $1;
      }
      else {
         die "Line is '$line' -- Cannot happen\n";
      }
   }
}

# ----
# OUTPUT: Any problems encountered while querying packages go to STDERR
# ----

for my $problem (@$packageProblems) {
   print STDERR "$problem\n";
}

# ---- 
# OUTPUT: Print missing stuff to STDOUT
# ----

foreach my $packageKey (sort keys %$missingStuff) {
   my $missingFiles = $$missingStuff{$packageKey};
   foreach my $file (@$missingFiles) {
      my $packageHash  = $$packages{$packageKey};
      my $packageName  = $$packageHash{NAME};
      my $packageDesig = $$packageHash{DESIGNATOR};
      print sprintf("Missing file %-30s from %s\n","'$file'",$packageDesig);
   }
}

# ----
# OUTPUT: Determine field widths for good formatting
# ----

my $maxPackageName    = 0;
my $maxPackageVersion = 0;
my $maxPackageRelease = 0;
my $maxPackageArch    = 0;
my $maxPackageVendor  = 0;

sub max {
   my $a = shift;
   my $b = shift;
   return $a > $b ? $a : $b;
}

foreach my $packageKey (keys %$packages) {
   my $packageHash = $$packages{$packageKey};
   $maxPackageName    = max(length($$packageHash{NAME}),$maxPackageName);
   $maxPackageVersion = max(length($$packageHash{VERSION}),$maxPackageVersion);
   $maxPackageRelease = max(length($$packageHash{RELEASE}),$maxPackageRelease);
   $maxPackageArch    = max(length($$packageHash{ARCH}),$maxPackageArch);
   $maxPackageVendor  = max(length($$packageHash{VENDOR}),$maxPackageVendor);
}

# ----
# OUTPUT: Print formatted details to STDOUT
# ----

my $formatL = "%-${maxPackageName}s   %-${maxPackageVersion}s   %-${maxPackageRelease}s   %-${maxPackageArch}s   %-${maxPackageVendor}s";
my $formatS = "%s";
my $formatV = "%15s  %5i  %s";

foreach my $packageKey (sort { lc($a) cmp lc($b) } keys %$packages) {
   my $packageHash    = $$packages{$packageKey};   
   my $packageName    = $$packageHash{NAME};
   my $packageVersion = $$packageHash{VERSION};
   my $packageRelease = $$packageHash{RELEASE};
   my $packageArch    = $$packageHash{ARCH};
   my $packageVendor  = $$packageHash{VENDOR};
   my $buildDate      = $$packageHash{BUILDDATE};
   my $left;
   my $right;
   if ($verify) {
      my $verifySums   = $$packageHash{VERIFYSUMS}; 
      my $verifyString = makeVerifyString($verifySums);
      my $numLines     = $$packageHash{NUMLINES};
      $left  = sprintf($formatL,$packageName,$packageVersion,$packageRelease,$packageArch,$packageVendor);
      $right = sprintf($formatV,$verifyString,$numLines,$buildDate);
   }
   else {
      $left  = sprintf($formatL,$packageName,$packageVersion,$packageRelease,$packageArch,$packageVendor);
      $right = sprintf($formatS,$buildDate);
   }
   $left =~ s/ /·/g; # replace space by a dot for better legibility
   print "${left}:  ${right}\n" 
}

# --------------------------------------------------------------------------------
# Helper to create package designator from package hash; result must be what "rpm" expects
# --------------------------------------------------------------------------------

sub makePackageDesignator {
   my($packageHash) = @_;
   my $res = "$$packageHash{NAME}-$$packageHash{VERSION}-$$packageHash{RELEASE}";
   # When to add the architecture? RPM does not take kindly to a "(none)" when used in a query...
   my $arch = $$packageHash{ARCH};
   if ($arch ne '(none)') {
      $res = "$res.$arch"
   }
   return $res
}

# --------------------------------------------------------------------------------
# Create the string which comes from package verification
# --------------------------------------------------------------------------------

sub makeVerifyString {
   my($verifySums) = @_;
   my $res = "";
   for my $flag ('S','M','5','D','L','U','G','T','P') {
      if (exists $$verifySums{$flag}) {
         if ($$verifySums{$flag}==1)     { $res .= $flag; } # At least 1 error
         elsif ($$verifySums{$flag}==-1) { $res .= '?';   } # At least 1 test not performed
         else                            { $res .= '.';   } # No problem
      }
      else {         
         $res .= 'x'; # missing flag
      }
   }
   return $res;
}

# --------------------------------------------------------------------------------
# Register a package in the list of packages
# --------------------------------------------------------------------------------
 
sub makePackageHash {
   my($packageProblems,$theName,$theVersion,$theRelease,$theBuildDate,$theVendor,$theArch,$verify,$verbose) = @_;
   #
   # If not all filled, die. Check whether "defined", because values may be "0"
   #
   my $txt = "$theName $theVersion $theRelease $theVendor $theArch $theBuildDate";
   {
      my $stop = 0;
      if (!defined($theName))        { print STDERR "NAME is missing for '$txt'\n";      $stop = 1 }
      if (!defined($theVersion))     { print STDERR "VERSION is missing for '$txt'\n";   $stop = 1 }
      if (!defined($theRelease))     { print STDERR "RELEASE is missing for '$txt'\n";   $stop = 1 }
      if (!defined($theBuildDate))   { print STDERR "BUILDTIME is missing for '$txt'\n"; $stop = 1 }
      if (!defined($theArch))        { print STDERR "ARCH is missing for '$txt'\n";      $stop = 1 }
      if (!defined($theVendor))      { print STDERR "VENDOR is missing for '$txt'\n";    $stop = 1 }
      if ($stop) {
         print STDERR "Could not get all the values -- won't continue\n";
         exit 1
      }
   }
   #
   # Prepare response hash
   #
   my $res = {  NAME        => $theName,
                VERSION     => $theVersion,
                RELEASE     => $theRelease,
                BUILDDATE   => $theBuildDate,
                ARCH        => $theArch,
                VENDOR      => $theVendor };
   #
   # Add the unique designator to be used for rpm selection
   #
   $$res{DESIGNATOR} = makePackageDesignator($res);
   #
   # Verify if so asked, adding data to "res"
   #
   if ($verify) {
      my $arrayRef = verifyPackage($res,$packageProblems);
      if ($verbose) {
         print STDERR sprintf("%-20s : %15s  %5i\n", $txt, makeVerifyString($$res{VERIFYSUMS}), $$res{NUMLINES});
      }
   }
   return $res;
}

# --------------------------------------------------------------------------------
# Verify package, adding results to "res"
# --------------------------------------------------------------------------------
 
sub verifyPackage {
   my($packageHash,$packageProblems) = @_;
   my $missingStuff = [];
   #
   # "verify verbose" should produce one line per file in the package; "verify" alone produces no output
   # If there is prelink problem, there will be an error message on STDERR saying that "one of
   # the prerequisites changed". These errors can be fixed by collecting STDERR of this program, 
   # extracting the executables named in the errors, and running prelink on them, using a pipe like this:
   # cat OUTERR | perl -n -e 'if (~/prelink: (\S+):/) { print "$1\n" }' | sort --unique | xargs prelink
   # 
   my $desig = $$packageHash{DESIGNATOR};
   if ($desig =~ /\'/) {
      die "There is a \' in the package designator '$desig' -- won't continue\n";
   }
   #
   # Could there be several entries matching the designator? Verify this!
   #
   {
      open(my $fh,"/bin/rpm --query '$desig' |") or die "Could not open RPM pipe: $!\n";
      my @test = <$fh>;
      close($fh) or die "Could not close RPM pipe when querying using designator '$desig'";
      if (@test != 1) {
         my $count = @test * 1;
         die "Got $count lines when querying using designator '$desig'\n";
      }
   }
   #
   # Get verify lines using the designator
   #
   my @lines;
   {
      open(my $fh,"/bin/rpm --verify --verbose '$desig' |") or die "Could not open RPM pipe: $!\n";
      @lines = <$fh>;
      # Don't care about errors here; indeed "prelink" warnings lead to non-zero return
      close($fh) # or die "Could not close RPM pipe when verifying using designator '$desig'\n"
   }
   #
   # set up "flag values"
   #
   #  0 == all the tests on the files of the package succeeded
   #  1 == at least one of the tests on the files of the package failed
   # -1 == at least one of the tests on the files of the package could not be performed, but none failed
   #
   # From the manual:
   #
   #    S file Size differs
   #    M Mode differs (includes permissions and file type)
   #    5 MD5 sum differs
   #    D Device major/minor number mismatch
   #    L readLink(2) path mismatch
   #    U User ownership differs
   #    G Group ownership differs
   #    T mTime differs
   #    P caPabilities differ <--- Not on Red Hat 5; it may be missing or be "C" for "C selinux Context differs"
   #
   # "Each of the 8 characters denotes the result of a comparison of attribute(s)  of  the  file  to  the
   #  value  of  those  attribute(s)  recorded in the database.  A single "." (period) means the test passed,
   #  while a single "?" (question mark) indicates the test could not be performed (e.g. file permissions 
   #  prevent reading). Otherwise, the (mnemonically emBoldened) character denotes failure of  the  corre-
   #  sponding --verify test"
   #
   #    c %config configuration file.
   #    d %doc documentation file.
   #    g %ghost file (i.e. the file contents are not included in the package payload).
   #    l %license license file.
   #    r %readme readme file.
   #
   my $verifySums = {};
   my $numLines   = 0;
   foreach my $line (@lines) {
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
         push(@$packageProblems,"Verifying $desig: Could not handle line '$line'");
      }
      # If we have "flagValuess", sum into "verifySums"
      foreach my $flag (keys %$flagValues) {
         if (! exists $$verifySums{$flag}) {
            $$verifySums{$flag} = 0
         }
         my $value = $$flagValues{$flag};
         if ($value eq '?') {
            if ($$verifySums{$flag} == 0) {
               $$verifySums{$flag} = -1; # at least one "not performed"
            }
         }
         elsif ($value ne '.') {
            $$verifySums{$flag} = 1; # at least one failure
         }
      }
   }
   $$packageHash{VERIFYSUMS}   = $verifySums;
   $$packageHash{MISSINGSTUFF} = $missingStuff;
   $$packageHash{NUMLINES}     = $numLines;
}

