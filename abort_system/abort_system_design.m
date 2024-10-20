% Abort System Design

%% Reset
clear; clc; close all;

set(0,'defaultTextInterpreter','latex')

%% Conversion Factors
feet_2_meters = 0.3048; % [unitless]
meters_2_feet = 1/feet_2_meters; % [unitless]
feet_2_inches = 12; % [unitless]
inches_2_feet = 1/feet_2_inches; % [unitless]

inches_2_meters = 0.0254; % [unitless]

lbs_2_newtons = 4.448; % [unitless]
newtons_2_lbs = 1/lbs_2_newtons; % [unitless]

%% Parachute Drop Test (C_D Determination) & Sizing
g = 9.81; % [m/s^2] gravitational acceleration
rho = 1.225; % [kg/m^3] sea-level air density

quick_link_mass = 0.077; % [kg]
test_parachute_mass = 0.062; % [kg]
test_parachute_radius = 15; % [in]
total_weight = (quick_link_mass + test_parachute_mass)*g; % [N]
height_of_deployment = 48*inches_2_meters; % [m] height at which parachute fully deployed
t_initial = 1.894; % [s]
t_final = 2.502; % [s]
v_terminal = height_of_deployment/(t_final - t_initial); % [m/s]
C_D_parachute = (2*total_weight)/(rho*v_terminal^2*pi*(test_parachute_radius*inches_2_meters)^2); % [unitless]

% Parachute Sizing
m_total = 1.5; % [kg] total mass
m_ascent_propellant = 0.0625; % [kg] ascent motor propellant mass

weight = (m_total - m_ascent_propellant)*g; % [N] rocket weight after ascent motor burnout

r_feet = 0.5:0.01:3; % [ft] potential parachute radii
r_meters = r_feet*feet_2_meters; % [m] potential parachute radii
A = pi*r_meters.^2; % [m^2] potential parachute cross-sectional area

v_meters = sqrt(2*weight/(rho*C_D_parachute)) * sqrt(1./A); % [m/s] corresponding parachute descent velocities
v_feet = v_meters*meters_2_feet; % [ft/s] corresponding parachute descent velocities

descent_rate_limits = [15 25]; % [ft/s] suggested lower and upper descent rate limits (hobby rocketry best practices)

CHOSEN_RADIUS = test_parachute_radius*inches_2_feet; % [ft] chosen parachute radius

opacities = [0.25, 0.5];
patch_shading = repmat(opacities, 1, 2);

figure
hold on
plot(r_feet, v_meters*meters_2_feet, 'k')
xlim([min(r_feet) max(r_feet)])
ylims = ylim;
title("Descent Rate [ft/s] vs. Parachute Radius [ft]", Interpreter="latex")
xlabel("Parachute Radius [ft]", Interpreter="latex")
ylabel("Descent Rate [ft/s]", Interpreter="latex")
pause();

yline(descent_rate_limits(2), '--', Label=sprintf("Upper Limit: %.i ft/s", descent_rate_limits(2)), LabelHorizontalAlignment="right", Interpreter="latex")
yline(descent_rate_limits(1), '--', Label=sprintf("Lower Limit: %.i ft/s", descent_rate_limits(1)), LabelHorizontalAlignment="right", LabelVerticalAlignment="bottom", Interpreter="latex")
fill([r_feet(1), r_feet(end), r_feet(end), r_feet(1)], [descent_rate_limits(1), descent_rate_limits(1), descent_rate_limits(2), descent_rate_limits(2)], 'green', FaceAlpha=0.25, EdgeAlpha=0)
pause();

[descent_rate_lower, descent_rate_lower_arg] = min(abs(v_feet - descent_rate_limits(1)));
[descent_rate_upper, descent_rate_upper_arg] = min(abs(v_feet - descent_rate_limits(2)));
[~, CHOSEN_RADIUS_arg] = min(abs(r_feet - CHOSEN_RADIUS));

xline(r_feet(descent_rate_lower_arg), 'r--', Label=sprintf("%.0f in", r_feet(descent_rate_lower_arg)*feet_2_inches), LabelHorizontalAlignment="center", LabelVerticalAlignment="top", LabelOrientation="horizontal", Interpreter="latex")
xline(r_feet(descent_rate_upper_arg), 'r--', Label=sprintf("%.0f in", r_feet(descent_rate_upper_arg)*feet_2_inches), LabelHorizontalAlignment="center", LabelVerticalAlignment="top", LabelOrientation="horizontal", Interpreter="latex")
plot(r_feet(descent_rate_lower_arg), v_feet(descent_rate_lower_arg), 'r.', MarkerSize=20)
plot(r_feet(descent_rate_upper_arg), v_feet(descent_rate_upper_arg), 'r.', MarkerSize=20)
pause();

line([CHOSEN_RADIUS CHOSEN_RADIUS], [ylims(1) v_feet(CHOSEN_RADIUS_arg)], 'Color', 'blue', 'LineStyle', '--')
line([min(r_feet) CHOSEN_RADIUS], [v_feet(CHOSEN_RADIUS_arg) v_feet(CHOSEN_RADIUS_arg)], 'Color', 'blue', 'LineStyle', '--')
plot(CHOSEN_RADIUS, v_feet(CHOSEN_RADIUS_arg), 'b.', MarkerSize=20)
text(CHOSEN_RADIUS, v_feet(CHOSEN_RADIUS_arg), sprintf("%.1f ft, %.2f ft/s", CHOSEN_RADIUS, v_feet(CHOSEN_RADIUS_arg)), HorizontalAlignment="left", VerticalAlignment="bottom", Interpreter="latex")

hold off

%% Parachute Sizing Tabular Output
fprintf("Parachute Radius [ft] | Descent Rate [ft/s]\n")
fprintf("-------------------------------------------\n")
for radius = r_feet
    fprintf("%-21.2f | %-19.2f\n", radius, v_meters(r_feet == radius)*meters_2_feet)
end

%% Run MATLAB Flight Simulation

run("../simulation/RocketLander_2D_version2p0/RocketLander_2D_version2p0.m") % run flight simulation

%% Shock Cord & Quick Link Load Calculations

flight_speed = sqrt(freeFlightStates(1:descentTimingIndex,2).^2 + freeFlightStates(1:descentTimingIndex,4).^2); % [m/s] flight speed (from RocketLander_2D_version2p0.m)
deployment_force_N = 0.5*rho*flight_speed.^2*A(CHOSEN_RADIUS_arg)*C_D_parachute; % [N] instantaneous force on abort system components if deployed
deployment_force_lb = deployment_force_N*newtons_2_lbs; % [N] instantaneous force on abort system components if deployed

free_flight_time = freeFlightTime(1:descentTimingIndex); % [s] flight time (excluding powered descent)

figure
hold on
plot(free_flight_time, flight_speed, 'k')
xlabel("Flight Time [s]")
ylabel("Flight Speed $\left[ \frac{m}{s} \right]$", Interpreter="latex")
yyaxis right
plot(free_flight_time, deployment_force_lb)
ylabel("Deployment Load [N]", Interpreter="latex")
title("Parachute Deployment Load [N] vs. Flight Time [s]")
pause();

x_axis_limits = xlim;
y_axis_limits = ylim;
fill([x_axis_limits(1), burnTime, burnTime, x_axis_limits(1)], [0, 0, y_axis_limits(2), y_axis_limits(2)], 'red', FaceAlpha=0.25, EdgeAlpha=0)
xline(burnTime, 'k--', Label="APS Burnout", LabelHorizontalAlignment="right", LabelVerticalAlignment="top", Interpreter="latex")
pause();

plot(free_flight_time(end), deployment_force_lb(end), 'r.', MarkerSize=20)
text(free_flight_time(end), deployment_force_lb(end), sprintf("%.0f lb", deployment_force_lb(end)), HorizontalAlignment="right", VerticalAlignment="bottom")

hold off

%% Component Sourcing
%{
Nylon Shock Cord: https://www.amazon.com/MONOBIN-Colors-Paracord-Bracelets-Making/dp/B09RWF3NQT/ref=sr_1_2?dib=eyJ2IjoiMSJ9.obURNx7DLeBG9d6WF0Vu890IIjM3V8tOHUNu2wlLI_sF-vlRyp2Yqc5ZKj5Spou3Z0JR2pvMmiEtl8vH73GmnZLMbHeBF_SbbP-76EB3CUlKbBHpCpW41zJay7QQOgtrn-fDH2yU4SOuaoHBS38ZFQEmgOaTIOjrYBjJOjwdQpzRMHh-PLbSdzxt8-sFU2uj.jAZBed-1Y61X77pORiha5LQrEE6aAlf7HkunTL4goic&dib_tag=se&m=A1B5F4J03US3M5&qid=1729018898&s=merchant-items&sr=1-2&th=1
Kevlar Shock Cord: https://www.9km-outdoor.com/products/100-kevlar-line-string-40lb-2000lb-fishing-assist-cord-strong-made-with-kevlar?variant=39439583150243
Quick Link: https://www.harborfreight.com/316-in-quick-links-3-piece-69062.html
%}