%LoadYarp;
       
global CTRL_THREAD_PER; % [s]
global PRINT_STATUS_PER; % [s]
global MAX_TORSO_PITCH;  % [deg]

CTRL_THREAD_PER = double(0.02); % [s]
PRINT_STATUS_PER = double(1.0); % [s]
MAX_TORSO_PITCH = double(30.0);  % [deg]

mod = handController(1.0);

mod.init();
mod.run();
mod.release();
