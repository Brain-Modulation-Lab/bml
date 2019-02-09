function confluent = bml_roi_confluence(cfg)

% BML_ROI_CONFLUENCE expands entries in a roi table to cover all the file
%
% Use as
%   confluent = bml_roi_confluence(roi)
%   confluent = bml_roi_confluence(cfg)
%
% cfg.roi - roi table
% cfg.complete - logical, should the file coverage be completed at begging
%   and end. Defaults to true.
% cfg.modify_coord - logical, indicating if file coordinates should be
%   modified. Defautlts to false. 
%
% Modifies starts and ends of roi to cover all the file, for each file.
% Requires variable nSamples and Fs. Only modifies file coords if
% cfg.modify_coord = true. 

if istable(cfg)
  cfg = struct('roi',cfg);
end
complete = bml_getopt(cfg,'complete',true);
modify_coord = bml_getopt(cfg,'modify_coord',false);

roi = bml_roi_table(bml_getopt(cfg,'roi'));
roi.fullfile = fullfile(roi.folder,roi.name);
uff = unique(roi.fullfile); %unique fullfile
confluent = table();

for i_uff=1:length(uff)
  i_roi = roi(strcmp(roi.fullfile,uff(i_uff)),:);
  
  %first
  if complete
    i_roi.starts(1) = bml_idx2time(i_roi(1,:),1) - 0.5 ./ i_roi.Fs(1);
  end

  %middle
  for i=1:(height(i_roi)-1)
    midpoint = (i_roi.t2(i) + i_roi.t1(i+1))/2;
    i_roi.ends(i) = midpoint;
    i_roi.starts(i+1) = midpoint;
  end

  %last
  if complete
    i_roi.ends(end) = bml_idx2time(i_roi(end,:),i_roi.nSamples(end)) + 0.5 ./ i_roi.Fs(end);
  end
  
  if modify_coord && complete
    if height(i_roi) > 1
      error('several entries for file %s. Try consolidating.',uff(i_uff))
    end
    i_roi_orig = i_roi;
    i_roi.s1(1) = 1;
    i_roi.t1(1) = bml_idx2time(i_roi_orig,1);
    i_roi.s2(1) = i_roi_orig.nSamples(1);
    i_roi.t2(1) = bml_idx2time(i_roi_orig,i_roi_orig.nSamples(1));
  end
  
  confluent = [confluent; i_roi];
end

confluent = bml_roi_table(confluent);

