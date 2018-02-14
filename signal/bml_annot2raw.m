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
elseif isstruct(cfg) && all(ismember({'trial','time','label'},fields(cfg)))  
	cfg = struct('template',cfg);
end
roi         = bml_getopt(cfg,'roi');
template    = bml_getopt(cfg,'template');

annot = bml_annot_table(annot,[],inputname(2));
assert(isempty(bml_annot_overlap(annot)),'annot contains overlaps');
assert(~isempty(roi) || ~isempty(template),'cfg.roi or cfg.template required');

%creating raw
if isempty(template) %from roi
  roi = bml_sync_consolidate(bml_roi_confluence(roi));
  assert(height(roi)==1,"can't deal with more than one sync chunk after consolidation for now");
  raw=[];
  raw.time={bml_idx2time(roi,roi.s1:roi.s2)};
  raw.trial={zeros(1,size(raw.time{1},2))};
  raw.fsample=roi.Fs;
else %from trmplate
  raw = template;
  raw.time=raw.time(1);
  raw.trial={zeros(1,size(raw.time{1},2))};
  roi = bml_raw2coord(raw);
end

if all(annot.duration==0)
  annot = bml_annot_extend(annot,mean(diff(raw.time{1}))/2);
end

description = annot.Properties.Description;
if isempty(description); description = 'annot'; end
raw.label={description};

for i=1:height(annot)
  [s,e] = bml_crop_idx_valid(roi,annot.starts(i), annot.ends(i));
  raw.trial{1}(1,s:e)=1;
end






