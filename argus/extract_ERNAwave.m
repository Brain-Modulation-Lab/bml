function ERNA = extract_ERNAwave(cfg)



% get cfg fields
fname = cfg.fname; % filename
srate = cfg.srate; % sample frequency [hz]
fcut = cfg.flowcut; % cut-off frequency low pass filter [Hz]
forder = cfg.forder; % order low pass filter [Hz]
task = cfg.task;
run_id = cfg.run_id;
detrend_type = cfg.detrend_type;
mask = cfg.mask.(task); % mask [ms]

% plot_flag = cfg.plot_flag;
% save_plot_flag = cfg.save_plot_flag;
% manual_check = cfg.manual_check;
% PATIENT = cfg.patient;
% init output
ERNA = struct();

try
    x = readtable(fname); x = x{:,:};
    timeburst = x(:,1);
    data = x(:,20:end)';
    stim_amp = x(:,3);
catch
    x = importdata(fname); x = x.data;
    timeburst = x(:,1);
    data = x(:,20:end)';
    stim_amp = x(:,3);
end

fprintf('  Run %s. \n', task)
fprintf('  Extracting time, stimulation and ERNA data. \n')

% PREPROCESSING
% timeburst is in this format HHmmss.xxxx
% convert it into seconds from midnight of the same day

timeburst_gtc = timestamp2gtc(timeburst);
timeburst_rgtc = filloutliers(timeburst_gtc,'linear');

%plot(timeburst_gtc, timeburst_rgtc-timeburst_gtc)


% define time vector
[nsamples, nbursts] = size(data);
time_vect = timeburst_rgtc + (0 : 1/srate : (nsamples - 1)/srate);

fprintf('   # good waveforms: %d \n',nbursts)
fprintf('   # samples: %d \n',nsamples)
fprintf('   Done. OK! \n\n')

perc_nanvalues = zeros(nbursts,1);


y = []; %erna

% loop over bursts
for burst_i = 1 : nbursts
    
    fprintf(' Running burst %d-%d (stim: %1.2f mA & freq: %1.0f Hz) [%1.2f%%] \n', burst_i,nbursts, stim_amp(burst_i), cfg.annot.Freq, burst_i/nbursts*100);
   
    % mask the data around the IBI
    fprintf('   Masking around IBI. \n')

    tmask = (time_vect(burst_i,:) - timeburst_rgtc(burst_i)) <= mask(2)/1000 & (time_vect(burst_i,:) - timeburst_rgtc(burst_i)) >= mask(1)/1000;
    time = time_vect(burst_i,tmask);
    data_tmp = data(tmask,burst_i);
    time_rel = time - timeburst_rgtc(burst_i);

    % handle nan values
    if any(isnan(data_tmp))
        perc_nanvalues(burst_i,1) = mean(isnan(data_tmp))*100;
        data_tmp = fillmissing(data_tmp,'linear');
    end

    % low pass filter at 1000 Hz
    fprintf('   Low-pass ButterWorth %d-th order filter %1.0f Hz \n', forder,fcut)
    [b,a] = butter(forder,fcut/(srate/2),'low');
    data_tmp = filtfilt(b,a,data_tmp);

    % detrending
    switch detrend_type
        case 'linear'
            fprintf('   Liner detrending. \n')
            data_tmp = detrend(data_tmp,1);
            fprintf('   Done. OK! \n\n')

        case 'quad'
            fprintf('   Quad detrending. \n')
            data_tmp = detrend(data_tmp,2);
            fprintf('   Done. OK! \n\n')

        case 'hpass'
            fprintf('   High-pass filtering. \n')
            [b,a] = butter(2,2/(srate/2),'high');
            data_tmp = filtfilt(b,a,data_tmp);

        case 'exp'
            fprintf('   Exp. detrending. \n')
            model = fittype('a-b*exp(-c*x)');
            if all(~isnan(data_tmp))
                F= fit(time_rel',data_tmp,model,'StartPoint',[[ones(size(time_rel')), -exp(-time_rel')]\data_tmp; 1]);
                data_tmp = data_tmp - F(time_rel);
            end
    end
    

    try
        y = [y; data_tmp'];
    catch
        y = [y; data_tmp(1:size(y,2))'];
    end
    fprintf('   Done. OK! \n\n')

end


% update annot to create annotation table
fprintf(' Update annotation table and store results \n');
annot = cfg.annot;
annot.starts = min(time_vect(:));
annot.ends = max(time_vect(:));


% STORE WAVEFORM

% store ERNA fields
ERNA.time = time_rel;
ERNA.data = y;
ERNA.stim_amp = stim_amp;
ERNA.Nsamples = nsamples;
ERNA.Nbursts = nbursts;
%ERNA.task = task;
ERNA.timeburst = timeburst_rgtc;
ERNA.run_id = run_id;
ERNA.perc_nanvalues = perc_nanvalues;
% ERNA.burst_mode = annot.Burst_mode;
% ERNA.SenseP = string(annot.SenseP);
% ERNA.SenseN = string(annot.SenseN);
% ERNA.StimC = string(annot.StimC);
% ERNA.Side = string(annot.Side);
ERNA.annot = annot;
end
