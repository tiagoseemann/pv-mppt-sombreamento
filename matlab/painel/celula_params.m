function c = celula_params(G, T, p)
%CELULA_PARAMS Grandezas dependentes de G e T de um grupo de p.Ncel celulas.
%   G pode ser vetor (uma irradiancia por submodulo); c.Ipv tem o mesmo tamanho.
%   As saidas valem para um grupo de p.Ncel celulas em serie (Ncel = 1 da
%   os valores por celula).
%   Campos de saida:
%       Vt, Vt_s  tensao termica de uma celula e do grupo [V]
%       Rs_s  resistencia serie do grupo [ohm]
%       Rp_s  resistencia paralela do grupo [ohm], uma por elemento de G
%       Ipv  fotocorrente [A]; I01, I02  correntes de saturacao dos diodos [A]

% Tensao termica Vt = k*T/q (uma celula); o grupo tem Ncel celulas em serie
c.Vt   = p.k * T / p.q;
c.Vt_s = p.Ncel * c.Vt;

% Resistencias de celulas em serie somam
c.Rs_s = p.Ncel * p.Rs;

% Resistencia paralela dependente da irradiancia (De Soto, Klein e Beckman,
% 2006, Solar Energy 80:78-88): Rp(G) = Rp_ref * Gn/G, um valor por submodulo.
% Com Rp constante, a fuga V/Rp quase nao muda com a luz enquanto a
% fotocorrente cai com G; em baixa irradiancia a fuga vira uma fracao enorme
% da corrente (no ajuste do ZTP-160M, perda de 26 % a 200 W/m^2, contra os
% 3-5 % tipicos de modulos monocristalinos). A lei empirica de De Soto faz a
% fuga escalar com a irradiancia. Em G = Gn nada muda, entao a extracao de
% parametros (toda feita em Gn) nao e afetada.
% G = 0 (submodulo no escuro): Gn/0 = Inf, logo Rp = Inf e a fuga Vd/Rp = 0
% (sem NaN, pois Vd/Inf = 0 e 1/Inf = 0).
c.Rp_s = p.Ncel * p.Rp * (p.Gn ./ G(:));

% Fotocorrente: proporcional a irradiancia, corrigida linearmente pela temperatura
c.Ipv  = (G(:) / p.Gn) * (p.Ipv_n + p.Ki * (T - p.Tn));

% Correntes de saturacao: lei EFETIVA, a mesma para os dois diodos,
%   I0k(T) = I0k_n * (T/Tn)^3 * exp(Eg/k * (1/Tn - 1/T)).
% Modulos reais se desviam da teoria da juncao ideal; por isso p.Eg e um gap
% EFETIVO, calibrado pelo coeficiente Kv de Voc do datasheet, que absorve
% efeitos que a lei simples ignora. Com o gap do silicio (1,12 eV) o modelo
% da Kv = -0,106 V/K para o KC200GT, contra -0,123 V/K medido.
c.I01  = p.I01_n * (T / p.Tn)^3 * exp(p.q * p.Eg / p.k * (1 / p.Tn - 1 / T));
c.I02  = p.I02_n * (T / p.Tn)^3 * exp(p.q * p.Eg / p.k * (1 / p.Tn - 1 / T));
end
