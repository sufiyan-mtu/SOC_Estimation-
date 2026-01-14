
%% make_ecm_report.m

if ~exist('out','var') || ~isprop(out,'logsout') || isempty(out.logsout)
    error('make_ecm_report:MissingOut', ...
          'Variable ''out'' (SimulationOutput with logsout) not found or empty.');
end

ECM_report_from_logsout(out);   % local function below does everything


% ======================================================================
% Local function(s) live below. Requires R2016b+ for functions-in-scripts.
% ======================================================================
function ECM_report_from_logsout(out)
% Uses your exact logsout names:
%   Required:  V_meas, V_ter, I_A, SOC_cc
%   Optional:  OCV_cc, R0, R1, R2, C1, C2, Vrc1, Vrc2, Vr0
% Figures:
%   Fig 1: V_meas vs V_ter (+ OCV_cc), V_error (with max marker), I_A, SOC_cc
%   Fig 2: R0/R1/R2, C1, C2, Vrc1/Vrc2/V_R0, OCV_cc vs V_ter

ds = out.logsout;
interpMethod = 'linear';   % simple & stable

% ---- Pull signals (exact names; optional ones may be missing) ----
Vm   = mustGet(ds,'V_meas');      % measured voltage
Ve   = mustGet(ds,'V_ter');       % terminal/estimated voltage
I_A  = mustGet(ds,'I_A');         % current
SOC  = mustGet(ds,'SOC_cc');      % SOC (coulomb count)

OCV  = getOpt(ds,'OCV_cc');       % optional de-polarized OCV
R0   = getOpt(ds,'R0'); R1 = getOpt(ds,'R1'); R2 = getOpt(ds,'R2');
C1   = getOpt(ds,'C1'); C2 = getOpt(ds,'C2');
Vrc1 = getOpt(ds,'Vrc1'); Vrc2 = getOpt(ds,'Vrc2');
Vr0  = getOpt(ds,'Vr0');          % may be absent; if so we compute R0 .* I_A

% ---- Align everything to V_meas time base ----
t        = Vm.Time(:);
v_meas   = Vm.Data(:);
v_ter    = alignTo(Ve,  t, interpMethod);
i_a      = alignTo(I_A, t, interpMethod);
soc_cc   = alignTo(SOC, t, interpMethod);
ocv_cc   = alignTo(OCV, t, interpMethod);

r0       = alignTo(R0,  t, interpMethod);
r1       = alignTo(R1,  t, interpMethod);
r2       = alignTo(R2,  t, interpMethod);
c1       = alignTo(C1,  t, interpMethod);
c2       = alignTo(C2,  t, interpMethod);
vrc1     = alignTo(Vrc1,t, interpMethod);
vrc2     = alignTo(Vrc2,t, interpMethod);
vr0_sig  = alignTo(Vr0, t, interpMethod);

% If Vr0 not logged, compute V_R0 = R0 * I_A
if all(~isfinite(vr0_sig)) && any(isfinite(r0)) && any(isfinite(i_a))
    V_R0 = r0 .* i_a;
else
    V_R0 = vr0_sig;
end

% ---- Error & metrics (V_meas - V_ter) ----
Verr      = v_meas - v_ter;
finite    = isfinite(Verr);
tf        = t(finite); ef = Verr(finite);
dt        = median(diff(tf));
n         = numel(tf);
duration  = tf(end) - tf(1);
rmse      = sqrt(mean(ef.^2));
mae       = mean(abs(ef));
[maxAbsErr, idxMax] = max(abs(ef));
tMax      = tf(idxMax);
errAtMax  = ef(idxMax);
bias      = mean(ef);

% ====================== Figure 1 (visible) ======================
fig1 = figure('Name','ECM – Fig1','Position',[100 100 1100 800],'Color','w');
tl1  = tiledlayout(fig1,4,1,'TileSpacing','compact','Padding','compact');
try
    title(tl1,'ECM validation');   % R2020b+
catch
    sgtitle('ECM validation');
end

% (1) Measured vs Estimated (+ OCV_cc if available)
nexttile; hold on; grid on;
plot(t, v_meas,'k-','DisplayName','V_{meas}');
plot(t, v_ter, 'b-','DisplayName','V_{ter}');
if any(isfinite(ocv_cc))
    plot(t, ocv_cc,'--','Color',[0.2 0.6 0.2],'DisplayName','OCV_{cc}');
end
ylabel('Voltage [V]');
title(sprintf('Measured vs Estimated  |  RMSE=%.3f V, MAE=%.3f V, Max=%.3f V', rmse, mae, maxAbsErr));
legend('Location','best');

% (2) Error with max marker
nexttile; hold on; grid on;
plot(t, Verr,'r-','DisplayName','V_{error} = V_{meas} - V_{ter}');
plot(tMax, errAtMax,'ro','MarkerSize',6,'LineWidth',1.2,'DisplayName','Max |error|');
text(tMax, errAtMax, sprintf('  %.3f V @ %.1f s', maxAbsErr, tMax), 'Color','r','FontSize',10);
ylabel('Error [V]');
title(sprintf('Bias=%.3f V, dt≈%.4f s, n=%d', bias, dt, n));
legend('Location','best');

% (3) Current
nexttile; hold on; grid on;
plot(t, i_a,'-'); ylabel('Current [A]'); title('Current');

% (4) SOC
nexttile; hold on; grid on;
plot(t, soc_cc,'-'); ylabel('SOC'); xlabel('Time [s]'); title('SOC_{cc}');

% ====================== Figure 2 (visible) ======================
fig2 = figure('Name','ECM – Fig2','Position',[120 120 1100 1000],'Color','w');
tl2  = tiledlayout(fig2,5,1,'TileSpacing','compact','Padding','compact');
try
    title(tl2,'ECM validation');
catch
    sgtitle('ECM validation');
end

% (1) Resistances
nexttile; hold on; grid on;
plottedR = false;
if any(isfinite(r0)), plot(t, r0,'-','DisplayName','R0'); plottedR = true; end
if any(isfinite(r1)), plot(t, r1,'-','DisplayName','R1'); plottedR = true; end
if any(isfinite(r2)), plot(t, r2,'-','DisplayName','R2'); plottedR = true; end
ylabel('\Omega'); title('R0, R1, R2');
if plottedR, legend('Location','best'); end

% (2) C1
nexttile; hold on; grid on;
if any(isfinite(c1)), plot(t, c1,'-','DisplayName','C1'); end
ylabel('F'); title('C1'); legend('Location','best');

% (3) C2
nexttile; hold on; grid on;
if any(isfinite(c2)), plot(t, c2,'-','DisplayName','C2'); end
ylabel('F'); title('C2'); legend('Location','best');

% (4) Polarizations: Vrc1 / Vrc2 / V_R0
nexttile; hold on; grid on;
didPol = false;
if any(isfinite(vrc1)), plot(t, vrc1,'-','DisplayName','V_{rc1}'); didPol = true; end
if any(isfinite(vrc2)), plot(t, vrc2,'-','DisplayName','V_{rc2}'); didPol = true; end
if any(isfinite(V_R0)), plot(t, V_R0,'-','DisplayName','V_{R0}');   didPol = true; end
ylabel('Voltage [V]'); title('V_{rc1}, V_{rc2}, V_{R0}');
if didPol, legend('Location','best'); end

% (5) OCV_cc vs V_ter
nexttile; hold on; grid on;
if any(isfinite(ocv_cc)), plot(t, ocv_cc,'--','DisplayName','OCV_{cc}'); end
plot(t, v_ter, '-','DisplayName','V_{ter}');
ylabel('Voltage [V]'); xlabel('Time [s]');
title('OCV_{cc} vs V_{ter}'); legend('Location','best');

% ====================== Page 1: Summary (INVISIBLE, single axes) ======================
sumFig = figure('Name','ECM – Summary', ...
                'Position',[140 140 1100 800], ...
                'Color','w', ...
                'Visible','off', ...
                'HandleVisibility','off');
axS = axes('Parent',sumFig,'Units','normalized','Position',[0 0 1 1],'Visible','off');

x = 0.03; y = 0.95; dy = 0.08;
text(axS, x, y, 'ECM validation – Summary & Equations', ...
     'Interpreter','tex','FontSize',13,'FontWeight','bold','Units','normalized'); y = y - dy;

text(axS, x, y, sprintf('Duration: %.2f s    dt \\approx %.4f s    n = %d', duration, dt, n), ...
     'Interpreter','tex','FontSize',11,'Units','normalized'); y = y - dy;
text(axS, x, y, sprintf('RMSE = %.6f V    MAE = %.6f V    Max|err| = %.6f V @ %.3f s    Bias = %.6f V', ...
     rmse, mae, maxAbsErr, tMax, bias), 'Interpreter','tex','FontSize',11,'Units','normalized'); y = y - dy;

text(axS, x, y, 'Model & error definitions', ...
     'Interpreter','tex','FontSize',12,'FontWeight','bold','Units','normalized'); y = y - dy + 0.02;

eqLines = {
    '$V_{err}(t) = V_{meas}(t) - V_{ter}(t)$'
    '$\mathrm{RMSE} = \sqrt{\frac{1}{n} \sum_{i=1}^{n} V_{err,i}^{2}}$'
    '$\mathrm{MAE} = \frac{1}{n} \sum_{i=1}^{n} |V_{err,i}|$'
    '$\mathrm{Bias} = \frac{1}{n} \sum_{i=1}^{n} V_{err,i}$'
    '$V_{ter}(t) = OCV(SOC(t)) - R_{0}(t)\,I(t) - V_{rc1}(t) - V_{rc2}(t)$'
};
for k = 1:numel(eqLines)
    text(axS, x, y, eqLines{k}, 'Interpreter','latex','FontSize',12,'Units','normalized');
    y = y - 0.07;
end

y = y - 0.03;
present = @(v) any(isfinite(v));
sigLine = sprintf('OCV_{cc}: %s    R0: %s    R1: %s    R2: %s    C1: %s    C2: %s', ...
    tf2str(present(ocv_cc)), tf2str(present(r0)), tf2str(present(r1)), ...
    tf2str(present(r2)), tf2str(present(c1)), tf2str(present(c2)));
text(axS, x, y, sigLine, 'Interpreter','tex','FontSize',11,'Units','normalized'); y = y - dy + 0.02;
polLine = sprintf('V_{rc1}: %s    V_{rc2}: %s    V_{R0}: %s', ...
    tf2str(present(vrc1)), tf2str(present(vrc2)), tf2str(present(V_R0)));
text(axS, x, y, polLine, 'Interpreter','tex','FontSize',11,'Units','normalized');

drawnow;                        % ensure figures are fully rendered
set([sumFig, fig1, fig2], ...
    'InvertHardcopy','off', ...
    'PaperPositionMode','auto', ...
    'Renderer','opengl');       % robust for exportgraphics (avoid blank pages)

% ====================== Resolve <projectRoot>/results ======================
thisFile = mfilename('fullpath');
if isempty(thisFile)
    wf = which('make_ecm_report');
    if ~isempty(wf), thisFile = wf; else, thisFile = pwd; end
end
[thisDir, ~] = fileparts(thisFile);
[parentDir, last] = fileparts(thisDir);
if strcmpi(last,'scripts'), baseDir = parentDir; else, baseDir = thisDir; end
resultsDir = fullfile(baseDir,'results');
if ~exist(resultsDir,'dir'), mkdir(resultsDir); end
reportPath = fullfile(resultsDir, sprintf('ECM_report_%s.pdf', datestr(now,'yyyymmdd_HHMMSS')));

% ====================== Export 3 pages (no PNGs) ======================
try
    % Page 1: Summary page (hidden)
    exportgraphics(sumFig, reportPath, ...
                   'ContentType','image', ...
                   'BackgroundColor','white', ...
                   'Resolution',300);

    % Page 2: Fig1
    exportgraphics(fig1, reportPath, ...
                   'Append', true, ...
                   'ContentType','image', ...
                   'BackgroundColor','white', ...
                   'Resolution',300);

    % Page 3: Fig2
    exportgraphics(fig2, reportPath, ...
                   'Append', true, ...
                   'ContentType','image', ...
                   'BackgroundColor','white', ...
                   'Resolution',300);

    fprintf('ECM report written: %s\n', reportPath);
catch ME
    % No PNGs by request—surface the error only.
    warning('ECM 3-page report generation failed: %s', ME.message);
end

% Close hidden summary figure; keep Fig1 & Fig2 visible
if isgraphics(sumFig), close(sumFig); end

% ---- Console summary (informational only) ----
fprintf('ECM metrics (aligned to V_meas): RMSE=%.6f V, MAE=%.6f V, Max|err|=%.6f V @ %.3f s, Bias=%.6f V\n', ...
        rmse, mae, maxAbsErr, tMax, bias);
fprintf('dt=%.6f s, duration=%.2f s, n=%d\n', dt, duration, n);

end

% ----------------- local helpers (file-scope only) -----------------
function ts = mustGet(ds,name)
    try
        el = ds.getElement(name); ts = el.Values;
    catch
        error('make_ecm_report:MissingSignal','Required logsout signal not found: %s', name);
    end
end

function ts = getOpt(ds,name)
    try
        el = ds.getElement(name); ts = el.Values;
    catch
        ts = [];
    end
end

function x = alignTo(ts, t, method)
    if isempty(ts), x = nan(size(t)); return; end
    x = interp1(ts.Time(:), ts.Data(:), t, method, 'extrap');
end

function idx = nearestIdx(t, tval)
    [~, idx] = min(abs(t - tval));
end

function s = tf2str(tf)
    if tf, s = 'yes'; else, s = 'no'; end
end
