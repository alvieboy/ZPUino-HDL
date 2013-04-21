#!/usr/bin/perl      
use Math::Complex; 

use POSIX qw(ceil);

my $infile = $ARGV[0];
my $force = $ARGV[1];
my $entity = $ARGV[2] || "prom_generic_dualport";
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

my $total_words = (2 ** $bits) / 4;
my $twcount = $total_words - 1;

my $mybuf;

my $out = "";
my $addr = 0;
my $bitsminusone = $bits-1;

print<<EOM;
library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all; 
use ieee.numeric_std.all;

entity ${entity} is
  port (
    CLK:              in std_logic;
    WEA:  in std_logic;
    ENA:  in std_logic;
    MASKA:    in std_logic_vector(3 downto 0);
    ADDRA:         in std_logic_vector($bitsminusone downto 2);
    DIA:        in std_logic_vector(31 downto 0);
    DOA:         out std_logic_vector(31 downto 0);
    WEB:  in std_logic;
    ENB:  in std_logic;
    ADDRB:         in std_logic_vector($bitsminusone downto 2);
    DIB:        in std_logic_vector(31 downto 0);
    MASKB:    in std_logic_vector(3 downto 0);
    DOB:         out std_logic_vector(31 downto 0)
  );
end entity ${entity};

architecture behave of ${entity} is

  subtype RAM_WORD is STD_LOGIC_VECTOR (31 downto 0);
  type RAM_TABLE is array (0 to $twcount) of RAM_WORD;
EOM

my @ram=();

while ( $total_words ) {
    #print STDERR "E $val ";
    $mybuf="\0\0\0\0";
    sysread($in,$mybuf,4);
    my $v = unpack("N",$mybuf);
    push(@ram,$v);
    $addr++;
    $total_words--;
}

# Output RAM contents

print " shared variable RAM: RAM_TABLE := RAM_TABLE'(\n";
print join(",", map { sprintf("x\"%08x\"",$_) } @ram );
print ");\n";

print "\nbegin\n";

print <<EOM;

  process (clk)
  begin
    if rising_edge(clk) then
      if ENA='1' then
        if WEA='1' then
          RAM(conv_integer(ADDRA) ) := DIA;
        end if;
        DOA <= RAM(conv_integer(ADDRA)) ;
      end if;
    end if;
  end process;  

  process (clk)
  begin
    if rising_edge(clk) then
      if ENB='1' then
        if WEB='1' then
          RAM( conv_integer(ADDRB) ) := DIB;
        end if;
        DOB <= RAM(conv_integer(ADDRB)) ;
      end if;
    end if;
  end process;  
EOM

print "end behave;\n";
