function sync_roi = bml_synchronize_files(cfg)

% BML_SYNCHRONIZE_FILES time-aligns files based on a common sync channel
%
% Use as
%   sync_roi = bml_synchronize_files(cfg)
%
% cfg - configuration structure
%   cfg.sync_channels - table with vars 'filetype', 'channel', 'chantype'
%   cfg.master_filetype - string: filetype that defines the time to which to align
%             other filetypes
%   cfg.sessions - annot table: defines starts and ends of sessions in master time
%   cfg.files - roi table with vars 'id','starts','ends','folder','name',
%            'nSamples','filetype'. Contains a coarse alignment of the
%            files, normally inferred from the OS 'Date-Modified' metadata.
%            'starts' and 'ends' should be given in seconds from midnight.
%   cfg.praat - logical: should synchronized files be opened in praat for
%            manual quality check
%   cfg.resample_freq - double: frequency in Hz at which to resample master
%            and slave raws. Defaults to 10000. 
%   cfg.env_freq - double: frequency of the envelope used for coarse
%           alignement (Hz). Defaults to 100. Note that
%           resample_freq/env_freq should be an integer. 
%   cfg.env_scan - double: number of seconds in which to scan for initial
%           coarse grain alignement between master and slave's envelopes.
%           Defaults to 300 seconds (5 minutes).
%   cfg.env_penalty_wt0 - double: penalty parameter for midpoint shift in
%           coarse time-warp. Defaults to 30. (see BML_TIMEWARP)
%   cfg.env_penalty_ws1 - double: penalty parameter for time stretching in
%           coarse time-warp. Defaults to 1e-3. (see BML_TIMEWARP)
%   cfg.lpf_max_freq - double: maximum low-pass-filter cutoff frequency (Hz).
%           The value used is the minimum between this argument and the
%           master's and slave's sampling frequency. Defaults to 4000 Hz. 
%   cfg.lpf_scan - double: number of seconds in which to scan for fine-grain
%           alignement between master and slave's low-pass-filter signal.
%           Defaults to 1 seconds.
%   cfg.lpf_penalty_wt0 - double: penalty parameter for midpoint shift in
%           fine-grain time-warp. Defaults to 1. (see BML_TIMEWARP)
%   cfg.lpf_penalty_ws1 - double: penalty parameter for time stretching in
%           fine-grain time-warp. Defaults to 1e-4. (see BML_TIMEWARP)
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

sync_channels   = bml_getopt(cfg,'sync_channels');
master_filetype = bml_getopt(cfg,'master_filetype');
sessions        = bml_annot_table(bml_getopt(cfg,'sessions'),'sessions');
files_os        = bml_roi_table(bml_getopt(cfg,'files'),'files_os');
praat           = bml_getopt(cfg,'praat',false);
resample_freq   = bml_getopt(cfg,'resample_freq',10000);
env_freq        = bml_getopt(cfg,'env_freq',100);
env_scan        = bml_getopt(cfg,'env_scan',300);
env_penalty_wt0 = bml_getopt(cfg,'env_penalty_wt0',30);
env_penalty_ws1 = bml_getopt(cfg,'env_penalty_ws1',1e-3);
lpf_max_freq    = bml_getopt(cfg,'lpf_max_freq',4000);
lpf_scan        = bml_getopt(cfg,'lpf_scan',1);
lpf_penalty_wt0 = bml_getopt(cfg,'lpf_penalty_wt0',1);
lpf_penalty_ws1 = bml_getopt(cfg,'lpf_penalty_ws1',1e-4);

sync_roi = files_os;
if ~ismember('warpfactor',sync_roi.Properties.VariableNames)
  sync_roi.warpfactor=ones(height(sync_roi),1);
end

slave_filetypes = setdiff(unique(sync_channels.filetype),master_filetype);
master_channel = sync_channels.channel{strcmp(sync_channels.filetype,master_filetype)};
master_chantype = sync_channels.chantype{strcmp(sync_channels.filetype,master_filetype)};

for session_i=1:height(sessions)
  session_files_os = bml_annot_intersect(files_os, sessions(session_i,:));  
  master_session_files_os=session_files_os(strcmp(session_files_os.filetype,master_filetype),:);  

  % create FT_DATATYPE_RAW with masters sync channel for entire session
  cfg=[]; cfg.channel = master_channel; cfg.chantype = master_chantype; 
  cfg.roi = master_session_files_os;
  master = bml_load_continuous(cfg);
   
  for slave_i=1:length(slave_filetypes)
    filetype_session_files_os=session_files_os(string(session_files_os.filetype)==slave_filetypes(slave_i),:);
    for file_i=1:height(filetype_session_files_os)
        
      %loading particular slave file
      cfg=[]; 
      cfg.channel = sync_channels.channel{strcmp(sync_channels.filetype,slave_filetypes(slave_i))};
      cfg.chantype = sync_channels.chantype{strcmp(sync_channels.filetype,slave_filetypes(slave_i))};
      cfg.roi = filetype_session_files_os(file_i,:);
      slave = bml_load_continuous(cfg);

      cfg=[]; cfg.resample_freq=resample_freq;
      cfg.method='envelope';cfg.env_freq=env_freq; cfg.scan=env_scan;
      cfg.penalty_wt0=env_penalty_wt0; cfg.penalty_ws1=env_penalty_ws1;
      wc_env = bml_timewarp(cfg,master,slave);
      slave.time{1} = bml_idx2time(wc_env, 1:length(slave.time{1}));

      cfg=[]; cfg.resample_freq=resample_freq;
      cfg.method='low-pass-filter'; cfg.scan=lpf_scan;
      cfg.lpf_freq=min([master.fsample,slave.fsample,lpf_max_freq]);
      cfg.penalty_wt0=lpf_penalty_wt0; cfg.penalty_ws1=lpf_penalty_ws1;
      wc_lpf = bml_timewarp(cfg,master,slave);
      slave.time{1} = bml_idx2time(wc_lpf, 1:length(slave.time{1}));

      %saving synchronized time coordinates
      filtvec=(sync_roi.id==filetype_session_files_os.files_os_id(file_i));
      sync_roi.t1(filtvec) = wc_lpf.t1;
      sync_roi.t2(filtvec) = wc_lpf.t2;
      sync_roi.s1(filtvec) = wc_lpf.s1;
      sync_roi.s2(filtvec) = wc_lpf.s2;
      sync_roi.warpfactor(filtvec) = wc_env.ws1*wc_lpf.ws1;
      
      if praat
        t1=max(master.time{1}(1),slave.time{1}(1));
        t2=min(master.time{1}(end),slave.time{1}(end));
        master_crop=bml_crop(master,t1,t2);
        cfg=[]; cfg.time=master_crop.time; cfg.method='pchip';
        slave_crop=ft_resampledata(cfg,bml_crop(slave,t1,t2));
        slave_crop.fsample = master_crop.fsample;
        bml_praat(master_crop,slave_crop);
      end
    end
  end
end





