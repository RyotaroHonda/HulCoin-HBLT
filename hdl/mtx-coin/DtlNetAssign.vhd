-- -*- vhdl -*-

library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------
entity DtlNetAssign is
  Port (
    outDtlU : out std_logic_vector(31 downto 0);
    outDtlD : out std_logic_vector(31 downto 0);
    inDtlU  : in std_logic_vector(31 downto 0);
    inDtlD  : in std_logic_vector(31 downto 0)
    );
end DtlNetAssign;

-------------------------------------------------------------------------------
architecture Behavioral of DtlNetAssign is

begin
  outDtlU(15)   <= NOT inDtlU(0) ;
  outDtlU(13)   <=     inDtlU(1) ;
  outDtlU(11)   <=     inDtlU(2) ;
  outDtlU(9)    <= NOT inDtlU(3) ;
  outDtlU(7)    <=     inDtlU(4) ;
  outDtlU(5)    <=     inDtlU(5) ;
  outDtlU(3)    <=     inDtlU(6) ;
  outDtlU(1)    <=     inDtlU(7) ;
  outDtlU(31)   <=     inDtlU(8) ;
  outDtlU(29)   <= NOT inDtlU(9) ;
  outDtlU(27)   <=     inDtlU(10);
  outDtlU(25)   <= NOT inDtlU(11);
  outDtlU(23)   <=     inDtlU(12);
  outDtlU(21)   <=     inDtlU(13);
  outDtlU(19)   <=     inDtlU(14);
  outDtlU(17)   <=     inDtlU(15);
  outDtlU(14)   <= NOT inDtlU(16);
  outDtlU(12)   <=     inDtlU(17);
  outDtlU(10)   <=     inDtlU(18);
  outDtlU(8)    <=     inDtlU(19);
  outDtlU(6)    <=     inDtlU(20);
  outDtlU(4)    <=     inDtlU(21);
  outDtlU(2)    <=     inDtlU(22);
  outDtlU(0)    <=     inDtlU(23);
  outDtlU(30)   <=     inDtlU(24);
  outDtlU(28)   <= NOT inDtlU(25);
  outDtlU(26)   <= NOT inDtlU(26);
  outDtlU(24)   <=     inDtlU(27);
  outDtlU(22)   <=     inDtlU(28);
  outDtlU(20)   <=     inDtlU(29);
  outDtlU(18)   <=     inDtlU(30);
  outDtlU(16)   <=     inDtlU(31);

  outDtlD(15)   <=     inDtlD(0) ;
  outDtlD(13)   <=     inDtlD(1) ;
  outDtlD(11)   <=     inDtlD(2) ;
  outDtlD(9)    <=     inDtlD(3) ;
  outDtlD(7)    <=     inDtlD(4) ;
  outDtlD(5)    <=     inDtlD(5) ;
  outDtlD(3)    <= NOT inDtlD(6) ;
  outDtlD(1)    <= NOT inDtlD(7) ;
  outDtlD(31)   <=     inDtlD(8) ;
  outDtlD(29)   <=     inDtlD(9) ;
  outDtlD(27)   <=     inDtlD(10);
  outDtlD(25)   <= NOT inDtlD(11);
  outDtlD(23)   <=     inDtlD(12);
  outDtlD(21)   <=     inDtlD(13);
  outDtlD(19)   <=     inDtlD(14);
  outDtlD(17)   <=     inDtlD(15);
  outDtlD(14)   <=     inDtlD(16);
  outDtlD(12)   <=     inDtlD(17);
  outDtlD(10)   <=     inDtlD(18);
  outDtlD(8)    <=     inDtlD(19);
  outDtlD(6)    <=     inDtlD(20);
  outDtlD(4)    <=     inDtlD(21);
  outDtlD(2)    <= NOT inDtlD(22);
  outDtlD(0)    <= NOT inDtlD(23);
  outDtlD(30)   <=     inDtlD(24);
  outDtlD(28)   <=     inDtlD(25);
  outDtlD(26)   <=     inDtlD(26);
  outDtlD(24)   <=     inDtlD(27);
  outDtlD(22)   <=     inDtlD(28);
  outDtlD(20)   <=     inDtlD(29);
  outDtlD(18)   <=     inDtlD(30);
  outDtlD(16)   <=     inDtlD(31);

end Behavioral;
