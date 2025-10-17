//-----------------------------------------------------------------------------
//
// Testbench: test
//
// Description:
// This is a comprehensive testbench for the 'synch_fifo' module. It is
// designed to verify the FIFO's functionality by simulating various
// operational scenarios, including basic reads/writes, corner cases like
// full and empty conditions, and interleaved operations.
//
// The testbench operates by:
// 1. Instantiating the FIFO module (the "Device Under Test" or DUT).
// 2. Generating a clock and reset signal.
// 3. Driving the DUT's inputs using a series of procedural tasks (`read`, `write`).
// 4. Monitoring the DUT's outputs to verify correct behavior.
// 5. Dumping waveforms to a .vcd file for visual debugging.
//
//-----------------------------------------------------------------------------

// Defines the simulation time unit (1ps) and precision (1ps).
`timescale 1ps/1ps
// Includes the Verilog file containing the FIFO design itself.
`include "main.v"

module test();

//=============================================================================
// Parameters and Signals
//=============================================================================
// Parameters should match the DUT's parameters for a consistent test.
parameter fifo_depth = 4;
parameter data_size  = 32;

// --- Testbench Signal Declarations ---
// `reg` types are used for signals that will be driven *by* the testbench
// onto the DUT's inputs (e.g., clock, reset, data_in).
reg clk, reset, chip_select, read_enable, write_enable;
reg [data_size-1:0] data_in;

// `wire` types are used for signals that are driven *by* the DUT. The
// testbench only monitors these output signals.
wire [data_size-1:0] data_out;
wire fifo_full, fifo_empty;

// Local parameter for sizing internal testbench registers correctly.
localparam address_bits = $clog2(fifo_depth);

//=============================================================================
// DUT (Device Under Test) Instantiation
//=============================================================================
// This creates an instance of the synchronous FIFO, connecting the testbench's
// `reg` and `wire` signals to the corresponding input and output ports of the DUT.
synch_fifo dut (
    .clk(clk),
    .reset(reset),
    .chip_select(chip_select),
    .read_enable(read_enable),
    .write_enable(write_enable),
    .data_in(data_in),
    .data_out(data_out),
    .fifo_full(fifo_full),
    .fifo_empty(fifo_empty)
);

//=============================================================================
// Clock and Reset Generation
//=============================================================================
// This `always` block generates a continuous clock signal with a 10ps period.
// It works by pausing for 5ps, then inverting the clock signal, creating a loop.
always #5 clk = ~clk;

// This `initial` block runs only once at the start of the simulation.
// It sets the initial values for all control signals and applies a brief
// active-low reset pulse to initialize the DUT.
initial begin
    clk          = 1'b0;
    chip_select  = 1'b0;
    read_enable  = 1'b0;
    write_enable = 1'b0;
    reset        = 1'b0; // Assert reset (active low)
    #2 reset     = 1;    // De-assert reset after 2ps
end

//=============================================================================
// Simulation Control and Waveform Dumping
//=============================================================================
// This block sets up the waveform dump file (.vcd) for visual analysis
// in tools like GTKWave. It also stops the simulation after 2000ps.
initial begin
    $dumpfile("test.vcd");
    $dumpvars(0, test); // Dump all signals within the 'test' module
    #2000 $finish;
end

integer i;

//=============================================================================
// Reusable Tasks for FIFO Interaction
//=============================================================================

// --- Write Task ---
// This task simulates a single-cycle write operation. It waits for a clock
// edge, drives the control signals and data, and then de-asserts the write
// signal to create a clean one-cycle pulse.
task write(input [data_size-1:0] data);
begin
    // Wait for the next positive clock edge to begin the operation.
    @(posedge clk) begin
        chip_select  = 1'b1;
        write_enable = 1'b1; // Assert write signal
        data_in      = data;   // Drive the data onto the bus

        // Log the action to the console for monitoring.
        if (!fifo_full)
            $display($time, " : W : FIFO[%2d] : %d", dut.write_address % fifo_depth, data_in);
        else
            $display($time, " : W : FIFO[%2d] :     FIFO FULL", dut.write_address % fifo_depth);

        // By waiting a tiny amount (#1) and then de-asserting the signal, we
        // ensure `write_enable` is high for exactly one clock cycle.
        #1 write_enable = 1'b0;
    end
end
endtask

// --- Read Task ---
// This task simulates a complete read operation. It is a TWO-CYCLE task because
// of the DUT's one-cycle read latency (data appears one cycle after the request).

// These registers are crucial for correctly logging the read operation. They
// "capture" the state of the FIFO at the moment of the request.
reg [address_bits:0] address_used;
reg                  fifo_was_empty;

task read();
begin
    // --- CYCLE 1: The Read Request ---
    // Wait for a clock edge to start the request.
    @(posedge clk) begin
        chip_select  = 1'b1;
        read_enable  = 1'b1; // Assert the read signal

        // CRITICAL: Capture the current read address and empty status.
        // We do this because by the next cycle (when the data arrives), the
        // DUT's internal read_address will have already been incremented and
        // the fifo_empty flag might have changed. This is our "bookmark".
        address_used   = dut.read_address;
        fifo_was_empty = fifo_empty;
    end

    // --- CYCLE 2: Receive and Verify Data ---
    // Wait for the next clock edge, by which time the data is valid on data_out.
    @(posedge clk) begin
        // Use the CAPTURED status (`fifo_was_empty`) to check if the read was valid.
        // This avoids the race condition where the FIFO becomes empty in the same
        // cycle that the last piece of data is read out.
        if(!fifo_was_empty)
            $display($time, " : R : FIFO[%2d] : %d", address_used % fifo_depth, data_out);
        else
            $display($time, " : R : FIFO[%2d] :     FIFO EMPTY", address_used % fifo_depth);

        // De-assert the read signal to complete the one-cycle read pulse.
        chip_select  = 1'b1;
        read_enable  = 1'b0;
    end
end
endtask

//=============================================================================
// Main Test Sequence
//=============================================================================
// This is the main "script" for the testbench. It calls the read/write tasks
// in a specific order to execute a series of targeted tests.
initial begin
    $display("TEST 1 : Basic write and read");
    write(1);
    write(10);
    write(100);
    read();
    read();
    read();

    $display("TEST 2 : Interleaved write and read");
    for (i = 0; i < fifo_depth; i = i + 1) begin
        write(2**i);
        read();
    end

    $display("TEST 3 : Full write then full read");
    for (i = 0; i < fifo_depth; i = i + 1) begin
        write(2**i);
    end
    for (i = 0; i < fifo_depth; i = i + 1) begin
        read();
    end

    $display("TEST 4 : Extra write on full FIFO");
    for (i = 0; i < fifo_depth; i = i + 1) begin
        write(2**i);
    end
    write(16); // This write should be ignored by the DUT because it's full.
    for (i = 0; i < fifo_depth; i = i + 1) begin
        read();
    end

    $display("TEST 4 : Extra reads on empty FIFO");
    read(); // This read should show "FIFO EMPTY"

    // The tests below were modified to use the single-cycle write task properly.
    $display("TEST 5 : Continuous writes with delay");
    chip_select  = 1'b1;
    for (i = 0; i < fifo_depth; i = i + 1) begin
        write(i**2);
        #10; // Add delay between writes
    end

    $display("TEST 6 : Continuous reads with delay");
    for (i = 0; i < fifo_depth; i = i + 1) begin
        #10;
        read();
    end

    $display("TEST 7 : Single write after empty");
    write(55);

    $display("TEST 8 : Read shortly after write");
    read();

end

endmodule