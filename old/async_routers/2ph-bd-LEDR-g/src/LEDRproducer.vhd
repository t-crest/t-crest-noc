-- 
-- Copyright Technical University of Denmark. All rights reserved.
-- This file is part of the T-CREST project.
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
-- 
--    1. Redistributions of source code must retain the above copyright notice,
--       this list of conditions and the following disclaimer.
-- 
--    2. Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
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
-- A simulated LEDR producer block.
--
-- Authors: Evangelia Kasapaki
--	    Rasmus Bo Sorensen 
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
library STD;
use STD.textio.all;
library work;
use work.defs.all;


entity LEDR_push_producer is
	generic (
		constant TEST_VECTORS_FILE: string
	);
	port (
		preset : in std_logic;
		right_f : out link_forward;
		right_b  : in link_backward
	);
end entity LEDR_push_producer;


architecture behavioral of LEDR_push_producer is
	file test_vectors: text open READ_MODE is TEST_VECTORS_FILE;
	
	signal req : std_logic := '0';
begin

	-- Simulation-only construct. Synthesizable implemention would just be a NOT gate: right_out.req <= NOT right_in.ack
	stimulus_generate : process  is
		variable flit : word_t := (others => '0');
		variable l    : line;
		variable count : natural := 0;
		variable data_phase : std_logic := '1';
	begin
		right_f.token_t  <= '0';
		right_f.token_parity <= '0';
		right_f.phit <= (others => '0');
		right_f.phit_parity <= (others => '0');
		
		wait until preset = '0';
                wait for 1 ns;
--                req <= '1';

		-- Due to initialization and loops, we start in the second half of the handshake cycle
		while not endfile(test_vectors) loop
			
			req <= not req;
			wait for 0.4 ns;

			readline(test_vectors, l);
			read(l, flit);

			-- Make sure data is valid some time before raising req
			
			right_f.token_t <= flit(33);
			right_f.token_parity <= flit(33) xor req;
			if (flit(33) = '1') then
				right_f.phit <= flit(32 downto 0);
				for i in 32 downto 0 loop
					right_f.phit_parity(i) <= flit(i) xor data_phase;
				end loop;
				data_phase := not data_phase;
			end if;	
			

	        	wait until right_b.ack'event;
		end loop;
		
		wait for 1 ns;
		
	end process stimulus_generate;

end architecture behavioral;

