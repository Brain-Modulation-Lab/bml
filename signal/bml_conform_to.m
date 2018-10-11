function conformed = bml_conform_to(master, slave)

% BML_CONFORM_TO conforms a slave ft_datatype_raw to the master's time
%
% Use as
%    conformed = bml_conform_to(master, slave)
%
% master - FT_DATATYPE_RAW
% slave  - FT_DATATYPE_RAW
%
% returns the data of slave, resampled to the times of master.
% Asumes that master and slave are synchronized to same time origin.
%
% EXAMPLES:
%
% % merge slave to master in a single merged FT_DATATYPE_RAW
%
% conformed = bml_conform_to(master, slave)
%
% cfg=[];
% cfg.appenddim  = 'chan';
% merged = ft_appenddata(cfg,master,conformed);
%

assert(isstruct(master) && all(ismember({'trial','time','label'},fieldnames(master))),"Invalid master");
assert(isstruct(slave) && all(ismember({'trial','time','label'},fieldnames(slave))),"Invalid slave");

master_N = length(master.trial);
nChans = length(slave.label);

%calculating mapping between master and slave trials
annot_master = bml_raw2annot(master);
annot_slave  = bml_raw2annot(slave);
master_slave = bml_annot_intersect(annot_master,annot_slave);
assert(~isempty(master_slave), "Can't conform. No master trials correspond to any slave trials.");
master_slave.master_frac = master_slave.duration/master_slave.master_duration;
ms_map = zeros(length(master.trial),1); %slave trial index for each master trial
for i=1:master_N
  i_ms=master_slave(master_slave.master_id==i,:);
  if height(i_ms)>1
    [~,i_ms_max_idx]=max(i_ms.master_frac);
    i_ms = i_ms(i_ms_max_idx,:);
  end
  if height(i_ms)>0
    ms_map(i)=i_ms.slave_id(1);
  end
end

%creating subset of slave and master times
sub_slave_N=sum(ms_map>0);
sub_slave=[];
sub_slave.label = slave.label;
sub_slave.trial = cell(1,sub_slave_N);
sub_slave.time = cell(1,sub_slave_N);
sub_master_time = cell(1,sub_slave_N);
starts=zeros(sub_slave_N,1);
ends=zeros(sub_slave_N,1);
sub_ms_map = zeros(master_N,1); %subset slave trial index for each master trial
sub_slave_i=1;
for i=1:master_N
  mc = annot_master(i,:);
  if ms_map(i)==0
    warning("Master trial %i has no corresponding Slave trial. Adding empty trial.",i);
  else
    starts(sub_slave_i) = mc.t1;
    ends(sub_slave_i) = mc.t2;
    sub_ms_map(i) = sub_slave_i;
    sub_slave.trial{sub_slave_i} = slave.trial{ms_map(i)};
    sub_slave.time{sub_slave_i} = slave.time{ms_map(i)};
    sub_master_time{sub_slave_i} = master.time{i};
    sub_slave_i = sub_slave_i + 1;
  end
end

%cheking if sampling rates of slave and master are similar.
%If fs_slave >> fs_master, then apply lowpass filter to slave before interpolating
if annot_slave.Fs(1) > 1.01 * annot_master.Fs(1) % 1% tolerance factor in freq comparison
  fprintf("low-pass filtering slave [%f Hz] to half the master's sampling rate [%f Hz], using 6th order Butterworth\n",annot_slave.Fs(1),annot_master.Fs(1)/2);
  cfg=[]; cfg.lpfilter='yes'; cfg.lpfreq=annot_master.Fs(1)/2; %such that new slave will be sampled at Nyquist rate
  cfg.lpfilttype = 'but'; cfg.lpfiltord = 6; %sixth order butterworth lowpass filter
  cfg.lpfiltdir = 'twopass'; %for zero lag
  cfg.lpinstabilityfix = 'no';
  cfg.lpfiltwintype = 'hamming';
  cfg.trackcallinfo = false;
  cfg.showcallinfo = 'no';
  if ~isfield(slave,'sampleinfo')
    %adding sample info if missing. Assuming contiguity.
    s = cumsum(cellfun(@(x) size(x,2),slave.time,'UniformOutput',true));
    slave.sampleinfo = [[0, s(1:(end-1))]' + 1, s'];
  end
  slave = ft_preprocessing(cfg,slave);
end

%interpolating subset of slave trials to master times
cfg=[]; cfg.time=sub_master_time; cfg.method='pchip';
cfg.feedback='no';
cfg.trackcallinfo = false;
cfg.showcallinfo = 'no';
sub_conformed=ft_resampledata(cfg,bml_crop(sub_slave,starts,ends));

%adding empty slave trials if necessary
conformed=[];
conformed.label = slave.label;
conformed.trial = cell(1,master_N);
conformed.time = cell(1,master_N);
for i=1:master_N
  if sub_ms_map(i)>0
  	conformed.time{i}=sub_conformed.time{sub_ms_map(i)};
    conformed.trial{i}=sub_conformed.trial{sub_ms_map(i)};
  else
    conformed.time{i}=master.time{i};
    conformed.trial{i}=zeros(nChans,length(conformed.time{i}));
  end
end

if ismember('hdr',fields(slave))
  conformed.hdr=slave.hdr;
else
  conformed.hdr=[];
end

%creating header
conformed.hdr.nChans = length(conformed.label);
conformed.hdr.Fs=round(1/mean(diff(conformed.time{1})));
conformed.hdr.label=conformed.label;

if ismember('fsample',fields(master))
  conformed.fsample = master.fsample;
  conformed.hdr.Fs = master.fsample;
elseif ismember('fsample',fields(conformed))
  conformed = rmfield(conformed,'fsample');
end

