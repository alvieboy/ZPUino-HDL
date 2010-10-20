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
}

print STDERR "Need to map $words words\n";

my $bits = ceil(logn($words,2));

print STDERR "Need $bits bits for address\n";

my $total_words = (2 ** $bits) / 4;

my $mybuf;

my $out = "";
my $addr = 0;

print<<EOM;
library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all; 
use ieee.numeric_std.all;

entity prom_generic_dualport is
  port (
    clk:              in std_logic;
    memAWriteEnable:  in std_logic;
    memAAddr:         in std_logic_vector(14 downto 2);
    memAWrite:        in std_logic_vector(31 downto 0);
    memARead:         out std_logic_vector(31 downto 0);
    memBWriteEnable:  in std_logic;
    memBAddr:         in std_logic_vector(14 downto 2);
    memBWrite:        in std_logic_vector(31 downto 0);
    memBRead:         out std_logic_vector(31 downto 0)
  );
end entity prom_generic_dualport;

architecture behave of prom_generic_dualport is

  subtype RAM_WORD is STD_LOGIC_VECTOR (31 downto 0);
  type RAM_TABLE is array (0 to 8191) of RAM_WORD;
  shared variable RAM: RAM_TABLE := RAM_TABLE'(
EOM


while ( $total_words ) {
    #print STDERR "E $val ";
    $mybuf="\0\0\0\0";
    sysread($in,$mybuf,4);
    my @v = unpack("CCCC",$mybuf);
    
    @v=(0,0,0,0) unless scalar(@v);
    print "RAM_WORD'(x\"";
    printf ("%02x",$_) foreach @v;
    print "\")";
    print "," if $total_words>1;
    print "\n";
    $addr++;
    $total_words--;
}
print ");\n\n\n";
 
print <<EOM;
begin

  process (clk)
  begin
    if rising_edge(clk) then
      if memAWriteEnable='1' then
        RAM( conv_integer(memAAddr) ) := memAWrite;
      end if;
      memARead <= RAM(conv_integer(memAAddr)) ;
    end if;
  end process;  

  process (clk)
  begin
    if rising_edge(clk) then
      if memBWriteEnable='1' then
        RAM( conv_integer(memBAddr) ) := memBWrite;
      end if;
      memBRead <= RAM(conv_integer(memBAddr)) ;
    end if;
  end process;  

end behave; 
EOM

