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






annot = cfg.annot;





% PREPROCESSING
% timeburst is in this format HHmmss.xxxx
% convert it into seconds from midnight of the same day

timeburst = timestamp2gtc(timeburst);
timeburst = filloutliers(timeburst,'linear');

% handle nan
% topop = any(isnan(data));
% data(:,topop) = [];
% timeburst(topop) = [];
% stim_amp(topop) = [];


% define time vector
[nsamples, nbursts] = size(data);
time_vect = timeburst + (0 : 1/srate : (nsamples - 1)/srate);

fprintf('   # good waveforms: %d \n',nbursts)
fprintf('   # samples: %d \n',nsamples)
fprintf('   Done. OK! \n\n')

perc_nanvalues = zeros(1,nbursts);


y = []; %erna



% loop over bursts
for burst_i = 1 : nbursts
    
    fprintf(' Running burst %d-%d (stim: %1.2f mA & freq: %1.0f Hz) [%1.2f%%] \n', burst_i,nbursts, stim_amp(burst_i), cfg.annot.Freq, burst_i/nbursts*100);
   
    % mask the data around the IBI
    fprintf('   Masking around IBI. \n')

    tmask = (time_vect(burst_i,:) - timeburst(burst_i)) <= mask(2)/1000 & (time_vect(burst_i,:) - timeburst(burst_i)) >= mask(1)/1000;
    time = time_vect(burst_i,tmask);
    data_tmp = data(tmask,burst_i);
    time_rel = time - timeburst(burst_i);



    % handle nan values
    if any(isnan(data_tmp))
        perc_nanvalues(burst_i) = mean(isnan(data_tmp))*100;
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
ERNA.timeburst = timeburst;
ERNA.run_id = run_id;
ERNA.perc_nanvalues = perc_nanvalues;
% ERNA.burst_mode = annot.Burst_mode;
% ERNA.SenseP = string(annot.SenseP);
% ERNA.SenseN = string(annot.SenseN);
% ERNA.StimC = string(annot.StimC);
% ERNA.Side = string(annot.Side);
ERNA.annot = annot;
end


% function x_steady = get_steadyERNA(x, Nlast_bursts)
% if iscell(x.steady_bursts)
%     x_steady = [];
%     for i = 1 : numel(x.steady_bursts)
%         if isempty(Nlast_bursts)
%             x_steady = [x_steady  mean(x.data(:,x.steady_bursts{i}),2,'omitnan')];
%         else
%             try
%                 x_steady = [x_steady  mean(x.data(:,x.steady_bursts{i}((end - Nlast_bursts + 1) : (end))),2,'omitnan')];
%             catch
%                 x_steady = [x_steady  mean(x.data(:,x.steady_bursts{i}),2,'omitnan')];
%             end
% 
%         end
%     end
% else
%     if isempty(Nlast_bursts)
%         x_steady = mean(x.data(:,x.steady_bursts),2,'omitnan');
%     else
%         try
%             x_steady = mean(x.data(:,x.steady_bursts((end - Nlast_bursts + 1) : (end))),2,'omitnan');
%         catch
%             x_steady = mean(x.data(:,x.steady_bursts),2,'omitnan');
%         end
%     end
% end
% end
% 
% 
% 
% function [amplitude, latency, frequency] = get_ERNAtimeproperties(x,type)
% switch type
%     case 'steady'
%         x_steady = get_steadyERNA(x,10);
% 
%         amplitude = nan(1,size(x_steady,2));
%         latency = nan(1,size(x_steady,2));
%         frequency = nan(1,size(x_steady,2));
% 
%         for  i = 1 : size(x_steady,2)
%             [pks,pkslocs] = findpeaks(x_steady(:,i), x.time,'MinPeakWidth',0.0005,'MinPeakProminence',10);
%             pks(pkslocs < 0.002) = [];
%             pkslocs(pkslocs < 0.002) = [];
%             if numel(pks) > 1
%                 if pks(2) > pks(1)
%                     pks(1) = [];
%                     pkslocs(1) = [];
%                 end
%             end
%             [mpks,mpkslocs] = findpeaks(-x_steady(:,i), x.time,'MinPeakWidth',0.0005,'MinPeakProminence',10);
%             mpks = -mpks;
% 
%             if numel(pkslocs) >= 2 &&  numel(mpkslocs) >= 2 &&  pkslocs(1) > 0.002 && pkslocs(1) < 0.006
%                 if mpkslocs(1) > 0.004
%                     amplitude(i) = pks(1) - mpks(1);
%                 else
%                     amplitude(i) = pks(1) - mpks(2);
%                 end
%                 latency(i) = pkslocs(1);
%                 frequency(i) = 1/(pkslocs(2) - pkslocs(1));
%             else
%                 amplitude(i) = nan;
%                 latency(i) = nan;
%                 frequency(i) = nan;
%             end
%         end
% 
%         %if numel(pkslocs)
% 
%         % if manual_check
%         %     figure
%         %     plot(x.time,x_steady);
%         %     hold on
%         %     if numel(pkslocs) >= 2 && pkslocs(1) > 0.002 && pkslocs(1) < 0.006
%         %         scatter(pkslocs(1),pks(1),'o')
%         %         if mpkslocs(1) > 0.004
%         %             scatter(mpkslocs(1),mpks(1),'o')
%         %         else
%         %             scatter(mpkslocs(2),mpks(2),'o')
%         %         end
%         %         scatter(pkslocs(2),pks(2),'o')
%         %     end
%         %     opts.Interpreter = 'tex';
%         %     opts.Default = 'Yes';
%         %     answer = questdlg('Is this correct?','Correction',...
%         %         'Yes','Manual correction',opts);
%         %     if contains(answer,'Manual correction')
%         %         [a,b] = ginput(3);
%         %         amplitude = y(1) - y(2);
%         %         latency = x(1);
%         %         frequency = 1/(x(3) - x(1));
%         %     end
%         %     close gcf;
%         % end
% 
% 
% 
%     case 'dynamic'
%         if ~iscell(x.steady_bursts)
%             tmp = x.steady_bursts;
%             steady_bursts{1} = tmp;
%         else
%             steady_bursts = x.steady_bursts;
%         end
% 
%         amplitude = cell(1,numel(steady_bursts));
%         latency = cell(1,numel(steady_bursts));
%         frequency = cell(1,numel(steady_bursts));
% 
%         for  i = 1 : numel(steady_bursts)
%             nbursts = numel(steady_bursts{i});
%             amplitude{i} = nan(1,nbursts);
%             latency{i} = nan(1,nbursts);
%             frequency{i} = nan(1,nbursts);
%             for bb = 1 : nbursts
%                 data = x.data(:,steady_bursts{i}(bb));
%                 [pks,pkslocs] = findpeaks(data, x.time,'MinPeakWidth',0.0005,'MinPeakProminence',10);
%                 pks(pkslocs < 0.002) = [];
%                 pkslocs(pkslocs < 0.002) = [];
%                 if numel(pks) > 1
%                     if pks(2) > pks(1)
%                         pks(1) = [];
%                         pkslocs(1) = [];
%                     end
%                 end
%                 [mpks,mpkslocs] = findpeaks(-data, x.time,'MinPeakWidth',0.0005,'MinPeakProminence',10);
%                 mpks = -mpks;
%                 if numel(pkslocs) >= 2 &&  numel(mpkslocs) >= 2  && pkslocs(1) > 0.002 && pkslocs(1) < 0.006
% 
%                     if mpkslocs(1) > 0.004
%                         amplitude{i}(bb) = pks(1) - mpks(1);
%                     else
%                         amplitude{i}(bb) = pks(1) - mpks(2);
%                     end
%                     latency{i}(bb) = pkslocs(1);
%                     frequency{i}(bb) = 1/(pkslocs(2) - pkslocs(1));
%                 end
%                 % if manual_check
%                 %     figure
%                 %     plot(x.time,data);
%                 %     hold on
%                 %     if numel(pkslocs) >= 2 && pkslocs(1) > 0.002 && pkslocs(1) < 0.006
%                 %         scatter(pkslocs(1),pks(1),'o')
%                 %         if mpkslocs(1) > 0.004
%                 %             scatter(mpkslocs(1),mpks(1),'o')
%                 %         else
%                 %             scatter(mpkslocs(2),mpks(2),'o')
%                 %         end
%                 %         scatter(pkslocs(2),pks(2),'o')
%                 %     end
%                 %     opts.Interpreter = 'tex';
%                 %     opts.Default = 'Yes';
%                 %     answer = questdlg('Is this correct?','Correction',...
%                 %         'Yes','Manual correction',opts);
%                 %     if contains(answer,'Manual correction')
%                 %         [a,b] = ginput(3);
%                 %         amplitude(bb) = y(1) - y(2);
%                 %         latency(bb) = x(1);
%                 %         frequency(bb) = 1/(x(3) - x(1));
%                 %     end
%                 %     close gcf;
%                 % end
% 
%                 clear mpks mpkslocs pks pkslocs
%             end
%         end
% 
%         if numel(amplitude) == 1
%             amplitude = cell2mat(amplitude);
%             latency = cell2mat(latency);
%             frequency = cell2mat(frequency);
%         end
% end
% end