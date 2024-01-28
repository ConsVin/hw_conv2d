module conv2d_binary #(
    parameter N_IMAGE  = 8,
    parameter K_KERNEL = 3,
    parameter BWD      = 1
)(
    input  logic            clk,
    input  logic            clear,
    
    input  logic [BWD-1:0]  i_data,
    input  logic            i_data_valid,
    
    // Use unpack array for top level simulation!
    input  logic[BWD-1:0]  i_kernel [K_KERNEL*K_KERNEL-1:0],

    output logic            o_data_clip,
    output logic            o_data_valid
);
//----------------------------------------
// Repack Unpacked Array back to packed
//----------------------------------------
typedef logic [K_KERNEL-1:0][K_KERNEL-1:0][BWD-1:0]  kernel_mat_t;
kernel_mat_t                            kernel;
logic [K_KERNEL*K_KERNEL-1:0][BWD-1:0]  kernel_packed_1d;
always_comb begin
    for (int i=0; i<$size(i_kernel); i++) begin
        // Inverse order to match window shape
        kernel_packed_1d[i] = i_kernel[$size(i_kernel)-1-i];
    end
    kernel = kernel_packed_1d;
end

//----------------------------------------
// Accumulate 2D Window
//----------------------------------------
// Two versions are presented, but only one is actually used
// Unused will be optimized away after synth
kernel_mat_t    window,               window_v1,       window_v2;
logic           window_valid,   window_valid_v1, window_valid_v2;
logic           window_end,       window_end_v1,   window_end_v2;

// Timing optimized, use FFs
window_buffer #(
    .N_IMAGE(N_IMAGE),
    .K_KERNEL(K_KERNEL),
    .BWD(BWD)
) i_window_buffer (
      .clk            ( clk               )
    , .clear          ( clear             )
    , .i_data         ( i_data            )
    , .i_data_valid   ( i_data_valid      )
    , .o_window       (   window_v1       )
    , .o_window_valid (   window_valid_v1 )
    , .o_window_end   (   window_end_v1   )
);

// Resource optimized, use Shift Registers
window_buffer_v2 #(
    .N_IMAGE(N_IMAGE),
    .K_KERNEL(K_KERNEL),
    .BWD(BWD)
) i_window_buffer_2 (
      .clk            ( clk            )
    , .clear          ( clear          )
    , .i_data         ( i_data         )
    , .i_data_valid   ( i_data_valid   )
    , .o_window       (  window_v2          )
    , .o_window_valid (  window_valid_v2    )
    , .o_window_end   (  window_end_v2      )
);

localparam USE_V2 = 1;
assign window         = ( USE_V2 ) ? window_v1       : window_v2;
assign window_valid   = ( USE_V2 ) ? window_valid_v1 : window_valid_v2;
assign window_end     = ( USE_V2 ) ? window_end_v1   : window_end_v2;

//---------------------------------
// Apply Kernel
//---------------------------------
logic [$clog2($bits(window)+1) -1:0] prod_sum;
// Note: prod_sum is asserted from CocoTB, don't rename!

kernel_1b_nxor#(
    .BW_BUS($bits(window))
)i_kernel_1b_nxor(
      .kernel( kernel     )
    , .i_data( window     )
    , .o_data( prod_sum   )
);

assign o_data_valid = window_valid;
assign o_data_clip  = (prod_sum > K_KERNEL/2);

// Simulation only code, can be use for debug
int valid_cnt = 0;
always_ff @(posedge clk) begin
    if (o_data_valid)
        valid_cnt += 1;
end

initial begin
    $dumpfile("dump.vcd");
end

endmodule
