function annot = bml_annot_calculate2(cfg, raw, varargin)

% BML_ANNOT_CALCULATE2 calculates scalar values from 2 specific annotations in raw
%
% Use as
%    annot = bml_annot_calculate2(cfg, raw, 'feature_1_name', feature_1_fun,
%                                           'feature_2_name', feature_2_fun,...)
%
% raw - FT_DATAYPE_RAW in global time coordinates to be used for calculation
% feature_1_name - string with column name for new feature
% feature_1_fun - function handle to calculate feature 1
% feature_2_name - string with column name for new feature
% feature_2_fun - function handle to calculate feature 2
% cfg - configuraton structure
% cfg.epoch - table with epochs on which to calculate the feature. Required columns are
%           for cross-channel only: id, starts, ends, duration, channel1, channel2 OR 
%           for cross-epoch&channel: id1, starts1, ends1, duration1, channel1, id2, starts2, ends2, duration2, channel2. 
% cfg.warn - logical indicating if warnings should be issued. Defaults to true
% cfg.minduration - minimal duration in seconds of epoch on which to calculate the
%          feature. Defaults to 0.001.
% cfg.timetol - float. Tolerance in seconds for determining unique epochs. 
%          Defaults to 0.001.
%
% returns the epoch table with new features calculated from raw

warn        = bml_getopt(cfg,'warn',true);
minduration = bml_getopt(cfg,'minduration',0.001);
epoch_orig  = bml_getopt(cfg,'epoch',[]);
annot_pair_id_present = ismember('annot_pair_id',epoch_orig.Properties.VariableNames);
timetol     = bml_getopt(cfg,'timetol',0.001);
if ~annot_pair_id_present
  epoch_orig.annot_pair_id = (1:height(epoch_orig))';
end
epoch = epoch_orig;

assert(~isempty(epoch),'epoch table required');

if all(ismember({'id1','starts1','ends1','duration1','channel1','id2','starts2','ends2','duration2','channel2'},...
    epoch.Properties.VariableNames))
  fprintf('Binary calculation across channels and epochs.\n');
elseif all(ismember({'id','starts','ends','duration','channel1','channel2'},epoch.Properties.VariableNames))
  fprintf('Binary calculation across channels, same epochs.\n');
  epoch2 = epoch(:,{'id','starts','ends','duration'});
  epoch2.Properties.VariableNames = {'id2','starts2','ends2','duration2'};
  epoch = bml_annot_rename(epoch,'id','id1','starts','starts1','ends','ends1','duration','duration1');
  epoch = [epoch, epoch2];
else
  error('required columns of epoch missing');
end

assert(all(ismember({'id1','starts1','ends1','channel1'},epoch.Properties.VariableNames)),...
  'One or more of the required variables id1, starts1, ends1, channel1 is missing from epoch table');
assert(all(ismember({'id2','starts2','ends2','channel2'},epoch.Properties.VariableNames)),...
  'One or more of the required variables id2, starts2, ends2, channel2 is missing from epoch table');

%removing rows with nans
rowhasnan = isnan(epoch.starts1) | isnan(epoch.ends1) | isnan(epoch.starts2) | isnan(epoch.ends2);
if sum(rowhasnan) > 0
  warning('removing %i rows with nans',sum(rowhasnan));
  epoch = epoch(~rowhasnan,:);
end

%mapping epochs to unqiue epochs
fprintf('Obtaining unique epochs...\n');
ueid_db1 = epoch(:,{'id1','starts1','ends1','channel1'});
ueid_db1.Properties.VariableNames = {'id','starts','ends','channel'};
ueid_db1.operand(:) = 1;
ueid_db2 = epoch(:,{'id2','starts2','ends2','channel2'});
ueid_db2.Properties.VariableNames = {'id','starts','ends','channel'};
ueid_db2.operand(:) = 2;
ueid_db = [ueid_db1; ueid_db2];

[C, ~, IC] = uniquetol(table2array(ueid_db(:,{'starts','ends'})),timetol,...
          'ByRows',1,'DataScale',1,'OutputAllIndices',true);

%creating raw with unique trials
C = array2table(C(~any(isnan(C),2),:),'VariableNames',{'starts','ends'});
C.id = (1:height(C))';
C = bml_annot_table(C);
cfg1=[];
cfg1.epoch = C;
cfg1.warn = warn;
[ue_raw, ue_db] = bml_redefinetrial(cfg1,raw);

% mapping index in ue_raw to original epoch table
ueid_db.ueid(:) = bml_map(IC,ue_db.epoch_id,ue_db.id,NaN); %index match ue_raw
ueid_db1.ueid(:) = ueid_db.ueid(ueid_db.operand == 1);
ueid_db2.ueid(:) = ueid_db.ueid(ueid_db.operand == 2);    
epoch.ueid1(:) = ueid_db1.ueid;
epoch.ueid2(:) = ueid_db2.ueid;

epoch = epoch(:,{'annot_pair_id','ueid1','duration1','channel1','ueid2','duration2','channel2'});
epoch = epoch(~(ismissing(epoch.ueid1)|ismissing(epoch.ueid2)),:); 

if nargin < 4
  error('at least one feature name and function required')
elseif mod(nargin,2)~=0 
  error('uneven number of arguments. Pairs of feature names and functions required')
else
  nfeatures = (nargin - 2)/2;
end
 
for i=1:nfeatures
  feature_name = cellstr(varargin{(i-1)*2+1});
  feature_fun = varargin{(i-1)*2+2};
% 	textprogressbar(sprintf('Calculating feature %s - ',feature_name{1}));
%  n_progress = floor(height(epoch)/100);
  feature = nan(height(epoch),numel(feature_name));
  for t=1:height(epoch)
%     if mod(t,n_progress) == 0
%       textprogressbar(round(100 .* t ./ height(epoch)))
%     end
    if (epoch.duration1(t) > minduration) && (epoch.duration2(t) > minduration)
      trial1 = ue_raw.trial{epoch.ueid1(t)};
      vec1   = trial1(bml_getidx(epoch.channel1(t),ue_raw.label),:);
      trial2 = ue_raw.trial{epoch.ueid2(t)};
      vec2   = trial2(bml_getidx(epoch.channel2(t),ue_raw.label),:);
      try
        feature(t,:)=feature_fun(vec1,vec2);
      catch 
        warning("%s failed on trial %i \n",feature_name{1},t)
      end
    end
  end
 
  for j=1:numel(feature_name)
    epoch.(feature_name{j}) = feature(:,j);
  end
% 	textprogressbar('done')   
end

annot = outerjoin(epoch_orig,epoch(:,[1,7:end]),'Type','left','Keys','annot_pair_id','MergeKeys',true);

if ~annot_pair_id_present
  annot.annot_pair_id = [];
end



