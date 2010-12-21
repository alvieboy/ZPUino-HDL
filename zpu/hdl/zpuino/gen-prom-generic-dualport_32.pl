#!/usr/bin/perl      
use Math::Complex; 

use POSIX qw(ceil);

my $infile = $ARGV[0];
my $force = $ARGV[1];

my @st = stat($infile) or die;

my $size = $st[7];

my $blocks = $size/32;
if ($size%32 != 0) {
    print STDERR "Infile is not aligned, fixing....\n";
    open(my $f, ">>",$infile) or die;
    my $rest = 32 - ($size%32);
    print $f "\0"x$rest;
    close($f);
    print STDERR "Padded with $rest zeroes.\n";
    $size+=$rest;
}

open(my $in, $infile) or die;

my $words = $size;

if (defined $force) {
    $words=$force;
    if ($size>$force) {
        print STDERR "File too large ($size won't fit $force)\n";
        exit -1;
    }
}

print STDERR "Need to map $words words\n";

my $bits = ceil(logn($words,2));

print STDERR "Need $bits bits for address\n";

my $total_words = (2 ** $bits) / 4 + 1;

my $mybuf;

my $out = "";
my $addr = 0;
my $bitsminusone = $bits-1;

print<<EOM;
library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all; 
use ieee.numeric_std.all;

entity prom_generic_dualport is
  port (
    clk:              in std_logic;
    memAWriteEnable:  in std_logic;
    memAWriteMask:    in std_logic_vector(3 downto 0);
    memAAddr:         in std_logic_vector($bitsminusone downto 2);
    memAWrite:        in std_logic_vector(31 downto 0);
    memARead:         out std_logic_vector(31 downto 0);
    memBWriteEnable:  in std_logic;
    memBAddr:         in std_logic_vector($bitsminusone downto 2);
    memBWrite:        in std_logic_vector(31 downto 0);
    memBWriteMask:    in std_logic_vector(3 downto 0);
    memBRead:         out std_logic_vector(31 downto 0)
  );
end entity prom_generic_dualport;

architecture behave of prom_generic_dualport is

  subtype RAM_WORD is STD_LOGIC_VECTOR (7 downto 0);
  type RAM_TABLE is array (0 to $total_words-1) of RAM_WORD;
EOM

# We use 4 rams here.

my @rams = ([],[],[],[]);

while ( $total_words ) {
    #print STDERR "E $val ";
    $mybuf="\0\0\0\0";
    sysread($in,$mybuf,4);
    my @v = unpack("CCCC",$mybuf);
    
    @v=(0,0,0,0) unless scalar(@v);
    my $index=0;
    foreach (reverse @v) {
        push (@{$rams[$index]}, $_);
        $index++;
    }
    $addr++;
    $total_words--;
}

#    print "RAM_WORD'(x\"";
#    printf ("%02x",$_) foreach @v;
#    print "\")";
#    print "," if $total_words>1;
#    print "\n";
#
#print ");\n\n\n";

# Output RAM contents

my $index = 0;
foreach my $ram (@rams)
{
    print " shared variable RAM${index}: RAM_TABLE := RAM_TABLE'(\n";
    print join(",", map { sprintf("x\"%02x\"",$_) } @$ram );
    print ");\n";
    $index++;
}

print "\nbegin\n";

my $index = 0;

foreach my $ram (@rams)
{
    my $start = (($index+1)*8)-1;
    my $end = $index*8;
print <<EOM;
  process (clk)
  begin
    if rising_edge(clk) then
    if memAWriteEnable='1' and memAWriteMask(${index})='1' then
      RAM${index}( conv_integer(memAAddr) ) := memAWrite($start downto $end);
      end if;
      memARead($start downto $end) <= RAM${index}(conv_integer(memAAddr)) ;
    end if;
  end process;  

  process (clk)
  begin
    if rising_edge(clk) then
      if memBWriteEnable='1' and memBWriteMask(${index})='1' then
         RAM${index}( conv_integer(memBAddr) ) := memBWrite($start downto $end);
      end if;
      memBRead($start downto $end) <= RAM${index}(conv_integer(memBAddr)) ;
    end if;
  end process;  
EOM

$index++;
}
print "end behave;\n";
