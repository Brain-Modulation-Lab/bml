function annot = bml_annot_read_tsv(filename,varargin)

% BML_ANNOT_READ_TSV reads tab delimited vector BIDS annotation table
%
% Use as
%   annot = bml_annot_read_tsv('annot/my_annot_table.tsv')
%
% filename - char or string indicating file to load
% varargin - further arguments for readtable
%
% pass 'AppendColsFromFilename', true to add subject, session, and task to
% to table columns
%
% returns an annotation table

% intercept varargin and remove AppendColsFromFilename variable if it
% exists
append_cols = false; 
i = strcmpi(varargin, 'AppendColsFromFilename'); 
if sum(i)==1
    append_cols = varargin{i+1}; 
    i = find(i); 
    varargin(i:i+1) = []; 
end 



if ~ismember('delimiter',varargin)
  varargin = [varargin, {'delimiter','\t'}];
end
if ~ismember('FileType',varargin)
  varargin = [varargin, {'FileType','text'}];
end
if ~ismember('TreatAsEmpty',varargin)
  varargin = [varargin, {'TreatAsEmpty',{'n/a'}}];
end

annot = readtable(filename,varargin{:});
[~,name,~]=fileparts(filename);
is_onset = ismember('onset',annot.Properties.VariableNames);
is_duration = ismember('duration',annot.Properties.VariableNames);
if is_onset && is_duration
    annot = bml_annot_rename(annot,'onset','starts');
    annot.ends = annot.starts + annot.duration;
    annot.id = (1:height(annot))';
    annot = bml_annot_table(annot,name);
end



%% Detect subject, session, task embedded in filename
% added by Latane Bullock 2023 05 31
% TODO: detect other table column variants besides subject_id etc, like
% 'sub'

if append_cols
    
    strids =   {'sub',        'ses',        'task'}; % bids identifier
    colnames = {'subject_id', 'session_id', 'task_id'}; 
    
    for i = 1:length(strids)
        % lookbehind, eg sub-DM1001_ses-intraop_suffix.tsv
        pat = ['(?<=' strids{i} '-)[a-zA-Z0-9-]*']; 
    
        mtch = regexp(filename, pat, 'match');
        if ~isempty(mtch)
    %         if iscell(mtch); mtch = mtch{1}; end
            assert(all(strcmp(mtch{1}, mtch))); % if multiple matches are found, make sure they are the same
            if ~ismember(colnames{i}, annot.Properties.VariableNames)
                annot(:, colnames{i}) = mtch(1);
            end
        end
    end

end



