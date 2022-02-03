function hour=bml_gtc2str(gtc,formatstr)

% BML_GTC2STR transforms a (cell-array) of floats representing seconds in GTC 
% to a string of format 'dd:hh:mm:ss.SSS'
%
% gtc - float or {N,1} cell array with floats in the global time coords
% formatstr - string representing output format time of day. Defalts to 'dd:hh:mm:ss.SSS'
%
% returns a {N,1} cellarray of strings representing global time coordinates

if ~exist('formatstr','var')
  formatstr = 'dd:hh:mm:ss.SSS';
end

if ~iscell(gtc)
  gtc = {gtc}; 
end

hour = cell(numel(gtc),1);
for i=1:numel(gtc)
  s = seconds(gtc{i});
  s.Format = formatstr;
  hour{i}=char(s);
end
