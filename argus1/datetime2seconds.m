function secs = datetime2seconds(hdr, date)
date = datetime(date,'InputFormat','yyyy-MM-dd HH:mm:ss');

if ~isempty(hdr)
    if ~any(strcmpi(hdr.Properties.VariableNames,'ImplantDate')) || isempty(hdr.ImplantDate)
        secs =   hour(date)*3600 + minute(date)*60 + second(date);
    else
        ref = datetime(hdr.ImplantDate,'InputFormat','yyyy-MM-dd HH:mm:ss');
        ref.TimeZone = date.TimeZone;
        secs = seconds(date - ref);
    end
else
    secs =   hour(date)*3600 + minute(date)*60 + second(date);
end