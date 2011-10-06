#!/usr/bin/perl -w
#
# Program to import a maildir kmail environement into a Claws Mail one.
# 
# Based on an older script I found to convert from KMail to Thunderbird.
# Modified by Shlomi Fish ( http://www.shlomifish.org/ )

use strict;
use warnings;

use File::Find::Object;
use File::Copy;
use File::Basename;
use File::Path;
use File::Spec;

# CHANGE AS YOU WISH
my $oldroot = "/home/shlomif/.Mail";
my $newroot = "/home/shlomif/Claws-Mail";

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

my %maildir_subdirs = (map { $_ => 1 } qw(cur new tmp));

# For the first empty root path.
$tree->next_obj();

FILE_FIND:
while (my $item = $tree->next_obj()) {

    my $old_pathname = $item->path();

    if ($item->is_file())
    {
        if ($old_pathname =~ m{\.(?:ids|sorted|index)\z})
        {
            next FILE_FIND;
        }
    }
    elsif ($item->is_dir())
    {
        if (exists($maildir_subdirs{$item->dir_components()->[-1] }))
        {
            $tree->prune();
            next FILE_FIND;
        }
    }

    if ($debug)
    { 
        print "CURR: $old_pathname\n";
    }

    if ($item->is_dir() && (! -d "$old_pathname/cur"))
    {
        next FILE_FIND;
    }

    my @dest_components = @{$item->dir_components()};
    # my $destname = $old_pathname;
    # $destname =~ s|^$oldroot||;

    foreach my $comp (@dest_components)
    {
        $comp =~ s{\A\.(.*?)\.directory\z}{$1}ms;
    }

    # Fix to get the mboxes in the right place.
    # Adapted from a patch by an E-mail correspondent.
    if ($item->is_file())
    {
        push @dest_components, $item->basename();
    }

    my $destname = join("/", @dest_components);
    if ($debug) {
        print "DEST: $destname\n";
    }

    my $outputfile="$newroot/$destname";
    my $cdir = dirname($outputfile);

    die "Destname is all space." if ($destname =~ /\A\s+\z/);

    mkpath($outputfile, 0, 0700);
    if ($item->is_dir()) {
        print (join(' ', "Maildir2MH", $old_pathname, $outputfile), "\n");
        system("Maildir2MH", $old_pathname, $outputfile);
        $tree->prune();
    }
    elsif ($item->is_file()) {
        print "Copying mailbox content from '$old_pathname' to '$outputfile'\n";
        system("mbox2MH", $old_pathname, $outputfile);
    }
}
