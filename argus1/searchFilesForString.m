function fileList = searchFilesForString(directory, searchString, ext)
    % Get the list of files in the specified directory
    files = dir(fullfile(directory, ['*.',ext]));
    
    % Initialize an empty list to store the file names
    fileList = {};
    
    % Loop through each file
    for i = 1:numel(files)
        % Check if the search string is present in the file name
        if contains(files(i).name, searchString)
            fileList = [fileList; fullfile(directory, files(i).name)];
        end
    end
end