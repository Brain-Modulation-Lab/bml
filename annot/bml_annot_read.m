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
annot = readtable(filename,varargin{:});
[~,name,~]=fileparts(filename);
annot = bml_annot_table(annot,name);

