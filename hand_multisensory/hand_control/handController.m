% Copyright: (C) 2015 iCub Facility
% Authors: Giulia Pasquale, Tyler Bonnen
% CopyPolicy: Released under the terms of the LGPLv2.1 or later, see LGPL.TXT

classdef handController < handle
    properties
        
        arm
        
        client
        icart
        
        rpclient
        readpose
        
        igazeRpcPort
        igazeXdPort
        igazeLeftOutPort
        igazeRightOutPort
        
        xd
        od
        
        startup_context_id
        
        t0
        t1
        box_radius
        max_iter
        joint_tol
        
        pos_grid
        
        joint0
        
    end
    
    methods
        
        function obj = handController(arm)
            
            obj.arm = arm;
        end
        
        function success = init(obj)
            % open a client interface to connect to the cartesian server of the simulator
            % we suppose that:
            % 1 - the iCub simulator is running
            %     (launch iCub_SIM)
            % 2 - the cartesian server is running
            %     (launch simCartesianControl)
            % 3 - the cartesian solver for the desired arm is running too
            %     (launch iKinCartesianSolver --context simCartesianControl --part left_arm/righ_arm)
            
            import yarp.BufferedPortBottle
            import yarp.Port
            import yarp.RpcClient
            
            import yarp.Bottle
            import yarp.Vector
            
            import yarp.Time
            
            import yarp.RFModule
            import yarp.RateThread
            
            import yarp.Drivers
            import yarp.PolyDriver
            import yarp.IPositionControl
            import yarp.Property
            
            import yarp.Network
            
            net = Network();
            net.init();
            
            option = Property('(device cartesiancontrollerclient)');
            option.put('remote',['/icubSim/cartesianController/' obj.arm]);
            option.put('local',['/cartesian_client/' obj.arm]);
            
            obj.client = PolyDriver();
            if (~obj.client.open(option))
                success = 0;
            end
            
            % open the view
            obj.icart = obj.client.viewICartesianControl();
            
            % latch the controller context in order to preserve it after closing the module
            % the context contains the dofs status, the tracking mode,
            % the resting positions, the limits and so on ...
            
            obj.startup_context_id = obj.icart.storeContext();
            
%             % set trajectory time
%             obj.icart.setTrajTime(1.0);
%             
%             % get the torso dofs
%             newDof = Vector();
%             curDof = Vector();
%             
%             obj.icart.getDOF(curDof);
%             newDof = curDof;
%             
%             % enable the torso yaw and pitch
%             % disable the torso roll
%             newDof.push_back(1);
%             newDof.push_back(0);
%             newDof.push_back(1);
%             
%             % impose some restriction on the torso pitch
%             %obj.limitTorsoPitch();
%             
%             % send the request for dofs reconfiguration
%             obj.icart.setDOF(newDof,curDof);
            
            % print out some info about the controller
            info = Bottle();
            obj.icart.getInfo(info);
            fprintf('info = %s\n',info.toString());
            
            obj.xd = Vector();
            obj.od = Vector();
            obj.xd.resize(3);
            obj.od.resize(4);
            
            obj.t0 = tic;
            obj.t1 = tic;
            
            tmpx = Vector();
            tmpo = Vector();
            tmpx.resize(3); % allocates the memory
            tmpo.resize(4); % allocates the memory
            obj.icart.getPose(tmpx, tmpo);
            
            point(1,1) = tmpx.get(0);
            point(1,2) = tmpx.get(1);
            point(1,3) = tmpx.get(2);
            
            obj.box_radius = 0.1;
            %obj.pos_grid = makeBox(point, obj.box_radius);

            obj.pos_grid = [point - obj.box_radius; point + obj.box_radius];
            
            obj.rpclient = RpcClient();
            obj.rpclient.close();
            disp('Going to open port /matlab/rpc_client');
            obj.rpclient.open('/matlab/rpc_client');
            system(['yarp connect /matlab/rpc_client /icubSim/' obj.arm '/rpc:i ']);
            
            obj.igazeRpcPort = RpcClient();
            obj.igazeRpcPort.close();
            disp('Going to open port /matlab/ikingazectrl/rpc');
            obj.igazeRpcPort.open('/matlab/ikingazectrl/rpc');
            system('yarp connect /matlab/ikingazectrl/rpc /iKinGazeCtrl/rpc');
            
            obj.igazeXdPort = Port();
            obj.igazeXdPort.close();
            disp('Going to open port /matlab/ikingazectrl/xd:o');
            obj.igazeXdPort.open('/matlab/ikingazectrl/xd:o');
            system('yarp connect /matlab/ikingazectrl/xd:o /iKinGazeCtrl/xd:i');
            
            obj.igazeLeftOutPort = Port();
            obj.igazeRightOutPort = Port();
            obj.igazeLeftOutPort.close();
            obj.igazeRightOutPort.close();
            disp('Going to open port /matlab/left/endeffector2D:o');
            obj.igazeLeftOutPort.open('/matlab/left/endeffector2D:o');
           
            disp('Going to open port /matlab/right/endeffector2D:o');
            obj.igazeRightOutPort.open('/matlab/right/endeffector2D:o');
            
        
            obj.readpose  = BufferedPortBottle();
            % first close the port just in case
            obj.readpose.close();
            
            disp(['Going to open port /matlab/' obj.arm ':i']);
            obj.readpose.open(['/matlab/' obj.arm ':i']);
            system(['yarp connect /icubSim/' obj.arm '/state:o /matlab/' obj.arm ':i']);
            
            obj.max_iter = 20;
            
            obj.joint_tol = 2.0;
            
            obj.joint0 = zeros(1,15);
            
            b = Bottle();
            b = obj.readpose.read();  
            for ii = 1:b.size()
                obj.joint0(ii) = b.get(ii-1).asDouble();
            end
            
        end
        
        function run(obj)
            
            import yarp.BufferedPortBottle
            import yarp.Port
            import yarp.RpcClient;
            import yarp.Bottle
            import yarp.Time
            import yarp.RFModule
            import yarp.RateThread
            import yarp.Vector
            
            import yarp.Drivers
            import yarp.PolyDriver
            import yarp.IPositionControl
            import yarp.Property
            
            % variables for hand movement
            wristJoints = [4 5 6];
            wristBoundaries = [-90 90; -90 0; -20 40];
            wristSegments = 1; % how many times to segment the range of motion
            fingers = 7:15;
            fingerBoundaries = [0 60; 10 90; 0 90; 0 180; 0 90; 0 180; 0 90; 0 180; 0 270];
            fingerSegments = 3;
            
            finishup = onCleanup(@() obj.release() );
            
            for ii = 1:size(obj.pos_grid,1)
                
                obj.xd.set(0, obj.pos_grid(ii,1));
                obj.xd.set(1, obj.pos_grid(ii,2));
                obj.xd.set(2, obj.pos_grid(ii,3));
                
                % go to the target
                obj.icart.goToPosition(obj.xd);
                mdone = 0;
                while(~mdone)
                    mdone = obj.icart.checkMotionDone();
                    pause(0.04);
                end
                
                x = Vector();
                o = Vector();
                % we get the current arm pose in the operational space
                obj.icart.getPose(x,o);
                
                obj.igazeXdPort.write(x);
                pause(0.5);
                
                cmd_string = ['get 2D (left ' num2str(x.get(0)) ' ' num2str(x.get(1)) ' ' num2str(x.get(2)) ')'];
                cmd = Bottle();
                reply = Bottle();
                cmd.fromString(cmd_string);
                obj.igazeRpcPort.write(cmd, reply);
                
                obj.igazeLeftOutPort.write(reply.get(1));
                
                cmd_string = ['get 2D (right ' num2str(x.get(0)) ' ' num2str(x.get(1)) ' ' num2str(x.get(2)) ')'];
                cmd = Bottle();
                reply = Bottle();
                cmd.fromString(cmd_string);
                obj.igazeRpcPort.write(cmd, reply);
                
                obj.igazeRightOutPort.write(reply.get(1));
                
                % some verbosity
                obj.printStatus();
                     
                % start iterating through postures
                
                interval1 =  (abs(wristBoundaries(1,1)) + abs(wristBoundaries(1,2)))/wristSegments;
                for wrist1Angle = wristBoundaries(1,1):interval1:wristBoundaries(1,2);
                    
                    cmd_string = ['set icmd cmod ' num2str(wristJoints(1)) ' pos'];
                    cmd = Bottle();
                    reply = Bottle();
                    cmd.fromString(cmd_string);
                    obj.rpclient.write(cmd, reply);
                    disp(reply.toString());
                    
                    
                    cmd_string = ['set pos ' num2str(wristJoints(1)) ' '  num2str(wrist1Angle)];
                    cmd = Bottle();
                    reply = Bottle();
                    cmd.fromString(cmd_string);
                    obj.rpclient.write(cmd, reply);
                    disp(reply.toString());
                    
                    b = Bottle();
                    b = obj.readpose.read();  
                    count = 0;
                    while abs(b.get(wristJoints(1)).asDouble() - wrist1Angle)>obj.joint_tol && count<obj.max_iter
                        pause(0.04);
                        b = Bottle();
                        b = obj.readpose.read();  
                        count = count + 1;
                    end
                    if count==obj.max_iter
                        disp(['cannot set ' num2str(wristJoints(1)) ' to '  num2str(wrist1Angle)]);
                        disp([num2str(wristJoints(1)) ' = '  num2str(b.get(wristJoints(1)).asDouble())]);
                    end
           
                    interval2 = (abs(wristBoundaries(2,1)) + abs(wristBoundaries(2,2)))/wristSegments;
                    
                    for wrist2Angle = wristBoundaries(2,1):interval2:wristBoundaries(2,2);
                        
                        cmd_string = ['set icmd cmod ' num2str(wristJoints(2)) ' pos'];
                        cmd = Bottle();
                        reply = Bottle();
                        cmd.fromString(cmd_string);
                        obj.rpclient.write(cmd, reply);
                        disp(reply.toString());
                        
                        cmd_string = ['set pos ' num2str(wristJoints(2)) ' '  num2str(wrist2Angle)];
                        cmd = Bottle();
                        reply = Bottle();
                        cmd.fromString(cmd_string);
                        obj.rpclient.write(cmd, reply);
                        disp(reply.toString());
                         
                        b = Bottle();
                        b = obj.readpose.read();
                        count = 0;
                        while abs(b.get(wristJoints(2)).asDouble() - wrist2Angle)>obj.joint_tol && count<obj.max_iter
                            pause(0.04);
                            b = Bottle();
                            b = obj.readpose.read();
                            count = count + 1;
                        end
                        if count==obj.max_iter
                            disp(['cannot set ' num2str(wristJoints(2)) ' to '  num2str(wrist2Angle)]);
                            disp([num2str(wristJoints(2)) ' = '  num2str(b.get(wristJoints(2)).asDouble())]);
                        end
                        
                        interval3 =  (abs(wristBoundaries(3,1)) + abs(wristBoundaries(3,2)))/wristSegments;
                        
                        for wrist3Angle = wristBoundaries(3,1):interval3:wristBoundaries(3,2);
                            
                            cmd_string = ['set icmd cmod ' num2str(wristJoints(3)) ' pos'];
                            cmd = Bottle();
                            reply = Bottle();
                            cmd.fromString(cmd_string);
                            obj.rpclient.write(cmd, reply);
                            disp(reply.toString());
                            
                            cmd_string = ['set pos ' num2str(wristJoints(3)) ' '  num2str(wrist3Angle)];
                            cmd = Bottle();
                            reply = Bottle();
                            cmd.fromString(cmd_string);
                            obj.rpclient.write(cmd, reply);
                            disp(reply.toString());
                             
                            b = Bottle();
                            b = obj.readpose.read();
                            count = 0;
                            while abs(b.get(wristJoints(3)).asDouble() - wrist3Angle)>obj.joint_tol && count<obj.max_iter
                                pause(0.04);
                                b = Bottle();
                                b = obj.readpose.read();
                                count = count + 1;
                            end
                            if count==obj.max_iter
                                disp(['cannot set ' num2str(wristJoints(3)) ' to '  num2str(wrist3Angle)]);
                                disp([num2str(wristJoints(3)) ' = '  num2str(b.get(wristJoints(3)).asDouble())]);
                            end
                    
                            % iterate through the fingers for each given wrist angle
                            for iFinger = 1:length(fingers)
                                
                                interval = (abs(fingerBoundaries(iFinger,1))+abs(fingerBoundaries(iFinger,2)))/fingerSegments;
                                for fingerAngle = fingerBoundaries(iFinger,1):interval:fingerBoundaries(iFinger,2)
                                    
                                    cmd_string = ['set pos ' num2str(fingers(iFinger)) ' '  num2str(fingerAngle)];
                                    cmd = Bottle();
                                    reply = Bottle();
                                    cmd.fromString(cmd_string);
                                    obj.rpclient.write(cmd, reply);
                                    disp(reply.toString());
                                     
                                    b = Bottle();
                                    b = obj.readpose.read();
                                    count = 0;
                                    while abs(b.get(fingers(iFinger)).asDouble() - fingerAngle)>obj.joint_tol && count<obj.max_iter
                                        pause(0.04);
                                        b = Bottle();
                                        b = obj.readpose.read();
                                        count = count + 1;
                                    end
                                    if count==obj.max_iter
                                        disp(['cannot set ' num2str(fingers(iFinger)) ' to '  num2str(fingerAngle)]);
                                        disp([num2str(fingers(iFinger)) ' = '  num2str(b.get(fingers(iFinger)).asDouble())]);
                                    end
                                    
                                end
                                
                                % return each finger to neutral before moving to the next
                                    
                                cmd_string = ['set pos ' num2str((fingers(iFinger))) ' '  num2str(obj.joint0(iFinger))];
                                cmd = Bottle();
                                reply = Bottle();
                                cmd.fromString(cmd_string);
                                obj.rpclient.write(cmd, reply);
                                disp(reply.toString());
                                 
                                b = Bottle();
                                b = obj.readpose.read();
                                count = 0;
                                while abs(b.get(fingers(iFinger)).asDouble() - obj.joint0(iFinger))>obj.joint_tol && count<obj.max_iter
                                    pause(0.04);
                                    b = Bottle();
                                    b = obj.readpose.read();
                                    count = count + 1;
                                end
                                if count==obj.max_iter
                                    disp(['cannot set ' num2str(fingers(iFinger)) ' to '  num2str(obj.joint0(iFinger))]);
                                    disp([num2str(fingers(iFinger)) ' = '  num2str(b.get(fingers(iFinger)).asDouble())]);
                                end
                                
                            end
                        end
                    end
                end
            end
        end
        
        function release(obj)
            
            % we require an immediate stop
            % before closing the client for safety reason
            obj.icart.stopControl();
            
            % it's a good rule to restore the controller
            % context as it was before opening the module
            obj.icart.restoreContext(obj.startup_context_id);
            
            obj.client.close();
            
            obj.rpclient.close();
            
            obj.readpose.close();
            
            obj.igazeRpcPort.close();
            obj.igazeXdPort.close();
            obj.igazeLeftOutPort.close();
            obj.igazeRightOutPort.close();
        end
   
        function limitTorsoPitch(obj)
            
            import yarp.BufferedPortBottle
            import yarp.Port
            import yarp.Bottle
            import yarp.Time
            import yarp.RFModule
            import yarp.RateThread
            import yarp.Vector
            
            import yarp.Drivers
            import yarp.PolyDriver
            import yarp.IPositionControl
            import yarp.Property

            global MAX_TORSO_PITCH % [deg]
            
            axis = int32(0); % pitch joint
            min = 0;
            max = 0;
            
            % sometimes it may be helpful to reduce
            % the range of variability of the joints;
            % for example here we don't want the torso
            % to lean out more than 30 degrees forward
            
            % we keep the lower limit
            obj.icart.getLimits(axis,min,max);
            obj.icart.setLimits(axis,min,MAX_TORSO_PITCH);
        end
   
        function printStatus(obj)
            
            import yarp.BufferedPortBottle
            import yarp.Port
            import yarp.Bottle
            import yarp.Time
            import yarp.RFModule
            import yarp.RateThread
             import yarp.Vector
            
            import yarp.Drivers
            import yarp.PolyDriver
            import yarp.IPositionControl
            import yarp.Property

            global PRINT_STATUS_PER % [s]
            
            telapsed = toc(obj.t1);
            if (telapsed>=PRINT_STATUS_PER)
                
                obj.t1 = tic;
                
                x = Vector();
                o = Vector();
                xdhat = Vector();
                odhat = Vector();
                qdhat = Vector();
                
                % we get the current arm pose in the operational space
                obj.icart.getPose(x,o);
                
                % we get the final destination of the arm
                % as found by the solver: it differs a bit
                % from the desired pose according to the tolerances
                obj.icart.getDesired(xdhat,odhat,qdhat);
                
                %e_x = norm(xdhat-x);
                %e_o = norm(odhat-o);
                fprintf('++++++++\n');
                fprintf('xd          [m] = %s\n',obj.xd.toString(3));
                fprintf('xdhat       [m] = %s\n',xdhat.toString(3));
                fprintf('x           [m] = %s\n',x.toString(3));
                fprintf('od        [rad] = %s\n',obj.od.toString(3));
                fprintf('odhat     [rad] = %s\n',odhat.toString(3));
                fprintf('o         [rad] = %s\n',o.toString(3));
                %fprintf('norm(e_x)   [m] = %g\n',e_x);
                %fprintf('norm(e_o) [rad] = %g\n',e_o);
                fprintf('---------\n\n');
               
            end
        end
    end
end
  
