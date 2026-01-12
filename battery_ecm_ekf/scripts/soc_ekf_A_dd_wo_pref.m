
function [soc_hat, P_out, K_out, innov] = soc_ekf_A_dd( ...
    Voc_meas, I_meas, Ts, Qn, eta, ...
    soc_prev, P_prev, ...
    OCV_SOC_bp, OCV_lut, OCV_dVoc_dSOC, ...
    Q_proc, R_meas, H_min, soc_min, soc_max)
% Hardened voltage-domain SOC EKF (Path-B).
% - Prefers prediction in pulses & OCV plateaus via R scheduling
% - NIS gating to skip outliers/transients
% - Trust region (±1% SOC/step) on correction to avoid jumps
% - Joseph-stabilized covariance (keeps P >= 0)
%
% Inputs (all via block ports; Option-A style):
%   Voc_meas       : de-polarized voltage [V] = V + v1 + v2 + R0*I_meas
%   I_meas         : current [A], discharge-positive convention
%   Ts             : sample time [s]
%   Qn             : nominal capacity [Ah]
%   eta            : Coulombic efficiency [0..1] (use 1.0 if you decided so)
%   soc_prev       : previous SOC estimate [0..1]
%   P_prev         : previous SOC covariance
%   OCV_SOC_bp     : [%] SOC breakpoints (strictly increasing), vector
%   OCV_lut        : [V] OCV values aligned with OCV_SOC_bp, vector
%   OCV_dVoc_dSOC  : [V per fractional SOC], aligned with OCV_SOC_bp, vector
%   Q_proc         : SOC process variance (per-step) [scalar]
%   R_meas         : base voltage measurement variance [scalar, V^2]
%   H_min          : minimum Jacobian (slope floor) [scalar, V/SOC]
%   soc_min/max    : clamp bounds [scalar]
%
% Outputs:
%   soc_hat        : updated SOC estimate
%   P_out          : updated SOC covariance (Joseph-stabilized)
%   K_out          : scalar Kalman gain (voltage-domain)
%   innov          : voltage innovation (Voc_meas - OCV(soc_pred))

% ----------------------------
% 0) Tunables for Path-B logic
% ----------------------------

alpha_R        = 0.10;   % inflate R with |I| (0.08–0.15 typical for “ignore measurement”)
alpha_plateau  = 2.0;    % inflate R when slope is small (1.5–3.0)
H_ref          = 0.03;   % reference slope [V per fractional SOC] (0.03–0.05)
nis_gate       = 2.71;   % ~90% chi-square gate (reject more often than 95%)
delta_cap      = 0.005;  % trust region: limit per-step SOC correction to ±0.5%

% ----------------------------
% 1) Prediction (coulomb count)
% ----------------------------
% NOTE: Qn in Ah -> convert via / (Qn*3600). With discharge-positive current,
% SOC must decrease under discharge.
soc_pred = soc_prev - (eta * Ts * I_meas) / (Qn * 3600);
soc_pred = min(max(soc_pred, soc_min), soc_max);

% If Q_proc is per-step, use as-is. If per-second, use Q_proc*Ts.
P_pred = P_prev + Q_proc;

% ----------------------------
% 2) OCV & slope lookup
% ----------------------------
% Convert breakpoints from percent to fractional SOC and clamp lookup
bp_frac = OCV_SOC_bp(:) / 100;    % [N x 1], fractional SOC
voc_tab = OCV_lut(:);             % [N x 1]
dH_tab  = OCV_dVoc_dSOC(:);       % [N x 1], V per fractional SOC

% Clamp SOC to the table's range for interpolation (avoid extrap artifacts)
soc_q = min(max(soc_pred, bp_frac(1)), bp_frac(end));

% 'linear' is MATLAB Function/codegen-safe; if sim-only, you may switch to 'pchip'
Voc_pred  = interp1(bp_frac, voc_tab, soc_q, 'linear');        % predicted voltage
dVoc_dSOC = interp1(bp_frac, dH_tab,  soc_q, 'linear');        % Jacobian (slope)

% Guard the slope
if ~isfinite(dVoc_dSOC)
    H = H_min;
else
    H = max(dVoc_dSOC, H_min);   % numerical floor only
end

% ----------------------------
% 3) R scheduling (prefer prediction in pulses & plateaus)
% ----------------------------
% Inflate measurement variance when |I| is large and when OCV slope is small.
R_eff = R_meas * (1 + alpha_R * abs(I_meas)) * (1 + alpha_plateau * (H_ref / H)^2);

% ----------------------------
% 4) Innovation, gain, gating
% ----------------------------
innov = Voc_meas - Voc_pred;              % voltage innovation, z - z_hat

S = H*H*P_pred + R_eff;                   % scalar innovation variance
if S < 1e-12, S = 1e-12; end

K = (P_pred * H) / S;                     % voltage-domain gain

% NIS gating (skip update when innovation is statistically unlikely)
NIS = (innov * innov) / S;                % chi-square, 1 dof
if NIS > nis_gate
    K = 0.0;                              % trust prediction only this sample
end

% ----------------------------
% 5) Update with trust region
% ----------------------------
delta  = K * innov;                       % SOC correction (via voltage-domain gain)
% Limit correction to ±delta_cap per step to avoid large jumps
if delta >  delta_cap, delta =  delta_cap; end
if delta < -delta_cap, delta = -delta_cap; end

soc_hat = soc_pred + delta;
soc_hat = min(max(soc_hat, soc_min), soc_max);

% Joseph-stabilized covariance (keeps P non-negative), using R_eff
P_out = (1 - K*H)^2 * P_pred + (K*K) * R_eff;

K_out = K;  % for logging/tuning
end
