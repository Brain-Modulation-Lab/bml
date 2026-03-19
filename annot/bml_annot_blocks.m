function [blocks, edges] = bml_annot_blocks(cfg, annot)
% BML_ANNOT_BLOCKS Groups annotations by label and temporal contiguity.

% --- Parameters & Cleanup ---
label        = bml_getopt(cfg, "label", []);
group_by     = bml_getopt(cfg, "group_by", []); 
win_edges    = bml_getopt(cfg, "win_edges", mean(annot.duration) * 0.7);
dt_tolerance = bml_getopt(cfg, "dt_tolerance", 1e-3); 

% SANITIZE: Ensure label is a char (string/cell handling)
if iscell(label) || (isstring(label) && numel(label) == 1)
    label = char(label);
end

% SANITIZE: Ensure group_by is a char if it's a single value in a cell/string
if ~isempty(group_by)
    if iscell(group_by) && numel(group_by) == 1
        group_by = char(group_by);
    elseif isstring(group_by) && numel(group_by) == 1
        group_by = char(group_by);
    end
end

% Validation
if isempty(label) || ~ismember(label, annot.Properties.VariableNames)
    error("Valid 'label' column '%s' required in annot table.", string(label));
end

% --- Step 1: Temporal Contiguity & Master Grouping ---
annot = sortrows(annot, 'starts');
n_rows = height(annot);

if n_rows > 1
    gaps = annot.starts(2:end) - annot.ends(1:end-1);
    is_gap = [true; gaps > dt_tolerance];
else
    is_gap = true;
end
contiguity_id = cumsum(is_gap);

% Determine the master grouping
if isempty(group_by)
    group_var_values = contiguity_id;
else
    % findgroups can handle cell arrays of strings or char vectors for column names
    user_groups = annot(:, group_by); 
    [combined_id, ~] = findgroups(user_groups, table(contiguity_id));
    group_var_values = combined_id(:); 
end

annot.master_grouping = group_var_values;
group_var = 'master_grouping';

% Pre-calculate global IDs for label consistency
label_id_col = [label, '_id'];
[~, ~, global_label_ids] = unique(string(annot.(label)));

% --- Step 2: Main Blocking Loop ---
groups = unique(annot.(group_var));
blocks = table();

for i = 1:numel(groups)
    group_mask = (annot.(group_var) == groups(i));
    annot_g = annot(group_mask, :);
    if isempty(annot_g), continue; end
    
    tt = string(annot_g.(label));
    
    % Block logic: changes in label within a contiguous time-chunk
    new_label_block = [true; ~strcmp(tt(2:end), tt(1:end-1))];
    bid             = cumsum(new_label_block);
    n_sub_blocks    = max(bid);
    
    blocks_r = table();
    blocks_r.starts      = splitapply(@min, annot_g.starts, bid);
    blocks_r.ends        = splitapply(@max, annot_g.ends, bid);
    blocks_r.(label)     = splitapply(@(x) x(1), tt, bid);
    
    % Carry over original group_by columns
    if ~isempty(group_by)
        % Using table indexing to grab the first row's metadata for this group
        if ischar(group_by)
            blocks_r.(group_by) = repmat(annot_g.(group_by)(1), n_sub_blocks, 1);
        else
            % If group_by was a list of columns, copy all of them
            for g_col = 1:numel(group_by)
                curr_col = group_by{g_col};
                blocks_r.(curr_col) = repmat(annot_g.(curr_col)(1), n_sub_blocks, 1);
            end
        end
    end
    
    % Assign consistent Label IDs
    group_label_ids = global_label_ids(group_mask);
    blocks_r.(label_id_col) = splitapply(@(x) x(1), group_label_ids, bid);

    blocks = bml_annot_rowbind(blocks, blocks_r);
end

blocks = bml_annot_table(blocks);
blocks = bml_annot_consolidate(blocks);

% --- Step 3: Edges (Transitions) ---
if height(blocks) >= 2
    block_gaps = blocks.starts(2:end) - blocks.ends(1:end-1);
    idx_from   = find(block_gaps <= dt_tolerance);
    
    if isempty(idx_from)
        edges = table();
    else
        edges = table();
        edges.starts  = blocks.ends(idx_from);
        edges.ends    = blocks.ends(idx_from);
        edges.from_id = idx_from;
        edges.to_id   = idx_from + 1;

        edges.(['from_', label]) = string(blocks.(label)(edges.from_id));
        edges.(['to_', label])   = string(blocks.(label)(edges.to_id));
        edges.transition         = edges.(['from_', label]) + " -> " + edges.(['to_', label]);
        
        edges.(['from_', label_id_col]) = blocks.(label_id_col)(edges.from_id);
        edges.(['to_', label_id_col])   = blocks.(label_id_col)(edges.to_id);

        if numel(win_edges) == 1, win_edges = [win_edges, win_edges]; end
        edges = bml_annot_extend(edges, win_edges);
        edges = bml_annot_table(edges);
    end
else
    edges = table();
end

end