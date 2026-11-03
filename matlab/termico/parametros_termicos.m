function pt = parametros_termicos(ds)
%PARAMETROS_TERMICOS Parametros do modelo termico do modulo, calibrado pelo NMOT.
if ~all(isfield(ds, {'A', 'massa', 'NMOT'}))
    error('parametros_termicos:datasheet', ...
          'Modelo termico requer A, massa e NMOT no datasheet (so o ZTP-160M tem)');
end
pt.A = ds.A;             % area do modulo [m^2]
% Capacidade termica por area = massa * calor especifico medio / area.
% O vidro domina a massa do modulo (~70-75 %) e tem cp ~ 840 J/(kg K); a moldura de
% aluminio (~900) e os polimeros (~1200-1500) sao fracoes menores, entao ~840 e uma
% media ponderada pela massa razoavel. Resulta em ~9,1 kJ/(m^2 K).
cp_medio = 840;                          % calor especifico medio [J/(kg K)]
pt.mcp_area = ds.massa * cp_medio / ds.A;   % [J/(m^2 K)]
pt.alpha = 0.9;          % fracao da radiacao solar absorvida
pt.eps = 0.85;           % emissividade do vidro
pt.kh = 1;               % fator de correcao da conveccao (calibrado abaixo)
pt = calibrar_nmot(pt, ds);
end
