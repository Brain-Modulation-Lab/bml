function [sync_roi, hF] = bml_sync_event(cfg, master_events, slave_events)

% bml_sync_event synchronizes files according to events
%
% Use as 
%    sync_roi = bml_sync_event(cfg, master_events, slave_events)
%
%   slave_events - events annotation table with sample column
%
%   cfg - configuration structure
%   cfg.master_events - events to align to in annot table in master time
%   cfg.timewarp - logical: Should slave time be warped? defaults to true.
%   cfg.diagnostic_plot - logical
%   cfg.timetol - numeric, time tolerance in seconds. Defaults to 1e-6
%   cfg.min_events - integer. Minimum number of events required to attemp
%             alingment, defaults to 10. 
%   cfg.strict - logical. Issue errors if timetol is violated instead of errors. 
%             Defaults to false. 
%
% returns a roi table

timewarp          = bml_getopt(cfg,'timewarp',false);
diagnostic_plot   = bml_getopt(cfg,'diagnostic_plot',false);
timetol           = bml_getopt(cfg,'timetol',1e-3);
sim_threshold     = bml_getopt(cfg,'sim_threshold',0.9);
min_events        = bml_getopt(cfg,'min_events',10);
strict            = bml_getopt(cfg,'strict',false);

assert(all(ismember({'starts','value'},slave_events.Properties.VariableNames)));
assert(all(ismember({'starts','value'},master_events.Properties.VariableNames)));

% all_slave_dt = zeros(height(roi),1);
% all_warpfactor = ones(height(roi),1);
% all_meanerror = zeros(height(roi),1);

cfg1=[];
cfg1.timetol=timetol;
[idxs_master_events, idxs_slave_events, mean_sim, sim]=bml_sync_match_events(cfg1,master_events,slave_events); 
dtv = master_events.starts(idxs_master_events)-slave_events.starts(idxs_slave_events);

sim_raw = [];
sim_raw.trial = {sim'};
sim_raw.time = {1:length(sim)};
sim_raw.label={'sim'};
sim_raw.fsample = 1;

%first pass to decide which events to sync together
cfg1=[];
cfg1.threshold = sim_threshold;
chunks = bml_annot_detect(cfg1, sim_raw);
chunks.delta_t(:)=nan;
chunks.warp(:)=nan;
tbar = mean(master_events.starts(idxs_master_events),'omitnan');
for i=1:height(chunks)
    chunk_idxs = ceil(chunks.starts(i)):floor(chunks.ends(i));
    p = polyfit(master_events.starts(idxs_master_events(chunk_idxs)) - tbar, dtv(chunk_idxs),1);
    chunks.warp(i) = p(1);
    chunks.delta_t(i) = p(2);
end

%consolidating chunks
cfg1=[];
cfg1.criterion = @(x) (abs(max(x.delta_t)-min(x.delta_t)) < cfg.timetol);
cons_chunks = bml_annot_consolidate(cfg1,chunks);

hF = gobjects(height(cons_chunks),1); % Latane Bullock 2023 12 12, return handles to diagnostic plots

%doing linear warping
cons_chunks.delta_t(:)=nan;
cons_chunks.warpfactor(:)=nan;
cons_chunks.s1(:)=nan;
cons_chunks.t1(:)=nan;
cons_chunks.s2(:)=nan;
cons_chunks.t2(:)=nan;
cons_chunks.mean_sim(:)=nan;
for i=1:height(cons_chunks)

    cons_chunk_idxs = ceil(cons_chunks.starts(i)):floor(cons_chunks.ends(i));
    cons_chunk_idxs = cons_chunk_idxs(sim(cons_chunk_idxs) > sim_threshold);

    p = polyfit(slave_events.starts(idxs_slave_events(cons_chunk_idxs)),master_events.starts(idxs_master_events(cons_chunk_idxs)),1);
    cons_chunks.warpfactor(i) = p(1);
    cons_chunks.delta_t(i) = p(2);
    cons_chunks.starts(i) = master_events.starts(idxs_master_events(cons_chunk_idxs(1)));
    cons_chunks.ends(i) = master_events.starts(idxs_master_events(cons_chunk_idxs(end)));
    cons_chunks.mean_sim(i) = mean(sim(cons_chunk_idxs),'omitnan');

    if ismember('sample',slave_events.Properties.VariableNames)
        p = polyfit(slave_events.sample(idxs_slave_events(cons_chunk_idxs)), master_events.starts(idxs_master_events(cons_chunk_idxs)),1);
        cons_chunks.s1(i) = slave_events.sample(idxs_slave_events(cons_chunk_idxs(1)));
        cons_chunks.s2(i) = slave_events.sample(idxs_slave_events(cons_chunk_idxs(end)));
        cons_chunks.t1(i) = cons_chunks.s1(i) * p(1) + p(2);
        cons_chunks.t2(i) = cons_chunks.s2(i) * p(1) + p(2);
    end

    if diagnostic_plot

        hF(i) = figure; tiledlayout(3, 1); 
     
        nexttile();
        plot(master_events.starts(idxs_master_events),slave_events.starts(idxs_slave_events) - master_events.starts(idxs_master_events))
        hold on;
        plot(master_events.starts(idxs_master_events(cons_chunk_idxs)),slave_events.starts(idxs_slave_events(cons_chunk_idxs)) - master_events.starts(idxs_master_events(cons_chunk_idxs)),'r')
        
        nexttile();
        i_slave_events_starts = (slave_events.starts(idxs_slave_events(cons_chunk_idxs))) .* cons_chunks.warpfactor(i) + cons_chunks.delta_t(i);
        plot(master_events.starts,ones(1,height(master_events)),'bo');
        hold on;
        plot(i_slave_events_starts,ones(1,length(i_slave_events_starts)),'r*');
  
        nexttile();
        histogram(log10(abs(master_events.starts(idxs_master_events(cons_chunk_idxs)) - i_slave_events_starts)));
        xlabel('master minus slave log10 diff [s]');
        ylabel('# events');
    end

end
cons_chunks.duration = cons_chunks.ends - cons_chunks.starts;
sync_roi = cons_chunks(:,{'id','starts','ends','duration','delta_t','warpfactor','mean_sim','s1','t1','s2','t2'});
