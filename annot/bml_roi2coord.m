function coord = bml_roi2coord(cfg, roi)

% BML_ROI2COORD calculates raw coordinates for entries in roi
%
% Use as
%   coord = bml_roi2coord(roi)
%   coord = bml_roi2coord(cfg, roi)
%
% roi - roi table with one or several rows for contiguous files (e.g.
%       neuroomega)
% cfg.timetol - double, time tolerance in seconds, defaults to 1e-3
%
% returns a coord struct with elements s1, s2, t1, t2, nSamples

if nargin==1
  if istable(cfg)
    cfg = struct('roi',cfg);
  end
elseif nargin~=2
  error('incorrect number of arguments');
end
  
roi      = bml_getopt(cfg,'roi');
timetol  = bml_getopt(cfg,'timetol',1e-3);

assert(~isempty(roi),'non-empty roi required');

roi.filetype_chantype = strcat(roi.filetype,roi.chantype,num2str(roi.Fs));
assert(length(unique(roi.filetype_chantype))==1,...
  'rows in roi belong to files of different type');

%detecting contiguos stretches
cfg=[];
cfg.criterion = @(x) sum(x.duration)-max(x.ends)+min(x.starts) < height(x)*timetol;
roi_cont = bml_annot_consolidate(cfg,roi);   

assert(height(roi_cont)==1,'files in roi are not time contiguous');

if height(roi)>1
        
  %calculating raw samples of contiguous file
  cs = cumsum(roi.s2-roi.s1) + roi.s1(1);
  cs = cs + (0:(height(roi)-1))';
  cs = [0; cs(1:end-1)];
  roi.raw1 = roi.s1 + cs;
  roi.raw2 = roi.s2 + cs;

  %doing linear fit to asses if consolidation is plausible
  s = [roi.raw1; roi.raw2];
  t = [roi.t1; roi.t2];
  p = polyfit(s,t,1);
  tfit = polyval(p,s);

  if max(abs(t - tfit)) <= timetol %consolidating
    roi.t1 = polyval(p,roi.raw1);
    roi.t2 = polyval(p,roi.raw2);
  else  
    warning('can''t consolidate within tolerance');
  end

else
  roi.raw1 = roi.s1;
  roi.raw2 = roi.s2;
end

coord = [];
coord.s1 = min(roi.raw1);
coord.s2 = max(roi.raw2);
coord.t1 = min(roi.t1);
coord.t2 = max(roi.t2);
coord.nSamples = sum(roi.raw2 - roi.raw1 + 1);

assert(coord.nSamples == coord.s2 - coord.s1 + 1, 'inconsistent coord');





