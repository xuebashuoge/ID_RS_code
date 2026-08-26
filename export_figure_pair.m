function files = export_figure_pair(fig, output_stem)
%EXPORT_FIGURE_PAIR Export a figure as vector PDF and 300-dpi PNG.

    output_dir = fileparts(output_stem);
    if ~isempty(output_dir) && ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    files.pdf = [output_stem '.pdf'];
    files.png = [output_stem '.png'];
    exportgraphics(fig, files.pdf, 'ContentType', 'vector', ...
        'Resolution', 300);
    exportgraphics(fig, files.png, 'Resolution', 300);
    fprintf('Saved %s and %s\n', files.pdf, files.png);
end
