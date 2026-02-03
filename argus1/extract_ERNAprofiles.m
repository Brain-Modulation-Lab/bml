function erna_act = extract_ERNAprofiles(cfg)


erna_annot = cfg.erna_annot;
%cfg.data =  data;
%cfg.time = time;
stim_vec = cfg.stim_vec; % E.stim_amp{run_i}
%cfg.timeburst = timeburst;
run_annot = cfg.run_annot;


if isfield(cfg,'properties') % amplitude, frequency, latency, damping, ncycles ...
    properties = cfg.properties;
else % default
    properties = {'amplitude'};
end

if isfield(cfg,'norm_flag')
    norm_flag = cfg.norm_flag;
else % default
    norm_flag = false;
end
if norm_flag
    if isfield(cfg,'type_norm')
        type_norm = cfg.type_norm;
    else % default
        type_norm = 'min-max';
    end
end


nRuns = height(run_annot);
bursts_tmp = cell(1,nRuns);

erna_act = struct();

burst_max = 1;

for run_i = 1 : nRuns
    %fprintf(' Printing ERNA figures for StimScan run %d - %d [%1.2f%%] \n',run_i, nRuns, run_i/nRuns*100)
    run = run_annot.Run(run_i);
    stim_run = run_annot.Amp(run_i); %3.5 mA most of the time accoridng to protocol
    erna_properties_run = erna_annot(erna_annot.run_id == run,:);

    stim_vec_run = filloutliers(stim_vec{run_i},'previous','movmedian',4);

    % get 1st burst with steady amp
    burst_ref = find(stim_vec_run == stim_run,1);

    if ~isempty(burst_ref)

        % get only burst at the steady value of amplitude
        erna_properties_run_ofint = erna_properties_run(erna_properties_run.stim_amp == stim_run,:);

        % get burst_id and erna ampltide
        bursts_tmp{run_i} = (erna_properties_run_ofint.burst_id - burst_ref) + 1; % corrected by first burst

        % save some info
        erna_act.run_id(run_i) = run;
        erna_act.burst_ref(run_i) = burst_ref;

        % update max
        if numel(bursts_tmp{run_i}) > 0
            if burst_max < max(bursts_tmp{run_i})
                burst_max = max(bursts_tmp{run_i});
            end
        end
    end


end

bursts = 1 : burst_max;

erna_act.bursts = bursts;
erna_act.norm_flag = norm_flag;
erna_act.properties = properties;

if norm_flag
    erna_act.type_norm = type_norm;
end



for run_i = 1 : nRuns
    %fprintf(' Printing ERNA figures for StimScan run %d - %d [%1.2f%%] \n',run_i, nRuns, run_i/nRuns*100)
    run = run_annot.Run(run_i);
    erna_properties_run = erna_annot(erna_annot.run_id == run,:);
    % get only burst at the steady value of amplitude
    erna_properties_run_ofint = erna_properties_run(erna_properties_run.stim_amp == stim_run,:);

    for prop_i = 1 : numel(properties)
        erna_property_tmp = erna_properties_run_ofint.(properties{prop_i});
        erna_act.(properties{prop_i}).profile(run_i,:) = nan(1,numel(bursts));
        erna_act.(properties{prop_i}).profile(run_i,ismember(bursts,bursts_tmp{run_i})) = erna_property_tmp;
        if numel(erna_property_tmp) >= 10
            [erna_act.(properties{prop_i}).min(run_i),idx_min] = min(erna_property_tmp,[],'omitnan');
            [erna_act.(properties{prop_i}).max(run_i),idx_max] = max(erna_property_tmp,[],'omitnan');
            erna_act.(properties{prop_i}).mean(run_i) = mean(erna_property_tmp,'omitnan');
            erna_act.(properties{prop_i}).std(run_i) = std(erna_property_tmp,[],'omitnan');
            erna_act.(properties{prop_i}).argburstmin(run_i) = bursts_tmp{run_i}(idx_min);
            erna_act.(properties{prop_i}).argburstmax(run_i) = bursts_tmp{run_i}(idx_max);
            erna_act.(properties{prop_i}).steady(run_i) = mean(erna_property_tmp((end - 10 + 1) : end),'omitnan');            

            if norm_flag
                switch type_norm
                    case 'min-max'
                        erna_act.(properties{prop_i}).profile_norm(run_i,:) = erna_act.(properties{prop_i}).profile(run_i,:)/erna_act.(properties{prop_i}).max(run_i);
                    case 'z-score'
                        erna_act.(properties{prop_i}).profile_norm(run_i,:) = (erna_act.(properties{prop_i}).profile(run_i,:) - erna_act.(properties{prop_i}).mean(run_i))/erna_act.(properties{prop_i}).std(run_i);
                end
            end
        end

        clear erna_property_tmp


    end


end
    
    
    
  


