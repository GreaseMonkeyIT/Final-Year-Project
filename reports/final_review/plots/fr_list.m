function list = fr_list()
%FR_LIST The figures of the final review: {file name, description, function}.
list = {
    'fig_pv_patterns',    'P-V curves of the nine shading patterns',                  @fr_pv_patterns
    'fig_startup_R1',     'Start-up waveforms on R1, Simulink, all variants',         @(r) fr_startup(r, 'R1')
    'fig_startup_P3',     'Start-up waveforms on P3, Simulink, all variants',         @(r) fr_startup(r, 'P3')
    'fig_search_points',  'Samples of each search on the P-V curve of R1',            @fr_search_points
    'fig_startup_stats',  'Start-up accuracy: 99 patterns (Simulink), all (static)',  @fr_startup_stats
    'fig_en50530',        'EN 50530 dynamic efficiency against the ramp slope',       @fr_en50530
    'fig_ramp_trace',     'One EN 50530 ramp: power against time',                    @(r) fr_traces_dyn(r, 'ramp')
    'fig_cloud_trace',    'One cloud event: power against time',                      @(r) fr_traces_dyn(r, 'cloud')
    'fig_cloud_stats',    '40 cloud events: efficiency and recovery time',            @fr_cloud_stats
    'fig_day',            'One full day and the energy ratio of all days',            @fr_day
    'fig_noise',          'Pattern steps under sensor noise',                         @fr_noise
    'fig_compute',        'Decision time and compute energy',                         @fr_compute
    };
end
