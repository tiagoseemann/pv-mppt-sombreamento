function [p, info] = extrair_parametros(ds, modelo, razao)
%EXTRAIR_PARAMETROS Parametros do modelo de 2 (ou 1) diodos a partir do datasheet.
%   [p, info] = extrair_parametros(ds)                 modelo de 2 diodos ('2d')
%   [p, info] = extrair_parametros(ds, modelo)         modelo = '2d' ou '1d'
%   [p, info] = extrair_parametros(ds, '2d', razao)    razao = I02_n / I01_n
%
%   '2d': convencao de Ishaque et al. (2011): a1 = 1, a2 = 1,2 e, por
%         padrao, I01_n = I02_n (razao = 1). Outra razao fixa I02_n = razao*I01_n.
%   '1d': a1 = ds.a_1d, I02_n = 0 (razao e ignorada)
%   Nos dois modelos:
%         incognitas x = [Ipv, log10 I01, Rs, Rp, Eg]  (Rs, Rp do MODULO)
%         condicoes: Isc, Voc, MPP, dP/dV = 0 no MPP, coef. Kv de Voc
%   5 condicoes e 5 incognitas: o ajuste e um sistema de equacoes resolvido
%   por minimos quadrados (residuo final ~ 0).
%   Todas as condicoes sao residuos EXPLICITOS de kcl_modulo nos pontos dados.
%
%   Por que fixar I02/I01 no '2d': o datasheet nao identifica I02 separadamente.
%   Fixando I02 em qualquer valor de 1e-12 a 1e-5 A, as condicoes de STC
%   (Isc, Voc, MPP, dP/dV) fecham exatamente; logo e preciso uma hipotese
%   extra publicada. A analise de identificabilidade fica para a Tarefa 3.
%
%   Por que Eg e incognita: Eg e um gap EFETIVO (ver celula_params); a
%   condicao de Kv o calibra.
%
%   p    : struct no formato de parametros_painel (valores POR CELULA)
%   info : saida do levenberg_marquardt (residuo, residuos r, iteracoes)

if nargin < 2, modelo = '2d'; end
if nargin < 3, razao = 1; end         % convencao de Ishaque: I01 = I02
p0 = parametros_base(ds);

switch modelo
    case '2d'
        p0.a1 = 1;  p0.a2 = 1.2;
        p0.razao = razao;
    case '1d'
        p0.a1 = ds.a_1d;  p0.a2 = 2;      % a2 nao importa: I02 = 0
        p0.razao = 0;                     % sem segundo diodo
    otherwise
        error('extrair_parametros:modelo', 'Modelo deve ser 1d ou 2d');
end

% A corrente de saturacao I01 varia muitas decadas, por isso e ajustada em
% log10: o otimizador ve variaveis da mesma ordem de grandeza.
%     Ipv          log10 I01  Rs [ohm]  Rp [ohm]  Eg [eV]
x0 = [ds.Isc;        -8;       0.2;      300;      1.12];
lb = [ds.Isc;        -14;      1e-4;     10;       0.9];
ub = [1.05 * ds.Isc;  -4;      2;        1e4;      1.6];

fun = @(x) residuos_extracao(x, ds, p0);
[x, info] = levenberg_marquardt(fun, x0, lb, ub);
p = aplicar_incognitas(x, p0);
p = rmfield(p, 'razao');              % campo auxiliar, so usado no ajuste
end

function q = aplicar_incognitas(x, p0)
% Converte o vetor de incognitas x em um struct de parametros POR CELULA.
% p0.razao = I02_n/I01_n fixa (1 no '2d' de Ishaque, 0 no '1d').
q = p0;
q.Ipv_n = x(1);
q.I01_n = 10^x(2);
q.I02_n = p0.razao * q.I01_n;
% x guarda Rs e Rp do modulo; as Ns celulas em serie dividem igualmente
q.Rs = x(3) / p0.Ns;
q.Rp = x(4) / p0.Ns;
q.Eg = x(5);                          % gap efetivo [eV]
end

function r = residuos_extracao(x, ds, p0)
% Residuos das condicoes do datasheet; todos zero na solucao.
q = aplicar_incognitas(x, p0);
Gn = q.Gn;  Tn = q.Tn;

% 1) Curto-circuito: (V, I) = (0, Isc) esta sobre a curva
F1 = kcl_modulo(0, ds.Isc, Gn, Tn, q);
% 2) Circuito aberto: (V, I) = (Voc, 0) esta sobre a curva
F2 = kcl_modulo(ds.Voc, 0, Gn, Tn, q);
% 3) MPP: (Vmp, Imp) esta sobre a curva
[F3, ~, dIdV] = kcl_modulo(ds.Vmp, ds.Imp, Gn, Tn, q);
% 4) MPP e maximo: dP/dV = I + V*dI/dV = 0 em (Vmp, Imp)
F4 = ds.Imp + ds.Vmp * dIdV;
% 5) Coeficiente termico: a Tn + dT o Voc deve ser Voc + Kv*dT.
%    Esta condicao calibra o gap efetivo Eg.
dT = 25;
F5 = kcl_modulo(ds.Voc + ds.Kv * dT, 0, Gn, Tn + dT, q);

% Divide por Isc para que todos os residuos sejam correntes relativas
r = [F1; F2; F3; F4; F5] / ds.Isc;
end

function p = parametros_base(ds)
% Campos que nao sao ajustados: constantes, STC, arranjo e bypass.
p.nome = ds.nome;
p.q = 1.602176634e-19;  p.k = 1.380649e-23;
p.Gn = 1000;  p.Tn = 298.15;
p.Ns = ds.Ns;  p.Nsub = ds.Nsub;  p.Ncel = ds.Ns / ds.Nsub;
p.Ki = ds.Ki;
p.I0bp = 1.4e-6;  p.nbp = 1.0;      % diodo de bypass Schottky (como no generico)
end
