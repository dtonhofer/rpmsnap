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

Suggestion for use if you have several machines
-----------------------------------------------

Suppose you have three machines called hostname1, hostname2 and hostname3. 

On one machine, install a directory tree that looks like this:

    rpm/
    ├── bin/
    │   └── rpmsnapcmp.pl
    ├── data/
    │   ├── hostname1/
    │   ├── hostname2/
    │   └── hostname3/
    └── sbin/
        ├── makesnap.sh
        ├── prelinkfix.sh
        └── rpmsnap.pl

Share and synchronized this directory tree among all the machines by putting it on a network file
system or by using a versioning system.

Make sure `makesnap.sh` is called regularly (for example, every 2nd day) on all three machines
via cron (not necessarily as root) by a suitable crontab entry.

Then summaries and files listing errors encountered during generation will accumulate under the
hostname-specific directories. `makesnap.sh` makes sure that a new summary is only kept 
if there are differences relative to the previous summary. For example, the tree may look like this
after some time:

    rpm/
    ├── bin
    │   └── rpmsnapcmp.pl
    ├── data
    │   ├── hostname1
    │   │   ├── rpmsnap.2012-10-04_17:00:01.err
    │   │   ├── rpmsnap.2012-10-04_17:00:01.txt
    │   │   ├── rpmsnap.2012-12-04_17:00:01.err
    │   │   └── rpmsnap.2012-12-04_17:00:01.txt
    │   ├── hostname2
    │   |   ├── rpmsnap.2013-02-13_17:00:01.txt
    │   │   ├── rpmsnap.2013-02-19_17:00:01.txt
    │   │   ├── rpmsnap.2013-03-01_17:00:01.err
    │   │   └── rpmsnap.2013-03-01_17:00:01.txt   
    │   └── hostname3
    │       ├── rpmsnap.2013-02-19_17:00:01.err
    │       ├── rpmsnap.2013-02-19_17:00:01.txt
    │       ├── rpmsnap.2013-02-22_17:00:01.txt
    │       └── rpmsnap.2013-02-25_17:00:02.txt
    └── sbin
        ├── makesnap.sh
        ├── prelinkfix.sh
        └── rpmsnap.pl

As the directory tree is synchronized among all the machines, it is easy to check for RPM database
differences from any machine.

The summary files "rpmsnap.YYYY-MM-DD_hh:mm:ss.txt" contain long lines like these:

    chkconfig··································1.3.59·············1.fc17·························x86_64···Fedora·Project····:        .........     97  Wed Mar  7 18:43:59 2012
    chmlib·····································0.40···············5.fc17·························x86_64···Fedora·Project····:        .........     12  Fri Jan 13 02:33:34 2012
    chrony·····································1.27···············0.3.pre1.fc17··················x86_64···Fedora·Project····:        .......T.     28  Fri Apr 27 15:23:18 2012
    cifs-utils·································5.9················3.fc17·························x86_64···Fedora·Project····:        .........     17  Sun Jan 13 12:21:11 2013
    cjet·······································0.8.9··············11.fc17························x86_64···Fedora·Project····:        .........      6  Fri Jan 13 02:42:35 2012
    cln-debuginfo······························1.3.2··············4.fc17.1·······················x86_64···Fedora·Project····:        .........   1084  Tue Feb 28 19:34:21 2012
    cln········································1.3.2··············4.fc17.1·······················x86_64···Fedora·Project····:        .........      7  Tue Feb 28 19:34:21 2012
    cloog-ppl··································0.15.11············3.fc17.1·······················x86_64···Fedora·Project····:        .........      7  Fri Jan 13 02:54:47 2012
    
Each lines lists: 

   - package name
   - package version
   - package release
   - package architecture
   - package vendor
   - summary of the flags set on any file of the package
   - number of files in the package 
   - package build date

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


