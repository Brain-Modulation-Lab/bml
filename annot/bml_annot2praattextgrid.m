function textgrids_all = bml_annot2praattextgrid(cfg, annot)

% bml_annot2textgrid converts a BML annot table into a textgrid that can be
% written to disk and opened with Praat
% Script assumes there is an audio file for the run, whose global time
% onset will be determined from the sync.tsv table
%
% Use as 
%   textgrid = bml_annot2coord(word_annot, 'word', 'word')
%   textgrid = bml_annot2coord(cfg, word_annot, ) to creat
%
% annot - ANNOT table with 'starts', 'ends' 
% cfg.col_name - name of the annot column from which we extract the TextGrid
%               label for each interval
% cfg.tier_name - name of the TextGrid tier you are creating (eg, 'phoneme', 'word')
% cfg.file_out - if this is not empty, the textgrid will be written to disk
%               at the path file_out  
%
% returns a cell array of textgrids, one per run 
% 
% TextGrids are of the format specified here: https://github.com/bbTomas/mPraat
% tg.tier - cell array of tiers
%     tier.type - 'interval' or 'point'
%     tier.T1 - float array of time onsets
%     tier.T2 - float array of time offsets 
%     tier.Label - cell array of phoneme/word labels
% tg.tmin
% tg.tmax
%
% 
% Latane Bullock 20230815 latanebullock@gmail.com


col_name  = bml_getopt(cfg,'col_name'); % col_name = col_name{1}; 
tier_name  = bml_getopt(cfg,'tier_name'); % tier_name = tier_name{1}; 
file_out_dir  = bml_getopt(cfg,'file_out_dir'); % file_out_dir = file_out_dir{1}; 

assert(ismember(col_name, annot.Properties.VariableNames), ['Column "' col_name{1} '" is not in annot']); 
assert(all(ismember({'subject_id', 'session_id', 'task_id'}, annot.Properties.VariableNames)), 'Please add subject, session, and task columns to annot'); 
assert(length(unique(annot.subject_id))==1, 'Annot should contain only one subject, session, and task'); 
assert(length(unique(annot.session_id))==1, 'Annot should contain only one subject, session, and task'); 
assert(length(unique(annot.task_id))==1, 'Annot should contain only one subject, session, and task'); 

SUBJECT = annot.subject_id{1}; 
SESSION = annot.session_id{1}; 
TASK =    annot.task_id{1}; 

%% 
PATH_DATASET = 'Y:\DBS';
PATH_DER = [PATH_DATASET filesep 'derivatives'];
PATH_DER_SUB = [PATH_DER filesep 'sub-' SUBJECT];  
PATH_ANNOT = [PATH_DER_SUB filesep 'annot'];

runs = bml_annot_read_tsv([PATH_ANNOT filesep 'sub-' SUBJECT '_runs.tsv']);

sync = bml_annot_read_tsv([PATH_ANNOT filesep 'sub-' SUBJECT '_ses-' SESSION '_sync.tsv']);
sync = sync(strcmp(sync.chantype, 'directionalmicaec'), :); 

matches = regexp(sync.basename, 'sub-(?<subject_id>\w+)_ses-(?<session_id>\w+)_task-(?<task_id>\w+)_run-(?<run_id>\d+).*', 'names'); 
sync.run_id = cellfun(@(m) str2num(m.run_id), matches); 
sync.task_id = cellfun(@(m) (m.task_id), matches, 'UniformOutput', false); 
sync.session_id = cellfun(@(m) (m.session_id), matches, 'UniformOutput', false); 

sync = sync(strcmp(sync.session_id, SESSION) & strcmp(sync.task_id, TASK), :);

% determine if annot is a point (durations==0) or interval (durations~=0)
tiertype = 'interval'; 
if sum(annot.starts - annot.ends) < 1e-3
    tiertype = 'point'; 
end

%%
run_ids = unique(annot.run_id); 

textgrids_all = []; 

for irun = 1:length(run_ids)
    run_id = run_ids(irun);

    t0 = sync.t1(sync.run_id==run_id);
    assert(numel(t0)==1, 'Run not properly identified.')
   
    annot_run = annot(annot.run_id==run_id, :); 

    %
    tier = [];
    tier.type = tiertype; 
    tier.name = tier_name{1}; 
    switch tiertype
        case 'interval'
            tier.T1 = annot_run.starts' - t0; 
            tier.T2 = annot_run.ends' - t0; 
        case 'point'
            tier.T = annot_run.starts' - t0; 
    end
    tier.Label = annot_run.(col_name{1})'; 
    

    textgrid = [];
    textgrid.tier = {};
    textgrid.tier{1} = tier;

    switch tiertype
        case 'interval'
            textgrid.tmin = min(tier.T1);
            textgrid.tmax = max(tier.T2);
        case 'point'
            textgrid.tmin = min(tier.T);
            textgrid.tmax = max(tier.T);
    end


    
    if ~isempty(file_out_dir)
        tgWrite(textgrid, [file_out_dir{1} filesep 'sub-' SUBJECT '_ses-' SESSION '_task-' TASK '_run-' sprintf('%02d', run_id) '_annot2textgrid-' col_name{1} '.TextGrid']); 
    end

    if isempty(textgrids_all)
        textgrids_all = textgrid; 
    else 
        textgrids_all = [textgrids_all; textgrid]; 
    end
end

if length(textgrids_all)==1 % unpack textgrid if there's just one run
    textgrids_all = textgrids_all(1); 
end






