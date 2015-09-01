function check_input_dir(dir_path)

if ~exist(dir_path,'dir')
    error('%s: not found.\n',dir_path);
end