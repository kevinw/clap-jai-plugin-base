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
        params_ext := this_plugin.clap_params_ext;
        if params_ext == null {
            return false;
        }
        
        params_save_data := serialize_params(*params_ext.param_holder);
        while params_save_data.count > 0 {
            bytes_written := stream.write(stream, params_save_data.data, cast(u64) params_save_data.count);
            if bytes_written < 0 {
                return false;
            }
            
            params_save_data.count -= bytes_written;
            params_save_data.data += bytes_written;
        }
        
        return true;
    }
}

clap_state_load :: (plugin: *clap_plugin_t, stream: *clap_istream_t) -> bool #c_call {
    this_plugin := from_raw_clap_plugin(plugin);
    push_context this_plugin.plugin_context {
        using self := this_plugin.clap_state_ext;
        params_ext := this_plugin.clap_params_ext;
        if params_ext == null {
            return false;
        }
        
        params_save_data : [..] u8;
        params_save_data.allocator = context.allocator;
        
        BYTES_TO_READ :: 256;
        read_buffer : [BYTES_TO_READ] u8;
        
        bytes_read := 1;
        while bytes_read > 0 {
            bytes_read = stream.read(stream, read_buffer.data, BYTES_TO_READ);
            if bytes_read < 0 {
                return false;
            }
            
            data_just_read := array_view(read_buffer, 0, bytes_read);
            array_add(*params_save_data, ..data_just_read);
        }
        
        deserialize_params(*params_ext.param_holder, params_save_data);
        
        return true;
    }
}
