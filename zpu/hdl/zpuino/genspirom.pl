#!/usr/bin/perl

die unless $ARGV[0] and $ARGV[1];
my $page = $ARGV[1];

open(my $in,$ARGV[0]) or die("cannot open: $!");    

my $count = 0;
my $mybuf;
my $end;

while (1) {
    unless (sysread($in,$mybuf,1)) {
        $mybuf="\0";
        $end=1;
    }
    
    my ($v) = unpack("C",$mybuf);
    printf "%02X",$v;
    $count++;
    if ($count==$page) {
        $count=0;
        print "\n";
        last if $end;
    }
}
