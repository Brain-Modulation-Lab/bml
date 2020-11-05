function bml_annot_write(annot,filename,varargin)

% BML_ANNOT_WRITE writes an annotation table
%
% Use as
%   bml_annot_write(annot,'annot/MyAnnot.txt')
%
% annot - annotation table to write
% filename - char or string indicating file to load
% varargin - further arguments for writetable

annot = bml_annot_table(annot,[],inputname(1));

if ~exist('filename','var')
  if isempty(annot.Properties.Description)
    error("filename required");
  else
    filename = fullfile(pwd,annot.Properties.Description,'.txt');
    fprintf("writing annot table in %s\n",filename);
  end
end

[~,~,ext] = fileparts(filename);
if strcmp(ext,'.tsv')
    annot.id=[];
    annot.ends=[];
end

if ~ismember('delimiter',varargin)
  varargin = [varargin, {'delimiter','\t'}];
end

writetable(annot,filename,varargin{:},'FileType','text');

