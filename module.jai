plugin_creator :: #type (factory: *clap_plugin_factory_t, host: *clap_host_t) -> *clap_plugin_t;
plugin_descriptor_getter :: #type (factory: *clap_plugin_factory_t, idx: u32) -> *clap_plugin_descriptor_t #c_call;

#module_parameters(Plugin_Type: Type,
                   plugin_id: string,
                   PLUGIN_CREATOR: plugin_creator,
                   PLUGIN_DESCRIPTOR_GETTER: plugin_descriptor_getter);

#load "src/audio_ports.jai";
#load "src/audio_processor.jai";
#load "src/clap_entry.jai";
#load "src/gui.jai";
#load "src/host_proxy.jai";
#load "src/params.jai";
#load "src/plugin_base.jai";
#load "src/plugin_process.jai";
#load "src/state.jai";
