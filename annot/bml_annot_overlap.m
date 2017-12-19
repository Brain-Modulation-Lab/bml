function overlap=bml_annot_overlap(cfg, annot)

% BML_ANNOT_OVERLAP calculates overlapping segments between annotations
%
% Use as
%   overlap=bml_annot_overlap(cfg, annot)
%   overlap=bml_annot_overlap(annot)
%
% cfg is a configuration structure
% cfg.timetol = time tolerance in seconds. Defaults to 1e-5.
%               useful to avoid detecting contiguity as overlaps due to
%               numeric issues.

if nargin == 1
  annot = cfg;
  cfg=[];
elseif nargin ~= 2
  error('incorrect number of arguments');
end

timetol = bml_getopt(cfg,'timetol',1e-5);
annot = bml_annot_table(annot);

i=1; j=2;
overlap = cell2table(cell(0,4)); 
overlap.Properties.VariableNames = {'starts','ends','id1','id2'};
while i<=height(annot) && j<=height(annot)
  %if annot.starts(i) < annot.ends(j) && annot.ends(i) > annot.starts(j)
  if annot.ends(j) - annot.starts(i) > timetol && ...
     annot.ends(i) - annot.starts(j) > timetol
    overlap = [overlap;{...
      max(annot.starts(i),annot.starts(j)),...
      min(annot.ends(i),annot.ends(j)),...
      annot.id(i),...
      annot.id(j)}];
      j = j + 1;
  elseif annot.ends(i) - annot.starts(j) <= timetol
    i=i+1;
    j=i+1;
  elseif annot.ends(j) - annot.starts(i) <= timetol
    j=j+1;
  else
    annot([i j],:)
    error('Unsupported input annotations tables');
  end
end
