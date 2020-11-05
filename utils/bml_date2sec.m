function sec=bml_date2sec(date,t0)

% BML_DATE2SEC transforms a cell-array of date strings to seconds from
% midnight
%
% date - {N,1} cell array with dates in the format '25-Jul-2017 12:14:25'
% t0 - string representing reference time of day. Defalts to '00:00:00'
%
% returns a [N,1] array of doubles with the number of seconds since
% midnight

if ~exist('t0','var')
  t0 = '00:00:00';
end

if isdatetime(date)
    date = cellstr(datestr(date));
end

if ~iscell(date)
  date = {date}; 
end

t0 = datenum(t0);
sec = zeros(numel(date),1);
for i=1:numel(date)
  if length(date{i})>=20
    sec(i)=datenum(date{i}(13:20));
  else
    sec(i)=nan;
  end
end

sec=round((sec-datenum(t0))*24*60*60);