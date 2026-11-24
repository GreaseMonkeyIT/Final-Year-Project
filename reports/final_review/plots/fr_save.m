function fr_save(fig, outDir, name)
%FR_SAVE Save a figure as PNG (200 dpi) into outDir/<name>.png.
if isempty(outDir), return, end
if ~isfolder(outDir), mkdir(outDir); end
% The figure theme of R2025a and later follows the theme of the operating
% system. A dark theme gives black axes. The light theme keeps the colours
% of fr_style.m readable. R2024b has no themes.
if ~isMATLABReleaseOlderThan("R2025a"), theme(fig, "light"); end
exportgraphics(fig, fullfile(outDir, [name '.png']), 'Resolution', 200, 'BackgroundColor', 'white');
end
