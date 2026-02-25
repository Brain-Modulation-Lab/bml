function E = bml_argus_read_records(argus1_data_path, srate)

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
  [data, metadata] = read_argus_record(fname);
  timeburst = metadata{:,1};
  stim_amp = metadata{:,3};

  % PREPROCESSING
  % timeburst is in this format HHmmss.xxxx
  % convert it into seconds from midnight of the same day  
  timeburst_gtc = timestamp2gtc(timeburst);
  E.timeburst{1,record_i} = filloutliers(timeburst_gtc,'linear');
  
  % define time vector
  [nbursts, nsamples] = size(data);
  fprintf(' with %d bursts. \n', nbursts)
  
  E.time{1,record_i} = (0 : 1/srate : (nsamples - 1)/srate);
  E.perc_nanvalues{1,record_i} = mean(isnan(data),2)*100;
  E.trial{1,record_i} = data;
  E.stim_amp{1,record_i} = stim_amp;    
  E.record_fname{1,record_i} = fname;  
  E.Nsamples{1,record_i}=nsamples;
  E.Nbursts{1,record_i}=nbursts;
end

E.fsample = srate;
E = ft_checkconfig(E);

end