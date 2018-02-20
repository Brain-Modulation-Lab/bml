function bml_defaults

% BML_DEFAULTS loads requried directories to Matlab's path

BML_FOLDERS = {'signal','annot','sync','io','utils','doc'};

bmlPath = fileparts(mfilename('fullpath')); % get the full path to this function, strip away 'ft_defaults'
%bmlPath = strrep(bmlPath, '\', '\\');

for i=1:numel(BML_FOLDERS)
  i_path = [bmlPath filesep BML_FOLDERS{i}];
  if isempty(regexp(path, i_path, 'once'))
    addpath(i_path);
  end
end

format long;