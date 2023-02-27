clap_get_plugin_count :: (factory: *clap_plugin_factory_t) -> u32 #c_call {
    return 1;
}

clap_get_plugin_descriptor :: (factory: *clap_plugin_factory_t, idx: u32) -> *clap_plugin_descriptor_t #c_call {
    return PLUGIN_DESCRIPTOR_GETTER(factory, idx);
}

clap_create_plugin :: (factory: *clap_plugin_factory_t, host: *clap_host_t, clap_plugin_id: *char) -> *clap_plugin_t #c_call {
    new_context: Context;
    push_context new_context {
        str_plugin_id := to_string(clap_plugin_id);
        if (str_plugin_id != plugin_id) {
            print("Wrong plugin_id! Got: %, expected: %. Returning null!\n", str_plugin_id, plugin_id);
            return null;
        }
    
        return PLUGIN_CREATOR(factory, host);
    }
}

plugin_factory := clap_plugin_factory_t.{clap_get_plugin_count,
                                         clap_get_plugin_descriptor,
                                         clap_create_plugin};


clap_init :: (plugin_path: *char) -> bool #c_call {
    return true;
}

clap_deinit :: () #c_call {
}

clap_get_factory :: (factory_id: *char) -> *void #c_call {
    return *plugin_factory;
}

#program_export
clap_entry := clap_plugin_entry_t.{CLAP_VERSION,
                                   clap_init,
                                   clap_deinit,
                                   clap_get_factory};;

