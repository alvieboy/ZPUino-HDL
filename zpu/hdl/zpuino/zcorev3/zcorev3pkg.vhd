library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.wishbonepkg.all;

package zcorev3pkg is

constant minimal_implementation: boolean := false;

type decoderstate_type is (
  State_Run,
  State_Jump
);

type DecodedOpcodeType is
(
Decoded_Nop,
Decoded_Idle,
Decoded_Im0,
Decoded_ImN,
Decoded_LoadSP,
Decoded_Dup,
Decoded_DupStackB,
Decoded_StoreSP,
Decoded_Pop,
Decoded_PopDown,
Decoded_PopDownDown,
Decoded_AddSP,
Decoded_AddStackB,
Decoded_Shift,
Decoded_Emulate,
Decoded_Break,
Decoded_PushSP,
Decoded_PopPC,
Decoded_Add,
Decoded_Or,
Decoded_And,
Decoded_Load,
Decoded_Not,
Decoded_Flip,
Decoded_Store,
Decoded_PopSP,
Decoded_Interrupt,
Decoded_Neqbranch,
Decoded_Eq,
Decoded_Storeb,
Decoded_Storeh,
Decoded_Ulessthan,
Decoded_Lessthan,
Decoded_Ashiftleft,
Decoded_Ashiftright,
Decoded_Loadb,
Decoded_Loadh,
Decoded_Call,
Decoded_Callpcrel,
Decoded_Mult,
Decoded_MultF16
);

type stackChangeType is (
  Stack_Same,
  Stack_Push,
  Stack_Pop,
  Stack_DualPop
);

type tosSourceType is
(
  Tos_Source_PC,
  Tos_Source_FetchPC,
  Tos_Source_Idim0,
  Tos_Source_IdimN,
  Tos_Source_StackB,
  Tos_Source_SP,
  Tos_Source_Add,
  Tos_Source_And,
  Tos_Source_Or,
  Tos_Source_Eq,
  Tos_Source_Not,
  Tos_Source_Flip,
  Tos_Source_LoadSP,
  Tos_Source_AddSP,
  Tos_Source_AddStackB,
  Tos_Source_Shift,
  Tos_Source_Ulessthan,
  Tos_Source_Lessthan,
  Tos_Source_LSU,
  Tos_Source_None
);


type opcode_type is record
  opcode:         std_logic_vector(OpCode_Size-1 downto 0);
  decoded:        DecodedOpcodeType;
  freeze:         std_logic;
  stackOper:      stackChangeType;
  spOffset:       unsigned(4 downto 0);
  tosSource:      tosSourceType;
end record;

type decoderegs_type is record
  valid:          boolean;
  op:             opcode_type;
  pc:             unsigned(maxAddrBitBRAM downto 0);
  fetchpc:        unsigned(maxAddrBitBRAM downto 0);
  pcint:          unsigned(maxAddrBitBRAM downto 0);
  idim:           std_logic;
  im:             std_logic;
  im_emu:         std_logic;
  break:          std_logic;
  state:          decoderstate_type;
end record;

type pf_state_type is (
  running,
  popsp
);

type prefetchregs_type is record
  sp:             unsigned(maxAddrBitBRAM downto 2);
  op:             opcode_type;
  spnext:         unsigned(maxAddrBitBRAM downto 2);
  valid:          boolean;
  pc:             unsigned(maxAddrBitBRAM downto 0);
  fetchpc:        unsigned(maxAddrBitBRAM downto 0);
  idim:           std_logic;
  break:          std_logic;
  load:           std_logic;
  readback:       std_logic;
  writeback:      std_logic;
  request:        std_logic;
  pending:        std_logic;
  abort:          std_logic;
  op_freeze:      boolean;
  state:          pf_state_type;
  read:           std_logic_vector(31 downto 0);
  raddr:          std_logic_vector(maxAddrBitBRAM downto 2);
end record;

subtype evalregs_type is prefetchregs_type;

component zcorev3_dfu is
  port (
    syscon:       in  wb_syscon_type;
    -- Data registers output
    dr:           out decoderegs_type;
    -- Instruction cache interface
    ici:          out icache_in_type;
    ico:          in  icache_out_type;
    -- Interrupt request
    int:          in boolean;
    -- Jump request and address
    jmp:          in boolean;
    ja:           in unsigned(maxAddrBitBRAM downto 0);
    -- Hold request
    hold:         in boolean
  );

end component;

component lsu is
  port (
    syscon:     in wb_syscon_type;

    mwbi:       in wb_miso_type;
    mwbo:       out wb_mosi_type;

    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type;
    tt:         in std_logic_vector(1 downto 0) -- Transaction type
  );
end component;

component zcorev3_pfu is
  port (
    syscon:       in  wb_syscon_type;
    -- Signals from decoder
    dri:          in  decoderegs_type;
    -- Data registers output
    dr:           out prefetchregs_type;
    -- SP Load
    newsp:        in  unsigned(maxAddrBitBRAM downto 2);
    loadsp:       in  boolean;
    -- Dcache connection
    dci:          out dcache_in_type;
    dco:          in dcache_out_type;
    -- Pipeline control
    hold:         in  boolean;
    busy:         out boolean;
    flush:        in  boolean
  );
end component;

type State_Type is
(
State_Execute,
State_LoadStack,
State_Loadb,
State_Loadh,
State_Resync2,
State_ResyncNos,
State_WaitSPB,
State_ResyncFromStoreStack,
State_Neqbranch,
State_Ashiftleft,
State_Mult,
State_MultF16,
State_PopSP
);

type exuregs_type is record
  idim:       std_logic;
  break:      std_logic;
  inInterrupt:std_logic;
  tos:        unsigned(wordSize-1 downto 0);
  nos:        unsigned(wordSize-1 downto 0);
  tos_save:   unsigned(wordSize-1 downto 0);
  nos_save:   unsigned(wordSize-1 downto 0);
  state:      State_Type;
  wroteback:  std_logic;
  -- Wishbone control signals (registered)
  wb_cyc:     std_logic;
  wb_stb:     std_logic;
  wb_we:      std_logic;
  wb_adr:     std_logic_vector(maxAddrBitIncIO downto 2);
  wb_dat:     std_logic_vector(wordSize-1 downto 0);

end record;


component zcorev3_exu is
  port (
    syscon:       in  wb_syscon_type;
    -- Signals from delay slot
    dri:          in  evalregs_type;
    -- Data registers output
    dr:           out exuregs_type;
    -- Combinatory
    valid:        in boolean;
    -- SP Load
    newsp:        out unsigned(maxAddrBitBRAM downto 2);
    loadsp:       out boolean;
    -- Jump request and address
    jmp:          out boolean;
    ja:           out unsigned(maxAddrBitBRAM downto 0);
    poppc_inst:   out std_logic;
    -- Pipeline control
    hold:         in  boolean;
    busy:         out boolean;
    -- Data access
    dci:          out dcache_in_type;
    dco:          in dcache_out_type;
    -- IO Access
    iowbi:           in wb_miso_type;
    iowbo:           out wb_mosi_type
  );
end component;

component zcorev3_evu is
  port (
    syscon:       in  wb_syscon_type;
    -- Signals from delay slot
    dri:          in  prefetchregs_type;
    -- Data registers output
    dr:           out evalregs_type;
    -- Comb. signals
    valid:        out boolean;
    -- SP Load
    newsp:        in unsigned(maxAddrBitBRAM downto 2);
    loadsp:       in boolean;
    -- Memory interface (cache)
    dco:          in dcache_out_type;
    -- Pipeline control
    hold:         in  boolean;
    busy:         out boolean;
    flush:        in  boolean
  );
end component;

component zcorev3_dbuf is
  port (
    syscon: in wb_syscon_type;
    we:     in std_logic;
    waddr:  in std_logic_vector(maxAddrBitBRAM downto 2);
    wdat:   in std_logic_vector(31 downto 0);
    raddr:  in std_logic_vector(maxAddrBitBRAM downto 2);
    re:     in std_logic;
    present: out std_logic;
    rdat:    out std_logic_vector(31 downto 0)
  );
end component;

end package;
