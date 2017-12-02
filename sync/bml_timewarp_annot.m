function [slave_delta_t, min_cost, warpfactor] = bml_timewarp_annot(cfg, master, slave)

% BML_TIMEWARP_ANNOT is an alias for BML_TIMEALIGN_ANNOT with enforced timewarp

cfg.timewarp = true;
[slave_delta_t, min_cost, warpfactor] = bml_timealign_annot(cfg, master, slave);