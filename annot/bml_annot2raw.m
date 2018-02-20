function raw = bml_annot2raw(cfg, annot)

% BML_ANNOT2RAW creates a raw of zeros with ones at annot times
% 
% Use as
%   raw = bml_annot2raw(cfg, annot)
%   raw = bml_annot2raw(cfg.roi, annot)
%   raw = bml_annot2raw(cfg.template, annot)
%
% cfg.roi - roi table from which to construct raw
% cfg.template - raw to use as template
%
% returns a FT_DATAYE_RAW structure with ones during the annotations

if istable(cfg)
  cfg = struct('roi',cfg);
elseif isstruct(cfg) && all(ismember({'trial','time','label'},fieldnames(cfg)))  
	cfg = struct('template',cfg);
end
roi         = bml_getopt(cfg,'roi');
template    = bml_getopt(cfg,'template');

annot = bml_annot_table(annot,[],inputname(2));
assert(isempty(bml_annot_overlap(annot)),'annot contains overlaps');
assert(~isempty(roi) || ~isempty(template),'cfg.roi or cfg.template required');

%creating raw
if ~isempty(roi) %from roi
  raw=[];
  raw.time=cell(1,height(roi));
  raw.trial=cell(1,height(roi));
  raw.fsample=roi.Fs(1);
  assert(length(unique(roi.Fs))==1, "Inconsistent Fs in roi");
  for i=1:height(roi)
    %assert(height(roi)==1,"can't deal with more than one sync chunk after consolidation for now");
    raw.time{i}=bml_idx2time(roi(i,:),roi.s1(i):roi.s2(i));
    raw.trial{i}=zeros(1,size(raw.time{1},2));
  end
elseif ~isempty(template) %from template
  raw = template;
  for i=1:length(raw.trial)
    raw.trial{i}=zeros(1,size(raw.time{i},2));
  end
  roi = bml_raw2annot(raw);
else
  error('cfg.roi or cfg.template required');
end

% if all(annot.duration==0)
%   annot = bml_annot_extend(annot,mean(diff(raw.time{1}))/2);
% end

description = annot.Properties.Description;
if isempty(description); description = 'annot'; end
raw.label={description};

for t=1:height(roi)
  t_annot = bml_annot_filter(annot,roi(t,:));
  for i=1:height(t_annot)
    [s,e] = bml_crop_idx_valid(roi(t,:), t_annot.starts(i), t_annot.ends(i));
    raw.trial{t}(1,s:e)=1;
  end
end




