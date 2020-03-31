
function annot = bml_annot_calculate(cfg, raw, varargin)

% BML_ANNOT_CALCULATE calculate scalar values from specific annotations in
% raw
%
% Use as
%    annot = bml_annot_calculate(cfg, raw, 'feature_1_name', feature_1_fun,
%                                          'feature_2_name', feature_2_fun,...)
%
% raw - FT_DATAYPE_RAW in global time coordinates to be used for calculation
% feature_1_name - string with column name for new feature
% feature_1_fun - function handle to calculate feature 1
% feature_2_name - string with column name for new feature
% feature_2_fun - function handle to calculate feature 2
% cfg - configuraton structure
% cfg.epoch - ANNOT table with epochs on which to calculate the feature
%          if not provided, the epochs are determined by the raw structure.
%          if a channels column is present, it use to select the channel
%          for each annotation
%
% returns an annotation table with new features calculated from raw

epoch = bml_annot_table(bml_getopt(cfg,'epoch',[]),'epoch');
if isempty(epoch)
	epoch = bml_raw2annot(raw);
  eraw = raw;
else
  cfg1=[];
  cfg1.epoch = epoch;
  [eraw, epoch] = bml_redefinetrial(cfg1,raw);
end

if ~ismember('channel',epoch.Properties.VariableNames)
  if length(eraw.label) == 1
    epoch.channel = repmat(eraw.label,height(epoch),1);
  else
    error('No channel column provided in cfg.epoch and more than one label present in raw')
  end
end

if nargin < 4
  error('at least one feature name and function required')
elseif mod(nargin,2)~=0 
  error('uneven number of arguments.Pairs of feature names and functions required')
else
  nfeatures = (nargin - 2)/2;
end
 
for i=1:nfeatures
  feature_name = varargin{(i-1)*2+1};
  feature_fun = varargin{(i-1)*2+2};
  
  if ~ismember(feature_name,epoch.Properties.VariableNames)
    epoch.(feature_name) = repmat({nan},height(epoch),1);
  end
  
  for t=1:numel(eraw.trial)
    trial = eraw.trial{t};
    try
      epoch{t,feature_name}={feature_fun(trial(bml_getidx(epoch.channel(i),eraw.label),:))};
    catch 
      warning("%s failed on trial %i \n",feature_name,t)
    end
  end
end

annot = epoch;
