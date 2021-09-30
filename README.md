# IBIS_Graph_Trimmer
IBIS (I/O Buffer Information Specification) graph trimming script, written in MATLAB.

Often, the IBIS file provides a stationary waveform on either ends of the rising and/or falling waveforms. This part is mostly unnecessary since it provides no useful information on the slope of the waveform.

If the simulation requires a higher frequency than the IBIS file provides, it can lead to buffer overflows. Either a rising IBIS trigger happens in the middle of a falling transition or vice versa. This usually is being treated as an overclocking issue by the EDS environment.

This can further lead to false positive overshoot, undershoot and/or ringing issues. To overcome this issue, I have designed a script in MATLAB. It allows the following to be done on the IBIS model:

  - Manual trimming of the waveform
    - Start time
    - End time 
  - Automatic trimming of the waveform based on the following parameters:
    - Lower limit of the waveform (Starting point of the trimming function)
    - Upper limit of the waveform (End point of the trimming function)
    - Trimming increment step size (Trimming precision)
    - Post-process threshold
  - Line frequency selection
  - Positive and negative duty cycle selection

By default, the application processes the 2 rising and 2 falling waveforms given in the IBIS model. One waveform is where the V_fixture is equal to 0 and the other waveform is where the V_fixture is equal to Vcc. So, in total 4 waveforms are processed. Manual or automatic trimming can be selected and given as an input parameter to the function.

Application provides the user a selection of 1-D data interpolation methods. This gives the EDS tools a better data, with better precision. The data sample size can be modified, default is 1000. User can use the following as the interpolation method: 
  'linear'
  'nearest'
  'next'
  'previous'
  'pchip'
  'cubic'
  'v5cubic'
  'makima'
  'spline'
  
The default method is 'spline'.

The application can parse a sub-model of the given IBIS file. User is given an option to visualize the pre-processed and post-processed waveforms. These can be turned on or off.

Post-processed waveforms can be shifted in time to preserve the correlation between the rising and falling waveform. A composite waveform is created and can be printed to give the user a better visualization and understanding of the process.

Additionally, buffer overclock test is provided. By checking the output message, the user can have a better understanding of the underlying process and the new timings of the processed waveforms. The test is provided for both the rising and falling edge. 

V_minimum, V_typical, V_maximum is processed separately. Each can be written into individual modified IBIS or excel files, with the ".ibs" or ".xlsx" extension.
