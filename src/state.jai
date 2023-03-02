Plugin_State :: struct {
    clap_ext := clap_plugin_state_t.{
        save=clap_state_save,
        load=clap_state_load
    };
}

clap_state_save :: (plugin: *clap_plugin_t, stream: *clap_ostream_t) -> bool #c_call {
    this_plugin := from_raw_clap_plugin(plugin);
    push_context this_plugin.plugin_context {
        using self := this_plugin.clap_state_ext;
        return true;
    }
}

clap_state_load :: (plugin: *clap_plugin_t, stream: *clap_istream_t) -> bool #c_call {
    this_plugin := from_raw_clap_plugin(plugin);
    push_context this_plugin.plugin_context {
        using self := this_plugin.clap_state_ext;
        return true;
    }
}
