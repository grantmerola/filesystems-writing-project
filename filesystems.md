### <a name="intro">Intro</a>
Filesystems are all around us they permeate our computing lives, almost always invisible. Like all hidden infrastructure they are essential to the modern functioning of society. Although filesystems play such an important role they are often bundled up with conversations about Operating Systems(OS). Filesystems *are* tightly coupled with operating systems, often in diagrams they are [shown](http://www.tldp.org/LDP/sag/html/overview-kernel.png) as part of the Kernel along with things like the Process, Network and Memory Managers, however filesystems are(on most systems) interchangeable. 

Due to the modular nature of many OSs the filesystem can be swapped out depending on the users need and wants. For instance some filesystems are fast others are reliable or highly compatible with other systems. This means that you may need to make a choice of filesystem to suit some specialized need, I hope to give you enough information so that you can know which features you need, and also a passing familiarity with some of the major filesystems.  

### <a name="what_is">What is a Filesystem?</a>
Most users never know that the filesystem exists, this is partially by design the average user has no need to interact with the filesystem and the complexities contained within would cause more confusion. However most standard computers users have used the [GUI](https://techterms.com/definition/gui) to interact with the filesystem, on Windows - File Explorer, and on macOS - Finder. The GUI provides an easy way to interact with the filesystem, the application can handle much of the formating and hide many of the complexities. 
##### <a name="trend">The progression of the filesystem</a>
There is a trend worth noting of hiding direct file access in newer OSs. For example early OSs were tightly coupled with the file hierarchy mostly out of necessity due to the limited computing power. With the advent of the GUI OS the file hierarchy was still visible but was constrained by preordained GUI actions. But with some of the most recent mobile OSs, notably iOS, the filesystem has all but disappeared. Android takes a more measured approach and still has a file viewer but files are clearly second class citizens. This was done so as to avoid many/all of the complexities of filesystems, however there were different complexities introduced as a byproduct of this shift away from the file system. Whether this shift is for better or worse still remains to be seen, more likely than not one devil has been traded for another. Regardless the filesystem will remain important in the internals and technical people will still need to interact with it. 

So at a macro scale a filesystem is something the user interacts with to manage files, directly or indirectly. But for an audience of the technical this is not sufficient or interesting. So as literally as possible what is(or perhaps more accurately) what composes an filesystem? Let's start at the bottom and work our way up. 
##### <a name="hardware">Hardware</a>
At the bottom is bits,(as hopefully you know) everything in a computer is made of bits. Information can be [stored](https://www.w3.org/International/questions/qa-what-is-encoding) in bits, for instance a file is a collection of bits.

But where are the bits, things don't **just** exist?
The bits exist in long term storage on the disk, also in [RAM](https://techterms.com/definition/ram) but since filesystems primarily deal with the disk we will only cover that. A Hard Drive Disk uses [magnetic storage](http://ffden-2.phys.uaf.edu/211.fall2000.web.projects/J%20Kugler/magnetic.html) to store information, the disk is divided up into:

- **Platters** - Platters are the actual disks that are on the are in the drive, there may be more than one per drive casing 
- **[Tracks](http://www.ntfs.com/hard-disk-basics.htm#MakingTracks)** - Tracks are rings on the disks where data is stored, there are thousands of tracks on a platter.
- **[Clusters](http://www.ntfs.com/hard-disk-basics.htm#SectorsandClusters)** - Clusters are simply a collection of Sectors, because sectors are small Clusters allow us to talk about larger chunks of data.
- **[Sectors](http://www.ntfs.com/hard-disk-basics.htm#SectorsandClusters)** - Sectors are the smallest unit of data that can be dealt with on the disk, they are usually 512 bytes.

![alt text](https://spectressite.files.wordpress.com/2015/12/disk-structure.png?w=616)

All these different constructs of size help the disk software stack manage the disk.

**So a Filesystem is a way for the user and system idea of a file to be translated down into the hardware reality of Sectors and Clusters; It is a mapping from software to hardware.**

### <a name="FAT">FAT</a>

FAT or **F**ile **A**llocation **T**able was [developed](https://staff.washington.edu/dittrich/misc/fatgen103.pdf#page=1) by Microsoft in the 1970, and although it is not the [oldest](https://softwareengineering.stackexchange.com/questions/103487/what-was-the-first-hierarchical-file-system) file system, it is by far the one of the most used especially for its age. FAT was originally used in Windows/DOS for many years and is still used today as the default filesystem on [SD cards](http://read.pudn.com/downloads77/ebook/294884/FAT32%20Spec%20%28SDA%20Contribution%29.pdf#page=1) and most USB flash drives. We will use FAT to talk about filesystem basics. 
##### <a name="fat_versions">Versions of FAT</a>
There are many different versions of FAT, the first published version of FAT, FAT12, the 12 [denoting](http://www.dfists.ua.es/~gil/FAT12Description.pdf#page=1) the use of 12 bit entries. Later other versions of FAT were released, FAT16, FAT32 and exFAT. Each of these successive versions increased the features and abilities of the FAT file system. The bit size often limits thing like max file size, max file name length and max disk size. exFAT would eventually practically solve most of these problems, but constant throughout is the file allocation table which is the basic data structure that filesystem is based and named after. 
##### <a name="fat_datastructure">File Allocation Table</a>
The file allocation table(will be referred to  as 'fat' **not** 'FAT' indicating the filesystem) is a simple data structure that is relatively easily mapped to the disk hardware reality, although other filesystems do not use the fat model directly, the data structures that are used are based on similar principles and understanding fat's will you to understand the concepts without having to know many of the implementation specific structures.

Before we can dig into how fats work let's briefly talk about pointers. Pointers are a incredibly common structure that often directly interact with control software. If we think about computers as series of ones and zeros([they actually are](https://en.wikipedia.org/wiki/Turing_machine)) all a pointer does is point at a to a place in that series, tying together the name of the pointer and a location.

![alt text](https://upload.wikimedia.org/wikipedia/commons/b/b4/Pointers.svg)

So a fat is a bunch of named pointers; a name of a file or a directory *points* to a place on the disk. Or more accurately in the case of a file it points to a cluster remember a cluster is a usable chunk of data made up of 512 byte sectors.

What if the file is 2KB? No problem just point at beginning of the file cluster and just read the sectors sequentially until we fill up to the known file size and hopefully at the same time find a special marker at the end that confirms the end of the file. 

But what if we want to edit a file? Well if you want to make the file smaller no problem just change your size and update the end marker. However if you want to make a file larger things get tricky. You see when you first wrote your file the next file that was written was placed immediately after it for performance reasons. So we could move that edited file to new territory and just rewrite it in its full length and this isn't a bad idea but it is slow because you have to rewrite the whole file in this new location which could take a while depending on the length of the file. So something clever is done, the file is broken into chunks that are [linked](https://staff.washington.edu/dittrich/misc/fatgen103.pdf#page=13) together via pointers. Although it will still take the disk a while to find the next cluster when reading, it is faster when the disk needs to read and write often. However if you use this model for to long then even small files can be fragmented over large section of the disk, it is then necessary to [defragment](https://en.wikipedia.org/wiki/Defragmentation) the drive by rewriting file files to be in continuous clusters.

![alt text](https://web.archive.org/web/20170211065251/http://www.ntfs.com/images/recover-FAT-structure.gif)

##### <a name="fat_problems">Problems with FAT</a>

FAT is old and relatively simple, there number of things that are lacking in the feature department. Many of the things that are now considered normal filesystem features were not even considered in the initial design of FAT, such as compression or encryption. Later many of these features were added in, but most were dirty hacks because the filesystem was never designed for it and backward compatibility was a goal. For instance name length may be the best example of this, when the filesystem was first introduced the name size was very small, but was expanded in later versions. However in later versions to keep backward compatibility this feature was implemented as a [hack](https://staff.washington.edu/dittrich/misc/fatgen103.pdf#page=28). 

Another example of a missing features is [**Data Integrity**](#data_integrity), many filesystems may take steps to insure that your data is safe often at the cost of speed or space efficiency. FAT at first didn't do anything, but eventually implemented a feature where copy of the fat would be made occasionally and stored. So that at the very least if the fat was corrupted, an unlikely but potentially causing complete data loss, the filesystem could be restored to that point in time and only some files would be lost. As you can imagine this is not a great system, what if data was corrupted but didn't cause problems for a long time, causing the backups to be corrupted too. Or what if it had been a while since a copy of the fat had been made all that new work is gone. And this doesn't help at all is the integrity of the file contents, arguably the more important stuff. 

##### <a name="fat_relevancy"> FAT's Relevancy Today </a>
Although Fat lacks many features that doesn't make it bad or even useless filesystem. As all filesystems do, FAT makes trade offs. Trade offs for speed and storage size at the cost of many features. These trade offs made more sense in a time of much more limited computing power and storage space. But today with our [GHz](https://techterms.com/definition/gigahertz) processors and [TB](https://techterms.com/definition/terabyte) hard drives, the trade offs that FAT made, make far less sense today. However FAT is sill used today in some low power computing environments because the trade offs it makes *are* worth it. It is also worth noting that the backward compatible nature of FAT make is at popular file interchange format between other filesystems.

### <a name="ZFS">ZFS</a>

ZFS is a filesystem [developed](http://open-zfs.org/wiki/History) in the early 2000's by Sun Microsystems its original use was in the Solaris OS. But it has taken on life of it's own on the open source community under the [OpenZFS project](http://open-zfs.org/). In every way that FAT is simple and lacking features ZFS is not. ZFS is often considered the gold standard for filesystems and although best is a deeply subjective measure, few would disagree that ZFS is an interesting and featureful filesystem.

ZFS [goals](http://queue.acm.org/detail.cfm?id=1317400): 

1. [**Simple Storage Management**](#pools)
2. [**Data Integrity**](#data_integrity) 
3. Performance

At scale.

##### <a name="pools">ZFS Storage Pools</a>

A more traditional filesystem has clear boundary especially down toward the hardware stack, usually they reach a point and then just hand over to the hardware stack. But ZFS in it effort to simplify storage management creates [pools](http://docs.oracle.com/cd/E26505_01/html/E37384/zfsover-2.html#gaypk) of disks. A pool is just a collection of disks that are manage by the filesystem instead of the volume manager. This allows ZFS to optimize the disk stack software to it's needs, such as ZFS's custom [RAID](https://techterms.com/definition/raid), [RAIDZ](https://blogs.oracle.com/ahl/what-is-raid-z) and simplify the management of disk. Each of your new disks to the pool which acts like really big virtual volume, as needed space is withdrawn and returned when done.

![alt text](https://pthree.org/wp-content/uploads/2012/12/zfs.png)

### <a name="data_integrity">Data Integrity</a>

One of the primary focuses and perhaps what ZFS is best known for is data integrity. Data integrity is something of a broad topic but basically the goal is to insure that none of the data is ever changed unintentionally, it can generally be broken up into three topics error prevention, error detection, and data correction.

##### <a name="integrity_need"> The need for Data Integrity </a>

Modern hardware is very reliable however errors do occur, often errors will be caught by error detection and correction systems on the hardware itself, even when errors are not caught it may not effect anything. All of this contributes to programmers trusting the hardware, when errors are so rare why take the time and overhead to check that what came back from the disk is what you think was. But when a lot the internal systems programs were designed a GB would have been an enormous amount of memory, who cares about 1 error every 10 GB when it would take decades to run through 10 GB, and even then it still might not matter. In the intervening years the hardware has gotten a bit better and when we can process TB of data quickly suddenly 1 error every 10 GB adds up fast. To quote Jeff Bonwick one of the initial engineers of ZFS:

>*"One thing that has changed, as Bill already mentioned, is that the error rates have remained constant, yet the amount of data and the I/O bandwidths have gone up tremendously. Back when we added large file support to Solaris 2.6, creating a one-terabyte file was a big deal. It took a week and an awful lot of disks to create this file.*

>*Now for comparison, take a look at, say, Greenplum’s database software, which is based on Solaris and ZFS. Greenplum has created a data-warehousing appliance consisting of a rack of 10 Thumpers (SunFire x4500s). They can scan data at a rate of one terabyte per minute. That’s a whole different deal. Now if you’re getting an uncorrectable error occurring once every 10 to 20 terabytes, that’s once every 10 to 20 minutes—which is pretty bad, actually."*

Interview found on [amc queue](http://queue.acm.org/detail.cfm?id=1317400), I recommend if you want to hear from formative figures in ZFS.

ZFS is a response to the the realization of the unreliably of hardware. Putting a lot of the work of data integrity on to the filesystem makes a lot of sense, the filesystem plays monkey in the middle between almost all user software and the disk. Adding data integrity features to the filesystem allows for zero cost integrity to client applications; updating one link in the chain is much more efficient than updating an ecosystem.

##### <a name="tools">Tools of Error Detection and Correction</a>

There are a number of tools used in error detection and correction systems:

- [Hashes](http://searchsqlserver.techtarget.com/definition/hashing) - A hash is a conversion of a larger amount of data to a fixed size bit of data, in cryptographic hashes the hash is non reversible meaning that once the data goes through the hash function the original data can not be reconstructed from the hash. The reason hashes can be useful for data integrity is that changing any part of the data will result in a different hash. Making it easy to tell if any data has changed.

- [Checksums](https://techterms.com/definition/checksum) - Checksums [may be seen as a subset](https://stackoverflow.com/questions/460576/hash-code-and-checksum-whats-the-difference) of hashes because they work much the same way the primary difference being that checksums are optimized for detecting data change making them the go to for many data integrity tasks.

- [Parity bits](https://techterms.com/definition/parity_bit) - Parity bits is a bit on the end of a string of bits that indicates whether there is an even or odd total number of ones in the string, on bit flip the parity will be off allowing for error detection. However if more than one bit were to flip the parity would reverse again and you would have a two bit error but not be able to detect it, this is why parity bits operate best on very small bits of data where the chances of multiple bit flips are very unlikely. In interesting use of parity bit is in raid arrays where using boolean math you can reconstruct the original data from one of the disks using the half the information on one other data disk and a disk of parity bits.

- [Redundancy](https://techterms.com/definition/redundancy) - Is the idea of having a backup, nothing is better, if the world burned down than a virgin copy of your data safely squirreled away. Having a plan for when things inevitably hit the fan is worth more gold than in all the world, this is true in all of tech not just filesystems.

The primary tool that ZFS uses extensively throughout is checksuming. ZFS uses checksums on every block of data that is written and the [entire data tree](https://pthree.org/2012/12/14/zfs-administration-part-ix-copy-on-write/) this means that if any data is corrupted the change will be obvious all the way up the tree and here we get to a trade off ZFS makes, trading error detection for speed. 

##### <a name="atomics">Atomics</a>

Another major area of data integrity is error prevention, a major way to prevent errors is to carefully track changes. A framework of thought used primarily in databases to track transactions is [ACID](http://www.onjava.com/pub/a/onjava/2001/11/07/atomic.html):

- **A** tomicity - Atomicity or Atomics are operations that complete and most importantly fail either all the way or not at all. This may not sound like much but half doing something is way worse then doing something all the way. If the system crashes during a non atomic operation the recovery state is unknown, potentially making it difficult or impossible to recover. Atomics must be small so that they have guarantee of completing during a system crash thus many other operations are made up of atomics that are combined together. This nature of being the fundamental indivisible unit is how they get the name atomics.

- **C** onsistency - Consistency is just making sure that the data your writing is generally valid for where your writing it.

- **I** solation - Isolation is making sure you are the only one who is writing in your area. It often leads to data corruption if two processes are trying to write to the same area, because neither know what state the data they are changing is in. Isolation simple insures that only one can go at a time.

- **D** urability - Durability insures that the operation was permanent. This doesn't mean much to filesystems where everything is written to the disk but make more sense to databases.

For filesystems Atomicity is most important, although isolation is also important, but is usually handled higher up in the OS by the process manager with write locks. 

Most filesystems have atomicity for most operations, the major exceptions being writes. It is difficult to guarantee atomicity for writes, because most writes are quite large and take a long time, remember atomics must be fast, often the largest guaranteed disk write is one sector. Not being able to guarantee the atomicity of writes is a problem when trying to trying to prevent errors. Most filesystems try and solve this with something called Journaling. 

#####  <a name="error_prevention"> Error Prevention</a>

[Journaling](http://www.linfo.org/journaling_filesystem.html) is where a filesystem keeps a log of everything it has and plans to do that way if an unexpected crash occurs and a issue is detected, the log can be rerun through to replicate the planned operations. This is not an ideal solution it is slow especially on start up, [checking](https://linux.die.net/man/8/fsck)(fsck) the filesystem for errors can be a lengthy process that scales with the size of the filesystem. 

The creators of ZFS wanted to avoid this issue to quote Jeff Bonwick again:

>*We can thank the skeptics in the early days for that. In the very beginning, I said I wanted to make this file system a FSCK-less file system, though it seemed like an inaccessible goal, looking at the trends and how much storage people have. Pretty much everybody said it’s not possible, and that’s just not a good thing to say to me. My response was, “OK, by God, this is going to be a FSCK-less file system.” We shipped in ’05, and here we are in ’07, and we haven’t needed to FSCK anything yet.*

Also from [amc queue](http://queue.acm.org/detail.cfm?id=1317400).

To do so ZFS uses technique called [**C**opy-**O**n-**W**rite](http://storagegaga.com/tag/copy-on-write/) or COW. COW is different because instead of recording all the operations, it writes everything it needs too in a new place and then just moves the pointer from the old location to the new location, pointer moves are much easier to do atomically. 

![alt text](https://pthree.org/wp-content/uploads/2012/12/copy-on-write.png)

Although ZFS has many more interesting features I now want to focus on another filesystem that uses COW at also has many of the same interesting features btrfs. ZFS was the primary filesystem in the Solaris OS, solaris is not as widespread as it once was and although ZFS has been ported on to many different systems it does not seem likely at this time that ZFS will eat the world and it percentage of use currently is very small compared to heavy weights such as [ext4](#defaults) or [ntfs](#defaults). This is not to say that btrfs is a some big shot, it too is relatively niche but it has a much better chance due to its close ties to the Linux project.

### <a name="btrfs">Btrfs</a> 

There was one major performance innovation that would catalyze the creation of btrfs and that was the a modified [B-tree](http://btechsmartclass.com/DS/U5_T3.html) algorithm that was especially suited for filesystem structures. The rest of the filesystem came about organically in the late two thousands. Btrfs and ZFS [share](https://lwn.net/Articles/342892/) a lot in common but my opinion btrfs focuses more on performance, so I want to take some time to talk about different features used to increase performance and some the trade offs of optimization. This is not to say that ZFS or other filesystems are not performant or don't implement these features, many do. 

When you are trying to optimize a system there are trade offs, sure at first you get a few freebies that make everything better, but in general optimization is about assessing your resources and finding your bottleneck. In a filesystem your bottleneck is always the disk, the disk is always orders of magnitude slower than the CPU. This means that for disk heavy tasks it is behooves you to do as much as possible with your data so that as little is written as possible.

##### <a name="compression">Compression</a>

One way to reduce total bits written is to use compression. When you compress all of your disk bound data you incur a performance penalty from having to compress and uncompress all your data but is is often worth it on systems with abundant RAM and CPU to do so, due to just how slow the disk is. Btrfs even provides [two](https://btrfs.wiki.kernel.org/index.php/Compression) different compression algorithms to optimize for different use cases, [ZLIB](https://www.zlib.net/) for slow, heavy compression and [LZO](http://www.oberhumer.com/opensource/lzo/) for fast, light compression. This compression is transparent meaning the average user can get it for free.

Another thing that can be optimized for is disk usage, one way to optimize disk usage is deduplication is the process where the filesystem looks for duplicate chunks of data and deletes the copies and points to the same chunk for use. This is a form of compression that can do much to save disk space, it can be more dangerous because you are reducing the number of valid copies and interfering in the inner workings of some files. So it is best if deduplication also comes with strong data integrity features.

Btrfs is also [known](https://lwn.net/Articles/342892/) for its packing of file information in an efficient form, ideally btrfs puts a things close together for faster reads. This is a byproduct of its structure.

![alt text](https://static.lwn.net/images/ns/kernel/btrfs/newskool.png)

### <a name="defaults">The Defaults</a>

All of the filesystems we have talked about thus far, are interesting and complex but not widely used primarily because they are not the defaults. The switching cost is high enough for most people that they never use anything but the defaults. This means that the defaults are by in large what people use because many never see the need for a different filesystem. The defaults for the [three major](https://www.netmarketshare.com/operating-system-market-share.aspx) operating systems are:

- Windows - [NTFS](https://support.microsoft.com/en-us/help/100108/overview-of-fat,-hpfs,-and-ntfs-file-systems) 
- macOS - HFS+
- Linux - [ext4](https://ext4.wiki.kernel.org)

We won't talk about HFS+ because it is older and has become an amalgamation of things designed over the years to suit Apples needs, this is not to say that HFS+ isn't [interesting](https://arstechnica.com/apple/2011/07/mac-os-x-10-7/12/). Also it's end may be in sight with the announcement of [APFS](https://arstechnica.com/apple/2017/02/testing-out-snapshots-in-apples-next-generation-apfs-file-system/).

I would however like to talk briefly about ext4 and NTFS. By the nature of being the defaults these filesystems have different goals from other filesystems. For example one of the major goals of ext4 is interoperability with ext2/3 and NTFS is backward compatible with many other part of Windows. This focus as on compatibility enviably leads to messier project than projects than systems designed standalone. Both of these filesystems come from a long history and were designed by their prospective organizations to solve the seam bursting increase in storage that was quickly reaching the limits of the older systems. 

### <a name="conclusion">Conclusion</a>

In conclusion the differences in the features and the abilities of filesystems vary, sometimes greatly. But in general this is not important to the average user. What matters to a technical audience is if you are one day asked to design a storage system you are aware of what a filesystem is and what features are available in good filesystems so that you can find a filesystem that suits your needs, be that data integrity, performance, interoperability or even backward compatibility. It is my hope that is site can give you just enough of a background of filesystems to learn on your own I strongly encourage you go and try to parse your way through the recommended reading. Click on links, read lots, ask questions and above all else be curious.

### <a name="recommended_reading">Recommended Reading</a>   

- [FAT](#FAT)
	- [FAT White Paper](https://staff.washington.edu/dittrich/misc/fatgen103.pdf)
	- [FAT Wikipedia Page](https://en.wikipedia.org/wiki/File_Allocation_Table)
- [ZFS](#ZFS)
	- [OpenZFS Project Wiki](http://open-zfs.org/)
	- [ZFS Wikipedia Page](https://en.wikipedia.org/wiki/ZFS)
	- [amc queue ZFS Interview](http://queue.acm.org/detail.cfm?id=1317400)
	- [ZFS write up and how to](https://pthree.org/2012/04/17/install-zfs-on-debian-gnulinux/)
	- [COW Info](http://storagegaga.com/tag/copy-on-write/)

- [Btrfs](#btrfs)
	- [Great Btrfs Article](https://lwn.net/Articles/342892/)
	- [Btrfs Wikipedia Page](https://en.wikipedia.org/wiki/Btrfs)
	- [Btrfs Wiki](https://btrfs.wiki.kernel.org)



"I don't know where to put the encryption paragraph yet, suggestions welcome"

##### <a name="encryption">Encryption</a>

"transition sentence" A good example of this is encryption, adding encryption will slow things down and add overhead but the cost may be worth it because the performance cuts are offset by gains in other areas. Not everyone believes that encryption should be handled at the filesystem level. Many users of filesystems without encryption get by just fine because regardless of the filesystem, you can still encrypt the whole disk allowing you to protect you data. But this a all or nothing solution it some time desirable to only encrypt some files. Some filesystems offer encryption transparently. 
