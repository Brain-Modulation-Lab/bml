
%% load packages
ft_defaults
bml_defaults
format long

%% Defining paths, loading parameters
SUBJECT='DM1006';
SESSION = 'intraop';
TASK = 'lombard'; 

%%% choose an artifact criterion version
ARTIFACT_CRIT = 'E'; %identifier for the criteria implemented in this script
% ARTIFACT_CRIT = 'F'; %identifier for the criteria implemented in this script



HIGH_PASS_FILTER = 'yes'; %should a high pass filter be applied
HIGH_PASS_FILTER_FREQ = 1; %cutoff frequency of high pass filter
do_bsfilter = 'yes'; 
line_noise_harm_freqs=[60 120 180 240]; % for notch filters for 60hz harmonics
SAMPLE_RATE = 100; % downsample rate in hz for high gamma traces

PATH_DATASET = 'Y:\DBS';
PATH_DER = [PATH_DATASET filesep 'derivatives'];
PATH_DER_SUB = [PATH_DER filesep 'sub-' SUBJECT];  
PATH_PREPROC = [PATH_DER_SUB filesep 'preproc'];
PATH_ANNOT = [PATH_DER_SUB filesep 'annot'];
PATH_FIELDTRIP = [PATH_DER_SUB filesep 'fieldtrip'];
PATH_AEC = [PATH_DER_SUB filesep 'aec']; 
PATH_SCORING = [PATH_DER_SUB filesep 'analysis' filesep 'task-', TASK, '_scoring'];
PATH_ANALYSIS = [PATH_DER_SUB filesep 'analysis'];
PATH_TRIAL_AUDIO = [PATH_ANALYSIS filesep 'task-', TASK, '_trial-audio'];
PATH_TRIAL_AUDIO_INTRAOP_GO = [PATH_TRIAL_AUDIO filesep 'ses-', SESSION, '_go-trials'];
PATH_TRIAL_AUDIO_INTRAOP_STOP = [PATH_TRIAL_AUDIO filesep 'ses-', SESSION, '_stop-trials']; 

PATH_SRC = [PATH_DATASET filesep 'sourcedata'];
PATH_SRC_SUB = [PATH_SRC filesep 'sub-' SUBJECT];  
PATH_SRC_SESS = [PATH_SRC_SUB filesep 'ses-' SESSION]; 
PATH_AUDIO = [PATH_SRC_SESS filesep 'audio']; 
PATHS_TASK = strcat(PATH_SRC_SUB,filesep,{'ses-training';'ses-preop';'ses-intraop'},filesep,'task');

PATH_ART_PROTOCOL = ['Y:\DBS\groupanalyses\task-smsl\A09_artifact_criteria_', ARTIFACT_CRIT];


PATH_FIGURES = [PATH_ART_PROTOCOL filesep 'figures']; 

% cd(PATH_DER_SUB)

artifact_annot_path = [PATH_ANNOT filesep 'sub-' SUBJECT '_ses-' SESSION '_task-' TASK '_artifact-criteria-' ARTIFACT_CRIT '.tsv'];

% session= bml_annot_read_tsv([PATH_ANNOT filesep 'sub-' SUBJECT '_sessions.tsv']);
% electrodes = bml_annot_read_tsv([PATH_ANNOT filesep 'sub-' SUBJECT '_electrodes.tsv']);
% channels = bml_annot_read_tsv([PATH_ANNOT filesep 'sub-' SUBJECT '_ses-' SESSION '_channels.tsv']); %%%% for connector info
%     channels.name = strrep(channels.name,'_Ll','_Lm'); % change name to match naming convention in electrodes table
% [~, ch_ind] = intersect(channels.name, electrodes.name,'stable');
% electrodes = join(electrodes,channels(ch_ind,{'name','connector'}) ,'keys','name'); %%% add connector info
sentences = bml_annot_read_tsv([PATH_ANNOT filesep 'sub-' SUBJECT '_ses-' SESSION '_task-' TASK '_annot-produced-sentences.tsv']);


%% Loading FieldTrip data 
load([PATH_FIELDTRIP filesep 'sub-' SUBJECT '_ses-' SESSION '_task-' TASK '_ft-raw.mat'],'D','loaded_epoch');
nTrials = numel(D.trial);

%remasking nans with zeros
cfg=[];
cfg.value=0;
cfg.remask_nan=true;
D=bml_mask(cfg,D);

% % % % % % % % % % % % %% working in protocol folder
% % % % % % % % % % % % cd(PATH_PROTOCOL)

% %% loading electrode type band table
% if ~exist('el_band','var')
%   param = readtable([PATH_ART_PROTOCOL, filesep, 'artifact_', ARTIFACT_CRIT , '_params.tsv'],'FileType','text');
%   param_default = param(param.subject == "default",:);
%   param_subject = param(strcmp(param.subject,SUBJECT),:);
%   if ~isempty(param_subject)
%     param = bml_annot_rowbind(param_default(~ismember(param_default.name,param_subject.name),:),param_subject);
%   end
% end

%% Applying High Pass Filter
cfg=[];
cfg.hpfilter=HIGH_PASS_FILTER;
cfg.hpfreq=HIGH_PASS_FILTER_FREQ;
cfg.hpfilttype='but';
cfg.hpfiltord=5;
cfg.hpfiltdir='twopass';
cfg.bsfilter=do_bsfilter;
cfg.bsfreq= [line_noise_harm_freqs-1; line_noise_harm_freqs+1]'; % notch filters for 60hz harmonics
cfg.channel={'ecog_*','macro_*','micro_*','dbs_*'};
D_hpf = ft_preprocessing(cfg,D);


%% 

D_hg = bml_extractgamma([], D_hpf);  

bml_databrowser


%% try trialing the data; then view again with databrowser

epoch = sentences;
epoch.starts = sentences.starts;
epoch.ends = sentences.starts;
epoch.t0 = epoch.starts;
epoch = epoch(~ismissing(epoch.t0),:); %removing rows with NaNs

toi = [-2, 2];
tbase = 'all'; % [begin end] in seconds or 'all' for whole-window normalization 

epoch = bml_annot_extend(epoch,-toi(1),toi(2));

cfg=[];
cfg.epoch = epoch;
cfg.timelock = 't0';
cfg.timesnap = true;
[D_hg_trial, epoch] = bml_redefinetrial(cfg, D_hg); % BEWARE there's a chance epoch changes height if the epoch is not present in D

bml_databrowser