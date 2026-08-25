function save_figure_300dpi(fig, base_path)
%SAVE_FIGURE_300DPI Export both PDF and PNG at publication resolution.

    output_dir = fileparts(base_path);
    if ~isempty(output_dir) && ~isfolder(output_dir)
        mkdir(output_dir);
    end
    pdf_path = [base_path, '.pdf'];
    png_path = [base_path, '.png'];

    try
        exportgraphics(fig, pdf_path, 'ContentType', 'vector', ...
            'Resolution', 300, 'BackgroundColor', 'white');
    catch export_error
        warning('conference:PdfExportFallback', ...
            'Vector PDF export failed (%s); using a 300-dpi vector PDF.', ...
            export_error.message);
        print(fig, pdf_path, '-dpdf', '-vector', '-r300');
    end
    exportgraphics(fig, png_path, 'Resolution', 300, ...
        'BackgroundColor', 'white');
end
