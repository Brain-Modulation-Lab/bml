function val = bml_getopt_single(varargin)

% BML_GETOPT_SINGLE gets a single value from a configuration structure [internal]

val = bml_getopt(varargin{:});
if iscell(val)
  if numel(val)==1
    val=val{1};
  else
    error('Several elements in configuratoin where one was expected');
  end
end