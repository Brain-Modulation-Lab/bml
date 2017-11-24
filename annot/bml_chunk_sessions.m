function chunks = bml_chunk_sessions(sessions, split_time)

% BML_CHUNK_SESSIONS breaks up sessions into smaller chunks
%
% Use as 
%   chunks = bml_chunk_sessions(sessions, split_time)
%
% sessions - annot table of sessions or chunks
% split_time - double: vector of times at which to split the sessions
%
% returns a chuked version of sessions


sessions = bml_annot_table(sessions);
assert(isempty(bml_annot_overlap(sessions)),'sessions should not overlap');
if nargin == 1; split_time = []; end

if ~ismember('session_id',sessions.Properties.VariableNames)
  sessions.session_id = sessions.id;
end
if ~ismember('session_part',sessions.Properties.VariableNames)
  sessions.session_part = ones(height(sessions),1);
end

for i=1:length(split_time)
  session_i=sessions((sessions.starts < split_time(i)) & (sessions.ends > split_time(i)),:);
  if isempty(session_i)
    warning("time %d does not belong to any session",split_time(i));
  else
    sessions.ends(sessions.id==session_i.id(1)) = split_time(i);
    session_i.id = max(sessions.id)+1;
    session_i.starts = split_time(i);
    session_i.session_part = session_i.session_part + 1;
    sessions = [sessions; session_i];
  end
end

sessions.id=[];
chunks=bml_annot_table(sessions);


  
  


