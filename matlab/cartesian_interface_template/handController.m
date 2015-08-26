% Copyright: (C) 2015 iCub Facility
% Authors: Giulia Pasquale
% CopyPolicy: Released under the terms of the LGPLv2.1 or later, see LGPL.TXT

classdef handController < handle
    properties
        
        period
        
        client
        icart
        
        xd
        od
        
        startup_context_id
        
        t
        t0
        t1
        
    end
    
    methods
        
        function obj = handController(period)
  
            obj.period = period;
            
        end
         
        function success = init(obj)
            % open a client interface to connect to the cartesian server of the simulator
            % we suppose that:
            %
            % 1 - the iCub simulator is running
            %     (launch iCub_SIM)
            %
            % 2 - the cartesian server is running
            %     (launch simCartesianControl)
            %
            % 3 - the cartesian solver for the left arm is running too
            %     (launch iKinCartesianSolver --context simCartesianControl --part left_arm)
            
            import yarp.BufferedPortBottle
            import yarp.Port
            
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

            obj.xd = Vector();
            obj.od = Vector();
           
            option = Property('(device cartesiancontrollerclient)');
            option.put('remote','/icubSim/cartesianController/left_arm');
            option.put('local','/cartesian_client/left_arm');
            
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
            
            % set trajectory time
            obj.icart.setTrajTime(1.0);
            
            % get the torso dofs
            newDof = Vector();
            curDof = Vector();
            
            obj.icart.getDOF(curDof);
            newDof = curDof;
            
            % enable the torso yaw and pitch
            % disable the torso roll
            newDof.push_back(1);
            newDof.push_back(0);
            newDof.push_back(1);
            
            % impose some restriction on the torso pitch
            %obj.limitTorsoPitch();
            
            % send the request for dofs reconfiguration
            obj.icart.setDOF(newDof,curDof);
            
            % print out some info about the controller
            info = Bottle();
            obj.icart.getInfo(info);
            fprintf('info = %s\n',info.toString());
            
            obj.xd.resize(3);
            obj.od.resize(4);
            
            obj.t = tic;
            obj.t0 = tic;
            obj.t1 = tic;
            
            success = 1;
            
        end
        
        function run(obj)
            
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
 
            %import yarp.Network
            
            %net = Network();
            %net.init();
            
            finishup = onCleanup(@() obj.release() );
            
            obj.t = tic;
            while (true)

                telapsed = toc(obj.t);
                if (telapsed >= obj.period)
                    
                    obj.t = tic;
                    
                    obj.generateTarget();
                
                    % go to the target (in streaming)
                    obj.icart.goToPose(obj.xd,obj.od);
                
                    % some verbosity
                    obj.printStatus();
                    
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
        end
   
        function generateTarget(obj)
            
            
            % translational target part: a circular trajectory
            % in the yz plane centered in [-0.3,-0.1,0.1] with radius=0.1 m
            % and frequency 0.1 Hz
            obj.xd.set(1, -0.3);
            telapsed = toc(obj.t0);
            obj.xd.set(2, -0.1+0.1*cos(2.0*pi*0.1*(telapsed)));
            obj.xd.set(3, +0.1+0.1*sin(2.0*pi*0.1*(telapsed)));
            
            % we keep the orientation of the left arm constant:
            % we want the middle finger to point forward (end-effector x-axis)
            % with the palm turned down (end-effector y-axis points leftward);
            % to achieve that it is enough to rotate the root frame of pi around z-axis
            obj.od.set(1, 0.0);
            obj.od.set(2, 0.0);
            obj.od.set(3, 1.0);
            obj.od.set(4, pi);
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
  
