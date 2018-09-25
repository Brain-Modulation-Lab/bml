function raw = bml_annot2raw(cfg, annot)

% BML_ANNOT2RAW creates a ft_datatype_raw of zeros with ones at annot times
% 
% Use as
%   raw = bml_annot2raw(cfg, annot)
%   raw = bml_annot2raw(cfg.roi, annot)
%   raw = bml_annot2raw(cfg.template, annot)
%   raw = bml_annot2raw(cfg)
%   raw = bml_annot2raw(cfg.roi)
%   raw = bml_annot2raw(cfg.template)
%
% cfg.roi - roi table from which to construct raw
% cfg.label - cellstr, names of channels in new raw. Defaults to 'annot'
% cfg.annot_label - string, indicates channel on which events should be
%     added. Defaults to cfg.label{1}. 
% cfg.annot_label_colname - cellstr, indicating name of column of annot
%     containging the channel's label the current annotation should be
%     added to. If not given, all annotations are added 
%     to same channel defined by annot_label.  
% cfg.template - raw to use as template
% annot - annotation table. If omitted a raw of zeros is returned.
%
% returns a FT_DATAYE_RAW structure with ones during the annotations

if istable(cfg)
  cfg = struct('roi',cfg);
elseif isstruct(cfg) && all(ismember({'trial','time','label'},fieldnames(cfg)))  
	cfg = struct('template',cfg);
end
roi         = bml_getopt(cfg,'roi');
template    = bml_getopt(cfg,'template');
label       = bml_getopt(cfg,'label',{'annot'});

assert(~isempty(roi) || ~isempty(template),'cfg.roi or cfg.template required');

%creating raw
if ~isempty(roi) %from roi
  raw=[];
  raw.time=cell(1,height(roi));
  raw.trial=cell(1,height(roi));
  raw.fsample=roi.Fs(1);
  raw.label = label;
  assert(length(unique(roi.Fs))==1, "Inconsistent Fs in roi");
  for i=1:height(roi)
    %assert(height(roi)==1,"can't deal with more than one sync chunk after consolidation for now");
    raw.time{i}=bml_idx2time(roi(i,:),roi.s1(i):roi.s2(i));
    raw.trial{i}=zeros(length(label),size(raw.time{1},2));
  end
elseif ~isempty(template) %from template
  raw = template;
  for i=1:length(raw.trial)
    raw.trial{i}=zeros(length(label),size(raw.time{i},2));
  end
  roi = bml_raw2annot(raw);
else
  error('cfg.roi or cfg.template required');
end

if nargin == 2
  annot = bml_annot_table(annot,[],inputname(2));
  
  % assert(isempty(bml_annot_overlap(annot)),'annot contains overlaps');
  % if all(annot.duration==0)
  %   annot = bml_annot_extend(annot,mean(diff(raw.time{1}))/2);
  % end
  
  description = annot.Properties.Description;
  if isempty(description) 
    description = 'annot';
  end
  if length(raw.label)==1 && strcmp(raw.label{1},'annot')
    raw.label={description};
  end
  
  annot_label_colname = bml_getopt(cfg,'annot_label_colname',[]);
  
  %assigning all annotation to same channel of raw
  if isempty(annot_label_colname)
    annot_label	= bml_getopt(cfg,'annot_label',raw.label{1});
    annot_idx   = bml_getidx(annot_label,raw.label);

    for t=1:height(roi)
      t_annot = bml_annot_filter(annot,roi(t,:));
      for i=1:height(t_annot)
        [s,e] = bml_crop_idx_valid(roi(t,:), t_annot.starts(i), t_annot.ends(i));
        raw.trial{t}(annot_idx,s:e)=1;
      end
    end
    
  else %annotations assing to specific channels
    if ~any(strcmp(annot.Properties.VariableNames, annot_label_colname))
      error('annot_label_colname should match a column of annot');
    end
    %iterating over labels of annot_label_colname
    ul = unique(annot{:,annot_label_colname});
    for i_ul=1:numel(ul)
      annot_l = annot(strcmp(annot{:,annot_label_colname},ul{i_ul}),:);
      annot_idx = bml_getidx(ul{i_ul},raw.label);

      for t=1:height(roi)
        t_annot_l = bml_annot_filter(annot_l,roi(t,:));
        for i=1:height(t_annot_l)
          [s,e] = bml_crop_idx_valid(roi(t,:), t_annot_l.starts(i), t_annot_l.ends(i));
          raw.trial{t}(annot_idx,s:e)=1;
        end
      end
      
    end    
  end
end




