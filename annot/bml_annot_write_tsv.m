function bml_annot_write_tsv(annot,filename,varargin)

% BML_ANNOT_WRITE writes an annotation table
%
% Use as
%   bml_annot_write(annot,'annot/MyAnnot.tsv')
%
% annot - annotation table to write
% filename - char or string indicating file to load
% varargin - further arguments for writetable

annot = bml_annot_table(annot,[],inputname(1));

if ~exist('filename','var')
  if isempty(annot.Properties.Description)
    error("filename required");
  else
    filename = fullfile(pwd,annot.Properties.Description,'.tsv');
    fprintf("writing annot table in %s\n",filename);
  end
end

annot = bml_annot_rename(annot,'starts','onset');
annot.id=[];
annot.ends=[];

if ~ismember('delimiter',varargin)
  varargin = [varargin, {'delimiter','\t'}];
end

writetable(annot,filename,varargin{:},'FileType','text');

