function [Rec] =  bml_neuroomega_load(cfg)

% BML_NEUROOMEGA_LOAD loads a NeuroOmega dataset as FT_DATATYPE_RAW data structure. 
%
% Use as
%   rec = bml_load_neuroomega(cfg);
%
% The first argument cfg is a configuration structure, which may contain
% the following fields:
% cfg.path - string: path to the folder containing the .mat files. Defauts to '.'
% cfg.depth - double: depths to be loaded. If empty (defaults) all depths
%             are loaded
% cfg.files_table - table: compatible with output of bml_neuroomega_info_file
%             should conatin vars 'depth', 'name', 'folder'
% cfg.chantype - cell array of strings: defines channel types to be loaded.
%                use an invalid channel as '?' to get a table of available
%                channels and chantypes printed out. An error will stop
%                further analysis. 
%
% Returns a struct.array, where each element contains the following fields
% Rec(i).files - cell array of strings: .mat filenames
% Rec(i).depth - float: depth of the record
% Rec(i).<chantype1> - FT_DATATYPE_RAW containing the data of <chantype1>
% Rec(i).<chantype2> - FT_DATATYPE_RAW containing the data of <chantype2>
%
% chantypes can be any of the following
%   micro - high impedance microelectrode raw signal
%   macro - low impedance "ring" electrode raw signal
%   analog - analog input, usually audio
%   micro_lfp - low-pass filtered and downsampled version of micro
%   micro_hf - high-pass filtered version of micro
%   macro_lfp - low-pass filtered and downsampled version of macro
%   digital - digital input (up and down)
%   add_analog - additional analog channels
%
%

%2017.10.12 AB Based on Ahmad's function ReadNeuroOmega_AA.m, adapted for
%fieltrip
REQUIRED_VARS = {'depth','name','folder'};

depth = ft_getopt(cfg,'depth',[]);
files = ft_getopt(cfg,'files_table',[]);
chantype = ft_getopt(cfg,'chantype',{'micro','macro','analog'});
if ~iscell(chantype); chantype={chantype}; end

if isempty(files)
  files = bml_neuroomega_info_file(cfg);
elseif ~all(ismember(REQUIRED_VARS,files.Properties.VariableNames))
  error(['variables ' strjoin(REQUIRED_VARS,', ') ' required in cfg.files_table']);
end

depth_all = unique([files.depth]);
if isempty(depth); depth=depth_all; end

depth_sel=intersect(depth,depth_all);
if isempty(depth_sel)
  error(['No depth selected. Available depths are : ',strjoin(depth_all,' ')]);
end

N=numel(depth_sel);
Rec(N)=struct();
for m=1:N %cycling through depths
    fprintf('\n--- Processing Depth %f ---\n', depth_sel(m));
    db = files([files.depth]==depth_sel(m),:);
    db = sortrows(db,'name');
    Rec(m).folder=db.folder;    
    Rec(m).filename=db.name;
    Rec(m).depth=depth_sel(m);
   
    for i=1:numel(chantype) %cycling through chantypes
      tmp=cellfun(@(x) ft_preprocessing(...
          struct('dataset',x,'chantype',chantype{i})),...
          fullfile(Rec(m).folder,Rec(m).filename),'UniformOutput',false);
      Rec(m).(chantype{i})=ft_appenddata(struct('appenddim','time'),tmp{:});       
    end   
end

