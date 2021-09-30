function IBIS_Trimmer(file_path, file_name, model_name, line_frequency, duty_cycle_pos_percent, duty_cycle_neg_percent,                             ...
                      lower_limit, upper_limit, trim_increment_step, postprocess_treshold, trim_start, trim_end, trimmer_type,                      ...
                      interpolation_method, plot_opt, file_IBIS_test_out)
    global TRUE FALSE RISING_WAVEFORM FALLING_WAVEFORM V_MINIMUM V_TYPICAL V_MAXIMUM IBIS_MAX_WAVEFORMDATA_COUNT TRIMMER_AUTO TRIMMER_MANUAL

    %Test results information
    fprintf('\n\n\tPlease check the test results at: %s\n\n', file_IBIS_test_out);
    test_output_FID       = fopen(file_IBIS_test_out, 'wt+');
    
    %Interface properties
    line_period           = 1/line_frequency;
    rising_width          = line_period * duty_cycle_pos_percent / 200;
    falling_width         = line_period * duty_cycle_neg_percent / 200;

    %Model name
    model_prefix          = '[Model]';
    end_of_file           = '[End]';
    
    %IBIS file
    IBIS_file             = fileread(horzcat(file_path, '\', file_name));
    temp_md               = transpose(strsplit(IBIS_file, '\n'));
    [size_md, ~]          = size(temp_md);
    
    index2     = 1;
    index_stop = 0;
    for index=1:(size_md - 1)
        if ((temp_md{index, 1}(1) == '|') || (strlength(temp_md{index, 1}) < 2))
            continue;
        elseif ((contains(temp_md{index, 1}, model_prefix)) && (contains(temp_md{index, 1}, model_name)))
            model_index(1) = index2;
            index_stop     = 1;            
        elseif ((index_stop) && (contains(temp_md{index, 1}, model_prefix)))
            model_index(2) = index2;
            index_stop     = 0;                        
        end
        %Split by line, without comments and empty lines
        IBIS_data_wo_comments{index2, 1} = temp_md{index, 1};
        index2                           = index2 + 1;
        %End of file reached
        if (contains(temp_md{index, 1}, end_of_file))
            break;
        end
    end
    
    %Model data
    model_data = IBIS_data_wo_comments(model_index(1):model_index(2));

    %Sub-model
        %Rising Waveform
    submodel_rising  = '[Rising Waveform]';
    [rising_wf_table,  submodel_rising_idx,  keyword_count_rising]  = Parse_SubModel_Waveform(submodel_rising,  model_data);
        %Falling Waveform
    submodel_falling = '[Falling Waveform]';
    [falling_wf_table, submodel_falling_idx, keyword_count_falling] = Parse_SubModel_Waveform(submodel_falling, model_data);
        %Start & end indexes
    submodel_rising_idx  = submodel_rising_idx  + model_index(1) - 1;
    submodel_falling_idx = submodel_falling_idx + model_index(1) - 1;

    [size_total, ~] = size(rising_wf_table);
    for index=1:size_total
        if (index > 1)
            fprintf(test_output_FID, '\n********** WAVEFORM [%d] END **********\n',   index - 1);
            fprintf(test_output_FID, '\n********** WAVEFORM [%d] START **********\n', index);
        else
            fprintf(test_output_FID, '\n********** WAVEFORM [%d] START **********\n', index);            
        end
        
        if (plot_opt{1, 1} == TRUE)
            %Plot the original waveforms
            fig_name                = sprintf('Original - Rising Waveform[%d]', index);
            fig{index}              = figure('Name', fig_name,  'Color', 'White', 'NumberTitle','off');
            fig{index}.NextPlot     = 'add';
                %Rising Waveform
            plot(rising_wf_table{index, 1}.Time, rising_wf_table{index, 1}.V_Minimum, 'Color', 'magenta');  %Min
            hold on;
            plot(rising_wf_table{index, 1}.Time, rising_wf_table{index, 1}.V_Typical, 'Color', 'cyan');  %Typ
            hold on;
            plot(rising_wf_table{index, 1}.Time, rising_wf_table{index, 1}.V_Maximum, 'Color', 'red');  %Max
            hold on;
            %Create new window
            fig_name                = sprintf('Original - Falling Waveform[%d]', index);        
            fig{index + 1}          = figure('Name', fig_name,  'Color', 'White', 'NumberTitle','off');        
            fig{index + 1}.NextPlot = 'add';
                %Falling Waveform
            plot(falling_wf_table{index, 1}.Time, falling_wf_table{index, 1}.V_Minimum, 'Color', 'magenta');  %Min
            hold on;
            plot(falling_wf_table{index, 1}.Time, falling_wf_table{index, 1}.V_Typical, 'Color', 'cyan');  %Typ
            hold on;
            plot(falling_wf_table{index, 1}.Time, falling_wf_table{index, 1}.V_Maximum, 'Color', 'red');  %Max
            hold on;
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %MINIMUM
            %Manual Trimmer
        if (trimmer_type               == TRIMMER_MANUAL)
                %Rising Waveform
            trim_wf_rising_min{index}  = Trim_Waveform_Manual(RISING_WAVEFORM,  V_MINIMUM,  rising_wf_table{index, 1},                                 ...
                                                              trim_start{1, V_MINIMUM}{1, index}, trim_end{1, V_MINIMUM}{1, index},                    ...
                                                              rising_width, falling_width, test_output_FID);
                %Falling Waveform
            trim_wf_falling_min{index} = Trim_Waveform_Manual(FALLING_WAVEFORM, V_MINIMUM,  falling_wf_table{index, 1},                                ...
                                                              trim_start{1, V_MINIMUM}{1, index + size_total},                                         ....
                                                              trim_end{1,   V_MINIMUM}{1, index + size_total},                                           ...
                                                              rising_width, falling_width, test_output_FID);                                                              
            %Auto Trimmer
        elseif (trimmer_type           == TRIMMER_AUTO)
                %Rising Waveform
            [trim_wf_rising_min{index},  twr_start_index{index}, twr_stop_index{index}]  = Trim_Waveform(RISING_WAVEFORM, V_MINIMUM,                   ...
                                                                                           rising_wf_table{index, 1}, rising_width, falling_width,     ...
                                                                                           lower_limit, upper_limit, trim_increment_step, test_output_FID);
                %Falling Waveform   
            [trim_wf_falling_min{index}, twf_start_index{index}, twf_stop_index{index}]  = Trim_Waveform(FALLING_WAVEFORM, V_MINIMUM,                  ...
                                                                                           falling_wf_table{index, 1}, rising_width, falling_width,    ...
                                                                                           lower_limit, upper_limit, trim_increment_step, test_output_FID);
        end
            %Interpolate the waveform to have the maximum points allowed by the IBIS standard for better precision
                %Rising Waveform
        interpolation_window{index}    = transpose(linspace(trim_wf_rising_min{1 , index}.Time(1),  trim_wf_rising_min{1 , index}.Time(end),           ...
                                                   IBIS_MAX_WAVEFORMDATA_COUNT));
        trim_wf_rising_min{index}      = interp1  (trim_wf_rising_min{1 , index}.Time,  trim_wf_rising_min{1 , index}.Voltage,                         ...
                                                   interpolation_window{1 , index}, interpolation_method);
        interp_wf_rising_min{index}    = table(interpolation_window{1 , index}, trim_wf_rising_min{1 , index},  'VariableNames', {'Time', 'Voltage'});
        plot_min_rising                = interp_wf_rising_min;
                %Falling Waveform
        interpolation_window{index}    = transpose(linspace(trim_wf_falling_min{1 , index}.Time(1), trim_wf_falling_min{1 , index}.Time(end),          ...
                                                   IBIS_MAX_WAVEFORMDATA_COUNT));
        trim_wf_falling_min{index}     = interp1  (trim_wf_falling_min{1 , index}.Time, trim_wf_falling_min{1 , index}.Voltage,                        ...
                                                   interpolation_window{1 , index}, interpolation_method);
        interp_wf_falling_min{index}   = table(interpolation_window{1 , index}, trim_wf_falling_min{1 , index}, 'VariableNames', {'Time', 'Voltage'});
        plot_min_falling               = interp_wf_falling_min;        
%             %Reference start is 0s
%         interp_wf_rising_min{index}    = Waveform_Shift(interp_wf_rising_min{1,  index},  0);
%         interp_wf_falling_min{index}   = Waveform_Shift(interp_wf_falling_min{1, index},  0);
            %Create the composite waveform
        composite_wf_min{index}        = Create_Composite_Waveform(interp_wf_rising_min{1,  index}, interp_wf_falling_min{1,  index});
            %Assign NA to the other waveforms in the V - T table
        wf_rising_min{index}           = Append_NA(interp_wf_rising_min{1,  index}, V_MINIMUM);
        wf_falling_min{index}          = Append_NA(interp_wf_falling_min{1, index}, V_MINIMUM);
            %Keywords
        wf_keywords_rising_min{index}  = IBIS_data_wo_comments((submodel_rising_idx(index, 1)   - 1 - keyword_count_rising(index, 1)):                 ...
                                                               (submodel_rising_idx(index, 1)   - 1));
        wf_keywords_falling_min{index} = IBIS_data_wo_comments((submodel_falling_idx(index, 1)  - 1 - keyword_count_falling(index, 1)):                ...
                                                               (submodel_falling_idx(index, 1)  - 1));
            %Modified Waveform
        wf_rising_min{index}           = table2cell(wf_rising_min{1,  index});
        wf_falling_min{index}          = table2cell(wf_falling_min{1, index});                                                        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %TYPICAL
            %Manual Trimmer
        if (trimmer_type               == TRIMMER_MANUAL)
                %Rising Waveform
            trim_wf_rising_typ{index}  = Trim_Waveform_Manual(RISING_WAVEFORM,  V_TYPICAL,  rising_wf_table{index, 1},                                 ...
                                                              trim_start{1, V_TYPICAL}{1, index}, trim_end{1, V_TYPICAL}{1, index},                    ...
                                                              rising_width, falling_width, test_output_FID);
                %Falling Waveform
            trim_wf_falling_typ{index} = Trim_Waveform_Manual(FALLING_WAVEFORM, V_TYPICAL,  falling_wf_table{index, 1},                                ...
                                                              trim_start{1, V_TYPICAL}{1, index + size_total},                                         ...
                                                              trim_end{1,   V_TYPICAL}{1, index + size_total},                                         ...
                                                              rising_width, falling_width, test_output_FID);                                                              
            %Auto Trimmer
        elseif (trimmer_type           == TRIMMER_AUTO)
                %Rising Waveform
            [trim_wf_rising_typ{index},  twr_start_index{index}, twr_stop_index{index}]  = Trim_Waveform(RISING_WAVEFORM, V_TYPICAL,                   ...
                                                                                           rising_wf_table{index, 1}, rising_width, falling_width,     ...
                                                                                           lower_limit, upper_limit, trim_increment_step, test_output_FID);
                %Falling Waveform   
            [trim_wf_falling_typ{index}, twf_start_index{index}, twf_stop_index{index}]  = Trim_Waveform(FALLING_WAVEFORM, V_TYPICAL,                  ...
                                                                                           falling_wf_table{index, 1}, rising_width, falling_width,    ...
                                                                                           lower_limit, upper_limit, trim_increment_step, test_output_FID);
        end
            %Interpolate the waveform to have the typical points allowed by the IBIS standard for better precision
                %Rising Waveform
        interpolation_window{index}    = transpose(linspace(trim_wf_rising_typ{1 , index}.Time(1),  trim_wf_rising_typ{1 , index}.Time(end),           ...
                                                   IBIS_MAX_WAVEFORMDATA_COUNT));
        trim_wf_rising_typ{index}      = interp1  (trim_wf_rising_typ{1 , index}.Time,  trim_wf_rising_typ{1 , index}.Voltage,                         ...
                                                   interpolation_window{1 , index}, interpolation_method);
        interp_wf_rising_typ{index}    = table(interpolation_window{1 , index}, trim_wf_rising_typ{1 , index},  'VariableNames', {'Time', 'Voltage'});
        plot_typ_rising                = interp_wf_rising_typ;
                %Falling Waveform
        interpolation_window{index}    = transpose(linspace(trim_wf_falling_typ{1 , index}.Time(1), trim_wf_falling_typ{1 , index}.Time(end),          ...
                                                   IBIS_MAX_WAVEFORMDATA_COUNT));
        trim_wf_falling_typ{index}     = interp1  (trim_wf_falling_typ{1 , index}.Time, trim_wf_falling_typ{1 , index}.Voltage,                        ...
                                                   interpolation_window{1 , index}, interpolation_method);
        interp_wf_falling_typ{index}   = table(interpolation_window{1 , index}, trim_wf_falling_typ{1 , index}, 'VariableNames', {'Time', 'Voltage'});
        plot_typ_falling               = interp_wf_falling_typ;        
%             %Reference start is 0s
%         interp_wf_rising_typ{index}    = Waveform_Shift(interp_wf_rising_typ{1,  index},  0);
%         interp_wf_falling_typ{index}   = Waveform_Shift(interp_wf_falling_typ{1, index},  0);
            %Create the composite waveform
        composite_wf_typ{index}        = Create_Composite_Waveform(interp_wf_rising_typ{1,  index}, interp_wf_falling_typ{1,  index});
            %Assign NA to the other waveforms in the V - T table
        wf_rising_typ{index}           = Append_NA(interp_wf_rising_typ{1,  index}, V_TYPICAL);
        wf_falling_typ{index}          = Append_NA(interp_wf_falling_typ{1, index}, V_TYPICAL);
            %Keywords
        wf_keywords_rising_typ{index}  = IBIS_data_wo_comments((submodel_rising_idx(index, 1)   - 1 - keyword_count_rising(index, 1)):                 ...
                                                               (submodel_rising_idx(index, 1)   - 1));
        wf_keywords_falling_typ{index} = IBIS_data_wo_comments((submodel_falling_idx(index, 1)  - 1 - keyword_count_falling(index, 1)):                ...
                                                               (submodel_falling_idx(index, 1)  - 1));
            %Modified Waveform
        wf_rising_typ{index}           = table2cell(wf_rising_typ{1,  index});
        wf_falling_typ{index}          = table2cell(wf_falling_typ{1, index});           
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %MAXIMUM
            %Manual Trimmer
        if (trimmer_type               == TRIMMER_MANUAL)
                %Rising Waveform
            trim_wf_rising_max{index}  = Trim_Waveform_Manual(RISING_WAVEFORM,  V_MAXIMUM,  rising_wf_table{index, 1},                                 ...
                                                              trim_start{1, V_MAXIMUM}{1, index}, trim_end{1, V_MAXIMUM}{1, index},                    ...
                                                              rising_width, falling_width, test_output_FID);
                %Falling Waveform
            trim_wf_falling_max{index} = Trim_Waveform_Manual(FALLING_WAVEFORM, V_MAXIMUM,  falling_wf_table{index, 1},                                ...
                                                              trim_start{1, V_MAXIMUM}{1, index + size_total},                                         ...
                                                              trim_end{1,   V_MAXIMUM}{1, index + size_total},                                         ...
                                                              rising_width, falling_width, test_output_FID);                                                              
            %Auto Trimmer
        elseif (trimmer_type           == TRIMMER_AUTO)
                %Rising Waveform
            [trim_wf_rising_max{index},  twr_start_index{index}, twr_stop_index{index}]  = Trim_Waveform(RISING_WAVEFORM, V_MAXIMUM,                   ...
                                                                                           rising_wf_table{index, 1}, rising_width, falling_width,     ...
                                                                                           lower_limit, upper_limit, trim_increment_step, test_output_FID);
                %Falling Waveform   
            [trim_wf_falling_max{index}, twf_start_index{index}, twf_stop_index{index}]  = Trim_Waveform(FALLING_WAVEFORM, V_MAXIMUM,                  ...
                                                                                           falling_wf_table{index, 1}, rising_width, falling_width,    ...
                                                                                           lower_limit, upper_limit, trim_increment_step, test_output_FID);
        end
            %Interpolate the waveform to have the maximum points allowed by the IBIS standard for better precision
                %Rising Waveform
        interpolation_window{index}    = transpose(linspace(trim_wf_rising_max{1 , index}.Time(1),  trim_wf_rising_max{1 , index}.Time(end),           ...
                                                   IBIS_MAX_WAVEFORMDATA_COUNT));
        trim_wf_rising_max{index}      = interp1  (trim_wf_rising_max{1 , index}.Time,  trim_wf_rising_max{1 , index}.Voltage,                         ...
                                                   interpolation_window{1 , index}, interpolation_method);
        interp_wf_rising_max{index}    = table(interpolation_window{1 , index}, trim_wf_rising_max{1 , index},  'VariableNames', {'Time', 'Voltage'});
        plot_max_rising                = interp_wf_rising_max;
                %Falling Waveform
        interpolation_window{index}    = transpose(linspace(trim_wf_falling_max{1 , index}.Time(1), trim_wf_falling_max{1 , index}.Time(end),          ...
                                                   IBIS_MAX_WAVEFORMDATA_COUNT));
        trim_wf_falling_max{index}     = interp1  (trim_wf_falling_max{1 , index}.Time, trim_wf_falling_max{1 , index}.Voltage,                        ...
                                                   interpolation_window{1 , index}, interpolation_method);
        interp_wf_falling_max{index}   = table(interpolation_window{1 , index}, trim_wf_falling_max{1 , index}, 'VariableNames', {'Time', 'Voltage'});
        plot_max_falling               = interp_wf_falling_max;        
%             %Reference start is 0s
%         interp_wf_rising_max{index}    = Waveform_Shift(interp_wf_rising_max{1,  index},  0);
%         interp_wf_falling_max{index}   = Waveform_Shift(interp_wf_falling_max{1, index},  0);
            %Create the composite waveform
        composite_wf_max{index}        = Create_Composite_Waveform(interp_wf_rising_max{1,  index}, interp_wf_falling_max{1,  index});
            %Assign NA to the other waveforms in the V - T table
        wf_rising_max{index}           = Append_NA(interp_wf_rising_max{1,  index}, V_MAXIMUM);
        wf_falling_max{index}          = Append_NA(interp_wf_falling_max{1, index}, V_MAXIMUM);        
            %Keywords
        wf_keywords_rising_max{index}  = IBIS_data_wo_comments((submodel_rising_idx(index, 1)   - 1 - keyword_count_rising(index, 1)):                 ...
                                                               (submodel_rising_idx(index, 1)   - 1));
        wf_keywords_falling_max{index} = IBIS_data_wo_comments((submodel_falling_idx(index, 1)  - 1 - keyword_count_falling(index, 1)):                ...
                                                               (submodel_falling_idx(index, 1)  - 1));
            %Modified Waveform
        wf_rising_max{index}           = table2cell(wf_rising_max{1,  index});
        wf_falling_max{index}          = table2cell(wf_falling_max{1, index});           
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %Print the delay information
            %Minimum
        time_diff = plot_min_rising{1, index}.Time(1) - plot_min_falling{1, index}.Time(1);
        fprintf(test_output_FID, '\n\n_____TIME DIFFERENCE(Rising - Falling Waveform)_____\n\tMINIMUM: [%0.20f\ts]', time_diff);
        if (time_diff < 0)
            fprintf(test_output_FID, '\tRising waveform needs the delay for correlation !');
        else
            fprintf(test_output_FID, '\tFalling waveform needs the delay for correlation !');            
        end
            %Typical
        time_diff = plot_typ_rising{1, index}.Time(1) - plot_typ_falling{1, index}.Time(1);
        fprintf(test_output_FID, '\n\tTYPICAL: [%0.20f\ts]', time_diff);
        if (time_diff < 0)
            fprintf(test_output_FID, '\tRising waveform needs the delay for correlation !');
        else
            fprintf(test_output_FID, '\tFalling waveform needs the delay for correlation !');            
        end
            %Maximum
        time_diff = plot_max_rising{1, index}.Time(1) - plot_max_falling{1, index}.Time(1);
        fprintf(test_output_FID, '\n\tMAXIMUM: [%0.20f\ts]', time_diff);
        if (time_diff < 0)
            fprintf(test_output_FID, '\tRising waveform needs the delay for correlation !');
        else
            fprintf(test_output_FID, '\tFalling waveform needs the delay for correlation !');            
        end       
        
        if (plot_opt{1, 2} == TRUE)
            %Plot the modified waveforms
            fig_name                = sprintf('Modified - Rising Waveform[%d]', index);
            fig{index + 2}          = figure('Name', fig_name, 'Color', 'White', 'NumberTitle','off');
            fig{index + 2}.NextPlot = 'add';
                %Rising Waveform
            plot(plot_min_rising{1, index}.Time, plot_min_rising{1, index}.Voltage,   'Color', 'magenta');  %Min
            hold on;
            plot(plot_typ_rising{1, index}.Time, plot_typ_rising{1, index}.Voltage,   'Color', 'cyan');  	%Typ
            hold on;
            plot(plot_max_rising{1, index}.Time, plot_max_rising{1, index}.Voltage,   'Color', 'red');  	%Max
            hold on;
            %Plot the modified waveforms
            fig_name                = sprintf('Modified - Falling Waveform[%d]', index);        
            fig{index + 3}          = figure('Name', fig_name, 'Color', 'White', 'NumberTitle','off');
            fig{index + 3}.NextPlot = 'add';		
                %Falling Waveform
            plot(plot_min_falling{1, index}.Time, plot_min_falling{1, index}.Voltage, 'Color', 'magenta');  %Min
            hold on;
            plot(plot_typ_falling{1, index}.Time, plot_typ_falling{1, index}.Voltage, 'Color', 'cyan');  	%Typ
            hold on;
            plot(plot_max_falling{1, index}.Time, plot_max_falling{1, index}.Voltage, 'Color', 'red');  	%Max
            hold on;
        end
        
        if (plot_opt{1, 3} == TRUE)
            %Plot the composite waveforms
            fig_name                = sprintf('Modified - Composite Waveform[%d]', index);        
            fig{index + 4}          = figure('Name', fig_name, 'Color', 'White', 'NumberTitle','off');
            fig{index + 4}.NextPlot = 'add';
                %Minimum
            plot(composite_wf_min{1, index}.Time, composite_wf_min{1, index}.Voltage, 'Color', 'magenta');
            hold on;
                %Typical
            plot(composite_wf_typ{1, index}.Time, composite_wf_typ{1, index}.Voltage, 'Color', 'cyan');
            hold on;
                %Maximum
            plot(composite_wf_max{1, index}.Time, composite_wf_max{1, index}.Voltage, 'Color', 'red');
            hold on;        
        end
    end
    fprintf(test_output_FID, '\n********** WAVEFORM [%d] END **********\n', index);
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Boundaries
    max_rising  = max(max(submodel_rising_idx));
    min_rising  = min(min(submodel_rising_idx));
    max_falling = max(max(submodel_falling_idx));
    min_falling = min(min(submodel_falling_idx));

    %Save the modified results into another IBIS file
    file_permission  		= 'wt+';
    %[Start - First Waveform]
    modified_start          = IBIS_data_wo_comments(1:(min_rising - keyword_count_rising(index, 1) - 2));                                                       
    %[Last Waveform - End]            
    modified_end            = IBIS_data_wo_comments((max_falling  + 1):end);
    %Write into a new *.ibs file        
        %MINIMUM
    analysis_type_str       = 'MINIMUM';
    Output_File_Name        = strcat('Modified_', model_name, '_', analysis_type_str, '.ibs');            
    IBIS_File_Complete(Output_File_Name, file_permission, modified_start, wf_keywords_rising_min, wf_rising_min,                                   ...
                       wf_keywords_falling_min, wf_falling_min, modified_end);
        %TYPICAL
    analysis_type_str       = 'TYPICAL';
    Output_File_Name        = strcat('Modified_', model_name, '_', analysis_type_str, '.ibs');
    IBIS_File_Complete(Output_File_Name, file_permission, modified_start, wf_keywords_rising_typ, wf_rising_typ,                                   ...
                       wf_keywords_falling_typ, wf_falling_typ, modified_end);        
        %MAXIMUM
    analysis_type_str       = 'MAXIMUM';
    Output_File_Name        = strcat('Modified_', model_name, '_', analysis_type_str, '.ibs');
    IBIS_File_Complete(Output_File_Name, file_permission, modified_start, wf_keywords_rising_max, wf_rising_max,                                   ...
                       wf_keywords_falling_max, wf_falling_max, modified_end);        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                                                                                                   
end

%Completes the IBIS file modification
function IBIS_File_Complete(Output_File_Name, file_permission, modified_start, wf_keywords_rising, wf_rising, wf_keywords_falling, wf_falling, modified_end)
    global IBIS_MAX_WAVEFORMDATA_COUNT CR LF
    %Convert waveforms into strings
    str_modified = '';
    [~, total_size] = size(wf_rising);
    for index=1:total_size
        str_rising   = '';
        str_falling  = '';        
        for index2=1:IBIS_MAX_WAVEFORMDATA_COUNT
            %Rising Waveform
            temp1       = sprintf('%s%s%s %s %s %s', char(CR), char(LF), string(wf_rising{1, index}{index2, 1}), ...
                                                     string(wf_rising{1, index}{index2, 2}),                     ...
                                                     string(wf_rising{1, index}{index2, 3}), string(wf_rising{1, index}{index2, 4}));
            str_rising  = strcat(str_rising, temp1);
            %Falling Waveform
            temp2       = sprintf('%s%s%s %s %s %s', char(CR), char(LF), string(wf_falling{1, index}{index2, 1}), ...
                                                     string(wf_falling{1, index}{index2, 2}),                     ...
                                                     string(wf_falling{1, index}{index2, 3}), string(wf_falling{1, index}{index2, 4}));
            str_falling = strcat(str_falling, temp2);   
        end
        %Keywords
        keyword_rising  = string(wf_keywords_rising{1,  index});
        keyword_falling = string(wf_keywords_falling{1, index});
        %Final string    
        str_modified    = vertcat(str_modified,    char(LF), keyword_rising, char(LF), str_rising, char(LF),       ...
                                  keyword_falling, char(LF), str_falling,    char(LF));
    end
    %Write into the given file with given permissions
    fileID   = fopen(Output_File_Name, file_permission);
    full_str = sprintf('%s%s%s%s%s%s%s', char(LF), string(modified_start), char(LF), str_modified, char(LF),string(modified_end), char(LF));
    fprintf(fileID, '%s', full_str);
    fclose(fileID);    
end

%Converts the V-T table into string format to re-write the IBIS file and/or excel spreadsheet
function str = Table2String(table)
    str_time = string(table.Time);
    str_vmin = string(table.V_Minimum);
    str_vtyp = string(table.V_Typical);
    str_vmax = string(table.V_Maximum);
    
    str = '';
    [size_table, ~] = size(table);
    for index=1:size_table
        %Time
        str_time(index, 1) = strcat(str_time(index, 1), 'S');
        %V(min)
        if (table.V_Minimum ~= 'NA')
            str_vmin(index, 1) = strcat(str_vmin(index, 1), 'V');
        end
        %V(typ)
        if (table.V_Typical ~= 'NA')
            str_vtyp(index, 1) = strcat(str_vtyp(index, 1), 'V');
        end
        %V(max)
        if (table.V_Maximum ~= 'NA')
            str_vmax(index, 1) = strcat(str_vmax(index, 1), 'V');
        end
        temp_str = sprintf('\n%s\t%s\t%s\t%s', str_time(index, 1), str_vtyp(index, 1), str_vmin(index, 1), str_vmax(index, 1));
        str      = strcat(str, temp_str);
    end
end

function wf_table_NA = Append_NA(waveform, analysis_type)
    global V_MINIMUM V_TYPICAL V_MAXIMUM

    [size_wf, ~]     = size(waveform);
    NA               = transpose(blanks(size_wf));
    NA(1:size_wf, 1) = 'N';
    NA(1:size_wf, 2) = 'A';
    
    if(analysis_type      == V_MINIMUM)
        %V-T with NA (V_typ, V_min, V_Max) respectively
        wf_table_NA = table(waveform.Time, NA, waveform.Voltage, NA, 'VariableNames', {'Time' 'V_Typical' 'V_Minimum' 'V_Maximum'});          
    elseif (analysis_type == V_TYPICAL)
        %V-T with NA (V_typ, V_min, V_Max) respectively
        wf_table_NA = table(waveform.Time, waveform.Voltage, NA, NA, 'VariableNames', {'Time' 'V_Typical' 'V_Minimum' 'V_Maximum'});        
    elseif (analysis_type == V_MAXIMUM)
        %V-T with NA (V_typ, V_min, V_Max) respectively
        wf_table_NA = table(waveform.Time, NA, NA, waveform.Voltage, 'VariableNames', {'Time' 'V_Typical' 'V_Minimum' 'V_Maximum'});         
    end
end

%Enables manual trimming of the given waveform
    %Trims:
        % [Time(data[0])        - Time(data[trim_start])] - Left part
        % [Time(data[trim_end]) - Time(data[end])]        - Right part        
function return_waveform = Trim_Waveform_Manual(waveform_type, analysis_type, waveform, trim_start_time, trim_end_time, ...
                                                rising_width, falling_width, test_output_FID)
    global V_MINIMUM V_TYPICAL V_MAXIMUM RISING_WAVEFORM FALLING_WAVEFORM OK
    
    if(analysis_type      == V_MINIMUM)
        Voltage           = waveform.V_Minimum;
    elseif (analysis_type == V_TYPICAL)
        Voltage           = waveform.V_Typical;
    elseif (analysis_type == V_MAXIMUM)
        Voltage           = waveform.V_Maximum;
    end    
    
    %Find the nearest points for trimming
    treshold_start = waveform.Time(end);
    treshold_end   = waveform.Time(end);
    [size_wf, ~]   = size(waveform);
    start_index    = 0;
    end_index      = size_wf;
    for index=1:size_wf
        start_difference = abs(trim_start_time - waveform.Time(index));
        end_difference   = abs(trim_end_time   - waveform.Time(index));
        %Nearest points
        if (start_difference < treshold_start)
            treshold_start = start_difference;
            start_index    = index;
        end
        if (end_difference < treshold_end)
            treshold_end = end_difference;
            end_index    = index;
        end
    end
    
    %Trim
    Time            = waveform.Time(start_index:end_index);
    Voltage         = Voltage(start_index:end_index);
    
    %Overclock test
    if (waveform_type == RISING_WAVEFORM)        
        test_name     = 'Rising Waveform';
        [result, msg] =  Buffer_Overclock_Test(test_output_FID, test_name, analysis_type, Time, rising_width);
        if (result    == OK)
            %Create the table
            return_waveform = table(Time, Voltage, 'VariableNames', {'Time', 'Voltage'});
        else
            error(msg);            
        end
    elseif (waveform_type == FALLING_WAVEFORM)
        test_name         = 'Falling Waveform';
        [result, msg]     =  Buffer_Overclock_Test(test_output_FID, test_name, analysis_type, Time, falling_width);
        if (result        == OK)
            %Create the table
            return_waveform = table(Time, Voltage, 'VariableNames', {'Time', 'Voltage'});
        else
            error(msg);
        end
    end
end

%Save the waveform into an excel sheet
    %File name without the extension
function Save_Waveform_Excel(waveform, file_name)
    file_name = char(strcat(file_name, '.xlsx'));
    %Clear previous analysis results
    if (exist(file_name, 'file'))
        delete(file_name);
    end    
    %Write
    writetable(waveform, file_name);
end

%Shifts the waveform [Left or Right]
    %New waveform is aligned to start_time [s]
function [waveform] = Waveform_Shift(waveform, start_time)
    [size_wf, ~] = size(waveform);
    time_diff = waveform.Time(1, 1) - start_time;
    for index=1:size_wf
        waveform.Time(index, 1) = waveform.Time(index, 1) - time_diff;
    end
end

%Post processing
    %Further smoothing the waveform
function [composite_waveform] = Post_Process_Waveforms(composite_waveform, postprocess_treshold,                                                    ...
                                                       wr_start_index, wr_stop_index, wf_start_index, wf_stop_index,                                ...
                                                       og_waveform_rising, og_waveform_falling, analysis_type, interpolation_method)
    global IBIS_MAX_WAVEFORMDATA_COUNT V_MINIMUM V_TYPICAL V_MAXIMUM
    
    falling_start_index = 0;
    treshold            = (-1) * composite_waveform.Voltage(IBIS_MAX_WAVEFORMDATA_COUNT + 2) * postprocess_treshold / 100;
    [size_wf, ~]        = size(composite_waveform);
    for index=IBIS_MAX_WAVEFORMDATA_COUNT + 2:size_wf
        if (composite_waveform.Voltage(index) - composite_waveform.Voltage(IBIS_MAX_WAVEFORMDATA_COUNT + 2) < treshold)
            falling_start_index = index;
            break;
        end
    end
    
    %Rising waveform interpolation
    %WF - Rising
    if(analysis_type      == V_MINIMUM)
        Voltage           = og_waveform_rising.V_Minimum;
    elseif (analysis_type == V_TYPICAL)
        Voltage           = og_waveform_rising.V_Typical;
    elseif (analysis_type == V_MAXIMUM)
        Voltage           = og_waveform_rising.V_Maximum;
    end    
    %Smooths the transition between Rising -> Falling Waveform
    if (falling_start_index)
        interpolation_step   = (og_waveform_rising.Time(end) - og_waveform_rising.Time(wr_stop_index)) /                                            ...
                               (falling_start_index - IBIS_MAX_WAVEFORMDATA_COUNT - 1);  
        rising_interpolation = transpose(interp1(og_waveform_rising.Time(wr_stop_index:end), Voltage(wr_stop_index:end),                            ...
                                og_waveform_rising.Time(wr_stop_index):interpolation_step:og_waveform_rising.Time(end), interpolation_method));
        %Re-assign the values into composite waveform
        composite_waveform.Voltage((IBIS_MAX_WAVEFORMDATA_COUNT + 2):(falling_start_index + 1)) = rising_interpolation;
    end
    
    %Falling waveform interpolation
    %WF - Rising
    if(analysis_type      == V_MINIMUM)
        Voltage           = og_waveform_falling.V_Minimum;
    elseif (analysis_type == V_TYPICAL)
        Voltage           = og_waveform_falling.V_Typical;
    elseif (analysis_type == V_MAXIMUM)
        Voltage           = og_waveform_falling.V_Maximum;
    end  
    treshold = (-1) * composite_waveform.Voltage(falling_start_index) * postprocess_treshold / 100;
    if (composite_waveform.Voltage(1) - composite_waveform.Voltage(end) < treshold)
        for index=falling_start_index:size_wf
            if (composite_waveform.Voltage(index) - composite_waveform.Voltage(IBIS_MAX_WAVEFORMDATA_COUNT + 2) < treshold)
                falling_trim_index = index;
                break;
            end
        end
        interpolation_step    = (og_waveform_falling.Time(end) - og_waveform_falling.Time(wf_stop_index)) /                                         ...
                               (falling_trim_index - falling_start_index + 1);  
        falling_interpolation = transpose(interp1(og_waveform_falling.Time(wf_stop_index:end), Voltage(wf_stop_index:end),                          ...
                                og_waveform_falling.Time(wf_stop_index):interpolation_step:og_waveform_falling.Time(end), interpolation_method));
        %Re-assign the waveform into composite waveform
            %Re-trim the steady state
            %Append the interpolated part at the end of the waveform to provide a continuous waveform between Falling -> Rising Waveform            
        composite_waveform.Voltage(falling_start_index:end) =                                                                                       ...
                         vertcat(composite_waveform.Voltage((falling_trim_index + 2):end), falling_interpolation);
    end
end

%Align start position for further process [Before Correlation]
%WARNING: This affects the real time timings and breaks the correlation between the two waveforms in the time domain
function [pp_waveform1, pp_waveform2, pp_wf1_start_index, pp_wf2_start_index, ispp] = Pre_Process_Waveforms(waveform1, waveform2)
    global TRUE 
    
    pp_waveform1       = waveform1;
    pp_waveform2       = waveform2;
    pp_wf1_start_index = waveform1.Time(1, 1);
    pp_wf2_start_index = waveform2.Time(1, 1);
    ispp               = TRUE;
    
    [size_wf1, ~] = size(waveform1);
    [size_wf2, ~] = size(waveform2);
    %WF1 needs negative shift
    if (waveform1.Time(1, 1) > waveform2.Time(1, 1))
        time_diff = waveform1.Time(1, 1) - waveform2.Time(1, 1);
        for index=1:size_wf1
            pp_waveform1.Time(index, 1) = waveform1.Time(index, 1) - time_diff;
        end        
    %WF2 needs negative shift
    elseif (waveform2.Time(1, 1) > waveform1.Time(1, 1))
        time_diff = waveform2.Time(1, 1) - waveform1.Time(1, 1);
        for index=1:size_wf2
            pp_waveform2.Time(index, 1) = waveform2.Time(index, 1) - time_diff;
        end
    end
end

%Create the composite waveform - Rising Waveform + Falling Waveform
function composite_waveform = Create_Composite_Waveform(rising_waveform, falling_waveform)
    [size_falling_wf, ~] = size(falling_waveform);
    %Shift the falling waveform at the end of rising waveform
    time_diff = falling_waveform.Time(1, 1) - rising_waveform.Time(end, 1);
    for index=1:size_falling_wf
        falling_waveform.Time(index, 1) = falling_waveform.Time(index, 1) - time_diff;
    end
    composite_waveform = vertcat(rising_waveform, falling_waveform(2:end, :));
end

%Interpolate the rising & falling waveform together
    %Further aligns the waveform
function [interpolated_waveform1, interpolated_waveform2] = Interpolate_Correlated_Waveforms(waveform1, waveform2, og_waveform1, og_waveform2, ...
                                                                                             analysis_type, pp_wf1_start_index,                ...
                                                                                             pp_wf2_start_index, ispp, interpolation_method)
    global IBIS_MAX_WAVEFORMDATA_COUNT V_MINIMUM V_TYPICAL V_MAXIMUM
    
    %Initial delay time equalization
    if (waveform1.Time(1, 1) > waveform2.Time(1, 1))
        int_start_time = waveform2.Time(1, 1);
    else
        int_start_time = waveform1.Time(1, 1);        
    end
 
    %Tail equalization
    if (abs(waveform1.Time(end, 1) - waveform1.Time(1, 1)) > abs(waveform2.Time(end, 1) - waveform2.Time(1, 1)))
        stop_time_diff = abs(waveform1.Time(end, 1) - waveform1.Time(1, 1));
    else
        stop_time_diff = abs(waveform2.Time(end, 1) - waveform2.Time(1, 1));        
    end    

    %Interpolation
        %WF - 1
    if(analysis_type      == V_MINIMUM)
        Voltage                  = og_waveform1.V_Minimum;
    elseif (analysis_type == V_TYPICAL)
        Voltage                  = og_waveform1.V_Typical;
    elseif (analysis_type == V_MAXIMUM)
        Voltage                  = og_waveform1.V_Maximum;
    end
    %Data is already pre-processed
    if (ispp)
        int_stop_time            = pp_wf1_start_index + stop_time_diff;                
    else
        int_stop_time            = waveform1.Time(1, 1) + stop_time_diff;        
    end    
    interpolation_step           = (int_stop_time - int_start_time) / IBIS_MAX_WAVEFORMDATA_COUNT;  
    [size_wf, ~]                 = size(transpose(int_start_time:interpolation_step:int_stop_time));
    interpolated_waveform1(:, 1) = transpose(linspace(0, stop_time_diff, size_wf));
    interpolated_waveform1(:, 2) = transpose(interp1(og_waveform1.Time, Voltage, int_start_time:interpolation_step:int_stop_time, ...
                                                     interpolation_method));                                                 
        %WF - 2
    if(analysis_type      == V_MINIMUM)
        Voltage                  = og_waveform2.V_Minimum;
    elseif (analysis_type == V_TYPICAL)
        Voltage                  = og_waveform2.V_Typical;
    elseif (analysis_type == V_MAXIMUM)
        Voltage                  = og_waveform2.V_Maximum;
    end
    %Data is already pre-processed    
    if (ispp)
        int_stop_time            = pp_wf2_start_index + stop_time_diff;                
    else
        int_stop_time            = waveform2.Time(1, 1) + stop_time_diff;        
    end
    interpolation_step           = (int_stop_time - int_start_time) / IBIS_MAX_WAVEFORMDATA_COUNT;
    [size_wf, ~]                 = size(transpose(int_start_time:interpolation_step:int_stop_time));
    interpolated_waveform2(:, 1) = transpose(linspace(0, stop_time_diff, size_wf));
    interpolated_waveform2(:, 2) = transpose(interp1(og_waveform2.Time, Voltage, int_start_time:interpolation_step:int_stop_time, ...
                                                     interpolation_method));
end

%Correlate Rising & Falling waveforms
    %Treat it as a continuous waveform
    %Inputs are [Time - Voltage] tables
function [aligned_waveform1, aligned_waveform2] = Correlate_Waveform(waveform1, waveform2, og_waveform1, og_waveform2, analysis_type, ...
                                                                     pp_wf1_start_index, pp_wf2_start_index, ispp)

    [size_waveform1, ~] = size(waveform1);
    [size_waveform2, ~] = size(waveform2);
    if (size_waveform1  > size_waveform2)
        time_difference = zeros(size_waveform1, 1);
    else
        time_difference = zeros(size_waveform2, 1);        
    end

    %Original waveforms
    aligned_waveform1 = waveform1;
    aligned_waveform2 = waveform2;  
    
    %Initial delay alignment
        %Already aligned
    if (waveform1.Time(1, 1) == waveform2.Time(1, 1))
        %WF1 needs further alignment
    elseif (waveform1.Time(1, 1) < waveform2.Time(1, 1))   
        for index=1:size_waveform1
            time_difference(index, 1) = abs(waveform2.Time(1, 1) - waveform1.Time(index, 1));
        end
        [~, starting_point_index_wf1] = min(time_difference(1:size_waveform1, 1));
        aligned_waveform1 = waveform1(starting_point_index_wf1:end, :);
        %WF2 needs further alignment
    elseif (waveform1.Time(1, 1) > waveform2.Time(1, 1))
        for index=1:size_waveform2
            time_difference(index, 1) = abs(waveform1.Time(1, 1) - waveform2.Time(index, 1));
        end
        [~, starting_point_index_wf2] = min(time_difference(1:size_waveform2, 1));
        aligned_waveform2 = waveform2(starting_point_index_wf2:end, :);        
    end
    
    %Interpolate and correlate the two waveforms together
        %Initial delay time will be the same
        %Trail times might be different
    [aligned_waveform1, aligned_waveform2] = Interpolate_Correlated_Waveforms(aligned_waveform1, aligned_waveform2, og_waveform1, og_waveform2, ...
                                                                              analysis_type, pp_wf1_start_index, pp_wf2_start_index, ispp,      ...
                                                                              interpolation_method);
        %Convert the results to a table
    aligned_waveform1 = table(aligned_waveform1(:,1), aligned_waveform1(:,2), 'VariableNames', {'Time', 'Voltage'});
    aligned_waveform2 = table(aligned_waveform2(:,1), aligned_waveform2(:,2), 'VariableNames', {'Time', 'Voltage'});        
end

%Sub model parsing
function [wf_table, submodel_index, index_keyword] = Parse_SubModel_Waveform(submodel, model_data)

    R_fixture     = 'R_fixture';
    V_fixture     = 'V_fixture';
    V_fixture_min = 'V_fixture_min';
    V_fixture_max = 'V_fixture_max';
    C_fixture     = 'C_fixture';
    L_fixture     = 'L_fixture';
    R_dut         = 'R_dut';
    L_dut         = 'L_dut';
    C_dut         = 'C_dut';
    
    [size_submodel, ~] = size(model_data);
    index_submodel     = 0;
    index_submodel_end = 0;
    for index=1:size_submodel
        if((index_submodel) && (                             ...
           contains(model_data{index, 1}, R_fixture)      || ...
           contains(model_data{index, 1}, V_fixture)      || ...
           contains(model_data{index, 1}, V_fixture_min)  || ...
           contains(model_data{index, 1}, V_fixture_max)  || ...
           contains(model_data{index, 1}, C_fixture)      || ...
           contains(model_data{index, 1}, L_fixture)      || ...
           contains(model_data{index, 1}, R_dut)          || ...
           contains(model_data{index, 1}, L_dut)          || ...
           contains(model_data{index, 1}, C_dut)             ...
           ))
            index_keyword(index_submodel, 1)  = index_keyword(index_submodel, 1) + 1;
        elseif (contains(model_data{index,  1}, submodel))
            %Start of the current submodel
            index_submodel                    = index_submodel + 1;
            index_keyword(index_submodel, 1)  = 0;
            submodel_index(index_submodel, 1) = index;
            %End of the previous submodel
            if (index_submodel > 1)
                submodel_index(index_submodel - 1, 2)  = index;
                index_submodel_end                     = index_submodel_end + 1;
            end
        elseif ((index_submodel > index_submodel_end) && (index > submodel_index(index_submodel, 1)) && (contains(model_data{index, 1}, '[')))
            %End of the current submodel
            submodel_index(index_submodel, 2) = index;
            index_submodel_end                = index_submodel_end + 1;
            %Task complete
            if (index_submodel == index_submodel_end)
                break;
            end
        end      
    end

    %Sub model data
    [size_submodel, ~] = size(submodel_index);
    for index=1:size_submodel
        submodel_index(index, 1) = submodel_index(index, 1) + index_keyword(index_submodel, 1) + 1;
        submodel_index(index, 2) = submodel_index(index, 2) - 1;
        submodel_data{index}     = model_data(submodel_index(index, 1):submodel_index(index, 2));
    end
    submodel_data = transpose(submodel_data);
    
    %Convert to table
    [size_submodel, ~]                   = size(submodel_data);
    for index=1:size_submodel
        [size_submodel_cell, ~]          = size(submodel_data{index, 1});
        for index2=1:size_submodel_cell
            wf_temp{index, 1}{index2, :} = strsplit(submodel_data{index, 1}{index2, 1});
        end
    end
    
    %Re-format the table
    for index3=1:size_submodel
        [size_submodel_cell, ~] = size(submodel_data{index3, 1});
        for index=1:size_submodel_cell  
            for index2=1:4
                %Format individual values
                    %Tera
                if (contains(wf_temp{index3, 1}{index, 1}{1, index2},     'T'))
                    result{index3}(index, index2) = str2double(wf_temp{index3, 1}{index, 1}{1, index2}(1:(end - 2))) * 1e12;
                    %Giga
                elseif (contains(wf_temp{index3, 1}{index, 1}{1, index2}, 'G'))
                    result{index3}(index, index2) = str2double(wf_temp{index3, 1}{index, 1}{1, index2}(1:(end - 2))) * 1e9;
                    %Mega
                elseif (contains(wf_temp{index3, 1}{index, 1}{1, index2}, 'M'))
                    result{index3}(index, index2) = str2double(wf_temp{index3, 1}{index, 1}{1, index2}(1:(end - 2))) * 1e6;
                    %Kilo
                elseif (contains(wf_temp{index3, 1}{index, 1}{1, index2}, 'k'))
                    result{index3}(index, index2) = str2double(wf_temp{index3, 1}{index, 1}{1, index2}(1:(end - 2))) * 1e3;
                    %Mili
                elseif (contains(wf_temp{index3, 1}{index, 1}{1, index2}, 'm'))
                    result{index3}(index, index2) = str2double(wf_temp{index3, 1}{index, 1}{1, index2}(1:(end - 2))) * 1e-3;
                    %Micro
                elseif (contains(wf_temp{index3, 1}{index, 1}{1, index2}, 'u'))
                    result{index3}(index, index2) = str2double(wf_temp{index3, 1}{index, 1}{1, index2}(1:(end - 2))) * 1e-6;
                    %Nano
                elseif (contains(wf_temp{index3, 1}{index, 1}{1, index2}, 'n'))
                    result{index3}(index, index2) = str2double(wf_temp{index3, 1}{index, 1}{1, index2}(1:(end - 2))) * 1e-9;
                    %Pico
                elseif (contains(wf_temp{index3, 1}{index, 1}{1, index2}, 'p'))
                    result{index3}(index, index2) = str2double(wf_temp{index3, 1}{index, 1}{1, index2}(1:(end - 2))) * 1e-12;
                    %Femto
                elseif (contains(wf_temp{index3, 1}{index, 1}{1, index2}, 'f'))
                    result{index3}(index, index2) = str2double(wf_temp{index3, 1}{index, 1}{1, index2}(1:(end - 2))) * 1e-15;
                    %A, V, Ohm, F, H, s ['a', 'A', 'v', 'V', 'o', 'O', 'F', 'h', 'H', 's', 'S']
                else
                    result{index3}(index, index2) = str2double(wf_temp{index3, 1}{index, 1}{1, index2}(1:(end - 2)));
                end
            end
        end
    end
    result = transpose(result);
     
    %Table
    [size_result, ~] = size(result);
    for index=1:size_result
        wf_table{index} = table(result{index, 1}(:, 1), result{index, 1}(:, 2), result{index, 1}(:, 3), result{index, 1}(:, 4), ...
                                'VariableNames', {'Time', 'V_Typical', 'V_Minimum', 'V_Maximum'});
    end
    wf_table = transpose(wf_table);
end

%Buffer overclocking test
    %Rising  Waveform: width = rising_width
    %Falling Waveform: width = falling_width
function [result, msg] = Buffer_Overclock_Test(test_output_FID, test_name, analysis_type, time, width)
    global OK NOK V_MINIMUM V_TYPICAL V_MAXIMUM

    %MINIMUM
    if(analysis_type      == V_MINIMUM)
        msg_atype         = fprintf(test_output_FID, '\n_____Buffer Overclock Test_____\n%s:', 'MINIMUM');
    %TYPICAL
    elseif (analysis_type == V_TYPICAL)
        msg_atype         = fprintf(test_output_FID, '\n_____Buffer Overclock Test_____\n%s:', 'TYPICAL');
    %MAXIMUM
    elseif (analysis_type == V_MAXIMUM)
        msg_atype         = fprintf(test_output_FID, '\n_____Buffer Overclock Test_____\n%s:', 'MAXIMUM');
    end   
    
    %Boundaries are checked against transmission line's frequency of operation
    if (abs(time(end) - time(1)) > width)
        msg_res = ...
        fprintf(test_output_FID, '\n\tBuffer is overclocked !\n\t\tMaximum allowed width[pos/neg] is:\t[%0.20f\ts]\n\t\tCurrent width[pos/neg] is:\t\t\t[%0.20f\ts]',  ...
                width, abs(time(end) - time(1)));
        msg = strcat(msg_atype, msg_res);
        result  = NOK;
    else
        msg_res = ...
        fprintf(test_output_FID, '\n\tTrimming successfull for %s !\n\t\tMaximum allowed width[pos/neg] is:\t[%0.20f\ts]\n\t\tCurrent width[pos/neg] is:\t\t\t[%0.20f\ts]', ...
                test_name, width, abs(time(end) - time(1)));
        msg = strcat(msg_atype, msg_res);
        result  = OK;
    end
end

%Trim the given waveform
    %Lower window = Steady state low val  +- percent(low)
    %Upper window = Steady state high val +- percent(high)
function [trimmed_waveform, trim_start_index, trim_stop_index] = Trim_Waveform(waveform_type, analysis_type, waveform, rising_width,         ...
                                                                               falling_width, lower_limit, upper_limit, trim_increment_step, ...
                                                                               test_output_FID)
    global OK RISING_WAVEFORM FALLING_WAVEFORM V_MINIMUM V_TYPICAL V_MAXIMUM

    %Waveform
        %Voltage
    if(analysis_type      == V_MINIMUM)
        Voltage           = waveform.V_Minimum;
    elseif (analysis_type == V_TYPICAL)
        Voltage           = waveform.V_Typical;
    elseif (analysis_type == V_MAXIMUM)
        Voltage           = waveform.V_Maximum;
    end   
        %Time
    Time = waveform.Time;
    
    trim_percentage_H   = lower_limit;
    %Sweep [0 - 100] / Ascending
    for trim_percentage_L=lower_limit:trim_increment_step:upper_limit
        %Rising Waveform
        if (waveform_type == RISING_WAVEFORM)
                %Steady state values
            steady_state_val_H = Voltage(end);
            steady_state_val_L = Voltage(1);

            limit1_L = steady_state_val_L - (max(Voltage) * trim_percentage_L / 100);
            limit1_H = steady_state_val_L + (max(Voltage) * trim_percentage_L / 100);
            limit2_L = steady_state_val_H - (abs(steady_state_val_H) * trim_percentage_H / 100);
            limit2_H = steady_state_val_H + (abs(steady_state_val_H) * trim_percentage_H / 100);
        %Falling Waveform
        elseif (waveform_type == FALLING_WAVEFORM)
                %Steady state values
            steady_state_val_H = Voltage(1);
            steady_state_val_L = Voltage(end);

            limit1_L = steady_state_val_H - (abs(steady_state_val_H) * trim_percentage_H / 100);
            limit1_H = steady_state_val_H + (abs(steady_state_val_H) * trim_percentage_H / 100);
            limit2_L = steady_state_val_L - (max(Voltage) * trim_percentage_L / 100);
            limit2_H = steady_state_val_L + (max(Voltage) * trim_percentage_L / 100);
        end
        trim_percentage_H = trim_percentage_H + trim_increment_step;
        
        upper_index_found  = 0;
        lower_index_found  = 0;
        [table_size, ~] = size(Time);
        for index=1:table_size
            %Lower index - RW
            %Upper index - FW
            if (((Voltage(index) >= limit1_H) || (Voltage(index) <= limit1_L)) && (~lower_index_found))
                lower_index       = index;
                trim_start_index  = lower_index;
                lower_index_found = 1;
            end
            %Upper index - RW
            %Lower index - FW        
            if (((Voltage(table_size - index + 1) >= limit2_H) || (Voltage(table_size - index + 1) <= limit2_L)) && (~upper_index_found))
                upper_index       = table_size - index + 1;
                trim_stop_index   = upper_index;
                upper_index_found = 1;
            end
        end
        %Test input
        temp_time = Time(lower_index:upper_index);

        if (waveform_type == RISING_WAVEFORM)        
            test_name     = 'Rising Waveform';
            [result, msg] =  Buffer_Overclock_Test(test_output_FID, test_name, analysis_type, temp_time, rising_width);
            if (result    == OK)
                %Trimmed waveform
                trimmed_waveform(:,1) = Time(lower_index:upper_index);     
                trimmed_waveform(:,2) = Voltage(lower_index:upper_index);                 
                %Convert the result into a table
                trimmed_waveform      = table(trimmed_waveform(:,1), trimmed_waveform(:,2), 'VariableNames', {'Time', 'Voltage'});
                break;
            end
        elseif (waveform_type == FALLING_WAVEFORM)
            test_name         = 'Falling Waveform';
            [result, msg]     =  Buffer_Overclock_Test(test_output_FID, test_name, analysis_type, temp_time, falling_width);
            if (result        == OK)
                %Trimmed waveform
                trimmed_waveform(:,1) = Time(lower_index:upper_index);     
                trimmed_waveform(:,2) = Voltage(lower_index:upper_index); 
                %Convert the result into a table
                trimmed_waveform      = table(trimmed_waveform(:,1), trimmed_waveform(:,2), 'VariableNames', {'Time', 'Voltage'});
                break;
            end
        end
    end
end