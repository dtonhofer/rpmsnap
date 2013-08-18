rpmsnap
=======

A simple set of scripts to compare the contents of RPM databases on different machines, or 
on the same machine at different times.

There are three scripts:

<table>

<tr>
<td>rpmsnap.pl</td>
<td>Access the RPM database using the `rpm` command and create a human-readable summary of its contents.</td>
</tr>

<tr>
<td>makesnap.sh</td>
<td>This script runs `rpmsnap.pl`; it should be run regularly from cron to create regular summaries which can 
accumulate in a directory, tagged by creation date.</td>
</tr>

<tr>
<td>rpmsnapcmp.pl</td>
<td>Takes two summaries created by `rpmsnap.pl` and compares the contents, writing out any differences found.</td>
</tr>

</table>

Similar programs
----------------

Paul Waterman's [rpmscomp](https://github.com/pdwaterman/rpmscomp/). 
It uses `ssh(1)` to grab a dump of the remote RPM database.

Suggestion for use if you have several machines (and NFS or SVN)
-----------------------------------------------

Suppose you have three machines called 'alpha.example.com', 'bravo.example.com' and 'charlie.example.com'.

On one machine, install a directory tree that looks like this:

    rpm/
    ├── bin/
    │   └── rpmsnapcmp.pl
    ├── data/
    │   ├── alpha.example.com/
    │   ├── bravo.example.com/
    │   └── charlie.example.com/
    └── sbin/
        ├── makesnap.sh
        └── rpmsnap.pl

Share and synchronize this directory tree among all the machines by putting it on a network file
system or by using a versioning system.

Make sure `makesnap.sh` is called regularly (for example, every 2nd day) on all the machines
via cron (not necessarily as root) by a suitable crontab entry.

Then summary files and files listing the errors encountered during generation will accumulate under the
hostname-specific directories. `makesnap.sh` makes sure that a new summary is only kept 
if there are changes relative to the previous summary.

In case of a network file system, sharing is immediate. In case of a versioning system, you have to 
synchronize the filetree from time to time among the machines.

Then the tree may look like this after some time:

    rpm/
    ├── bin
    │   └── rpmsnapcmp.pl
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
    └── sbin
        ├── makesnap.sh
        └── rpmsnap.pl

It is thus easy to check for RPM database differences from any machine.

The summary files "rpmsnap.YYYY-MM-DD_hh:mm:ss.txt" contain long lines like these:

    chkconfig·············1.3.59·············1.fc17···············x86_64···Fedora·Project····:        .........     97  Wed Mar  7 18:43:59 2012
    chmlib················0.40···············5.fc17···············x86_64···Fedora·Project····:        .........     12  Fri Jan 13 02:33:34 2012
    chrony················1.27···············0.3.pre1.fc17········x86_64···Fedora·Project····:        .......T.     28  Fri Apr 27 15:23:18 2012
    cifs-utils············5.9················3.fc17···········.···x86_64···Fedora·Project····:        .........     17  Sun Jan 13 12:21:11 2013
    cjet··················0.8.9··············11.fc17··············x86_64···Fedora·Project····:        .........      6  Fri Jan 13 02:42:35 2012
    cln-debuginfo·········1.3.2··············4.fc17.1·············x86_64···Fedora·Project····:        .........   1084  Tue Feb 28 19:34:21 2012
    cln···················1.3.2··············4.fc17.1·············x86_64···Fedora·Project····:        .5.......      7  Tue Feb 28 19:34:21 2012
    cloog-ppl·············0.15.11············3.fc17.1·············x86_64···Fedora·Project····:        .........      7  Fri Jan 13 02:54:47 2012
    
Each lines lists: 

   - package name
   - package version
   - package release
   - package architecture
   - package vendor
   - OR-ed representation of the flags raised on the files of the package during check (SM5DLUGTP)
   - number of files in the package 
   - package build date

As reference, the following flags may be raised when `rpm` compares the actual filesystem state with its
database (from the RPM man page; note that these may differ a bit depending the system issue):

    S : file Size differs
    M : Mode differs (includes permissions and file type)
    5 : MD5 sum differs
    D : Device major/minor number mismatch
    L : readLink(2) path mismatch
    U : User ownership differs
    G : Group ownership differs
    T : mTime differs
    P : caPabilities differ

Ideas and todos
---------------

   - Add the number of missing files to the output
   - Compare expected package size with effective package size

License
-------

Distributed under the MIT License, see http://opensource.org/licenses/MIT

Copyright (c) 2011<br>
M-PLIFY S.A.<br>
21, rue Glesener<br>
L-1631 Luxembourg<br>
 
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.


