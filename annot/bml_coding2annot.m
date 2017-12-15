function annot = bml_coding2annot(cfg)

% BML_CODING2ANNOT creates annot table from CodingMatrix 
%
% Use as
%   annot = bml_codingmatrix2annot(cfg)
%
% cfg.CodingMatPath    - path to mat file with coding info
% cfg.EventsPerTrial   - double, defaults depends on CodingAppVersion
% cfg.roi              - roi table with sessions audio sync information
% cfg.audio_chanel     - string indicating audio channel (optinal)
% cfg.CodingAppVersion - char, defines format expected for CodingMatrix
%                      - accepted values are 'U01_v1' (default), 'pilot'
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
CodingAppVersion = bml_getopt(cfg,'CodingAppVersion','U01_v1');
AudioCoord       = bml_getopt(cfg,'warpcoords');
praat            = bml_getopt(cfg,'praat');
audio_channel    = bml_getopt(cfg,'audio_channel');

if isempty(AudioCoord) || praat
  %loading sychronized audio to get the time-mapping
  roi = bml_sync_consolidate(roi);
  sync_audio = bml_load_continuous(roi);
  
  if ~isempty(audio_channel)
    cfg1=[];
    cfg1.channel = audio_channel;
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
    
    fprintf('Calculating alignment between coding and roi audios');
    cfg1=[]; cfg1.method='lpf';
    [coding_audio_dt, max_corr] = bml_timealign(cfg1, sync_audio, coding_audio);
    assert(roi.Fs == Afs, 'roi''s Fs should be equivalent to Coding Aduio Afs');
    
    AudioCoord.s1 = AudioCoord.s1 - round(coding_audio_dt*Afs);
    AudioCoord.s2 = AudioCoord.s2 - round(coding_audio_dt*Afs);
    
    assert(max_corr > 0.95, 'max_cor = %f should be near 1', max_corr);
  end
  if praat
    sync_audio.time = sync_audio_time; %setting sync time
    coding_audio.time{1} = bml_idx2time(AudioCoord, 1:length(coding_audio.time{1}));    
    bml_praat(sync_audio, bml_conform_to(sync_audio,coding_audio));
  end
end

annot=table();
if ismember(CodingAppVersion,{'U01_v1'})
  EventsPerTrial   = bml_getopt(cfg,'EventsPerTrial',3);
  N_trials = size(CodingMatrix,2);
  for i=1:N_trials
    id=i;
    
    %initial trial time in Audio secons 
    ti = EventTimes(SkipEvents + i * EventsPerTrial);  

    %CodingMatrix row 1: Phonetic code in latex
    phoneticCode=CodingMatrix(1,i);

    %CodingMatrix row 2: Syllable errors
    err_syl1=CodingMatrix{2,i}(1);
    err_syl2=CodingMatrix{2,i}(2);
    err_syl3=CodingMatrix{2,i}(3);

    %CodingMatrix row 3: Syl onset time
    onset_syl=bml_strnumcell2ordvec(CodingMatrix{3,i}); %in Audio seconds
    onset_syl1=bml_idx2time(AudioCoord,(onset_syl(1)+ti)*Afs); %in sfm
    onset_syl2=bml_idx2time(AudioCoord,(onset_syl(2)+ti)*Afs); %in sfm
    onset_syl3=bml_idx2time(AudioCoord,(onset_syl(3)+ti)*Afs); %in sfm

    %CodingMatrix row 4: Syl offset time  
    offset_syl = bml_strnumcell2ordvec(CodingMatrix{4,i}); %in Audio seconds
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
        assert(j <= length(offset_syl),'Inconsistent syl offset times in trial %i',i);  
        if offset_syl(j) <= onset_syl_inf(k+1)
          offset_syl_complete(k) = offset_syl(j);
          offset_syl_coded(k) = 1;
          j = j + 1;
        else
          offset_syl_complete(k) = onset_syl_inf(k+1);
          offset_syl_coded(k) = 0;
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
  
elseif ismember(CodingAppVersion,{'pilot'})  
  EventsPerTrial   = bml_getopt(cfg,'EventsPerTrial',4);
  N_trials = size(CodingMatrix,2);
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