function sync_roi = bml_sync_digital(cfg)

% BML_SYNC_ANALOG time-aligns files based on a common analog sync channel
%
% Use as
%   sync_roi = bml_sync_digital(cfg)
%
% cfg - configuration structure
%   cfg.sync_channels - table with vars 'filetype', 'channel', 'chantype'
%   cfg.master_filetype - string: filetype that defines the time to which to align
%             other filetypes
%   cfg.sync_chunks - annot table: defines starts and ends of chunks of time to sync
%             in master time. Usually corresponds to sessions but can be
%             shorter periods.
%   cfg.chunk_extend - double or double array of length 2: amount of seconds by 
%             which to extend each sync chunk in slave files to avoid cropping out 
%             relevant part of because of incorrect initial alignemnt
%             files. Defaults to 0 seconds.    
%   cfg.roi - roi table with vars 'id','starts','ends','folder','name',
%            'nSamples','filetype'. Contains a coarse alignment of the
%            files, normally inferred from the OS 'Date-Modified' metadata.
%            'starts' and 'ends' should be given in seconds from midnight.
%   cfg.timewarp - logical: Should slave time be warped? defaults to 
%            true.
%   cfg.praat - logical: should synchronized files be opened in praat for
%            manual quality check
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
%   cfg.lpf - logical: low-pass-filter alignment if true (default)
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

sync_channels       = bml_getopt(cfg,'sync_channels');
master_filetype     = bml_getopt_single(cfg,'master_filetype');
chunks              = bml_annot_table(bml_getopt(cfg,'chunks'),'chunks');
chunk_extend        = bml_getopt(cfg,'chunk_extend',0);
roi_os              = bml_roi_table(bml_getopt(cfg,'roi'),'roi_os');
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

assert(~ismember('filetype',chunks.Properties.VariableNames),...
  'cfg.chunks should not containt ''filetype'' variable');
assert(~isempty(chunks),'empty chunks table');

sync_roi = table();
sync_roi_vars = {'starts','ends','s1','t1','s2','t2','folder','name','nSamples','Fs','session_id','session_part','filetype'};

filetypes=unique(sync_channels.filetype);
slave_filetypes = setdiff(filetypes,master_filetype);
master_channel = sync_channels.channel{strcmp(sync_channels.filetype,master_filetype)};
master_chantype = sync_channels.chantype{strcmp(sync_channels.filetype,master_filetype)};

extended_chunks = bml_annot_extend(chunks,chunk_extend);

%checking files before commiting to synchronization
for chunk_i=1:height(chunks)
  chunk_roi_os = bml_annot_intersect(roi_os, chunks(chunk_i,:));  
  for filetype_i=1:length(filetypes)
    cfg=[]; cfg.ft_feedback=ft_feedback;
    cfg.channel = sync_channels.channel{strcmp(sync_channels.filetype,filetypes(filetype_i))};
    cfg.chantype = sync_channels.chantype{strcmp(sync_channels.filetype,filetypes(filetype_i))};
  	cfg.roi=chunk_roi_os(string(chunk_roi_os.filetype)==filetypes(filetype_i),:);
    cfg.dryrun=true;
    assert(height(cfg.roi)>0,'No files for filetype %s and session %i',...
      filetypes{filetype_i},chunks.id(chunk_i));
    bml_load_continuous(cfg); %raises error if continuity is violated
  end
end

%synchronizing
for chunk_i=1:height(chunks)
  chunk_id = chunks.id(chunk_i);
  
  %interseting with chunks for master
  chunk_roi_os = bml_annot_intersect(roi_os, chunks(chunk_i,:)); 
  master_chunk_roi_os=chunk_roi_os(strcmp(chunk_roi_os.filetype,master_filetype),:);  
  
  %interseting with extended chunks for slave
  extended_chunk_roi_os = bml_annot_intersect(roi_os, extended_chunks(chunk_i,:));  

  cfg=[]; %creating masters raw with sync channel for entire session
  cfg.channel = master_channel; cfg.chantype = master_chantype; 
  cfg.roi = master_chunk_roi_os; cfg.ft_feedback=ft_feedback;
  cfg.dryrun = dryrun;
  [master, master_map] = bml_load_continuous(cfg);
  
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
    [slave, slave_map] = bml_load_continuous(cfg);  
    
    %envelope alingment and warping
    if ~dryrun
      cfg=[]; cfg.ft_feedback=ft_feedback;
      cfg.resample_freq=resample_freq; cfg.timewarp=timewarp;
      cfg.method='envelope';cfg.env_freq=env_freq; cfg.scan=env_scan;
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





