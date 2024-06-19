rpmsnap
=======

# What is it

A simple Perl script to generate reports of the contents of [Red Hat Package Manager (RPM) databases](http://en.wikipedia.org/wiki/RPM_Package_Manager) of various machines, or of the same machine at different times. Another Perl script helps in comparing two reports.

## Similar programs

Paul Waterman's [rpmscomp](https://github.com/pdwaterman/rpmscomp/). It uses `ssh(1)` to grab a dump of a remote RPM database. 

There is a Perl module to access the PRM database: [RPM4](https://metacpan.org/pod/RPM4). We don't use it though and call the `rpm(8)` command through Perl's [https://perldoc.perl.org/functions/system](`system()`].

## Status

- Maintained. Old but serviceable.
- 2011-XX-XX: The first version was created in the context of administration of a handful of machines running Red Hat Linux.
- 2022-06-25: Code rearranged. Fixed so that it can deal with carets that are now starting to show up in release strings.
- 2022-07-04: Gross bug fixed whereby the last package in the rpm-generated package list was not considered.
- 2024-06-19: Reorganized the tree of files. Slight maintenance.

## License

[MIT License](http://opensource.org/licenses/MIT) with original copyright held by author's former employer.

Copyright (c) 2011<br>
M-PLIFY S.A.<br>
68, avenue de la Liberté<br>
L-1930 Luxembourg<br>

_The above address has been out of date for a decade now, but let's keep it_

# Usage

There are three scripts:

<table>

<tr>
<td>rpmsnap.pl</td>
<td>Access the RPM database using the "rpm" command directly and create a human-readable report of its contents on STDOUT.</td>
</tr>

<tr>
<td>makesnap.sh</td>
<td>Runs "rpmsnap.pl" and captures the output in a file whose name depends on the current time. "rpmsnap.pl" should be run regularly from crontab to create reports which accumulate in a directory.</td>
</tr>

<tr>
<td>rpmsnapcmp.pl</td>
<td>Compares two reports created by "rpmsnap.pl", writing out any differences found.</td>
</tr>

</table>

The report printed by `rpmsnap.pl` contains one line per package. 
The line may be rather longish. To improve legibility by replacing the blank
character by a dot, use the `--dotify` option.

An excerpt from an example report:

```
aajohan-comfortaa-fonts    3.101     4.fc36          noarch   Fedora Project:  .........  18  Wed 19 Jan 2022 09:54:02 PM CET 
aalib-libs                 1.4.0     0.43.rc5.fc36   x86_64   Fedora Project:  .........  11  Wed 19 Jan 2022 09:53:44 PM CET 
abattis-cantarell-fonts    0.301     7.fc36          noarch   Fedora Project:  .........  14  Wed 26 Jan 2022 08:46:41 AM CET 
abattis-cantarell-vf-fonts 0.301     7.fc36          noarch   Fedora Project:  .........  10  Wed 26 Jan 2022 08:46:41 AM CET 
abrt-addon-ccpp            2.15.1    1.fc36          x86_64   Fedora Project:  .........  61  Thu 10 Mar 2022 10:07:22 PM CET 
abrt-addon-kerneloops      2.15.1    1.fc36          x86_64   Fedora Project:  .........  20  Thu 10 Mar 2022 10:07:22 PM CET 
abrt-addon-pstoreoops      2.15.1    1.fc36          x86_64   Fedora Project:  .........   8  Thu 10 Mar 2022 10:07:22 PM CET 
chmlib                     0.40      26.fc36         x86_64   Fedora Project:  .........  25  Thu 20 Jan 2022 12:15:23 AM CET  
chrony                     4.2       5.fc36          x86_64   Fedora Project:  S.5....T.  32  Wed 16 Feb 2022 11:04:28 AM CET 
```

Each line lists, in this column order:

   - package name                e.g. `aajohan-comfortaa-fonts`
   - package version             e.g. `3.101`
   - package release             e.g. `4.fc36`
   - package architecture        e.g. `noarch`
   - package vendor              e.g. `Fedora Project`
   - verification result         e.g. `.M.......` (if requested through the `--verify` option)
   - number of files in package  e.g. `18`
   - package builddate           e.g. `Wed 19 Jan 2022 09:54:02 PM CET`

If `--verify` has been given as option, you will see the "verification result"
column in the output. The "verification result" describes whether there was
anything unexpected regarding the files in the package.

RPM verification consists in running a number of tests on each file in the
package. As described in the man page of `rpm`, there is a mnemonic letter
corresponding to each test which may go wrong:

   - `S` => file Size differs
   - `M` => Mode differs (includes permissions and file type)
   - `5` => digest (formerly MD5 sum) differs
   - `D` => Device major/minor number mismatch
   - `L` => readLink(2) path mismatch
   - `U` => User ownership differs
   - `G` => Group ownership differs
   - `T` => mTime differs
   - `P` => caPabilities differ

The "verification result" contains one character for each of the above in a fixed order. That character is:

   1. the corresponding mnemonic letter if at least one of the files in the package did not pass the corresponding test; otherwise
   1. the letter `?` if the test could not be performed on at least one of the files in the package (e.g. missing file or permission error); otherwise
   1. the letter `.` if all the files in the package passed the test.

## Suggestion if you have several machines

Suppose you have three machines called 'alpha.example.com', 'bravo.example.com' and 'charlie.example.com'.

On one machine, install a directory tree that looks like this:

    rpm/
    ├── bin/
    │   ├── rpmsnapcmp.pl
    │   └── see.sh
    ├── data/
    │   ├── alpha.example.com/
    │   ├── bravo.example.com/
    │   └── charlie.example.com/
    ├── do -> ./sbin/makesnap.sh
    └── sbin/
        ├── get_hostname_function.sh
        ├── makesnap.sh
        ├── prelinkfix.sh
        └── rpmsnap.pl

Share and synchronize this directory tree among all the machines by putting it on a network file
system or by using a versioning system like svn or git.

Make sure `makesnap.sh` is called regularly (for example, every 2nd day) on all the machines
via cron (not necessarily as root) by a suitable crontab entry. The symlink `do` is just there
to find the command more easily when one is on the command line.

Then summary files and files listing the errors encountered during generation will accumulate under the
hostname-specific directories. `makesnap.sh` makes sure that a new summary is only kept 
if there are changes relative to the previous summary.

In case of a network file system, sharing is immediate. In case of a versioning system, you have to 
synchronize the filetree from time to time among the machines.

Then the tree may look like this after some time:

    rpm/
    ├── bin
    │   ├── rpmsnapcmp.pl
    │   └── see.sh
    ├── data
    │   ├── alpha.example.com
    │   │   ├── rpmsnap.2012-10-04_17:00:01.err
    │   │   ├── rpmsnap.2012-10-04_17:00:01.txt
    │   │   ├── rpmsnap.2012-12-04_17:00:01.err
    │   │   └── rpmsnap.2012-12-04_17:00:01.txt
    │   ├── bravo.example.com
    │   |   ├── rpmsnap.2013-02-13_17:00:01.txt
    │   │   ├── rpmsnap.2013-02-19_17:00:01.txt
    │   │   ├── rpmsnap.2013-03-01_17:00:01.err
    │   │   └── rpmsnap.2013-03-01_17:00:01.txt   
    │   └── charlie.example.com
    │       ├── rpmsnap.2013-02-19_17:00:01.err
    │       ├── rpmsnap.2013-02-19_17:00:01.txt
    │       ├── rpmsnap.2013-02-22_17:00:01.txt
    │       └── rpmsnap.2013-02-25_17:00:02.txt
    ├── do -> ./sbin/makesnap.sh
    └── sbin/
        ├── get_gostname_function.sh
        ├── makesnap.sh
        ├── prelinkfix.sh
        └── rpmsnap.pl

It is thus easy to check for RPM database differences from any machine.

# Ideas and todos

   - Add the number of missing files to the output.
   - Compare expected package size with effective package size.
   - The rpm database is accessed by calls to `rpm`; but there is actually [RPM4](https://metacpan.org/pod/RPM4)!
   - It might be more productive to dump everything into a relational database and work with that.
   - Would be interesting to examine the provides/requires capability graph, too. So maybe a graph database would be even better.

# Bugs

   - If there are several packages with different version and they get updated and some
     get dropped, (case of the kernel packages for example) `rpmsnapcmp.pl` does not
     output a meaningful correspondence. 
   - See getAllVerifyLinesForPackage() for a problem with flag processing.

