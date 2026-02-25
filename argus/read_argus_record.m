function [data, metadata] = read_argus_record(fname)
%READ_ARGUS_RECORD Read an Argus-style TSV where a fixed metadata block is
%followed by a variable-length numeric tail starting at column "Sense_Data".
%
%   [data, metadata] = argus_read_record(fname)
%
% Outputs:
%   data     - nTrials x nTime double matrix, padded with NaN
%   metadata - nTrials x K table of doubles (non-numeric -> NaN)
%              includes metadata.n_samples (length per trial)
%
% Assumptions:
% - Tab-delimited text file.
% - First row is a header containing column "Sense_Data".
% - Columns before Sense_Data are metadata (converted to numeric).

    arguments
        fname (1,1) string
    end

    if ~isfile(fname)
        error("argus_read_record:FileNotFound", "File not found: %s", fname);
    end

    delim = sprintf('\t');

    % Read all lines (skip blank)
    lines = readlines(fname, "EmptyLineRule","skip");
    if isempty(lines)
        error("argus_read_record:EmptyFile", "File is empty: %s", fname);
    end

    % Header
    headerLine = lines(1);
    headers = split_tsv_line(headerLine, delim);

    senseIdx = find(headers == "Sense_Data", 1, "first");
    if isempty(senseIdx)
        error("argus_read_record:NoSenseDataColumn", ...
            "Header does not contain a 'Sense_Data' column.");
    end

    K = senseIdx - 1;
    if K < 1
        error("argus_read_record:BadHeader", ...
            "'Sense_Data' appears as the first column; expected metadata columns before it.");
    end

    body = lines(2:end);
    nTrials = numel(body);

    % First pass: parse metadata strings and ragged numeric tails
    fixed_str = strings(nTrials, K);
    tails = cell(nTrials, 1);
    nSamp = zeros(nTrials, 1);

    for i = 1:nTrials
        parts = split_tsv_line(body(i), delim);

        % Pad metadata fields if line is short
        if numel(parts) < K
            parts(end+1:K) = "";
        end
        fixed_str(i,:) = parts(1:K);

        % Tail
        if numel(parts) >= senseIdx
            tail = strip(parts(senseIdx:end));
            tail = tail(tail ~= ""); % drop empty tokens
            if isempty(tail)
                v = zeros(0,1);
            else
                v = str2double(tail);
                v = v(:);
            end
        else
            v = zeros(0,1);
        end

        tails{i} = v;
        nSamp(i) = numel(v);
    end

    % Build trial x time matrix (pad with NaN)
    nTime = max(nSamp);
    data = NaN(nTrials, nTime);
    for i = 1:nTrials
        if nSamp(i) > 0
            data(i, 1:nSamp(i)) = tails{i};
        end
    end

    % Convert metadata to numeric table
    metaNames = make_valid_names(headers(1:K));
    metaNum = NaN(nTrials, K);
    for j = 1:K
        metaNum(:,j) = str2double(fixed_str(:,j));
    end
    metadata = array2table(metaNum, "VariableNames", metaNames);

    % Add useful numeric derived field
    metadata.n_samples = nSamp;
end

% ---------------- helpers ----------------

function parts = split_tsv_line(line, delim)
% Minimal quote-aware TSV splitter (tab delim).

    s = string(line);

    % Fast path
    if ~contains(s, '"')
        parts = split(s, delim);
        return;
    end

    ch = char(s);
    d  = char(delim);  % tab
    out = strings(0,1);

    buf = char.empty(1,0);
    inQuotes = false;

    for k = 1:numel(ch)
        c = ch(k);

        if c == '"'
            inQuotes = ~inQuotes;
            buf(end+1) = c; %#ok<AGROW>
        elseif c == d && ~inQuotes
            out(end+1,1) = string(buf); %#ok<AGROW>
            buf = char.empty(1,0);
        else
            buf(end+1) = c; %#ok<AGROW>
        end
    end
    out(end+1,1) = string(buf);

    out = strip(out);
    out = strip(out, '"');
    out = replace(out, '""', '"');

    parts = out;
end

function vnames = make_valid_names(names)
    vnames = matlab.lang.makeValidName(cellstr(names));
    vnames = matlab.lang.makeUniqueStrings(vnames);
end
