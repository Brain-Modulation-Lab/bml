function coord = bml_annot2coord(annot, Fs)

% BML_ANNOT2COORD gets s1,t1,s2,t2 coordinates from annot and Fs
%
% Use as 
%   coord = bml_annot2coord(annot, Fs)
%
% annot - ANNOT table with 'starts', 'ends' and optionally 'Fs' variables 
%        (all other vars ignored)
% Fs - numeric, exact sampling frequency of returned s1,t1,s2,t2 coords. 
%      if absent a Fs var in annot is required
%
% returns a table/struct if annot is a table/struct

  if istable(annot)
    if exist('Fs','var')
      annot.Fs(:) = Fs;
    end
    assert(ismember('Fs',annot.Properties.VariableNames),"Fs required");
    assert(ismember('starts',annot.Properties.VariableNames),"starts required");
    assert(ismember('ends',annot.Properties.VariableNames),"ends required");  
    coord = annot;
    coord.s1(:)=0;
    coord.t1(:)=0;
    coord.s2(:)=0;
    coord.t2(:)=0;
    for i=1:height(annot)
      i_coord = annot2coord(annot.starts(i),annot.ends(i),annot.Fs(i));
      coord.s1(i)=i_coord.s1;
      coord.t1(i)=i_coord.t1;
      coord.s2(i)=i_coord.s2;
      coord.t2(i)=i_coord.t2;
    end
  elseif isstruct(annot)
    if exist('Fs','var')
      annot.Fs = Fs;
    end
    assert(ismember('Fs',fields(annot)),"Fs required");
    assert(ismember('starts',fields(annot)),"starts required");
    assert(ismember('ends',fields(annot)),"ends required");
    coord = annot2coord(annot.starts,annot.ends,annot.Fs);
  else
    error('Unknown type for annot. Table or struct accepted.');
  end
end

function simple_coord = annot2coord(starts,ends,Fs)
  pTT = 9; %pTT = pTimeTol = -log10(timetol)
  simple_coord=[];
  simple_coord.s1=1;
  simple_coord.t1=round(starts+0.5/Fs,pTT);
  simple_coord.s2=round((ends-starts)*Fs)-1;
  simple_coord.t2=simple_coord.t1 + (simple_coord.s2 - simple_coord.s1)/Fs; 
end

