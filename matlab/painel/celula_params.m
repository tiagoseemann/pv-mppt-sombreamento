function c = celula_params(G, T, p)
%CELULA_PARAMS Grandezas dependentes de G e T de um grupo de p.Ncel celulas.
%   G pode ser vetor (uma irradiancia por submodulo); c.Ipv tem o mesmo tamanho.
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

% Correntes de saturacao crescem fortemente com T (gap Eg e expoente gam)
c.I01  = p.I01_n * fator_T(p.a1, 3);
c.I02  = p.I02_n * fator_T(p.a2, 1.5);

    function f = fator_T(a, gam)
        % Razao I0(T)/I0(Tn) = (T/Tn)^gam * exp(q*Eg/(a*k) * (1/Tn - 1/T))
        f = (T / p.Tn)^gam * exp(p.q * p.Eg / (a * p.k) * (1 / p.Tn - 1 / T));
    end
end
