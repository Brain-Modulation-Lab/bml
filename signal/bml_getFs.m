function Fs = bml_getFs(cfg, raw)

% BML_GETFS returns the sampling frequency of a raw object
%
% Use as
%   Fs = bml_getFs(cfg, raw)
%   Fs = bml_getFs(raw)
%
% cfg - configuration structure with fields
% cfg.timetol - tolerance in absolute time (s)
% cfg.reltimetol - tolerance in relative time 
% raw - ft_datatype_raw object
%
% returns a double with the sampling rate

if ~exist('raw','var')  
  raw=cfg;
  cfg=[];
end

timetol = bml_getopt(cfg,'timetol',1e-9);
reltimetol = bml_getopt(cfg,'reltimetol',1e-4);
freqsignif = bml_getopt(cfg,'freqsignif',4);

%checking within trial consistency
timetol_offenders = [];
reltimetol_offenders = [];
median_dt = nan(1,length(raw.time));
for t=1:length(raw.time)
  dts = diff(raw.time{t});
  median_dt(t)=median(dts);
  if range(dts) > timetol
    timetol_offenders = [timetol_offenders, t];
  end
	if range(dts)/median_dt(t) > reltimetol
    reltimetol_offenders = [reltimetol_offenders, t];
  end
end

if ~isempty(timetol_offenders)
  warning("trials %s don't comply with timetol of %f",toString(timetol_offenders),timetol)
end
if ~isempty(reltimetol_offenders)
  warning("trials %s don't comply with reltimetol of %f",toString(reltimetol_offenders),reltimetol)
end

mean_median_dt = mean(median_dt);

%checking across trials consistency
if range(median_dt) > timetol
  warning("timetol violated across trials")
end
if range(median_dt)/mean_median_dt > reltimetol
  warning("reltimetol violated across trials")
end

Fs = round(1/mean_median_dt,freqsignif,'signif');









  