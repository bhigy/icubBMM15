
% Copyright: (C) 2010 RobotCub Consortium
% Authors: Lorenzo Natale
% CopyPolicy: Released under the terms of the LGPLv2.1 or later, see LGPL.TXT

% show how to call YARP from Matlab.
% Write a bottle (quivalent to yarp write)
% -nat

function yarp_rpc()

%LoadYarp;
import yarp.RpcClient;
import yarp.Bottle;
import yarp.Network;
import yarp.Stamp;

net = Network();
net.init();

done = 0;

port = RpcClient();

%first close the port just in case
port.close();

finishup = onCleanup(@() port.close() );

disp('Going to open port /matlab/rpc_client');
port.open('/matlab/rpc_client');

disp('Please connect to a server RPC port (e.g. /icubSim/right_arm/rpc:i)');

cmd = Bottle();
reply = Bottle();

while(~done)
    
  cmd_string = input('Write a string e.g. ''set pos 4 -90'' (''quit'' to quit):', 's');

  cmd.fromString(cmd_string);
  
  port.write(cmd, reply);
  
  if ~strcmp(reply.toString(), '[ok]') && ~strcmp(reply.toString(), '[ack]')
      done = 1;
  end
  
end

port.close();
  
end
  
