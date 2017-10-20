function sec=bml_date2sec(date)

% BML_DATE2SEC transforms a cell-array of date strings to seconds from
% midnight
%
% date - {N,1} cell array with dates in the format '25-Jul-2017 12:14:25'
%
% returns a [N,1] array of doubles with the number of seconds since
% midnight

sec=(datenum(cellfun(@(x){x(13:20)},date))-datenum('00:00:00'))*24*60*60;
