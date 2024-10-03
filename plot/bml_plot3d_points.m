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
% points - a table (usually with a set of electrodes) specifying the location of electrodes
% to plot. Electrodes should have columns 'x', 'y', 'z' to plot. 
% 
% points can optionally have a column 'color' where each row is an
% [R G B] color value row vector. 

radius = bml_getopt(cfg,'radius', 1);
h_ax = bml_getopt(cfg,'h_ax', []);
is_interactive = bml_getopt(cfg,'is_interactive', 0);



%% set default colors 
COLORS = []; 
% COLORS.electrode = [66, 164, 245]./255; % blue
COLORS.electrode = [255 0 0]./255; % blue
COLORS.electrode_highlight = 'r'; 
COLORS.surface = [.9 .9 .9];
COLORS.selected = []; 

[sphere_x,sphere_y,sphere_z] = sphere(50);

if ~ismember('color', points.Properties.VariableNames)
    points.color = repmat(COLORS.electrode, [height(points), 1]); 
end

if ~ismember('radius', points.Properties.VariableNames)
    points.radius = repmat(radius, [height(points), 1]); 
end


%% Plot spheres in 3D space
if isempty(h_ax)
    figure('Color', 'w');
    h_ax = gca; 
else 
    axes(h_ax); 
end
hold on

if size(points.color, 2)==1 % if user has passed color DATA values
    h_points = gobjects(1, height(points));
    for ip = 1:height(points) % this version enables plotting with color bar
        x = points.radius(ip) .* sphere_x + points.x(ip);
        y = points.radius(ip) .* sphere_y + points.y(ip);
        z = points.radius(ip) .* sphere_z + points.z(ip);
        c = ones(size(z))*points.color(ip);
        try
            h_points(ip)=surf(x, y, z, c, ...
                'EdgeColor','none', 'FaceColor', 'flat', ...
                'DisplayName', points.name{ip});
        catch
            h_points(ip)=surf(x, y, z, c, ...
                'EdgeColor','none', 'FaceColor', 'flat');
        end
        
    end
else % if user has passed specific colors
    h_points = gobjects(1, height(points));
    for ip = 1:height(points) % this version ignores colorbar, just indicates face color
        x = points.radius(ip).*sphere_x + points.x(ip);
        y = points.radius(ip).*sphere_y + points.y(ip);
        z = points.radius(ip).*sphere_z + points.z(ip);
        try
            h_points(ip)=surf(x, y, z, [], 'facecolor', points.color(ip, :), ...
                'EdgeColor','none', 'DisplayName', points.name{ip});
        catch
            h_points(ip)=surf(x, y, z, [], 'facecolor', points.color(ip, :), ...
                'EdgeColor','none');
        end
    end
end

h_points_orig = copyobj(h_points, h_ax);
set(h_points_orig, 'Visible', 'off');

if is_interactive
h_annotation = annotation('textbox', [0.1, 0.1, 0.1, 0.1], 'String', "Selected:", 'Interpreter', 'none'); 
set(h_points, 'ButtonDownFcn', @(src, event) set_selected_object(src, event, h_points, h_points_orig,  h_annotation, COLORS.electrode_highlight)  );
set(h_ax.Parent, 'Pointer', 'crosshair')
end

end

function set_selected_object(src, event, h_points, h_points_orig,  h_annotation, select_color)

for ip = 1:numel(h_points); set(h_points(ip), 'facecolor', h_points_orig(ip).FaceColor); end
set(src, 'facecolor', select_color);
set(h_annotation, 'String', "Selected: " + src.DisplayName);
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





% % This function will move the light after each rotation
% function move_light_source(src, evt, hL)
% disp('updating camlight')  ;  
% camlight(hL, 'headlight');
% end





