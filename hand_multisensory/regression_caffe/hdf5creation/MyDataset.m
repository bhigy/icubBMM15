classdef MyDataset < handle %matlab.mixin.Copyable %hgsetget 
    
    properties
       
        Tree
        Registry
        
        RootPath
        
        ExampleCount
        
        ImSize
     
        DsetMeanImg
        
        Oversample
        
    end
    
    methods
        
        function obj = MyDataset(mean_img_path, oversample)
            
            obj.DsetMeanImg = load(mean_img_path);
            
            obj.Oversample = oversample;
            
        end
        
        function assign_registry_and_tree_from_folder(object, in_rootpath, objlist, out_registry_path)
            
            % Init members
            object.Registry = [];
            object.Tree = struct('name', {}, 'subfolder', {});
            object.ExampleCount = 0;
            
            % explore folders creating .Tree .Registry .ExampleCount
            
            check_input_dir(in_rootpath);
            object.RootPath = in_rootpath;
            
            object.Tree = explore_next_level_folder(object, '', object.Tree, objlist);
            
            if ~isempty(out_registry_path)
                
                [reg_dir, ~, ~] = fileparts(out_registry_path);
                check_output_dir(reg_dir);
                
                fid = fopen(out_registry_path,'w');
                if (fid==-1)
                    fprintf(2, 'Cannot open file: %s', out_registry_path);
                end
         
                for line_idx=1:object.ExampleCount
                    fprintf(fid, '%s\n', object.Registry{line_idx});
                end
                fclose(fid);
            end
            
        end
        
        function current_level = explore_next_level_folder(obj, current_path, current_level, objects_list)
            
            % get the listing of files at the current level
            files = dir(fullfile(obj.RootPath, current_path));
 
            flag = 0;
            
            for idx_file = 1:size(files)
                
                % for each folder, create its duplicate in the hierarchy
                % then get inside it and repeat recursively
                if (files(idx_file).name(1)~='.')
                    
                    if (files(idx_file).isdir)
                        
                        tmp_path = current_path;
                        current_path = fullfile(current_path, files(idx_file).name);
                        
                        current_level(length(current_level)+1).name = files(idx_file).name;
                        current_level(length(current_level)).subfolder = struct('name', {}, 'subfolder', {});
                        current_level(length(current_level)).subfolder = explore_next_level_folder(obj, current_path, current_level(length(current_level)).subfolder, objects_list);
                        
                        % fall back to the previous level
                        current_path = tmp_path;
                        
                    else
                        
                        if flag==0
                            
                            flag = 1;
                            
                            if isempty(objects_list)
                                tobeadded = 1;
                            else
                                file_src = fullfile(current_path, files(idx_file).name);
                                [file_dir, ~, ~] = fileparts(file_src);
                                
                                file_dir_splitted = strsplit(file_dir, ['\' filesep]);
                                
                                tobeadded = 0;
                                for s=1:length(objects_list)
                                    contains_path = 1;
                                    for ss=1:length(objects_list(s,:))
                                        contains_path = contains_path & sum(strcmp(file_dir_splitted,objects_list{s,ss}));
                                    end
                                    tobeadded = tobeadded + contains_path;
                                end
                            end
                            
                        end
                        
                        if tobeadded
                            
                           file_src = fullfile(current_path, files(idx_file).name);
                           [file_dir, file_name, ~] = fileparts(file_src);
                           obj.ExampleCount = obj.ExampleCount + 1;
                           obj.Registry{obj.ExampleCount,1} = fullfile(file_dir, file_name);
                           
                        end

                    end
                end
            end
        end
                
        function reproduce_tree(obj, out_rootpath)
            
            check_output_dir(out_rootpath);
            reproduce_level(obj, out_rootpath, obj.Tree);
        end
        
        function reproduce_level(obj, current_path, current_level)
            
            for idx=1:length(current_level)
                
                tmp_path = current_path;
                current_path = fullfile(current_path, current_level(idx).name);
                if ~isdir(current_path)
                    mkdir(current_path);
                end
                reproduce_level(obj, current_path, current_level(idx).subfolder);
                % fall back to the previous level
                current_path= tmp_path;
            end
        end
        
        function assign_registry_and_tree_from_file(object, in_registry_path, objlist, out_registry_path)

            [reg_dir, ~, ~] = fileparts(in_registry_path);
            check_input_dir(reg_dir);
            
            try
            input_registry = textread(in_registry_path, '%s', 'delimiter', '\n'); 
            catch err
                fprintf(2, 'Cannot open file: %s', in_registry_path);
            end
            
            % select only specified folders
            [object.Registry, object.Tree] = select_registry_paths(input_registry, objlist);
            object.ExampleCount = size(object.Registry,1);

            if ~isempty(out_registry_path)
             
                [reg_dir, ~, ~] = fileparts(out_registry_path);
                check_output_dir(reg_dir);
                
                fid = fopen(out_registry_path,'w');
                if fid==-1
                    fprintf(2, 'Cannot open file: %s',out_registry_path);
                end
                for line_idx=1:object.ExampleCount
                    fprintf(fid, '%s\n', object.Registry{line_idx});
                end  
                fclose(fid);
 
            end

        end

        function images = prepare_image(obj, im)
            
            % convert to single
            im = single(im);
            
            % compute the dims
            im_DIM = size(im);
            im_mean_DIM = size(obj.DsetMeanImg.mean_data);
            
            % set crop dim
            CROP_SIZE = 227;
            
            if min(im_mean_DIM(1:2))<CROP_SIZE
                error('Mean image must be not smaller than input crop.');
            end
            
            if ~isequal(im_DIM(1:2),im_mean_DIM(1:2))
                % resize to the mean image dim
                im = imresize(im, im_mean_DIM(1:2), 'bilinear');
            end
            
            % permute from RGB to BGR (IMAGE_MEAN is already BGR)
            im = im(:,:,[3 2 1]) - obj.DsetMeanImg.mean_data;
            
            if obj.Oversample==1 && sum(im_mean_DIM(1:2)==CROP_SIZE)
                
                disp('Mean image is equal to input crop: cannot oversample.');
                obj.Oversample=0;
                
            end
            
            if obj.Oversample==1
                
                % 4 corners and their x-axis flips
                images = zeros(CROP_SIZE, CROP_SIZE, NUM_CHANNELS, 10, 'single');
                h_off = im_mean_DIM(1)-CROP_SIZE + 1;
                w_off = im_mean_DIM(2)-CROP_SIZE + 1;
                curr = 1;
                for i = [0 h_off]
                    for j = [0 w_off]
                        images(:, :, :, curr) = permute(im(i:i+CROP_SIZE-1, j:j+CROP_SIZE-1, :), [2 1 3]);
                        images(:, :, :, curr+5) = images(end:-1:1, :, :, curr);
                        curr = curr + 1;
                    end
                end
                
                % central crop and x-axis flip
                h_off = ceil(( im_mean_DIM(1)-CROP_SIZE) / 2);
                w_off = ceil(( im_mean_DIM(2)-CROP_SIZE) / 2);
                images(:,:,:,5) = permute(im(h_off:h_off+CROP_SIZE-1,w_off:w_off+CROP_SIZE-1,:), [2 1 3]);
                images(:,:,:,10) = images(end:-1:1, :, :, curr);
                
            elseif obj.Oversample==0
                
                % pick only the central crop
                h_off = ceil(( im_mean_DIM(1)-CROP_SIZE) / 2);
                w_off = ceil(( im_mean_DIM(2)-CROP_SIZE) / 2);
                images = permute(im(h_off:h_off+CROP_SIZE-1,w_off:w_off+CROP_SIZE-1,:), [2 1 3]);
                
            end
            
            % normalize for HDF5 format
            %images = images/255.0;
            
            
        end
        
    end
end
