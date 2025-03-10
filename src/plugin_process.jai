CLAP_PROCESS_EVENTS_RESOLUTION_SAMPLES :: 64; // @TODO: make this configurable

// This is a macro for now... I'm not sure that's the right choice,
// but at least I know how macros work now.
process_event :: (sample_offset: u32) #expand {
    event := `events.get(`events, `current_event_index);

    if event.type == CLAP_EVENT_PARAM_VALUE {
        param_event := cast(*clap_event_param_value_t) event;
        param: *Param_Base;
        if param_event.cookie != null {
            param = cast(*Param_Base) param_event.cookie;
        } else {
            param = `params.params[param_event.param_id];
        }

        param.set_value(param, param_event.value);
    } else if event.type == CLAP_EVENT_PARAM_MOD {
        param_event := cast(*clap_event_param_mod_t) event;
	    param: *Param_Base;
	    if param_event.cookie != null {
	        param = cast(*Param_Base) param_event.cookie;
	    } else {
	        param = `params.params[param_event.param_id];
	    }

	    if param.set_modulation != null {
	        param.set_modulation(param, param_event.amount);
	    } else {
	        // host is misbehaving...
	    }
    }

    // process other clap events...

    `current_event_index += 1;
    if `current_event_index < `num_events {
        `next_event_time = `events.get(`events, `current_event_index).time;
    } else {
        `next_event_time = `num_samples;
    }
}

get_num_samples_to_process :: (n: u32) -> u32 #expand {
    samples_until_end_of_block := `num_samples - n;
    if `num_events == 0 {
        return samples_until_end_of_block;
    }

    samples_until_next_event := samples_until_end_of_block;
    for event_index: `current_event_index..`num_events-1 {
        event := `events.get(`events, event_index);
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

plugin_process :: (plugin: *clap_plugin_t, process: *clap_process_t) -> clap_process_status #c_call {
    
    using self := from_raw_clap_plugin(plugin);

    realtime_context : #Context;
    realtime_context.temporary_storage = *audio_processor.audio_thread_storage;
    realtime_context.allocator = temp;

    push_context realtime_context {
        defer reset_temporary_storage();

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

        n : u32 = 0;
        while n < num_samples {
            num_samples_to_process := get_num_samples_to_process(n);
            
            // process the events in this sub-block
            while (next_event_time < n + num_samples_to_process && current_event_index < num_events) {
                process_event(n);
            }

            process_buffers := create_process_buffers(process.audio_inputs, process.audio_outputs, num_samples_to_process, n);
            audio_processor.process_audio(*audio_processor, *process_buffers);

            // add output events to out-going queue...

            n += num_samples_to_process;
        }

        // process any leftover events
        while current_event_index < num_events {
            process_event(num_samples);
        }

        return .CLAP_PROCESS_CONTINUE;
    }
}
