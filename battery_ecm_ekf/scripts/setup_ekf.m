
function setup_ekf(varargin)
% setup_ekf (minimal, version-safe)
% Upserts EKF tuning params and OCV slope into the existing DD.
% Reads OCV_SOC_bp (percent) and OCV_lut (volts) from DD (written by setup_ecm).
%
% Name-Value:
%   'ddPath'   : dictionary path (default 'mdl/ecm_dd.sldd')
%   'Q_proc'   : SOC process variance        (default 1e-6)
%   'R_meas'   : voltage measurement var     (default 9e-4)      % <-- unchanged default
%   'H_min'    : Jacobian floor              (default 5e-5)
%   'soc_min'  : SOC clamp lower             (default 0.0)
%   'soc_max'  : SOC clamp upper             (default 1.0)
%   'SlopeMethod' : 'gradient' or 'pchip'    (default 'gradient')
%
% NOTE: Ts, Qn, soc0 are intentionally NOT set here (kept simple).
%       Ts comes from Script 3; Qn entered manually; initial SOC from Script 3.

p = inputParser; p.FunctionName = 'setup_ekf';
addParameter(p,'ddPath',      fullfile('mdl','ecm_dd.sldd'), @ischar);
addParameter(p,'Q_proc',      1e-8, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p,'R_meas',      (60e-2)^2, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p,'H_min',       5e-5, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p,'soc_min',     0.0,  @(x)isnumeric(x)&&isscalar(x));
addParameter(p,'soc_max',     1.0,  @(x)isnumeric(x)&&isscalar(x));
addParameter(p,'SlopeMethod', 'gradient', @(s)ischar(s)&&ismember(lower(s),{'gradient','pchip'}));
parse(p,varargin{:});

ddPath      = p.Results.ddPath;
Q_proc      = p.Results.Q_proc;
R_meas      = p.Results.R_meas;
H_min       = p.Results.H_min;
soc_min     = p.Results.soc_min;
soc_max     = p.Results.soc_max;
SlopeMethod = lower(p.Results.SlopeMethod);

% --- Open dictionary and read percent OCV entries ---
if ~isfile(ddPath)
    error('Data dictionary not found: %s. Run setup_ecm first.', ddPath);
end
dd   = Simulink.data.dictionary.open(ddPath);
sect = getSection(dd,'Design Data');

if ~ddHasEntry(sect,'OCV_SOC_bp') || ~ddHasEntry(sect,'OCV_lut')
    Simulink.data.dictionary.closeAll;
    error('OCV_SOC_bp/OCV_lut not found. Ensure Script 1 wrote them.');
end
OCV_SOC_bp = getValue(getEntry(sect,'OCV_SOC_bp'));  % [%]
OCV_lut    = getValue(getEntry(sect,'OCV_lut'));     % [V]

% --- Compute slope with respect to FRACTIONAL SOC ---
Voc_bp_frac = (OCV_SOC_bp(:).')/100;   % row, fractional SOC [0..1]
Voc_tab     = OCV_lut(:).';            % row, volts
assert(all(diff(Voc_bp_frac)>0), 'OCV_SOC_bp must be strictly increasing.');

switch SlopeMethod
    case 'gradient'
        dVoc_dSOC = gradient(Voc_tab, Voc_bp_frac);    % [V per fractional SOC]
    case 'pchip'
        pp        = pchip(Voc_bp_frac, Voc_tab);
        dVoc_dSOC = ppval(fnder(pp,1), Voc_bp_frac);   % [V per fractional SOC]
end

% --- Apply Jacobian floor here (pre-store)
dVoc_dSOC = max(dVoc_dSOC, H_min);     % element-wise floor

% --- Upsert minimal EKF entries (no delete/recreate) ---
ddUpsert(sect,'OCV_dVoc_dSOC', dVoc_dSOC);  % pre-floored slope aligned to OCV_SOC_bp
ddUpsert(sect,'Q_proc',         Q_proc);
ddUpsert(sect,'R_meas',         R_meas);
ddUpsert(sect,'H_min',          H_min);
ddUpsert(sect,'soc_min',        soc_min);
ddUpsert(sect,'soc_max',        soc_max);

saveChanges(dd);
Simulink.data.dictionary.closeAll;

end

% ======= Local helpers (version-safe) =======
function tf = ddHasEntry(sect, name)
% Return true if an entry exists in the section, false otherwise.
try
    getEntry(sect, name);
    tf = true;
catch
    tf = false;
end
end

function ddUpsert(sect, name, value)
% Set entry if exists; else create it.
try
    e = getEntry(sect, name);
    setValue(e, value);
catch
    addEntry(sect, name, value);
end
end
