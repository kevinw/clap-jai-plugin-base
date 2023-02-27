plugin_creator :: #type (factory: *clap_plugin_factory_t, host: *clap_host_t) -> *clap_plugin_t;
plugin_descriptor_getter :: #type (factory: *clap_plugin_factory_t, idx: u32) -> *clap_plugin_descriptor_t #c_call;

#module_parameters(Plugin_Type: Type,
                   plugin_id: string,
                   PLUGIN_CREATOR: plugin_creator,
                   PLUGIN_DESCRIPTOR_GETTER: plugin_descriptor_getter);

#load "clap_entry.jai";
#load "host_proxy.jai";
#load "plugin_base.jai";
