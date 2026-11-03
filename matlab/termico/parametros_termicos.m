function pt = parametros_termicos(ds)
%PARAMETROS_TERMICOS Parametros do modelo termico do modulo, calibrado pelo NMOT.
pt.A = ds.A;             % area do modulo [m^2]
pt.mcp_area = 11e3;      % capacidade termica por area: vidro+EVA+celula [J/(m^2 K)]
pt.alpha = 0.9;          % fracao da radiacao solar absorvida
pt.eps = 0.85;           % emissividade do vidro
pt.kh = 1;               % fator de correcao da conveccao (calibrado abaixo)
pt = calibrar_nmot(pt, ds);
end
