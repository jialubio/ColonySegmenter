% For cluster
taskID = getenv('SLURM_ARRAY_TASK_ID'); %%% THIS IS A STRING
taskID = str2num(taskID);
%taskID = 12;
load('Image_Names_char.mat') % This .mat records the name of all images to read in

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This code segments a single microscope image of agar plate,
% saves the segmented images in a new folder named the same as the
% original image.
% The individual colony images are named as '(Originalimagename)_n.tif'
% n is the index of the image.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% this algorithm uses edge detection
% ref: https://www.mathworks.com/help/images/detecting-a-cell-using-image-segmentation.html
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Step 1: Read Image
I = imread(FileNames{taskID});
name = regexp(FileNames{taskID},'.tif','split');
Original_Img_Name = name{1,1};

% Step 2: Detect Cells
[~,threshold] = edge(I,'sobel');
fudgeFactor = 1.3;
BWs = edge(I,'sobel',threshold * fudgeFactor);

% Step 3: Dilate the image
se90 = strel('line',3,90);
se0 = strel('line', 3,0);
BWsdil = imdilate(BWs,[se90 se0]);

% Step 4: Fill interior gaps
BWdfill = imfill(BWsdil,'holes');

% Step 5: Remove connected objects on borders
BWnobord = imclearborder(BWdfill,4);

% Step 6: Smooth the object
seD = strel('diamond',20);
BWfinal = imerode(BWnobord,seD);
BWfinal = imerode(BWfinal,seD);

% Step 7: Locate cells, draw bounding box and remove noise
BW = imclearborder(BWfinal);
stats = struct2table(regionprops(BW,{'Area','Solidity','PixelIdxList', 'Centroid', 'BoundingBox'}));
% Remove detection on noise
idx = stats.Area < 100000;
for kk = find(idx)',
    BW(stats.PixelIdxList{kk}) = false;
end

% Step 8: Crop image and save
idx_cell = stats.Area > 100000;
index = 1;

if length(find(idx_cell)) ~= 0,
    BoundingBox = stats.BoundingBox(find(idx_cell)',:);
    BoundingBox_large = zeros(length(find(idx_cell)),4);
    
    % bring the upper left cornor higher and more to the left
    % but still within the boundary
    [row1,col1] = find(BoundingBox(:,1:2)<100);
    BoundingBox_large(:,1:2) = BoundingBox(:,1:2)-100;
    BoundingBox_large(row1,1:2) = BoundingBox(row1,1:2);
    
    % enlarge the box, and keep it in boundary
    BoundingBox_large(:,3:4) = BoundingBox(:,3:4)*1.5;
    % lower right
    x_bottomright = BoundingBox_large(:,2) + BoundingBox_large(:,4);
    y_bottomright = BoundingBox_large(:,1) + BoundingBox_large(:,3);
    [a, b] = size(I);
    [row2,col2] = find(x_bottomright > a | y_bottomright > b);
    vec = ones(size(BoundingBox_large,1),2);
    vec(row1,:) = 0;
    BoundingBox_large(row2,3:4) = BoundingBox(row2,3:4)+ 100*vec(row2,:);
    
    % Crop image and save
    for ii = 1: size(BoundingBox_large,1),    
        I_cell = imcrop(I,BoundingBox_large(ii,:));
        File_Name = strcat('Segmented/',Original_Img_Name,'_', num2str(index),'.tif');

        imwrite(I_cell, File_Name);
        index = index + 1;
    end
  
    
    % Draw bounding box 
    % a bit slow
    Line_Width = 10;
    for ii = 1: size(BoundingBox_large,1),
        x1 = round(BoundingBox_large(ii,1));
        x2 = round(BoundingBox_large(ii,2));
        x3 = round(BoundingBox_large(ii,3));
        x4 = round(BoundingBox_large(ii,4));
        
        I(x2-Line_Width:x2+Line_Width, x1-Line_Width:x1+x3+Line_Width) = 1;
        I(x2+x4-Line_Width:x2+x4+Line_Width, x1-Line_Width:x1+x3+Line_Width) = 1;      
        I(x2:x2+x4, x1-Line_Width:x1+Line_Width) = 1;
        I(x2:x2+x4, x1+x3-Line_Width:x1+x3+Line_Width) = 1; 
    end 
    Detected_Img_Name = strcat('Detected/','Detected_', Original_Img_Name, '.tif');
    imwrite(I,Detected_Img_Name);
    % Visualize segmentation, save it as 'Detected_(Originalimagename).tif   
end



% imshow(I);
%     for ii = 1: size(BoundingBox,1),
%         h = rectangle('Position',BoundingBox_large(ii,:), 'EdgeColor','b');
%     end
