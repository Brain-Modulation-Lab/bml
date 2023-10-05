function json = readjson(filename)
% fileName = 'filename.json'; % filename in JSON extension
fid = fopen(filename); % Opening the file
raw = fread(fid,inf); % Reading the contents
str = char(raw'); % Transformation
fclose(fid); % Closing the file
json = jsondecode(str); % Using the jsondecode function to parse JSON from string
end