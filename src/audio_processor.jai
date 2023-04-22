Process_Buffers :: struct {
    data_in: [..] *float;
    data_out: [..] *float;
    num_in_channels: u32;
    num_out_channels: u32;
    num_samples: u32;
}

create_process_buffers :: (clap_buffer_in: *clap_audio_buffer_t,
                           clap_buffer_out: *clap_audio_buffer_t,
                           n_samples: u32,
                           sample_offset: u32 = 0) -> Process_Buffers {
    using process_buffers: Process_Buffers;

    // dynamic allocations, but should be real-time safe because we're using Temporary_Storage
    array_resize(*data_in, clap_buffer_in.channel_count, false); 
    array_resize(*data_out, clap_buffer_out.channel_count, false);

    num_samples = n_samples;
    num_in_channels = clap_buffer_in.channel_count;
    num_out_channels = clap_buffer_out.channel_count;
    
    for channel_idx: 0..clap_buffer_in.channel_count-1 {
        data_in[channel_idx] = clap_buffer_in.data32[channel_idx] + sample_offset;
    }
    for channel_idx: 0..clap_buffer_out.channel_count-1 {
        data_out[channel_idx] = clap_buffer_out.data32[channel_idx] + sample_offset;
    }

    return process_buffers;
}

Audio_Processor :: struct {
    derived: *void;
    process_audio: (proc: *Audio_Processor, buffers: *Process_Buffers);

    audio_thread_storage_data: [..] u8;
    audio_thread_storage: Temporary_Storage;
}
