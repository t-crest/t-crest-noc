--
-- Copyright Technical University of Denmark. All rights reserved.
-- This file is part of the T-CREST project.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
--    1. Redistributions of source code must retain the above copyright notice,
--	 this list of conditions and the following disclaimer.
--
--    2. Redistributions in binary form must reproduce the above copyright
--	 notice, this list of conditions and the following disclaimer in the
--	 documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER ``AS IS'' AND ANY EXPRESS
-- OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
-- OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
-- NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
-- THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- The views and conclusions contained in the software and documentation are
-- those of the authors and should not be interpreted as representing official
-- policies, either expressed or implied, of the copyright holder.
--

-------------------------------------------------------------------------------
-- traffic generator intended as sub-hierarchical test bench
--
-- this code provides stimuli to the network during simulation and is supposed
-- to be instanciated from within the tile to be tested.
-- Author: Christoph Mueller
-- (partially copied from the old testbenches by Evangelia)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use ieee.math_real.all;
use std.textio.all;
use work.txt_util.all;
use work.command_util.all;
use work.config.all;
use work.ocp.all;
use work.noc_interface.all;
use work.tile_package.all;
use work.traffic_generator_package.all;

entity traffic_generator is
  
  port (
    clk, reset : in  std_logic;	 -- clock & asynchronous low active reset
    spm_master : out spm_master;
    spm_slave  : in  spm_slave;
    p_master   : out ocp_io_m;
    p_slave    : in  ocp_io_s;
    settings   : in  tile_settings
    );

end traffic_generator;


architecture behav of traffic_generator is

  -- configuration files
  file schedule : text open read_mode is TG_SCHEDULE_FILE;
  file data	: text open read_mode is TG_SPM_INIT_FILE;
  file dma	: text open read_mode is TG_DMA_INIT_FILE;

  -- signals to synchronize the init processes
  signal SPM_INITIALIZED : std_logic := '0';
  signal NI_INITIALIZED	 : std_logic := '0';
  signal DMA_INITIALIZED : std_logic := '0';
  
begin  -- behav

  -----------------------------------------------------------------------------
  -- process to initialize the route & slot table
  -----------------------------------------------------------------------------
  init_ni : process

    variable word    : string (100 downto 1);  --std_logic_vector(15 downto 0) := (others => '0');
    variable cnt     : integer := 0;
    variable slt_num : integer;
    variable l	     : line;
    variable slt     : std_logic_vector(4 downto 0);
    variable route   : std_logic_vector(15 downto 0);

    variable node_id : integer;

  begin

    p_master.MCmd	 <= (others => '0');
    p_master.MAddr	 <= (others => '0');
    p_master.MData	 <= (others => '0');
    p_master.MByteEn	 <= (others => '0');
    p_master.MRespAccept <= '0';


    wait until falling_edge(reset);
    wait for 6*NA_HPERIOD;

    if not endfile(schedule) then

      loop
	str_read(schedule, word);
	exit when word(100 downto 96 - floor(log10(real(node_id)))) = ("# NI" & node_id'image) or endfile(schedule);
      end loop;

      report "NI" & word(100 downto 96) & " (" & traffic_generator'instance_name & ") " severity note;

      loop
	str_read(schedule, word);
	exit when word(100 downto 89) = "# SLOT_TABLE" or endfile(schedule);
      end loop;

      report "ST" & word(100 downto 89) severity note;

      readline(schedule, l);
      read(l, slt_num);
      cnt := 0;
      loop
	readline(schedule, l);
	read(l, slt);
	--st_write
	--print str(slt);
	st_write(p_master,
		 p_slave,
		 std_logic_vector(to_unsigned(cnt*4, OCP_ADDR_WIDTH-ADDR_MASK_W)),
		 slt, clk);
	cnt := cnt + 1;
	exit when cnt = slt_num or endfile(schedule);
      end loop;

      loop
	str_read(schedule, word);
	exit when word(100 downto 88) = "# ROUTE_TABLE" or endfile(schedule);
      end loop;
      report "RT==========>" & word(100 downto 88) severity note;

      cnt := 0;
      loop
	readline(schedule, l);
	read(l, route);
	--rt_write
	--report str(route);
	route_write (p_master,
		     p_slave,
		     std_logic_vector(to_unsigned(cnt*4, OCP_ADDR_WIDTH-ADDR_MASK_W)),
		     route, clk);
	cnt := cnt + 1;
	exit when cnt = N*N or endfile(schedule);
      end loop;

      NI_INITIALIZED <= '1';

    end if;

    -- lock
    wait;
  end process;


  -----------------------------------------------------------------------------
  -- process to initialize the SPM
  -----------------------------------------------------------------------------
  spm_initilize : process

    variable count : natural := 0;
    variable word  : string (100 downto 1);  --std_logic_vector(15 downto 0) := (others => '0');
    variable addr  : integer;
  begin

    spm_master.MCmd  <= (others => '0');
    spm_master.MAddr <= (others => '0');
    spm_master.MData <= (others => '0');

    wait until falling_edge(reset);

    -- search for data section
    if not endfile(data) then
      loop
	str_read(data, word);
	exit when word(100 downto 96 - floor(log10(real(node_id)))) = ("# NI" & node_id'image) or endfile(data);
      end loop;
    end if;

    -- program the memory
    while not endfile(data) loop      
      wait until rising_edge(clk);
      wait for delay;
      str_read(data, word);
      -- only lines starting with an @ are considered
      exit when word(100) \ = '@' or endfile(data);

      addr := to_integer(unsigned(strh(word(99 downto 96))));
      
      -- write data
      spm_master.MCmd <= "1";
      spm_master.MAddr <= std_logic_vector(to_unsigned(addr, spm_master.MAddr'length));
      spm_master.MData <= strh(word(94 downto 79));
    end loop;

    wait until rising_edge(clk);
    --wait until rising_edge(clk);
    wait for delay;

    -- disable writing
    spm_master.MCmd  <= "0";
    spm_master.MAddr <= (others => '0');
    spm_master.MData <= (others => '0');

    -- all done, hand over to the DMA setup...
    SPM_INITIALIZED <= '1';
    wait until (DMA_INITIALIZED = '1');

    -- simulate for some time
    wait for 3 us;

    -- read the data from the spm
    wait until rising_edge(clk);

    count := 0;
    while(count < 16 * SPM_INIT_SIZE) loop

      wait until rising_edge(clk);
      wait for delay;

      spm_master.MCmd  <= "0";
      spm_master.MAddr <= std_logic_vector(to_unsigned(count, 16));  --x"00000000";
      spm_master.MCmd  <= "0";
      spm_master.MAddr <= std_logic_vector(to_unsigned(count, 16));  --x"00000002";
      spm_master.MCmd  <= "0";
      spm_master.MAddr <= std_logic_vector(to_unsigned(count, 16));  --x"00000004";
      spm_master.MCmd  <= "0";
      spm_master.MAddr <= std_logic_vector(to_unsigned(count, 16));  --x"00000006";

      count := count + 1;

    end loop;

    wait;
  end process;


  -----------------------------------------------------------------------------
  -- proces to initialize the DMA as specified in the dma init file
  -----------------------------------------------------------------------------
  init_DMA : process
    variable addr_field : std_logic_vector(31 downto 0);
    variable dma_id	: integer;
    
  begin	 -- process init_DMA

    -- find section
    if not endfile(dma) then
      loop
	str_read(dma, word);
	exit when word(100 downto 96 - floor(log10(real(node_id)))) = ("# NI" & node_id'image) or endfile(dma);
      end loop;
    end if;

    -- make sure all data is copied to the SPM and that the NI is initialized
    wait until (SPM_INITIALIZED = '1') and (NI_INITIALIZED = '1');

    -- iterate ofer dema setting entrys and program dma as needed
    while not endfile(dma) loop
      
      wait until rising_edge(clk);
      wait for delay;
      str_read(dma, word);
      exit when word(100) \ = '@' or endfile(dma);

      dma_id	 := to_integer(unsigned(strh(word(99 downto 99))));
      addr_field := strh(word(97 downto 94)) & strh(word(92 downto 89));

      report "DMA(" & word(99) & "): " & word(97 downto 94) & " -> " & word(92 downto 89) & " (" & traffic_generator'instance_name & ") " severity note;

      -- program address
      dma_write (p_master, p_slave,
		 std_logic_vector(TG_DMA_BASE_ADDRESS + dma_id * TG_DMA_DISTANCE + TG_DMA_ADDRESS_FIELD), addr_field, clk);
      -- enable & start dma
      dma_write (p_master, p_slave,
		 std_logic_vector(TG_DMA_BASE_ADDRESS + dma_id * TG_DMA_DISTANCE + TG_DMA_ENABLE), x"00008004", clk);

    end loop;

    -- everything done
    DMA_INITIALIZED <= '1';

    -- lock
    wait;
  end process init_DMA;
end behav;
