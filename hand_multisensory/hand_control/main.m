%LoadYarp;
       
global PRINT_STATUS_PER; % [s]
global MAX_TORSO_PITCH;  % [deg]

PRINT_STATUS_PER = double(1.0); % [s]
MAX_TORSO_PITCH = double(30.0);  % [deg]

mod = handController('right_arm');

mod.init();
mod.run();
