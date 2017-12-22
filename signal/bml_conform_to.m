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

assert(numel(master.trial)==numel(slave.trial),"master and slave have different number of trials");
starts=zeros(numel(master.trial),1);
ends=zeros(numel(master.trial),1);
for i=1:numel(master.trial)
  mc = bml_raw2coord(master,i);
  sc = bml_raw2coord(slave,i);
  assert(mc.t2 > sc.t1 && mc.t1 < mc.t2, 'can''t conform trial %i, raws dont''t overlap',i);
  starts(i)=mc.t1;
  ends(i)=mc.t2;
end

cfg=[]; cfg.time=master.time; cfg.method='pchip';
cfg.feedback='no';
conformed=ft_resampledata(cfg,bml_crop(slave,starts,ends));

if ismember('fsample',fields(master))
  conformed.fsample = master.fsample;
elseif ismember('fsample',fields(conformed))
  conformed = rmfield(conformed,'fsample');
end
if ismember('hdr',fields(slave))
  conformed.hdr=slave.hdr;  
end
% if ismember('hdr',fields(master))
%   conformed.hdr=master.hdr;  
% end

