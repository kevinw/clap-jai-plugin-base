#import "clap-jai";
// clap_plugin_descriptor (but not really...)
// from_raw_clap_plugin

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
    }

    return true;
}

plugin_deactivate :: (plugin: *clap_plugin_t) -> void #c_call {
    using self := from_raw_clap_plugin(plugin);
    push_context plugin_context {
        if deactivate != null {
            deactivate(self);
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

plugin_process :: (plugin: *clap_plugin_t, process: *clap_process_t) -> clap_process_status #c_call {
    using self := from_raw_clap_plugin(plugin);
    push_context audio_thread_ctx.ctx {
        context.allocator = temp;

        {
            out_events := process.out_events;
            // @TODO: push UI events to output queue...
        }

        num_samples := process.frames_count;
        events := process.in_events;
        num_events := events.size(events);
        current_event_index : u32 = 0;
        next_event_time := num_samples;

        if num_events > 0 { // get timestamp of first event
            next_event_time = events.get(events, 0).time;
        }

        process_event :: (events: *clap_input_events_t,
                          current_event_index: *u32,
                          next_event_time: *u32,
                          num_events: u32,
                          num_samples: u32,
                          sample_offset: u32,
                          params: *Param_Holder) {
            event := events.get(events, (<<current_event_index));

            if event.type == CLAP_EVENT_PARAM_VALUE {
                param_event := cast(*clap_event_param_value_t) event;
                param: *Param_Base;
                if param_event.cookie != null {
                    param = cast(*Param_Base) param_event.cookie;
                } else {
                    param = params.params[param_event.param_id];
                }

                param.set_value(param, param_event.value);
            }

            // process other clap events...

            (<<current_event_index) += 1;
            if (<<current_event_index) < num_events {
                (<<next_event_time) = events.get(events, (<<current_event_index)).time;
            } else {
                (<<next_event_time) = num_samples;
            }
        }

        get_num_samples_to_process :: (events: *clap_input_events_t,
                                       current_event_index: *u32,
                                       num_events: u32,
                                       n: u32,
                                       num_samples: u32) -> u32 {
            samples_until_end_of_block := num_samples - n;
            if num_events == 0 {
                return samples_until_end_of_block;
            }

            samples_until_next_event := samples_until_end_of_block;
            for event_index: (<<current_event_index)..num_events-1 {
                event := events.get(events, event_index);
                if (event.time < n + CLAP_PROCESS_EVENTS_RESOLUTION_SAMPLES) {
                    // this event is within the resolution size, so we don't need to split
                    continue;
                }

                if (event.space_id != CLAP_CORE_EVENT_SPACE_ID) {
                    continue; // never split for events that are not in the core namespace
                }

                // For now we're only splitting the block on parameter events
                // so we can get sample-accurate automation, and transport events.
                if (event.type == CLAP_EVENT_PARAM_VALUE ||
                    event.type == CLAP_EVENT_PARAM_MOD ||
                    event.type == CLAP_EVENT_TRANSPORT)
                {
                    samples_until_next_event = event.time - n;
                    break;
                }
            }

            // the number of samples left is less than
            // CLAP_PROCESS_EVENTS_RESOLUTION_SAMPLES so let's just
            // process the rest of the block
            if samples_until_end_of_block <= CLAP_PROCESS_EVENTS_RESOLUTION_SAMPLES {
                return samples_until_end_of_block;
            }

            // process up until the next event, rounding up to the nearest multiple
            // of CLAP_PROCESS_EVENTS_RESOLUTION_SAMPLES
            num_small_blocks := (samples_until_next_event + CLAP_PROCESS_EVENTS_RESOLUTION_SAMPLES - 1) / CLAP_PROCESS_EVENTS_RESOLUTION_SAMPLES;
            return min(num_small_blocks * CLAP_PROCESS_EVENTS_RESOLUTION_SAMPLES, samples_until_end_of_block);
        }

        CLAP_PROCESS_EVENTS_RESOLUTION_SAMPLES :: 64; // @TODO: make this configurable
        n : u32 = 0;
        while n < num_samples {
            num_samples_to_process := get_num_samples_to_process(events, *current_event_index, num_events, n, num_samples);
            
            // process the events in this sub-block
            while (next_event_time < n + num_samples_to_process && current_event_index < num_events) {
                process_event(events, *current_event_index, *next_event_time, num_events, num_samples, n, *params.param_holder);
            }

            process_buffers := create_process_buffers(process.audio_inputs, process.audio_outputs, num_samples_to_process, n);
            audio_processor.process_audio(*audio_processor, *process_buffers);

            // add output events to out-going queue...

            n += num_samples_to_process;
        }

        // process any leftover events
        while current_event_index < num_events {
            process_event(events, *current_event_index, *next_event_time, num_events, num_samples, num_samples, *params.param_holder);
        }

        return .CLAP_PROCESS_CONTINUE;
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
        
        if (id_cstr == CLAP_EXT_PARAMS && clap_params_ext != null) {
            log("Plugin extension %: FOUND!", id_str);
            return *clap_params_ext.clap_ext;
        } else if (id_cstr == CLAP_EXT_AUDIO_PORTS && clap_audio_ports_ext != null) {
            log("Plugin extension %: FOUND!", id_str);
            return *clap_audio_ports_ext.clap_ext;
        }
        
        log("Plugin extension %: NOT FOUND!", id_str);

        return null;
    }
}

plugin_on_main_thread :: (plugin: *clap_plugin_t) -> void #c_call {
}
