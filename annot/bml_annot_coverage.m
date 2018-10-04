function coverage = bml_annot_coverage(cfg, numerator, denominator)

% BML_ANNOT_COVERAGE calculates the fraction of denominator covered by
% numerator
%
% Use as
%   coverage = bml_annot_coverage(cfg, numerator, denominator);
%   coverage = bml_annot_coverage(numerator, denominator);
%
% The first argument cfg is a optional configuration structure with
% the following optional fields:
%
% cfg.groupby - cellstr indicating grouping columns of numerator. If empty
%   (default), all rows of numerator are considered in the same group.
%
% numerator, denominator - annot tables with fields 'starts' and 'ends'.
%
% Returns an annotation table with the same variables as denominator plus
% and additional coverage variable. If groupby is given, each row of 
% denominator is expanded into a group of size given by the number of levels of
% groupby. The grouping variable of numerator is included in coverage. 

if nargin == 2
  denominator = numerator;
  numerator = cfg;
  cfg = [];
elseif nargin ~= 3
  error('incorrect use of bml_annot_coverage. See help.');
end

groupby   = bml_getopt(cfg,'groupby',[]);

%ToDo: allow grouping by several variables
if isempty(groupby)
  numerator.groupby_ = ones(height(numerator),1);
  groupby = {'groupby_'};
  groups={1};
else
	if sum(strcmp(numerator.Properties.VariableNames, groupby))~=1
    error('groupby should match one (and only one) column of numerator');
  end
  groups = unique(numerator{:,groupby});
end

coverage = table();
for g=1:numel(groups)
  if iscellstr(groups(g))
    numerator_g = numerator(strcmp(numerator{:,groupby},groups(g)),:);
  else
    numerator_g = numerator(numerator{:,groupby}==groups{g},:);    
  end
  
  for d=1:height(denominator)
    denominator_d = denominator(d,:);
    cfg1=[];
    cfg1.keep='none';
    intsc = bml_annot_intersect(cfg1,numerator_g,denominator_d);
    if isempty(intsc)
      cvg = 0;
    else
      cvg = sum(intsc.duration) ./ denominator.duration(d);
    end
    denominator_d.(groupby{1}) = groups(g);
    denominator_d.coverage = cvg;
    coverage = [coverage; denominator_d];
  end
end

if any(strcmp('groupby_',coverage.Properties.VariableNames))
  coverage.groupby_ = [];
end

coverage.id=[];
coverage = bml_annot_table(coverage);



