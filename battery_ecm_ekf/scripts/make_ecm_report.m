
function ecm_quick_simple()
% Minimal 2-figure ECM report from out.logsout
% Figure 1: V_meas vs V_ter, V_error (with max error marker), I_A, SOC_cc
% Figure 2: R0/R1/R2, C1 (own plane), C2 (own plane), Vrc1/Vrc2/V_R0, OCV vs V_ter

    % --- Get logsout ---
    if ~evalin('base','exist(''out'',''var'')')
        error('Base workspace must contain variable ''out'' (SimulationOutput).');
    end
    out  = evalin('base','out');
    if ~isprop(out,'logsout') || isempty(out.logsout)
        error('out.logsout is empty. Enable signal logging in your model.');
    end
    ds = out.logsout;

    % --- Pull signals (use your names; add aliases if needed) ---
    ts_Vm  = getTS(ds, {'V_meas'});      % measured voltage
    ts_Ve  = getTS(ds, {'V_ter','V_est'}); % estimated/terminal voltage
    ts_I   = getTS(ds, {'I_A'});         % current
    ts_SOC = getTS(ds, {'SOC_cc'});      % SOC
    ts_R0  = getTS(ds, {'R0'});
    ts_R1  = getTS(ds, {'R1'});
    ts_R2  = getTS(ds, {'R2'});
    ts_C1  = getTS(ds, {'C1'});
    ts_C2  = getTS(ds, {'C2'});
    ts_Vr1 = getTS(ds, {'Vrc1'});
    ts_Vr2 = getTS(ds, {'Vrc2'});
    ts_OCV = getTS(ds, {'OCV'});

    % --- Reference time: measured voltage if available, else current ---
    if ~isempty(ts_Vm), t = ts_Vm.Time(:); else, t = ts_I.Time(:); end

    % --- Resample to common time base (simple linear) ---
    Vm = toVec(ts_Vm,  t);
    Ve = toVec(ts_Ve,  t);
    I  = toVec(ts_I,   t);
    SOC= toVec(ts_SOC, t);
    R0 = toVec(ts_R0,  t);
    R1 = toVec(ts_R1,  t);
    R2 = toVec(ts_R2,  t);
    C1 = toVec(ts_C1,  t);
    C2 = toVec(ts_C2,  t);
    Vr1= toVec(ts_Vr1, t);
    Vr2= toVec(ts_Vr2, t);
    OCV= toVec(ts_OCV, t);

    % --- Error + max error ---
    Verr = Vm - Ve;
    [MaxAbsErr, idxMax] = max(abs(Verr));
    tMax  = t(idxMax);
    VerrM = Verr(idxMax);

    % --- V_R0 (series drop) if available ---
    if ~isempty(R0) && ~isempty(I), VR0 = R0 .* I; else, VR0 = []; end

    % ---------- Figure 1 ----------
    fig1 = figure('Name','ECM Simple – Fig1','Position',[100 100 1100 800],'Color','w');
    tl1 = tiledlayout(fig1,4,1,'TileSpacing','compact','Padding','compact');

    % (1) Measured vs Estimated (+ OCV if present)
    nexttile; hold on; grid on;
    plot(t, Vm, '-', 'DisplayName','V_{meas}');
    plot(t, Ve, '-', 'DisplayName','V_{ter}');
    if ~isempty(OCV), plot(t, OCV, '--', 'DisplayName','OCV'); end
    ylabel('Voltage [V]'); title('Measured vs Estimated Voltage'); legend('Location','best');

    % (2) Error with max marker
    nexttile; hold on; grid on;
    plot(t, Verr, '-', 'DisplayName','V_{error}');
    plot(tMax, VerrM, 'ro', 'MarkerSize', 6, 'LineWidth', 1.5, 'DisplayName','Max |error|');
    text(tMax, VerrM, sprintf('  %.3f V @ %.1f s', MaxAbsErr, tMax), 'Color','r','FontSize',10);
    ylabel('Error [V]'); title('Voltage Error (V_{meas} - V_{ter})'); legend('Location','best');

    % (3) Current
    nexttile; hold on; grid on;
    plot(t, I, '-', 'DisplayName','I_A');
    ylabel('Current [A]'); title('Current'); legend('Location','best');

    % (4) SOC
    nexttile; hold on; grid on;
    plot(t, SOC, '-', 'DisplayName','SOC_{cc}');
    ylabel('SOC'); xlabel('Time [s]'); title('SOC_{cc}'); legend('Location','best');

    % ---------- Figure 2 ----------
    fig2 = figure('Name','ECM Simple – Fig2','Position',[150 150 1100 1000],'Color','w');
    tl2 = tiledlayout(fig2,5,1,'TileSpacing','compact','Padding','compact');

    % (1) Resistances
    nexttile; hold on; grid on;
    plot(t, R0, '-', 'DisplayName','R0');
    plot(t, R1, '-', 'DisplayName','R1');
    plot(t, R2, '-', 'DisplayName','R2');
    ylabel('Resistance [\Omega]'); title('R0, R1, R2'); legend('Location','best');

    % (2) C1 (separate axis)
    nexttile; hold on; grid on;
    plot(t, C1, '-', 'DisplayName','C1');
    ylabel('C1 [F]'); title('C1'); legend('Location','best');

    % (3) C2 (separate axis)
    nexttile; hold on; grid on;
    plot(t, C2, '-', 'DisplayName','C2');
    ylabel('C2 [F]'); title('C2'); legend('Location','best');

    % (4) Polarizations: Vrc1 / Vrc2 / V_R0
    nexttile; hold on; grid on;
    if ~isempty(Vr1), plot(t, Vr1, '-', 'DisplayName','V_{rc1}'); end
    if ~isempty(Vr2), plot(t, Vr2, '-', 'DisplayName','V_{rc2}'); end
    if ~isempty(VR0), plot(t, VR0, '-', 'DisplayName','V_{R0}'); end
    ylabel('Voltage [V]'); title('V_{rc1}, V_{rc2}, V_{R0}'); legend('Location','best');

    % (5) OCV vs V_ter
    nexttile; hold on; grid on;
    if ~isempty(OCV), plot(t, OCV, '--', 'DisplayName','OCV'); end
    plot(t, Ve, '-', 'DisplayName','V_{ter}');
    ylabel('Voltage [V]'); xlabel('Time [s]');
    title('OCV vs V_{ter}'); legend('Location','best');

    % Done
    fprintf('Max|error| = %.4f V at t = %.3f s\n', MaxAbsErr, tMax);
end

% ===== Helpers (tiny & fast) =====
function ts = getTS(ds, nameList)
    ts = [];
    for k = 1:numel(nameList)
        try
            el = ds.getElement(nameList{k});
            if isa(el,'Simulink.SimulationData.Signal') && ~isempty(el.Values)
                ts = el.Values; return;
            end
        catch, end
    end
end

function x = toVec(ts, t_ref)
    if isempty(t_ref), x = []; return; end
    if isempty(ts),   x = nan(size(t_ref)); return; end
    x = interp1(ts.Time(:), ts.Data(:), t_ref, 'linear','extrap');
end
