data_dir = 'D:\FUS_cases\4049-2022-09-12-09-19-35\Sonication8'; % directory of sonication imaging
results_dir = 'D:\FUS_results\figures'; % directory for saving figures, change this to your own directory
if ~exist("results_dir",'dir'); mkdir(results_dir); end
iSub = regexp(data_dir,filesep);
title_text = data_dir(iSub(end)+1:end); % sonication subdirectory, also the title of the figure
sonication_id = str2double(regexp(title_text,'\d*','match'));

img_dim = [256 256]; % pixel dimension of the images
bit_depth = 32; bits_per_byte = 8; 
file_bytes = bit_depth*prod(img_dim,'all')/bits_per_byte;
file_ext = 'raw';
file_list = dir(fullfile(data_dir,['*.' file_ext]));
file_list = file_list([file_list.bytes] == file_bytes); % specifies file size
therm_prefix = ['5-' num2str(sonication_id) '-3-']; % prefix of the thermometry image series
file_list = file_list(contains({file_list.name},therm_prefix));
%% Import idividual binary image files into a single stack (img_stack)
seq_id = zeros(length(file_list),1);
temp = cellfun(@(x) extractBetween(x,therm_prefix,['.' file_ext]),{file_list.name},'UniformOutput',true);
seq_id = cellfun(@str2num,temp); clear temp
[~,iSort] = sort(seq_id);
img_stack = single(zeros(img_dim(1),img_dim(2),length(iSort))); % intialize the image stack for import

% for i = 1:length(file_list) % extract the frame ID from file name
% temp(i) = extractBetween(file_list(i).name,therm_prefix,['.' file_ext]);
% seq_id(i) = str2num(temp{i});
% end
% clear temp

for i = 1:length(iSort) % import individual images into a single stack
    %% i = 11
    frame_id = num2str(seq_id(iSort(i)));
    file_path = fullfile(data_dir,[therm_prefix frame_id '.' file_ext]);
    F = fopen(file_path,'r');
    temp = fread(F,img_dim,"single",0);
    img_stack(:,:,i) = temp'; clear temp
    fclose(F);
end
%% Display thermometry MR frames and histogram of pixel values
idxReal = logical(squeeze(std(img_stack,[],[1 2]))); % only use frames with standard deviation > 0
img_2_disp = mean(img_stack(:,:,idxReal),3);
hFig = figure(1); set(hFig,'Position',[500 500 1400 500]);
subplot(1,2,1);
axIm = imagesc(img_2_disp); colormap("gray");
subplot(1,2,2); axHist = histogram(img_2_disp);

%% Select ROIs and define masks
close all; clear mask
num_of_roi = 2;

for i = 1:num_of_roi
    clear arImg arMask arRoi
axIm = imagesc(img_2_disp); colormap("gray");
hDraw(i) = drawfreehand;
mask{i} = createMask(hDraw(i));
arImg = reshape(img_stack,size(img_stack,1)*size(img_stack,2),size(img_stack,3));
arMask = reshape(mask{i},size(mask{i},1)*size(mask{i},2),1);
arRoi = arImg.*arMask;
roi_mean(i,:) = mean(arRoi,1);
roi_stack{i} = reshape(arRoi,size(img_stack,1),size(img_stack,2),size(img_stack,3));
end
%%
clear bnd
mask_bnd = zeros(size(img_stack,1),size(img_stack,2),length(mask));
for i = 1:length(mask)
    bnd(i) = bwboundaries(mask{i});
    for j = 1:length(bnd{i})
        mask_bnd(bnd{i}(j,1),bnd{i}(j,2),i) = 1;
    end
end

%%
hFig = figure(1);
set(hFig,'Position',[500 500 750 300]);
hTile = tiledlayout(1,2);
nexttile;
img_disp = mean(img_stack(:,:,2:end),3);
img_and_mask = img_disp+sum(mask_bnd,3)*max(img_disp(:));
hIm = imagesc(img_and_mask); colormap('gray'); clim([0 150]);
for i = 1:length(mask)
    txt = num2str(i);
    hText(i) = text(max(bnd{i}(:,2)),max(bnd{i}(:,1)),txt,...
        'HorizontalAlignment','center',...
        'VerticalAlignment','top',...
        'FontSize',14,...
        'Color',[1 1 1]);
end
set(gca,'XTickLabel',[],...
    'YTicklabel',[])
title([title_text ' ROIs'])

nexttile;
legend_text = string(1:length(mask));
hPlot = plot(roi_mean','LineWidth',3);
fig_configAxis(gca);
offsetAxes
hLeg = legend(legend_text); set(hLeg,'Box','off');
xlabel('Thermometry frame #'); ylabel('a.u.');
title('Mean ROI intensity');
for i = 1:length(hText)
    hText(i).Color = hPlot(i).Color;
end

save_path_pdf = fullfile(results_dir,[title_text '.pdf']);
save_path_png = fullfile(results_dir,[title_text '.png']);
save_path_eps = fullfile(results_dir,[title_text '.epsc']);
saveas(hFig,save_path_pdf); saveas(hFig,save_path_png); saveas(hFig,save_path_eps);

