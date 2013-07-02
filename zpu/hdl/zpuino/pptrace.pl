#!/usr/bin/perl

my $imacc = 0;
my $idim;

sub emul
{
    my ($op)= @_;
    my@ops=qw/unknown loadh storeh lessthan lessthanorequal
        ulessthan ulessthanorequal
        swap mult lshiftright ashiftleft ashiftright
        call eq neq neg sub xor loadb storeb
        div mod eqbranch neqbranch poppcrel config pushpc
        syscall pushspadd halfmult callpcrel/;
    return @ops[$op-32];
}

sub inst
{
    my ($opcodeh, $sph) = @_;
    my $r;
    
    my $opcodeval = hex($opcodeh);
    my $sp = hex($sph);
    
    if ($opcodeval & 0x80) {
        my $imval = ($opcodeval & 0x7F);
        unless ($idim) {
            # Check signal
            if ($imval &0x40) {
                $imval = $imval - 128;
            }
            $idim=1;
        } 
        $r = "im $imval ";
        $imacc <<=7;
        $imacc += $imval;
        $r .= sprintf ("(%d, 0x%08x)", $imacc,$imacc & 0xffffffff);
        return $r;
    }
    $idim = 0;
    $imacc=0;
    
    return "????" if $opcodeval == 0x01;
    return "pushsp" if $opcodeval == 0x02;
    return "????" if $opcodeval == 0x03;
    return "poppc" if $opcodeval == 0x04;
    return "add" if $opcodeval == 0x05;
    return "and" if $opcodeval == 0x06;
    return "or" if $opcodeval == 0x07;
    return "load" if $opcodeval == 0x08;
    return "not" if $opcodeval == 0x09;
    return "flip" if $opcodeval == 0x0a;
    return "nop" if $opcodeval == 0x0b;
    return "store" if $opcodeval == 0x0c;
    return "popsp" if $opcodeval == 0x0d;
    return "????" if $opcodeval == 0x0e;
    return "????" if $opcodeval == 0x0f;
    
    # Emulate
    
    my $off = (($opcodeval & 0x1f) ^ 0x10)<<2;
    my $spo;
    $spo = sprintf( "%08X", $sp+ $off);
    
    if (($opcodeval >> 5)==0x1){
        return "emulate/" . emul($opcodeval & 0x1f);
    }
    if (($opcodeval >> 5)==0x2){
        return "storesp $off ($spo)";
    }
    if (($opcodeval >> 5)==0x3){
        return "loadsp $off ($spo)";
    }
    if (($opcodeval >> 5)==0x0){
        return "addsp $off ($spo)";
    }
    
    return "";
}
my @funcs;

sub printalign
{
    my ($size,@args) = @_;
    my $s = join('',@args);
    
    while (length($s)<$size) {
        $s.=" ";
    }
    print $s;
}

sub locate
{
    my ($addr) = @_;

    foreach $func (@funcs) {
        if ($addr >= $func->{start}) {
            #   printf ("\n$addr %x %x\n", $func->{start}, $func->{end});
            return "\t[ " ,$func->{name}." + ".($addr-$func->{start})," ]";
        }
    }
    return "";
}

while (my $f = shift @ARGV) {
    # Load symbols
    open(my $sim, "zpu-elf-objdump -x $f |") or die;
    # 00000ab6 g     F .text  0000013d __divsi3
    while (<$sim>) {
        if (/^([0-9a-z]{8})\s[gl]......\s(\S+)\s+(\S+)\s+([^\.]\S+)/) {
            #print "$4 ($1)\n";
            next if $2 =~ /(data|stack|bss)/;
            push(@funcs, 
                 {
                     name => $4,
                     start => hex($1),
                     end => hex($3) +hex($1)
                 }
                );
        }

    }
    @funcs = sort { $b->{start} <=> $a->{start} } @funcs;
    close($sim);
}

my $lastpc;

while (<STDIN>) {
    chomp;
    if (/0x(\S+)\s0x(\S+)\s0x(\S+)/) {
        next if $1 eq $lastpc;
        print;
        printalign(30, " ",inst($2,$3)); print locate(hex($1));
        $lastpc=$1;
    } else {
        print;
    }
    print "\n";
}
