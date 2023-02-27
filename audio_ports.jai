Audio_Ports :: struct {
    clap_ext := clap_plugin_audio_ports_t.{
        count=clap_audio_ports_count,
        get=clap_audio_ports_get
    };
}

clap_audio_ports_count :: (plugin: *clap_plugin_t, is_input: bool) -> u32 #c_call {
    return 1; // @TODO
}

clap_audio_ports_get :: (plugin: *clap_plugin_t, index: u32, is_input: bool, info: *clap_audio_port_info_t) -> bool #c_call {
    if index == 0 {
        info.flags |= CLAP_AUDIO_PORT_IS_MAIN;
    }
    
    info.in_place_pair = CLAP_INVALID_ID; // @TODO

    info.channel_count = 2;
    info.port_type = CLAP_PORT_STEREO.data;

    return true;
}
