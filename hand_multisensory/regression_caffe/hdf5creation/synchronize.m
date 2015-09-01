%%

path_vector = '/Users/giulia/DATASETS/joints_leftArm/data.txt';

fid = fopen(path_vector,'r');
if (fid==-1)
    error('Error!');
end

if isunix
    [~,vector_count] = system(['wc -l < ' path_vector]);
    vector_count = str2num(vector_count);
elseif ispc
    [~,vector_count] = system(['find /v /c "&*fake&*" "' path_vector '"']);
    last_space = strfind(vector_count,' ');
    vector_count = str2num(vector_count((last_space(end)+1):(end-1)));
end

vector_cell = textscan(fid, '%d %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f', vector_count);
vector_cell(1) = [];
vector_cell(2) = [];

fclose(fid);

%%

path_image = '/Users/giulia/DATASETS/left_data/data.txt';

fid = fopen(path_image,'r');
if (fid==-1)
    error('Error!');
end

if isunix
    [~,img_count] = system(['wc -l < ' path_image]);
    img_count = str2num(img_count);
elseif ispc
    [~,img_count] = system(['find /v /c "&*fake&*" "' path_image '"']);
    last_space = strfind(img_count,' ');
    img_count = str2num(img_count((last_space(end)+1):(end-1)));
end

image_cell = textscan(fid, '%d %f %f %s', img_count);
image_cell(1) = [];
image_cell(2) = [];

fclose(fid);

Tstart = 1440966540.000000;

image_cell{1} = image_cell{1} - Tstart;
vector_cell{1} = vector_cell{1} - Tstart;

%%

time_window = 30;

path_association = '/Users/giulia/DATASETS/image_vector.txt';
path_vector = '/Users/giulia/DATASETS/vector.txt';
path_image = '/Users/giulia/DATASETS/image.txt';

fid = fopen(path_association,'w');
if (fid==-1)
    error('Error!');
end

fid_vector = fopen(path_vector,'w');
if (fid_vector==-1)
    error('Error!');
end

fid_image = fopen(path_image,'w');
if (fid_image==-1)
    error('Error!');
end

ass_cell = cell(1, 4);

for idx_img = 1:(img_count-10)
    
    t_image = image_cell{1}(idx_img);
    
    if idx_img==1
        t_diff = vector_cell{1} - t_image;
        [min_diff, start_idx_vector] = min(abs(t_diff));
    else
        end_idx_vector = min(start_idx_vector + (time_window-1), length(vector_cell{1}));
        t_diff = vector_cell{1}(start_idx_vector:end_idx_vector) - t_image;
        flag = 1;
        if t_diff(1)<0 && t_diff(end)>=0
            [min_diff, idx_vector] = min(abs(t_diff));
            start_idx_vector = (start_idx_vector-1) + idx_vector;
            flag = 0;
        end
        if t_diff(1)>=0
            flag = 0;
        end
        while (t_diff(end)<0 && end_idx_vector<length(vector_cell{1}))
            start_idx_vector = end_idx_vector;
            end_idx_vector = min(start_idx_vector + time_window, length(vector_cell{1}));
            t_diff = vector_cell{1}(start_idx_vector:end_idx_vector) - t_image;
            if t_diff(1)<0 && t_diff(end)>=0
                [min_diff, idx_vector] = min(abs(t_diff));
                start_idx_vector = start_idx_vector + idx_vector;
                flag = 0;
                break;
            end
            if t_diff(1)>=0
                flag = 0;
                break;
            end
        end
        if flag
            start_idx_vector = end_idx_vector;
        end
    end
    
    tmp_v = zeros(1,16);
    for ii=0:15  
        tmp_v(ii+1) = vector_cell{2+ii}(start_idx_vector);
    end
    
    fprintf(fid, '%.6f %s %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f\n', image_cell{1}(idx_img), image_cell{2}{idx_img}, vector_cell{1}(start_idx_vector), tmp_v);
    fprintf(fid_image, '%s\n', image_cell{2}{idx_img});
    fprintf(fid_vector, '%.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f\n', tmp_v);
    
end

fclose(fid);
fclose(fid_image);
fclose(fid_vector);
