% Latane Bullock 2023 11 08 

% chat gpt prompt: I have two vectors x1 and x2 whose values are a 
% single letter A-Z. The vectors are of different lengths: n and m. 
% Write an algorithm in MATLAB takes the two vectors and returns two vectors
% idxs_x1 and idxs_x2 both of length min(n, m). idxs_x1 and idxs_x2 should 
% contain indices from x1 and x2 respecively which maximizes sum(x1[idxs_x1]==x2[idxs_x2]).  

function [idxs_x1, idxs_x2] = find_mincost_indices(x1, x2)
    n = length(x1);
    m = length(x2);
    
    % Create a matrix to store the dynamic programming table
    dp = zeros(n+1, m+1);
    
    % Fill the DP table
    for i = 1:n
        for j = 1:m
            if x1(i) == x2(j)
                dp(i+1, j+1) = dp(i, j) + 1;
            else
                dp(i+1, j+1) = max(dp(i+1, j), dp(i, j+1));
            end
        end
    end
    
    % Backtrack to find the indices that maximize the sum
    idxs_x1 = [];
    idxs_x2 = [];
    i = n;
    j = m;
    while i > 0 && j > 0
        if x1(i) == x2(j)
            idxs_x1 = [i, idxs_x1];
            idxs_x2 = [j, idxs_x2];
            i = i - 1;
            j = j - 1;
        elseif dp(i+1, j) > dp(i, j+1)
            j = j - 1;
        else
            i = i - 1;
        end
    end
    
    % idxs_x1 and idxs_x2 will contain the indices maximizing the sum
end
