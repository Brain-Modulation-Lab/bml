%% PREPROCESS_TRIALS_FOR_CODINGAPP
% version 2017.11.15

% This script time-aligns Audio files (produced by the subject) with BCI 
% files, extracts BCI stimuli event times and creates preprocessed files 
% for Coding App.
% 
% It depends on fieldtrip (https://github.com/fieldtrip/fieldtrip), 
% bml (https://github.com/Brain-Modulation-Lab/bml) and praat. 
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% %
% save final version of script with preprocessed files for documentation purpose
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% %
% 
% Define path to fieldtrip and bml
% Define configuration variables
% Check coarse alignment of files
% Check fine alignment in praat
% Check consistency of session ids with filenames
% Check segmentation with CodingApp. Special attention to first trial!


%% loading packages

%fieldtrip
addpath('/Users/brainmodulationlab/git/fieldtrip')
addpath('/Users/brainmodulationlab/git/bml/annot')
addpath('/Users/brainmodulationlab/git/bml/io')
addpath('/Users/brainmodulationlab/git/bml/utils')
addpath('/Users/brainmodulationlab/git/bml/signal')
ft_defaults

%% configuration variables

SUBJECT='DBS3010';

%defining path to data
PATH_DATA='/Users/brainmodulationlab/Data-BML';
PATH_AUDIO=[PATH_DATA filesep SUBJECT filesep 'Raw' filesep 'Audio'];
PATH_BCI2000=[PATH_DATA filesep SUBJECT filesep 'Raw' filesep 'BCI2000'];

%defining path to mat file with triplet wordlist
PATH_PROTO='/Users/brainmodulationlab/Dropbox/Lab-BML/Proto';
PATH_WORDLIST_MAT = [PATH_PROTO filesep 'Paradigms/2017-11-14-triplets/triplets.mat'];

%defining path to save preprocessed files
PATH_SAVE_PREPROCESSED = [PATH_DATA filesep SUBJECT filesep 'Preprocessed Data/AudioCodingFiles2'];
cd(PATH_SAVE_PREPROCESSED);

AudioTimeCorrection=-450; % correction for audio clock with respect to computer clock
                          % used for initial coarse alignment
MinFileDuration=100; %Minimum duration of files to consider
EventsPerTrial = 3;
StartDelayAfterKeyDown = 1.5;
MaxTrialDuration = 5;

% session description: session to wordlist mapping and 1st trial on BCI start
session_id= [ 1,  2,  3,  4]'; % session id
wordlist  = [ 1,  2,  3,  4]'; % triplet list in PATH_WORDLIST_MAT corresponding to session 
auto1     = [ 1,  1,  0,  1]'; % was first trial of session initiated automatically by 
                               % BCI without keydown event
delay1    = [10, 10, 10, 10]'; % Time delay from BCI file start to first trial. Only used if auto1==1
sessionDesc = table(session_id, wordlist, auto1, delay1);

% manual corrections for specific trials
session_id= [ 3]';
trial     = [ 1]';
correction= [-2]';
sessionTrialCorrection = table(session_id, trial, correction);

% Building sync channels table
filetype  = {'audio.wav'; 'bci2000.dat'};
channel   = {'*Tr1';      'Audio In 1'};
chantype  = {'audio';     'audio'};
sync_channels=table(filetype,channel,chantype);

preprocessingDate = date;

%% loading BCI2000 file information

cfg=[];
cfg.path=PATH_BCI2000;
cfg.pattern='*.dat';
cfg.filetype='bci2000.dat';
info_bci=bml_annot_table(bml_info_raw(cfg));

%% loading audio file information

cfg=[];
cfg.path=PATH_AUDIO;
cfg.pattern='*.wav';
cfg.filetype='audio.wav';
info_wav=bml_annot_table(bml_info_raw(cfg));

info_wav.starts = info_wav.starts + AudioTimeCorrection;
info_wav.ends = info_wav.ends + AudioTimeCorrection;

%% merging file information tables
info = [info_bci; info_wav];
info.type_id=info.id; info.id=[];
info = bml_annot_table(info);

%% estimating sessions
sessions = info(info.filetype=='audio.wav',1:4);
sessions.id = [];
sessions = bml_annot_table(sessions);

%% plotting files times (check coarse alignment)
uft=unique(info.filetype);
figure;
for ift=1:length(uft)
  db = info(info.filetype==uft(ift),:);
  subplot(length(uft)+1,1,ift);
  bml_annot_plot([],db,'LineWidth',3);
  ylabel(uft(ift));
  xlim([min(info.starts),max(info.ends)]);
end
subplot(length(uft)+1,1,length(uft)+1);
bml_annot_plot([],sessions,'LineWidth',3);
ylabel('sessions');
xlim([min(info.starts),max(info.ends)]);

%% Synchronizing files (check fine alignment on praat)
cfg=[];
cfg.sessions=sessions;
cfg.sync_channels=sync_channels;
cfg.master_filetype='audio.wav';
cfg.files = info(info.duration>MinFileDuration,:);
cfg.praat = true;
cfg.timewarp = false;
sync=bml_sync_analog(cfg);

writetable(sync,fullfile(PATH_SAVE_PREPROCESSED,[SUBJECT '_BCI_Audio_sync.txt']));
% sync=readtable(fullfile(PATH_SAVE_PREPROCESSED,[SUBJECT '_BCI_Audio_sync.txt']));

%% check consistency of session_id
sync(:,{'name','session_id'})
if ~all(ismember(setdiff(unique(sync.session_id),0),sessionDesc.session_id))
  error("Unknown session(s) id detected");
end

%% Creating preprocessed mat files
load(PATH_WORDLIST_MAT)

%correction get function
if_notempty_else = @(varargin) varargin{1+isempty(varargin{1})};
get_correction = @(session_id,trial) if_notempty_else(...
  sessionTrialCorrection.correction(...
    (sessionTrialCorrection.session_id==session_id) & ...
    (sessionTrialCorrection.trial==trial))...
  ,0);

for j=1:height(sessionDesc) 
  
  session_id = sessionDesc.session_id(j);
  
  %getting session's bci and audio info
  session_sync=sync(sync.session_id==session_id,:);
  session_sync_bci = session_sync(session_sync.filetype=="bci2000.dat",:);
  session_sync_audio = session_sync(session_sync.filetype=="audio.wav",:);

  %reading bci events
  event = bml_read_event(session_sync_bci);
  %selecting relevant events
  event = event(strcmp({event.type},'KeyDown'));
  
  %transforming bci samples to audio samples index
  st    = bml_idx2time(session_sync_bci,[event.sample]);
  idx   = bml_time2idx(session_sync_audio,st);
  
  %creating variables for Coding App
  raw_audio   = bml_load_continuous(session_sync_audio);
  Afs         = raw_audio.fsample;
  Audio       = raw_audio.trial{1}';
  EventTimes  = zeros(1,EventsPerTrial*(length(idx)+1));
  SkipEvents  = 1-EventsPerTrial;
  WordList    = eval(['triplet' num2str(sessionDesc.wordlist(j))]);
  WordList    = transpose(strcat(WordList(:,1),WordList(:,2),WordList(:,3)));
  
  %populaing Event Times
  i_trial=1; %trial counter
  
  %first trial (no keydown event)
  if sessionDesc.auto1(j)
    start_idx = bml_time2idx(session_sync_audio,bml_idx2time(session_sync_bci,1));
    start_idx = start_idx + (sessionDesc.delay1(j) + get_correction(session_id,i_trial)) * Afs;
    end_idx = idx(1);
    if (end_idx-start_idx)/Afs > MaxTrialDuration
      end_idx = start_idx + MaxTrialDuration*Afs;
    end
    EventTimes(1,1) = start_idx / Afs;
    EventTimes(1,2) = end_idx / Afs;
    i_trial=i_trial+1;
  end
    
  %keydown events trials
  for i=1:(length(idx)-1)
    start_idx = idx(i) + (StartDelayAfterKeyDown+get_correction(session_id,i_trial)) * Afs;
    end_idx = idx(i+1);
    if (end_idx-start_idx)/Afs > MaxTrialDuration
      end_idx = start_idx + MaxTrialDuration*Afs;
    end
    EventTimes(1,(i_trial-1)*EventsPerTrial + 1) = start_idx / Afs;
    EventTimes(1,(i_trial-1)*EventsPerTrial + 2) = end_idx / Afs;
    i_trial=i_trial+1;
  end
  
  %last trial
  start_idx = idx(end) + (StartDelayAfterKeyDown+get_correction(session_id,i_trial)) * Afs;
  EventTimes(1,(i_trial-1)*EventsPerTrial + 1) = start_idx / Afs;
  EventTimes(1,(i_trial-1)*EventsPerTrial + 2) = (start_idx + MaxTrialDuration*Afs) / Afs;
  
  %saving
  save(strcat(PATH_SAVE_PREPROCESSED,filesep,SUBJECT,"_session",num2str(session_id),".mat"),...
    'Afs','Audio','EventTimes','SkipEvents','WordList','preprocessingDate');
  
end

%% Checking segmentation with 
CodingApp

%% Loading audio file and events for debugging

% %getting session's bci and audio info
% session_sync=sync(sync.session_id==3,:);
% session_sync_bci = session_sync(session_sync.filetype=="bci2000.dat",:);
% session_sync_audio = session_sync(session_sync.filetype=="audio.wav",:);
% 
% %reading bci events
% event = bml_read_event(session_sync_bci);
% event = event(strcmp({event.type},'KeyDown'));
% st    = bml_idx2time(session_sync_bci,[event.sample]);
% idx   = bml_time2idx(session_sync_audio,st);
% 
% %open timestamps in praat
% audio = bml_load_continuous(session_sync_audio);
% dig = zeros(size(audio.trial{1}));
% dig(idx)=1;
% timestamps = audio;
% timestamps.trial{1}=dig;
% timestamps.label{1}=['s',num2str(i),'_KeyDown'];
% bml_praat(audio,timestamps);

