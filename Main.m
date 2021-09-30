% Main Application
function Main()

%Clean the workspace & command window
clear;
clc;

%Global variables
global OK NOK TRUE FALSE RISING_WAVEFORM FALLING_WAVEFORM IBIS_MAX_WAVEFORMDATA_COUNT V_MINIMUM V_TYPICAL V_MAXIMUM TRIMMER_AUTO TRIMMER_MANUAL         ...
       CR LF

CR                          = 13;
LF                          = 10;
OK                          = 0;
NOK                         = -1;
TRUE                        = 1;
FALSE                       = 0;
V_MINIMUM                   = 1;
V_TYPICAL                   = 2;
V_MAXIMUM                   = 3;
TRIMMER_AUTO                = 1;
TRIMMER_MANUAL              = 1;
RISING_WAVEFORM             = 1;
FALLING_WAVEFORM            = 0;
IBIS_MAX_WAVEFORMDATA_COUNT = 1000;

%Get the input arguments
fprintf('[Please fill/update the appropriate excel file before executing the script !]\n\n[Start of the execution !]');

%IBIS
    %Path to test output file
file_IBIS_test_out     = '';
    %Path to the IBIS directory
file_path              = '';
    %File name
file_name              = '';
    %Sub model
model_name             = '';
    %Interface properties
duty_cycle_pos_percent = 50;
duty_cycle_neg_percent = 50;
line_frequency         = 75;
    %Interpolation properties
interpolation_method   = 'spline';
    %Trimmer properties [%, s]
trimmer_type = TRIMMER_AUTO;
        %Auto Trimmer
            %Starts trimming betwen [%lower_limit] of the waveform and [%upper_limit] of the waveform
lower_limit            = 0;
upper_limit            = 100;
trim_increment_step    = 1e-3;
postprocess_treshold   = 0.0001; % Unit: [%]
        %Manual Trimmer
%WARNING: If the rising & falling trim start times are different, this difference must be compansated in the EDA tool stimulus !
    %Rising - Falling waveforms are time correlated, they must have the same reference as a start time !
    %Line Delay = EDA Stimulus Delay - MATLAB delay [Rising <-> Falling]
%Rising - Falling V-T are time correlated, they must be the same !
    %MINIMUM
trim_start{V_MINIMUM} = {3.0000e-9, 1.7500e-9, 3.5000e-9, 4.5000e-9};      %[Waveform(1) - Waveform(2) - ... - Waveform(n)]
trim_end  {V_MINIMUM} = {4.4999e-9, 3.2499e-9, 4.8999e-9, 5.8999e-9};
    %TYPICAL
trim_start{V_TYPICAL} = {1.5999e-9, 0.7000e-9, 1.5000e-9, 2.1400e-9};      %[Waveform(1) - Waveform(2) - ... - Waveform(n)]
trim_end  {V_TYPICAL} = {3.0999e-9, 2.1999e-9, 2.9999e-9, 3.6399e-9};
    %MAXIMUM
trim_start{V_MAXIMUM} = {1.0000e-9, 0.3000e-9, 0.7999e-9, 1.1500e-9};      %[Waveform(1) - Waveform(2) - ... - Waveform(n)]
trim_end  {V_MAXIMUM} = {2.4999e-9, 1.7999e-9, 2.2999e-9, 2.6499e-9};
    %Visualization properties
plot_opt = {TRUE, TRUE, TRUE};                                             %Original - Modified - Composite
    %Function call
func = @IBIS_Trimmer;
func(file_path, file_name, model_name, line_frequency, duty_cycle_pos_percent, duty_cycle_neg_percent, lower_limit, upper_limit, trim_increment_step, ...
     postprocess_treshold, trim_start, trim_end, trimmer_type, interpolation_method, plot_opt, file_IBIS_test_out);

%Program completion
fprintf('\n[Successfull execution !]\n');

end