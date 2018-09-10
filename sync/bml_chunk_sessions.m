function chunks = bml_chunk_sessions(session, split_time, chunk_duration)

% BML_CHUNK_SESSIONS breaks up sessions into smaller chunks
%
% Use as 
%   chunks = bml_chunk_sessions(session, split_time)
%   chunks = bml_chunk_sessions(session, [], chunk_duration)
%
% session - annot table of sessions or chunks
% split_time - double: vector of times at which to split the sessions or 
%           integer < 10 indicating the number of chuncks each session
%           should be split into
% chunk_duration - double: desired duration of the resulting chunks
% returns a chuked version of session


session = bml_annot_table(session);
assert(isempty(bml_annot_overlap(session)),'sessions should not overlap');
if nargin == 1 
  split_time = [];
elseif nargin == 2
    if length(split_time)==1 && abs(split_time-round(split_time,0))<1e-9 && split_time <= 10
        n_split = split_time;
        split_time = [];
        for s=1:height(session)
            bp  = linspace(session.starts(s),session.ends(s),n_split+1);
            split_time = [split_time, bp(2:(end-1))];
        end
    end
elseif nargin == 3 && isempty(split_time)
	split_time = [];
    for s=1:height(session)
        n_split = round(session.duration(s)/chunk_duration);
        bp  = linspace(session.starts(s),session.ends(s),n_split+1);
        split_time = [split_time, bp(2:(end-1))];
    end    
else
    warning("incorrect number of arguments");
end

if ~ismember('session_id',session.Properties.VariableNames)
  session.session_id = session.id;
end
if ~ismember('session_part',session.Properties.VariableNames)
  session.session_part = ones(height(session),1);
end

for i=1:length(split_time)
  session_i=session((session.starts < split_time(i)) & (session.ends > split_time(i)),:);
  if isempty(session_i)
    warning("time %d does not belong to any session",split_time(i));
  else
    session.ends(session.id==session_i.id(1)) = split_time(i);
    session_i.id = max(session.id)+1;
    session_i.starts = split_time(i);
    session_i.session_part = session_i.session_part + 1;
    session = [session; session_i];
  end
end

session.id=[];
chunks=bml_annot_table(session);


  
  


