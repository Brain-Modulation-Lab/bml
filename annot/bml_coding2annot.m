function annot = bml_coding2annot(cfg)

% BML_CODING2ANNOT creates annotation table from CodingMatrix 
%
% Use as
%   annot = bml_codingmatrix2annot(cfg)
%
% cfg.CodingMatPath    - path to mat file with coding info
% cfg.EventsPerTrial   - double, defaults depends on CodingAppVersion
% cfg.roi              - roi table with sessions audio sync information
% cfg.audio_chanel     - string indicating audio channel (optinal)
% cfg.CodingAppVersion - char, defines format expected for CodingMatrix
%                        accepted values are: 
%                        >'U01_v1': UO1 coding before July 2018
%                        >'U01_v2'(default): UO1 coding after July 2018.
%                                   Contains structured coding of errors
%                        >'pilot': for coding of pilot data (DBS2000 series)
% cfg.session_id       - integer, session id number for warnings and
%                        session_id column of output table
% cfg.diary_filename   - str, name of file to save all output, including
%                        warnings. Defaults to empty
% cfg.timetol_consolidate - double: consolidation time tolerance. Defaults to 1e-3s
%           this time tolerance relates to the sync consolidation process.
%           extrinsic time tolerance (between samples of different strams)
% cfg.praat - bool: if true, audio files are opened in praat for visual
%           inspections
% cfg.AudioCoord = time coordinates of audio file. If empty, calculated
%           from roi
%
% returns annot table with one row per trial (syllable triplet) 

% Todo: take sync table as input, read audio files, use them to sync the
% Audio variable of the mat and, with that, get the times in master
% coordinates.
%

if nargin ~= 1
  error('Use as bml_coding2annot(cfg)');
end

CodingMatPath = bml_getopt_single(cfg,'CodingMatPath');
assert(~isempty(CodingMatPath),'cfg.CodingMatPath required in single argument call');
load(CodingMatPath,'CodingMatrix');
load(CodingMatPath,'EventTimes');
load(CodingMatPath,'SkipEvents');
load(CodingMatPath,'WordList');
load(CodingMatPath,'Afs');

roi              = bml_getopt(cfg,'roi');
CodingAppVersion = bml_getopt(cfg,'CodingAppVersion','U01_v2');
AudioCoord       = bml_getopt(cfg,'AudioCoord');
praat            = bml_getopt(cfg,'praat',false);
audio_channel    = bml_getopt(cfg,'audio_channel');
session_id       = bml_getopt(cfg,'session_id',nan);
diary_filename   = bml_getopt_single(cfg,'diary_filename',[]);
timetol_cons     = bml_getopt(cfg,'timetol_consolidate',1e-3);

if ~isempty(diary_filename)
  diary(diary_filename);
end

if ~isnan(session_id)
  fprintf('\n - Extracting coding from session %i - \n\n ',session_id)  
end

if isempty(AudioCoord) || praat
  %loading sychronized audio to get the time-mapping
  %roi = bml_sync_consolidate(roi);
  
  cfg1=[];
  cfg1.roi = roi;
  cfg1.match_labels = false; %allowing for audio files with different labels
  cfg1.timetol_consolidate = timetol_cons;
  sync_audio = bml_load_continuous(cfg1);
  
  if ~isempty(audio_channel)
    cfg1=[];
    cfg1.channel = audio_channel;
    cfg1.trackcallinfo = false;
    cfg1.showcallinfo = 'no';    
    sync_audio = ft_selectdata(cfg1,sync_audio);
  end
  
  % unwarping to facilitate correlation with coding_audio
  loadedAudioCoord = bml_raw2coord(sync_audio);
  sync_audio_time = sync_audio.time;
  sync_audio.time{1} = (1:length(sync_audio.time{1}))./sync_audio.fsample;
  
  %loading coding audio
  cfg1=[]; cfg1.CodingMatPath = CodingMatPath;
  coding_audio = bml_coding2raw(cfg1);

  if isempty(AudioCoord)
    AudioCoord = loadedAudioCoord;
    
    fprintf('Calculating alignment between coding and roi audio\n');
    cfg1=[]; cfg1.method='lpf';
    assert(sync_audio.fsample == Afs, 'roi''s Fs=%f should be equivalent to Coding Audio Afs=%f',sync_audio.fsample,Afs);      
    [coding_audio_dt, max_corr] = bml_timealign(cfg1, sync_audio, coding_audio);
    
    AudioCoord.s1 = AudioCoord.s1 - round(coding_audio_dt*Afs);
    AudioCoord.s2 = AudioCoord.s2 - round(coding_audio_dt*Afs);
    
    if max_corr < 0.95
      fprintf('Warning: max_cor = %f should be near 1. Check in Praat if alignment is correct.\n', max_corr)
    end    
  end
  if praat
    sync_audio.time = sync_audio_time; %setting sync time
    coding_audio.time{1} = bml_idx2time(AudioCoord, 1:length(coding_audio.time{1}));    
    bml_praat(sync_audio, bml_conform_to(sync_audio,coding_audio));
  end
end

annot=table();
if ismember(CodingAppVersion,{'U01_v2'}) % CodingApp version July 2018 =============
  EventsPerTrial   = bml_getopt(cfg,'EventsPerTrial',3);
  N_trials = size(CodingMatrix,2);
	if SkipEvents + N_trials * EventsPerTrial > length(EventTimes)
    fprintf('Warning: Less EventTimes than expected based on CodingMatrix.\n');
    N_trials = floor((length(EventTimes) - SkipEvents)/EventsPerTrial);
  end
  for i=1:N_trials
    id=i;
    trial_id = id;
    data_integrity = true;
    
    %initial trial time in Audio seconds 
    ti = EventTimes(SkipEvents + i * EventsPerTrial);  
    tf_idx = SkipEvents + i * EventsPerTrial + 1; 
    if tf_idx <= length(EventTimes)
      tf = EventTimes(tf_idx); 
    else
      tf = ti + 5;
    end
    
    %CodingMatrix row 1: Phonetic code in latex
    phonetic_code=CodingMatrix(1,i);
    if isempty(phonetic_code)|| strcmp(phonetic_code,{' '}) || strcmp(phonetic_code,{''})
      phonetic_code = {nan(1)};
    end

    %CodingMatrix row 2: Syllable errors - deprecated
%     err_syl1=CodingMatrix{2,i}(1);
%     err_syl2=CodingMatrix{2,i}(2);
%     err_syl3=CodingMatrix{2,i}(3);

    %CodingMatrix row 3: Syl onset time
    onset_syl=bml_strnumcell2ordvec(CodingMatrix{3,i}); %in Audio seconds
    empty_syl = isempty(onset_syl);
    if length(onset_syl) ~= 3
      %if ~empty_syl || ~ismissing(phonetic_code{1})
      if ~empty_syl | ~ismissing(phonetic_code{1})
        fprintf('Warning[01] number of syllable onsets is different from 3 in trial %i of session %i \n',trial_id,session_id)
        data_integrity = false;
      end
      onset_syl = default_nan3(onset_syl);
    end    
    syl1_onset=bml_idx2time(AudioCoord,(onset_syl(1)+ti)*Afs); %in sfm
    syl2_onset=bml_idx2time(AudioCoord,(onset_syl(2)+ti)*Afs); %in sfm
    syl3_onset=bml_idx2time(AudioCoord,(onset_syl(3)+ti)*Afs); %in sfm
    
    if ~isnan(syl1_onset) && ~iscellstr(phonetic_code)
      fprintf('Warning[02] phonetic coding is missing but syllable onsets are present in trial %i of session %i\n',trial_id,session_id)
      data_integrity = false;     
    end
    
    %CodingMatrix row 4: Syl offset time  
    offset_syl = default_nan(bml_strnumcell2ordvec(CodingMatrix{4,i})); %in Audio seconds
    offset_syl_complete = nan(1,length(onset_syl));
    if ~empty_syl
      for j=1:length(onset_syl)
        if j<length(onset_syl) && ~isnan(onset_syl(j+1))
          curr_syl_offset = offset_syl(offset_syl > onset_syl(j) & offset_syl <= onset_syl(j+1));
        else %last syl
          curr_syl_offset = offset_syl(offset_syl > onset_syl(j));          
        end
        if length(curr_syl_offset)>1
          fprintf('Warning[05] syllable %i has more than one offset in trial %i of session %i\n',j,trial_id,session_id)
          data_integrity = false;  
          offset_syl_complete(j) = curr_syl_offset(1);
        elseif length(curr_syl_offset)==1
          offset_syl_complete(j) = curr_syl_offset(1);          
        else %no current syl offset
          if j < length(onset_syl)
            offset_syl_complete(j) = onset_syl(j+1); 
          elseif ~isnan(onset_syl(j)) %last syl onset
            fprintf('Warning[04] last syllable has no offset in trial %i of session %i\n',trial_id,session_id)
            data_integrity = false;  
            offset_syl_complete(j) = nan;
          end         
        end
      end
    else %empty syl
      if ~all(ismissing(offset_syl))
        fprintf('Warning[03] syllable offsets are present but no syllable onsets are given in trial %i of session %i\n',trial_id,session_id)
        data_integrity = false;         
      end
      offset_syl_complete = nan(1,length(onset_syl));
    end
    syl1_offset=bml_idx2time(AudioCoord,(offset_syl_complete(1)+ti) * Afs);%in sfm
    syl2_offset=bml_idx2time(AudioCoord,(offset_syl_complete(2)+ti) * Afs);%in sfm
    syl3_offset=bml_idx2time(AudioCoord,(offset_syl_complete(3)+ti) * Afs);%in sfm

    %CodingMatrix row 5: Vowel onset time
    onset_vowel=bml_strnumcell2ordvec(CodingMatrix{5,i}); %in Audio seconds
    onset_vowel_complete = nan(1,length(onset_syl));
    if ~empty_syl
      %checking for vowel onsets outside syllables
      if isectopic(onset_vowel,onset_syl,offset_syl_complete)
        fprintf('Warning[08] vowel onset(s) outside syllable in trial %i of session %i\n',trial_id,session_id)
        data_integrity = false;         
      end
      %assigning vowel onsets to syllables
      for j=1:length(onset_syl)
        curr_onset_vowel = onset_vowel(onset_vowel >= onset_syl(j) & onset_vowel < offset_syl_complete(j));
        if length(curr_onset_vowel)>1
          fprintf('Warning[06] syllable %i has more than one vowel onset in trial %i of session %i\n',j,trial_id,session_id)
          data_integrity = false;  
          onset_vowel_complete(j) = curr_onset_vowel(1);
        elseif length(curr_onset_vowel)==1
          onset_vowel_complete(j) = curr_onset_vowel(1);          
        else %no current vowel onset, assuming syl onset for vowel
          onset_vowel_complete(j) = onset_syl(j); 
        end
      end
    else %empty syl
      if ~all(ismissing(onset_vowel))
        fprintf('Warning[07] vowel onset(s) are present but no syllable onsets are given in trial %i of session %i\n',trial_id,session_id)
        data_integrity = false;         
      end
      onset_vowel_complete = nan(1,length(onset_syl));
    end
    syl1_vowel_onset=bml_idx2time(AudioCoord,(onset_vowel_complete(1)+ti) * Afs);
    syl2_vowel_onset=bml_idx2time(AudioCoord,(onset_vowel_complete(2)+ti) * Afs);
    syl3_vowel_onset=bml_idx2time(AudioCoord,(onset_vowel_complete(3)+ti) * Afs);

    %CodingMatrix row 6: Vowel offsets
    offset_vowel = bml_strnumcell2ordvec(CodingMatrix{6,i}); %in Audio seconds
    offset_vowel_complete = nan(1,length(onset_syl));
    if ~empty_syl
      %checking for vowel offsets outside syllables
      if isectopic(offset_vowel,onset_syl,offset_syl_complete)
        fprintf('Warning[11] vowel offset(s) outside syllable in trial %i of session %i\n',trial_id,session_id)
        data_integrity = false;         
      end
      %assigning vowel offsets to syllables
      for j=1:length(onset_syl)
        curr_offset_vowel = offset_vowel(offset_vowel > onset_syl(j) & offset_vowel <= offset_syl_complete(j));
        if length(curr_offset_vowel)>1
          fprintf('Warning[09] syllable %i has more than one vowel offset in trial %i of session %i\n',j,trial_id,session_id)
          data_integrity = false;  
          offset_vowel_complete(j) = curr_offset_vowel(1);
        elseif length(curr_offset_vowel)==1
          offset_vowel_complete(j) = curr_offset_vowel(1);          
        else %no current vowel onset, assuming syl onset for vowel
          offset_vowel_complete(j) = offset_syl_complete(j); 
        end
      end
    else %empty syl
      if ~all(ismissing(offset_vowel))
        fprintf('Warning[10] vowel offset(s) are present but no syllable onsets are given in trial %i of session %i\n',trial_id,session_id)
        data_integrity = false;         
      end
      offset_vowel_complete = nan(1,length(onset_syl));
    end 
    syl1_vowel_offset=bml_idx2time(AudioCoord,(offset_vowel_complete(1)+ti) * Afs);%in sfm
    syl2_vowel_offset=bml_idx2time(AudioCoord,(offset_vowel_complete(2)+ti) * Afs);%in sfm
    syl3_vowel_offset=bml_idx2time(AudioCoord,(offset_vowel_complete(3)+ti) * Afs);%in sfm

    %CodingMatrix row 7: Preword onset times
    nontask1_pre_onset = default_nan(bml_strnumcell2ordvec(CodingMatrix{7,i})); %in Audio seconds
    if length(nontask1_pre_onset) > 1
      fprintf('Warning[12] more than one Pre onset time given in trial %i of session %i\n',trial_id,session_id)
      data_integrity = false;
      nontask1_pre_onset = nontask1_pre_onset(1);
    end
    if ~isnan(nontask1_pre_onset) && nontask1_pre_onset >= onset_syl(1)
      fprintf('Warning[13] Pre event onset after first syllable onset in trial %i of session %i\n',trial_id,session_id)
      data_integrity = false;
    end
    nontask1_pre_onset = bml_idx2time(AudioCoord,(nontask1_pre_onset+ti) * Afs);
    
    %CodingMatrix row 8: Preword offset times
    nontask1_pre_offset = default_nan(bml_strnumcell2ordvec(CodingMatrix{8,i})); %in Audio seconds
    if ~isnan(nontask1_pre_offset) || length(nontask1_pre_offset) > 1
      fprintf('Warning[14] Pre event offset(s) present when none expected in trial %i of session %i\n',trial_id,session_id)
      data_integrity = false;
      nontask1_pre_offset = nontask1_pre_offset(1);
    else %asigning Pre offse to first syl onset
      nontask1_pre_offset = onset_syl(1);
    end  
    nontask1_pre_offset = bml_idx2time(AudioCoord,(nontask1_pre_offset+ti) * Afs);

    %CodingMatrix row 9: Post word onset times
    nontask2_post_onset = default_nan(bml_strnumcell2ordvec(CodingMatrix{9,i})); %in Audio seconds
    if ~isnan(nontask2_post_onset) || length(nontask2_post_onset) > 1
      fprintf('Warning[15] Post event onset(s) present when none expected in trial %i of session %i\n',trial_id,session_id)
      data_integrity = false;
      nontask2_post_onset = nontask2_post_onset(1);
    else %asigning post onset to last syl offset
      nontask2_post_onset = offset_syl_complete(end);
    end      
    nontask2_post_onset = bml_idx2time(AudioCoord,(nontask2_post_onset+ti) * Afs);

    %CodingMatrix row 10: Post word offset times
    nontask2_post_offset = default_nan(bml_strnumcell2ordvec(CodingMatrix{10,i})); %in Audio seconds
    if length(nontask2_post_offset) > 1
      fprintf('Warning[16] more than one Post event offset time given in trial %i of session %i\n',trial_id,session_id)
      data_integrity = false;
      nontask2_post_offset = nontask2_post_offset(1);
    end
    if ~isnan(nontask2_post_offset) && nontask2_post_offset <= offset_syl_complete(end)
      fprintf('Warning[17] Post event offset before last syllable offset in trial %i of session %i\n',trial_id,session_id)
      data_integrity = false;
    end
    nontask2_post_offset = bml_idx2time(AudioCoord,(nontask2_post_offset+ti) * Afs);
    
    %CodingMatrix row 11: Other onset times  
    nontask345_other_onset = default_nan3(bml_strnumcell2ordvec(CodingMatrix{11,i}));
    if length(nontask345_other_onset) ~= 3
      fprintf('Warning[18] more than 3 ''Other events'' onsets present in trial %i of session %i\n',trial_id,session_id)
      data_integrity = false;
    end  
    
    %CodingMatrix row 12: Other offset times
    nontask345_other_offset = default_nan3(bml_strnumcell2ordvec(CodingMatrix{12,i}));
    if length(nontask345_other_offset) ~= 3
      fprintf('Warning[19] more than 3 ''Other events'' offsets present in trial %i of session %i\n',trial_id,session_id)
      data_integrity = false;
    end  
    
    if (~isnan(nontask345_other_offset(1)) && isnan(nontask345_other_onset(1))) || ...
       (~isnan(nontask345_other_offset(2)) && isnan(nontask345_other_onset(2))) || ...
       (~isnan(nontask345_other_offset(3)) && isnan(nontask345_other_onset(3)))
      fprintf('Warning[20] Other event offset has no corresponding onset in trial %i of session %i\n',trial_id,session_id)
      data_integrity = false;     
    end

    for j=1:3
      if ~isnan(nontask345_other_onset(j)) && ...
          isectopic(nontask345_other_onset(j),onset_syl,offset_syl_complete) && ...
          isnan(nontask345_other_offset(j))
        fprintf('Warning[21] Other event onset %i outside syllables has no corresponding offset in trial %i of session %i\n',j,trial_id,session_id)
        data_integrity = false;
      end
    end
   
    %transforming to global time coords of other nontask events
    nontask345_other_onset = bml_idx2time(AudioCoord,(nontask345_other_onset+ti) * Afs);
    nontask3_other_onset = nontask345_other_onset(1);
    nontask4_other_onset = nontask345_other_onset(2);    
    nontask5_other_onset = nontask345_other_onset(3);
    nontask345_other_offset = bml_idx2time(AudioCoord,(nontask345_other_offset+ti) * Afs);
    nontask3_other_offset = nontask345_other_offset(1);
    nontask4_other_offset = nontask345_other_offset(2);    
    nontask5_other_offset = nontask345_other_offset(3);
    
    %CodingMatrix row 13: Note for current trial
    row13=CodingMatrix{13,i};
    if ~iscell(row13) || ~(size(row13,1)==2 && size(row13,2)==1)
      fprintf('Warning[22] CodingMatrix format of non-task event description is invalid in trial %i of session %i\n',trial_id,session_id)
      data_integrity = false;
      comment = {'row13 invalid'};
      nontask1_pre_type={nan};
      nontask2_post_type={nan};
      nontask3_other_type={nan};
      nontask4_other_type={nan};
      nontask5_other_type={nan};
    else    
      comment = default_str(row13(1,1));

      %mapping non-task codes to strings
      nt_code = [1,      2,                  3,          4,                 5,                6];
      nt_str = {'none', 'beeping-constant', 'OR-noise', 'provider-speech', 'patient-speech', 'patient-non-speech'};

      nontask1_pre_type=bml_map(row13{2,1}(1),nt_code,nt_str);
      nontask2_post_type=bml_map(row13{2,1}(2),nt_code,nt_str);
      nontask3_other_type=bml_map(row13{2,1}(3),nt_code,nt_str);
      nontask4_other_type=bml_map(row13{2,1}(4),nt_code,nt_str);
      nontask5_other_type=bml_map(row13{2,1}(5),nt_code,nt_str);
    end  
    
    %CodingMatrix row 14: Stressors binary
    row14=CodingMatrix{14,i};
    if ~isnumeric(row14) || iscell(row14) || ~(size(row14,1)==5 && size(row14,2)==3)
      fprintf('Warning[23] CodingMatrix format of speech-specific annotations are invalid in trial %i of session %i\n',trial_id,session_id)
      syl1_stress={nan};
      syl2_stress={nan}; 
      syl3_stress={nan};
      syl1_consonant_accuracy={nan};
      syl2_consonant_accuracy={nan};
      syl3_consonant_accuracy={nan};
      syl1_vowel_accuracy={nan};
      syl2_vowel_accuracy={nan};
      syl3_vowel_accuracy={nan};
      syl1_consonant_disorder={nan};
      syl2_consonant_disorder={nan};
      syl3_consonant_disorder={nan};
      syl1_vowel_disorder={nan};
      syl2_vowel_disorder={nan};
      syl3_vowel_disorder={nan};
    else
      stressor_code = [0,1];
      stressor_str  = {'not-stressed', 'stressed'};
      syl1_stress = bml_map(row14(1,1),stressor_code,stressor_str);
      syl2_stress = bml_map(row14(1,2),stressor_code,stressor_str);    
      syl3_stress = bml_map(row14(1,3),stressor_code,stressor_str);    

      accuracy_code = [0,1];
      accuracy_str  = {'accurate', 'inaccurate'};
      syl1_consonant_accuracy = bml_map(row14(2,1),accuracy_code,accuracy_str);
      syl2_consonant_accuracy = bml_map(row14(2,2),accuracy_code,accuracy_str);    
      syl3_consonant_accuracy = bml_map(row14(2,3),accuracy_code,accuracy_str);    

      syl1_vowel_accuracy = bml_map(row14(3,1),accuracy_code,accuracy_str);
      syl2_vowel_accuracy = bml_map(row14(3,2),accuracy_code,accuracy_str);    
      syl3_vowel_accuracy = bml_map(row14(3,3),accuracy_code,accuracy_str);    

      disorder_code = [1,       2,         3,           4,           5,                6,            7,        8,        9,         10,             11,           12];
      disorder_str  = {'none', 'missing', 'distorted', 'imprecise', 'spirantization', 'dysfluency', 'creaky', 'tremor', 'breathy', 'hoarse-harsh', 'voice-break','strain'}; 
      syl1_consonant_disorder = bml_map(row14(4,1),disorder_code,disorder_str);
      syl2_consonant_disorder = bml_map(row14(4,2),disorder_code,disorder_str);    
      syl3_consonant_disorder = bml_map(row14(4,3),disorder_code,disorder_str); 

      syl1_vowel_disorder = bml_map(row14(5,1),disorder_code,disorder_str);
      syl2_vowel_disorder = bml_map(row14(5,2),disorder_code,disorder_str);    
      syl3_vowel_disorder = bml_map(row14(5,3),disorder_code,disorder_str);  
    end
    
    cue_triplet = WordList(i);

    starts = bml_idx2time(AudioCoord, ti * Afs);
    ends   = bml_idx2time(AudioCoord, tf * Afs);

    annot = [annot; table(id, starts, ends, session_id, trial_id, ...
      cue_triplet, phonetic_code,...
      syl1_onset, syl1_offset, syl1_vowel_onset, syl1_vowel_offset, syl1_stress,...
      syl1_consonant_accuracy, syl1_consonant_disorder, syl1_vowel_accuracy, syl1_vowel_disorder, ...
      syl2_onset, syl2_offset, syl2_vowel_onset, syl2_vowel_offset, syl2_stress,...
      syl2_consonant_accuracy, syl2_consonant_disorder, syl2_vowel_accuracy, syl2_vowel_disorder, ...
      syl3_onset, syl3_offset, syl3_vowel_onset, syl3_vowel_offset, syl3_stress,...
      syl3_consonant_accuracy, syl3_consonant_disorder, syl3_vowel_accuracy, syl3_vowel_disorder, ...
      nontask1_pre_onset, nontask1_pre_offset, nontask1_pre_type, ...
      nontask2_post_onset, nontask2_post_offset, nontask2_post_type, ...
      nontask3_other_onset, nontask3_other_offset, nontask3_other_type, ...
      nontask4_other_onset, nontask4_other_offset, nontask4_other_type, ...     
      nontask5_other_onset, nontask5_other_offset, nontask5_other_type, ...         
      comment, data_integrity)];

  end
   
elseif ismember(CodingAppVersion,{'U01_v1'}) %==================================
  EventsPerTrial   = bml_getopt(cfg,'EventsPerTrial',3);
  N_trials = size(CodingMatrix,2);
	if SkipEvents + N_trials * EventsPerTrial > length(EventTimes)
    warning("Less EventTimes than expected based on CodingMatrix.");
    N_trials = floor((length(EventTimes) - SkipEvents)/EventsPerTrial);
  end
  for i=1:N_trials
    id=i;
    
    %initial trial time in Audio seconds 
    ti = EventTimes(SkipEvents + i * EventsPerTrial);  

    %CodingMatrix row 1: Phonetic code in latex
    phoneticCode=CodingMatrix(1,i);

    %CodingMatrix row 2: Syllable errors
    err_syl1=CodingMatrix{2,i}(1);
    err_syl2=CodingMatrix{2,i}(2);
    err_syl3=CodingMatrix{2,i}(3);

    %CodingMatrix row 3: Syl onset time
    onset_syl=bml_strnumcell2ordvec(CodingMatrix{3,i}); %in Audio seconds
    if size(onset_syl,2) < 3
      onset_syl = [onset_syl, nan(1,3-size(onset_syl,2))];
    end    
    onset_syl1=bml_idx2time(AudioCoord,(onset_syl(1)+ti)*Afs); %in sfm
    onset_syl2=bml_idx2time(AudioCoord,(onset_syl(2)+ti)*Afs); %in sfm
    onset_syl3=bml_idx2time(AudioCoord,(onset_syl(3)+ti)*Afs); %in sfm
    
    %CodingMatrix row 4: Syl offset time  
    offset_syl = bml_strnumcell2ordvec(CodingMatrix{4,i}); %in Audio seconds
    if isempty(offset_syl)
      offset_syl = nan;
    end
    %completing missing offsets
    if length(offset_syl)==length(onset_syl)
      offset_syl_complete = offset_syl;
      offset_syl_coded = ones(1,length(offset_syl_complete));
    else
      offset_syl_complete = zeros(1,length(onset_syl));
      offset_syl_coded = zeros(1,length(onset_syl));
      onset_syl_inf = [onset_syl inf];
      j=1; %offset_syl counter
      for k=1:(length(onset_syl))
        if j <= length(offset_syl) 
          if offset_syl(j) <= onset_syl_inf(k+1)
            offset_syl_complete(k) = offset_syl(j);
            offset_syl_coded(k) = 1;
            j = j + 1;
          else
            offset_syl_complete(k) = onset_syl_inf(k+1);
            offset_syl_coded(k) = 0;
          end
        else
            offset_syl_complete(k) = NaN;
            offset_syl_coded(k) = 0;          
          warning('Inconsistent syl offset times in trial %i',i)
        end
      end
    end
    offset_syl1=bml_idx2time(AudioCoord,(offset_syl_complete(1)+ti) * Afs);%in sfm
    offset_syl2=bml_idx2time(AudioCoord,(offset_syl_complete(2)+ti) * Afs);%in sfm
    offset_syl3=bml_idx2time(AudioCoord,(offset_syl_complete(3)+ti) * Afs);%in sfm
    offset_coded_syl1=offset_syl_coded(1);
    offset_coded_syl2=offset_syl_coded(2);
    offset_coded_syl3=offset_syl_coded(3); 

    %CodingMatrix row 5: Vowel onset time
    onset_vowel=bml_strnumcell2ordvec(CodingMatrix{5,i}); %in Audio seconds
    if size(onset_vowel,2) < 3
      onset_vowel = [onset_vowel, nan(1,3-size(onset_vowel,2))];
    end  
    onset_vowel1=bml_idx2time(AudioCoord,(onset_vowel(1)+ti) * Afs);
    onset_vowel2=bml_idx2time(AudioCoord,(onset_vowel(2)+ti) * Afs);
    onset_vowel3=bml_idx2time(AudioCoord,(onset_vowel(3)+ti) * Afs);

    %CodingMatrix row 6: Vowel offsets, not coded
    %CodingMatrix row 7: Preword onset times
    %CodingMatrix row 8: Preword offset times
    %CodingMatrix row 9: Post word onset times
    %CodingMatrix row 10: Post word offset times
    %CodingMatrix row 11: Other onset times  
    %CodingMatrix row 12: Other offset times

    %CodingMatrix row 13: Note for current trial
    comment=CodingMatrix(13,i);

    %CodingMatrix row 14: Stressors binary 

    word_triplet = WordList(i);

    starts = bml_idx2time(AudioCoord,(min(onset_syl)+ti) * Afs);
    ends = bml_idx2time(AudioCoord,(max(offset_syl)+ti) * Afs);

    annot = [annot; table(id, starts, ends, phoneticCode, err_syl1, err_syl2, err_syl3,...
      onset_syl1, offset_syl1, onset_syl2, offset_syl2, onset_syl3, offset_syl3,...
      onset_vowel1, onset_vowel2, onset_vowel3,...
      offset_coded_syl1, offset_coded_syl2, offset_coded_syl3, word_triplet, comment)];

  end
  
elseif ismember(CodingAppVersion,{'pilot'}) %================================== 
  EventsPerTrial   = bml_getopt(cfg,'EventsPerTrial',4);
  N_trials = size(CodingMatrix,2);
  if SkipEvents + N_trials * EventsPerTrial > length(EventTimes)
    warning("Less EventTimes than expected based on CodingMatrix.");
    N_trials = floor((length(EventTimes) - SkipEvents)/EventsPerTrial);
  end
  for i=1:N_trials
    id=i;
    ti = EventTimes(SkipEvents + i * EventsPerTrial);
    
    %CodingMatrix row 1. phonetic code in LaTex separated by '/'.
    phoneticCode = default_str(CodingMatrix(1,i));

    %CodingMatrix row 2. 1st Consonant errors
    err_cons1 = CodingMatrix(2,i);

    %CodingMatrix row 3. Vowel errors
    err_vowel = CodingMatrix(3,i);

    %CodingMatrix row 4. 2nd Consonant error  
    err_cons2 = CodingMatrix(4,i);
    
    %CodingMatrix row 5. Word onset time
    onset_word=bml_idx2time(AudioCoord,(default_nan(CodingMatrix{5,i}) + ti) * Afs);

    %CodingMatrix row 6. Word offset time
    offset_word=bml_idx2time(AudioCoord,(default_nan(CodingMatrix{6,i}) + ti) * Afs);
    
    %CodingMatrix row 7. 1 if actual task presentation was revealed
    unveil=default_int(CodingMatrix{7,i});
    
    %CodingMatrix row 8. Notes for current trial
    comment=CodingMatrix(8,i);    
    
    %CodingMatrix row 9. Onset of vowel
    onset_vowel=bml_idx2time(AudioCoord,(default_nan(CodingMatrix{9,i}) + ti) * Afs);    
    
    %CodingMatrix row 10. Offset of vowel    
    offset_vowel=bml_idx2time(AudioCoord,(default_nan(CodingMatrix{10,i}) + ti) * Afs);        
 
    word = WordList(i);

    starts = onset_word;
    ends = offset_word;

    annot = [annot; table(id, starts, ends, phoneticCode,...
      err_cons1, err_vowel, err_cons2, onset_word, offset_word, ...
      unveil, comment, onset_vowel, offset_vowel, word)];
    
  end
else
  error('unknown CodingAppVersion')
end
  
annot = bml_annot_table(annot);
annot.trial_id = annot.id;

if ~isempty(diary_filename)
  diary off;
end

end



%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Private functions %%%
%%%%%%%%%%%%%%%%%%%%%%%%%

function default = default_str(input)
  if isempty(input)
    default = {''};
  else
    default = input;
  end
end

function default = default_int(input)
  if isempty(input)
    default = 0;
  else
    default = input;
  end
end

function default = default_nan(input)
  if isempty(input)
    default = nan;
  else
    default = input;
  end
end

function default = default_nan3(input)
  default = padarray(input,[isempty(input),max([0,3-size(input,2)])],nan,'post');
end

function ise = isectopic(t,syl_onset,syl_offset)
  for j=1:length(t)
    if ~isnan(t(j))
      ise = true;
      for k=1:length(syl_onset)
       if ~isnan(syl_onset(k)) && ~isnan(syl_offset(k)) && t(j) >= syl_onset(k) && t(j) <= syl_offset(k)
         ise = false;
       end
      end
      if ise
        return
      end
    end
  end
  ise = false;
end


