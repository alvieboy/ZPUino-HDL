-- ZPU
--
-- Copyright 2004-2008 oharboe - Øyvind Harboe - oyvind.harboe@zylin.com
-- Copyright 2010-2012 Alvaro Lopes - alvieboy@alvie.com
-- 
-- The FreeBSD license
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above
--    copyright notice, this list of conditions and the following
--    disclaimer in the documentation and/or other materials
--    provided with the distribution.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE ZPU PROJECT ``AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
-- ZPU PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
-- INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
-- STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
-- ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-- 
-- The views and conclusions contained in the software and documentation
-- are those of the authors and should not be interpreted as representing
-- official policies, either expressed or implied, of the ZPU Project.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.wishbonepkg.all;
use work.zcorev3pkg.all;

entity zcorev3 is
  port (
    syscon:         in wb_syscon_type;

    -- Master wishbone interface (RAM)
    mwbi:           in wb_miso_type;
    mwbo:           out wb_mosi_type;

    -- Master wishbone interface (IO) - non-pipelined
    iowbi:           in wb_miso_type;
    iowbo:           out wb_mosi_type;

    poppc_inst:     out std_logic;
    break:          out std_logic;

    -- ROM wb interface
    rwbi:           in wb_miso_type;
    rwbo:           out wb_mosi_type;

    icache_flush:        in std_logic;
    dcache_flush:        in std_logic;
    -- Debug interface

    dbg_out:            out zpu_dbg_out_type;
    dbg_in:             in zpu_dbg_in_type
  );
end zcorev3;

architecture behave of zcorev3 is


-- state machine.



constant spMaxBit: integer := stackSize_bits-1;
constant minimal_implementation: boolean := false;

subtype index is integer range 0 to 3;
signal tOpcode_sel : index;

function pc_to_cpuword(pc: unsigned) return unsigned is
  variable r: unsigned(wordSize-1 downto 0);
begin
  r := (others => DontCareValue);
  r(maxAddrBit downto 0) := pc;
  return r;
end pc_to_cpuword;

function pc_to_memaddr(pc: unsigned) return unsigned is
  variable r: unsigned(maxAddrBit downto 0);
begin
  r := (others => '0');
  r(maxAddrBit downto minAddrBit) := pc(maxAddrBit downto minAddrBit);
  return r;
end pc_to_memaddr;

-- Prefetch stage registers




-- Registers for each stage
signal exr:     exuregs_type;
signal prefr:   prefetchregs_type;
signal evalr:   prefetchregs_type;
signal decr:    decoderegs_type;


signal newsp:         unsigned(maxAddrBitBRAM downto 2);    -- SP value to load, coming from EXU into PFU
signal decode_load_sp:  boolean;                      -- Load SP signal from EXU to PFU
signal exu_busy:        boolean;                      -- EXU busy ( stalls PFU )
signal evalr_busy:      boolean;
signal exu_busy_test:   std_logic;                      -- EXU busy ( stalls PFU )
signal pfu_busy:        boolean;                      -- PFU busy ( stalls DFU )
signal evu_busy:        boolean;
signal decode_jump:     boolean;                      -- Jump signal from EXU to DFU
signal jump_address:    unsigned(maxAddrBitBRAM downto 0);  -- Jump address from EXU to DFU
signal do_interrupt:    boolean;                      -- Helper.

--signal nos:                   unsigned(wordSize-1 downto 0); -- This is only a helper
--signal wroteback_q:           std_logic; -- TODO: get rid of this here, move to EXU regs

signal dci: dcache_in_type;
signal dco: dcache_out_type;
signal ici: icache_in_type;
signal ico: icache_out_type;

signal is_prefr_valid: std_logic; -- Valid insn/prefetch data

signal lmwbi:           wb_miso_type;
signal lmwbo:           wb_mosi_type;

  signal hold_pfu: boolean;
  signal hold_dfu: boolean;
  signal valid: boolean;
begin


  icache: zpuino_icache
  generic map (
    ADDRESS_HIGH => maxAddrBitBRAM
  )
  port map (
    syscon    => syscon,
    ci        => ici,
    co        => ico,
    mwbi      => rwbi,
    mwbo      => rwbo
  );

  ici.flush <= icache_flush;

  dcache: zpuino_dcache
  generic map (
      ADDRESS_HIGH    => maxAddrBitBRAM,
      CACHE_MAX_BITS  => 15,
      CACHE_LINE_SIZE_BITS => 6
  )
  port map (
    syscon  => syscon,
    ci      => dci,
    co      => dco,
    mwbi    => lmwbi,
    mwbo    => lmwbo
  );

  mylsu: lsu
  port map (
    syscon    => syscon,

    mwbi      => mwbi,
    mwbo      => mwbo,

    wbi       => lmwbo,
    wbo       => lmwbi,
    tt        => "11" -- 11=Write-Combine
  );


  dci.flush <= dcache_flush;
  -- move this please
  do_interrupt <= true when iowbi.int='1' and exr.inInterrupt='0' else false;

  DFU: zcorev3_dfu
    port map (
      syscon  => syscon,
      dr      => decr,
      ici     => ici,
      ico     => ico,
      int     => do_interrupt,
      jmp     => decode_jump,
      ja      => jump_address,
      hold    => hold_dfu
  );

  hold_dfu<=exu_busy or pfu_busy or evu_busy;

  PFU: zcorev3_pfu
    port map (
      syscon  => syscon,
      dri     => decr,
      dr      => prefr,
      dci     => dci,
      dco     => dco,
      newsp   => newsp,
      loadsp  => decode_load_sp,
      hold    => hold_pfu,
      busy    => pfu_busy,
      flush   => decode_jump
  );

  hold_pfu<=exu_busy or evu_busy;

  EVU: zcorev3_evu
    port map (
      syscon  => syscon,
      dri     => prefr,
      dr      => evalr,
      valid   => valid,
      newsp   => newsp,
      loadsp  => decode_load_sp,
      dco     => dco,
      hold    => exu_busy,
      busy    => evu_busy,
      flush   => decode_jump
  );


  EXU: zcorev3_exu
    port map (
      syscon  => syscon,
      dri     => evalr,
      dr      => exr,
      valid   => valid,
      newsp   => newsp,
      loadsp  => decode_load_sp,
      jmp     => decode_jump,
      ja      => jump_address,
      hold    => false,
      busy    => exu_busy,
      dci     => dci,
      dco     => dco,
      iowbi   => iowbi,
      iowbo   => iowbo
  );


  process(syscon.clk)
  begin
    if rising_edge(syscon.clk) then
      dbg_out.pc <= std_logic_vector(evalr.pc);
      dbg_out.sp <= std_logic_vector(evalr.sp);
      dbg_out.opcode <= evalr.op.opcode;
      dbg_out.stacka <= std_logic_vector(exr.tos);
      dbg_out.stackb <= std_logic_vector(exr.nos);
      dbg_out.valid <= '1';--evalr.valid; --and not exu_busy;
   end if;
  end process;

end behave;

