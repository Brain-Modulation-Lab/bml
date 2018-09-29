function info = bml_neuroomega_info_depth(cfg)

% BML_NEUROOMEGA_INFO_DEPTH returns a table with .mat file information
% aggregated by depth. Useful to select relevant depths
%
% Use as
%   info = bml_neuroomega_info_depth(cfg)
%
% where cfg is a configureation struct with the following fields
% cfg.path - string: path where to look for the .mat files
% cfg.sort - string: variable by which to sort the output table
% cfg.direction - string: either 'descend' (default) or 'ascend'
%
% Returns a table with variables
%   depth - double: position of the record in mm
%   files - double: number of files at this depth
%   size - double: aggregated size of all files in MB

% 2017.10.13 AB

sortvar = ft_getopt(cfg,'sort','depth');
direction = ft_getopt(cfg,'direction','descend');

files = bml_neuroomega_info_file(cfg);
files.size = files{:,'bytes'}/1e6;

info=varfun(@(x)round(sum(x),1),files,'InputVariables','size',...
       'GroupingVariables','depth');
if ismember('time_begin', files.Properties.VariableNames)
  info=join(info,...
    varfun(@min,files,'InputVariables','time_begin',...
       'GroupingVariables','depth')...
    ,'Keys','depth');
end
if ismember('time_end', files.Properties.VariableNames)
  info=join(info,...
    varfun(@max,files,'InputVariables','time_end',...
       'GroupingVariables','depth')...
    ,'Keys','depth');
end
if all(ismember({'time_begin','time_end'}, files.Properties.VariableNames))
  files.file_duration=files.time_end-files.time_begin;
  info=join(info,...
    varfun(@sum,files,'InputVariables','file_duration',...
       'GroupingVariables','depth')...
    ,'Keys','depth');
  info.duration=info.max_time_end-info.min_time_begin;
  info.contiguous=info.sum_file_duration > 0.99 * info.duration;
end

if ismember('GroupCount_info', info.Properties.VariableNames)
  info.Properties.VariableNames{'GroupCount_info'} = 'files';
elseif ismember('GroupCount', info.Properties.VariableNames)
  info.Properties.VariableNames{'GroupCount'} = 'files';  
end

%Eliminating GroupCounts
info(:,strncmp('GroupCount',info.Properties.VariableNames,10))=[]

info.Properties.VariableNames{'Fun_size'} = 'size';
%info.Properties.VariableUnits = {'mm' '#' 'MB'};

info=sortrows(info,sortvar,direction);







