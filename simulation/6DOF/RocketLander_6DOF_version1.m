
% RocketLander_6DOF_version1

% ===============================
% Symbol and Conventions Section

% ===============================
clc; 
clear
close all;

tic

% ===============================
% List of all shared variables
% (Initialize now so we know to share with nested functions)
global x0 xdot0_body xdot0_inertial y0 ydot0_body ydot0_inertial z0 zdot0_body zdot0_inertial
global psi0 theta0 phi0 alpha0 beta0 P0 Q0 R0 m0 I_xx0 I_yy0 I_zz0 C_G0 C_P0 thetaDot0 C_D S 
global thrustCurve ratesOptions rho S C_D g_accel t_fire burnTime
global propellantMass DesiredRange DesiredCrashSpeed animateOptions

% ===============================
% Input Section

% Load Trajectory parameters
Parameters_Trajectory

% Load Rocket parameters
Parameters_Rocket

% Load Motor parameters
Parameters_Motor

% Load Earth Data
Parameters_Earth

% Launch Angle Determination ODE45 options
tspan = [0 14]; % (s)
options = odeset('MaxStep',2.5E-2);
% Set options for running rates function
ratesOptions = [0 0];
% ratesOptions(1)   -   are we firing descent motor?
% ratesOptions(2)   -   are we using TVC?

% Setup Animation
global DART_stl orientation_animation trajectory_animation pos_tracked_X pos_tracked_Y pos_tracked_Z xdot_body ydot_body zdot_body
% setup_animation(eul2quat([psi0 theta0 phi0]), [xdot0_body ydot0_body zdot0_body])

initial_launch_angle = abs(90 - abs(90 - rad2deg(abs(theta0)))); % [deg]

% iterate through potential launch angles
for pitch_angle = deg2rad(initial_launch_angle)
    launch_angle = pitch_angle % set launch angle to theta
    Y0 = [x0 xdot0_body xdot0_inertial y0 ydot0_body ydot0_inertial z0 zdot0_body zdot0_inertial psi0 theta0 phi0 launch_angle alpha0 beta0 P0 Q0 R0 m0 I_xx0 I_yy0 I_zz0 C_G0]';
    % Launch rocket and calculate landing range
    [t,y] = ode45(@sixDOF,tspan,Y0,options);

    indices = find(y(:,5)>-0.2); % all states with positive altitude
    range = sqrt(y(indices(end),1)^2 + y(indices(end),3)^2);   % (m)
    
    % Check if desired range condition is satisfied within tolerance
    % if (range > DesiredRange)
        % set launch pitch angle
        thetaLaunch = pitch_angle; % (degrees)
        freeFlightTime = t;
        freeFlightStates = y;
        fprintf('Desired range possible with launch angle of %.2f degrees.\n',rad2deg(thetaLaunch))

        figure()
        plot3(freeFlightStates(indices,1),freeFlightStates(indices,4),freeFlightStates(indices,7),'b')
        hold on
        [~, index_burnout] = min(abs(freeFlightTime - burnTime));
        plot3(freeFlightStates(index_burnout,1),freeFlightStates(index_burnout,4),freeFlightStates(index_burnout,7),'.r',MarkerSize=10)
        grid minor
        xlabel('x (m)'); ylabel('y (m)'); zlabel('z (m)')
        title('3D Trajectory')
        print('time versus trajectory.png','-dpng','-r300')
        freeFlightStates(:,5) = atan2d(freeFlightStates(:,4),freeFlightStates(:,2)); % (degrees)
        % break
    % end

end

close(orientation_animation)
close(trajectory_animation)

%% Descent Motor Ignition Time Determination
index_Apogee = find(freeFlightStates(:,5)==max(freeFlightStates(indices,5)));
index_Crash = indices(end);

time_Apogee = freeFlightTime(index_Apogee)
time_Crash = freeFlightTime(index_Crash)

%% Motor timing Determination using ODE45

% ODE45 options and rates options
options_descent = odeset('RelTol',52E-1,'MaxStep',1E-1);

% Set options for running rates function
ratesOptions = [1 0];
% ratesOptions(1)   -   are we firing descent motor?
% ratesOptions(2)   -   are we using TVC?


figure(2);
hold on;
xlabel('t (s)')
ylabel('Crash Speed, vertical (m/s)')
leastCrashVelocity = 100; % initialize least crash_velocity
crash_velocity = -200; % initialize 
for ctr = index_Apogee+6050:index_Crash-200
    t_fire = t(ctr)
    tspan_descent = [t_fire 20]; % (s)
    Y0_descent = [y(ctr,1) y(ctr,2) y(ctr,3) y(ctr,4) y(ctr,5) y(ctr,6) y(ctr,7)]';
    [t_descent,y_descent] = ode45(@rates,tspan_descent,Y0_descent,options_descent);
    indices_descent = find(y_descent(:,3)>=0); % all states with positive altitude


    % Check to see if new crash velocity is least deadly crash velocity yet
    term1 = abs(y_descent(indices_descent(end),4));
    term2 = abs(leastCrashVelocity);
    if term1<term2
        descentTimingIndex = ctr;
        poweredDescentTime = t_descent;
        poweredDescentStates = y_descent;
        descentIndices = find(poweredDescentStates(:,3)>=0);
        leastCrashVelocity = term1; % (m/s)
        poweredDescentStates(:,5) = atan2d(poweredDescentStates(:,4),poweredDescentStates(:,2)); % (degrees)
    end

    % set variable for previous crash velocity (for checking and
    % comparison)
    crash_velocity = y_descent(indices_descent(end),4) % (m/s)
    % Check if desired range condition is satisfied within tolerance
    if abs(abs(crash_velocity)-abs(DesiredCrashSpeed))<=2E0
        % display descent firing time
        fprintf('Desired landing speed possible with descent motor timing of %.2f seconds after liftoff.\n',t_fire);
        plot(t_fire,crash_velocity,'r*')
    else
        plot(t_fire,crash_velocity,'b*')
    end
    % simulate the rocket descent with descent motor
    % evaluate crash velocity
    % if crash velocity is within tolerances:
        % output t_fire and display
        % save succesful landing trajectory states

end
title('Vertical Crash Speed versus Descent Ignition Timing')
print('landing speed and timing.png','-dpng','-r300')


figure(3);
hold on;
xlabel('x (m)');
ylabel('y (m)');
plot(freeFlightStates(1:descentTimingIndex,1),freeFlightStates(1:descentTimingIndex,3),'b*',poweredDescentStates(descentIndices,1),poweredDescentStates(descentIndices,3),'r*');
legend('Ascent and Unpowered Phase','Descent Burn Phase','location','best')
title('Ascent, freeflight, and Powered Descent Trajectory')
print('Powered Descent Trajectory.png','-dpng','-r300')

figure(4);
hold on
xlabel('t (s)');
ylabel('');
plot(freeFlightTime(1:descentTimingIndex),freeFlightStates(1:descentTimingIndex,2),'b*',poweredDescentTime(descentIndices),poweredDescentStates(descentIndices,2),'r*',freeFlightTime(1:descentTimingIndex),freeFlightStates(1:descentTimingIndex,4),'b:',poweredDescentTime(descentIndices),poweredDescentStates(descentIndices,4),'r:')
legend('Ascent and free flight v_x','Powered Descent v_x','Ascent and free flight v_y','Powered Descent v_y','location','best')
title('Vertical and Horizontal Velocities During Flight')
print('Velocity components during ascent, freeflight, and powered descent.png','-dpng','-r300')

disp(sprintf('landing v_x = %.2f m/s.',poweredDescentStates(descentIndices(end),2)))
disp(sprintf('landing v_y = %.2f m/s.',poweredDescentStates(descentIndices(end),4)))
disp(sprintf('landing theta = %.2f degrees.',poweredDescentStates(descentIndices(end),5)))

elapsedTime = toc
disp(sprintf('Elasped time was %.0f minutes, %.0f seconds.',elapsedTime/60,mod(elapsedTime,60)))

%%
% ===============================================================
% ANIMATION

figure(5)
title('Rocket Trajectory Animation')
xlabel('x (m)'); ylabel('y (m)'); zlabel('z (m)')
camlight('left');        
material('dull');
scaleFactor = 36.00000065 * 25.4;

%%

% set boundaries of screen by placing markers at launch site, target,
% apogee, ascent burnout, and descent ignition altitudes (and x and y
% coordinates)

%%

% setup patch for animation

        fv_noFire = stlread('Rocket_Lander_No_Fire.stl');
        fv_noFire.vertices = fv_noFire.vertices/scaleFactor;
        
        noFireRocket_patch = patch(fv_noFire,'FaceColor', [0 1 0], 'EdgeColor', 'none');
        rocket_Patch_XData0 = noFireRocket_patch.XData;
        rocket_Patch_ZData0 = noFireRocket_patch.ZData;
        
        fv_ascentRocketFire = stlread('Rocket_Lander_Ascent_Fire.stl');
        fv_ascentRocketFire.vertices = fv_ascentRocketFire.vertices/scaleFactor;
        
        ascentFire_patch = patch(fv_ascentRocketFire,'FaceColor', [1 0.1 0.1], 'EdgeColor', 'none');
        ascentFire_patch_XDATA0 = ascentFire_patch.XData;
        ascentFire_patch_ZDATA0 = ascentFire_patch.ZData;

% Loop through optimal states to animate rocket on ascent and coast
prevTime = 0; % initialize
for ctr = indices(1):descentTimingIndex
    timeAnimation = freeFlightTime(ctr);
    if or(timeAnimation>=prevTime+0.25,ctr==indices(1))
        statesToAnimate = freeFlightStates(ctr,:);

        if timeAnimation <= burnTime
            % show flame
            ascentFire_patch.XData = ascentFire_patch_XDATA0 + statesToAnimate(1);
            ascentFire_patch.ZData = ascentFire_patch_ZDATA0 + statesToAnimate(3);
        else
            ascentFire_patch.Visible = 'off';
        end
        
        % draw rocket
        noFireRocket_patch.XData = rocket_Patch_XData0 + statesToAnimate(1);
        noFireRocket_patch.ZData = rocket_Patch_ZData0 + statesToAnimate(3);

        xlim([-10 60]); zlim([-10 160]);  axis equal; view([12 14]);
        pause(0.01);
        prevTime = timeAnimation;

    end
end

%% Powered Descent

% setup patch for animation
fv_descendingRocket = stlread('Rocket_Lander_Descent_Rocket.stl');
fv_descendingRocket.vertices = fv_descendingRocket.vertices/scaleFactor;

descengingRocket_patch = patch(fv_descendingRocket,'FaceColor',[0 1 0],'EdgeColor','none');

descendingRocketP_patch_XData0 = ascentFire_patch.XData;
descendingRocketP_patch_ZData0 = ascentFire_patch.ZData;

fv_descentRocketFire = stlread('Rocket_Lander_Descent_Fire.stl');
fv_descentRocketFire.vertices = fv_descentRocketFire.vertices/scaleFactor;

descentFire_patch = patch(fv_descentRocketFire,'FaceColor', [1 .1 .1], 'EdgeColor', 'none');

descendingFire_patch_XData0 = descentFire_patch.XData;
descendingFire_patch_ZData0 = descentFire_patch.ZData;


% Loop through optimal states to animate rocket on powered descent
prevTime = 0; % initialize
timeAnimation = poweredDescentTime(descentIndices(1));
for ctr = descentIndices(1):descentIndices(end)
    if or(timeAnimation>=prevTime+0.25,ctr==indices(1))
        statesToAnimate = poweredDescentStates(ctr,:);

        % update descending rocket 
        descengingRocket_patch.XData = descendingRocketP_patch_XData0 + statesToAnimate(1); % m
        descengingRocket_patch.ZData = descendingRocketP_patch_ZData0 + statesToAnimate(3);

        % update descending fire
        descentFire_patch.XData = descendingFire_patch_XData0 + statesToAnimate(1); % m
        descentFire_patch.ZData = descendingFire_patch_ZData0 + statesToAnimate(3);

        xlim([-75 95]); zlim([-10 160]);  axis equal; view([12 14]);
        pause(0.01)
        prevTime = timeAnimation;

    end
end