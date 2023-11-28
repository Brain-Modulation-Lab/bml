function [h_points] = bml_plot3d_points(cfg, points)
% Latane Bullock 2023 08 01 latanebullock@gmail.com

% BML_PLOT3D_points plots 3d points. This script can be used to plot
% locations of elecrodes on the cortical surface or on subcortical
% surfaces. 
%
% Use as
%   bml_plot3d_points(cfg, points_table);
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.electrodes - an electrode table specifying the location of electrodes
% to plot. Electrodes should have columns 'x', 'y', 'z' to plot. 

snap_elecs_to_surf = bml_getopt(cfg,'snap_elecs_to_surf',false);
fig_title = bml_getopt(cfg,'title','');
cam_view = bml_getopt(cfg,'view',[-96 15]);
surface_facealpha = bml_getopt(cfg,'surface_facealpha',1);
radius = bml_getopt(cfg,'radius', 1);
h_ax = bml_getopt(cfg,'h_ax', []);


%% set default colors 
COLORS = []; 
COLORS.electrode = [66, 164, 245]./255; 
COLORS.electrode_highlight = 'r'; 
COLORS.surface = [.9 .9 .9];

[sphere_x,sphere_y,sphere_z] = sphere(50);

if ~ismember('color', points.Properties.VariableNames)
    points.color = repmat([1 0 0], [height(points), 1]); 
end


%% Plot spheres in 3D space
if isempty(h_ax)
    figure('Color', 'w');
    h_ax = gca; 
else 
    axes(h_ax); 
end
hold on

h_points = gobjects(1, height(points)); 
for ip = 1:height(points)
    h_points(ip)=surf(radius.*sphere_x + points.x(ip), ...
                      radius.*sphere_y + points.y(ip), ...
                      radius.*sphere_z + points.z(ip), ...
                'FaceColor', points.color(ip, :), ...
                'EdgeColor','none', 'DisplayName', 'temporary_name');
end

% now plot electrodes
% scatter3(points.x, points.y, points.z,12,'filled','MarkerEdgeColor','k');

end





% 
% % highlight a single electrodee
% subset = electrode;
% hE = gobjects([1 height(subset)]); 
% for ielec = 1:height(subset)
%     hE(ielec) = scatter3(subset.native_x(ielec), subset.native_y(ielec), subset.native_z(ielec), ... 
%         20,'filled','MarkerFaceColor', COLORS.electrode, 'MarkerEdgeColor','k', ...
%         'DisplayName', subset.name{ielec}, 'ButtonDownFcn', @(src,event) elec_select_callback(src, event, COLORS)); 
% end

% scatter3(electrode.x, electrode.y, electrode.z,12,'filled','MarkerEdgeColor','k'); 

% iptaddcallback(hE,);


% % Highlight some electrodes 
% idxs_highlight = ismember(electrode.name, ELECS_HIGHLIGHT); 
% set(hE(idxs_highlight), 'MarkerFaceColor', COLORS.electrode_highlight); 





% This function will move the light after each rotation
function move_light_source(src, evt, hL)
disp('updating camlight')  ;  
camlight(hL, 'headlight');
end





