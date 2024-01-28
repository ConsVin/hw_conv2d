
module window_buffer#(
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
//------------------------------------------------------
// Shift registers
//------------------------------------------------------
always_ff @(posedge clk) begin
    data_valid_d <= i_data_valid;
    
    //------------------------------------------------------
    if (i_data_valid) begin
        col_cnt <= (col_end) ? '0 : col_cnt+1;

        row_cnt <= (row_end && col_end) ? '0 :
                              (col_end) ? row_cnt+1 : row_cnt;

        space[0] <= {space[0][N_IMAGE-2:0], i_data};
        for (int i=1; i<K_KERNEL; i++) begin
            if (col_cnt == 0) 
                space[i] <= {space[i-1][N_IMAGE-2:0], space[i-1][N_IMAGE-1]};
            else 
                space[i] <= {space[i][N_IMAGE-2:0],     space[i][N_IMAGE-1]};    
        end
    end
    //------------------------------------------------------
    if (clear) begin
        col_cnt      <= '0;
        row_cnt      <= '0;
        data_valid_d <= '0;
    end
end


logic    row_valid;
logic    col_valid;
assign row_valid    =  (row_cnt >=  K_KERNEL-1);
assign col_valid    =  (col_cnt >=  K_KERNEL-1);

logic window_valid;
always_ff @(posedge clk) begin
    window_valid <=
           col_valid 
        &&  row_valid 
        && data_valid_d
        ;
    o_window_end <= (col_cnt == N_IMAGE-1) && (row_cnt == N_IMAGE-1) && data_valid_d;
    end

// Reshape
logic [K_KERNEL-1:0][K_KERNEL-1:0][BWD-1:0] window;
always_comb begin
    for (int i=0; i<K_KERNEL; i++) begin
        for (int j=0; j<K_KERNEL; j++) begin
            window[i][j] = space[i][j];
        end
    end
end 

assign o_window         = window;
assign o_window_valid   = window_valid;

endmodule
