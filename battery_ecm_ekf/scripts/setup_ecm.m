
function setup_ecm()
% Ingest data and create LUTs + overwrite the data dictionary for the ECM model.
% Changes vs. your original:
%   - Adds crate_bp = [0, ...] so LUTs handle I = 0 A cleanly.
%   - Closes any open dictionaries/models referencing the dd and overwrites mdl/ecm_dd.sldd.

%% -----------------------------------------------
% 1) Read 2-RC ECM parameter table (SoC & C-rate surfaces)
% -----------------------------------------------
csvPath = fullfile('data','ecm_lookup_table.csv');  % columns: SOC, C_rate, R0,R1,C1,R2,C2
assert(isfile(csvPath), 'CSV not found: %s', csvPath);
ecm = readtable(csvPath);

% Required columns check
req = {'SOC','C_rate','R0','R1','C1','R2','C2'};
for k = 1:numel(req)
    assert(ismember(req{k}, ecm.Properties.VariableNames), ...
        'CSV missing column: %s', req{k});
end

soc_raw   = ecm.SOC(:);
crate_raw = ecm.C_rate(:);
R0_raw    = ecm.R0(:);
R1_raw    = ecm.R1(:);
C1_raw    = ecm.C1(:);
R2_raw    = ecm.R2(:);
C2_raw    = ecm.C2(:);

% Build interpolants (SoC, C-rate) -> parameter
F_R0 = scatteredInterpolant(soc_raw, crate_raw, R0_raw, 'linear','nearest');
F_R1 = scatteredInterpolant(soc_raw, crate_raw, R1_raw, 'linear','nearest');
F_C1 = scatteredInterpolant(soc_raw, crate_raw, C1_raw, 'linear','nearest');
F_R2 = scatteredInterpolant(soc_raw, crate_raw, R2_raw, 'linear','nearest');
F_C2 = scatteredInterpolant(soc_raw, crate_raw, C2_raw, 'linear','nearest');

% Breakpoints (keep SoC as before; prepend 0 to C-rate)
soc_bp = linspace(min(soc_raw), max(soc_raw), 101);

crate_lo     = max(1e-3, min(crate_raw));     % original lower bound
crate_hi     = max(crate_raw);
crate_bp_core = linspace(crate_lo, crate_hi, 81);
crate_bp      = [0, crate_bp_core];           % <-- add 0 C-rate
crate_bp      = unique(crate_bp(:).','stable');  % ensure strictly increasing unique

% Evaluate surfaces on the grid
[Sg, Cg] = ndgrid(soc_bp, crate_bp);
R0_lut = F_R0(Sg, Cg);
R1_lut = F_R1(Sg, Cg);
C1_lut = F_C1(Sg, Cg);
R2_lut = F_R2(Sg, Cg);
C2_lut = F_C2(Sg, Cg);

%add SOC-OCV LUT
OCV_SOC_bp = [2.5,5,10,15,20,30,40,50,60,70,80,90,95,100];
OCV_lut = [3.077,3.1749,3.1967,3.2132,3.2338,3.2636,3.2838,3.286,3.2892,3.3039,3.3274,3.3292,3.3316,3.4469];

%% -----------------------------------------------
% 2) Safely overwrite Simulink Data Dictionary
% -----------------------------------------------
ddPath = fullfile('mdl','ecm_dd.sldd');

% Close any open dictionaries and models that reference this dd
try
    % Close Data Dictionary Editor instances and dd handles
    Simulink.data.dictionary.closeAll;
catch
end

% Close any loaded model that is linked to this dd (prevents file locks)
try
    mdlList = find_system('Type','block_diagram');
    for i = 1:numel(mdlList)
        try
            if strcmp(get_param(mdlList{i}, 'DataDictionary'), ddPath)
                save_system(mdlList{i});
                close_system(mdlList{i}, 0);  % close without saving again
            end
        catch
            % ignore if property not available or model not linked
        end
    end
catch
end

% Now delete and recreate the dictionary file
if isfile(ddPath)
    delete(ddPath);
end
Simulink.data.dictionary.create(ddPath);

% Open fresh dictionary and write entries
dd   = Simulink.data.dictionary.open(ddPath);
sect = getSection(dd,'Design Data');

addEntry(sect,'soc_bp',   soc_bp);
addEntry(sect,'crate_bp', crate_bp);
addEntry(sect,'R0_lut',   R0_lut);
addEntry(sect,'R1_lut',   R1_lut);
addEntry(sect,'C1_lut',   C1_lut);
addEntry(sect,'R2_lut',   R2_lut);
addEntry(sect,'C2_lut',   C2_lut);
addEntry(sect,'OCV_SOC_bp',   OCV_SOC_bp);
addEntry(sect,'OCV_lut',   OCV_lut);

saveChanges(dd);
% fprintf('✅ Data dictionary overwritten at %s\n', ddPath);
% fprintf('soc_bp:   N=%d  range [%.4f .. %.4f]\n', numel(soc_bp), soc_bp(1), soc_bp(end));
% fprintf('crate_bp: N=%d  range [%.6f .. %.6f] (includes 0)\n', numel(crate_bp), crate_bp(1), crate_bp(end));
% fprintf('LUT sizes: R0=%dx%d, R1=%dx%d, C1=%dx%d, R2=%dx%d, C2=%dx%d\n', ...
%     size(R0_lut,1), size(R0_lut,2), ...
%     size(R1_lut,1), size(R1_lut,2), ...
%     size(C1_lut,1), size(C1_lut,2), ...
%     size(R2_lut,1), size(R2_lut,2), ...
%     size(C2_lut,1), size(C2_lut,2));

% Optional: close the dd so next run starts clean
try
    Simulink.data.dictionary.closeAll;
catch
end
end

