Param_Base :: struct {
    #as using clap_param_info: clap_param_info_t;   

    get_value: (param: *Param_Base) -> float64;
    set_value: (param: *Param_Base, float64);
    set_modulation: (param: *Param_Base, float64) = null;
    text_to_value: (param: *Param_Base, text: string) -> float64;
    value_to_text: (param: *Param_Base, value: float64) -> string;
}

Param_Holder :: struct {
    params: [..] *Param_Base;
}

Params :: struct {
    using param_holder: Param_Holder;
    clap_ext := clap_plugin_params_t.{
        count=clap_params_count,
        get_info=clap_params_get_info,
        get_value=clap_params_get_value,
        value_to_text=clap_params_value_to_text,
        text_to_value=clap_params_text_to_value,
        flush=clap_params_flush
    };
}

register_param :: (using plugin_params: Params, new_param: *Param_Base) {
    new_param.id = cast(u32) params.count;
    array_add(*params, new_param);
}

//===============================================================
Float_Parameter :: struct {
    #as using base_param: Param_Base;
    // TODO: some sort of normalisable range...
    current_value: float64;
    modulation_amount: float64 = 0.0;
}

init_param :: (using param: *Float_Parameter, param_name: string, param_module: string = "") {
    cookie = *base_param;
    
    flags |= .CLAP_PARAM_IS_AUTOMATABLE;
    flags |= .CLAP_PARAM_IS_MODULATABLE;

    memcpy(name.data, param_name.data, param_name.count);
    memcpy(module.data, param_module.data, param_module.count);

    min_value = 0.0;
    max_value = 1.0;
    default_value = 0.5;
    current_value = default_value;

    get_value = float_param_get_value;
    set_value = float_param_set_value;
    text_to_value = float_param_text_to_value;
    value_to_text = float_param_value_to_text;
}

float_param_get_value :: (param: *Param_Base) -> float64 {
    return (cast(*Float_Parameter) param).current_value;
}

float_param_set_value :: (param: *Param_Base, value: float64) {
    (cast (*Float_Parameter) param).current_value = value;
}

float_param_text_to_value :: (param: *Param_Base, text: string) -> float64 {
    return string_to_float64(text);
}

float_param_value_to_text :: (param: *Param_Base, value: float64) -> string {
    return tprint("%", value);
}

//===============================================================
clap_params_count :: (plugin: *clap_plugin_t) -> u32 #c_call {
    this_plugin := from_raw_clap_plugin(plugin);
    push_context this_plugin.plugin_context {
        using self := this_plugin.clap_params_ext;
        return cast(u32) params.count;
    }
}

clap_params_get_info :: (plugin: *clap_plugin_t, param_index: u32, param_info: *clap_param_info_t) -> bool #c_call {
    this_plugin := from_raw_clap_plugin(plugin);
    push_context this_plugin.plugin_context {
        using self := this_plugin.clap_params_ext;
        memcpy(param_info, *params[param_index].clap_param_info, size_of(clap_param_info_t));
        return true;
    }
}

clap_params_get_value :: (plugin: *clap_plugin_t, param_id: clap_id, out_value: *float64) -> bool #c_call {
    this_plugin := from_raw_clap_plugin(plugin);
    push_context this_plugin.plugin_context {
        using self := this_plugin.clap_params_ext;
        param := params[param_id];
        (<<out_value) = param.get_value(param);
        return true;
    }
}

clap_params_value_to_text :: (plugin: *clap_plugin_t, param_id: clap_id, value: float64, out_buffer: *char, out_buffer_capacity: u32) -> bool #c_call {
    this_plugin := from_raw_clap_plugin(plugin);
    push_context this_plugin.plugin_context {
        params := this_plugin.clap_params_ext;
        param := params.params[param_id];
        value_string := param.value_to_text(param, value);
        memcpy(out_buffer, value_string.data, value_string.count);
        return true;
    }
}

clap_params_text_to_value :: (plugin: *clap_plugin_t, param_id: clap_id, param_value_text: *char, out_value: *float64) -> bool #c_call {
    this_plugin := from_raw_clap_plugin(plugin);
    push_context this_plugin.plugin_context {
        params := this_plugin.clap_params_ext;
        param := params.params[param_id];

        value_str: string;
        value_str.data = param_value_text;
        value_str.count = c_style_strlen(param_value_text);

        (<<out_value) = param.text_to_value(param, value_str);

        return true;
    }
}

clap_params_flush :: (plugin: *clap_plugin_t, in: *clap_input_events_t, out: *clap_output_events_t) -> void #c_call {
}
