function runAnimationERNA(cfg, data)


% get cfg fields
timeburst = cfg.timeburst;
time = cfg.time;
erna_cycles_annot = cfg.erna_cycles;
run_annot = cfg.run_annot;
stim_vec = cfg.stim_vec;
time_rel = cfg.time_rel;
Cmap = cfg.Cmap;
gifname = cfg.gifname;
update_rate = cfg.update_rate;

out = ernacycles2erna(cfg,data);
erna_annot = out.annot;

% extract useful data
if time_rel
    timeburst = timeburst - run_annot.starts;
end

stim_run = run_annot.Amp;% 3.5 mA most of the time accoridng to protocol


% find burst id with erna cycles
%bursts = erna_cycles_annot.burst_id(erna_cycles_annot.cycle_id == 1);


idx_erna_annot = erna_annot.burst_id == 1;
idx_erna_cycles_annot = erna_cycles_annot.burst_id == 1;


fig = figure('position',[ 200 200 1200 800],'visible','off');
tiledlayout(2,3)
nexttile(1,[1 1])
imagesc(timeburst,time,data')
hold on
if ~isempty(erna_cycles_annot.peak_time(erna_cycles_annot.cycle_id == 1 & idx_erna_cycles_annot))
    s1 = scatter(timeburst(1) ,erna_cycles_annot.peak_time(erna_cycles_annot.cycle_id == 1 & idx_erna_cycles_annot),80,'r','filled');
else
    s1 = scatter(timeburst(1) ,nan,80,'r','filled');
end
if ~isempty(erna_cycles_annot.trough_time(erna_cycles_annot.cycle_id == 1 & idx_erna_cycles_annot))

    s2 = scatter(timeburst(1) ,erna_cycles_annot.trough_time(erna_cycles_annot.cycle_id == 1 & idx_erna_cycles_annot),80,'b','filled');
else
    s2 = scatter(timeburst(1) ,nan,80,'b','filled');
end
if ~isempty(erna_cycles_annot.peak_time(erna_cycles_annot.cycle_id == 2 & idx_erna_cycles_annot))

    s3 = scatter(timeburst(1) ,erna_cycles_annot.peak_time(erna_cycles_annot.cycle_id == 2 & idx_erna_cycles_annot),80,'r','filled');
else
    s3 = scatter(timeburst(1) ,nan,80,'r','filled');
end
l1 = xline([timeburst(1) timeburst(1)], '--');
set(gca,'YDir','normal')
xlabel(' Time burst [s]')
ylabel('Time after last pulse [s]')
colormap(Cmap)
cb = colorbar;
cb.Label.String = 'Erna amplitude [\muV]';
box off

yyaxis right
stairs(timeburst,stim_vec,'linewidth',2)
ylabel(' Stim. [mA]')
ylim([0 stim_run + .2])

nexttile(2,[1 1])
p1 = plot(time,data(1,:),'color','k','linewidth',1.5);
xlim([0 0.015])
xlabel('Time after last pulse [s]')
ylabel('ERNA [\muV]')
hold on
s5 = scatter(nan,nan,80,'r','filled');
s6 = scatter(nan,nan,80,'b','filled');
s7 = scatter(nan,nan,80,'r','filled');
box off


nexttile(3,[1 1])

if ~isempty(erna_annot.latency(idx_erna_annot)) && ~isempty(erna_annot.frequency(idx_erna_annot)) && ~isempty(erna_annot.amplitude(idx_erna_annot))
    s4 = scatter3(erna_annot.latency(idx_erna_annot),erna_annot.frequency(idx_erna_annot),  ...
        erna_annot.amplitude(idx_erna_annot),  15,timeburst(1),'filled');
else
    s4 = scatter3(nan,nan,nan,15,'filled');
end
xlabel(' ERNA latency [s] ')
ylabel(' ERNA Frequency [Hz] ')
zlabel(' ERNA amplitude [\muV] ')
colormap(Cmap)
cb = colorbar;
cb.Label.String = 'Time burst [s]';
s4.MarkerFaceAlpha = .4;

nexttile(4,[1 1])
if ~isempty(erna_annot.amplitude(idx_erna_annot))
    s8  = scatter(timeburst(1), erna_annot.amplitude(idx_erna_annot),25,'k','filled');
else
    s8 = scatter(nan,nan,25,'filled');
end
hold on
l2 = xline([timeburst(1) timeburst(1)], '--');

xlabel(' Time burst [s]')
ylabel(' ERNA amplitude [\muV] ')
yyaxis right
stairs(timeburst,stim_vec,'linewidth',2)
ylabel(' Stim. [mA]')
box off
ylim([0 run_annot.Amp + .2])

nexttile(5,[1 1])
if ~isempty(erna_annot.latency(idx_erna_annot))
    s9  = scatter(timeburst(1), erna_annot.latency(idx_erna_annot),25,'k','filled');
else
    s9 = scatter(nan,nan,25,'filled');
end
hold on
l3 = xline([timeburst(1) timeburst(1)], '--');

xlabel(' Time burst [s]')
ylabel(' ERNA latency [ms] ')
yyaxis right
stairs(timeburst,stim_vec,'linewidth',2)
ylabel(' Stim. [mA]')
box off
ylim([0 run_annot.Amp + .2])

nexttile(6,[1 1])
if ~isempty(erna_annot.frequency(idx_erna_annot))
    s10  = scatter(timeburst(1), erna_annot.frequency(idx_erna_annot),25,'k','filled');
else
    s10 = scatter(nan,nan,25,'filled');
end
hold on
l4 = xline([timeburst(1) timeburst(1)], '--');

xlabel(' Time burst [s]')
ylabel(' ERNA frequency [Hz] ')
yyaxis right
stairs(timeburst,stim_vec,'linewidth',2)
ylabel(' Stim. [mA]')
box off
ylim([0 run_annot.Amp + .2])

sgtitle(sprintf('Stim: %s (Sensing: %s-%s) [%1.1f mA, %1.1f Hz] [stimScan Run=%d] \n', string(run_annot.StimC), ...
    string(run_annot.SenseP), string(run_annot.SenseN), run_annot.Amp, ...
    run_annot.Freq, run_annot.Run))

count = 1;
burst_i = 2;
start_time = tic;
while burst_i < size(data,1)

    if toc(start_time) < update_rate
        % do nothing
    else
        % update plot
        idx_erna_cycles_annot = erna_cycles_annot.burst_id == burst_i;
        idx_erna_annot = erna_annot.burst_id == burst_i;

        l1(1).Value = timeburst(burst_i) ;
        l2(1).Value = timeburst(burst_i) ;
        l3(1).Value = timeburst(burst_i) ;
        l4(1).Value = timeburst(burst_i) ;
        
        s1.XData = timeburst(burst_i);
        if ~isempty(erna_cycles_annot.peak_time(erna_cycles_annot.cycle_id == 1 & idx_erna_cycles_annot))
            s1.YData = erna_cycles_annot.peak_time(erna_cycles_annot.cycle_id == 1 & idx_erna_cycles_annot);
            s5.XData = erna_cycles_annot.peak_time(erna_cycles_annot.cycle_id == 1 & idx_erna_cycles_annot);
            s5.YData = erna_cycles_annot.peak_amp(erna_cycles_annot.cycle_id == 1 & idx_erna_cycles_annot);            
        else
            s1.YData = nan;
            s5.XData = nan;         
            s5.YData = nan;            
        end
        s2.XData = timeburst(burst_i);
        if ~isempty(erna_cycles_annot.trough_time(erna_cycles_annot.cycle_id == 1 & idx_erna_cycles_annot))
            s2.YData = erna_cycles_annot.trough_time(erna_cycles_annot.cycle_id == 1 & idx_erna_cycles_annot);
            s6.XData = erna_cycles_annot.trough_time(erna_cycles_annot.cycle_id == 1 & idx_erna_cycles_annot);
            s6.YData = erna_cycles_annot.trough_amp(erna_cycles_annot.cycle_id == 1 & idx_erna_cycles_annot);
       
        else
            s2.YData = nan;
            s6.XData = nan;         
            s6.YData = nan;
        end
        s3.XData = timeburst(burst_i);
        if ~isempty(erna_cycles_annot.peak_time(erna_cycles_annot.cycle_id == 2 & idx_erna_cycles_annot))
            s3.YData = erna_cycles_annot.peak_time(erna_cycles_annot.cycle_id == 2 & idx_erna_cycles_annot);
             s7.XData = erna_cycles_annot.peak_time(erna_cycles_annot.cycle_id == 2 & idx_erna_cycles_annot);
             s7.YData = erna_cycles_annot.peak_amp(erna_cycles_annot.cycle_id == 2 & idx_erna_cycles_annot);

        else
            s3.YData = nan;
            s7.XData = nan;
            s7.YData = nan;
        end
        p1.YData = data(burst_i,:);
        
        if ~isempty(erna_annot.latency(idx_erna_annot))
            s4.XData = [s4.XData erna_annot.latency(idx_erna_annot) ];
            s9.YData = [s9.YData erna_annot.latency(idx_erna_annot)];          
            s9.XData = timeburst(1:burst_i);       
        else
            s4.XData = [s4.XData nan ];
            s9.XData = [s9.XData nan ];
            s9.YData  = [s9.YData  nan ];             
        end
        if ~isempty (erna_annot.frequency(idx_erna_annot))
            s4.YData = [s4.YData erna_annot.frequency(idx_erna_annot)];
            s10.YData = [s10.YData erna_annot.frequency(idx_erna_annot)];          
            s10.XData = timeburst(1:burst_i);
        else
            s4.YData = [s4.YData nan ];
            s10.XData = [s10.XData nan ];
            s10.YData  = [s10.YData  nan ];    
        end
        if ~isempty(erna_annot.amplitude(idx_erna_annot))
            s4.ZData = [s4.ZData erna_annot.amplitude(idx_erna_annot)];
            s8.YData = [s8.YData erna_annot.amplitude(idx_erna_annot)];          
            s8.XData = timeburst(1:burst_i);
        
        else
            s4.ZData = [s4.ZData nan ];
            s8.XData = [s8.XData nan ];
            s8.YData  = [s8.YData  nan ];
            
        end
        s4.SizeData = s4.SizeData + .5;
        %s4.ColorVariable = timeburst(1 : burst_i);
     
         
       
        refreshdata
        drawnow

        burst_i = burst_i + 1;
        start_time = tic;
    end

    % Capture the plot as an image
    frame = getframe(fig);
    im = frame2im(frame);
    [imind,cm] = rgb2ind(im,256);
    % Write to the GIF File
    if count == 1
        imwrite(imind,cm,gifname,'gif', 'Loopcount',inf,'DelayTime',0.1);
    else
        imwrite(imind,cm,gifname,'gif','WriteMode','append','DelayTime',0.1);
    end
    count = count + 1;
end
close(fig)