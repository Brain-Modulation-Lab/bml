function conformed = bml_conform_to(master, slave)

% BML_CONFORM_TO conforms salve to master
%
% Use as
%    conformed = bml_conform_to(master, slave)
%
% master - FT_DATATYPE_RAW
% slave  - FT_DATATYPE_RAW
%
% returns the data of salve, resampled to the times of master
%
% --- examples ---
%
% % merge slave to master in a single merged FT_DATATYPE_RAW
%
% conformed = bml_conform_to(master, slave)
% 
% cfg=[];
% cfg.appenddim  = 'chan';
% merged = ft_appenddata(cfg,master,conformed);
%

t1=master.time{1}(1);
t2=master.time{1}(end);
cfg=[]; cfg.time=master.time; cfg.method='pchip';
cfg.feedback='no';
conformed=ft_resampledata(cfg,bml_crop(slave,t1,t2));

if ismember('fsample',fields(master))
  conformed.fsample = master.fsample;
end
if ismember('hdr',fields(slave))
  conformed.hdr=slave.hdr;
end
