function tab = identificabilidade_2d(nome, razoes)
%IDENTIFICABILIDADE_2D Mostra que o datasheet nao determina o 2o diodo.
%   tab = identificabilidade_2d('ztp160m')
%   tab = identificabilidade_2d('ztp160m', razoes)
%
%   Para cada razao r = I02/I01, ajusta o modelo de 2 diodos com as mesmas
%   5 condicoes do datasheet. Se todas fecham (residuo ~0) mas as previsoes
%   fora do STC mudam, o parametro nao e identificavel so com o datasheet.
%   A faixa de eta200_rel na tabela e a incerteza que sobra na previsao em
%   baixa irradiancia.
if nargin < 2, razoes = [0.01 0.1 1 10 100]; end
ds = datasheet_painel(nome);
n = numel(razoes);
residuo = zeros(n, 1);  Eg = zeros(n, 1);
eta200_rel = zeros(n, 1);  gamaP = zeros(n, 1);
for k = 1:n
    [p, info] = extrair_parametros(ds, '2d', razoes(k));
    residuo(k) = info.residuo;
    Eg(k) = p.Eg;
    uniforme = ones(1, p.Nsub);
    P1000 = curva_pv(1000 * uniforme, p.Tn, p, 1000).Pmp;
    P200  = curva_pv( 200 * uniforme, p.Tn, p, 1000).Pmp;
    eta200_rel(k) = (P200 / 200) / (P1000 / 1000);      % eficiencia relativa em baixa luz
    Pq = curva_pv(1000 * uniforme, p.Tn + 10, p, 1000).Pmp;
    Pf = curva_pv(1000 * uniforme, p.Tn - 10, p, 1000).Pmp;
    gamaP(k) = (Pq - Pf) / 20 / P1000;                  % coeficiente termico de Pmax
end
tab = table(razoes(:), residuo, Eg, eta200_rel, gamaP, ...
    'VariableNames', {'razao_I02_I01', 'residuo', 'Eg_ef_eV', 'eta200_rel', 'gamaP_1_K'});
end
