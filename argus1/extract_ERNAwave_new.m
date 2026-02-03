function ERNA = extract_ERNAwave(cfg)



% get cfg fields
fname = cfg.fname; % filename
srate = cfg.srate; % sample frequency [hz]
flowcut = cfg.flowcut; % cut-off frequency low pass filter [Hz]
fhighcut = cfg.fhighcut; % cut-off frequency low pass filter [Hz]

annot = cfg.annot; % annot table
forder = cfg.forder; % order low pass filter [Hz]
task = cfg.task;
run_id = cfg.run_id;
detrend_type = cfg.detrend_type;
mask = cfg.mask.ibi.(task); % mask [ms]
wideband_mask = cfg.mask.ipi.wideband.wideband(ismember(cfg.mask.ipi.wideband.freq_stim,annot.Freq)); % mask [ms]

IPI = 1/annot.Freq; % inter-pulse interval


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

timeburst = timestamp2gtc(timeburst);
timeburst = filloutliers(timeburst,'linear');
stim_amp = filloutliers(stim_amp,'linear','movmedian',15);


% remove when stim_amp == 0
data = data(:,stim_amp > 0);
timeburst = timeburst(stim_amp > 0);
timeburst_copy = timeburst;
stim_amp = stim_amp(stim_amp > 0);
%stim_amp_copy = stim_amp;


% define time vector
[nsamples, nbursts] = size(data);
time_vect = timeburst + (0 : 1/srate : (nsamples - 1)/srate);
time_vect = time_vect';


% % check overlap vectors and vectorize
num_overlap = round((time_vect(end,1:(end-1)) - time_vect(1,2:end))*srate) + 1;
data_cont = [];
time_vect_cont = [];

for pi = 1 : (nbursts - 1)
    if num_overlap(pi) > 0
        data_cont = [data_cont; data(1 : (end - num_overlap(pi)),pi)];
        time_vect_cont = [time_vect_cont; time_vect(1 : (end - num_overlap(pi)),pi)];
    elseif num_overlap(pi) < 0
        data_cont = [data_cont; data(1 : end,pi); nan(abs(num_overlap(pi)),1)];
        time_vect_cont = [time_vect_cont; time_vect(:,pi); time_vect(end,pi) + 1/srate* (1 : abs(num_overlap(pi)))'];
    else
        data_cont = [data_cont; data(1 : end,pi)];
        time_vect_cont = [time_vect_cont; time_vect(:,pi)];
    end
    hold on
end
data_cont = [data_cont; data(:,end)]';
time_vect_cont = [time_vect_cont; time_vect(:,end)]';


%handle nan values
if any(isnan(data_cont))
    % perc_nanvalues(burst_i) = mean(isnan(data_tmp))*100;
    data_cont = fillmissing(data_cont,'linear');
end

% do filtering and preproc operations now
% low pass filter at 1000 Hz
fprintf('   Low-pass ButterWorth %d-th order filter %1.0f Hz \n', forder,flowcut)
[b,a] = butter(forder,flowcut/(srate/2),'low');
data_cont = filtfilt(b,a,data_cont);



% high pass filter
fprintf('   High-pass ButterWorth %d-th order filter %1.0f Hz \n', forder,fhighcut)
[b,a] = butter(forder,fhighcut/(srate/2),'high');
data_cont = filtfilt(b,a,data_cont);

% flip polarity
% range_end = [abs(min(data_cont(time_vect_cont >= timeburst(end - 20 + 1) & time_vect_cont <= timeburst(end)))) abs(max(data_cont(time_vect_cont >= timeburst(end - 20 + 1) & time_vect_cont <= timeburst(end))))];
% if range_end(1) > range_end(2)
%     data_cont = - data_cont;
%     flip_polarity = 1;
% else
%     flip_polarity = 0;
% end




% identify timepulses from stimulation
[~,locs] = findpeaks(zscore(diff(data_cont)),'MinPeakHeight',1,'MinPeakProminence',.5,'MinPeakDistance',round(IPI*1/2*srate)); % 50% of IPI as minimum MinPeak Distance
timepulses_from_stim = time_vect_cont(locs + 1);

% identify timepulses frm theoretical distance and known number of bursts (IPI)
timepulses = sort(reshape([timeburst - (0:9)*IPI]',1,[]));
timepulses = timepulses(timepulses >= time_vect_cont(1));

% remove last pulses after last timeburst
timepulses_from_stim = timepulses_from_stim(timepulses_from_stim < timeburst(end)); % remove pulses after last burst
timepulses = timepulses(timepulses <= (timeburst(end) + IPI/2)); % remove pulses after last burst

% adjust timepulses using timepulses_from_stim
timepulses_tmp = [];
for pulse_i = 1 : numel(timepulses)
    [k,dist] = dsearchn(timepulses_from_stim',timepulses(pulse_i));
    if dist >= 3/2*IPI % this pulse ahs not been identified by stim artefact
        local_span = time_vect_cont >= (timepulses(pulse_i) - IPI/3) & time_vect_cont <= (timepulses(pulse_i) + IPI/3);
        time_span = time_vect_cont(local_span);
        [maxl,idx_maxl] = max(data_cont(local_span));
        if maxl > data_cont(dsearchn(time_vect_cont',timepulses(pulse_i))) % need to adjust to local peak?
            timepulses_tmp = [timepulses_tmp time_span(idx_maxl)];
        else % just put timepulses
            timepulses_tmp = [timepulses_tmp timepulses(pulse_i)];
        end
    else % use timepusles_from_stim
         %timepulses_tmp = [timepulses_tmp timepulses_from_stim(k)];
         timepulses_tmp = [timepulses_tmp timepulses_from_stim(k)];
    end
end

%assert(numel(unique(timepulses_tmp)) == numel(timepulses_tmp),"Multiple timepulses are mapped onto the same timestamp: please check!")
if ~(numel(unique(timepulses_tmp)) == numel(timepulses_tmp))
    warning("Multiple timepulses are mapped onto the same timestamp: please check!")
end
timepulses = unique(timepulses_tmp);

%timepulses_from_stim = timepulses_from_stim(timepulses_from_stim > (timeburst(1) - 9*IPI - 0.0001)); % remove pulses before first burst



%timepulses = [timeburst(1)' timepulses]; % skip first

% adjust estimation
% timepulses = timepulses(timepulses > (timeburst(1) - 9*IPI - 0.0001)); % remove pulses before first burst
% timepulses = unique(timepulses_from_stim(dsearchn(timepulses_from_stim',timepulses')));

%timeburst(timeburst <= timepulses(1) & timeburst >= timepulses(end)) = [];


burst_mode = cfg.annot.Burst_mode;

if burst_mode
    %timepulses(timepulses > timeburst(end) & timepulses < timeburst(1)) = [];
    %timeburst(timeburst <= timepulses(1)) = [];

    %timeburst = timepulses(dsearchn(timepulses', timeburst));
%     timepulses = timepulses(timepulses <= timeburst(end)); % remove pulses after last burst
%     timepulses = timepulses(timepulses > (timeburst(1) - 9*IPI - 0.0001)); % remove pulses before first burst
    stim_amp(timeburst <= timepulses(1)) = [];
    timeburst(timeburst <= timepulses(1)) = [];
   
    which_burst = nan(1,numel(timepulses));
    for pulse_i = 1 : numel(timepulses)
        if ~isempty(find(timeburst >= timepulses(pulse_i) ,1))
            which_burst(pulse_i) = find(timeburst >= timepulses(pulse_i) ,1);
        end
    end
    last_pulse =  [find(abs(diff(which_burst)) > 0) numel(which_burst)];
    first_pulse = [1 last_pulse(1: end-1) + 1];
else
    timeburst = [];
    which_burst = [];
    first_pulse = 1;
    last_pulse =  numel(timepulses);
end

npulses = numel(timepulses);
nbursts = numel(timeburst);



% calculate powespectrum
data_cont_notched = data_cont;
freq_notch = 60
    [b,a] = butter(1,(freq_notch + [-1 +1])/(srate/2) ,'stop');
    data_cont_notched = filtfilt(b,a,data_cont_notched);

[sxx, fxx, txx] = spectrogram((data_cont_notched),hanning(round(0.5*srate)),round(0.5*srate*.75),2^nextpow2(round(1*srate)),srate);
sxx = abs(sxx);
figure
imagesc(txx,fxx,10*log10(sxx))
colorbar
ylim([1 500])
clim([0 60])
set(gca,'YDir','normal')



figure
plot(fxx,mean(sxx,2,'omitnan'))
xlim([200 500])







fprintf('   # samples: %d \n',nsamples)
if burst_mode
    fprintf('   # bursts: %d \n',nbursts)
else
    fprintf('   # pulses: %d \n',nbursts)
end

fprintf('   Done. OK! \n\n')


%% loop over pulses remembering that every ten pulses you have a burst


pulses_trial = [];
pulses_time = [];
bursts_trial = [];
bursts_time = [];


if burst_mode
    stim_amp_bursts = stim_amp;
else
    stim_amp_bursts = [];
    %stim_amp_pulses = stim_amp;
end
stim_amp_pulses = nan(1,npulses);

for pulse_i = 1 : npulses
    %burst_i =  which_burst(pulse_i);
    if mod(pulse_i,500) == 0
        fprintf(' Running pulse %d - %d [%1.2f%%] \n',pulse_i,npulses,pulse_i/npulses*100);
    end
    % mask your signal and adjust time duplicates if there are
    if ismember(pulse_i, last_pulse)
        idx_mask = time_vect_cont >= (timepulses(pulse_i) + mask(1)*1E-3) & time_vect_cont <=  (timepulses(pulse_i) + mask(2)*1E-3);
    else
%         idx_mask = time_vect_cont >= (timepulses(pulse_i) + mask(1)*1E-3) & time_vect_cont <=  (timepulses(pulse_i) + IPI - 0.0001);
        idx_mask = time_vect_cont >= (timepulses(pulse_i) + mask(1)*1E-3) & time_vect_cont <=  (timepulses(pulse_i) + wideband_mask*1E-3);

    end
    data_mask = data_cont(idx_mask);
    time_mask = time_vect_cont(idx_mask);

    % adjust time vector
    [~,idx_sort] = sort(time_mask);
    data_mask = data_mask(idx_sort);
    time_mask = time_mask(idx_sort);
    % do detrending
    switch detrend_type
        case 'linear'
            data_mask = detrend(data_mask,1);
        case 'quad'
            data_mask = detrend(data_mask,2);
        case 'hpass'
            [b,a] = butter(2,2/(srate/2),'high');
            data_mask = filtfilt(b,a,data_mask);
    end
    % any nan values?
    % handle nan values
    if any(isnan(data_mask))
        %perc_nanvalues(burst_i) = mean(isnan(data_tmp))*100;
        data_mask = fillmissing(data_mask,'linear');
    end
    % append waveforms
    if  ismember(pulse_i, last_pulse) && burst_mode
        %RNA.bursts.trial(which_burst(pulse_i),) = data_mask;
        if which_burst(pulse_i)  == 1
            bursts_time = time_mask - timepulses(pulse_i);
        else
            if length(bursts_trial(end,:)) >=  length(data_mask) % need to cut it
                bursts_trial =  bursts_trial(:, 1 : length(data_mask));
            else
                data_mask =  data_mask(1 : size(bursts_trial,2));
            end
        end
        bursts_trial = [bursts_trial; data_mask];
        % narrow the window to save pulse anyway
        %idx_mask = time_mask >= (timepulses(pulse_i) + mask(1)*1E-3) & time_mask <= (timepulses(pulse_i) + IPI - 0.0001);
        idx_mask = time_mask >= (timepulses(pulse_i) + mask(1)*1E-3) & time_mask <= (timepulses(pulse_i) + wideband_mask*1E-3);

        %idx_mask = 1 : numel(data_mask);
        data_mask = data_mask(idx_mask);
        time_mask = time_mask(idx_mask);
    end
    % save pulse
    if pulse_i  == 1
        pulses_time = time_mask - timepulses(pulse_i);
    else
        if length(pulses_trial(end,:)) >=  length(data_mask) % need to cut it
            pulses_trial =  pulses_trial(:, 1 : length(data_mask));
        else
            data_mask =  data_mask(1 : size(pulses_trial,2));
        end
    end
    pulses_trial = [pulses_trial; data_mask];

    % save informationa about pulses stimulation if it is in burst_mode
    if burst_mode
        stim_amp_pulses(pulse_i) = stim_amp(which_burst(pulse_i));
    else
        stim_amp_pulses(pulse_i) = stim_amp(dsearchn(timeburst_copy,timepulses(pulse_i)));
    end


end


pulses_time = pulses_time(1 : size(pulses_trial,2));
if burst_mode
    bursts_time = bursts_time(1 : size(bursts_trial,2));
end
%     ERNA.pulses.time{1,pulse_i} = time_mask - timepulses(pulse_i);
%     ERNA.pulses.trial{1,pulse_i} = data_mask;
% STORE WAVEFORM
% % update annot to create annotation table
% fprintf(' Update annotation table and store results \n');
annot.starts = min(time_vect_cont);
annot.ends = max(time_vect_cont);
% store ERNA fields
if burst_mode
    ERNA.bursts.time = bursts_time;
    ERNA.bursts.trial = bursts_trial;
    ERNA.bursts.stim_amp = stim_amp_bursts;
end
ERNA.pulses.time = pulses_time;
ERNA.pulses.trial = pulses_trial;
ERNA.pulses.stim_amp = stim_amp_pulses;
%ERNA.stim_amp = stim_amp;
%ERNA.stim_amp_pulses = stim_amp_pulses;
ERNA.Nsamples = nsamples;
ERNA.Npulses = npulses;
ERNA.Nbursts = nbursts;
ERNA.timepulses = timepulses;
ERNA.timeburst = timeburst;
ERNA.last_pulse = last_pulse;
ERNA.first_pulse = first_pulse;
ERNA.which_burst = which_burst;
%ERNA.flip_polarity = flip_polarity;
ERNA.burst_mode = burst_mode;
ERNA.run_id = run_id;
ERNA.annot = annot;


