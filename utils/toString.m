function s = toString(v, varargin)
%TOSTRING creates a string representation of any MATLAB variable
%   STRINGREP=RPTGEN.TOSTRING(VARIABLE, CHARLIMIT)

%   Copyright 1997-2017 The MathWorks, Inc.
%--------1---------2---------3---------4---------5---------6---------7---------8

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Convert string arguments to character array arguments
n = numel(varargin);
for i = 1:n
    if isstring(varargin{i})
        varargin{i} = char(varargin{i});
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[charLimit, cr] = locParseInputArgs(varargin{:});

if ischar(v)
    s = locRenderChar(v, charLimit, cr);
elseif isstring(v) 
    if isscalar(v) 
        s = locRenderChar(char(v), charLimit, cr);
    else
        s = locRenderStringArray(v, charLimit, cr);
    end
    
elseif isnumeric(v)
    s = locRenderNumeric(v, charLimit, cr);

elseif iscellstr(v)
    s = locRenderCellStr(v, charLimit, cr);

elseif iscell(v)
    s = locRenderCell(v, charLimit, cr);

elseif isstruct(v)
    s = locRenderStruct(v, charLimit, cr);

elseif isobject(v)
    s = locRenderMCOSObject(v);

elseif isa(v, 'DAStudio.Object')
    s = locRenderDAObject(v, charLimit, cr);
    
else
    s = locRenderViaDISP(v, charLimit, cr);
end    
    
%-------------------------------------------------------------------------------
function sizeString = locRenderSizeString(sizeVector, isMinimize)
% locRenderSizeString accepts a size vector (i.e. the output from SIZE) and 
% renders it as AxBxC. 

if ((nargin > 1) && isMinimize ...
        && (length(sizeVector) < 3) ...   % check length "[1 1]"
        && (max(sizeVector) == 1))        % check elements are all 1s
    % Renders empty if sizeVector is "[1 1]"
    sizeString = '';
else
    % Render output as "AxBxCx"
    sizeString = sprintf('%ix', sizeVector);
    % Remove trailing x
    sizeString(end) = ' ';
end

%-------------------------------------------------------------------------------
function string = locRenderStruct(value, charLimit, cr)

siz = size(value);
nDims = length(siz);

if ((nDims > 2) || (max(siz) > 1))
    % 3d or N-d array - always collapse
    compactStruct = 1;

else
    % Render via DISP method for structures
    % >> aStruct = struct('a',123,'b','xyz');
    % >> rptgen.toString(aStruct);
    string = locRenderViaDISP(value, inf, cr);
    compactStruct = (length(string) > charLimit);
end

if compactStruct
    % Test code for following code paths
    % >> aStruct = struct('a',123,'b','xyz','c',123,'d','xyz','e',1,'f',2);
    % >> aStructMultiDims = repmat(aStruct,[2 2])

    sizStr = locRenderSizeString(siz, true);
    
    % Note the %%s used for a possibily another call to SPRINTF
    string = sprintf('[%s%s w/ fields: %%s]', sizStr, 'struct');

    if (length(string) > charLimit+8)
        % >> rptgen.toString(aStructMultiDims, 10);
        %      [2x2 struct]
        string = sprintf('[%s%s]', sizStr, 'struct');
    
    else
        % Construct list of fieldnames
        f = rptgen.makeSingleLineText(fieldnames(value), ', ');

        if (length(f) > charLimit - length(string))
            f = f(1:charLimit-length(string));
            if (length(f) < 3)
                % >> rptgen.toString(aStructMultiDims, 20)
                %      [2x2 struct w/ fields: ...]
                f = '...';
            else
                % >> rptgen.toString(aStructMultiDims, 40)
                %      [2x2 struct w/ fields: a, b, c, d,...]
                f(end-2:end) = '...';
            end
        end
        
        % Second SPRINTF.  Note, string contains %%s.
        string = sprintf(string, f);
    end
end

% Replace carriage returns 
string = strrep(string, newline, cr);


%-------------------------------------------------------------------------------
function string = locRenderCell(value, charLimit, cr)

siz = size(value);
nDims = length(siz);

isCollapse = false;
if isempty(value)
    % >> rptgen.toString({''})
    string = '{}';

elseif (nDims < 3)
    % 3d or N-d array - always collapse
    % >> a = cell(2,2);
    % >> a{1,1} = 11;
    % >> a{1,2} = '1,2';
    % >> a{2,1} = 21;
    % >> a{2,2} = '2,2';
    % >> rptgen.toString(a)
    % >> rptgen.toString(a, 5)
    string = '{';
    for i = 1:siz(1)
        j = 1;
        sLength = length(string);
        while (j <= siz(2)) && ~isCollapse
            % Pass in a character limit roughly corresponding to the percentage
            % of cells we have left to go
            pctCharLimit = (charLimit-sLength)/((i-1)*siz(2)+j);

            string = [ string ...
                       ' ' ...
                       rptgen.toString(value{i,j}, pctCharLimit, ' ') ...
                       ' ,' ]; %#ok
            
            j = j+1;
            sLength = length(string);
            isCollapse = ~(sLength <= charLimit);
        end
        string(end) = ';';

        % NOTE* Below was 'string(end+1)=cr;', but this fails when value is not a string
        string = [string cr]; %#ok
    end
    string(end-1) = '}';
    string(end) = [];

else
    % 3d or N-d array - always collapse
    % >> a = cell(2,2);
    % >> a{1,1} = 11;
    % >> a{1,2} = '1,2';
    % >> a{2,1} = 21;
    % >> a{2,2} = '2,2';
    % rptgen.toString(repmat(a,[2 2 2]))
    isCollapse = true;
end

if isCollapse
    string = sprintf('[%s cell]', locRenderSizeString(siz));
end

%-------------------------------------------------------------------------------
function string = locRenderStringArray(value, charLimit, cr)

value = num2cell(value);

siz = size(value);
nDims = length(siz);

isCollapse = false;
if isempty(value)
    % >> rptgen.toString({''})
    string = '[]';

elseif (nDims < 3)
    % 3d or N-d array - always collapse
    % >> a = ["a","b";"c";"d"];
    % >> rptgen.toString(a)
    % >> rptgen.toString(a, 5)
    string = '[';
    for i = 1:siz(1)
        j = 1;
        sLength = length(string);
        while (j <= siz(2)) && ~isCollapse
            % Pass in a character limit roughly corresponding to the percentage
            % of cells we have left to go
            pctCharLimit = (charLimit-sLength)/((i-1)*siz(2)+j);
            
            if i > 1
                leftQuote = ' "';
            else
                leftQuote = '"';
            end

            string = [ string ...
                       leftQuote ...
                       rptgen.toString(value{i,j}, pctCharLimit) ...
                       '",' ]; %#ok
            
            j = j+1;
            sLength = length(string);
            isCollapse = ~(sLength <= charLimit);
        end
        string(end) = ';';

        % NOTE* Below was 'string(end+1)=cr;', but this fails when value is not a string
        string = [string cr]; %#ok
    end
    string(end-1) = ']';
    string(end) = [];

else
    % 3d or N-d array - always collapse
    % >> a = ["a","b";"c";"d"];
    % rptgen.toString(repmat(a,[2 2 2]))
    isCollapse = true;
end

if isCollapse
    string = sprintf('[%s string array]', locRenderSizeString(siz));
end

%-------------------------------------------------------------------------------
function string = locRenderViaDISP(value, charLimit, cr)
% value called by EVALC
                                 
try
    string = evalc('disp(value)');

    % Eliminate leading and trailing \n's
    string = regexprep(string, '^\n+|\n+$', '');

    % Replace carriage returns 
    string = strrep(string, newline, cr);
    
    forceCollapse = false;
catch ex %#ok<NASGU>
    forceCollapse = true;
end

if (forceCollapse || (length(string) > charLimit))
    siz = size(value);
    string = sprintf('[%s%s]', locRenderSizeString(siz), class(value));
end

%-------------------------------------------------------------------------------
function string = locRenderNumeric(value, charLimit, cr)

siz = size(value);
nElem = prod(siz);
nDims = length(siz);

% Get typical string length for a given display format
dispFormat = get(0, 'Format');
switch dispFormat(1)
    case 'b'
        % >> format bank
        typNumStrLen = 4;
        precision = 2;
    case 'l'
        % >> format long
        typNumStrLen = 17;
        precision = 7;
        
    otherwise
        % >> format short
        typNumStrLen = 6;
        precision = [];
end

if ((nDims > 2) || (nElem*typNumStrLen > charLimit))
    % Show in collapse form
    % >> rptgen.toString(rand(100), 100)
    %      [100x100 double]
    string = sprintf('<%s%s>', locRenderSizeString(siz), class(value));

elseif (nElem == 1)
    % Obey current FORMAT setting by using DISP
    % >> aNumber = int16(255);
    % >> format hex
    % >> rptgen.toString(aNumber);
    string = strtrim(locRenderViaDISP(value, charLimit, cr));
    
elseif (nElem == 0)
    % >> rptgen.toString(zeros(0));
    string = '[]';

else
    % Can not use DISP to get the correct display format because DISP depends 
    % on the size of the command window.  Use NUM2STR instead.
    % NUM2STR works best a FULL matrix (not sparse)
    % >> aNumber = zeros(5);
    % >> aSparse = sparse(aNumber);
    % >> rptgen.toString(aSparse)
    %      [0  0 ;
    %       0  0 ]
    % NOTE: This does not work with FORMAT not defined above.
    % g947514: Cast value to double to ensure that num2str works with all
    % numeric types, including fixed-point (fi) types.
    if isinteger(value) || isempty(precision)
        % >> format short
        % >> rptgen.toString([1 2 3]) % test empty precision
        string = num2str(double(full(value)));
    else
        string = num2str(double(full(value)), precision);
    end
    brackets = '[]';

    % Blank columns are the leading and trailing two columns beform the CR
    blankColumn = blanks(size(string,1))';

    % Second to last column
    semicolonColumn = ';';
    semicolonColumn = semicolonColumn(ones(size(string,1),1));

    % Last column, carriage return (CR) column
    crColumn = cr(ones(size(string,1),1));

    % Construct output
    string = [blankColumn, string, blankColumn, semicolonColumn, crColumn];
    string(1,1)       = brackets(1);
    string(end,end-1) = brackets(2);
    string(end,end)   = ' ';
    
    % Make sure that out is single-line for concatenating w/ others
    string = string';
    string = string(:)';

    % Make sure there are no zeros in the string
    string(string == 0) = ' ';
end

%-------------------------------------------------------------------------------
function string = locRenderChar(value, charLimit, cr)

siz = size(value);
nElem = prod(siz);
nDims = length(siz);
    
if (nDims > 2) || (nElem > charLimit)
    % Multi-dimension text & extremely long text
    % >> rptgen.toString(repmat('adsfasdf',[3 3 3]))
    % >> rptgen.toString('adsfasdf', 2)
    string = sprintf('[%schar]',locRenderSizeString(siz));

elseif (nDims > 1)
    % Multiline text
    % >> rptgen.toString(repmat('ab',[2 2]))
    string = rptgen.makeSingleLineText(value, cr);

else
    % Single line text
    % >> rptgen.toString('abc')
    string = v;
end

%-------------------------------------------------------------------------------
function string = locRenderCellStr(value, charLimit, cr, objType)

siz = size(value);
nDims = length(siz);

if (nargin < 4)
    objType = 'cellstr';
end

if (nDims < 3) && (min(siz) == 1)
    % Handles [nx1] and [1xn] cell array dimensions
    % >> a = cell(1,2)
    % >> a{1,1} = '1,1'
    % >> a{1,2} = '1,2'
    % >> rptgen.toString(a)
    string = rptgen.makeSingleLineText(value, cr);
    if (length(string) > charLimit)
        string = sprintf('[%s %s]', locRenderSizeString(siz), objType);
    end
else
    % Handles [nxm] cell array dimensions, ie [2x2]
    % >> a = cell(2,2)
    % >> a{1,1} = '1,1'
    % >> a{1,2} = '1,2'
    % >> a{2,1} = '2,1'
    % >> a{2,2} = '2,2'
    % >> rptgen.toString(a)
    string = locRenderCell(value, charLimit, cr);
    
end

%-------------------------------------------------------------------------------
function string = locRenderDAObject(value, charLimit, cr)
% >> a = handle(1);
% >> for i = 1:100
% >>    a(i) = rptgen.cfr_text
% >> end
% >> rptgen.toString(a,inf)
% >> rptgen.toString(a)

value = value(:);
vLen = length(value);
cellStr = cell(1, vLen);
for i = 1:vLen
    cellStr{i} = getDisplayLabel(value(i));
end
string = locRenderCellStr(cellStr, charLimit, cr, 'DAStudio.Object');

%-------------------------------------------------------------------------------
function string = locRenderMCOSObject(value)
sz = size(value);
szStr = locRenderSizeString(sz, true);
string = sprintf('<%s %s>', szStr, class(value));

%-------------------------------------------------------------------------------
function [charLimit, cr] = locParseInputArgs(varargin)

if (nargin == 2)
    charLimit = floor(varargin{1});
    cr = varargin{2};
    
elseif (nargin == 1)
    charLimit = floor(varargin{1});
    cr = newline;
    
else % nargin == 0
    charLimit = inf;
    cr = newline;
end

if (charLimit <= 0)
    charLimit = inf;
end
