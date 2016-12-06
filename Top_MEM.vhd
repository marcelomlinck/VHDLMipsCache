----------------------------------------------------------------------------------
-- Company: Insight Corp.
-- Engineer: Bruno Scherer Oliveira / Ricardo Aquino Guazzelli
-- 
-- Create Date:    19:40:44 05/25/2011 
-- Module Name:    Top_MEM - MEM 
-- Project Name: 	 MR4_cache
-- Description: internal architecture of a hierarchy cache memory
-- with direct mapping.
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: The top of the top. Bitches Dig Top...less...
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.CachePackage.ALL;

entity Top_MEM is
	port(
		clk,reset:						in STD_LOGIC; --d���
		addr:								in reg32; --equivale ao PC
		ce_n,we_n,oe_n: 			in STD_LOGIC; --ce, we, oe
		data_in:							in reg32; --recebe instru��o da Mem�ria Principal
		data_out:						out reg32; --instructi��o para mem�ria principal
		hold:								out STD_LOGIC --stall
	);
end Top_MEM;

architecture MEM of Top_MEM is
signal L2_L1: reg128; -- connect L2 with L1
signal MP_L2: reg32;  -- connect MP WITH l2
-- auxiliary signals
signal L1_data,MP_data,MP_address,L2_address,L1_address: reg32; --Passa o endere�o para as caches e mem�ria principal.
signal L1_ce_n, L1_we_n, L1_oe_n, L1_hit: STD_LOGIC; --Escrita, leitura e hit de L1
signal L2_ce_n, L2_we_n, L2_oe_n, L2_hit: STD_LOGIC; --Escrita, hit e leitura de L2
signal MP_ce_n,MP_we_n,MP_oe_n: STD_LOGIC; --Escrita hit e leitura da Mem�ria principal
signal MAST : type_state; --A m�quina de estados � definida no top caches
signal L2wait: integer range 0 to WAIT_L2-1; --Verifica se est� pronta para enviar dados � L1
signal MPwait: integer range 0 to WAIT_MP-1; --Verifica se est� pronta para enviar dados � L2
signal Isend,aux_address: reg32 := (others=>'0'); --Isend: conta se foram carregadas 8 instru��es em L2
--aux_address: L2 recebe endere�o da mem�ria principal por esse sinal
begin

	-- L1 cache
	L1: entity work.L1_cache
		 generic map ( START_A => x"00400000" ) --Come�a com o endere�o inicial padr�o
		 port map (
			address => L1_address, --Recebe o endere�o do processador
			data => L1_data, --Recebe os dados do processador
			block_L2 => L2_L1, --Recebe os dados de L2
			ce_n => L1_ce_n, 
			we_n => L1_we_n,
			oe_n => L1_oe_n, --Passa os sinais de escrita e leitura do processador
			hit => L1_hit --Passa o hit
		);
		
	-- L2 cache
	L2: entity work.L2_cache
		 generic map ( START_A => x"00400000" ) --Come�a com o endere�o inicial padr�o
		 port map (
			address => L2_address, --Recebe o endere�o de L1
			Block_L1 => L2_L1, --Passa os dados para L1
			block_MP => MP_L2, --Recebe os dados da mem�ria principal
			ce_n => L2_ce_n,
			we_n => L2_we_n,
			oe_n => L2_oe_n, --Passa os sinais de escrita e leitura do processador
			hit => L2_hit --Passa o hit
		);
		
	MP: entity work.MP
       generic map( START_ADDRESS => x"00400000" )
       port map (
			ce_n=>MP_ce_n, 
			we_n=>MP_we_n, 
			oe_n=>MP_oe_n, --Passa os sinais de escrita e leitura do processador
			address=>MP_address, --A mem�ria principal recebe o endere�o de L2
			data=>MP_data --Recebe os dados do processador
		);
		
        
		MP_data <= data_in; --Recebe os dados do processador
		
		MP_L2 <= (others=>'Z') when MAST = TMEMO else MP_data; --Quando se inicia o programa L2 n�o recebe nada da mem�ria princiapal, sen�o L2 recebe o que est� na mem�ria principal
		
		data_out <= L1_data; --Ao final o dado sai de L1 para o processador, pois ela est� no n�vel superior
		
		
		-- hold processor
		hold <= '0' when MAST = SL1 and L1_hit = '1' else '1'; --Se o processador estiver lendo a L1 e L1 deu hit n�o "tranca" e a cache pode passa a mem�ria, sen�o "tranca" at� que L1 tenha armazenado o endere�o correto
		
		-- address connect direct 
		L1_address <= addr; --L1 recebe o endere�o de PC
		L2_address <= aux_address when MAST = WMP or MAST = SMP else addr ; --L2 recebe o endere�o auxiliar quando o dado estiver na mem�ria principal ou em L2, sen�o recebe do PC
		MP_address <= addr when MAST = TMEMO else aux_address; --Se o endere�o estiver na mem�ria principal ela tem o mesmo endere�o de PC, sen�o ela recebe um endere�o auxiliar
		
		aux_address <= addr(31 downto 4) & "0000" + Isend;	--O endere�o auxiliar recebe o endere�o de PC + 0000 + 8 instru��es da mem�ria principal 
		
		-- L1 control
		L1_ce_n <= '0' when MAST = SL1 or MAST = WL2 or MAST = WBL1 else '1'; --Desabilita o ce quando o processador estiver lendo L1 ou L2 estiver sendo escrita
		L1_oe_n <= '0' when MAST = SL1 or MAST = WBL1 else '1'; --Esse sinal bizzaro est� inativo quando o processador estiver lendo L1
		L1_we_n <= '0' when MAST = WL2 else '1'; --L1 n�o pode escrever se o dado estiver sendo escrito em L2
		
		-- L2 control
		L2_ce_n <= '0' when MAST = WL2 or MAST = WMP else '1'; --Desabilita o ce quando estiver escrevendo L2 ou lendo/pegando o dado da mem�ria principal
		L2_oe_n <= '0' when MAST = WL2 else '1'; --Esse sinal bizzaro est� inativo quando o processador estiver lendo L2
		L2_we_n <= '0' when MAST = WMP else '1'; --L2 n�o pode escrever se o dado estiver na mem�ria principal
		
		-- MP control
		MP_ce_n <= '0' when MAST = WMP or MAST = SMP else --Desabilita o ce se a mem�ria principal est� passando para L2
					  ce_n when MAST = TMEMO --Quando se inicia o programa a mem�ria principal tem o mesmo sinal de leitura do processador
					  else '1'; 
		MP_oe_n <= '0' when MAST = WMP or MAST = SMP else '1'; --Se a mem�ria principal est� passando para L2 desativa o sinal bizarro
		MP_we_n <= we_n when MAST = TMEMO else '1'; --Quando se inicia o programa a mem�ria principal tem o mesmo sinal de escrita do processador
		
		
		process(MAST,clk,reset)
		begin
		 if(reset = '1') then
			-- loading instruction memory
			MAST <= TMEMO; --Iniciando o programa
		 elsif(rising_edge(clk)) then --Se clock = '1'
			case MAST is 
		 
				when TMEMO =>
						-- memory is ready
						MAST <= SL1;  --Na primeira borda de subida ap�s o reset l� a L1
						
					
				when SL1 =>
					if L1_hit = '0' then --Se deu miss na L1
						-- instruction in L1
						-- go back and hold = '0' --Se a instru��o estiver em L1(L1_hit = '1') volta e "destrava" o processador
						if WriteBack ='1' then
							MAST <= WBL1;
						else
							MAST <= SL2; --L� a L2
					end if;
				
				when WBL1 =>
					if WriteBack = '0' then 
						MAST <= SL1;
					end if;
				
				when SL2 =>
					if L2_hit = '1' then --Se deu hit na L2
						-- instruction in L2
						-- wait for L2
						MAST <= WL2; --Pega a instru��o de L2
					else 
						L2wait <= 0; -- L2 est� pronta para ser escrita
						MAST <= SMP; -- OK, the instruction is in MP!
					end if;
				
				when SMP =>
					if Isend = 32 then --Se forem passadas 8 instru��es para L2
						-- L2 loaded!
						Isend <= (others=>'0'); --Passou as instru��es, portanto zera Isend
						MAST <= WL2; --Espera por L2
					else 
						MPwait <= 0; --Mem�ria principal est� pronta para enviar os dados
						MAST <= WMP; -- there're more instructions --Falta passar instru��es
					end if;
					
				when WL2 =>
					-- L2 ready to write
					if(L2wait = WAIT_L2) then MAST <= SL1; --Se L2 est� pronta para escrever, escreve em L1
					else L2wait <= L2wait + 1; -- wait for L2 
					end if;
				
				when WMP =>
					-- MP ready to write
					if(MPwait = WAIT_MP) then
						Isend <= Isend + 4; -- one more instruction --Passa mais uma instru��o para L2
						MAST <= SMP; --V� se acabou de passar todas as instru��es para L2
					else MPwait <= MPwait + 1; --Espera pela mem�ria principal
					end if;
			end case;
		end if;
	end process;
	
end MEM;