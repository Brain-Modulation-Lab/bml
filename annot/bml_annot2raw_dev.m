function raw = bml_annot2raw_dev(cfg, annot)

% BML_ANNOT2RAW creates a ft_datatype_raw from and annotation table
%
% Use as
%   raw = bml_annot2raw(cfg, annot)
%   raw = bml_annot2raw(cfg.roi, annot)
%   raw = bml_annot2raw(cfg.template, annot)
%   raw = bml_annot2raw(cfg)
%   raw = bml_annot2raw(cfg.roi)
%   raw = bml_annot2raw(cfg.template)
%
% cfg.roi - roi table from which to construct raw
% cfg.label - cellstr, names of channels in new raw. Defaults to 'annot' if
%     annot_label_colname is not provided.
% cfg.annot_label - string, indicates channel on which events should be
%     added. Defaults to cfg.label{1}.
% cfg.label_colname - cellstr, indicating name of column of annot
%     containging the channel's label the current annotation should be
%     added to. If not given, all annotations are added
%     to same channel defined by annot_label.
% cfg.annot_label_colname - (deprecated) same as label_colname
% cfg.template - raw to use as template
% cfg.value_type - string: {'presence', 'count', 'column'}. boolean indicating if number in raw should indicate number of
%     annotations at that time point. If 'column', 'value_colname' should be
%     specified. Defaults to presence.
% cfg.value_colname - string, the column name in annot with which raw
%     should be filled.
% cfg.fill_function - function handle. Should take two arguments and
%     returne a matrix of specified size. Defaults to zeros. Common alternatives
%     are '@(x,y) nan(x,y)', '@(x,y) ones(x,y)', '@(x,y) randn(x,y)', etc.
% annot - annotation table. If omitted a raw of zeros (or as determined by
%     fill_function) is returned.
%
% returns a FT_DATAYE_RAW structure with ones during the annotations

if istable(cfg)
    cfg = struct('roi',cfg);
elseif isstruct(cfg) && all(ismember({'trial','time','label'},fieldnames(cfg)))
    cfg = struct('template',cfg);
end
roi         = bml_getopt(cfg,'roi');
template    = bml_getopt(cfg,'template');
% count       = bml_getopt(cfg,'count',true);
value_type       = bml_getopt(cfg,'value_type', 'presence');
value_colname       = bml_getopt(cfg,'value_colname', []);
label       = bml_getopt(cfg,'label',[]);
annot_label	= bml_getopt(cfg,'annot_label',[]);
annot_label_colname = bml_getopt(cfg,'annot_label_colname',[]);
label_colname =  bml_getopt(cfg,'label_colname',annot_label_colname);
fill_function = bml_getopt(cfg,'fill_function',@(x,y) zeros(x,y));

if nargin == 2
    annot = bml_annot_table(annot,[],inputname(2));
else
    annot = [];
end

if ~isempty(label)
    label = cellstr(label);
    if size(label,1) < size(label,2)
        label = label';
    end
end

if isempty(label_colname)
    if isempty(label)
        if isempty(template)
            label = {'annot'}; %default
        else
            fprintf('using labels from template');
            label = template.label;
        end
    end
    if isempty(annot_label)
        annot_label = label{1}; %default
    end

else %label_colname present
    if istable(annot)
        if isempty(annot)
            warning('empty annot table passed to bml_annot2raw');
            ul =[];
        elseif sum(strcmp(annot.Properties.VariableNames, label_colname))~=1
            error('cfg.label_colname should match a column of annot');
        else
            ul = unique(annot{:,label_colname});
        end
        if isempty(label)
            if isempty(template)
                if ~isempty(ul)
                    fprintf('using levels of %s as labels\n', label_colname{1})
                    label = ul;
                else
                    label = {'annot'};
                end
            else
                fprintf('using labels from template\n');
                label = template.label;
            end
        end
        if ~isempty(annot_label)
            fprintf('cfg.label_colname found in annot, ignoring cfg.annot_label \n');
        end
    else
        error('label_annot specified but no annot table given');
    end
end

assert(~isempty(roi) || ~isempty(template),'cfg.roi or cfg.template required');

%creating raw
if ~isempty(roi) %from roi
    raw=[];
    raw.time=cell(1,height(roi));
    raw.trial=cell(1,height(roi));
    raw.fsample=roi.Fs(1);
    raw.label = label;
    assert(length(unique(roi.Fs))==1, "Inconsistent Fs in roi");
    for i=1:height(roi)
        raw.time{i}=bml_idx2time(roi(i,:),roi.s1(i):roi.s2(i));
        raw.trial{i}=fill_function(length(label),size(raw.time{i},2));
    end
elseif ~isempty(template) %from template
    raw = template;
    for i=1:length(raw.trial)
        raw.trial{i}=fill_function(length(label),size(raw.time{i},2));
    end
    raw.label = label;
    roi = bml_raw2annot(raw);
else
    error('cfg.roi or cfg.template required');
end

if istable(annot)

    description = annot.Properties.Description;
    if isempty(description)
        description = 'annot';
    end
    if length(raw.label)==1 && strcmp(raw.label{1},'annot')
        raw.label={description};
    end

    % assigning all annotation to same channel of raw
    warning_flag = 0 ;
    if isempty(label_colname)
        annot_idx   = bml_getidx(annot_label,raw.label);
        if annot_idx > 0 && annot_idx <= numel(raw.label)
            for t=1:height(roi)
                t_annot = bml_annot_filter(annot,roi(t,:));
                for i=1:height(t_annot)

                    if t_annot.starts(i)==t_annot.ends(i) % duration 0... single 'dirac delta' event
                        [s,~] = bml_crop_idx_valid(roi(t,:), t_annot.starts(i), [], 1);
                        e = s;
                    else
                        [s,e] = bml_crop_idx_valid(roi(t,:), t_annot.starts(i), t_annot.ends(i));
                    end

                    if value_type=="count"
                        raw.trial{t}(annot_idx,s:e)=raw.trial{t}(annot_idx,s:e)+1;
                    elseif value_type=="presence"
                        raw.trial{t}(annot_idx,s:e)=1;
                    elseif value_type=="column"
                        %                val = unique(t_annot.(value_colname{1}));
                        vals = t_annot.(value_colname{1}); % value_colname is a cell array
                        %                if length(val)>1 && ~warning_flag
                        %                 warning('Conflicting annotation values for column: %s. \nAssuming first value.', value_colname{1})
                        %                 warning_flag = 1;
                        %
                        %                 t_annot = bml_annot_filter()
                        %                end
                        %                val = val(1);
                        raw.trial{t}(annot_idx,s:e) = vals(i);
                    else; error('Unrecognized "value_type" parameter: %s', value_type);
                    end
                end
            end
        end

    elseif ~isempty(annot) %annotations assing to specific channels

        %iterating over labels
        for i_l=1:numel(label)
            annot_l = annot(strcmp(annot{:,label_colname},label{i_l}),:);
            annot_idx = bml_getidx(label{i_l},raw.label);
            if annot_idx > 0 && annot_idx <= numel(raw.label)
                for t=1:height(roi)
                    t_annot_l = bml_annot_filter(annot_l,roi(t,:));
                    for i=1:height(t_annot_l)
                        [s,e] = bml_crop_idx_valid(roi(t,:), t_annot_l.starts(i), t_annot_l.ends(i));
                        if count
                            raw.trial{t}(annot_idx,s:e)=raw.trial{t}(annot_idx,s:e)+1;
                        else
                            raw.trial{t}(annot_idx,s:e)=t_annot_l.(cfg.value_colname)(i);
                        end
                    end
                end
            end
        end
    end
end




