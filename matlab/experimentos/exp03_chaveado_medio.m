%EXP03 Modelo chaveado x medio em CCM (STC) e em DCM (baixa irradiancia).
% Degrau de +0,02 na razao ciclica em t = 2 ms, partindo do equilibrio no MPP.
%   - STC (1000 W/m^2): conducao continua. O modelo medio deve seguir a media
%     de um periodo do chaveado (valida o modelo medio usado no resto do trabalho).
%   - 50 W/m^2: i_L medio (~1 A) e menor que meio ripple (~3 A), entao o
%     indutor zera a cada periodo (DCM). O chaveado captura isso (o diodo
%     bloqueia, i_L >= 0); o modelo medio de CCM nao, e por isso as curvas
%     se separam. Essa diferenca E o resultado esperado: mostra o limite de
%     validade do modelo medio.
%     Fisica do DCM: com i_L partindo de zero a cada periodo, a energia
%     puxada por ciclo e fixada por (v*d*Ts)^2/(2L), muito maior que a
%     potencia do painel a 50 W/m^2. O equilibrio do modelo medio nao e
%     equilibrio do chaveado: v_pv cai continuamente ja antes do degrau.
%     O modelo medio, por sua vez, chega a dar i_L < 0 (fisicamente
%     impossivel, o diodo bloqueia).
clear; clc; close all;
setup_path();

pasta_figs = fullfile(raiz_projeto(), 'relatorio', 'figs');
if ~isfolder(pasta_figs), mkdir(pasta_figs); end

p = parametros_painel('ztp160m');  pc = parametros_conversor(p, 12);
casos = {1000, 'STC (CCM)'; 50, '50 W/m^2 (DCM: medio de CCM nao vale)'};
t_fim = 6e-3;

figure('Position', [100 100 900 650], 'Theme', 'light');
for c = 1:2
    G = casos{c, 1} * ones(1, p.Nsub);

    % Ponto de partida: MPP da curva e o equilibrio do modelo medio nesse ponto
    cv = curva_pv(G, p.Tn, p);
    v0 = cv.Vmp;  I0 = painel_sombreado(v0, G, p.Tn, p);
    eq = equilibrio_conversor(v0, I0, pc);
    if ~eq.viavel
        error('exp03:inviavel', 'Ponto de partida inviavel em G = %g W/m^2', casos{c, 1});
    end
    dfun = @(t) eq.d + 0.02 * (t >= 2e-3);

    tic;
    rs = sim_chaveado(t_fim, dfun, G, p.Tn, p, pc, [v0; eq.iL]);
    t_chav = toc;
    tic;
    rm = sim_medio_aberta(t_fim, dfun, G, p.Tn, p, pc, [v0; eq.iL]);
    t_med = toc;

    % Media movel de um periodo do chaveado, comparada ao modelo medio
    nper = round(pc.Ts / (rs.t(2) - rs.t(1)));
    vbar = movmean(rs.v, nper);  ibar = movmean(rs.iL, nper);
    vm = interp1(rm.t, rm.v, rs.t);  im = interp1(rm.t, rm.iL, rs.t);
    k = rs.t > pc.Ts & rs.t < t_fim - pc.Ts;   % sem as bordas da media movel

    % Ripple de i_L no ultimo periodo antes do degrau, contra v*d/(L*fs)
    kr = rs.t > 2e-3 - pc.Ts & rs.t < 2e-3;
    ripple_sim = max(rs.iL(kr)) - min(rs.iL(kr));
    ripple_ana = v0 * eq.d / (pc.L * pc.fs);

    fprintf('\n--- %s ---\n', casos{c, 2});
    fprintf('v0 = %.2f V, I0 = %.3f A, d = %.4f, iL = %.3f A, CCM = %d\n', ...
        v0, I0, eq.d, eq.iL, verifica_ccm(v0, eq.d, eq.iL, pc));
    fprintf('erro max |media(chav) - medio|: v = %.3f V (%.2f %%), iL = %.3f A (%.2f %%)\n', ...
        max(abs(vbar(k) - vm(k))), 100 * max(abs(vbar(k) - vm(k))) / v0, ...
        max(abs(ibar(k) - im(k))), 100 * max(abs(ibar(k) - im(k))) / eq.iL);
    fprintf('ripple iL: simulado %.3f A, analitico %.3f A\n', ripple_sim, ripple_ana);
    fprintf('tempo: chaveado %.1f s, medio %.2f s\n', t_chav, t_med);

    % So para o grafico: 1 a cada 4 amostras (50 pontos por periodo ainda
    % mostram o ripple) deixa o PDF bem menor
    kp = 1:4:numel(rs.t);
    subplot(2, 2, 2 * c - 1);
    plot(rs.t(kp) * 1e3, rs.v(kp), 'LineWidth', 1.0); hold on;
    plot(rs.t(kp) * 1e3, vbar(kp), 'k', 'LineWidth', 0.8);   % o que e comparado
    plot(rm.t * 1e3, rm.v, '--', 'LineWidth', 1.4); hold off; grid on;
    ylabel('v_{pv} [V]'); xlabel('t [ms]'); title(casos{c, 2});
    % Posicao fixa: com 'best' o exportgraphics trava (minutos) nessas curvas densas
    legend('chaveado', 'media de 1 periodo', 'medio', 'Location', 'southwest');
    subplot(2, 2, 2 * c);
    plot(rs.t(kp) * 1e3, rs.iL(kp), 'LineWidth', 1.0); hold on;
    plot(rs.t(kp) * 1e3, ibar(kp), 'k', 'LineWidth', 0.8);
    plot(rm.t * 1e3, rm.iL, '--', 'LineWidth', 1.4); hold off; grid on;
    ylabel('i_L [A]'); xlabel('t [ms]'); title(casos{c, 2});
end
exportgraphics(gcf, fullfile(pasta_figs, 'e3_chaveado_medio.pdf'));
