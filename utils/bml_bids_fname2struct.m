function [s] = bml_bids_fname2struct(filenames)
%BML_BIDS_FNAME2STRUCT Turn a BIDS filename (string or char array) into a
% struct. Struct fields correspond to BIDS standard fields. 
% Latane Bullock 2024 01 14s

filenames = string(filenames); 

s = []; 

strids =   {'sub',        'ses',        'task',   'run',    'ch',         'elec'}; % bids identifier
colnames = {'subject_id', 'session_id', 'task_id','run_id', 'channel_id', 'electrode_id'};

for i = 1:length(strids)
    % lookbehind, eg sub-DM1001_ses-intraop_suffix.tsv
    pat = ['(?<=' strids{i} '-)[a-zA-Z0-9-]*'];

    mtch = regexp(filenames, pat, 'match');
    if ~isempty(mtch)
        %         if iscell(mtch); mtch = mtch{1}; end
        assert(all(strcmp(mtch{1}, mtch))); % if multiple matches are found, make sure they are the same
        s.(strids{i}) = mtch{1};
        s.(colnames{i}) = mtch{1};
    end
end



