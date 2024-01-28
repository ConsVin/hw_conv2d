
module window_buffer_v2#(
    parameter N_IMAGE  = 8,
    parameter K_KERNEL = 3,
    parameter BWD      = 8
)(
    input  logic clk,
    input  logic clear,

    input  logic                             [BWD-1:0] i_data,
    input  logic                                       i_data_valid,

    output logic [K_KERNEL-1:0][K_KERNEL-1:0][BWD-1:0] o_window,
    output logic                                       o_window_valid,
    output logic                                       o_window_end
);

/* verilator lint_off WIDTHEXPAND */
logic [K_KERNEL-1:0][N_IMAGE-1:0][BWD-1:0] space;

logic data_valid_d;
logic [$clog2(N_IMAGE)-1:0] col_cnt, 
                            row_cnt;
logic                       col_end, 
                            row_end;
assign col_end = (col_cnt == N_IMAGE-1);
assign row_end = (row_cnt == N_IMAGE-1);

logic [$clog2(K_KERNEL)-1:0] kernel_row_cnt,kernel_row_cnt_d;
logic kernel_row_end;
assign kernel_row_end  =  kernel_row_cnt == K_KERNEL-1;

//------------------------------------------------------
// Shift registers
//------------------------------------------------------
always_ff @(posedge clk) begin
    if (i_data_valid) begin
        col_cnt <= (col_end) ? '0 : col_cnt+1;
        if (col_end) begin
            row_cnt        <= (       row_end ) ? '0 :        row_cnt+1;
            kernel_row_cnt <= (kernel_row_end ) ? '0 : kernel_row_cnt+1;
        end
    end
    data_valid_d     <= i_data_valid;
    kernel_row_cnt_d <= kernel_row_cnt;
    
    if (clear) begin // We do want to drop control signals during reset
        col_cnt        <= '0;
        row_cnt        <= '0;
        kernel_row_cnt <= '0;
    end
end

always_ff @(posedge clk) begin
    if (i_data_valid) begin
        for (int i=0; i<K_KERNEL; i++) begin
            space[i] <= { space[i][N_IMAGE-2:0],    
                         ((kernel_row_cnt==i) ? i_data :  space[i][N_IMAGE-1])
                        };
        end
    end
end

//----------------------------
// Output Interface control Logic
//----------------------------
logic    row_valid;
logic    col_valid;
assign row_valid    =  (row_cnt >=  K_KERNEL-1);
assign col_valid    =  (col_cnt >=  K_KERNEL-1);

logic window_valid;
always_ff @(posedge clk) begin
    window_valid <=     col_valid 
                        &&  row_valid 
                        && data_valid_d
                        ;
    o_window_end <=     (col_cnt == N_IMAGE-1) 
                    &&  (row_cnt == N_IMAGE-1) 
                    &&   data_valid_d
                    ;
    end
//----------------------------
// Reshape values to window
//----------------------------
logic [K_KERNEL-1:0][K_KERNEL-1:0][BWD-1:0] window;
int  row_idx [K_KERNEL-1:0];
always_comb begin
    for (int i=0; i<K_KERNEL; i++) begin
        // 
        row_idx[i] = ((K_KERNEL-i)+kernel_row_cnt_d)%K_KERNEL;
        for (int j=0; j<K_KERNEL; j++) begin
            window[i][j] = space[ row_idx[i] ][j];
                                //  |          |
                                //  |        Static
                                //  |
                                // Row Select Mux
        end

    end
end 

assign o_window         = window;
assign o_window_valid   = window_valid;

endmodule
