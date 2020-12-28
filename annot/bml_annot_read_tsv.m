function annot = bml_annot_read_tsv(filename,varargin)

% BML_ANNOT_READ_TSV reads tab delimited vector BIDS annotation table
%
% Use as
%   annot = bml_annot_read_tsv('annot/my_annot_table.tsv')
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


