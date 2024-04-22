 function masked = bml_mask_TF(cfg, raw, epoch)

% wrapper around BML_MASK, accomodating for artifact masking time-freq objects
%
% BML_MASK creates a new raw file with the specified values masked
% 
% Use as
%   raw = bml_mask(cfg, raw)
%   raw = bml_annot2raw(cfg.annot, mask)

raw_freq = [];
raw_freq.label = raw.label;
raw_freq.trial = arrayfun(@(tr_i) false(size(raw.powspctrm,[2,4])), ...
    1:size(raw.powspctrm,1), 'UniformOutput',false);
raw_freq.time = arrayfun(@(tr_i) (raw.time + epoch.t0(tr_i)), ...
    1:size(raw.powspctrm,1), 'UniformOutput',false);
raw_freq.fsample = round(1/mean(diff(raw.time)),4,'significant');

mask_cfg = cfg;
mask_cfg.value = true;
masked_freq = bml_mask(mask_cfg, raw_freq);

mask = permute(cat(3,masked_freq.trial{:}), [3,1,4,2]);
mask = repmat(mask,[1,1,size(raw.powspctrm,3),1]);

masked = raw;
masked.powspctrm(mask==1) = cfg.value;





