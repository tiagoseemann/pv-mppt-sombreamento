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
%   com fsolve (Optimization Toolbox); residuo final ~ 0.
%   Todas as condicoes sao residuos EXPLICITOS de kcl_modulo nos pontos dados.
%
%   Por que fixar I02/I01 no '2d': o datasheet nao identifica I02 separadamente.
%   Fixando I02 em qualquer valor de 1e-12 a 1e-5 A, as condicoes de STC
%   (Isc, Voc, MPP, dP/dV) fecham exatamente; logo e preciso uma hipotese
%   extra publicada. A analise de identificabilidade esta em identificabilidade_2d.m.
%
%   Por que Eg e incognita: Eg e um gap EFETIVO (ver celula_params); a
%   condicao de Kv o calibra. No '1d' ele e so um parametro de calibracao,
%   sem significado fisico: compensa a inclinacao errada que o a agrupado
%   da a lei T^3 (o KC200GT '1d' da Eg ~ 0,91 eV).
%
%   p    : struct no formato de parametros_painel (valores POR CELULA)
%   info : saida do fsolve (residuo = norma dos residuos, r, iter)
%          mais info.convergiu = (residuo < 1e-6); avisa se nao convergiu

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

% Variaveis do fsolve: y = [Ipv, log10 I01, log10 Rs, log10 Rp, Eg].
% O fsolve NAO tem limites. Sem eles, no ZTP-160M ele divergia (Rp indo
% para -4e12 ohm e residuo parado em 4e-2). Resolvemos em log10 de Rs e Rp:
% 10^y e sempre positivo, entao a divergencia para valores negativos some.
% I01 ja era ajustada em log10 porque varia muitas decadas (o solver ve
% variaveis da mesma ordem de grandeza).
%     Ipv   log10 I01  log10 Rs [ohm]  log10 Rp [ohm]  Eg [eV]
y0 = [ds.Isc; -8;      log10(0.2);     log10(300);     1.12];
fun = @(y) residuos_extracao([y(1); y(2); 10^y(3); 10^y(4); y(5)], ds, p0);

% Tolerancias apertadas: o sistema 5x5 tem solucao exata (residuo ~ 0)
opcoes = optimoptions('fsolve', 'Display', 'off', ...
    'FunctionTolerance', 1e-14, 'StepTolerance', 1e-14, ...
    'OptimalityTolerance', 1e-14, 'MaxIterations', 500, ...
    'MaxFunctionEvaluations', 5000);
[y, r, ~, saida] = fsolve(fun, y0, opcoes);
x = [y(1); y(2); 10^y(3); 10^y(4); y(5)];
info = struct('iter', saida.iterations, 'residuo', norm(r), 'r', r);
p = aplicar_incognitas(x, p0);
p = rmfield(p, 'razao');              % campo auxiliar, so usado no ajuste

% Sistema 5x5: na solucao exata todos os residuos sao ~0
info.convergiu = info.residuo < 1e-6;
if ~info.convergiu
    warning('extrair_parametros:naoConvergiu', ...
        'Extracao de %s (%s) nao convergiu: residuo = %.2e', ...
        ds.nome, modelo, info.residuo);
end
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
%    Esta condicao calibra o gap efetivo Eg. dT = 25 K leva a 50 C, dentro
%    da faixa de operacao real, e e grande o bastante para que o efeito
%    de Eg sobre Voc domine o erro numerico.
dT = 25;
F5 = kcl_modulo(ds.Voc + ds.Kv * dT, 0, Gn, Tn + dT, q);

% Divide por Isc para que todos os residuos sejam correntes relativas
r = [F1; F2; F3; F4; F5] / ds.Isc;
end

function p = parametros_base(ds)
% Campos que nao sao ajustados: constantes, STC, arranjo e bypass.
% As constantes fisicas e o diodo de bypass devem ser iguais aos de
% parametros_painel('generico') (painel/parametros_painel.m): mesma fisica.
p.nome = ds.nome;
p.q = 1.602176634e-19;  p.k = 1.380649e-23;
p.Gn = 1000;  p.Tn = 298.15;
p.Ns = ds.Ns;  p.Nsub = ds.Nsub;  p.Ncel = ds.Ns / ds.Nsub;
p.Ki = ds.Ki;
p.I0bp = 1.4e-6;  p.nbp = 1.0;      % diodo de bypass Schottky (como no generico)
end
