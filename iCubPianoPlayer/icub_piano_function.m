function icub_piano_function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% Start connection with icub:

%LoadYarp;
import yarp.Port;
import yarp.Bottle;
import yarp.Network;

net = Network();
net.init();

done=0;

portCMDiCub=Port();
%first close the port just in case
portCMDiCub.close();

disp('Going to open port /matlab/write');
portCMDiCub.open('/matlab/cmd:o');

system('/Users/diegomendoza/icubrep/yarp/build/install/bin/yarp connect /matlab/cmd:o /actionsRenderingEngine/cmd:io');


finishup = onCleanup(@() closePorts(portCMDiCub));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Run audio_analysis function to record the template melody:

[robot_arm robot_joint tone_onset_times tone_offset_times] = audio_analysis;

template_melody.robot_arm=robot_arm;
template_melody.robot_joint=robot_joint;
template_melody.tone_onset_times=tone_onset_times;
template_melody.tone_offset_times=tone_offset_times;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Create iCub command string:

space_str=' ';

total_tones=length(tone_onset_times);

for tone_number=1:total_tones
    
    robot_arm_string_temp=num2str(robot_arm(tone_number));
    robot_joint_string_temp=num2str(robot_joint(tone_number));
    tone_onset_times_string_temp=num2str(tone_onset_times(tone_number));
    tone_offset_times_string_temp=num2str(tone_offset_times(tone_number));
     icub_command_struct.tone_numbers(tone_number).command_string=['(',robot_arm_string_temp,space_str,robot_joint_string_temp,space_str,space_str,tone_onset_times_string_temp,space_str,tone_offset_times_string_temp,')'];
end

icub_piano_command_string = strcat('play',{' '});

for tone_number=1:total_tones-1

    icub_piano_command_string = strcat(icub_piano_command_string,{icub_command_struct.tone_numbers(tone_number).command_string},{' '});

end

icub_piano_command_string = strcat(icub_piano_command_string,{icub_command_struct.tone_numbers(total_tones).command_string});
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% Create and send icub command bottle:


disp('Please connect to a bottle sink (e.g. yarp read)');

b=Bottle();
b.fromString(icub_piano_command_string{1});
portCMDiCub.write(b);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Run audio_analysis function to record what the icub plays:

[robot_arm robot_joint tone_onset_times tone_offset_times] = audio_analysis;

produced_melody.repetition(1).robot_arm=robot_arm;
produced_melody.repetition(1).robot_joint=robot_joint;
produced_melody.repetition(1).tone_onset_times=tone_onset_times;
produced_melody.repetition(1).tone_offset_times=tone_offset_times;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
end 


function closePorts(portCMDiCub)
    portCMDiCub.close;
end



  
