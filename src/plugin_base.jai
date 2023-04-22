#import "clap-jai";

Plugin_Base :: struct {
    // basic plugin stuff
    host_proxy: Host_Proxy;
    clap_plugin: clap_plugin_t;
    plugin_internal: *Plugin_Type;

    // context to use for non-audio thread stuff
    plugin_context: *Context;

    // implementing struct should override these where appropriate
    initialize_plugin: (plugin: *Plugin_Type); // REQUIRED
    deinitialize_plugin: (plugin: *Plugin_Type) = null;
    activate: (plugin: *Plugin_Type, sample_rate: float64, max_frames_count: u32); // REQUIRED
    deactivate: (plugin: *Plugin_Type) = null;
    start_processing: (plugin: *Plugin_Type) -> bool = null;
    stop_processing: (plugin: *Plugin_Type) = null;
    reset_plugin: (plugin: *Plugin_Type) = null;
    // process -> let the base handle events + block splitting
    // on_main_thread

    // extension interfaces...
    clap_audio_ports_ext: *Audio_Ports = null;
    clap_params_ext: *Params = null;
    clap_state_ext: *Plugin_State = null;
    clap_gui_ext: *Plugin_Gui = null;
}

from_raw_clap_plugin :: (plugin: *clap_plugin_t) -> *Plugin_Type #c_call {
    return cast(*Plugin_Type) plugin.plugin_data;
}

plugin_base_init :: (using plugin: *Plugin_Type, factory: *clap_plugin_factory_t, host: *clap_host_t) {
    host_proxy.host = host;
    plugin_internal = plugin;

    clap_plugin.desc = PLUGIN_DESCRIPTOR_GETTER(factory, 0);
    clap_plugin.plugin_data = plugin;
    clap_plugin.init = plugin_init;
    clap_plugin.destroy = plugin_destroy;
    clap_plugin.activate = plugin_activate;
    clap_plugin.deactivate = plugin_deactivate;
    clap_plugin.start_processing = plugin_start_processing;
    clap_plugin.stop_processing = plugin_stop_processing;
    clap_plugin.reset = plugin_reset;
    clap_plugin.process = plugin_process;
    clap_plugin.get_extension = plugin_get_extension;
    clap_plugin.on_main_thread = plugin_on_main_thread;
}

plugin_init :: (plugin: *clap_plugin_t) -> bool #c_call {
    using self := from_raw_clap_plugin(plugin);

    plugin_context = *host_proxy.host_jai_context;
    plugin_context.logger = Context_Base.default_logger;
    plugin_context.allocator = Context_Base.default_allocator;
    plugin_context.print_style = Print_Style.{};

    push_context plugin_context {
        log("Initializing host proxy!\n");
        host_proxy_init(*host_proxy, true);
        self.initialize_plugin(self);
    }

    return true;
}

plugin_destroy :: (plugin: *clap_plugin_t) -> void #c_call {
    using self := from_raw_clap_plugin(plugin);

    push_context plugin_context {
        if deinitialize_plugin != null {
            deinitialize_plugin(self);
        }

        // TODO: check that GUI is destroyed here!

        free(self);
    }
}

plugin_activate :: (plugin: *clap_plugin_t, sample_rate: float64, min_frames_count: u32, max_frames_count: u32) -> bool #c_call {
    using self := from_raw_clap_plugin(plugin);
    push_context plugin_context {
        log("Activating plugin with sample rate %, and max block size %\n", sample_rate, max_frames_count);
        activate(self, sample_rate, max_frames_count);

        if audio_processor.audio_thread_storage_data.count == 0 {
            audio_thread_storage_bytes := 20 * max_frames_count;
            array_resize(*audio_processor.audio_thread_storage_data, audio_thread_storage_bytes);
            audio_processor.audio_thread_storage.data = audio_processor.audio_thread_storage_data.data;
            audio_processor.audio_thread_storage.size = audio_thread_storage_bytes;
        }
    }

    return true;
}

plugin_deactivate :: (plugin: *clap_plugin_t) -> void #c_call {
    using self := from_raw_clap_plugin(plugin);
    push_context plugin_context {
        if deactivate != null {
            deactivate(self);
        }

        if audio_processor.audio_thread_storage_data.data != null {
            array_free(audio_processor.audio_thread_storage_data);
        }
    }
}

plugin_start_processing :: (plugin: *clap_plugin_t) -> bool #c_call {
    using self := from_raw_clap_plugin(plugin);
    push_context plugin_context {
        if start_processing != null {
            return start_processing(self);
        }

        return true;
    }
}

plugin_stop_processing :: (plugin: *clap_plugin_t) -> void #c_call {
    using self := from_raw_clap_plugin(plugin);
    push_context plugin_context {
        if stop_processing != null {
            stop_processing(self);
        }
    }
}

plugin_reset :: (plugin: *clap_plugin_t) -> void #c_call {
    using self := from_raw_clap_plugin(plugin);
    push_context plugin_context {
        if reset_plugin != null {
            reset_plugin(self);
        }
    }
}

plugin_get_extension :: (plugin: *clap_plugin_t, id: *char) -> *void #c_call {
    using self := from_raw_clap_plugin(plugin);
    push_context plugin_context {
        id_cstr: string;
        id_cstr.data = id;
        id_cstr.count = c_style_strlen(id) + 1;
        id_str := to_string(id);
        log("Host queried for plugin extension %\n", id_str);

        ext_found := true;
        defer {
            found_or_not := ifx ext_found then "FOUND" else "NOT FOUND";
            log("Plugin extension %: %!", id_str, found_or_not);
        }
        
        if (id_cstr == CLAP_EXT_PARAMS && clap_params_ext != null) {
            return *clap_params_ext.clap_ext;
        } else if (id_cstr == CLAP_EXT_AUDIO_PORTS && clap_audio_ports_ext != null) {
            return *clap_audio_ports_ext.clap_ext;
        } else if (id_cstr == CLAP_EXT_STATE && clap_state_ext != null) {
            return *clap_state_ext.clap_ext;
        } else if(id_cstr == CLAP_EXT_GUI && clap_gui_ext != null) {
            return *clap_gui_ext.clap_ext;
        }
        
        ext_found = false;
        return null;
    }
}

plugin_on_main_thread :: (plugin: *clap_plugin_t) -> void #c_call {
}
