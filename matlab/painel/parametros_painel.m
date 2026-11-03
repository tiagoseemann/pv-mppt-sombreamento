function p = parametros_painel(nome)
%PARAMETROS_PAINEL Parametros do modulo FV com submodulos e diodos de bypass.
%   p = parametros_painel('generico')  painel generico de 36 celulas (~140 W)
%   ATENCAO: valores PROVISORIOS (painel generico de 36 celulas, ~140 W).
%   Substituir pelos parametros extraidos do datasheet do ZTP-160M (etapa 1).

if nargin < 1, nome = 'generico'; end
if ~strcmpi(nome, 'generico')
    error('parametros_painel:nome', 'Painel "%s" ainda nao suportado', nome);
end
p.nome = 'generico';

% Constantes fisicas
p.q  = 1.602176634e-19;     % carga do eletron [C]
p.k  = 1.380649e-23;        % constante de Boltzmann [J/K]
p.Eg = 1.12;                % gap do silicio [eV]

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
p.a1    = 1.0;
p.a2    = 2.0;
p.Rs    = 0.005;            % [ohm]
p.Rp    = 10;               % [ohm]
p.Ki    = 0.0005 * 8.2;     % coef. termico da corrente [A/K]

% Diodo de bypass (Schottky)
p.I0bp = 1.4e-6;            % [A]  (V_F ~ 0,4 V a 8 A)
p.nbp  = 1.0;
end
