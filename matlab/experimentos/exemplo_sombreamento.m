%EXEMPLO_SOMBREAMENTO Curvas I-V e P-V do modulo com e sem sombreamento parcial.
clear; clc;

p = parametros_painel();
T = 298.15;

cenarios = {
    [1000 1000 1000], 'sem sombra'
    [1000 1000  400], '1 submodulo a 400 W/m^2'
    [1000  600  300], 'sombra em degrade (1000/600/300)'
};

cores = lines(size(cenarios, 1));

figure('Name', 'Sombreamento parcial', 'Position', [100 100 1000 420]);
for n = 1:size(cenarios, 1)
    c = curva_pv(cenarios{n, 1}, T, p);
    cor = cores(n, :);

    subplot(1, 2, 1); hold on;
    plot(c.V, c.I, 'Color', cor, 'LineWidth', 1.5, 'DisplayName', cenarios{n, 2});

    subplot(1, 2, 2); hold on;
    plot(c.V, c.P, 'Color', cor, 'LineWidth', 1.5, 'DisplayName', cenarios{n, 2});
    plot(c.Vmp, c.Pmp, 'o', 'Color', cor, 'MarkerFaceColor', cor, ...
        'HandleVisibility', 'off');

    fprintf('\n== %s ==\n', cenarios{n, 2});
    fprintf('Maximo global: %.1f W em %.2f V\n', c.Pmp, c.Vmp);
    disp(c.picos);
end

subplot(1, 2, 1); grid on; xlabel('V [V]'); ylabel('I [A]'); title('Curva I-V');
legend('Location', 'southwest');
subplot(1, 2, 2); grid on; xlabel('V [V]'); ylabel('P [W]'); title('Curva P-V (o = maximo global)');
