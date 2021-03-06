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


--------------------------------------------------------------------------------
-- NxN bi-torus NoC.
--
-- Author: Evangelia Kasapaki
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.txt_util.all;
use work.cmd_util.all;
use work.config_types.all;
use work.config.all;
use work.noc_defs.all;
use work.ocp.all;
use work.noc_interface.all;
use work.tile_package.all;


entity tiled_noc is

  generic (
    LINK_PIPELINE_STAGES : integer := 0;
    SWAP_PORTS		 : boolean := false);
  port (
    --p_clk		: in std_logic;
    n_clk : in std_logic;
    reset : in std_logic);

end tiled_noc;

architecture struct_noswap of tiled_noc is

------------------------------component declarations----------------------------

  component tile
    port (
      clk	  : in	std_logic;
      reset	  : in	std_logic;
      settings	  : in	tile_settings;
      north_in_f  : in	channel_forward;
      north_in_b  : out channel_backward;
      east_in_f	  : in	channel_forward;
      east_in_b	  : out channel_backward;
      south_in_f  : in	channel_forward;
      south_in_b  : out channel_backward;
      west_in_f	  : in	channel_forward;
      west_in_b	  : out channel_backward;
      north_out_f : out channel_forward;
      north_out_b : in	channel_backward;
      east_out_f  : out channel_forward;
      east_out_b  : in	channel_backward;
      south_out_f : out channel_forward;
      south_out_b : in	channel_backward;
      west_out_f  : out channel_forward;
      west_out_b  : in	channel_backward);
  end component;

------------------------------signal declarations----------------------------

  signal north_out_f : link_m_f;
  signal north_out_b : link_m_b;
  signal east_out_f  : link_m_f;
  signal east_out_b  : link_m_b;
  signal south_out_f : link_m_f;
  signal south_out_b : link_m_b;
  signal west_out_f  : link_m_f;
  signal west_out_b  : link_m_b;

  type link_m_f_p is array (LINK_PIPELINE_STAGES downto 0) of link_m_f;
  type link_m_b_p is array (LINK_PIPELINE_STAGES downto 0) of link_m_b;

  signal north_in_f_p : link_m_f_p;
  signal north_in_b_p : link_m_b_p;
  signal east_in_f_p  : link_m_f_p;
  signal east_in_b_p  : link_m_b_p;
  signal south_in_f_p : link_m_f_p;
  signal south_in_b_p : link_m_b_p;
  signal west_in_f_p  : link_m_f_p;
  signal west_in_b_p  : link_m_b_p;


-------------------------------------------------------------------------------

  constant even_N : boolean := ((N mod 2) = 0);	 -- even number of tiles

  --variable do_flip : boolean;

begin
  no_swap : if not SWAP_PORTS generate
    nodes_m : for i in 0 to M-1 generate
      nodes_n : for j in 0 to N-1 generate
      begin
	noc_tile : tile
	  port map (
	    --p_clk => p_clk,
	    clk		=> n_clk,
	    reset	=> reset,
	    settings	=> generate_tile_settings(i, j),
	    north_in_f	=> north_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
	    north_in_b	=> north_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
	    east_in_f	=> east_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
	    east_in_b	=> east_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
	    south_in_f	=> south_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
	    south_in_b	=> south_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
	    west_in_f	=> west_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
	    west_in_b	=> west_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
	    north_out_f => north_out_f(i)(j),
	    north_out_b => north_out_b(i)(j),
	    east_out_f	=> east_out_f(i)(j),
	    east_out_b	=> east_out_b(i)(j),
	    south_out_f => south_out_f(i)(j),
	    south_out_b => south_out_b(i)(j),
	    west_out_f	=> west_out_f(i)(j),
	    west_out_b	=> west_out_b(i)(j)
	    );
      end generate nodes_n;
    end generate nodes_m;
  end generate no_swap;

  swap : if SWAP_PORTS generate
    nodes_m : for i in 0 to M-1 generate
      nodes_n : for j in 0 to N-1 generate
	-- yikes, generate statements for vhdl'93 are ugly... - no if/else construct,
	-- So - I read the standard and found this way arround...
	constant do_flip : boolean := not ((real(i) < (real(N)/2.0) and real(j) < (real(N)/2.0)) or (real(i) >= (real(N)/2.0) and real(j) >= (real(N)/2.0)));
	constant center	 : boolean := ((i /= 0) and (i /= N/2) and (j /= 0) and (j /= N/2));

	constant south_edge : boolean := (i = 0);
	constant north_edge : boolean := (i = N/2);
	constant west_edge  : boolean := (j = 0);
	constant east_edge  : boolean := (j = N/2);

	constant corner_sw : boolean := (south_edge and west_edge);
	constant corner_se : boolean := (south_edge and east_edge);
	constant corner_nw : boolean := (north_edge and west_edge);
	constant corner_ne : boolean := (north_edge and east_edge);

	constant corner : boolean := (corner_sw or corner_se or corner_nw or corner_ne);

	constant settings : tile_settings := generate_tile_settings(i, j);
      begin


	-------------------------------------------------------------------------
	-- flip tiles arround for better routeability (reduced wire crossings)
	-------------------------------------------------------------------------

	
	tile_center : if (not corner) generate
	  no_flip : if (not do_flip) generate
	    noc_tile_no_flip_center : tile
	      port map (
		--p_clk => p_clk,
		clk	    => n_clk,
		reset	    => reset,
		settings    => settings,
		north_in_f  => north_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		north_in_b  => north_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		east_in_f   => east_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		east_in_b   => east_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		south_in_f  => south_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		south_in_b  => south_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		west_in_f   => west_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		west_in_b   => west_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		north_out_f => north_out_f(i)(j),
		north_out_b => north_out_b(i)(j),
		east_out_f  => east_out_f(i)(j),
		east_out_b  => east_out_b(i)(j),
		south_out_f => south_out_f(i)(j),
		south_out_b => south_out_b(i)(j),
		west_out_f  => west_out_f(i)(j),
		west_out_b  => west_out_b(i)(j)
		);
	  end generate no_flip;

	  flip : if (do_flip) generate
	    noc_tile_flip_center : tile
	      port map (
		clk	    => n_clk,
		reset	    => reset,
		settings    => settings,
		north_in_f  => south_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		north_in_b  => south_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		east_in_f   => west_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		east_in_b   => west_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		south_in_f  => north_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		south_in_b  => north_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		west_in_f   => east_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		west_in_b   => east_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		north_out_f => south_out_f(i)(j),
		north_out_b => south_out_b(i)(j),
		east_out_f  => west_out_f(i)(j),
		east_out_b  => west_out_b(i)(j),
		south_out_f => north_out_f(i)(j),
		south_out_b => north_out_b(i)(j),
		west_out_f  => east_out_f(i)(j),
		west_out_b  => east_out_b(i)(j)
		);
	  end generate flip;
	end generate tile_center;

	is_corner : if (corner) generate
	  c_sw : if corner_sw generate
	    --flip : if (do_flip) generate
	    noc_tile_corner : tile
	      port map (
		clk	    => n_clk,
		reset	    => reset,
		settings    => settings,
		north_in_f  => west_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		north_in_b  => west_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		east_in_f   => east_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		east_in_b   => east_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		south_in_f  => south_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		south_in_b  => south_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		west_in_f   => north_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		west_in_b   => north_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		north_out_f => west_out_f(i)(j),
		north_out_b => west_out_b(i)(j),
		east_out_f  => east_out_f(i)(j),
		east_out_b  => east_out_b(i)(j),
		south_out_f => south_out_f(i)(j),
		south_out_b => south_out_b(i)(j),
		west_out_f  => north_out_f(i)(j),
		west_out_b  => north_out_b(i)(j)
		);
	    --end generate flip;
	  end generate c_sw;

	  c_se : if corner_se generate
	    flip_odd : if (not even_N) generate
	      noc_tile_corner : tile
		port map (
		  clk	      => n_clk,
		  reset	      => reset,
		  settings    => settings,
		  north_in_f  => east_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  north_in_b  => east_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  east_in_f   => north_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  east_in_b   => north_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  south_in_f  => south_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  south_in_b  => south_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  west_in_f   => west_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  west_in_b   => west_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  north_out_f => east_out_f(i)(j),
		  north_out_b => east_out_b(i)(j),
		  east_out_f  => north_out_f(i)(j),
		  east_out_b  => north_out_b(i)(j),
		  south_out_f => south_out_f(i)(j),
		  south_out_b => south_out_b(i)(j),
		  west_out_f  => west_out_f(i)(j),
		  west_out_b  => west_out_b(i)(j)
		  );
	    end generate flip_odd;
	    flip_even : if (even_N) generate
	      noc_tile_corner : tile
		port map (
		  clk	      => n_clk,
		  reset	      => reset,
		  settings    => settings,
		  north_in_f  => south_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  north_in_b  => south_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  east_in_f   => north_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  east_in_b   => north_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  south_in_f  => west_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  south_in_b  => west_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  west_in_f   => east_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  west_in_b   => east_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  north_out_f => south_out_f(i)(j),
		  north_out_b => south_out_b(i)(j),
		  east_out_f  => north_out_f(i)(j),
		  east_out_b  => north_out_b(i)(j),
		  south_out_f => west_out_f(i)(j),
		  south_out_b => west_out_b(i)(j),
		  west_out_f  => east_out_f(i)(j),
		  west_out_b  => east_out_b(i)(j)
		  );
	    end generate flip_even;
	    
	  end generate c_se;
	  c_nw : if corner_nw generate
	    flip_odd : if (even_N) generate
	      noc_tile_corner : tile
		port map (
		  clk	      => n_clk,
		  reset	      => reset,
		  settings    => settings,
		  north_in_f  => south_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  north_in_b  => south_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  east_in_f   => north_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  east_in_b   => north_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  south_in_f  => west_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  south_in_b  => west_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  west_in_f   => east_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  west_in_b   => east_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  north_out_f => south_out_f(i)(j),
		  north_out_b => south_out_b(i)(j),
		  east_out_f  => north_out_f(i)(j),
		  east_out_b  => north_out_b(i)(j),
		  south_out_f => west_out_f(i)(j),
		  south_out_b => west_out_b(i)(j),
		  west_out_f  => east_out_f(i)(j),
		  west_out_b  => east_out_b(i)(j)
		  );
	    end generate flip_odd;
	    flip_even : if (not even_N) generate
	      noc_tile_corner : tile
		port map (
		  clk	      => n_clk,
		  reset	      => reset,
		  settings    => settings,
		  north_in_f  => north_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  north_in_b  => north_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  east_in_f   => east_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  east_in_b   => east_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  south_in_f  => south_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  south_in_b  => south_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  west_in_f   => west_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  west_in_b   => west_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  north_out_f => north_out_f(i)(j),
		  north_out_b => north_out_b(i)(j),
		  east_out_f  => east_out_f(i)(j),
		  east_out_b  => east_out_b(i)(j),
		  south_out_f => south_out_f(i)(j),
		  south_out_b => south_out_b(i)(j),
		  west_out_f  => west_out_f(i)(j),
		  west_out_b  => west_out_b(i)(j)
		  );
	    end generate flip_even;
	  end generate c_nw;
	  c_ne : if corner_ne generate
	    flip_odd : if (not even_N) generate
	      noc_tile_corner : tile
		port map (
		  clk	      => n_clk,
		  reset	      => reset,
		  settings    => settings,
		  north_in_f  => north_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  north_in_b  => north_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  east_in_f   => south_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  east_in_b   => south_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  south_in_f  => east_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  south_in_b  => east_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  west_in_f   => west_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  west_in_b   => west_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  north_out_f => north_out_f(i)(j),
		  north_out_b => north_out_b(i)(j),
		  east_out_f  => south_out_f(i)(j),
		  east_out_b  => south_out_b(i)(j),
		  south_out_f => east_out_f(i)(j),
		  south_out_b => east_out_b(i)(j),
		  west_out_f  => west_out_f(i)(j),
		  west_out_b  => west_out_b(i)(j)
		  );
	    end generate flip_odd;
	    flip_even : if (even_N) generate
	      noc_tile_corner : tile
		port map (
		  clk	      => n_clk,
		  reset	      => reset,
		  settings    => settings,
		  north_in_f  => west_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  north_in_b  => west_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  east_in_f   => east_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  east_in_b   => east_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  south_in_f  => south_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  south_in_b  => south_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  west_in_f   => north_in_f_p(i)(j)(LINK_PIPELINE_STAGES),
		  west_in_b   => north_in_b_p(i)(j)(LINK_PIPELINE_STAGES),
		  north_out_f => west_out_f(i)(j),
		  north_out_b => west_out_b(i)(j),
		  east_out_f  => east_out_f(i)(j),
		  east_out_b  => east_out_b(i)(j),
		  south_out_f => south_out_f(i)(j),
		  south_out_b => south_out_b(i)(j),
		  west_out_f  => north_out_f(i)(j),
		  west_out_b  => north_out_b(i)(j)
		  );
	    end generate flip_even;
	  end generate c_ne;
	end generate is_corner;
      end generate nodes_n;
    end generate nodes_m;
  end generate swap;

  pipeline_stages : block is
  begin	 -- block pipeline_stages
    links_pl_m : for i in 0 to M-1 generate
      links_pl_n : for j in 0 to n-1 generate
	pipeline_stage : for p in LINK_PIPELINE_STAGES - 1 downto 0 generate
	  pipeline_latch_north : entity work.channel_latch(struct)
	    generic map (
	      init_token => EMPTY_TOKEN,
	      init_data	 => (others => '0')
	      )
	    port map (
	      preset	=> reset,
	      left_in	=> north_in_f_p(i)(j)(p + 1),
	      left_out	=> north_in_b_p(i)(j)(p + 1),
	      right_out => north_in_f_p(i)(j)(p),
	      right_in	=> north_in_b_p(i)(j)(p),
	      lt_enable => open
	      );
	  pipeline_latch_south : entity work.channel_latch(struct)
	    generic map (
	      init_token => EMPTY_TOKEN,
	      init_data	 => (others => '0')
	      )
	    port map (
	      preset	=> reset,
	      left_in	=> south_in_f_p(i)(j)(p + 1),
	      left_out	=> south_in_b_p(i)(j)(p + 1),
	      right_out => south_in_f_p(i)(j)(p),
	      right_in	=> south_in_b_p(i)(j)(p),
	      lt_enable => open
	      );
	  pipeline_latch_east : entity work.channel_latch(struct)
	    generic map (
	      init_token => EMPTY_TOKEN,
	      init_data	 => (others => '0')
	      )
	    port map (
	      preset	=> reset,
	      left_in	=> east_in_f_p(i)(j)(p + 1),
	      left_out	=> east_in_b_p(i)(j)(p + 1),
	      right_out => east_in_f_p(i)(j)(p),
	      right_in	=> east_in_b_p(i)(j)(p),
	      lt_enable => open
	      );
	  pipeline_latch_west : entity work.channel_latch(struct)
	    generic map (
	      init_token => EMPTY_TOKEN,
	      init_data	 => (others => '0')
	      )
	    port map (
	      preset	=> reset,
	      left_in	=> west_in_f_p(i)(j)(p + 1),
	      left_out	=> west_in_b_p(i)(j)(p + 1),
	      right_out => west_in_f_p(i)(j)(p),
	      right_in	=> west_in_b_p(i)(j)(p),
	      lt_enable => open
	      );
	end generate pipeline_stage;
      end generate links_pl_n;
    end generate links_pl_m;
    
  end block pipeline_stages;

  links_m : for i in 0 to M-1 generate
    links_n : for j in 0 to N-1 generate
      top : if (i = 0) generate
	north_in_f_p(i)(j)(0)	<= south_out_f(N-1)(j);
	south_out_b(N-1)(j)	<= north_in_b_p(i)(j)(0);    --b
	south_in_f_p(N-1)(j)(0) <= north_out_f(i)(j);
	north_out_b(i)(j)	<= south_in_b_p(N-1)(j)(0);  --b
      end generate top;
      left : if (j = 0) generate
	west_in_f_p(i)(j)(0)   <= east_out_f(i)(N-1);
	east_out_b(i)(N-1)     <= west_in_b_p(i)(j)(0);	     --b
	east_in_f_p(i)(N-1)(0) <= west_out_f(i)(j);
	west_out_b(i)(j)       <= east_in_b_p(i)(N-1)(0);    --b
      end generate left;
      bottom : if (i = (N-1) and j < (N-1)) generate
	east_in_f_p(i)(j)(0)   <= west_out_f(i)(j+1);
	west_out_b(i)(j+1)     <= east_in_b_p(i)(j)(0);	     --b
	west_in_f_p(i)(j+1)(0) <= east_out_f(i)(j);
	east_out_b(i)(j)       <= west_in_b_p(i)(j+1)(0);    --b
      end generate bottom;
      right : if (i < (N-1) and j = (N-1)) generate
	south_in_f_p(i)(j)(0)	<= north_out_f(i+1)(j);
	north_out_b(i+1)(j)	<= south_in_b_p(i)(j)(0);    --b
	north_in_f_p(i+1)(j)(0) <= south_out_f(i)(j);
	south_out_b(i)(j)	<= north_in_b_p(i+1)(j)(0);  --b
      end generate right;
      center : if (i < (N-1) and j < (N-1)) generate
	north_in_f_p(i+1)(j)(0) <= south_out_f(i)(j);
	south_out_b(i)(j)	<= north_in_b_p(i+1)(j)(0);  --b
	south_in_f_p(i)(j)(0)	<= north_out_f(i+1)(j);
	north_out_b(i+1)(j)	<= south_in_b_p(i)(j)(0);    --b
	west_in_f_p(i)(j+1)(0)	<= east_out_f(i)(j);
	east_out_b(i)(j)	<= west_in_b_p(i)(j+1)(0);   --b
	east_in_f_p(i)(j)(0)	<= west_out_f(i)(j+1);
	west_out_b(i)(j+1)	<= east_in_b_p(i)(j)(0);     --b
      end generate center;
    end generate links_n;
  end generate links_m;

end struct_noswap;
