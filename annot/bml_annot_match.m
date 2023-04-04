function annot = bml_annot_match(cfg, data, template)

% BML_ANNOT_MATCH matches a raw data object to a template
%
% Use as
%   annot = bml_annot_match(cfg, data, template)
%
% data - ft_datatype_raw data object to be annotated
% template - the pattern to match to
%
% cfg.threshold - double: The minimum correlation value to be assigned as a positive match
% cfg.channel - Nx1 cell-array with selection of channels (default = 'all'), see FT_CHANNELSELECTION
% cfg.template_channel - cellstr with channel of template to use
% cfg.timeeps - double, epsilon for time. Defaults to 1e-9
% cfg.scan - annotation table with ranges to scan. If not provided the
%       entire data object will be scanned
% cfg.max_annot - integer: maximun number of annotations to return
% cfg.max_annot_per_scan - integer: maximun number of annotations to
%       return per time interval scanned per channel
% cfg.warn - bool, should warnings be issued? Defaults to true
%
% returns an annotation table


%% Loading parameters
max_annot         = bml_getopt(cfg, 'max_annot', inf);
max_annot_per_scan = bml_getopt(cfg, 'max_annot_per_scan', inf);
timeeps           = bml_getopt(cfg, 'timeeps', 1e-9);
template_channel  = bml_getopt_single(cfg, 'template_channel',[]);
threshold         = bml_getopt(cfg, 'threshold', []);
scan              = bml_getopt(cfg, 'scan', table());
warn              = bml_getopt(cfg, 'warn', true);
allow_overlap     = bml_getopt(cfg, 'allow_overlap', false);
annot             = table(); %output table

%selecting channels from raw
if any(ismember({'channel'},fieldnames(cfg)))
  cfg1=[];
  cfg1.channel = cfg.channel;
  data = ft_selectdata(cfg1,data);
end

if isempty(threshold)
  error('cfg.threshold argument required')
end

%selecting channel from template
if isempty(template_channel) 
  if ~numel(template.label,1)
    error('single channel must be selected from template. Use cfg.template_channel to select one.')
  end
else
  if ~ismember(template_channel,template.label)
    error('channel %s not found in template',template_channel)
  end
  cfg=[];
  cfg.channel = template_channel;
  cfg.ft_feedback = 'no';
  cfg.showcallinfo = 'no';
  cfg.trackcallinfo = false;
  template = ft_selectdata(cfg, template);
end
if numel(template.trial) > 1
  error('template should have a single trial')
end

% verifying sampling rate of template 
template.fsample = bml_getFs(template);% round(1/mean(diff(template.time{1})));
Fs = bml_getFs(data);%round(1/mean(diff(data.time{1})));
if template.fsample ~= Fs
  cfg=[];
  cfg.resamplefs = Fs;
  template = ft_resampledata(cfg,template);
  template.fsample = Fs;
end

%normalizing template
if any(ismissing(template.trial{1}))    
    warning('Template contains nans. Masking wiht zeros.');
    cfg=[];
    cfg.value=0;
    cfg.remask_nan=1;
    cfg.complete_trial =0;
    template=bml_mask(cfg,template);
end

template_std = std(template.trial{1},'omitnan');
if template_std > eps
  template.trial{1} = (template.trial{1} - mean(template.trial{1})) ./ template_std;
else
  if warn
    warning('template has no fluctutations, cannot correlate')
  end
  return
end

if isempty(scan)
  scan = bml_raw2annot(data);
else
  cfg=[];
  cfg.keep = 'x';
  scan = bml_annot_intersect(cfg,scan, bml_raw2annot(data));
  if isempty(scan)
    if warn
      warning('No region to scan after intersecting scan with raw. Returning empty table.')
    end
    return
  end
end

%redefining trials based on scan
cfg=[];
cfg.epoch = scan;
data = bml_redefinetrial(cfg,data);

n1 = size(template.trial{1},2);
template_duration = n1/Fs;
n_annots = 0;
for s=1:numel(data.trial)
  
  %getting raw for single trial
  cfg=[];
  cfg.trials = s;
  cfg.ft_feedback = 'no';
  cfg.showcallinfo = 'no';
  cfg.trackcallinfo = false;
  data_s = ft_selectdata(cfg,data);
  
  for l=1:length(data_s.label)
    
    %doing the cross correlation
    %calculating Pearson's correlation coefficient for cross correlation
    [r, lags] = xcorr(data_s.trial{1}(l,:),template.trial{1}(1,:));
    %figure; plot(data_s.trial{1}(l,:));
    %figure; plot(template.trial{1}(1,:));
    d2u = xcorr((data_s.trial{1}(l,:)).^2,ones(1,n1));
    du  = xcorr(data_s.trial{1}(l,:),ones(1,n1));
    sqdenom = n1*d2u - du.^2;
    sqdenom(sqdenom < eps) = eps;
    r = r ./ realsqrt(sqdenom);
    mad_r = mad(r,1);

    %cropping only valid portions of xcorr
    n_s = length(data_s.trial{1}(l,:));
    if n_s >= n1
        r = r(n_s:(2*n_s-n1));
        lags = lags(n_s:(2*n_s-n1));
    else
        warning("template shorter than matching signal")
        r = r(n1:(2*n1-n_s));
        lags = lags(n1:(2*n1-n_s));
    end
        
    %detecting matches
    loop_count = 0;
    n_annots_per_scan = 0;
    search_match = true;
    while search_match
      %figure; plot(lags,r)  
      %figure; plot(data_s.time{1}, data_s.trial{1})
      %figure; plot(template.time{1}, template.trial{1})
      loop_count = loop_count + 1;
      n_annots = n_annots + 1;
      
      if n_annots > max_annot
        error('more annotations found than max_annot = %i',max_annot)
      end
      
      [max_r, max_idx] = max(r);
      max_ti = lags(max_idx)/Fs + data_s.time{1}(1); %calculating time in GTC
      max_tf = max_ti + template_duration;
      
      if max_r > threshold %match
        
        %calculating overlap with previous matches
        overlap = 0;
        for i=1:height(annot)
          if annot{i,1} <= max_tf && annot{i,2} > max_ti
            overlap = overlap + (min(max_tf,annot{i,2}) - max(max_ti,annot{i,1}))/template_duration;
          end
        end
        
        if overlap <= allow_overlap
          annot = [annot; cell2table({max_ti,max_tf,max_r,mad_r})];
          n_annots_per_scan = n_annots_per_scan + 1;
          r(max(floor(max_idx-n1/2),1):min(ceil(max_idx+n1/2),length(r)))=0;
          search_match = n_annots_per_scan < max_annot_per_scan;
        else
          r(floor(max_idx-n1/4):ceil(max_idx+n1/4))=0;
        end
      else
        search_match = false;
      end
    end
  end  
end

if ~isempty(annot)
  annot.Properties.VariableNames = {'starts','ends','max_cor','mad_cor'};
  annot = bml_annot_table(annot);
end








