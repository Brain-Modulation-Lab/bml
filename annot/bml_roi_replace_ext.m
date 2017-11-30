function replaced_roi = bml_roi_replace_ext(cfg, roi)

% BML_ROI_REPLACE_EXT replaces the extension in a variable
%
% Use as 
%   replaced_roi = bml_roi_replace_ext(cfg, roi)
%   replaced_roi = bml_roi_replace_ext(cfg.new, roi)
%
% cfg.new   - char: new extension
% cfg.old   - char: optional old extension
% cfg.variable - char: variable on which to chanche extension ('name' by default)
%
% returns a roi table with extensions replaced where appropiate

if ischar(cfg) || isstring(cfg) || iscellstr(cfg)
  cfg = struct('new', cellstr(cfg));
end

new = bml_getopt(cfg,'new');
old = bml_getopt(cfg,'old','*');
variable = bml_getopt(cfg,'variable','name');

assert(~isempty(new),'new extension required')

for i=1:height(roi)
  i_var = roi{i,variable};
  [filepath,name,ext]=fileparts([i_var{:}]);
  rx=regexp(ext,regexptranslate('wildcard',old),'match');
  if ~isempty(rx)
    name = strcat(name,'.',new);
  end
  roi{i,variable} = fullfile(filepath,name);  
end

replaced_roi=roi;






