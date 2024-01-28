import numpy as np
import logging
import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

def conv2d(image, kernel):
    # 2D convolution, 'valid' is the only supported mode!
    K0,K1 = kernel.shape
    N0,N1 = image.shape
    assert K0 == K1, f"Kernel must be square"
    assert N0 == N1, f"Image must be square"
    N,K = N0,K0
    # Output size
    L = N-K + 1
    prod = np.zeros([L, L])
    for i in range(L):
        for j in range(L):
            for k0 in range(K):
                for k1 in range(K):
                    prod[i][j] += image[i + k0][ j + k1] * kernel[k0][k1]
    return prod

def model_dut(image, kernel):
    """Bit-accurate model of the DUT"""
    # Conver 0,1 to -1,1
    image =   image*2  -1
    kernel = kernel*2  -1
    result = conv2d(image, kernel)
    n_max = kernel.shape[0]*kernel.shape[1]
    # Sum of -1,1 to 1's counter
    result = (result+n_max)/2
    return result 

async def send_vector(dut, data):
    """Send data to the module"""
    await RisingEdge(dut.clk)
    dut.i_data_valid.value = 1
    for val in data.flatten():
        dut.i_data.value = int(val)
        await RisingEdge(dut.clk)
    dut.i_data_valid.value = 0
    await RisingEdge(dut.clk)

async def monitor_result(dut, expected):
    """Monitor output of the model"""
    word_cnt = 0
    val_cnt  = 0
    while (True):
        await RisingEdge(dut.clk)
        if (dut.o_data_valid.value == 1):
            e,r = expected[val_cnt],int(dut.prod_sum.value)
            if e !=r :
                s = f"Recieved value {e} doesn't match expected={r}"
                cocotb.log.error(s)
                #  raise ValueError(s)
            else:
                s = f" #{val_cnt} Recieved value {e}  expected={r}"
                cocotb.log.debug(s)
            val_cnt+=1 
            
def set_kernel(dut, kernel):
    for i,val in enumerate(kernel.flatten()):
        dut.i_kernel[i].value = int(val)


@cocotb.test()
async def basic_test(dut):
    # Run Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start(start_high=False))
    # Read Constants
    N = dut.N_IMAGE.value
    K = dut.K_KERNEL.value
    BWD = dut.BWD.value
    L = N-K+1
    # Generate some random input
    if 1:
        data   = np.random.randint( (1<<BWD), size=(N,N))
        kernel = np.random.randint( (1<<BWD), size=(K,K))
    else:
        data   = np.arange( 0, N*N).reshape(N,N)%(1<<BWD)
        kernel = np.arange( 0, K*K).reshape(K,K)%(1<<BWD)


    # Emulate
    result = model_dut(data,kernel)
    # dbg
    cocotb.log.info('Image values')
    cocotb.log.info(data)
    cocotb.log.info('Kernel values')
    cocotb.log.info(kernel)
    cocotb.log.info('Expected dot-product')
    cocotb.log.info(result)
    
    # Assign Kernel Values
    set_kernel(dut, kernel)
    # Send  data and monitor result
    await cocotb.start(send_vector(dut, data))
    await cocotb.start(monitor_result(dut, result.flatten()))
    await RisingEdge(dut.window_end)
    for _ in range(2):
        await RisingEdge(dut.clk)
    assert dut.valid_cnt.value == L*L , "Something went wrong"
    await Timer(100, units="ns")  # wait a bit
