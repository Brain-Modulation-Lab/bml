function spike = bml_annot2spike(cfg, annot, raw)

% BML_ANNOT2SPIKE creates a ft_datatype_spike structure from an annotation table
%
% Use as
%   spike = bml_annot2spike(cfg, annot)
%   spike = bml_annot2spike(cfg, annot, raw)
%   spike = bml_annot2spike(cfg, annot, spike_waveform)
% 
% cfg.roi - roi table used to transform the times in annot.starts to
%       timestamps (ie, samples). Required if raw is not provided. 
% cfg.waveform_extract - boolean indicating if waveforms whould be cropped
%       from raw. Defaults to false. 
% cfg.waveform_samples - integer indicating number of sample for the
%       waveforms. Defauls to 44. 
%
% annot - annotation table to transform to spike timestamps. Only the
%         starts vector is used. Normally obtained from bml_plexon2annot
% raw - ft_datatype_raw from where to use as template for the spikes
%       timestamps and to crop the snippets from. 
% spike_waveform - ft_datatype_spike as returned by ft_read_spike or
%       bml_plexon2annot. waveforms are extracted from here if available. 
%       should contain fields 'waveform' and 'label'. 
%
% returns a ft_datatype_spike structure. Each label correspons to an
% individual unit named as <channel>_<unit>. 
%
% If spike_waveform is provided, a waveform field will be present in the 
% output, where the mapping of units to waveform is based on annot.channel,
% annot.spike_idx, spike_waveform.label and spike_waveform.waveform. 
%
% If raw is provided, a waveform field will be present in the output, where the 
% mapping of snippets are extracted from the raw vector. The labels of raw
% must match annot.channel.

if nargin == 3
  assert(isstruct(raw), "Invalid third argument");
  if all(ismember({'trial','time','label'},fieldnames(raw)))
    % Usage spike = bml_annot2spike(cfg, annot, raw)
    spike_waveform = [];
  elseif	all(ismember({'waveform','label'},fieldnames(raw)))
    % Usage spike = bml_annot2spike(cfg, annot, spike_waveform)
    spike_waveform = raw;
    raw = [];
  else
    error("invalid third argument");
  end  
elseif nargin == 2
  spike_waveform = [];  
	raw = [];
else
  error("Incorrect number of arguments");
end

roi = bml_getopt(cfg,'roi');
if isempty(roi) 
  if ~isempty(raw)
    roi = bml_raw2annot(raw);
  else
    error("cfg.roi or raw required");
  end
end

annot = bml_annot_table(annot);
assert(all(ismember({'channel','unit'},annot.Properties.VariableNames)),...
  "channel and unit columns required in annot");

waveform_extract = bml_getopt(cfg,'waveform_extract',false);
waveform_samples = bml_getopt(cfg,'waveform_samples',44);

has_spike_idx = ismember({'spike_idx'},annot.Properties.VariableNames);

spike=struct();
spike.timestamp=[];
spike.label=[];
spike_idx=[];
channel=[];

lev_channel = unique(annot.channel);
for i_ch=1:length(lev_channel)
  ch_annot = annot(strcmp(annot.channel,lev_channel(i_ch)),:);
  lev_unit = unique(ch_annot.unit);
  for i_u=1:length(lev_unit)
    u_ch_annot = ch_annot(ch_annot.unit==lev_unit(i_u),:);
    spike.timestamp = {spike.timestamp, bml_time2idx(roi,u_ch_annot.starts)};
    spike.label = {spike.timestamp, strcat(lev_unit(i_ch),'_',u_ch_annot(i_u))};
    if has_spike_idx
      spike_idx = {spike_idx, u_ch_annot.spike_idx};
      channel = {channel, lev_unit(i_ch)};
    end
  end
end

if has_spike_idx && ~isempty(spike_waveform)
  %getting waveforms from spike_waveform
  spike.waveform=cell(1,length(spike_idx));
  for i_wf=1:length(spike_idx)
    orig_wf_idx = bml_getidx(channel(i_wf),spike_waveform.label);
    spike.waveform(1,i_wf) = spike_waveform.waveform{orig_wf_idx}(spike_idx{i_wf},:);
  end
end

if ~isempty(raw) && waveform_extract
  error("waveform extraction not implemented yet");
end








