function  Stim  = bml_compute_Spikelocked_clusterperm( spkSampRate, IFR,ISITS,D, n_trials, basetimes, trialtimes, respInterval,alpha,minTsig,n_btsp)
%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here
Stim.respInterval = respInterval;

Stim.DispInterval = -1: 1/spkSampRate : Stim.respInterval(2) + 1;
Stim.n_trials = n_trials;
Stim.spkSampRate = spkSampRate;

Stim.trial_nsamples = round(spkSampRate*diff(respInterval)) + 1;
% Baseline data (hard-coded to take one second back from basetimes)
Stim.base_samples = round(spkSampRate*basetimes);
Stim.base_nsamples = round(spkSampRate) + 1; % hard/coded baseline 1 s
% build baseline segments
Stim.IFRbase = cell2mat(arrayfun(@(x) IFR((Stim.base_samples(x)-spkSampRate):Stim.base_samples(x)), ...
    1:n_trials, 'uniformoutput', false)');
Stim.ISITSbase = cell2mat(arrayfun(@(x) ISITS((Stim.base_samples(x)-spkSampRate):Stim.base_samples(x)), ...
    1:n_trials, 'uniformoutput', false)');

Stim.FRbaseline = mean(Stim.IFRbase(:));
Stim.ISITSbaseline = mean(Stim.ISITSbase(:));

% Trial data
Stim.trial_samples = round(spkSampRate*trialtimes);
Stim.DD = cell2mat(arrayfun(@(x) ...
    D((Stim.trial_samples(x)+round(spkSampRate*Stim.respInterval(1))): ...
    (Stim.trial_samples(x)+round(spkSampRate*Stim.respInterval(2)))), ...
    1:n_trials, 'uniformoutput', false)');
Stim.IFRdata = cell2mat(arrayfun(@(x) ...
    IFR((Stim.trial_samples(x)+round(spkSampRate*Stim.respInterval(1))): ...
    (Stim.trial_samples(x)+round(spkSampRate*Stim.respInterval(2)))), ...
    1:n_trials, 'uniformoutput', false)');
Stim.ISITSdata = cell2mat(arrayfun(@(x) ...
    ISITS((Stim.trial_samples(x)+round(spkSampRate*Stim.respInterval(1))): ...
    (Stim.trial_samples(x)+round(spkSampRate*Stim.respInterval(2)))), ...
    1:n_trials, 'uniformoutput', false)');


% Wilcoxon + ClusterBased perm test
Stim = do_clustermod(Stim,alpha,minTsig,n_btsp,"IFR");    
Stim = do_clustermod(Stim,alpha,minTsig,n_btsp,"ISITS");
% try
%     Stim = do_clustermod(Stim,alpha,minTsig,n_btsp,"IFR");    
%     Stim = do_clustermod(Stim,alpha,minTsig,n_btsp,"ISITS");
% catch
%     warning("no enough samples")
% end
% 


    
    
function Stim = do_clustermod(Stim,alpha,minTsig,n_btsp,flag_neural)
        if contains(flag_neural,"IFR")
            Y = Stim.IFRdata;
            Y_baseline = Stim.IFRbase;
        elseif contains(flag_neural,"ISITS")
               Y = Stim.ISITSdata;
            Y_baseline = Stim.ISITSbase;
        end
        
        [pstats,~,stats] = arrayfun(@(x) signrank(Y(:,x),mean(Y_baseline,2,'omitnan'),"method","approximate"),1:Stim.trial_nsamples);
        zstats = [stats.zval];
        Stim.Zscore = zstats;
        
        Psig = bwconncomp(pstats < alpha);
        n_clusters = Psig.NumObjects;
        zcluster = cellfun(@(x) sum(zstats(x)),Psig.PixelIdxList);
        
        zclust_btsp = [];
        data_all = [Y_baseline Y];
        nsamples_all = size(data_all,2);
        for btsp_i = 1 : n_btsp
            if mod(btsp_i,100) == 0
                fprintf("launching btsp %d/%d \n",btsp_i,n_btsp)
            end
            base_id = zeros(Stim.n_trials,Stim.base_nsamples);
            trial_id = zeros(Stim.n_trials,Stim.trial_nsamples);
            % trial-wise permutation
            for trial_i = 1 : Stim.n_trials
                base_id(trial_i,:) = randperm(nsamples_all,Stim.base_nsamples);
                trial_id(trial_i,:) = setdiff(1:nsamples_all,base_id(trial_i,:));
            end
            data_btsp = data_all(trial_id);
            base_btsp = mean(data_all(base_id),2,'omitnan');
            
            [pstats_btsp,~,stats_btsp] = arrayfun(@(x) ranksum(data_btsp(~ismissing(data_btsp(:,x)),x),base_btsp),1:Stim.trial_nsamples);
            zstats_btsp = [stats_btsp.zval];
            Psig_btsp = bwconncomp(pstats_btsp < 0.05);
            zclust_btsp = [zclust_btsp cellfun(@(x) sum(zstats_btsp(x)),Psig_btsp.PixelIdxList)];
        end
        
        %% check properties of significant periods
        sign_mod_length = cellfun(@(x) numel(x)/Stim.spkSampRate,Psig.PixelIdxList);
        
        
        if n_clusters > 0
            %         figure("renderer","painters")
            %         h = histogram(zclust_btsp,'facecolor','k');
            %         hold on
            for cluster_i = 1 : n_clusters
                
                if contains(flag_neural,"IFR")
                    Stim.IFRmod(cluster_i).Zclust =  zcluster(cluster_i);
                    Stim.IFRmod(cluster_i).Zlength =  sign_mod_length(cluster_i);
                    Stim.IFRmod(cluster_i).Zlength_enough =  sign_mod_length(cluster_i) >= minTsig/1000;
                    Stim.IFRmod(cluster_i).Pbtsp =  mean(zclust_btsp>= zcluster(cluster_i));
                    Stim.IFRmod(cluster_i).Zflag = Stim.IFRmod(cluster_i).Pbtsp < 0.05;
                    Stim.IFRmod(cluster_i).tbins = Psig.PixelIdxList{cluster_i};
                elseif contains(flag_neural,"ISITS")
                    Stim.ISITSmod(cluster_i).Zclust =  zcluster(cluster_i);
                    Stim.ISITSmod(cluster_i).Zlength =  sign_mod_length(cluster_i);
                    Stim.ISITSmod(cluster_i).Zlength_enough =  sign_mod_length(cluster_i) >= minTsig/1000;
                    Stim.ISITSmod(cluster_i).Pbtsp =  mean(zclust_btsp >= zcluster(cluster_i));
                    Stim.ISITSmod(cluster_i).Zflag = Stim.ISITSmod(cluster_i).Pbtsp < 0.05;
                    Stim.ISITSmod(cluster_i).tbins = Psig.PixelIdxList{cluster_i};
                end

                
                %text(zcluster(plot_i),max(h.Values) + .05*max(h.Values),sprintf("P_{Z_{%d}} = %1.3f",plot_i,Stim.IFRmod(plot_i).Pbtsp))
                
                %             if zcluster(plot_i) < 0
                %                 plot([zcluster(plot_i) zcluster(plot_i)],[0 max(h.Values)],'b--','linewidth',1.4)
                %
                %             else
                %                 plot([zcluster(plot_i) zcluster(plot_i)],[0 max(h.Values)],'r--','linewidth',1.4)
                %             end
            end
            %         xlabel("Cluster-wise Z")
            %         ylabel("count")
            %         plot([prctile(zclust_btsp,2.5) prctile(zclust_btsp,2.5)], [0 max(h.Values)],'k--','linewidth',1.4)
            %         plot([prctile(zclust_btsp,97.5) prctile(zclust_btsp,97.5)], [0 max(h.Values)],'k--','linewidth',1.4)
            %         box off
            %         disp("displaying and saving figure...")
            %         saveas(gcf,figname,"png")
            %         saveas(gcf,figname,"pdf")
            %         saveas(gcf,figname,"eps")
            %         close gcf
        end
    end


end
