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
if strcmp(ext,'.tsv')
    annot.ends = annot.starts + annot.duration;
    annot.id = (1:height(annot))';
end
annot = bml_annot_table(annot,name);

