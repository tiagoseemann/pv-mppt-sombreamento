function arq = baixar_pvgis(ano)
%BAIXAR_PVGIS Serie horaria do PVGIS para Florianopolis no plano do modulo.
%   Usa a API seriescalc (versao 5_3). aspect: 0 = sul, 180 = norte (no hemisferio
%   sul o modulo aponta para o norte). Os horarios do CSV estao em UTC.
%   Verificado: a v5_3 responde; base PVGIS-SARAH3; colunas time, G(i), H_sun,
%   T2m, WS10m, Int (usadas: time, G(i), T2m, WS10m); amostras em hh:03 UTC.
%   O cabecalho ecoa azimute -179 para aspect = 180 (diferenca desprezivel).
%   Dia escolhido (resultados/dia_escolhido.txt): maior irradiacao diaria de
%   janeiro de 2020 entre os dias em sino (G sobe ate o pico e so desce depois):
%   2020-01-26, 7,825 kWh/m2 (empate tecnico com 25/01, 7,825).
url = 'https://re.jrc.ec.europa.eu/api/v5_3/seriescalc';
arq = fullfile(raiz_projeto(), 'data', 'clima', sprintf('pvgis_floripa_%d.csv', ano));
txt = webread(url, 'lat', -27.595, 'lon', -48.548, 'startyear', ano, ...
    'endyear', ano, 'angle', 27, 'aspect', 180, 'outputformat', 'csv', ...
    weboptions('ContentType', 'text', 'Timeout', 60));
fid = fopen(arq, 'w');  fprintf(fid, '%s', txt);  fclose(fid);
end
