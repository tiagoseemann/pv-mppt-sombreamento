function v = validar_painel(nome)
%VALIDAR_PAINEL Compara os modelos de 1 e 2 diodos com o que o datasheet publica.
%   v = validar_painel('ztp160m')
%
%   O datasheet nao traz curvas I-V. Os pontos de STC entram no ajuste (o
%   erro deles so confirma que a extracao fechou); o coeficiente termico de
%   Pmax (gamaP) NAO entra no ajuste e e a validacao independente.
%
%   v.erroPmax_STC, v.erroVoc_STC : erro relativo em STC   [1d 2d]
%   v.gamaP_modelo                : dPmax/dT / Pmax  [1/K]  [1d 2d]
%   v.G                           : irradiancias avaliadas [W/m^2]
%   v.Pmax_G                      : Pmax em cada G [W] (linhas: 1d, 2d)
ds = datasheet_painel(nome);
modelos = {extrair_parametros(ds, '1d'), extrair_parametros(ds, '2d')};
Gs = [1000 800 600 400 200];
v.G = Gs;
for m = 1:2
    p = modelos{m};
    uniforme = ones(1, p.Nsub);           % sem sombra: mesma G nos submodulos

    % Pontos de STC (impostos no ajuste). c.V(end) e a ultima tensao com
    % I >= 0, ou seja, o Voc da curva (resolucao de ~12 mV com 2000 pontos).
    c = curva_pv(1000 * uniforme, p.Tn, p, 2000);
    v.erroPmax_STC(m) = (c.Pmp - ds.Pmax) / ds.Pmax;
    v.erroVoc_STC(m) = (c.V(end) - ds.Voc) / ds.Voc;

    % Coeficiente termico de Pmax: derivada central entre 15 C e 35 C,
    % normalizada pelo Pmax de STC (mesma definicao do datasheet, em 1/K)
    cq = curva_pv(1000 * uniforme, p.Tn + 10, p, 2000);
    cf = curva_pv(1000 * uniforme, p.Tn - 10, p, 2000);
    v.gamaP_modelo(m) = (cq.Pmp - cf.Pmp) / 20 / c.Pmp;

    % Potencia maxima em varias irradiancias: e onde 1d e 2d diferem, pois
    % em baixa corrente a forma da curva do diodo (a1 agrupado no 1d, ou
    % difusao + recombinacao no 2d) muda a tensao do MPP
    for k = 1:numel(Gs)
        v.Pmax_G(m, k) = curva_pv(Gs(k) * uniforme, p.Tn, p, 1000).Pmp;
    end
end
end
