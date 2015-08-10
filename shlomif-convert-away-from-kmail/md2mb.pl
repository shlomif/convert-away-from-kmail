#!/usr/bin/perl -w
#
# Program to import a maildir kmail environement into a thunderbird one.

use strict;
use warnings;

use File::Find::Object;
use File::Copy;
use File::Basename;
use File::Path;
use File::Spec;

my $cmd="formail";

# CHANGE AS YOU WISH
my $oldroot = "/home/shlomif/.Mail";
my $newroot = "/home/shlomif/.thunderbird/qlrfs7yx.default/Mail/Local Folders";

# Is the newroot a file (1) or a dir (0)
my $nrisfile = 0;
my $debug = 0;
# END CHANGE

$debug++ if ((defined $ARGV[0]) && ($ARGV[0] eq "-v"));
print "DEBUG MODE, not doing anything, just printing\n" if ($debug);
if ($debug) {
	print "CMD1: mkdir -p $newroot\n" if ((not -d "$newroot") && (not $nrisfile));
} else {
	mkpath("$newroot",0, 0755) if ((not -d "$newroot") && (not $nrisfile));
}
system("$cmd </dev/null >/dev/null 2>/dev/null") == 0 or die "cannot find formail on your \$PATH!\nAborting";

my $tree = File::Find::Object->new({}, $oldroot);

sub _my_slurp_dir
{
    my ($dirname) = @_;
    opendir my $dh, $dirname
        or return [];

    my @results = File::Spec->no_upwards(readdir($dh));

    closedir($dh);

    return [map { "$dirname/$_" } @results];
}

FILE_FIND:
while (my $item = $tree->next_obj()) {

    my $old_pathname = $item->path();

    if (-f $old_pathname)
    {
        if (($old_pathname =~ m{\.(ids|sorted|index)$})
                or ($old_pathname =~ m{/(cur|new|tmp)/}))
        {
            next FILE_FIND;
        }
    }
    elsif (-d $old_pathname)
    {
        if ( $old_pathname =~ /\/(cur|new|tmp)\z/)
        {
            $tree->prune();
            next FILE_FIND;
        }
    }

    if ($debug)
    {
        print "CURR: $old_pathname\n";
    }

    my @dest_components = @{$item->dir_components()};
    # my $destname = $old_pathname;
    # $destname =~ s|^$oldroot||;

    foreach my $comp (@dest_components)
    {
        $comp =~ s{\A\.(.*?)\.directory\z}{$1.sbd}ms;
    }

    my $destname = join("/", @dest_components);
    if ($debug) {
        print "DEST: $destname\n";
    }

    my $outputfile="$newroot/$destname";
    my $cdir = dirname($outputfile);

    die "Destname is all space." if ($destname =~ /\A\s+\z/);

    if (-d $old_pathname) {

        # Done so because glob cannot handle whitespace.
        my @files = (map { @{_my_slurp_dir("$old_pathname/$_")} } (qw(cur new)));
        if (@files) {
            if ($debug) {
                print "CMD2: mkdir -p $cdir\n" if (not -d "$cdir");
            } else {
                mkpath($cdir, 0, 0700) if (not -d "$cdir");
            }
        }
        MAILDIR:
        foreach my $file (@files) {
            if (! (-f $file and -s $file and -r $file))
            {
                next MAILDIR;
            }
            $file =~ s/'/'"'"'/;  # escape ' (single quote)
            # NOTE! The output file must not contain single quotes (')!
            my $run = "cat '$file' | $cmd >> '$outputfile'";
            if ($debug) {
                print "CMD3: $run\n";
            } else {
                print "Copying maildir content from $old_pathname to $outputfile\n";
                system($run) == 0 or warn "cannot run \"$run\".";
            }
        }
    }
    elsif (-f $old_pathname) {
        if ($debug) {
            print "CMD2: mkdir -p $cdir\n" if (not -e "$cdir");
            print "CMD3: cp $old_pathname $cdir\n";
        } else {
            mkpath("$cdir",0, 0755) if (not -e "$cdir");
            copy($old_pathname,$cdir);
            print "Copying mailbox content from $old_pathname to $outputfile\n";
        }
    }
}
