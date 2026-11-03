function c = celula_params(G, T, p)
%CELULA_PARAMS Grandezas dependentes de G e T de um grupo de p.Ncel celulas.
%   G pode ser vetor (uma irradiancia por submodulo); c.Ipv tem o mesmo tamanho.
%   As saidas valem para um grupo de p.Ncel celulas em serie (Ncel = 1 da
%   os valores por celula).
%   Campos de saida:
%       Vt, Vt_s  tensao termica de uma celula e do grupo [V]
%       Rs_s, Rp_s  resistencias serie e paralelo do grupo [ohm]
%       Ipv  fotocorrente [A]; I01, I02  correntes de saturacao dos diodos [A]

% Tensao termica Vt = k*T/q (uma celula); o grupo tem Ncel celulas em serie
c.Vt   = p.k * T / p.q;
c.Vt_s = p.Ncel * c.Vt;

% Resistencias de celulas em serie somam
c.Rs_s = p.Ncel * p.Rs;
c.Rp_s = p.Ncel * p.Rp;

% Fotocorrente: proporcional a irradiancia, corrigida linearmente pela temperatura
c.Ipv  = (G(:) / p.Gn) * (p.Ipv_n + p.Ki * (T - p.Tn));

% Correntes de saturacao: a dependencia com T vem do MECANISMO de conducao,
% nao do fator de idealidade ajustado (a1, a2), entao os divisores sao fixos.
%   Difusao (diodo 1):     I01 ~ ni^2 ~ T^3   * exp(-Eg/(k*T))
%   Recombinacao (diodo 2): I02 ~ ni  ~ T^1,5 * exp(-Eg/(2*k*T))
% Por isso os expoentes 3 e 1,5 pertencem ao mecanismo: um modelo de 1 diodo
% com a agrupado (~1,3) mantem a forma da difusao (De Soto).
c.I01  = p.I01_n * (T / p.Tn)^3   * exp(p.q * p.Eg / p.k       * (1 / p.Tn - 1 / T));
c.I02  = p.I02_n * (T / p.Tn)^1.5 * exp(p.q * p.Eg / (2 * p.k) * (1 / p.Tn - 1 / T));
end
