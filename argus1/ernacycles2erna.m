function out = ernacycles2erna(cfg,data)


erna_cycles = cfg.erna_cycles;
time = cfg.time;
stim_vec = cfg.stim_vec;
timeburst = cfg.timeburst;
run_annot = cfg.run_annot;
fsample = cfg.fsample;
erna = table();
cont = 1;
bursts = unique(erna_cycles.burst_id);

PXX = [];
for burst_i = 1 : numel(bursts)
    get_cycles = erna_cycles(erna_cycles.burst_id == bursts(burst_i),:);
    erna.starts(cont) = time(1) + timeburst(bursts(burst_i));
    erna.ends(cont) = time(end) + timeburst(bursts(burst_i));
    erna.amplitude(cont) = get_cycles.amplitude_cycle(get_cycles.cycle_id == 1);
    erna.frequency(cont) = 1/(get_cycles.peak_time(get_cycles.cycle_id == 2) - get_cycles.peak_time(get_cycles.cycle_id == 1));
    erna.damping(cont) = log(erna.amplitude(cont)/(get_cycles.peak_amp(get_cycles.cycle_id == 2) - get_cycles.trough_amp(get_cycles.cycle_id == 2)));
    erna.latency(cont) = get_cycles.peak_time(get_cycles.cycle_id == 1);
    erna.ncycles(cont) = height(get_cycles);
    erna.run_id(cont) = run_annot.Run;
    erna.burst_id(cont) = bursts(burst_i);
    erna.stim_amp(cont) = stim_vec(bursts(burst_i));

    % check power-based frequency
    [pxx,f] = pwelch(data(bursts(burst_i),:),hanning(numel(data(bursts(burst_i),:))/3), floor(numel(data(bursts(burst_i),:))/9), 2^(nextpow2(numel(data(bursts(burst_i),:))) + 4), fsample );
    % figure
    % plot(f,pxx)
    % xlim([0 600])
    pxx = pxx(f > 100);
    f = f(f > 100);

    PXX = [PXX pxx];



    [pxxmax,idx_peak] = findpeaks(pxx,'MinPeakProminence',.1);
    fpeak = f(idx_peak);
    if numel(idx_peak) > 1
        [pxxmax,idx_peak] = max(pxx(idx_peak));
        fpeak = fpeak(idx_peak);
    end

    if isempty(fpeak)
        f_offset = find(f > 250,1);

        [pxxmax,idx_peak] = max(pxx(f_offset : end));
        fpeak = f(f_offset + idx_peak);
    end
            clear idx_peak

    erna.frequency_power(cont) = fpeak;
    erna.amplitude_power(cont) = pxxmax;


    cont = cont+1;
end

% store output
out = struct();
out.annot= erna;
if height(erna_cycles) > 0
    out.f = f;
    out.PXX = PXX;
else
    out.f = nan;
    out.PXX = nan;
end