# Libraries
import datetime
import math
import os
from rocketpy import Environment, SolidMotor, Rocket, prints
import stat
import sys

# Function for `shutil.rmtree` to call on "Access is denied" error from read-only folder
def remove_readonly(func, path, excinfo):
    os.chmod(path, stat.S_IWRITE)
    func(path)

results_dir = "Results"

if os.path.exists(results_dir):
    None
else:
    os.mkdir(results_dir) # Create folder for all results for the given date/time

# Establish Launch Date and Time (EST)
if (len(sys.argv) != 1): # sys.argv[0] is the program name
    launch_date = datetime.datetime.strptime(sys.argv[1], "%m-%d-%Y") # launch date
    launch_hour = int(sys.argv[2])
    launch_time = datetime.time(hour=launch_hour, minute=00) # # launch time (hr, min) (input as EST)
    launch_date_and_time = datetime.datetime.combine(launch_date, launch_time) # launch date and time
    if (len(sys.argv) > 4):
        automation_flag = int(sys.argv[4]) # flag to signal the program is being executed by an automatic runner
    else:
        automation_flag = 0 # the program is being executed manually
else: # use current date and time if none provided on the command line
    launch_date_and_time = datetime.datetime.now() # launch date and time

est_timezone = datetime.timezone(datetime.timedelta(hours=-5)) # UTC to EST timezone conversion
launch_date_and_time = launch_date_and_time.astimezone(est_timezone) # Ensure time used is EST

'''
Establish Launch Site Latitude & Longitude
Source 1: Google Maps (Independent)
https://www.google.com/maps/@27.933873,-80.7094486,55m/data=!3m1!1e3?entry=ttu&g_ep=EgoyMDI1MDEwOC4wIKXMDSoASAFQAw%3D%3D
'''
launch_site_latitude_independent = 27.933880 # [deg] North, launch site latitude (if launching independently (i.e., without a NAR section))
launch_site_longitude_independent = -80.709505 # [deg] West, launch site longitude (if launching independently (i.e., without a NAR section))

'''
Establish Launch Site Latitude & Longitude
Source 1: Google Maps (ROAR, NAR section 795)
https://www.google.com/maps/@28.5633031,-81.0187189,261m/data=!3m1!1e3?authuser=1&hl=en&entry=ttu&g_ep=EgoyMDI1MDEyOS4xIKXMDSoASAFQAw%3D%3D
'''
launch_site_latitude_ROAR = 27.563321 # [deg] North, launch site latitude (if launching with ROAR, NAR section 795))
launch_site_longitude_ROAR = -81.018022 # [deg] West, launch site longitude (if launching with ROAR, NAR section 795))

# Construct Launch Site Environment
launch_site = Environment(
    date=launch_date_and_time, # launch date and time
    latitude=launch_site_latitude_ROAR, # [deg] positive corresponds to North
    longitude=launch_site_longitude_ROAR, # [deg] positive corresponds to East
    elevation=4, # [m] launch site elevation above sea level
    max_expected_height=250 # [m] maximum altitude to keep weather data (must be above sea level)
)

'''
-------------------- Add Forecast (i.e., Wind) Information --------------------
Ensemble, GEFS: 1-deg geographical resolution, updated every 6 hours (00, 06, 12, 18UTC) (experimentally determined to have the same forecast depth as GFS)
Forecast, GFS: 0.25-deg geographical resolution, updated every 6 hours (good balance)
Forecast, RAP: 0.19-deg geographical resolution, updated hourly (best temporal resolution and update frequency)
Forecast, NAM: ~0.045-deg geographical resolution, updated every 6 hours with points spaced every 3 hours (best geographical resolution) (https://www.ncei.noaa.gov/products/weather-climate-models/north-american-mesoscale)
'''
try:
    launch_site.set_atmospheric_model(type="Forecast", file="RAP") # RAP updates hourly
except (ValueError): # ValueError thrown when "Chosen launch time is not available in the provided file"
    try:
        launch_site.set_atmospheric_model(type="Forecast", file="NAM") # NAM has 3-hour point spacing and updates every 6 hours
    except (ValueError): # same ValueError as above
        try:
            launch_site.set_atmospheric_model(type="Forecast", file="GFS") # GFS updates every 6 hours
        except (ValueError): # same ValueError as above
            try:
                launch_site.set_atmospheric_model(type="Ensemble", file="GEFS") # GEFS experimentally determined to have same forecast depth as GFS, but can't hurt to include just in case
            except (ValueError): # same ValueError as above
                None # will default to the ISA (no wind)
            else:
                print("Weather Model: GEFS")
        else:
            print("Weather Model: GFS")
    else:
        print("Weather Model: NAM")
else:
    print("Weather Model: RAP")

# Run if the script is executed directly (i.e., not as a module)
if __name__ == "__main__":
    # Print information of launch site conditions
    launch_site_prints = prints.environment_prints._EnvironmentPrints(launch_site)
    launch_site_prints.all()
    # Set Path to the Thrust Curve Source
    thrust_source_path = "../../../AeroTechG25W_thrustcurve.csv"
    # Set Path to the Fin Airfoil Geometry Source
    fin_airfoil_source_path = "NACA0012.csv"
else:
    thrust_source_path = "../../../../AeroTechG25W_thrustcurve.csv" # TBR, not a robust solution (only works from a directory one level higher)
    fin_airfoil_source_path = "../NACA0012.csv" # same TBR as above

# AeroTech-G25W Motor Characteristics
propellant_length=0.09235 # [m] length of propellant grain
propellant_OD=0.02355 # [m] outer diameter of propellant grain
propellant_ID=0.00608 # [m] diameter of propellant core
propellant_mass=62.5/1000 # [kg] mass of propellant

nozzle_length=0.0224 # [m] nozzle length (measured from exit plane to plane abutting propellant grain)

CG_position_dry=0.07309 # [m] positiion of motor CG without propellant (relative to nozzle exit plane)

# Construct AeroTechG25W Solid Rocket Motor
AeroTechG25W = SolidMotor(
    thrust_source=thrust_source_path, # [s, N]
    dry_mass=101.72/1000, # [kg]
    dry_inertia=(235307.21*(1000**(-3)), 235307.21*(1000**(-3)), 13414.14*(1000**(-3))), # [kg*m^2] motor's dry mass inertia tensor components (e_3 = rocket symmetry axis)
    nozzle_radius=7.70/2/1000, # [m] nozzle exit radius
    grain_number=1, # [unitless]
    grain_density=propellant_mass/(propellant_length*(math.pi*(propellant_OD/2)**2 - math.pi*(propellant_ID/2)**2)), # [kg/m^2]
    grain_outer_radius=propellant_OD/2, # [m]
    grain_initial_inner_radius=propellant_ID/2, # [m]
    grain_initial_height=propellant_length, # [m]
    grain_separation=0, # [m] all one propellant grain
    grains_center_of_mass_position=nozzle_length + (propellant_length/2), # [m]
    center_of_dry_mass_position=CG_position_dry, # [m]
    nozzle_position=0.0, # [m] position of nozzle exit area, relative to motor coordinate system origin
    burn_time=None, # [s] derived from `thrust_source`
    throat_radius=3.56/2/1000, # [m] radius of nozzle throat
    reshape_thrust_curve=False,
    interpolation_method="linear",
    coordinate_system_orientation="nozzle_to_combustion_chamber" # direction of positive coordinate system axis
)

# Rocket Characteristics
total_mass = 1434.96/1000 # [kg] maximum allowable rocket mass per 14 CFR Part 101.22 is 1500 grams
motor_mass = AeroTechG25W.propellant_initial_mass + AeroTechG25W.dry_mass # [kg] total mass of ONE motor

# Construct Rocket
DART_rocket = Rocket(
    radius=(3.28/2*25.4)/1000, # [m] largest outer radius
    mass=total_mass - motor_mass, # [kg] dry mass of the rocket
    inertia=(46065894.35*(1000**(-3)), 46057059.28*(1000**(-3)), 1796848.98*(1000**(-3)), 4106.46*(1000**(-3)), 53311.54*(1000**(-3)), 60557.58*(1000**(-3))), # [kg*m^2] rocket inertia tensor components (e_3 = rocket symmetry axis)
    power_off_drag=1.6939, # [unitless] C_D without motor firing
    power_on_drag=1.6939, # [unitless] C_D with motor firing
    center_of_mass_without_motor=0, # [m] position of the rocket CG w/o motors relative to the rocket's coordinate system
    coordinate_system_orientation="tail_to_nose" # direction of positive coordinate system axis
)

'''
-------------------- Add Ascent Motor --------------------
postion: [m] Position of the motor's coordinate system origin relative to the user defined rocket coordinate system
'''
DART_rocket.add_motor(AeroTechG25W, position=-0.370869)

'''
-------------------- Add Rail Buttons --------------------
upper_button_position: Position of the rail button furthest from the nozzle relative to the rocket's coordinate system
lower_button_position: Position of the rail button closest to the nozzle relative to the rocket's coordinate system
'''
DART_rail_buttons = DART_rocket.set_rail_buttons(
    upper_button_position=-0.1,
    lower_button_position=-0.3
) # [ARBITRARILY CHOSEN AND NEEDS TO BE UPDATED] !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

'''
-------------------- Add Nose Cone --------------------
length: [m] length of the nose cone (excluding the shoulder)
kind: One of {Von Karman, conical, ogive, lvhaack, powerseries}
position: [m] Nose cone tip coordinate relative to the rocket's coordinate system
'''
DART_nose = DART_rocket.add_nose(
    length=0.145836,
    kind="ogive",
    position=0.389190,
    bluffness=0.6/1.5
)

# Construct Fins
DART_fins = DART_rocket.add_trapezoidal_fins(
    n=3, # [unitless] number of fins
    root_chord=0.125223, # [m]
    tip_chord=0.062611, # [m]
    span=0.08636, # [m]
    position=-0.244369, # [m]
    cant_angle=0, # [deg] cant (i.e., tilt) angle of fins (non-zero will induce roll)
    airfoil=(fin_airfoil_source_path, "degrees"), # [CSV of {alpha,C_L}, alpha provided in degrees]
)

# Parachute Characteristics
C_D = 0.84 # [unitless] parachute drag coefficient
parachute_reference_area=math.pi*(30*0.0254/2)**2 # [m^2] reference area of parachute

# Construct Parachute
# main = DART_rocket.add_parachute(
#     name="main", # name of the parachute (no impact on simulation)
#     cd_s=C_D*parachute_reference_area, # [m^2] drag coefficient times parachute reference area
#     trigger="apogee", # will trigger the parachute deployment at apogee (can also use a callable function based on fresstream pressure, altitude, and state vector)
#     sampling_rate=10, # [Hz] sampling rate in which the trigger function works (used to simulate sensor refresh rates)
#     lag=0, # [s] time between the ejection system is triggers and the parachute is fully opened (SHOULD BE QUANTIFIED WITH EJECTION TESTING)
#     noise=(0,0,0) # [Pa] (mean, standard deviation, time-correlation) used to add noise to the pressure signal
# )

'''
Effective Launch Rail Length: length in which the rocket will be attached to the rail, only moving along a fixed direction (the line parallel to the rail)
Source: (https://docs.rocketpy.org/en/latest/reference/classes/Flight.html#rocketpy.Flight.__init__)

Measurements:
- Total Rail Length: 71 [in]
- Rail Length above Launch Stand: 63.25 [in]
- Distance between Launch Stand Pad and L-Bracket Hardstop: 2.125 [in]
- Lower Rail Button to Bottom of Ascent Motor Mount: 8.14 [in]
- Lower Rail Button to Bottom of Ascent Motor Mount Aft Closure: 8.58 [in]
- Upper Rail Button to Bottom of Ascent Motor Mount Aft Closure: 16.58 [in]

Final (Calculated) Length Options:
- Distance between the Top Rail Button and the Top of the Rail: 1.131 [m], 44.545 [in] (accounting for L-bracket hardstop)
- Distance between the Lower Rail Button and the Top of the Rail: 1.335 [m], 52.545 [in] (accounting for L-bracket hardstop)
'''
launch_rail_length = 1.131 # [m]