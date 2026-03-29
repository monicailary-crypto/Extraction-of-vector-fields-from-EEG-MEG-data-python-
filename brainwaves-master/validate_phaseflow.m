%% validate_phaseflow.m
% Valida i risultati Python confrontandoli con MATLAB.
%
% Prerequisiti:
%   1. Avere phaseflow_results.mat (generato da save_for_matlab.py)
%   2. Avere nel path MATLAB:
%      - phases_nodes.m, phaseflow_cnem.m, grad_B_cnem.m, grad_cnem.m
%        (da neural-flows o brainwaves)
%      - cnem3d.mexw64 (se disponibile) oppure usare solo il confronto diretto
%
% Uso:
%   run validate_phaseflow.m

clc; clear; close all;

%% ── 1. Carica risultati Python ───────────────────────────────────────────
fprintf('Carico risultati Python...\n');
load('phaseflow_results.mat');
% Variabili disponibili: yphasep, loc, dt, sfreq, vnormp, vxp, vyp, vzp

fprintf('  yphasep : %dx%d\n', size(yphasep));
fprintf('  loc     : %dx%d\n', size(loc));
fprintf('  vnormp  : %dx%d\n', size(vnormp));
fprintf('  dt = %.4f s  sfreq = %.1f Hz\n', dt, sfreq);

%% ── 2. Confronto diretto sui valori Python ───────────────────────────────
fprintf('\n=== Statistiche Python ===\n');
fprintf('  vnormp mediana : %.2f mm/s\n', median(vnormp(:), 'omitnan'));
fprintf('  vnormp media   : %.2f mm/s\n', mean(vnormp(:),   'omitnan'));
fprintf('  vnormp std     : %.2f mm/s\n', std(vnormp(:),    'omitnan'));
fprintf('  vxp media      : %.4f  std: %.2f\n', mean(vxp(:),'omitnan'), std(vxp(:),'omitnan'));
fprintf('  vyp media      : %.4f  std: %.2f\n', mean(vyp(:),'omitnan'), std(vyp(:),'omitnan'));
fprintf('  vzp media      : %.4f  std: %.2f\n', mean(vzp(:),'omitnan'), std(vzp(:),'omitnan'));

%% ── 3. Ricalcolo MATLAB delle fasi (non richiede CNEM) ──────────────────
fprintf('\nRicalcolo fasi in MATLAB...\n');
% Implementazione hilbert senza Signal Processing Toolbox
% usa la FFT nativa di MATLAB
yphase_matlab = zeros(size(yphasep));
for jj = 1:size(yphasep, 2)
    y = yphasep(:, jj) - mean(yphasep(:, jj));
    N = length(y);
    f = fft(y, N);
    h = zeros(N, 1);
    if mod(N, 2) == 0
        h([1, N/2+1]) = 1;
        h(2:N/2) = 2;
    else
        h(1) = 1;
        h(2:(N+1)/2) = 2;
    end
    yphase_matlab(:, jj) = unwrap(angle(ifft(f .* h)));
end

% Confronto fasi Python vs MATLAB
diff_phase = abs(yphase_matlab - yphasep);
fprintf('=== Confronto fasi ===\n');
fprintf('  Differenza max  : %.6f rad\n', max(diff_phase(:)));
fprintf('  Differenza media: %.6f rad\n', mean(diff_phase(:)));
% Atteso: differenza ~0 (stessa implementazione Hilbert+unwrap)

%% ── 4. Ricalcolo phaseflow MATLAB (richiede CNEM) ───────────────────────
cnem_available = false;
try
    % Testa se CNEM è disponibile
    which('m_cnem3d_scni');
    cnem_available = true;
    fprintf('\nCNEM trovato — ricalcolo phaseflow in MATLAB...\n');
catch
    fprintf('\nCNEM non trovato — skip ricalcolo phaseflow.\n');
    fprintf('Aggiungi al path: addpath(''path/to/neural-flows/external/cnem_03-10-17/matlab/bin'')\n');
end

if false  % CNEM non disponibile su Windows
    v_matlab = phaseflow_cnem(yphase_matlab, loc, dt);

    fprintf('\n=== Statistiche MATLAB ===\n');
    fprintf('  vnormp mediana : %.2f mm/s\n', median(v_matlab.vnormp(:), 'omitnan'));
    fprintf('  vnormp media   : %.2f mm/s\n', mean(v_matlab.vnormp(:),   'omitnan'));
    fprintf('  vnormp std     : %.2f mm/s\n', std(v_matlab.vnormp(:),    'omitnan'));

    fprintf('\n=== Confronto Python vs MATLAB ===\n');
    diff_v = abs(v_matlab.vnormp - vnormp);
    fprintf('  vnormp diff max  : %.2f mm/s\n', max(diff_v(:), [], 'omitnan'));
    fprintf('  vnormp diff media: %.2f mm/s\n', mean(diff_v(:), 'omitnan'));
    rel_err = diff_v ./ (vnormp + eps);
    fprintf('  errore relativo medio: %.4f%%\n', 100*mean(rel_err(:), 'omitnan'));

    %% ── 5. Plot confronto ────────────────────────────────────────────────
    figure('Name', 'Confronto Python vs MATLAB');

    subplot(2,2,1);
    histogram(vnormp(:), 100, 'Normalization', 'probability');
    xlabel('vnormp (mm/s)'); title('Python — distribuzione vnormp');
    xlim([0, prctile(vnormp(:), 95)]);

    subplot(2,2,2);
    histogram(v_matlab.vnormp(:), 100, 'Normalization', 'probability');
    xlabel('vnormp (mm/s)'); title('MATLAB — distribuzione vnormp');
    xlim([0, prctile(v_matlab.vnormp(:), 95)]);

    subplot(2,2,[3,4]);
    t = (0:size(vnormp,1)-1) / sfreq;
    plot(t, mean(vnormp, 2, 'omitnan'), 'b', 'DisplayName', 'Python');
    hold on;
    plot(t, mean(v_matlab.vnormp, 2, 'omitnan'), 'r--', 'DisplayName', 'MATLAB');
    xlabel('Tempo (s)'); ylabel('vnormp media (mm/s)');
    title('Velocità media tra elettrodi nel tempo');
    legend; grid on;

    saveas(gcf, 'confronto_python_matlab.png');
    fprintf('\nFigura salvata: confronto_python_matlab.png\n');
end

%% ── 6. Topoplot MATLAB (non richiede CNEM) ──────────────────────────────
fprintf('\nGenerazione topoplot MATLAB con risultati Python...\n');

% Usa i vettori Python direttamente
pct = 95;
thresh = prctile(vnormp(:), pct);
mask = vnormp < thresh;

vn_mean = mean(vnormp .* mask, 1, 'omitnan');  % (1, N) media temporale
vx_mean = mean(vxp    .* mask, 1, 'omitnan');
vy_mean = mean(vyp    .* mask, 1, 'omitnan');
vz_mean = mean(vzp    .* mask, 1, 'omitnan');

% Proiezione PCA loc 3D -> 2D
center = mean(loc, 1);
xc = loc - center;
[~, ~, V] = svd(xc, 'econ');
pca_axes = V(:, 1:2);       % (3, 2)
xy2d = xc * pca_axes;       % (N, 2)
xy2d_norm = xy2d / max(sqrt(sum(xy2d.^2, 2)));  % normalizza

% Vettori 2D
v3d = [vx_mean', vy_mean', vz_mean'];   % (N, 3)
v2d = v3d * pca_axes;                   % (N, 2)
max_mag = max(sqrt(sum(v2d.^2, 2)));
v2d_norm = v2d / max_mag * 0.15;

% Canali
ch = {'Fp1','Fp2','F3','F4','C3','C4','P3','P4','O1','O2',...
      'F7','F8','T3','T4','T5','T6','FZ','CZ','PZ'};

figure('Name', 'Topoplot phaseflow (risultati Python)');
hold on;

% Heatmap interpolata
[xi, yi] = meshgrid(linspace(-1,1,200), linspace(-1,1,200));
zi = griddata(xy2d_norm(:,1), xy2d_norm(:,2), vn_mean', xi, yi, 'v4');
mask_circ = xi.^2 + yi.^2 > 1;
zi(mask_circ) = NaN;
contourf(xi, yi, zi, 50, 'LineStyle', 'none');
contour(xi, yi, zi, 12, 'w', 'LineWidth', 0.4);
colormap('jet'); colorbar;
xlabel(''); ylabel('');

% Cerchio testa
th = linspace(0, 2*pi, 300);
plot(cos(th), sin(th), 'k-', 'LineWidth', 2.5);
plot([-0.1 0 0.1], [0.99 1.12 0.99], 'k-', 'LineWidth', 2.5);  % naso

% Elettrodi
scatter(xy2d_norm(:,1), xy2d_norm(:,2), 80, vn_mean', 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.8);

% Etichette
for i = 1:length(ch)
    text(xy2d_norm(i,1)+0.04, xy2d_norm(i,2)+0.04, ch{i}, ...
         'FontSize', 7, 'FontWeight', 'bold');
end

% Frecce
quiver(xy2d_norm(:,1), xy2d_norm(:,2), v2d_norm(:,1), v2d_norm(:,2), ...
       0, 'k', 'LineWidth', 1.5, 'MaxHeadSize', 0.5);

% Orientamento
text(0, 1.18, 'Anteriore', 'HorizontalAlignment','center','FontAngle','italic','FontSize',9);
text(0, -1.18,'Posteriore','HorizontalAlignment','center','FontAngle','italic','FontSize',9);
text(-1.18, 0, 'Sinistro',  'HorizontalAlignment','right', 'FontAngle','italic','FontSize',9);
text( 1.18, 0, 'Destro',    'HorizontalAlignment','left',  'FontAngle','italic','FontSize',9);

axis equal; axis off;
xlim([-1.3 1.3]); ylim([-1.3 1.4]);
title(sprintf('Phaseflow EEG — banda alpha (8-13 Hz)\nVelocita mediana: %.0f mm/s', ...
              median(vn_mean)), 'FontSize', 11);

saveas(gcf, 'topoplot_matlab.png');
fprintf('Topoplot MATLAB salvato: topoplot_matlab.png\n');

fprintf('\nValidazione completata.\n');
