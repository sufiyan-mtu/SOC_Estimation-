
%% make_ekf_report.m
% One-call EKF validation script (no saving, logsout-only).
% Usage: run after simulation when 'out' (SimulationOutput) exists in base.

if ~exist('out','var') || ~isprop(out,'logsout') || isempty(out.logsout)
    error('make_ekf_report:MissingOut', ...
          'Variable ''out'' (SimulationOutput with logsout) not found or empty.');
end

EKF_report_from_logsout(out);   % local function below does everything


% ======================================================================
% Local function(s) live below. Requires R2016b+ for functions-in-scripts.
% ======================================================================
function EKF_report_from_logsout(out)
% Uses exact names from your logsout snapshot:
%   SOC_cc, SOC_kalman, V_error, Innov, K_out, P_out, V_meas
% (No OCV_cc or V_ter figure per request)

ds = out.logsout;
interpMethod = 'linear';   % simple & stable

% ---- Pull signals (exact names; optional ones may be missing) ----
SOC_ref = mustGet(ds,'SOC_cc');       % reference SoC (CC)
SOC_ekf = mustGet(ds,'SOC_kalman');   % EKF SoC
Verr    = mustGet(ds,'V_error');      % innovation / voltage residual
Innov   = getOpt(ds,'Innov');         % optional second innovation trace
Kout    = getOpt(ds,'K_out');         % optional Kalman gain
Pout    = getOpt(ds,'P_out');         % optional covariance (posterior in EKF math)
Vmeas   = getOpt(ds,'V_meas');        % optional V_meas for context

% ---- Align everything to SOC_cc time base ----
t        = SOC_ref.Time(:);
soc_ref  = SOC_ref.Data(:);
soc_ekf  = alignTo(SOC_ekf, t, interpMethod);
v_err    = alignTo(Verr,    t, interpMethod);
innov    = alignTo(Innov,   t, interpMethod);
k_out    = alignTo(Kout,    t, interpMethod);
p_out    = alignTo(Pout,    t, interpMethod);
v_meas   = alignTo(Vmeas,   t, interpMethod);

% ---- SoC metrics ----
e_soc      = soc_ekf - soc_ref;
finite_soc = isfinite(e_soc);
tf         = t(finite_soc); ef = e_soc(finite_soc);

% Robust seconds conversion for time metrics
if isduration(tf) || isdatetime(tf)
    dt_sec       = seconds(median(diff(tf)));
    duration_sec = seconds(tf(end) - tf(1));
else
    dt_sec       = median(diff(tf));
    duration_sec = tf(end) - tf(1);
end
n          = numel(tf);
soc_rmse   = sqrt(mean(ef.^2));
soc_mae    = mean(abs(ef));
[soc_maxAbsErr, idxMax] = max(abs(ef));
tMax_soc   = tf(idxMax);
% seconds for the max-error timestamp (relative to start)
if isduration(tf) || isdatetime(tf)
    tMax_sec = seconds(tMax_soc - tf(1));
else
    tMax_sec = tMax_soc - tf(1);
end
soc_bias   = mean(ef);

% ---- Innovation metrics (from V_error) ----
finite_v = isfinite(v_err);
v_rmse   = sqrt(mean(v_err(finite_v).^2));
v_bias   = mean(v_err(finite_v));

% ====================== Figure 1: SOC (VISIBLE) ======================
fig1 = figure('Name','EKF – Fig1 (SOC)','Color','w','Position',[140 120 1050 700]);
tl1  = tiledlayout(fig1,2,1,'TileSpacing','compact','Padding','compact');
try
    title(tl1,'EKF validation — SOC');  % R2020b+
catch
    sgtitle('EKF validation — SOC');    % fallback
end

% SOC traces
nexttile; hold on; grid on;
plot(t, soc_ref,'k-','DisplayName','SOC_{cc}');
plot(t, soc_ekf,'b-','DisplayName','SOC_{EKF}');
ylabel('SOC');
title(sprintf('EKF vs CC  |  RMSE=%.3f, MAE=%.3f, Max=%.3f', ...
      soc_rmse, soc_mae, soc_maxAbsErr));
legend('Location','best');

% SOC error
nexttile; hold on; grid on;
plot(t, e_soc,'r-','DisplayName','e_{SOC} = EKF - CC');
idxNear = nearestIdx(t, tMax_soc);
plot(t(idxNear), e_soc(idxNear),'ro','MarkerSize',6,'LineWidth',1.2,'DisplayName','Max |error|');
text(t(idxNear), e_soc(idxNear), sprintf('  %.3f @ %.1f s', soc_maxAbsErr, tMax_sec), ...
     'Color','r','FontSize',10);
ylabel('SOC error'); xlabel('Time [s]');
title(sprintf('Bias=%.3f, dt≈%.4f s, n=%d', soc_bias, dt_sec, n));
legend('Location','best');

% ================== Figure 2: Innovation/Gain (VISIBLE) ==================
fig2 = figure('Name','EKF – Fig2 (Innovation/Gain)','Color','w','Position',[160 140 1050 900]);
tl2  = tiledlayout(fig2,3,1,'TileSpacing','compact','Padding','compact');
try
    title(tl2,'EKF validation — Innovation & Gain');
catch
    sgtitle('EKF validation — Innovation & Gain');
end

% Innovations (V_error and optional Innov) + V_meas on right axis for context
nexttile; hold on; grid on;
plot(t, v_err,'m-','DisplayName','V\_error');
if any(isfinite(innov)), plot(t, innov,'c-','DisplayName','Innov'); end
ylabel('Innovation [V]');
if any(isfinite(v_meas))
    yyaxis right; plot(t, v_meas,'Color',[0.2 0.6 1],'DisplayName','V_{meas}'); ylabel('V_{meas} [V]');
    yyaxis left;
end
title(sprintf('Innovation | RMSE=%.3f V, Bias=%.3f V', v_rmse, v_bias));
legend('Location','best');

% Kalman gain
nexttile; hold on; grid on;
if any(isfinite(k_out))
    plot(t, k_out,'g-','DisplayName','K_{out}');
    ylabel('Kalman gain'); title('K_{out}');
    legend('Location','best');
else
    plot(t, nan(size(t)),'g-'); ylabel('Kalman gain'); title('K_{out} not logged'); legend('Location','best');
end

% Covariance plot (posterior covariance)
nexttile; hold on; grid on;
if any(isfinite(p_out))
    plot(t, p_out,'k-','DisplayName','P_{out}');
    ylabel('Covariance P_{out}');
    title('Covariance P_{out}');
else
    plot(t, nan(size(t)),'k-'); ylabel('Covariance P_{out}');
    title('P_{out} not logged');
end
xlabel('Time [s]'); legend('Location','best');

% ====================== Page 1: Summary (INVISIBLE, single axes) ======================
sumFig = figure('Name','EKF – Summary', ...
                'Position',[140 140 1100 800], ...
                'Color','w', ...
                'Visible','off', ...
                'HandleVisibility','off');
axS = axes('Parent',sumFig,'Units','normalized','Position',[0 0 1 1],'Visible','off');

% Text layout (robust; no tiledlayout to avoid space errors)
x = 0.03; y = 0.95; dy = 0.08;
text(axS, x, y, 'EKF validation — Summary & Equations', ...
     'Interpreter','tex','FontSize',13,'FontWeight','bold','Units','normalized'); y = y - dy;

text(axS, x, y, sprintf('Duration: %.2f s    dt \\approx %.4f s    n = %d', duration_sec, dt_sec, n), ...
     'Interpreter','tex','FontSize',11,'Units','normalized'); y = y - dy;
text(axS, x, y, sprintf('SOC: RMSE=%.6f, MAE=%.6f, Max|err|=%.6f @ %.1f s, Bias=%.6f', ...
     soc_rmse, soc_mae, soc_maxAbsErr, tMax_sec, soc_bias), ...
     'Interpreter','tex','FontSize',11,'Units','normalized'); y = y - dy;
text(axS, x, y, sprintf('Innovation: RMSE=%.6f V, Bias=%.6f V', v_rmse, v_bias), ...
     'Interpreter','tex','FontSize',11,'Units','normalized'); y = y - dy;

% EKF core equations (LaTeX)
text(axS, x, y, 'EKF equations', ...
     'Interpreter','tex','FontSize',12,'FontWeight','bold','Units','normalized'); y = y - dy + 0.02;

eqLines = {
    '$x_{k|k-1} = f\!\left(x_{k-1},\,u_k\right) + w_k$'
    '$P_{k|k-1} = A_k\,P_{k-1}\,A_k^{\top} + Q_k$'
    '$K_k = P_{k|k-1}\,H_k^{\top}\!\left(H_k\,P_{k|k-1}\,H_k^{\top} + R_k\right)^{-1}$'
    '$x_{k|k} = x_{k|k-1} + K_k\,\big(z_k - h\!\left(x_{k|k-1},\,u_k\right)\big)$'
    '$P_{k|k} = \left(I - K_k\,H_k\right) P_{k|k-1}$'
    '$\text{Innovation } \nu_k = z_k - h(x_{k|k-1},u_k)$'
};
for k = 1:numel(eqLines)
    text(axS, x, y, eqLines{k}, 'Interpreter','latex','FontSize',12,'Units','normalized');
    y = y - 0.07;
end

% Optional signals present
y = y - 0.03;
present = @(v) any(isfinite(v));
sigLine = sprintf('Signals present — Innov: %s    K_{out}: %s    P_{out}: %s    V_{meas}: %s', ...
    tf2str(present(innov)), tf2str(present(k_out)), tf2str(present(p_out)), tf2str(present(v_meas)));
text(axS, x, y, sigLine, 'Interpreter','tex','FontSize',11,'Units','normalized');

% ====================== Export 3-page PDF to <projectRoot>/results ======================
drawnow;                                     % ensure figures render
set([sumFig, fig1, fig2], 'Renderer','opengl', 'InvertHardcopy','off', 'PaperPositionMode','auto');

% Resolve results folder next to 'scripts'
thisFile = mfilename('fullpath');
if isempty(thisFile)
    wf = which('make_ekf_report');
    if ~isempty(wf), thisFile = wf; else, thisFile = pwd; end
end
[thisDir, ~] = fileparts(thisFile);
[parentDir, last] = fileparts(thisDir);
if strcmpi(last, 'scripts')
    baseDir = parentDir;    % project root (sibling of 'scripts')
else
    baseDir = thisDir;      % if structure differs, use this file's folder
end
resultsDir = fullfile(baseDir, 'results');
if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end

reportPath = fullfile(resultsDir, sprintf('EKF_report_%s.pdf', datestr(now,'yyyymmdd_HHMMSS')));

try
    % Page 1: Summary (hidden)
    exportgraphics(sumFig, reportPath, ...
                   'ContentType','image', 'BackgroundColor','white', 'Resolution',300);
    % Page 2: Fig1
    exportgraphics(fig1,   reportPath, ...
                   'Append', true, 'ContentType','image', 'BackgroundColor','white', 'Resolution',300);
    % Page 3: Fig2
    exportgraphics(fig2,   reportPath, ...
                   'Append', true, 'ContentType','image', 'BackgroundColor','white', 'Resolution',300);

    fprintf('EKF report written: %s\n', reportPath);
catch ME
    % Per request: no PNG fallbacks—surface error only
    warning('EKF 3-page report generation failed: %s', ME.message);
end

% Close hidden summary (keep visible figs on screen)
if isgraphics(sumFig), close(sumFig); end

% ---- Console summary (informational only) ----
fprintf('EKF vs CC (SOC): RMSE=%.6f, MAE=%.6f, Max|err|=%.6f @ %.1f s, Bias=%.6f\n', ...
        soc_rmse, soc_mae, soc_maxAbsErr, tMax_sec, soc_bias);
fprintf('Innovation: RMSE=%.6f V, Bias=%.6f V\n', v_rmse, v_bias);

end

% ----------------- local helpers (file-scope only) -----------------
function ts = mustGet(ds,name)
    try
        el = ds.getElement(name); ts = el.Values;
    catch
        error('make_ekf_report:MissingSignal','Required logsout signal not found: %s', name);
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
    % Robust nearest index for numeric, duration, or datetime time vectors
    if isduration(t) || isdatetime(t)
        tt = seconds(t - t(1));
        tv = seconds(tval - t(1));
    else
        tt = double(t);
        tv = double(tval);
    end
    [~, idx] = min(abs(tt - tv));
end

function s = tf2str(tf)
    if tf, s = 'yes'; else, s = 'no'; end
end
