function E = bml_read_argus1_records(argus1_data_path, srate)

RecordFiles = natsort(searchFilesForString(argus1_data_path, 'record','txt')); 

nRecordFiles = numel(RecordFiles);
if nRecordFiles > 0
    fprintf(' OK! Found %d RECORD files in %s. \n', nRecordFiles, argus1_data_path);
else
    warning(' No recordings for this patient. Check if the path is correct.')
end

E = [];

for record_i = 1:nRecordFiles
  fname = RecordFiles{record_i};
  [~,n,e]=fileparts(fname);
  fprintf(' Loading %s%s', n, e)
  try
      x = readtable(fname); 
      x = x{:,:};
      timeburst = x(:,1);
      data = x(:,20:end)';
      stim_amp = x(:,3);
  catch
      x = importdata(fname); 
      x = x.data;
      timeburst = x(:,1);
      data = x(:,20:end)';
      stim_amp = x(:,3);
  end

  % PREPROCESSING
  % timeburst is in this format HHmmss.xxxx
  % convert it into seconds from midnight of the same day  
  timeburst_gtc = timestamp2gtc(timeburst);
  timeburst_rgtc = filloutliers(timeburst_gtc,'linear');

  % define time vector
  [nsamples, nbursts] = size(data);
  time_vect = timeburst_rgtc + (0 : 1/srate : (nsamples - 1)/srate);
  perc_nanvalues = zeros(nbursts,1);

  fprintf(' with %d bursts. \n', nbursts)

  y = []; %erna
  for burst_i = 1 : nbursts

    time = time_vect(burst_i,:);
    data_tmp = data(:,burst_i);
    time_rel = time - timeburst_rgtc(burst_i);
    perc_nanvalues(burst_i,1) = mean(isnan(data_tmp))*100;

    try
        y = [y; data_tmp'];
    catch
        y = [y; data_tmp(1:size(y,2))'];
    end
  end

  E.time{1,record_i} = time_rel;
  E.trial{1,record_i} = y;
  E.timeburst{1,record_i} = timeburst_rgtc;      
  E.stim_amp{1,record_i} = stim_amp;    
  E.record_fname{1,record_i} = fname;  
  E.perc_nanvalues{1,record_i} = perc_nanvalues;
  E.Nsamples{1,record_i}=nsamples;
  E.Nbursts{1,record_i}=nbursts;
end

E.fsample = srate;
E = ft_checkconfig(E);

end