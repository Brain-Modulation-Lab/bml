function annot = bml_annot_detect_refactor(cfg, env)

    % DETECT_THRESHOLD_CROSSINGS identifies threshold crossings in a signal
    %
    % cfg.threshold - [lower_threshold, upper_threshold]
    % cfg.max_annots - maximum number of crossings per trial (default: inf)
    % cfg.minimum_pre_quiet - minimum time without signal being above threshold (default: 0)
    % cfg.trials - indices of trials to process (default: all trials)
    % cfg.timeeps - minimum time difference between crossings (default: 1e-9)
    %
    % env.trial - cell array of trials, each a matrix (channels x samples)
    % env.time - cell array of time vectors for each trial
    % env.label - cell array of channel labels
    % env.fsample - sampling frequency of the signal

    % Parameters from cfg
    threshold = cfg.threshold;
    max_annots = get_cfg_value(cfg, 'max_annots', inf);
    timeeps = get_cfg_value(cfg, 'timeeps', 1e-9);
    minimum_pre_quiet = get_cfg_value(cfg, 'minimum_pre_quiet', 0);
    trials = get_cfg_value(cfg, 'trials', 1:numel(env.trial));

    lower_threshold = threshold(1);
    upper_threshold = threshold(end);

    % Initialize result table
    annot = table();

    % Loop over trials
    for i = trials
        fprintf('Processing trial %d\n', i);

        trial_data = env.trial{i};  % Signal data (channels x samples)
        trial_time = env.time{i};  % Time vector (1 x samples)
        fsample = env.fsample;     % Sampling frequency

        % Loop over channels
        for l = 1:size(trial_data, 1)
            fprintf('  Channel %s\n', env.label{l});

            % Extract signal for current channel
            channel_data = trial_data(l, :);

            % Find threshold crossings where the signal rises above the threshold
            crossings = find(channel_data(1:end-1) < lower_threshold & channel_data(2:end) >= lower_threshold) + 1;

            % Initialize variables
            valid_starts = [];

            % Loop through crossings to identify valid ones
            for c_idx = crossings
                crossing_time = trial_time(c_idx);

                % Compute the time window for `minimum_pre_quiet`
                pre_quiet_start_time = crossing_time - minimum_pre_quiet;

                % Find indices corresponding to the quiet window
                if pre_quiet_start_time > trial_time(1)
                    pre_quiet_idx = trial_time >= pre_quiet_start_time & trial_time < crossing_time;
                    pre_quiet_signal = channel_data(pre_quiet_idx);
                else
                    pre_quiet_signal = [];  % If the window starts before the trial
                end

                % Check if the crossing is valid
                is_signal_below_threshold = isempty(pre_quiet_signal) || all(pre_quiet_signal < lower_threshold);

                if channel_data(c_idx) > upper_threshold && is_signal_below_threshold
                    % Check if time since last valid crossing is greater than timeeps
                    if isempty(valid_starts) || (crossing_time - valid_starts(end) >= timeeps)
                        valid_starts = [valid_starts; crossing_time];

                        % Limit number of annotations
                        if length(valid_starts) >= max_annots
                            break;
                        end
                    end
                end
            end

            % Append to the annotation table
            if ~isempty(valid_starts)
                new_rows = table(valid_starts, ...
                                 repmat(i, length(valid_starts), 1), ...
                                 repmat(env.label(l), length(valid_starts), 1), ...
                                 'VariableNames', {'starts', 'trial', 'channel'});
                annot = [annot; new_rows];
            end
        end
    end

    fprintf('Detection complete.\n');
end

% Helper function to get cfg values with default
function val = get_cfg_value(cfg, field, default)
    if isfield(cfg, field)
        val = cfg.(field);
    else
        val = default;
    end
end


