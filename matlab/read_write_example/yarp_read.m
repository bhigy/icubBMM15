
% Copyright: (C) 2010 RobotCub Consortium
% Authors: Lorenzo Natale
% CopyPolicy: Released under the terms of the LGPLv2.1 or later, see LGPL.TXT

% show how to call YARP from Matlab.
% Write a bottle (quivalent to yarp write)
% -nat

%LoadYarp;
import yarp.Port;
import yarp.Bottle;
import yarp.Network;

done=0;

net = Network();
net.init();

port=Port();
%first close the port just in case
port.close();

disp('Going to open port /matlab/read');
port.open('/matlab/read');

disp('Please connect to a bottle sink (e.g. yarp write)');
disp('The program closes when ''quit'' is received');

b=Bottle();
while(~done)
  port.read(b);
  disp(b.toString);
  
  if (strcmp(b.toString, 'quit'))
	done=1;
  end
end

port.close();
  
  
  
