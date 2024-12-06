library ieee, mylib;
use ieee.std_logic_1164.all;
use mylib.defBCT.all;

package defIOManager is
  -- Local Address  -------------------------------------------------------
  constant kSelIntIn0              : LocalAddressType := x"100"; -- W/R, [2:0]
  constant kSelIntIn1              : LocalAddressType := x"110"; -- W/R, [2:0]
  constant kSelIntIn2              : LocalAddressType := x"120"; -- W/R, [2:0]
  constant kSelIntIn3              : LocalAddressType := x"130"; -- W/R, [2:0]

end package defIOManager;

