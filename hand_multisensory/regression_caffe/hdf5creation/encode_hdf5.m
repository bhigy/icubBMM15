%% WRITING TO HDF5

dirpath = '/Users/giulia/DATASETS/left';

labelspath = '/Users/giulia/DATASETS/vector.txt';

fid = fopen(labelspath,'r');
if (fid==-1)
    error('Error!');
end

if isunix
    [~,vector_count] = system(['wc -l < ' labelspath]);
    vector_count = str2num(vector_count);
elseif ispc
    [~,vector_count] = system(['find /v /c "&*fake&*" "' labelspath '"']);
    last_space = strfind(vector_count,' ');
    vector_count = str2num(vector_count((last_space(end)+1):(end-1)));
end

labels_cell = textscan(fid, '%.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f', 98120);

fclose(fid);

labels_cell = cell2mat(labels_cell(8:15)); 

% convert and normalize
labels_cell = labels_cell * pi/180.0;
labels_cell = ( labels_cell - pi ) / pi;

imagenet_meanimg_path = '/Users/giulia/LIBRARIES/caffe/matlab/+caffe/imagenet/ilsvrc_2012_mean.mat';

filename_prefix = 'icubdata_train_';

imW = 320;
imH = 240;
cropSize = 227;

imC = 3;
imL = 8;
oversample = 0;
dset = MyDataset(imagenet_meanimg_path, oversample);
dset.assign_registry_and_tree_from_folder(dirpath, [], []);

num_total_samples = length(dset.Registry)-3570;

chunksz = 40;

% *data* is W*H*C*N matrix of images should be normalized (e.g. to lie between 0 and 1) beforehand
% *label* is D*N matrix of labels (D labels per sample) 
% *create* [0/1] specifies whether to create file newly or to append to previously created file, useful to store information in batches when a dataset is too big to be held in memory  (default: 1)
% *startloc* (point at which to start writing data). By default, 
% if create=1 (create mode), startloc.data=[1 1 1 1], and startloc.lab=[1 1]; 
% if create=0 (append mode), startloc.data=[1 1 1 K+1], and startloc.lab = [1 K+1]; where K is the current number of samples stored in the HDF
% chunksz (used only in create mode), specifies number of samples to be stored per chunk (see HDF5 documentation on chunking) for creating HDF5 files with unbounded maximum size - TLDR; higher chunk sizes allow faster read-write operations 

for fileno = 1:10
    
    created_flag = false;

    totalct = 0;

    fprintf('TRAIN: file no. %d\n', fileno);
    
    for batchno = 1:171
        % for batchno = 1:1710
        % for batchno = 1:1713
        
        fprintf('TRAIN: batch no. %d\n', batchno);
        
        last_read = (fileno-1)*chunksz*171 + (batchno-1)*chunksz;
        
        batchdata = zeros(cropSize, cropSize, imC, chunksz);
        batchlabs = zeros(imL, chunksz);
        
        for imidx = 1:chunksz
            
            im = imread(fullfile(dirpath, [dset.Registry{last_read+imidx} '.ppm']));
            
            im = dset.prepare_image(im);
            
            batchdata(:, :, :, imidx) = im;
            batchlabs(:, imidx) = labels_cell(last_read+imidx, :);
            
        end
    
        % store to hdf5
        startloc = struct('dat',[1,1,1,totalct+1], 'lab', [1,totalct+1]);
    
        curr_dat_sz = store2hdf5([filename_prefix num2str(fileno) '.h5'], batchdata, batchlabs, ~created_flag, startloc, chunksz);
    
        created_flag = true; % flag set so that file is created only once
    
        totalct = curr_dat_sz(end); % updated dataset size (#samples)
    end
    
    % display structure of the stored HDF5 file
    h5disp([filename_prefix num2str(fileno) '.h5']);
    
end

% CREATE list.txt containing filename, to be used as source for HDF5_DATA_LAYER

FILE = fopen('train.txt', 'a');
for fileno=1:10
    fprintf(FILE, '%s', [filename_prefix num2str(fileno) '.h5']);
end
fclose(FILE);

fprintf('HDF5 filename listed in %s \n', 'train.txt');

%% READING FROM HDF5

data_rd = h5read([filename_prefix num2str(10) '.h5'], '/data', [1 1 1 1], [227, 227, 3, 1]);
label_rd = h5read([filename_prefix num2str(10) '.h5'], '/label', [1 1], [8, 1]);

fprintf('Testing ...\n');

try 
  
  im = imread(fullfile(dirpath, [dset.Registry{chunksz*9*171+1} '.ppm']));
  im = dset.prepare_image(im);
  
  assert(isequal(data_rd, single(im)), 'Data do not match');
  assert(isequal(label_rd, single(labels_cell(chunksz*9*171+1,:)')), 'Labels do not match');

  fprintf('Success!\n');
  
catch err
    
  fprintf('Test failed ...\n');
  getReport(err)
  
end

clear all;

%% WRITING TO HDF5

dirpath = '/Users/giulia/DATASETS/left';

labelspath = '/Users/giulia/DATASETS/vector.txt';

fid = fopen(labelspath,'r');
if (fid==-1)
    error('Error!');
end

if isunix
    [~,vector_count] = system(['wc -l < ' labelspath]);
    vector_count = str2num(vector_count);
elseif ispc
    [~,vector_count] = system(['find /v /c "&*fake&*" "' labelspath '"']);
    last_space = strfind(vector_count,' ');
    vector_count = str2num(vector_count((last_space(end)+1):(end-1)));
end

labels_cell = textscan(fid, '%.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f', 98120);

fclose(fid);

labels_cell = cell2mat(labels_cell(8:15)); 

imagenet_meanimg_path = '/Users/giulia/LIBRARIES/caffe/matlab/+caffe/imagenet/ilsvrc_2012_mean.mat';

filename_prefix = 'icubdata_test_';

imW = 320;
imH = 240;
cropSize = 227;

imC = 3;
imL = 8;
oversample = 0;
dset = MyDataset(imagenet_meanimg_path, oversample);
dset.assign_registry_and_tree_from_folder(dirpath, [], []);

num_total_samples = length(dset.Registry)-3570;

% *data* is W*H*C*N matrix of images should be normalized (e.g. to lie between 0 and 1) beforehand
% *label* is D*N matrix of labels (D labels per sample) 
% *create* [0/1] specifies whether to create file newly or to append to previously created file, useful to store information in batches when a dataset is too big to be held in memory  (default: 1)
% *startloc* (point at which to start writing data). By default, 
% if create=1 (create mode), startloc.data=[1 1 1 1], and startloc.lab=[1 1]; 
% if create=0 (append mode), startloc.data=[1 1 1 K+1], and startloc.lab = [1 K+1]; where K is the current number of samples stored in the HDF
% chunksz (used only in create mode), specifies number of samples to be stored per chunk (see HDF5 documentation on chunking) for creating HDF5 files with unbounded maximum size - TLDR; higher chunk sizes allow faster read-write operations 

chunksz = 40;

start_im_idx = chunksz*171*10;

for fileno = 1:10
    
    created_flag = false;

    totalct = 0;

    fprintf('TEST: file no. %d\n', fileno);
    
for batchno = 1:74
%for batchno = 1714:2453
  
    fprintf('TEST: batch no. %d\n', batchno);
    
    last_read = start_im_idx + (fileno-1)*74*chunksz + (batchno-1)*chunksz;

    batchdata = zeros(cropSize, cropSize, imC, chunksz);
    batchlabs = zeros(imL, chunksz);
    
    for imidx = 1:chunksz
        
        im = imread(fullfile(dirpath, [dset.Registry{last_read+imidx} '.ppm']));
       
        im = dset.prepare_image(im);
        
        batchdata(:, :, :, imidx) = im;
        batchlabs(:, imidx) = labels_cell(last_read+imidx, :);
        
    end

    % store to hdf5
    startloc = struct('dat',[1,1,1,totalct+1], 'lab', [1,totalct+1]);
    
    curr_dat_sz = store2hdf5([filename_prefix num2str(fileno) '.h5'] , batchdata, batchlabs, ~created_flag, startloc, chunksz); 
    
    created_flag = true; % flag set so that file is created only once
    
    totalct = curr_dat_sz(end); % updated dataset size (#samples)
end

% display structure of the stored HDF5 file
h5disp([filename_prefix num2str(fileno) '.h5']);

end

% CREATE list.txt containing filename, to be used as source for HDF5_DATA_LAYER

FILE = fopen('test.txt', 'a');
for fileno=1:10
    fprintf(FILE, '%s', [filename_prefix num2str(fileno) '.h5']);
end
fclose(FILE);

fprintf('HDF5 filename listed in %s \n', 'test.txt');

%% READING FROM HDF5

% read data and labels for samples #1000 to 1999

data_rd = h5read([filename_prefix num2str(5) '.h5'], '/data', [1 1 1 1], [227, 227, 3, 1]);
label_rd = h5read([filename_prefix num2str(5) '.h5'], '/label', [1 1], [8, 1]);

fprintf('Testing ...\n');

try 
  
  im = imread(fullfile(dirpath, [dset.Registry{start_im_idx+ chunksz*4*74+1} '.ppm']));
  im = dset.prepare_image(im);
  
  assert(isequal(data_rd, single(im)), 'Data do not match');
  assert(isequal(label_rd, single(labels_cell(start_im_idx+ chunksz*4*74+1,:)')), 'Labels do not match');

  fprintf('Success!\n');
  
catch err
    
  fprintf('Test failed ...\n');
  getReport(err)
  
end
