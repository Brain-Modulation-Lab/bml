function [idxs_x1, idxs_x2, mean_sim, sim, hF_diagnostic] = bml_sync_match_events2(cfg, events1, events2)
    % BML_SYNC_MATCH_EVENTS
    %
    % Input:
    %   events1: events table with required columns starts and value 
    %   events2: events table with required columns starts and value 
    %   cfg.timetol: intended time tolerance in seconds for similarity metric.
    %                Defaults to 0.001
    %   cfg.onsettol: time tolerace for onset mismatch. Defaults to 100s
    %   cfg.simtol: similarity tolerance. Defaults to 0
    %   cfg.weight_time_pre: float - weight of event duration similarity
    %                Defaults to 1/4
    %   cfg.weight_time_post: float - weight of event duration similarity
    %                Defaults to 1/4
    %   cfg.weight_value_pre: float - weight of matching pre transition values
    %                Defaults to 1/4
    %   cfg.weight_value_post: float - weight of matching post transition values
    %                Defaults to 1/4
    %   cfg.weight_onset: float - weight of onset matching. This considers
    %                             the absolute value of events(i).starts. 
    %                Defaults to 0
    %   cfg.diagnostic_plot: bool
    %   
    % Output:
    %   idxs_x1: Vector of indices from x1
    %   idxs_x2: Vector of indices from x2
    %   mean_sim: mean similarity
    %   sim: similarity vector

    % Latane Bullock 2023 11 08 
    % Alan Bush 2023 12 05 - generalizer to similarity functions
    
    % chat gpt prompt: I have two vectors x1 and x2 whose values are a 
    % single letter A-Z. The vectors are of different lengths: n and m. 
    % Write an algorithm in MATLAB takes the two vectors and returns two vectors
    % idxs_x1 and idxs_x2 both of length min(n, m). idxs_x1 and idxs_x2 should 
    % contain indices from x1 and x2 respecively which maximizes sum(x1[idxs_x1]==x2[idxs_x2]).  

    timetol = bml_getopt(cfg,'timetol',0.001);
    onsettol = bml_getopt(cfg,'onsettol',100);
    simtol = bml_getopt(cfg,'simtol',0);
    wdt1 = bml_getopt(cfg,'weight_time_pre',1/4);
    wdt2 = bml_getopt(cfg,'weight_time_post',1/4);
    wv1 = bml_getopt(cfg,'weight_value_pre',1/4);
    wv2 = bml_getopt(cfg,'weight_value_post',1/4);
    wo = bml_getopt(cfg,'weight_onset',0);

    total = wdt1 + wdt2 + wv1 + wv2 + wo; 
    wdt1 = wdt1 / total;
    wdt2 = wdt2 / total;
    wv1 = wv1 / total ;
    wv2 = wv2 / total;
    wo = wo / total;  

%     wdt1 = bml_getopt(cfg,'weight_time_pre',1/5);
%     wdt2 = bml_getopt(cfg,'weight_time_post',1/5);
%     wv1 = bml_getopt(cfg,'weight_value_pre',1/5);
%     wv2 = bml_getopt(cfg,'weight_value_post',1/5);
%     wo = bml_getopt(cfg,'weight_onset',1/5);
%     
    diagnostic_plot = bml_getopt(cfg,'diagnostic_plot',0);

    %defining trigger feature matrix with columns
    % 1) pre-inter-trigger interval,
    % 2) post-inter-trigger interval,
    % 3) pre value, 
    % 4) post value
    % 5) onset

    events1_delta_starts = diff(events1.starts);
    x1 = [events1_delta_starts(1:(end-1)),...
          events1_delta_starts(2:end),....
          events1.value(1:(end-2)),...
          events1.value(2:(end-1)),...
          events1.starts(1:(end-2))];

    events2_delta_starts = diff(events2.starts);
    x2 = [events2_delta_starts(1:(end-1)),...
          events2_delta_starts(2:end),....
          events2.value(1:(end-2)),...
          events2.value(2:(end-1)),...
          events2.starts(1:(end-2))];

    similarity_fun = @(x1,x2) wdt1 .* (1./(1+((x1(:,1)-x2(:,1))./timetol).^2)) + ...
                              wdt2 .* (1./(1+((x1(:,2)-x2(:,2))./timetol).^2)) + ...
                              wv1 .* (x1(:,3)==x2(:,3)) + ...
                              wv2 .* (x1(:,4)==x2(:,4)) + ...
                              wo .* (1./(1+((x1(:,5)-x2(:,5))./onsettol).^2));

    n = size(x1,1);
    m = size(x2,1);
    
    % Create a matrix to store the dynamic programming table
    dp = zeros(n+1, m+1);
    
    % Fill the DP table
    for i = 1:n
        for j = 1:m
            dp(i+1, j+1) = max([dp(i, j) + similarity_fun(x1(i,:),x2(j,:)), dp(i+1, j), dp(i, j+1)]);
        end
    end
    
    % Backtrack to find the indices that maximize the sum
    idxs_x1 = [];
    idxs_x2 = [];
    i = n;
    j = m;
    s = 0; 
    while i > 0 && j > 0
        if dp(i+1, j+1) + s*simtol  > dp(i+1, j) && dp(i+1, j+1) + s*simtol > dp(i, j+1) 
            idxs_x1 = [i, idxs_x1];
            idxs_x2 = [j, idxs_x2];
            i = i - 1;
            j = j - 1;
            s = 1;
        elseif dp(i+1, j) > dp(i, j+1)
            j = j - 1;
            s = 0;
        else
            i = i - 1;
            s = 0;
        end
    end
    
    % idxs_x1 and idxs_x2 will contain the indices maximizing the sum
    sim = similarity_fun(x1(idxs_x1,:),x2(idxs_x2,:));
    mean_sim = mean(sim,1);
    
    if diagnostic_plot
        hF_diagnostic = figure('Position', [ 1000         611         889         727]); 
        subplot(4,1,2:4)
        imagesc(dp)
        hold on
        plot(idxs_x2,idxs_x1)
        subplot(4,1,1)
        plot(idxs_x2,sim); ylim([0 1.1]);
    
        fprintf("mean similarity of matched events is %f\n", mean_sim)
    end

    idxs_x1 = idxs_x1 + 1;
    idxs_x2 = idxs_x2 + 1;
    
end
