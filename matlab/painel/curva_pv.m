function c = curva_pv(G, T, p, nPts)
%CURVA_PV Varre a tensao do modulo e devolve as curvas I-V e P-V.
%   c = curva_pv(G, T, p)       G: 1 x Nsub [W/m^2], T [K]
%   c = curva_pv(G, T, p, nPts)
%
%   c.V, c.I, c.P : curvas
%   c.Vmp, c.Pmp  : maximo GLOBAL
%   c.picos       : tabela com todos os maximos locais

if nargin < 4, nPts = 600; end

% Voc estimado folgado: soma dos Voc nominais por submodulo, com margem
Voc_est = p.Nsub * p.Ncel * 0.75;
V = linspace(0, Voc_est, nPts);
I = zeros(size(V));

z = [];
for n = 1:nPts
    [I(n), s] = painel_sombreado(V(n), G, T, p, z);
    z = s.z;                      % warm start para o proximo ponto
end

ok = I >= 0;                      % descarta a regiao alem de Voc
c.V = V(ok);  c.I = I(ok);  c.P = c.V .* c.I;

[c.Pmp, k] = max(c.P);
c.Vmp = c.V(k);
c.Imp = c.I(k);

loc = find(islocalmax(c.P));
c.picos = table(c.V(loc).', c.I(loc).', c.P(loc).', ...
    'VariableNames', {'V', 'I', 'P'});
end
