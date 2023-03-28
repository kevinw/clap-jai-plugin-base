Math :: #import "Math";
String :: #import "String";

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

register_param :: (using plugin_params: *Params, new_param: *Param_Base) {
    new_param.id = cast(u32) params.count;
    array_add(*params, new_param);
}

//===============================================================
Param_Save_Info :: struct {
    param_id: clap_id;
    param_value: float64;
}

serialize_params :: (using param_holder: *Param_Holder) -> [] u8 #must {
    serial_buffer : [] u8;
    serial_buffer.count = size_of(Param_Save_Info) * params.count;
    serial_buffer.data = alloc(serial_buffer.count, context.allocator);
    serial_ptr := cast(*Param_Save_Info) serial_buffer.data;
    memset(serial_buffer.data, 0, serial_buffer.count);
    
    info : Param_Save_Info;
    for param, idx : params {
        info.param_id = param.id;
        info.param_value = param.get_value(param);
        
        memcpy(serial_ptr + idx, *info, size_of(Param_Save_Info));
    }
    
    return serial_buffer;
}

deserialize_params :: (using param_holder: *Param_Holder, serial_buffer: [] u8) -> bool {
    if serial_buffer.count % size_of (Param_Save_Info) != 0 {
        return false;
    }
    
    serial_ptr := cast(*Param_Save_Info) serial_buffer.data;
    num_serials := serial_buffer.count / size_of (Param_Save_Info);
    info : Param_Save_Info;
    for idx : 0..num_serials-1 {
        memcpy(*info, serial_ptr + idx, size_of(Param_Save_Info));
        
        for param, idx : params {
            if param.id == info.param_id {
                param.set_value(param, info.param_value);
                break;
            }
        }
    }
    
    // TODO: if a param is not set, we should reset it to it's default state!

    return true;
}

//===============================================================
Normalisable_Range :: struct ($T: Type) {
    start: T;
    end: T;
    skew: T;
}

init_range :: (using range: *Normalisable_Range($T), _start: T, _end: T, _centre: T) {
    start = _start;
    end = _end;
    set_skew_value(range, _centre);
}

set_skew_value :: (using range: *Normalisable_Range($T), centre: T) {
    skew = Math.log(cast(T) 0.5) / Math.log((centre - start) / (end - start));
}

convert_to :: (using range: *Normalisable_Range($T), value: T) -> T {
    proportion := (value - start) / (end - start);
    Math.Clamp(*proportion, 0.0, 1.0);

    if (skew == cast(T) 1) {
        return proportion;
    }

    return Math.pow(proportion, skew);
}

convert_from :: (using range: *Normalisable_Range($T), proportion: T) -> T {
    Math.Clamp(*proportion, 0.0, 1.0);

    if (skew != cast(T) 1 && proportion > cast(T) 0) {
        proportion = Math.exp(Math.log(proportion) / skew);
    }

    return start + (end - start) * proportion;
}

Float_Parameter :: struct {
    #as using base_param: Param_Base;
    
    range: Normalisable_Range(float64);
    current_value: float64;
    modulation_amount: float64 = 0.0;
}

init_param :: (using param: *Float_Parameter,
               param_name: string,
               min_val: float64,
               max_val: float64,
               centre_val: float64,
               default_val: float64,
               param_module: string = "") {
    cookie = *base_param;
    
    flags |= .CLAP_PARAM_IS_AUTOMATABLE;
    flags |= .CLAP_PARAM_IS_MODULATABLE;

    memcpy(name.data, param_name.data, param_name.count);
    memcpy(module.data, param_module.data, param_module.count);

    min_value = 0.0;
    max_value = 1.0;
    init_range(*range, min_val, max_val, centre_val);
    default_value = convert_to(*range, default_val);
    current_value = default_value;

    get_value = float_param_get_normalised_value;
    set_value = float_param_set_normalised_value;
    set_modulation = float_param_set_modulation;
    text_to_value = float_param_text_to_value;
    value_to_text = float_param_value_to_text;
}

param_get_value :: (using param: *Float_Parameter) -> float64 {
    return convert_from(*range, current_value);
}

param_get_modulated_value :: (using param: *Float_Parameter) -> float64 {
    modulated_value_01 := current_value + modulation_amount;
    Math.Clamp(*modulated_value_01, 0.0, 1.0);
    return convert_from(*range, modulated_value_01);
}

float_param_get_normalised_value :: (param_base: *Param_Base) -> float64 {
    using param := cast(*Float_Parameter) param_base;
    return current_value;
}

float_param_set_normalised_value :: (param_base: *Param_Base, value: float64) {
    using param := cast(*Float_Parameter) param_base;
    current_value = value;
}

float_param_set_modulation :: (param_base: *Param_Base, mod_amount: float64) {
    using param := cast(*Float_Parameter) param_base;
    modulation_amount = mod_amount;
}

float_param_text_to_value :: (param_base: *Param_Base, text: string) -> float64 {
    using param := cast(*Float_Parameter) param_base;
    return convert_to(*range, string_to_float64(text));
}

float_param_value_to_text :: (param_base: *Param_Base, value: float64) -> string {
    using param := cast(*Float_Parameter) param_base;
    return tprint("%", convert_from(*range, value));
}

//===============================================================
// Just like a Float_Parameter, except the text<->value conversions are in units of Hz/kHz
Frequency_Parameter :: struct {
    #as using base: Float_Parameter;
}

init_param :: (using param: *Frequency_Parameter,
               param_name: string,
               min_val: float64,
               max_val: float64,
               centre_val: float64,
               default_val: float64,
               param_module: string = "") {
    init_param(cast(*Float_Parameter) param, param_name, min_val, max_val, centre_val, default_val, param_module);
    text_to_value = freq_param_text_to_value;
    value_to_text = freq_param_value_to_text;
}

freq_param_text_to_value :: (param_base: *Param_Base, text: string) -> float64 {
    using param := cast(*Float_Parameter) param_base;

    is_khz := String.contains(text, "k");
    text_trim := String.trim_left(text, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ; ");
    text_trim = String.trim_right(text_trim, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ; ");

    if text_trim.count == 0 {
        return default_value;
    }

    unnormed_value := string_to_float64(text_trim);
    if is_khz {
        unnormed_value *= 1000.0;
    }
    return convert_to(*range, unnormed_value);
}

freq_param_value_to_text :: (param_base: *Param_Base, value: float64) -> string {
    using param := cast(*Float_Parameter) param_base;
    unnormed_value := convert_from(*range, value);
    suffix := ifx unnormed_value >= 1000.0 {
        unnormed_value /= 1000.0;
        "kHz";
    } else {
        "Hz";
    }
    return tprint("% %", formatFloat(unnormed_value, trailing_width=2, zero_removal=.NO), suffix);
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
