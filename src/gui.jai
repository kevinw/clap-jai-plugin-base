// Trying out a little GUI system here...
// I think we may need to define our own window
// type that can do the sort of things that
// hosts expect plugin windows to be able to do.

// #import "Window_Creation";

Plugin_Gui :: struct {
    clap_ext := clap_plugin_gui_t.{
        is_api_supported=clap_gui_is_api_supported,
        get_preferred_api=clap_gui_get_preferred_api,
        create=clap_gui_create,
        destroy=clap_gui_destroy,
        set_scale=clap_gui_set_scale,
        get_size=clap_gui_get_size,
        can_resize=clap_gui_can_resize,
        get_resize_hints=clap_gui_get_resize_hints,
        adjust_size=clap_gui_adjust_size,
        set_size=clap_gui_set_size,
        set_parent=clap_gui_set_parent,
        set_transient=clap_gui_set_transient,
        suggest_title=clap_gui_suggest_title,
        show=clap_gui_show,
        hide=clap_gui_hide
    };

    // window: *Window_Type = null;
}

clap_gui_is_api_supported :: (plugin: *clap_plugin_t, api: *char, is_floating: bool) -> bool #c_call {
    // api_cstr: string;
    // api_cstr.data = api;
    // api_cstr.count = c_style_strlen(api) + 1;
    // return api_cstr == CLAP_WINDOW_API_WIN32;
    return false;
}

clap_gui_get_preferred_api :: (plugin: *clap_plugin_t, api: **char, is_floating: *bool) -> bool #c_call {
    return false;
}

clap_gui_create :: (plugin: *clap_plugin_t, api: *char, is_floating: bool) -> bool #c_call {
    this_plugin := from_raw_clap_plugin(plugin);
    push_context this_plugin.plugin_context {
        using self := this_plugin.clap_gui_ext;

        // if window != null {
        //     return false;
        // }

        // window = alloc(size_of(Window_Type));
        // (<<window) = create_window(400, 400, "Test Window");
        // return true;
    }

    return false;
}


clap_gui_destroy :: (plugin: *clap_plugin_t) -> void #c_call {
    this_plugin := from_raw_clap_plugin(plugin);
    push_context this_plugin.plugin_context {
        using self := this_plugin.clap_gui_ext;
        // if window != null {
        //     free(window);
        // }
    }
}

clap_gui_set_scale :: (plugin: *clap_plugin_t, scale: float64) -> bool #c_call {
    return false;
}

clap_gui_get_size :: (plugin: *clap_plugin_t, width: *u32, height: *u32) -> bool #c_call {
    (<<width) = 400;
    (<<height) = 400;
    return true;
}

clap_gui_can_resize :: (plugin: *clap_plugin_t) -> bool #c_call {
    return true;
}

clap_gui_get_resize_hints :: (plugin: *clap_plugin_t, hints: *clap_gui_resize_hints_t) -> bool #c_call {
    return false;
}

clap_gui_adjust_size :: (plugin: *clap_plugin_t, width: *u32, height: *u32) -> bool #c_call {
    return false;
}

clap_gui_set_size :: (plugin: *clap_plugin_t, width: u32, height: u32) -> bool #c_call {
    return false;
}

clap_gui_set_parent :: (plugin: *clap_plugin_t, window: *clap_window_t) -> bool #c_call {
    return false;
}

clap_gui_set_transient :: (plugin: *clap_plugin_t, window: *clap_window_t) -> bool #c_call {
    return false;
}

clap_gui_suggest_title :: (plugin: *clap_plugin_t, title: *char) -> void #c_call {
}

clap_gui_show :: (plugin: *clap_plugin_t) -> bool #c_call {
    return false;
}

clap_gui_hide :: (plugin: *clap_plugin_t) -> bool #c_call {
    return false;
}
