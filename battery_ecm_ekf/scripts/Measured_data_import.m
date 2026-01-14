
%% 0) Load your MAT file
thisScript = mfilename('fullpath');              % full path to Measured_data_import.m
repoRoot   = fileparts(fileparts(thisScript));   % up one -> scripts/, up two -> repo root

% Pick your data file under /data
dataFile   = fullfile(repoRoot, 'data', '10-25-19_11.29 960_WLTP206b.mat');

% Load
S    = load(dataFile);
meas = S.meas;


%% 1) Clean time vector (strictly increasing) and start at t=0
t = meas.Time(:);                 % ensure column
% If time is not seconds, convert here; otherwise keep as is
t = t - t(1);                     % start at zero
[tu, idx] = unique(t,'stable');   % remove duplicates
I = meas.Current(idx);
V = meas.Voltage(idx);
% if isfield(meas,'Battery_Temp_degC'), Tbat = meas.Battery_Temp_degC(idx); end


%% 3) Compute sample time (for Discrete-Time Integrators)
Ts_data = median(diff(tu));
fprintf('Detected Ts ≈ %.6f s, duration = %.2f s, samples = %d\n', Ts_data, tu(end), numel(tu));

%% 4) Build timeseries for Simulink From Workspace blocks
I_A    = timeseries(I, tu);   I_A.Name    = 'I_A';
V_meas = timeseries(V, tu);   V_meas.Name = 'V_meas';

% Optional: set in base workspace if you run from a function/script
assignin('base','I_A',I_A);
assignin('base','V_meas',V_meas);
assignin('base','Ts_data',Ts_data);
%% 5) Guess initial SOC
OCV_SOC_bp = [2.5,5,10,15,20,30,40,50,60,70,80,90,95,100];
OCV_lut = [3.077,3.1749,3.1967,3.2132,3.2338,3.2636,3.2838,3.286,3.2892,3.3039,3.3274,3.3292,3.3316,3.4469];
% Assuming OCV_lut & ocv_soc_bp exist in your dictionary/base
SoC0_guess = interp1(OCV_lut, OCV_SOC_bp, V_meas.Data(1), 'linear','extrap');
assignin('base','SoC0_guess', SoC0_guess);
%% 
% set_param('ECM_EKF_WLTP','StopTime',num2str(I_A.Time(end)));


