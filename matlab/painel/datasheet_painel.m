function ds = datasheet_painel(nome)
%DATASHEET_PAINEL Dados de catalogo (STC) usados na extracao de parametros.
%   ds = datasheet_painel('kc200gt')   Kyocera KC200GT (benchmark, Villalva 2009)
%   ds = datasheet_painel('ztp160m')   ZTROON ZTP-160M (painel do trabalho)
%
%   Campos:
%   Isc, Imp [A]; Voc, Vmp [V]; Pmax [W]; Ki [A/K]; Kv [V/K];
%   gamaP = coeficiente termico de Pmax [1/K] (usado so para VALIDAR o modelo);
%   Ns = celulas em serie; Nsub = submodulos (= diodos de bypass);
%   a_1d = fator de idealidade adotado no modelo de 1 diodo.
%   So no ZTP-160M: A = area [m^2]; NMOT = temperatura nominal de operacao [C].

switch lower(nome)
    case 'kc200gt'
        % Kyocera KC200GT -- Villalva et al. (2009), Tabela I.
        % Usado apenas como benchmark da extracao de parametros.
        ds.nome = 'KC200GT';
        ds.Isc = 8.21;   ds.Voc = 32.9;
        ds.Imp = 7.61;   ds.Vmp = 26.3;   ds.Pmax = 200.143;
        ds.Ki = 3.18e-3; ds.Kv = -0.123;  ds.gamaP = NaN;
        ds.Ns = 54;      ds.Nsub = 3;
        ds.a_1d = 1.3;
    case 'ztp160m'
        % ZTROON ZTP-160M -- datasheet v4.3 (dez/2024).
        % Coeficientes do catalogo em %/K convertidos para A/K e V/K.
        ds.nome = 'ZTP-160M';
        ds.Isc = 9.02;   ds.Voc = 22.64;
        ds.Imp = 8.20;   ds.Vmp = 19.57;  ds.Pmax = 160;
        ds.Ki = 0.0005 * ds.Isc;          % +0,05 %/K de Isc
        ds.Kv = -0.0034 * ds.Voc;         % -0,34 %/K de Voc
        ds.gamaP = -0.004;                % -0,4 %/K de Pmax
        ds.Ns = 33;                       % "Associacao das celulas 3x11"
        ds.Nsub = 3;                      % HIPOTESE: 1 bypass por coluna de 11
        ds.A = 0.82;                      % area [m^2]
        ds.NMOT = 45;                     % [C]
        % Modulo monocristalino com fator de forma alto (0,78): a = 1,3
        % (escolha de Villalva para o KC200GT, policristalino) nao o alcanca
        % sem Rs <= 0. a = 1,1 e o maior valor, em passos de 0,1, que ajusta.
        % A literatura trata o a do modelo de 1 diodo como escolha em [1; 1,5].
        ds.a_1d = 1.1;
    otherwise
        error('datasheet_painel:nome', 'Painel desconhecido: %s', nome);
end
end
