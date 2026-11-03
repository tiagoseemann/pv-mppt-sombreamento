function p = parametros_painel(nome)
%PARAMETROS_PAINEL Parametros do modulo FV com submodulos e diodos de bypass.
%   p = parametros_painel('generico')  painel generico de 36 celulas (~140 W)
%   p = parametros_painel('ztp160m')   painel real (tambem 'kc200gt')
%   Caso 'generico': valores provisorios, mantidos como referencia de
%   regressao dos testes de sombreamento.
%   Paineis reais: parametros do modelo de 2 diodos extraidos do datasheet
%   (extrair_parametros) a cada chamada. A extracao leva < 0,5 s, entao nao
%   ha cache em disco: um cache esconderia mudancas no codigo.

if nargin < 1, nome = 'generico'; end
if ~strcmpi(nome, 'generico')
    p = extrair_parametros(datasheet_painel(nome), '2d');
    return
end
p.nome = 'generico';

% Constantes fisicas
p.q  = 1.602176634e-19;     % carga do eletron [C]
p.k  = 1.380649e-23;        % constante de Boltzmann [J/K]
p.Eg = 1.12;                % gap efetivo [eV] (aqui o do silicio)

% Condicoes nominais (STC)
p.Gn = 1000;                % [W/m^2]
p.Tn = 298.15;              % [K]

% Arranjo
p.Ns   = 36;                % celulas em serie no modulo
p.Nsub = 3;                 % submodulos (= numero de diodos de bypass)
p.Ncel = p.Ns / p.Nsub;     % celulas por submodulo

% Parametros POR CELULA do modelo de 2 diodos
p.Ipv_n = 8.21;             % fotocorrente nominal [A]
p.I01_n = 3.5e-10;          % saturacao, difusao [A]
p.I02_n = 1.0e-6;           % saturacao, recombinacao [A]
p.a1    = 1.0;              % fator de idealidade do diodo de difusao
p.a2    = 2.0;              % fator de idealidade do diodo de recombinacao
p.Rs    = 0.005;            % resistencia serie POR CELULA [ohm]
p.Rp    = 10;               % resistencia paralela POR CELULA [ohm]
p.Ki    = 0.0005 * 8.2;     % coef. termico da corrente [A/K] (+0,05 %/K x Isc)

% Diodo de bypass (Schottky)
p.I0bp = 1.4e-6;            % [A]  (V_F ~ 0,4 V a 8 A)
p.nbp  = 1.0;
end
