function annot = bml_codingmatrix2annot(cfg, CodingMatrix, EventTimes, SkipEvents, WordList)

% BML_CODINGMATRIX2ANNOT creates annotation table from CodingMatrix 
%
% Use as
%   annot = bml_codingmatrix2annot(cfg, CodingMatrix, EventTimes, SkipEvents, WordList)
%   annot = bml_codingmatrix2annot(cfg)
%
% cfg.CodingMatPath - path to mat file with coding info
% cfg.EventsPerTrial - double, defaults to 3
% cfg.t0 - Time origin of audio file in coding mat file
%
% annot table has one row per triplet 

if nargin == 1
  CodingMatPath = bml_getopt_single(cfg,'CodingMatPath');
  assert(~isempty(CodingMatPath),'cfg.CodingMatPath required in single argument call');
  load(CodingMatPath,'CodingMatrix');
  load(CodingMatPath,'EventTimes');
  load(CodingMatPath,'SkipEvents');
  load(CodingMatPath,'WordList');
elseif nargin ~= 4
  error('Use as bml_codingmatrix2annot(cfg, CodingMatrix, EventTimes, SkipEvents)');
end

EventsPerTrial  = bml_getopt(cfg,'EventsPerTrial',3);
t0              = bml_getopt(cfg,'t0',0);

N_trials = size(CodingMatrix,2);
annot=table();

for i=1:N_trials
  
  id=i;
  ti = EventTimes(SkipEvents + i * EventsPerTrial) + t0;
  
  %CodingMatrix row 1: Phonetic code in latex
  phoneticCode=CodingMatrix(1,i);
  
  %CodingMatrix row 2: Syllable errors
  err_syl1=CodingMatrix{2,i}(1);
  err_syl2=CodingMatrix{2,i}(2);
  err_syl3=CodingMatrix{2,i}(3);
  
  %CodingMatrix row 3: Syl onset time
  onset_syl=bml_strnumcell2ordvec(CodingMatrix{3,i});
  onset_syl1=onset_syl(1) + ti;
  onset_syl2=onset_syl(2) + ti;
  onset_syl3=onset_syl(3) + ti;
  
  %CodingMatrix row 4: Syl offset time  
  offset_syl = bml_strnumcell2ordvec(CodingMatrix{4,i});
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
  offset_syl1=offset_syl_complete(1) + ti;
  offset_syl2=offset_syl_complete(2) + ti;
  offset_syl3=offset_syl_complete(3) + ti;
  offset_coded_syl1=offset_syl_coded(1);
  offset_coded_syl2=offset_syl_coded(2);
  offset_coded_syl3=offset_syl_coded(3); 
    
  %CodingMatrix row 5: Vowel onset time
  onset_vowel=bml_strnumcell2ordvec(CodingMatrix{5,i});
  onset_vowel1=onset_vowel(1) + ti;
  onset_vowel2=onset_vowel(2) + ti;
  onset_vowel3=onset_vowel(3) + ti; 
  
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

  starts = min(onset_syl + ti);
  ends = max(offset_syl + ti);
  
  annot = [annot; table(id, starts, ends, phoneticCode, err_syl1, err_syl2, err_syl3,...
    onset_syl1, offset_syl1, onset_syl2, offset_syl2, onset_syl3, offset_syl3,...
    onset_vowel1, onset_vowel2, onset_vowel3,...
    offset_coded_syl1, offset_coded_syl2, offset_coded_syl3, word_triplet, comment)];

end

annot = bml_annot_table(annot);
