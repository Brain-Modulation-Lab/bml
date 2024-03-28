function [hFigure, hSurface] = bml_plot3d_surface(cfg, vertices, faces)
% Latane Bullock 2023 08 01 latanebullock@gmail.com

% BML_PLOT3D_SURFACE plots a 3d  surface. This script can plot subortical 
% or cortical surfaces. Users can optionally plot electrodes. 
%
% Use as
%   bml_plot_cortical_surface(cfg, raw);
%   bml_plot_cortical_surface(raw);
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.electrodes - an electrode table specifying the location of electrodes
% to plot. Electrodes should have columns 'x', 'y', 'z' to plot. 

snap_elecs_to_surf = bml_getopt(cfg,'snap_elecs_to_surf',false);
fig_title = bml_getopt(cfg,'title','');
cam_view = bml_getopt(cfg,'view',[-96 15]);
electrodes = bml_getopt(cfg,'electrodes',table());
surface_facealpha = bml_getopt(cfg,'surface_facealpha', 1);
surface_facecolor =  bml_getopt(cfg,'surface_facecolor', []);
h_ax = bml_getopt(cfg,'h_ax', []);


%% set default colors 
COLORS = []; 
COLORS.electrode = [66, 164, 245]./255; 
COLORS.electrode_highlight = 'r'; 
COLORS.surface = [.9 .9 .9];

%% Plot cortical surface
if isempty(h_ax)
    hFigure = figure('Color', 'w');
    h_ax = gca; 
else 
    axes(h_ax); 
end

if isempty(surface_facecolor)
    surface_facecolor = COLORS.surface; 
end


hSurface = patch('vertices', vertices, 'faces', faces,...
        'FaceColor', surface_facecolor, 'EdgeColor', 'none', 'FaceAlpha',surface_facealpha, ...
        'facelighting', 'gouraud', 'specularstrength', 0, 'ambientstrength', 0.5, 'diffusestrength', 0.5); 
view(cam_view); 
hL = camlight('headlight','infinite');
hRotate = rotate3d; 

hold on
axis off; axis equal; axis tight; 


% add a callback which will be executed after each rotation
set(hRotate,'ActionPostCallback',{@move_light_source, hL});

% remove multiple lights if they exist
hL = findobj(gca, 'type', 'light');
if length(hL)>1
    delete(hL(2:end))
end

%% Plot electrodes if electrodes table present
if ~isempty(electrodes)

if snap_elecs_to_surf 
    % Snap coordinates to closest vertex on the pial surface
    cols = {'name', 'x', 'y', 'z'};
    coords = electrodes(:, cols(2:end));
    [~, idxs] = min(pdist2(coords{:, :}, vertices), [], 2);
    coords = vertices(idxs, :);

    electrodes.x = coords(:, 1);
    electrodes.y = coords(:, 2);
    electrodes.z = coords(:, 3);
%     tit = "cohort_coverage_good_white_bad_black_closest-vertex.png";
% % else
%     electrodes.native_x = electrodes.native_x; 
end

% now plot electrodes
cfg = []; 
cfg.radius = 1; 
cfg.h_ax = h_ax; 
bml_plot3d_points(cfg, electrodes); 
% scatter3(electrodes.x, electrodes.y, electrodes.z, 12, 'filled','MarkerEdgeColor','k');


title(fig_title); 

end



% 
% % highlight a single electrodee
% subset = electrodes;
% hE = gobjects([1 height(subset)]); 
% for ielec = 1:height(subset)
%     hE(ielec) = scatter3(subset.native_x(ielec), subset.native_y(ielec), subset.native_z(ielec), ... 
%         20,'filled','MarkerFaceColor', COLORS.electrodes, 'MarkerEdgeColor','k', ...
%         'DisplayName', subset.name{ielec}, 'ButtonDownFcn', @(src,event) elec_select_callback(src, event, COLORS)); 
% end

% scatter3(electrodes.x, electrodes.y, electrodes.z,12,'filled','MarkerEdgeColor','k'); 

% iptaddcallback(hE,);


% % Highlight some electrodes 
% idxs_highlight = ismember(electrodes.name, ELECS_HIGHLIGHT); 
% set(hE(idxs_highlight), 'MarkerFaceColor', COLORS.electrode_highlight); 



end


% This function will move the light after each rotation
function move_light_source(src, evt, hL)
disp('updating camlight')  ;  
camlight(hL, 'headlight');
end





