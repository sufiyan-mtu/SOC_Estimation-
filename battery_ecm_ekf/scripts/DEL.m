
S = load('C:\Users\ahmeds28\Downloads\kalman\battery_ecm_ekf\data\10-25-19_11.29 960_WLTP206b.mat');
vars = fieldnames(S);
for k = 1:numel(vars)
    v = S.(vars{k});
    sheetName = matlab.lang.makeValidName(vars{k});
    if istable(v)
        writetable(v, 'all_vars.xlsx', 'Sheet', sheetName);
    elseif isnumeric(v) || islogical(v)
        writematrix(v, 'all_vars.xlsx', 'Sheet', sheetName);
    elseif isstruct(v)
        % Flatten simple struct-of-vectors into a table
        f = fieldnames(v);
        T = table();
        for j = 1:numel(f)
            col = v.(f{j});
            if isvector(col)
                T.(f{j}) = col;
            end
        end
        writetable(T, 'all_vars.xlsx', 'Sheet', sheetName);
    end
end
