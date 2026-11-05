% Testes dos cenarios: perfil EN 50530, leitor do PVGIS e eventos de sombra.
function tests = test_cenarios
tests = functiontests(localfunctions);
end

function test_en50530_trapezio(tc)
% Uma linha de tabela sintetica gera espera + trapezios com as duracoes esperadas.
arq = [tempname '.csv'];
writelines(["% teste"
             "sequencia,G_baixo,G_alto,inclinacao_Wm2s,patamar_s,repeticoes,espera_s"
             "X,100,500,10,5,2,20"], arq);
tc.addTeardown(@delete, arq);
cen = perfil_en50530(arq, 3);
% espera 20 s em 100; trapezio: sobe 40 s, 5 s em 500, desce 40 s, 5 s em 100 (x2)
verifyEqual(tc, cen.t_fim, 20 + 2 * 90, 'AbsTol', 1e-9);
verifyEqual(tc, cen.G(10), [100 100 100], 'AbsTol', 1e-9);   % espera
verifyEqual(tc, cen.G(40), [300 300 300], 'AbsTol', 1e-6);   % meio da 1a rampa
verifyEqual(tc, cen.G(62), [500 500 500], 'AbsTol', 1e-9);   % patamar alto
verifyEqual(tc, cen.G(85), [300 300 300], 'AbsTol', 1e-6);   % meio da 1a descida (65 a 105 s)
verifyEqual(tc, cen.G(200), [100 100 100], 'AbsTol', 1e-9);  % patamar final
end

function test_en50530_tabela_real(tc)
% A tabela transcrita da norma (B.2 + B.3 + B.4) soma 25085,7 s e a 1a rampa chega a 500.
arq = fullfile(raiz_projeto(), 'data', 'en50530_rampas.csv');
cen = perfil_en50530(arq, 3);
% rampas calculadas pela inclinacao (ex.: 400/3 = 133,3 s; o relatorio imprime 133)
verifyEqual(tc, cen.t_fim, 25085.714, 'AbsTol', 1e-3);       % B.2 + B.3 + B.4
verifyEqual(tc, cen.G(300 + 800), [500 500 500], 'AbsTol', 1e-6);  % fim da 1a rampa a 0,5 W/m2/s
end

function test_sombra_afeta_so_um_submodulo(tc)
% Um evento com sub = 3 reduz so a irradiancia do 3o submodulo.
cen = cenario_constante([1000 1000 1000], 298.15, 1, 100);
ev = table(10, 20, 3, 0.3, 1, 'VariableNames', {'t_ini', 't_fim', 'sub', 'fator', 'rampa_s'});
cen = aplicar_sombras(cen, ev);
verifyEqual(tc, cen.G(5), [1000 1000 1000], 'AbsTol', 1e-9);
verifyEqual(tc, cen.G(10.5), [1000 1000 650], 'AbsTol', 1e-6);   % meio da rampa de entrada
verifyEqual(tc, cen.G(15), [1000 1000 300], 'AbsTol', 1e-6);
verifyEqual(tc, cen.G(25), [1000 1000 1000], 'AbsTol', 1e-9);    % depois do evento
end

function test_nuvem_afeta_todos(tc)
% Um evento com sub = 0 (nuvem) reduz todos os submodulos.
cen = cenario_constante([1000 1000 1000], 298.15, 1, 100);
ev = table(10, 20, 0, 0.5, 1, 'VariableNames', {'t_ini', 't_fim', 'sub', 'fator', 'rampa_s'});
cen = aplicar_sombras(cen, ev);
verifyEqual(tc, cen.G(15), [500 500 500], 'AbsTol', 1e-6);
end

function test_dia_florianopolis_utc_para_local(tc)
% O leitor converte UTC para hora local (UTC-3) e entrega G, Tamb em K e t_ini_dia.
arq = [tempname '.csv'];
L = ["Latitude (decimal degrees):	-27.595"; ""; "time,G(i),H_sun,T2m,WS10m,Int"];
for hu = 0:23                                   % 15/01/2020, hora UTC
    G = max(0, 1000 * sin(pi * (hu - 3 - 6) / 13));   % sol entre 6h e 19h local
    L(end + 1) = sprintf('20200115:%02d10,%.9f,30,%.1f,2.0,0', hu, G, 25 + hu / 10); %#ok<AGROW>
end
L(end + 1) = "";  L(end + 1) = "G(i): Global irradiance on the inclined plane (W/m2)";
writelines(L, arq);
tc.addTeardown(@delete, arq);
cen = dia_florianopolis(arq, datetime(2020, 1, 15), 3);
% amostra das 15:10 UTC = 12:10 local (no proprio ponto, a interpolacao e exata)
verifyEqual(tc, cen.G(12 * 3600 + 600), 1000 * sin(pi * 6 / 13) * [1 1 1], 'RelTol', 1e-6);
verifyEqual(tc, cen.Tamb(12 * 3600 + 600), 25 + 15 / 10 + 273.15, 'AbsTol', 1e-9);
% o fixture e zero as 06:10 local (sin(0)); o primeiro G > 5 e a amostra das 07:10
verifyEqual(tc, cen.t_ini_dia, 7 * 3600 + 600, 'AbsTol', 1e-6);
% UTC 00-02 pertence ao dia local anterior: o dia termina na amostra das 20:10 local
verifyEqual(tc, cen.t_fim, 20 * 3600 + 600, 'AbsTol', 1e-6);
end
