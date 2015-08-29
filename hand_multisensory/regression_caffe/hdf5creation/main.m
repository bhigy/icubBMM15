%% WRITING TO HDF5

dirpath = '/Users/giulia/DATASETS/icubworld28/train/day1/cub/cup1';

imagenet_meanimg_path = '/Users/giulia/LIBRARIES/caffe/matlab/+caffe/imagenet/ilsvrc_2012_mean.mat';

filename = 'icubdata.h5';

imW = 256;
imH = 256;
imC = 3;
imL = 15;

oversample = 0;
dset = GenericFeature(imagenet_meanimg_path, oversample);
dset.assign_registry_and_tree_from_folder(dirpath, [], []);

num_total_samples = length(dset.Registry);

% *data* is W*H*C*N matrix of images should be normalized (e.g. to lie between 0 and 1) beforehand
% *label* is D*N matrix of labels (D labels per sample) 
% *create* [0/1] specifies whether to create file newly or to append to previously created file, useful to store information in batches when a dataset is too big to be held in memory  (default: 1)
% *startloc* (point at which to start writing data). By default, 
% if create=1 (create mode), startloc.data=[1 1 1 1], and startloc.lab=[1 1]; 
% if create=0 (append mode), startloc.data=[1 1 1 K+1], and startloc.lab = [1 K+1]; where K is the current number of samples stored in the HDF
% chunksz (used only in create mode), specifies number of samples to be stored per chunk (see HDF5 documentation on chunking) for creating HDF5 files with unbounded maximum size - TLDR; higher chunk sizes allow faster read-write operations 

chunksz = 64;

created_flag = false;

totalct = 0;

for batchno = 1:num_total_samples/chunksz
  
    fprintf('batch no. %d\n', batchno);
    
    last_read = (batchno-1)*chunksz;

    batchdata = zeros(imW, imH, imC, chuncksz);
    batchlabs = rand(imL, chuncksz);
    
    for imidx = 1:chuncksz
        
        im = imread(filepath(dirpath, dset.Registry{last_read+1+imidx}));
       
        im = dset.prepare_im(im);
        
        batchdata(:, :, :, imidx) = im;
        
    end

    % store to hdf5
    startloc = struct('dat',[1,1,1,totalct+1], 'lab', [1,totalct+1]);
    
    curr_dat_sz = store2hdf5(filename, batchdata, batchlabs, ~created_flag, startloc, chunksz); 
    
    created_flag = true; % flag set so that file is created only once
    
    totalct = curr_dat_sz(end); % updated dataset size (#samples)
end

% display structure of the stored HDF5 file
h5disp(filename);

%% READING FROM HDF5

% read data and labels for samples #1000 to 1999

data_rd = h5read(filename, '/data', [1 1 1 1000], [5, 5, 1, 1000]);
label_rd = h5read(filename, '/label', [1 1000], [10, 1000]);

fprintf('Testing ...\n');

try 
    
  assert(isequal(data_rd, single(data_disk(:,:,:,1000:1999))), 'Data do not match');
  assert(isequal(label_rd, single(label_disk(:,1000:1999))), 'Labels do not match');

  fprintf('Success!\n');
  
catch err
    
  fprintf('Test failed ...\n');
  getReport(err)
  
end

% CREATE list.txt containing filename, to be used as source for HDF5_DATA_LAYER

FILE = fopen('train.txt', 'w');
fprintf(FILE, '%s', filename);
fclose(FILE);

fprintf('HDF5 filename listed in %s \n', 'train.txt');

% NOTE: In net definition prototxt, use list.txt as input to HDF5_DATA as: 
% layer {
%   name: "data"
%   type: "HDF5Data"
%   top: "data"
%   top: "labelvec"
%   hdf5_data_param {
%     source: "train/test.txt"
%     batch_size: 64
%   }
% }
