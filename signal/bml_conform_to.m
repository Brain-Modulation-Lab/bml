function conformed = bml_conform_to(master, slave)

%BML_CONFORM_TO conforms salve to master

t1=master.time{1}(1);
t2=master.time{1}(end);
cfg=[]; cfg.time=master.time; cfg.method='pchip';
cfg.feedback='no';
conformed=ft_resampledata(cfg,bml_crop(slave,t1,t2));
conformed.fsample = master.fsample;
