function Tout = bml_argus_raw2table(argus_raw, opts)

arguments
  argus_raw
  opts.timetol (1,1) double = 1e-9;
end

% exporting waveforms as table
nRuns = numel(argus_raw.trial);
Tall = cell(nRuns,1);

% longest time vector
[~, iMax] = max(cellfun(@numel, argus_raw.time));
tMaster = argus_raw.time{iMax};

% prefix check with float tolerance
argus_raw_time = argus_raw.time(~cellfun('isempty', argus_raw.time));
if ~all(cellfun(@(x) max(abs(x - tMaster(1:numel(x)))) < opts.timetol, argus_raw_time))
  warning('Time Tolerance Violated');
end

time_ref = round(tMaster,9,'significant') * 1000; %ms
rawNames = "t_" + string(compose("%.3f", time_ref));
rawNames = replace(rawNames, ".", "ms");
rawNames = replace(rawNames, "-", "n");
dataVarNames = matlab.lang.makeValidName(rawNames);

for run_i = 1:nRuns
    run      = str2double(regexp(argus_raw.record_fname{1,run_i}, '(\d+)(?=(\.[^./\\]*)?$)', 'tokens', 'once'));  % digits before last ".ext" (or end)
    time     = argus_raw.time{1,run_i};        % 1 x N_times
    if isempty(time)
      continue
    end
    data     = argus_raw.trial{1,run_i};       % N_trial x N_time
    timeburst= argus_raw.timeburst{1,run_i};   % N_trial x 1
    stim_amp = argus_raw.stim_amp{1,run_i};    % N_trial x 1   (fix: stim_amp not srim_amp)

    nTrials = size(data, 1);
    nTimes = size(data,2);
    if nTimes < length(tMaster)
      data(:, end+1:length(tMaster)) = NaN;
    end
    T = array2table(data, "VariableNames", dataVarNames);
    T.run = repmat(run, nTrials, 1);
    T.starts = timeburst(:);
    T.ends = T.starts + time(end);
    T.stim_amp  = stim_amp(:);
    T = movevars(T, ["run","starts","stim_amp"], "Before", 1);
    Tall{run_i} = T;
end

Tout = vertcat(Tall{:});