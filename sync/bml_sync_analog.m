function sync_roi = bml_sync_analog(cfg)

% BML_SYNC_ANALOG time-aligns files based on a common analog sync channel
%
% Use as
%   sync_roi = bml_sync_digital(cfg)
%
% cfg - configuration structure (reuired fields)
%   cfg.roi - roi table with vars 'id','starts','ends','folder','name',
%            'nSamples','filetype'. Contains a coarse alignment of the
%            files, normally inferred from the OS 'Date-Modified' metadata.
%            'starts' and 'ends' should be given in seconds from midnight.
%   cfg.sync_channels - table with vars 'filetype', 'channel', 'chantype'
%            and optionally 'threshold' (see below).
%            This table defines how channels of different filetypes will be
%            mapped with each other. If the threshold variable is present and 
%            the value for a specific channels is given (i.e. it is not NaN), 
%            then time intervals where the rectified signal of that channel exceeds the threshold
%            are zeroed. This can be useful to remove saturating glitches in the 
%            signal sometimes observed in trellis analog or other channels.     
%   cfg.chunks - annot table: defines starts and ends of chunks of time to sync
%            in master time. Usually corresponds to sessions but can be
%            shorter periods.
%   cfg.master_filetype - string: filetype that defines filetype used as master time,
%            to which to align other filetypes
%   cfg.sync_roi - roi table with previous results of current run. If
%            provided, the algorithm will skip doing the same
%            synchronization chunks. Useful for iterative chunking. 
%
% cfg - configuration structure (optional fields)
%   cfg.timewarp - logical: Should slave time be warped? defaults to true.
%   cfg.lpf - logical: low-pass-filter alignment if true (default)
%   cfg.praat - logical: should synchronized files be opened in praat for
%            manual quality check. Defaults to false.
%   cfg.chunk_extend - double or double array of length 2: amount of seconds by 
%             which to extend each sync chunk in slave files to avoid cropping out 
%             relevant part of because of incorrect initial alignemnt
%             files. Defaults to 0 seconds.    
%   cfg.resample_freq - double: frequency in Hz at which to resample master
%            and slave raws. Defaults to 10000. 
%   cfg.dryrun - logical: if true no alignment is performed (defaults to
%           false)
%   cfg.env_freq - double: frequency of the envelope used for coarse
%           alignement (Hz). Defaults to 100. Note that
%           resample_freq/env_freq should be an integer. 
%   cfg.env_scan - double: number of seconds in which to scan for initial
%           coarse grain alignement between master and slave's envelopes.
%           Defaults to 300 seconds (5 minutes).
%   cfg.env_penalty_wt0_min - double: penalty parameter for midpoint shift in
%           coarse time-warp. Defaults to 1e-3. (see BML_TIMEWARP)
%   cfg.env_penalty_ws1 - double: penalty parameter for time stretching in
%           coarse time-warp. Defaults to 1e-3. (see BML_TIMEWARP)
%   cfg.lpf_max_freq - double: maximum low-pass-filter cutoff frequency (Hz).
%           The value used is the minimum between this argument and the
%           master's and slave's sampling frequency. Defaults to 4000 Hz. 
%   cfg.lpf_scan - double: number of seconds in which to scan for fine-grain
%           alignement between master and slave's low-pass-filter signal.
%           Defaults to 1 seconds.
%   cfg.lpf_penalty_wt0_min - double: penalty parameter for midpoint shift in
%           fine-grain time-warp. Defaults to 1e-6. (see BML_TIMEWARP)
%   cfg.lpf_penalty_ws1 - double: penalty parameter for time stretching in
%           fine-grain time-warp. Defaults to 1e-4. (see BML_TIMEWARP)
%   cfg.ft_feedback - string: default to 'no'. Defines verbosity of fieldtrip
%           functions 
%   cfg.discontinuous - string or logical: 
%           * true or 'allow' to allow discontinous files to be loaded filling 
%           the gap with zero-padding, if possible within timetol.
%           * false or 'no' to issue an error if discontinous files are found
%           * 'warn' to allow with a warning (default)
%   cfg.high_pass - logical: should high pass filter be applied before
%           alignment. Defaults to false.
%   cfg.high_pass_freq - float: high pass frequency in Hz. Defaults to 5 Hz
%
% returns roi table with vars 
%   id: integer identification number of the synchronized file chunk
%   starts: start time in seconds from midnight of the represented signal
%   ends: end time in seconds from midnight of the represented signal
%   duration: duration in seconds as calculated by ends - starts
%   s1: first sample number of synchronization coordinate
%   t1: midpoint time of sample s1. Note that if s1==1 => t1=starts+0.5/Fs
%   s2: last sample number of synchronization coordinate
%   t2: midpoint time of sample s2. Note that if s2==end => t2=ends-0.5/Fs
%   folder: 
%   name: file name. Note that several each file can have several file
%         chunks, i.e. several rows in this table 
%   nSamples: integer total number of samples of the file
%   filetype: 
% 
%--------------------------------------------------------------------------
%
% The algorithm first opens time chucks (defined in cfg.chunks) of the files 
% defined in cfg.roi, loading the channels defined in cfg.sync_channels. 
% The coarse alignment of cfg.roi should be within a 60 second tolerance.
% It then calculates the envelope of the channels with BML_ENVELOPE_BINABS,
% and aligns these envelopes with BML_TIMEALIGN. If cfg.timewarp is true, 
% it applies a time-warping algorithm as defined in BML_TIMEWARP to
% maximize the correlation between slave and master channels. If cfg.lpf is
% true, it then repeats these processes for a low-pass filter version of
% the channels. If cfg.praat is true, the resulting synchronized chunks are 
% loaded in praat. The function returns a synchronization roi table. 
%

%ToDo: check that filetype of roi is consitent with cfg.sync_channels
%add examples to documentation

sync_channels       = bml_getopt(cfg,'sync_channels');
master_filetype     = bml_getopt_single(cfg,'master_filetype');
chunks              = bml_getopt(cfg,'chunks');
chunk_extend        = bml_getopt(cfg,'chunk_extend',0);
roi_os              = bml_roi_table(bml_getopt(cfg,'roi'),'roi_os');
prev_sync_roi       = bml_getopt(cfg,'sync_roi');
praat               = bml_getopt(cfg,'praat',false);
resample_freq       = bml_getopt(cfg,'resample_freq',10000);
dryrun              = bml_getopt(cfg,'dryrun',false);
env_freq            = bml_getopt(cfg,'env_freq',100);
env_scan            = bml_getopt(cfg,'env_scan',300);
env_penalty_wt0_min = bml_getopt(cfg,'env_penalty_wt0_min',1e-3);
env_penalty_ws1     = bml_getopt(cfg,'env_penalty_ws1',1e-3);
lpf_max_freq        = bml_getopt(cfg,'lpf_max_freq',4000);
lpf                 = bml_getopt(cfg,'lpf',true);
lpf_scan            = bml_getopt(cfg,'lpf_scan',1);
lpf_penalty_wt0_min = bml_getopt(cfg,'lpf_penalty_wt0_min',1e-6);
lpf_penalty_ws1     = bml_getopt(cfg,'lpf_penalty_ws1',1e-4);
timewarp            = bml_getopt(cfg,'timewarp',true);
ft_feedback         = bml_getopt_single(cfg,'ft_feedback','no');
discontinuous       = bml_getopt(cfg,'discontinuous','warn');
high_pass           = bml_getopt(cfg,'high_pass',false);
high_pass_freq      = bml_getopt(cfg,'high_pass_freq',5);
timetol             = bml_getopt(cfg,'timetol',1e-6);

assert(~ismember('filetype',chunks.Properties.VariableNames),...
  'cfg.chunks should not containt ''filetype'' variable');
assert(~isempty(chunks),'empty chunks table');

chunks = bml_annot_table(bml_chunk_sessions(chunks),'chunks');

sync_roi = table();
sync_roi_vars = {'starts','ends','s1','t1','s2','t2','folder','name','nSamples','Fs','session_id','session_part','filetype'};
sync_roi_vars_out = [sync_roi_vars,{'chantype','chunk_id','warpfactor','sync_channel','sync_type'}];

filetypes=unique(sync_channels.filetype);
slave_filetypes = setdiff(filetypes,master_filetype);
master_channel = sync_channels.channel{strcmp(sync_channels.filetype,master_filetype)};
master_chantype = sync_channels.chantype{strcmp(sync_channels.filetype,master_filetype)};

extended_chunks = bml_annot_extend(chunks,chunk_extend);

if ~isempty(prev_sync_roi) %previous attempts to sync
  prev_sync_roi = bml_roi_table(prev_sync_roi,'prev');
  assert(all(ismember({'sync_type','sync_channel','chantype'},prev_sync_roi.Properties.VariableNames)),...
    "variables sync_type, sync_channel and chantype required for cfg.sync_roi");
else %checking files before commiting to synchronization
  for chunk_i=1:height(chunks)
    chunk_roi_os = bml_annot_intersect(roi_os, chunks(chunk_i,:));  
    for filetype_i=1:length(filetypes)
      cfg=[]; 
      cfg.ft_feedback=ft_feedback;
      cfg.channel = sync_channels.channel{strcmp(sync_channels.filetype,filetypes(filetype_i))};
      cfg.chantype = sync_channels.chantype{strcmp(sync_channels.filetype,filetypes(filetype_i))};
      cfg.roi=chunk_roi_os(string(chunk_roi_os.filetype)==filetypes(filetype_i),:);
      cfg.dryrun=true;
      cfg.discontinuous=discontinuous;
      assert(height(cfg.roi)>0,'No files for filetype %s and chunk_id %i',...
        filetypes{filetype_i},chunks.id(chunk_i));
      try
        bml_load_continuous(cfg); %raises error if continuity is violated
      catch err
        error('filetype %s chunk %i failed \n %s',filetypes{filetype_i},chunks.id(chunk_i),err.message);
      end
    end
  end
end

%synchronizing
for chunk_i=1:height(chunks)
  chunk_id = chunks.id(chunk_i);
  
  %interseting with chunks for master
  chunk_roi_os = bml_annot_intersect(roi_os, chunks(chunk_i,:)); 
  master_chunk_roi_os=chunk_roi_os(strcmp(chunk_roi_os.filetype,master_filetype),:);  
  
  %intersecting with extended chunks for slave
  extended_chunk_roi_os = bml_annot_intersect(roi_os, extended_chunks(chunk_i,:));  

  do_this_chunk = true;
  %cheking if this chunk was previously done
  if ~isempty(prev_sync_roi)
    cfg=[];
    cfg.overlap=0.001;
    prev_chunk_i = bml_annot_filter(cfg,prev_sync_roi,master_chunk_roi_os);
    prev_chunk_i_master = prev_chunk_i(strcmp(prev_chunk_i.sync_type,'master') &...
                                       strcmp(prev_chunk_i.sync_channel,master_channel) & ...
                                       strcmp(prev_chunk_i.chantype,master_chantype),:);
    %cheking consistency of previous and current syncs
    if height(prev_chunk_i_master)==height(master_chunk_roi_os) && ...
       abs(min(prev_chunk_i_master.starts) - min(master_chunk_roi_os.starts)) < timetol && ...
       abs(max(prev_chunk_i_master.ends) - max(master_chunk_roi_os.ends)) < timetol
     
       do_this_chunk = false; %will skip the calculations for this chunk
       fprintf('skipping chunk %i consistent with chunk %i in cfg.sync_roi \n',chunk_id, unique(prev_chunk_i_master.chunk_id));
     
       %adding row info for master
       row = prev_chunk_i_master(:,sync_roi_vars_out);
       row.chunk_id(:) = chunk_id;  %replacing chunk info
       sync_roi = [sync_roi;row];
       
       %adding row info for slaves
       row = prev_chunk_i(ismember(prev_chunk_i.filetype,slave_filetypes) & ...
              ismember(prev_chunk_i.sync_channel,sync_channels.channel(ismember(sync_channels.filetype,slave_filetypes))) &...
              prev_chunk_i.chunk_id == unique(prev_chunk_i_master.chunk_id), ...
              sync_roi_vars_out);
       row.chunk_id(:) = chunk_id; %replacing chunk info
       sync_roi = [sync_roi;row];  
    end
  end
  
  if do_this_chunk
    fprintf('synchronizing chunk %i \n',chunk_id);

    cfg=[]; %creating masters raw with sync channel for entire session
    cfg.channel = master_channel; 
    cfg.chantype = master_chantype; 
    cfg.roi = master_chunk_roi_os; 
    cfg.ft_feedback = ft_feedback;
    cfg.dryrun = dryrun;
    cfg.discontinuous = discontinuous;
    [master, master_map] = bml_load_continuous(cfg);

    if ismember('threshold',sync_channels.Properties.VariableNames)
      %zeroing supra treshold regions of master
      threshold = sync_channels.threshold(...
        strcmp(sync_channels.filetype,master_filetype) & ...
        strcmp(sync_channels.channel,master_channel) & ...
        strcmp(sync_channels.chantype,master_chantype));
      
      if ~isnan(threshold)
        fprintf('Threshold found for channel ''%s'' of filetype ''%s'' \nZeroing where abs > %f \n',...
          master_channel,master_filetype,threshold);  
        
        cfg1=[];
        cfg1.threshold = threshold;
        sat = bml_annot_detect(cfg1,bml_envelope_binabs(master));
        
        cfg2=[];
        cfg2.value=0;
        cfg2.annot=sat;
        master = bml_mask(cfg2,master);
      end
    end
    
    %if sync_channels.channel{strcmp(sync_channels.filetype,master_filetype)}
    
    if high_pass
      master.trial{1} = ft_preproc_highpassfilter(master.trial{1},...
                        master.fsample, high_pass_freq, 4, 'but', 'twopass');
    end

    row = master_chunk_roi_os(:,sync_roi_vars);
    row.chantype = repmat({master_chantype},height(row),1);
    row.chunk_id = repmat(chunk_id,height(row),1);
    row.warpfactor = ones(height(row),1);
    row.sync_channel = master_channel;
    row.sync_type = {'master'};
    sync_roi = [sync_roi;row];

    if praat && ~dryrun
      bml_praat(strcat('c',num2str(chunk_id),'_master_',master_filetype),master);  
    end

    for slave_i=1:length(slave_filetypes)
      filetype_chunk_roi_os=extended_chunk_roi_os(string(extended_chunk_roi_os.filetype)==slave_filetypes(slave_i),:);
      slave_channel = sync_channels.channel{strcmp(sync_channels.filetype,slave_filetypes(slave_i))};
      slave_chantype = sync_channels.chantype{strcmp(sync_channels.filetype,slave_filetypes(slave_i))};

      cfg=[]; %creating slave raw with sync channel for entire session
      cfg.ft_feedback=ft_feedback;
      cfg.channel = slave_channel; 
      cfg.chantype = slave_chantype;
      cfg.roi = filetype_chunk_roi_os;
      cfg.dryrun = dryrun;
      cfg.discontinuous=discontinuous;
      [slave, slave_map] = bml_load_continuous(cfg);  

      if ismember('threshold',sync_channels.Properties.VariableNames)
     	%zeroing supra treshold regions of slave
        threshold = sync_channels.threshold(...
          strcmp(sync_channels.filetype,slave_filetypes(slave_i)) & ...
          strcmp(sync_channels.channel,slave_channel) & ...
          strcmp(sync_channels.chantype,slave_chantype));
      
        if ~isnan(threshold)
          fprintf('Threshold found for channel ''%s'' of filetype ''%s'' \nZeroing where abs > %f \n',...
            slave_channel,slave_filetypes(slave_i),threshold);  

          cfg1=[];
          cfg1.threshold = threshold;
          sat = bml_annot_detect(cfg1,bml_envelope_binabs(slave));

          cfg2=[];
          cfg2.value=0;
          cfg2.annot=sat;
          slave = bml_mask(cfg2,slave);
        end
      end
      
      if high_pass && ~dryrun
        slave.trial{1} = ft_preproc_highpassfilter(slave.trial{1},...
                        slave.fsample, 5, 4, 'but', 'twopass');
      end

      %envelope alingment and warping
      if ~dryrun
        cfg=[]; cfg.ft_feedback=ft_feedback;
        cfg.resample_freq=resample_freq; cfg.timewarp=timewarp;
        cfg.method='envelope'; cfg.env_freq=env_freq; cfg.scan=env_scan;
        cfg.penalty_wt0_min=env_penalty_wt0_min; cfg.penalty_ws1=env_penalty_ws1;
        wc_env = bml_timewarp(cfg,master,slave);
        slave.time{1} = bml_idx2time(wc_env, 1:length(slave.time{1}));
      else  
        wc_env = [];
        wc_env.s1 = min(slave_map.raw1);
        wc_env.s2 = max(slave_map.raw2);
        wc_env.t1 = min(slave_map.t1);
        wc_env.t2 = max(slave_map.t2);
        wc_env.wt0=0; 
        wc_env.ws1=1; 
      end

      if lpf && ~dryrun %low-pass frequency filter alignment and warping
          cfg=[]; cfg.ft_feedback=ft_feedback;
          cfg.resample_freq=resample_freq; cfg.timewarp=timewarp;
          cfg.method='low-pass-filter'; cfg.scan=lpf_scan;
          cfg.lpf_freq=min([master.fsample,slave.fsample,lpf_max_freq]);
          cfg.penalty_wt0_min=lpf_penalty_wt0_min; cfg.penalty_ws1=lpf_penalty_ws1;
          wc_lpf = bml_timewarp(cfg,master,slave);
          slave.time{1} = bml_idx2time(wc_lpf, 1:length(slave.time{1}));
      else
          wc_lpf = wc_env;
          wc_lpf.ws1 = 1;
      end

      %saving sync info
      row = filetype_chunk_roi_os(:,sync_roi_vars);
      if height(row) ~= height(slave_map)
        row = row(ismember(row.name,slave_map.name),:);
      end
      row.s1 = slave_map.s1;
      row.s2 = slave_map.s2; 
      row.t1 = bml_idx2time(wc_lpf,slave_map.raw1);
      row.t2 = bml_idx2time(wc_lpf,slave_map.raw2);
      row.starts = row.t1 - 0.5./row.Fs;
      row.ends = row.t2 + 0.5./row.Fs;
      row.chantype=repmat({slave_chantype},height(row),1);
      row.sync_channel = repmat({slave_channel},height(row),1);
      row.sync_type = repmat({'slave'},height(row),1);
      row.warpfactor = repmat(wc_env.ws1*wc_lpf.ws1,height(row),1);
      row.chunk_id = repmat(chunk_id,height(row),1);
      sync_roi = [sync_roi; row];

      if praat && ~dryrun
        slave_crop = bml_conform_to(master,slave);
        bml_praat(strcat('c',num2str(chunk_id),'_slave_',slave_filetypes(slave_i)),slave_crop);
      end
    end
  end
end

sync_roi = bml_roi_table(sync_roi);

for slave_i=1:length(slave_filetypes)
  sync_roi_i = sync_roi(strcmp(sync_roi.filetype,slave_filetypes{slave_i}),:);
  chantype = unique(sync_roi_i.chantype);
  sync_channel = unique(sync_roi_i.sync_channel);
  fprintf('Summary for slave filetype %s, chantype %s, sync_channel %s \n.',...
    slave_filetypes{slave_i},chantype{1},sync_channel{1});
  sync_roi_i(:,{'id','starts','ends','duration','name','session_id','warpfactor'})
end



