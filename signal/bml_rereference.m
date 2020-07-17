function [ref,U] = bml_rereference(cfg,raw)

% BML_REREFERENCE applies re-referencing scheme to raw
%
% Use as
%   [ref,U] = bml_rereference(cfg,raw)
%
% cfg.label - Nx1 cellstr with labels. Defaults to raw.label
% cfg.group - Nx1 integer array identifying groups of electrodes
%   contacts of same group are re-referenced together
%   values <=0 and nans are not re-referenced. 
%   If not specified, groups are defined by string before underscore '_'
%   (i.e. ecog_*, micro_*, macro_*, audio_*, envaudio_*, etc)
% cfg.method - string, method to be implemented
%   'CAR', common average referencing (default)
%   'CARCF', common average referencing with cross fading
%   'CMR', common median referencing
%   'CTAR', common trimmed average referencing
%   'LAR', local average referencing
%   'VAR', variable average referencing
%   'bipolar', bipolar referencing
% cfg.percent - numeric, indicates percentage of labels in group used in
%   trimmed mean. Defaults to 50. 
% cfg.crossfading_width - scalar. Width in samples of the crossfading
%   region. Defaults to 100;
% cfg.refchan - either cellstr with label to use a reference for all
%   other channels, or table with label and reference column for custom
%   bipolar referencing montage
% cfg.refkeep - bool indicating if reference channels should be kept 
%
% raw - ft_datatype_raw to be re-referenced
% 
% Returns
% ref - ft_datatype_raw with re-referenced data
% U - double, unmixing matrix. ref = U * raw

assert(isstruct(raw),"invalid raw");
assert(all(ismember({'trial','time','label'},fieldnames(raw))),"invalid raw");

label     = bml_getopt(cfg,'label',raw.label);
group     = bml_getopt(cfg,'group');
method    = bml_getopt_single(cfg,'method','CAR');
percent   = bml_getopt(cfg,'percent',50);
crossfading_width = bml_getopt(cfg,'crossfading_width',100);

%checking for NaNs in data
raw_has_nan = any(cellfun(@(x) any(any(isnan(x),1),2),raw.trial));

assert(size(label,1)>=size(label,2),"label cell array should be Nx1, not 1xN")

%inferring groups from labels
if isempty(group)
  sl=split(label,'_');
  sl=sl(:,1);
  usl=unique(sl);
  group = bml_map(sl,usl,1:length(usl));
end

%assigning orphan raw labels to null group
in=ismember(raw.label,label);
if ~all(in)
  label = [label;raw.label(~in)];
  group = [group; zeros(sum(~in),1)];
end

%re-ordering group to match raw.label
assert(length(group)==length(label),'cfg.label and cfg.group should be of same length');
group = bml_map(raw.label,label,group);
label = raw.label;

%creating null group
group(ismissing(group))=0;
group(group<=0)=0;
g0 = sum(group<=0);

%keeping original order
[g,g_idx]=sort(group);
ug = unique(g);
[N,~] = histc(g,ug);

if ~raw_has_nan && ismember(method,{'CAR','LAR','VAR'})
  
  %% matrix multiplication based methods  
    
  %creating blocks
  if ismember(method,{'CAR'})
    U_blocks=cellfun(@bml_comavgref_matrix,num2cell(N),'UniformOutput',false);
  elseif ismember(method,{'LAR'})
    U_blocks=cellfun(@bml_locavgref_matrix,num2cell(N),'UniformOutput',false);
  elseif ismember(method,{'VAR'})
    warning('Using experimental method VAR, susceptible to high amplitude artifacts')

    %calculating variance-covariance matrix
    cfg1=[];
    cfg1.covariance = 'yes';
    cfg1.vartrllength = 2;
    tl_raw=ft_timelockanalysis(cfg1,raw);

    %grouping matrix into blocks
    COVs = cell(length(ug),1);
    for i=1:length(ug)
      COVs{i,1}=tl_raw.cov(g_idx(g==ug(i)),g_idx(g==ug(i)));
    end

    %creating blocks
    U_blocks=cellfun(@bml_varavgref_matrix,COVs,'UniformOutput',false);

  else
    error('unknown method')
  end

  %replacing block by identity for null group
  if g0 > 0
    U_blocks{1} = eye(N(1));
  end

  %joining blocks
  U = blkdiag(U_blocks{:});
  U(g_idx,g_idx) = U;
  %image(U,'CDataMapping','scaled')

  %applying unmixing matrix to data
  ref = bml_apply(@(x) U*x, raw);

else
  
  %% explicit substraction based methods
    
  %removing null group 
  ug = ug(ug>0);
  
  %% Common Average Reference
  if ismember(method,{'CAR','common'}) %common average referencing
    ref = raw;
    for t=1:numel(raw.trial)
      for g=1:numel(ug)
        %calculating groups common average
        commavg = nanmean(raw.trial{t}(group==ug(g),:),1);
        ref.trial{t}(group==ug(g),:) = raw.trial{t}(group==ug(g),:) - commavg;
      end
    end
    
  %% Common Trimmed Average Reference 
  elseif ismember(method,{'CTAR'})
    ref = raw;
    for t=1:numel(raw.trial)
      for g=1:numel(ug)
        %calculating groups common trimmed average
        commtrimmean = trimmean(raw.trial{t}(group==ug(g),:),percent,1);
        ref.trial{t}(group==ug(g),:) = raw.trial{t}(group==ug(g),:) - commtrimmean;
      end
    end  
    
  %% Common Average Reference with Cross-Fading
  elseif ismember(method,{'CARCF'}) %common average referencing with cross fading
    cfp = linspace(0,1,ceil(crossfading_width/2)); %crossfading pattern
    cfp = [cfp, fliplr(cfp(2:end))]; 
    cfp = cfp ./ sum(cfp);
    cfr = ones(size(cfp)); %crossfading region
    cfr = cfr ./ sum(cfr);
    
    ref = raw;
    for t=1:numel(raw.trial)
      %get nan mask
      cf_weights = isnan(raw.trial{t});
      
      %implementing justification of crossfading by extending nan mask
      cf_weights = convn(cf_weights, cfr, 'same');
      cf_weights = cf_weights > 0;

      %calculating crossfading weights
      cf_weights = 1 - convn(cf_weights, cfp, 'same');
      
      for g=1:numel(ug)
        %calculating groups common average
        tr = raw.trial{t}(group==ug(g),:);
        tr(isnan(tr)) = 0;
        tw = cf_weights(group==ug(g),:);
        commavg = sum(tr .* tw,1) ./ sum(tw,1);
        ref.trial{t}(group==ug(g),:) = raw.trial{t}(group==ug(g),:) - commavg;
      end
    end 
    
 
    
     %% Common Median Reference 
  elseif ismember(method,{'CMR'})
    ref = raw;
    for t=1:numel(raw.trial)
      for g=1:numel(ug)
        %calculating groups common median 
        commmed = nanmedian(raw.trial{t}(group==ug(g),:),1);
        ref.trial{t}(group==ug(g),:) = raw.trial{t}(group==ug(g),:) - commmed;
      end
    end  
    
  %% Bipolar Reference 
  elseif ismember(method,{'bipolar'})
    %loading label again from cfg
    label   = bml_getopt(cfg,'label',raw.label);
    refchan = bml_getopt(cfg,'refchan',[]); 
    
    %defining reference for each channel to be re-referenced
    if isempty(refchan)
      error('reference channel(s) required for bipolar referencing')
    elseif numel(refchan)==1
      reftable = table(label);
      reftable.reference(:) = refchan;
    elseif numel(refchan) == numel(label)
      reftable = table(label);
      reftable.reference = refchan;
    else
      error('refchan should have one element, or same number of elements as label');
    end
    
    ref = raw;
    for t=1:numel(raw.trial)
      for j=1:height(reftable)
        ref.trial{t}(ismember(ref.label,reftable.label(j)),:) = ...
          raw.trial{t}(ismember(raw.label,reftable.label(j)),:) - ...
          raw.trial{t}(ismember(raw.label,reftable.reference(j)),:);
      end
    end  
    
    if ~bml_getopt(cfg,'refkeep',0)
      %removing reference channels
      cfg1=[];
      cfg1.channel = setdiff(ref.label, unique(reftable.reference));
      ref = ft_selectdata(cfg1, ref);
    end
    
  elseif ismember(method,{'LAR','local'})
    error('local average referencing not implemented for data with NaNs')
  elseif ismember(method,{'VAR','variable'})
    error('variable average referencing not implemented for data with NaNs')
  else
    error('unknown method')
  end
end



