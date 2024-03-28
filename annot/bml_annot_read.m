function annot = bml_annot_read(filename,varargin)

% BML_ANNOT_READ reads an annotation table
%
% Use as
%   annot = bml_annot_read('annot/sync.txt')
%
% filename - char or string indicating file to load
% varargin - further arguments for readtable
%
% returns an annotation table

if ~ismember('delimiter',varargin)
  varargin = [varargin, {'delimiter','\t'}];
end
if ~ismember('FileType',varargin)
  varargin = [varargin, {'FileType','text'}];
end
if ~ismember('TreatAsEmpty',varargin)
  varargin = [varargin, {'TreatAsEmpty',{'NA'}}];
end

annot = readtable(filename,varargin{:});
[~,name,ext]=fileparts(filename);

[~,name,~]=fileparts(filename);
is_onset = ismember('onset',annot.Properties.VariableNames);
is_duration = ismember('duration',annot.Properties.VariableNames);
if is_onset && is_duration
    annot = bml_annot_rename(annot,'onset','starts');
    annot.ends = annot.starts + annot.duration;
    annot.id = (1:height(annot))';
    annot = bml_annot_table(annot,name);
end

% if strcmp(ext,'.tsv')
%     try
%         annot.ends = annot.starts + annot.duration;
%     catch
%         annot.ends = annot.onset + annot.duration;
%     end
%     annot.id = (1:height(annot))';
% end

annot = bml_annot_table(annot,name);

