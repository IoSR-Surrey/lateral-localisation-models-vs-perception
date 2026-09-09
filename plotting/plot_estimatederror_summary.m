function [errormetrics] = plot_estimatederror_summary(error_struct,listexp_id,color_info,target_axes,equal_xy_limits)
%PLOT_ESTIMATEDERROR_SUMMARY Plot a linear-model summary of model vs perceptual data.
%
% Optional third argument color_info is a struct that overrides the default
% data markers with per-point colored markers. Supported fields:
%   kind             'continuous' | 'discrete' | 'uniform'
%   values           vector of per-point grouping values (same length as
%                    the predictor/response data used by
%                    error_struct.error)
%   label            (optional) colorbar/legend title
%   categories       (optional) cell array of labels, one per unique
%                    group, used for the legend when kind='discrete'
%   symmetric        (optional, default true) if true and
%                    kind='continuous', center the color axis on zero
%   shape_values     (optional) vector of per-point shape-grouping values
%                    (same length as values). Splits the scatter into one
%                    series per shape group, each drawn with a distinct
%                    marker.
%   shape_markers    (optional) cell array of MATLAB marker specs (e.g.
%                    {'o','s','d','^'}), one per unique shape group, in
%                    the same order as the sorted unique shape values.
%   shape_categories (optional) cell array of labels, one per shape
%                    group, used for a separate shape legend.
%   shape_label      (optional) shape-legend title.
%   resp_xerr        (optional) per-point half-width for symmetric
%                    horizontal error bars on perceived angle (x-axis);
%                    same length as values. Typically SEM*2.
%   est_yerr         (optional) per-point half-width for symmetric
%                    vertical error bars on estimated angle (y-axis);
%                    same length as values. Typically model SEM across HRTFs.
%   marker_size      (optional) scatter marker area in points^2. Overrides
%                    the default tile (10) or standalone (40) size.
%
% Optional fourth argument target_axes is an axes handle (typically a tile
% from a tiledlayout). When supplied, the plot is drawn into that axes, the
% per-tile legend / colorbar / large title are suppressed (the caller is
% expected to add layout-level shared decorations), and only the model id is
% used as the tile title. When omitted, the function creates its own figure
% with full per-figure decorations.
%
% Optional fifth argument equal_xy_limits (default false) forces the x and
% y axis to share the same range (the union of the x- and y-data ranges).
% Set to true to get a square plot where the y=x fit line bisects the axes;
% leave false to let x and y fit their respective data independently.
    if nargin < 3
        color_info = [];
    end
    if nargin < 4
        target_axes = [];
    end
    if nargin < 5 || isempty(equal_xy_limits)
        equal_xy_limits = false;
    end
    standalone = nargin < 4 || isempty(target_axes);
    if standalone
        varfontsize = 10;
        annotation_fontsize = 14;
        tile_title_fontsize = [];
        marker_size = 40;
        shape_proto_size = 50;
    else
        pub_fs = grid_publication_font_sizes();
        varfontsize = pub_fs.tick;
        annotation_fontsize = pub_fs.annotation;
        tile_title_fontsize = pub_fs.tile_title;
        marker_size = 10;
        shape_proto_size = 12;
    end
    if ~isempty(color_info) && isfield(color_info, 'marker_size') ...
            && ~isempty(color_info.marker_size)
        marker_size = color_info.marker_size;
        shape_proto_size = max(shape_proto_size, marker_size);
    end

   %  if contains(error_struct.model_id, 'wierstorf2013_lindemann1986')
   %      figure;
   %      plot(error_struct.localisation);
   %      title("Model: " + error_struct.model_id + " - Data from " + listexp_id);
   %      grid on;
   %      text(20,-10,['R^2 = ' num2str(round(error_struct.localisation.Rsquared.Adjusted,2))],'Color','red','FontSize',18)
   %      xlim([-40 100])
   %      ylim([-80 100])
   %      xlabel('Perceived angle (°)')
   %      ylabel('Estimated angle (°)')
   %      legend('Location','southeast')
   %      ax = gca;
   %      ax.FontSize = varfontsize;
   % elseif contains(error_struct.model_id, 'lindemann1986') || contains(error_struct.model_id,'dietz2011')
   %      figure;
   %      plot(error_struct.itd);
   %      title("Model: " + error_struct.model_id + " - Data from " + listexp_id);
   %      grid on;
   %      text(20,-10,['R^2 = ' num2str(round(error_struct.itd.Rsquared.Adjusted,2))],'Color','red','FontSize',18)
   %      xlim([-40 100])
   %      ylim([-80 100])
   %      xlabel('Perceived angle (°)')
   %      ylabel('Estimated angle (°)')
   %      legend('Location','southeast')
   %      ax = gca;
   %      ax.FontSize = varfontsize;
   %  end
   % 
   %  if contains(error_struct.model_id, 'wierstorf2013_dietz2011')
   %      figure;
   %      plot(error_struct.localisation);
   %      title("Model: " + error_struct.model_id + " - Data from " + listexp_id);
   %      grid on;
   %      text(20,-10,['R^2 = ' num2str(round(error_struct.localisation.Rsquared.Adjusted,2))],'Color','red','FontSize',18)
   %      xlim([-40 100])
   %      ylim([-80 100])
   %      xlabel('Perceived angle (°)')
   %      ylabel('Estimated angle (°)')
   %      legend('Location','southeast')
   %      ax = gca;
   %      ax.FontSize = varfontsize;
   %  elseif contains(error_struct.model_id, 'dietz2011')
   %      figure;
   %      plot(error_struct.ildlp);
   %      title("Model: " + error_struct.model_id + "(from ILD LP) - Data from " + listexp_id);
   %      grid on;
   %      text(20,-10,['R^2 = ' num2str(round(error_struct.ildlp.Rsquared.Adjusted,2))],'Color','red','FontSize',18)
   %      xlim([-40 100])
   %      ylim([-80 100])
   %      xlabel('Perceived angle (°)')
   %      ylabel('Estimated angle (°)')
   %      legend('Location','southeast')
   %      ax = gca;
   %      ax.FontSize = varfontsize;
   %  end

    standalone = isempty(target_axes);
    if standalone
        figure;
        ax = gca;
    else
        ax = target_axes;
        axes(ax);
    end

    h = plot(error_struct.error);
    hold(ax, 'on');

    % Restyle the LinearModel fit line and confidence bounds to be red
    % and slightly bolder so they remain prominent on top of the scatter
    % points. h(1) is the data markers; h(2) is the fit line; h(3:end)
    % are the confidence bounds.
    % fit_color = [0.85 0.10 0.10];
    fit_color = 'r';
    if numel(h) >= 2 && isgraphics(h(2))
        set(h(2), 'Color', fit_color, 'LineWidth', 1.2);
    end
    for k = 3:numel(h)
        if isgraphics(h(k))
            set(h(k), 'Color', fit_color, 'LineWidth', 0.75);
        end
    end

    % y=x reference line. Endpoints are far outside any plausible data
    % range so MATLAB clips it to the axes box, regardless of any later
    % xlim/ylim adjustments by the grid wrapper. XLimInclude/YLimInclude
    % are off so the line never drives axis-limit computation, and
    % HandleVisibility is off so it stays out of any auto-detected
    % legend.
    yx_line = plot(ax, [-1e4, 1e4], [-1e4, 1e4], '--', ...
        'Color', [0.4 0.4 0.4], 'LineWidth', 1, ...
        'HandleVisibility', 'off');
    yx_line.XLimInclude = 'off';
    yx_line.YLimInclude = 'off';

    has_uniform = ~isempty(color_info) && isfield(color_info, 'kind') ...
        && strcmpi(color_info.kind, 'uniform');
    has_color = ~has_uniform && ~isempty(color_info) && isfield(color_info, 'values') ...
        && ~isempty(color_info.values);

    x = error_struct.error.Variables.(error_struct.error.PredictorNames{1});
    y = error_struct.error.Variables.(error_struct.error.ResponseName);
    resp_xerr = [];
    if ~isempty(color_info) && isfield(color_info, 'resp_xerr') ...
            && ~isempty(color_info.resp_xerr)
        resp_xerr = color_info.resp_xerr(:);
        if numel(resp_xerr) ~= numel(x)
            warning('plot_estimatederror_summary:resp_xerr_length_mismatch', ...
                'color_info.resp_xerr has %d entries but model has %d data points. Skipping response error bars.', ...
                numel(resp_xerr), numel(x));
            resp_xerr = [];
        end
    end

    est_yerr = [];
    if ~isempty(color_info) && isfield(color_info, 'est_yerr') ...
            && ~isempty(color_info.est_yerr)
        est_yerr = color_info.est_yerr(:);
    elseif isfield(error_struct, 'est_yerr') && ~isempty(error_struct.est_yerr)
        est_yerr = error_struct.est_yerr(:);
    end
    if ~isempty(est_yerr) && numel(est_yerr) ~= numel(x)
        warning('plot_estimatederror_summary:est_yerr_length_mismatch', ...
            'est_yerr has %d entries but model has %d data points. Skipping estimate error bars.', ...
            numel(est_yerr), numel(x));
        est_yerr = [];
    end

    if has_color
        cvals = color_info.values(:);
        if numel(cvals) ~= numel(x)
            warning('plot_estimatederror_summary:length_mismatch', ...
                'color_info.values has %d entries but model has %d data points. Skipping color overlay.', ...
                numel(cvals), numel(x));
            has_color = false;
        end
    end

    % Optional per-point shape grouping (different marker per group).
    has_shape = has_color && isfield(color_info, 'shape_values') ...
        && ~isempty(color_info.shape_values);
    if has_shape
        sh_vals = color_info.shape_values(:);
        if numel(sh_vals) ~= numel(x)
            warning('plot_estimatederror_summary:shape_length_mismatch', ...
                'color_info.shape_values has %d entries but model has %d data points. Skipping shape overlay.', ...
                numel(sh_vals), numel(x));
            has_shape = false;
        end
    end

    % Build the shape group ordering used by the scatter loop and by the
    % shape legend. When no shape grouping is given we use a single
    % implicit group with the default marker.
    if has_shape
        unique_shape_groups = unique(sh_vals(~isnan(sh_vals)));
        n_shape = numel(unique_shape_groups);
        shape_markers = {};
        if isfield(color_info, 'shape_markers') && ~isempty(color_info.shape_markers)
            shape_markers = color_info.shape_markers;
        end
        if numel(shape_markers) < n_shape
            default_markers = {'o','s','d','^','v','>','<','p','h','x','+','*'};
            shape_markers = [shape_markers, default_markers(1:n_shape-numel(shape_markers))];
        end
    else
        unique_shape_groups = NaN;
        n_shape = 1;
        shape_markers = {'o'};
    end

    resp_xerr_handles = gobjects(0);
    if ~isempty(resp_xerr)
        resp_xerr_handles = draw_resp_xerr(ax, x, y, resp_xerr);
    end

    est_yerr_handles = gobjects(0);
    if ~isempty(est_yerr)
        est_yerr_handles = draw_est_yerr(ax, x, y, est_yerr);
    end

    if has_uniform
        if ~isempty(h) && isgraphics(h(1))
            set(h(1), 'Visible', 'off');
        end
        marker_color = [0 0.4470 0.7410];
        if isfield(color_info, 'marker_color') && ~isempty(color_info.marker_color)
            marker_color = color_info.marker_color;
        end
        scatter(ax, x, y, marker_size, marker_color, 'filled', ...
            'Marker', 'o', 'MarkerEdgeColor', 'k', 'LineWidth', 0.3);
        fit_ci_handles = gobjects(0);
        for k = 2:numel(h)
            if isgraphics(h(k))
                fit_ci_handles(end + 1) = h(k); %#ok<AGROW>
            end
        end
        if ~isempty(fit_ci_handles)
            uistack(fit_ci_handles, 'top');
        end
        if ~isempty(resp_xerr_handles)
            uistack(resp_xerr_handles, 'bottom');
        end
        if ~isempty(est_yerr_handles)
            uistack(est_yerr_handles, 'bottom');
        end
        if standalone
            legend_handles = gobjects(0);
            legend_labels = {};
            if numel(h) >= 2 && isgraphics(h(2))
                legend_handles(end + 1) = h(2);
                legend_labels{end + 1} = 'Fit';
            end
            if numel(h) >= 3 && isgraphics(h(3))
                legend_handles(end + 1) = h(3);
                legend_labels{end + 1} = 'Confidence bounds';
            end
            if ~isempty(legend_handles)
                legend(ax, legend_handles, legend_labels, ...
                    'Location', 'southeast', 'Interpreter', 'none');
            end
        end
    elseif has_color
        % Hide default LinearModel data markers (handle 1); keep fit/CI lines.
        if ~isempty(h) && isgraphics(h(1))
            set(h(1), 'Visible', 'off');
        end

        % Track legend prototypes separately for color and shape so that
        % the standalone legend and the grid wrapper can present them as
        % two distinct legends rather than a combinatorial mix.
        color_proto_handles = gobjects(0);
        color_proto_labels = {};
        shape_proto_handles = gobjects(0);
        shape_proto_labels = {};

        if isfield(color_info, 'kind') && strcmpi(color_info.kind, 'continuous')
            for is = 1:n_shape
                if has_shape
                    smask = sh_vals == unique_shape_groups(is);
                else
                    smask = true(size(x));
                end
                if any(smask)
                    scatter(ax, x(smask), y(smask), marker_size, cvals(smask), 'filled', ...
                        'Marker', shape_markers{is}, ...
                        'MarkerEdgeColor', 'k', 'LineWidth', 0.3);
                end
            end
            colormap(ax, parula);
            symmetric = ~isfield(color_info, 'symmetric') || color_info.symmetric;
            if symmetric
                cmax = max(abs(cvals(~isnan(cvals))));
                if isfinite(cmax) && cmax > 0
                    clim(ax, [-cmax, cmax]);
                end
            end
            if standalone
                cb = colorbar(ax);
                if isfield(color_info, 'label') && ~isempty(color_info.label)
                    cb.Label.String = color_info.label;
                    cb.Label.FontSize = varfontsize;
                end
            end
        else
            unique_groups = unique(cvals(~isnan(cvals)));
            n_groups = numel(unique_groups);
            categories = {};
            if isfield(color_info, 'categories')
                categories = color_info.categories;
            end
            if ~isempty(categories)
                n_colors = numel(categories);
            else
                n_colors = n_groups;
            end
            cmap = discrete_colorblind_palette(n_colors);
            for ig = 1:n_groups
                gval = unique_groups(ig);
                if ~isempty(categories) && gval >= 1 && gval <= n_colors
                    color_idx = gval;
                else
                    color_idx = ig;
                end
                cmask = cvals == gval;
                for is = 1:n_shape
                    if has_shape
                        smask = sh_vals == unique_shape_groups(is);
                    else
                        smask = true(size(x));
                    end
                    mask = cmask & smask;
                    if any(mask)
                        scatter(ax, x(mask), y(mask), marker_size, cmap(color_idx,:), 'filled', ...
                            'Marker', shape_markers{is}, ...
                            'MarkerEdgeColor', 'k', 'LineWidth', 0.3);
                    end
                end
                % One prototype scatter per color group so the legend
                % shows a single uniform marker for each color category.
                proto = scatter(ax, NaN, NaN, marker_size, cmap(color_idx,:), 'filled', ...
                    'MarkerEdgeColor', 'k', 'LineWidth', 0.3, ...
                    'HandleVisibility', 'off');
                color_proto_handles(end+1) = proto; %#ok<AGROW>
                if ~isempty(categories) && gval >= 1 && gval <= numel(categories)
                    color_proto_labels{end+1} = categories{gval}; %#ok<AGROW>
                else
                    color_proto_labels{end+1} = sprintf('%g', gval); %#ok<AGROW>
                end
            end
        end

        % Shape prototypes (in neutral grey) for an independent shape
        % legend. These are drawn at NaN coords so they never affect
        % limits, and HandleVisibility off so the auto legend ignores
        % them by default.
        if has_shape
            shape_categories = {};
            if isfield(color_info, 'shape_categories') && ~isempty(color_info.shape_categories)
                shape_categories = color_info.shape_categories;
            end
            for is = 1:n_shape
                proto = scatter(ax, NaN, NaN, shape_proto_size, [0.4 0.4 0.4], 'filled', ...
                    'Marker', shape_markers{is}, ...
                    'MarkerEdgeColor', 'k', 'LineWidth', 0.3, ...
                    'HandleVisibility', 'off');
                shape_proto_handles(end+1) = proto; %#ok<AGROW>
                if numel(shape_categories) >= is
                    shape_proto_labels{end+1} = shape_categories{is}; %#ok<AGROW>
                else
                    shape_proto_labels{end+1} = sprintf('%g', unique_shape_groups(is)); %#ok<AGROW>
                end
            end
        end

        % Stash the prototype handles in the axes UserData so the grid
        % wrapper can pick them up to build shared layout-level legends.
        ax.UserData.color_proto_handles = color_proto_handles;
        ax.UserData.color_proto_labels  = color_proto_labels;
        ax.UserData.shape_proto_handles = shape_proto_handles;
        ax.UserData.shape_proto_labels  = shape_proto_labels;

        % The custom scatter markers were drawn after plot(lm), so they
        % currently sit on top of the fit/CI lines. Raise the fit line
        % (and confidence bounds, when present) above the scatter points
        % so the regression line is always visible.
        fit_ci_handles = gobjects(0);
        for k = 2:numel(h)
            if isgraphics(h(k))
                fit_ci_handles(end+1) = h(k); %#ok<AGROW>
            end
        end
        if ~isempty(fit_ci_handles)
            uistack(fit_ci_handles, 'top');
        end
        if ~isempty(resp_xerr_handles)
            uistack(resp_xerr_handles, 'bottom');
        end
        if ~isempty(est_yerr_handles)
            uistack(est_yerr_handles, 'bottom');
        end

        if standalone
            legend_handles = gobjects(0);
            legend_labels = {};
            if ~isempty(color_proto_handles)
                legend_handles = [legend_handles, color_proto_handles];
                legend_labels = [legend_labels, color_proto_labels];
            end
            if ~isempty(shape_proto_handles)
                legend_handles = [legend_handles, shape_proto_handles];
                legend_labels = [legend_labels, shape_proto_labels];
            end
            % Attach fit / confidence-bound entries to the legend (if present).
            if numel(h) >= 2 && isgraphics(h(2))
                legend_handles(end+1) = h(2);
                legend_labels{end+1} = 'Fit';
            end
            if numel(h) >= 3 && isgraphics(h(3))
                legend_handles(end+1) = h(3);
                legend_labels{end+1} = 'Confidence bounds';
            end

            if ~isempty(legend_handles)
                lg = legend(ax, legend_handles, legend_labels, ...
                    'Location', 'southeast', 'Interpreter', 'none');
                if ~strcmpi(color_info.kind, 'continuous') ...
                        && isfield(color_info, 'label') && ~isempty(color_info.label)
                    title(lg, color_info.label);
                end
            end
        end
    elseif standalone
        legend(ax, 'Location', 'southeast')
    end

    if ~has_color && ~has_uniform
        if ~isempty(resp_xerr_handles)
            uistack(resp_xerr_handles, 'bottom');
        end
        if ~isempty(est_yerr_handles)
            uistack(est_yerr_handles, 'bottom');
        end
    end

    model_label = format_model_plot_label(error_struct.model_id);
    if standalone
        title(ax, "Model: " + model_label + " - Data from " + listexp_id, ...
            'Interpreter', 'none');
    else
        title(ax, model_label, 'Interpreter', 'none', 'FontSize', tile_title_fontsize);
        if exist('h', 'var') && numel(h) >= 1
            % Tile-mode never needs the per-tile auto legend that plot(lm) creates.
            legend(ax, 'off');
        end
    end
    grid(ax, 'on');
    % Single multiline text keeps line spacing consistent in screen and PDF.
    annotation_label = build_fit_annotation_label(error_struct, listexp_id);
    text(ax, 0.04, 0.96, annotation_label, ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', ...
        'Interpreter', 'tex', ...
        'Color', 'red', 'FontSize', annotation_fontsize);
    % Pick axis limits driven by the actual data so all points are clearly
    % visible. By default x and y are scaled independently; set the
    % equal_xy_limits toggle to force them to share a single range (square
    % plot, y=x bisects the axes). The grid wrapper may later override
    % these to be consistent across tiles.
    [xlim_data, ylim_data] = compute_data_axis_limits(error_struct.error, [], resp_xerr, est_yerr);
    if equal_xy_limits
        lo = min(xlim_data(1), ylim_data(1));
        hi = max(xlim_data(2), ylim_data(2));
        xlim_data = [lo, hi];
        ylim_data = [lo, hi];
    end
    xlim(ax, xlim_data);
    ylim(ax, ylim_data);
    if standalone
        xlabel(ax, 'Perceived angle (°)')
        ylabel(ax, 'Estimated angle (°)')
    else
        % Tile mode: the grid wrapper attaches one shared x/y label at the
        % tiledlayout level so we don't repeat them on every tile. plot(lm)
        % auto-fills these with the variable names, so we explicitly clear.
        xlabel(ax, '')
        ylabel(ax, '')
    end
    ax.FontSize = varfontsize;



    % if contains(error_struct.model_id, 'lindemann1986') || contains(error_struct.model_id,'dietz2011')
    %     figure;
    %     plot(error_struct.error);
    %     title("Model: " + error_struct.model_id + " - Data from " + listexp_id);
    %     grid on;
    %     text(20,-10,['R^2 = ' num2str(round(error_struct.itd.Rsquared.Adjusted,2))],'Color','red','FontSize',18)
    %     xlim([-40 100])
    %     ylim([-80 100])
    %     xlabel('Perceived angle (°)')
    %     ylabel('Estimated angle (°)')
    %     legend('Location','southeast')
    %     ax = gca;
    %     ax.FontSize = varfontsize;
    % 
    % end
    % 
    % if contains(error_struct.model_id, 'dietz2011')
    %     figure;
    %     plot(error_struct.ildlp);
    %     title("Model: " + error_struct.model_id + " - Data from " + listexp_id);
    %     grid on;
    %     text(20,-10,['R^2 = ' num2str(round(error_struct.ildlp.Rsquared.Adjusted,2))],'Color','red','FontSize',18)
    %     xlim([-40 100])
    %     ylim([-80 100])
    %     xlabel('Perceived angle (°)')
    %     ylabel('Estimated angle (°)')
    %     legend('Location','southeast')
    %     ax = gca;
    %     ax.FontSize = varfontsize;
    % end
    % 
    % 
    % if contains(error_struct.model_id, 'may2011')
    %     figure;
    %     plot(error_struct.loglik);
    %     title("Model: " + error_struct.model_id + "(from loglik) - Data from " + listexp_id);
    %     grid on;
    %     text(20,-10,['R^2 = ' num2str(round(error_struct.loglik.Rsquared.Adjusted,2))],'Color','red','FontSize',18)
    %     xlim([-40 100])
    %     ylim([-80 100])
    %     xlabel('Perceived angle (°)')
    %     ylabel('Estimated angle (°)')
    %     legend('Location','southeast')
    %     ax = gca;
    %     ax.FontSize = varfontsize;
    % end
    % 
    % if contains(error_struct.model_id, 'may2011')
    %     figure;
    %     plot(error_struct.timefreq);
    %     title("Model: " + error_struct.model_id + "(from timefreq) - Data from " + listexp_id);
    %     grid on;
    %     text(20,-10,['R^2 = ' num2str(round(error_struct.timefreq.Rsquared.Adjusted,2))],'Color','red','FontSize',18)
    %     xlim([-40 100])
    %     ylim([-80 100])
    %     xlabel('Perceived angle (°)')
    %     ylabel('Estimated angle (°)')
    %     legend('Location','southeast')
    %     ax = gca;
    %     ax.FontSize = varfontsize;
    % end
    % 
    % if contains(error_struct.model_id, 'desena2020PE')
    %     figure;
    %     plot(error_struct.localisation);
    %     title("Model: " + error_struct.model_id + " - Data from " + listexp_id);
    %     grid on;
    %     text(20,-10,['R^2 = ' num2str(round(error_struct.localisation.Rsquared.Adjusted,2))],'Color','red','FontSize',18)
    %     xlim([-40 100])
    %     ylim([-80 100])
    %     xlabel('Perceived angle (°)')
    %     ylabel('Estimated angle (°)')
    %     legend('Location','southeast')
    %     ax = gca;
    %     ax.FontSize = varfontsize;
    % elseif contains(error_struct.model_id, 'desena2020lindemann')
    %     figure;
    %     plot(error_struct.localisation);
    %     title("Model: " + error_struct.model_id + " - Data from " + listexp_id);
    %     grid on;
    %     text(20,-10,['R^2 = ' num2str(round(error_struct.localisation.Rsquared.Adjusted,2))],'Color','red','FontSize',18)
    %     xlim([-40 100])
    %     ylim([-80 100])
    %     xlabel('Perceived angle (°)')
    %     ylabel('Estimated angle (°)')
    %     legend('Location','southeast')
    %     ax = gca;
    %     ax.FontSize = varfontsize;
    % elseif contains(error_struct.model_id, 'desena2020breebaart')
    %     figure;
    %     plot(error_struct.localisation);
    %     title("Model: " + error_struct.model_id + " - Data from " + listexp_id);
    %     grid on;
    %     text(20,-10,['R^2 = ' num2str(round(error_struct.localisation.Rsquared.Adjusted,2))],'Color','red','FontSize',18)
    %     xlim([-40 100])
    %     ylim([-80 100])
    %     xlabel('Perceived angle (°)')
    %     ylabel('Estimated angle (°)')
    %     legend('Location','southeast')
    %     ax = gca;
    %     ax.FontSize = varfontsize;
    % elseif contains(error_struct.model_id, 'llado2025')
    %     figure;
    %     plot(error_struct.localisation);
    %     title("Model: " + error_struct.model_id + " - Data from " + listexp_id);
    %     grid on;
    %     text(20,-10,['R^2 = ' num2str(round(error_struct.localisation.Rsquared.Adjusted,2))],'Color','red','FontSize',18)
    %     xlim([-40 100])
    %     ylim([-80 100])
    %     xlabel('Perceived angle (°)')
    %     ylabel('Estimated angle (°)')
    %     legend('Location','southeast')
    %     ax = gca;
    %     ax.FontSize = varfontsize;
    % end
end

function h_err = draw_est_yerr(ax, x, y, est_yerr)
valid = isfinite(x) & isfinite(y) & isfinite(est_yerr) & est_yerr >= 0;
if ~any(valid)
    h_err = gobjects(0);
    return
end
h_err = errorbar(ax, x(valid), y(valid), est_yerr(valid), est_yerr(valid), 'vertical', ...
    'LineStyle', 'none', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.75, ...
    'CapSize', 3, 'HandleVisibility', 'off');
end

function h_err = draw_resp_xerr(ax, x, y, resp_xerr)
valid = isfinite(x) & isfinite(y) & isfinite(resp_xerr) & resp_xerr >= 0;
if ~any(valid)
    h_err = gobjects(0);
    return
end
% Horizontal errorbar expects (xneg, xpos); pass both for symmetric bars.
h_err = errorbar(ax, x(valid), y(valid), resp_xerr(valid), resp_xerr(valid), 'horizontal', ...
    'LineStyle', 'none', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.75, ...
    'CapSize', 3, 'HandleVisibility', 'off');
end

function [xlim_data, ylim_data] = compute_data_axis_limits(error_obj, padding_frac, resp_xerr, est_yerr)
% Return independent [lo hi] limits for x (predictor) and y (response)
% data of a LinearModel, with a small fractional padding so the extreme
% points do not sit exactly on the axis edge. Used so each axis fits its
% own data range; the grid wrapper later unifies across tiles.
if nargin < 2 || isempty(padding_frac)
    padding_frac = 0.08;
end
if nargin < 3
    resp_xerr = [];
end
if nargin < 4
    est_yerr = [];
end
x = error_obj.Variables.(error_obj.PredictorNames{1});
y = error_obj.Variables.(error_obj.ResponseName);
if ~isempty(resp_xerr) && numel(resp_xerr) == numel(x)
    x_for_limits = [x - resp_xerr(:); x + resp_xerr(:)];
else
    x_for_limits = x;
end
if ~isempty(est_yerr) && numel(est_yerr) == numel(y)
    y_for_limits = [y - est_yerr(:); y + est_yerr(:)];
else
    y_for_limits = y;
end
xlim_data = padded_range(x_for_limits, padding_frac);
ylim_data = padded_range(y_for_limits, padding_frac);
end

function lim = padded_range(v, padding_frac)
v = v(isfinite(v));
if isempty(v)
    lim = [-1, 1];
    return
end
lo = min(v);
hi = max(v);
rng_val = hi - lo;
if rng_val == 0
    rng_val = max(1, abs(hi));
end
pad = padding_frac * rng_val;
lim = [lo - pad, hi + pad];
end

function label = build_fit_annotation_label(error_struct, listexp_id)
%BUILD_FIT_ANNOTATION_LABEL Multiline R^2, beta1, and optional beta0 text.
r2_label = ['R^2 = ' num2str(round(error_struct.error.Rsquared.Ordinary, 2))];
if isfield(error_struct, 'r2_ci') && isstruct(error_struct.r2_ci) ...
        && isfield(error_struct.r2_ci, 'r2_ci') ...
        && numel(error_struct.r2_ci.r2_ci) == 2
    r2_label = [r2_label ' [' ...
        num2str(round(error_struct.r2_ci.r2_ci(1), 2)) ', ' ...
        num2str(round(error_struct.r2_ci.r2_ci(2), 2)) ']'];
end

lines = {r2_label, format_slope_annotation(error_struct)};
position_id = '';
if isfield(error_struct, 'position_id')
    position_id = error_struct.position_id;
end
if is_off_centre_listener_position(position_id, listexp_id)
    lines{end + 1} = format_intercept_annotation(error_struct); %#ok<AGROW>
end
label = strjoin(lines, newline);
end

function label = format_slope_annotation(error_struct)
%FORMAT_SLOPE_ANNOTATION Text for beta1 (slope of estimated ~ perceived).
    beta1 = NaN;
    if isfield(error_struct, 'error')
        try
            beta1 = error_struct.error.Coefficients.Estimate(2);
        catch
            beta1 = NaN;
        end
    end
    label = ['\beta_1 = ' num2str(round(beta1, 2))];
    if isfield(error_struct, 'slope_ci') && isstruct(error_struct.slope_ci) ...
            && isfield(error_struct.slope_ci, 'slope_ci') ...
            && numel(error_struct.slope_ci.slope_ci) == 2
        label = [label ' [' ...
            num2str(round(error_struct.slope_ci.slope_ci(1), 2)) ', ' ...
            num2str(round(error_struct.slope_ci.slope_ci(2), 2)) ']'];
    end
end

function label = format_intercept_annotation(error_struct)
%FORMAT_INTERCEPT_ANNOTATION Text for beta0 (intercept of estimated ~ perceived).
    beta0 = NaN;
    if isfield(error_struct, 'error')
        try
            beta0 = error_struct.error.Coefficients.Estimate(1);
        catch
            beta0 = NaN;
        end
    end
    label = ['\beta_0 = ' num2str(round(beta0, 2))];
    if isfield(error_struct, 'intercept_ci') && isstruct(error_struct.intercept_ci) ...
            && isfield(error_struct.intercept_ci, 'intercept_ci') ...
            && numel(error_struct.intercept_ci.intercept_ci) == 2
        label = [label ' [' ...
            num2str(round(error_struct.intercept_ci.intercept_ci(1), 2)) ', ' ...
            num2str(round(error_struct.intercept_ci.intercept_ci(2), 2)) ']'];
    end
end