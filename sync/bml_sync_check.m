function bml_sync_check(cfg)

% BML_SYNC_CHECK loads files in a synchronization roi table into praat
%
% Use as
%    bml_sync_check(cfg)
%
% cfg - configuration structure
%   cfg.roi - roi table with additional vars 'session_id','session_part',
%            'filetype','sync_channel','sync_type','chunk_id'. Contains 
%            a coarse alignment of the files, normally inferred from the
%            OS 'Date-Modified' metadata.
%   cfg.praat - logical: should synchronized files be opened in praat.
%           Defaults to true.
%   cfg.ft_feedback - string: default to 'no'. Defines verbosity of fieldtrip
%           functions 

sync_roi_vars = {'session_id','session_part','filetype','sync_channel','sync_type','chunk_id'};

if istable(cfg)
  cfg = struct('roi',cfg);
end

sync_roi            = bml_roi_table(bml_getopt(cfg,'roi'),'roi_os');
praat               = bml_getopt(cfg,'praat',true);
ft_feedback         = bml_getopt_single(cfg,'ft_feedback','no');

assert(~isempty(sync_roi),'empty sync roi table');
assert(all(ismember(sync_roi_vars,sync_roi.Properties.VariableNames)),...
  "roi table should have vars %s",strjoin(sync_roi_vars));

%loading sync channels
chunk_ids=unique(sync_roi.chunk_id);
for chunk_i=1:length(chunk_ids)
  chunk_id = chunk_ids(chunk_i);
  master_roi = sync_roi((sync_roi.chunk_id==chunk_id) & (sync_roi.sync_type=="master"),:);
  slave_roi = sync_roi((sync_roi.chunk_id==chunk_id) & (sync_roi.sync_type=="slave"),:);
  
  master_filename = unique(master_roi.name);
  master_folder = unique(master_roi.name);

	assert(~isempty(master_filename), "No master file found for for chunk %i",chunk_id);
  assert(length(master_filename)==1 & length(master_folder)==1,...
    "More than one master file for chunk %i",chunk_id);
  assert(length(unique(master_roi.s1))==1,"Inconsistent s1 for master of chunk %i", chunk_id);
  assert(length(unique(master_roi.s2))==1,"Inconsistent s2 for master of chunk %i", chunk_id);
  assert(length(unique(master_roi.t1))==1,"Inconsistent t1 for master of chunk %i", chunk_id);
  assert(length(unique(master_roi.t2))==1,"Inconsistent t2 for master of chunk %i", chunk_id);
  assert(length(unique(master_roi.starts))==1,"Inconsistent starts for master of chunk %i", chunk_id);
  assert(length(unique(master_roi.ends))==1,"Inconsistent ends for master of chunk %i", chunk_id);
  
  cfg=[];
  cfg.roi=master_roi(1,:);
  cfg.channel=unique(master_roi.sync_channel);
  master = bml_load_continuous(cfg);
  
  if praat
  	bml_praat(strcat('c',num2str(chunk_id),'_master_',master_filename),master);  
  end
  
  for slave_i=1:height(slave_roi)  
    
    cfg=[];
    cfg.roi=slave_roi(slave_i,:);
    cfg.channel=unique(slave_roi.sync_channel(slave_i));
    slave = bml_load_continuous(cfg);    
    
    if praat
      t1=master.time{1}(1);
      t2=master.time{1}(end);
      cfg=[]; cfg.time=master.time; cfg.method='pchip';
      cfg.extrapval = nan;
      cfg.feedback=ft_feedback;
      slave_crop=ft_resampledata(cfg,bml_crop(slave,t1,t2));
      slave_crop.fsample = master.fsample;
      bml_praat(strcat('c',num2str(chunk_id),'_slave_',slave_roi.name(slave_i)),slave_crop);
    end

  end
end





