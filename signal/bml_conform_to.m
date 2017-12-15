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

mc = bml_raw2coord(master);
sc = bml_raw2coord(slave);
assert(mc.t2 > sc.t1 && mc.t1 < mc.t2, 'can''t conform, raws dont''t overlap');

cfg=[]; cfg.time=master.time; cfg.method='pchip';
cfg.feedback='no';
conformed=ft_resampledata(cfg,bml_crop(slave,mc.t1,mc.t2));

if ismember('fsample',fields(master))
  conformed.fsample = master.fsample;
end
if ismember('hdr',fields(slave))
  conformed.hdr=slave.hdr;
end
