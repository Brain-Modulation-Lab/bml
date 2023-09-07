function bml_annot_plot(cfg, annot, varargin)

% BML_ANNOT_PLOT plots an annotation table
%
% Use as
%   bml_annot_plot(annot, varargin)
%   bml_annot_plot(cfg, annot, varargin)
%
% cfg - configuration structure
% annot - annotation table
% varargin - further arguments for plot
%
% cfg.y - char indicating variable to use for y axis. Default to 'id'
% cfg.facet - char indicating variable by wich to facet the plot
% cfg.subplot_m - number of rows of the subplot layout. Defaults to the
%         number of levels of the facet variable
% cfg.subplot_n - number of columns of the subplot layout. Defaults to 1
% cfg.subplot_p - start index of the subplot. Defaults to 0. 

if istable(cfg)
  if ~exist('annot','var')
    annot = [];
  end
  varargin = [annot, varargin];
  annot = cfg;
  cfg=[];
end

yvar         = bml_getopt_single(cfg,'y','id');
yvar_offset  = bml_getopt_single(cfg,'y_offset', 0); % added Latane Bullock 2023 05 31
facetvar     = bml_getopt_single(cfg,'facet');

annot = bml_annot_table(annot);

if isempty(varargin)
  varargin={'LineWidth',0.5};
end

if isempty(facetvar)
  for i=1:height(annot)
    hold on;
    annot_yvar = annot.(yvar);
    plot([annot.starts(i),annot.ends(i)],[annot_yvar(i)+yvar_offset,annot_yvar(i)+yvar_offset],varargin{:})
    ylabel(yvar);
    xlabel('Time (s)');
  end
else
    
  assert(ismember(facetvar,annot.Properties.VariableNames),'unknown variable %s',facetvar)
  u=unique(annot.(facetvar));
  
  subplot_m = bml_getopt(cfg,'subplot_m',length(u));
  subplot_n = bml_getopt(cfg,'subplot_n',1);
  subplot_p = bml_getopt(cfg,'subplot_p',0);
  
  for i=1:length(u)
    db = annot(strcmp(annot.(facetvar),u(i)),:);
    subplot(subplot_m,subplot_n,subplot_p+i);
    db_yvar = db.(yvar);
    for j=1:height(db)
      hold on;
      plot([db.starts(j),db.ends(j)],[db_yvar(j),db_yvar(j)],varargin{:})
    end
    ylabel(u(i));
    if i == length(u)
      xlabel('Time (s)');
    end
    xlim([min(annot.starts),max(annot.ends)]);
  end
end


