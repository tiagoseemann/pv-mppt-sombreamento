function cen = dia_florianopolis(arq, dia, Nsub)
%DIA_FLORIANOPOLIS Cenario de um dia (t em segundos desde 00:00 LOCAL).
%   dia: datetime (hora local). O PVGIS entrega UTC; converte para UTC-3, de modo
%   que t = 0 e a meia-noite LOCAL e os eventos de sombra usam hora local.
%   Colunas usadas: time, G(i), T2m, WS10m. O CSV tem cabecalho e rodape de texto:
%   so as linhas que comecam com a data (yyyyMMdd:HHmm) sao dados.
linhas = splitlines(string(fileread(arq)));
ini = find(startsWith(linhas, "time,"), 1);
dados = linhas(ini + 1:end);
dados = dados(~cellfun(@isempty, regexp(cellstr(dados), '^\d{8}:\d{4},', 'once')));
tmp = [tempname '.csv'];
writelines([linhas(ini); dados], tmp);
tab = readtable(tmp, 'VariableNamingRule', 'preserve', 'Delimiter', ',', ...
    'TextType', 'string');
delete(tmp);
% UTC -> hora local (Brasilia, UTC-3)
tt = datetime(tab.time, 'InputFormat', 'yyyyMMdd:HHmm') - hours(3);
sel = dateshift(tt, 'start', 'day') == dateshift(dia, 'start', 'day');
h = hours(tt(sel) - dateshift(dia, 'start', 'day')) * 3600;   % segundos desde 00:00 local
G = tab.("G(i)")(sel);  Ta = tab.T2m(sel) + 273.15;  vw = tab.WS10m(sel);
% Interpolacao suave entre as amostras horarias (fora do intervalo: valor mais proximo)
gi = griddedInterpolant(h, G, 'pchip', 'nearest');
ti = griddedInterpolant(h, Ta, 'pchip', 'nearest');
vi = griddedInterpolant(h, vw, 'pchip', 'nearest');
cen.G = @(t) max(gi(t), 0) * ones(1, Nsub);
cen.Tamb = @(t) ti(t);
% Vento: o PVGIS da WS10m (10 m de altura); Watmuff usa o vento junto ao modulo.
% Lei de potencia do perfil de vento (expoente 1/7, terreno aberto), modulo a ~2 m:
fator_altura = (2 / 10)^(1/7);                 % ~0,79
cen.vw = @(t) fator_altura * max(vi(t), 0);
cen.t_fim = h(end);  cen.t_ini_dia = h(find(G > 5, 1));  cen.t_fim_dia = h(find(G > 5, 1, 'last'));
end
