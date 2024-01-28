/*  

Single-binary dot-product
    1. Calculate element-wise multiplication of two vectors : data & kernel
    2. Return number of ones in product vector

Binary to Integer represnetation

    1'b0    -1
    1'b1     1

Times Table:
  
    Intefer Form        Binary Form

     1 * -1 = -1        1 * 0   = 0
    -1 *  1 = -1        0 * 1   = 0
    -1 * -1 =  1        0 * 0   = 1
     1 *  1 =  1        1 * 1   = 1

     
*/

module kernel_1b_nxor#(
    parameter BW_BUS = 1
)(
    input logic [BW_BUS-1:0]             kernel,
    input logic [BW_BUS-1:0]             i_data,
    output logic [$clog2(BW_BUS+1)-1:0]  o_data
);

logic [BW_BUS-1:0] prod;
assign prod =    ~(i_data ^ kernel);
assign o_data =  $countbits(prod,'1); 
 
endmodule