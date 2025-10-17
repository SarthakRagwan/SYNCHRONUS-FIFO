//-----------------------------------------------------------------------------
//
// Module: synch_fifo
//
// Description:
// A synchronous (single clock) First-In, First-Out (FIFO) buffer.
//
// Design Strategy:
// This FIFO uses read and write pointers that are one bit wider than the
// number of bits required to address the memory depth. This extra bit acts
// as a "lap counter" or "wrap-around indicator." This common technique allows
// for robust and unambiguous detection of "full" and "empty" conditions
// without needing a separate counter for the number of elements.
//
//-----------------------------------------------------------------------------
module synch_fifo(
    // --- I/O Ports ---
    clk,
    reset,
    chip_select,
    read_enable,
    write_enable,
    data_in,
    data_out,
    fifo_full,
    fifo_empty
);

//=============================================================================
// Port Declarations
//=============================================================================
input                   clk;            // System clock
input                   reset;          // Asynchronous, active-low reset
input                   chip_select;    // Module enable signal
input                   read_enable;    // Assert to read data from the FIFO
input                   write_enable;   // Assert to write data into the FIFO
input      [data_size-1:0]  data_in;        // Data to be written into the FIFO

output reg [data_size-1:0]  data_out;       // Data read from the FIFO
output                  fifo_full;      // Flag: High when FIFO is full
output                  fifo_empty;     // Flag: High when FIFO is empty

//=============================================================================
// Parameters
//=============================================================================
parameter fifo_depth = 4;   // User-configurable: Number of words the FIFO can store
parameter data_size  = 32;  // User-configurable: Width of each data word in bits

// This local parameter calculates the number of bits needed to address the memory.
// For a depth of 4, $clog2(4) = 2. So, 'address_bit' will be 2, meaning we
// need 2 bits (e.g., addr[1:0]) to represent all addresses from 0 to 3.
localparam address_bit = $clog2(fifo_depth);

//=============================================================================
// Internal Signals and Registers
//=============================================================================
// Pointers for read and write operations.
// CRITICAL: They are declared to be [address_bit:0], making them ONE BIT WIDER
// than the address itself. For a depth of 4, address_bit=2, so the pointers
// are 3 bits wide ([2:0]). The extra MSB (bit 2) acts as a wrap-around
// indicator, which is the key to distinguishing a full FIFO from an empty one.
reg [address_bit:0] read_address  = 0;
reg [address_bit:0] write_address = 0;

// This is the actual memory array (an array of registers) that stores the FIFO contents.
// It has 'fifo_depth' locations, each 'data_size' bits wide.
reg [data_size-1:0] FIFO [fifo_depth-1:0];

//=============================================================================
// Write Logic
//=============================================================================
// This block describes a synchronous process that handles write operations.
// The sensitivity list makes it trigger on a positive clock edge or a
// negative reset edge (asynchronous reset).
always @(posedge clk or negedge reset) begin
    // Asynchronous Reset Logic: If reset is low, instantly reset the write pointer.
    if (!reset) begin
        write_address <= 0;
    end
    // Synchronous Write Logic: On a positive clock edge...
    // A write occurs only if the module is selected, a write is enabled, AND the FIFO is not full.
    else if (chip_select && write_enable && !fifo_full) begin
        // Write the incoming data into the memory.
        // NOTE: We only use the lower bits of the pointer ([address_bit-1:0])
        // to form the actual memory address, as the memory depth is only 2^address_bit.
        FIFO[write_address[address_bit-1:0]] <= data_in;

        // Increment the full write pointer. The non-blocking assignment (`<=`) ensures
        // this update happens synchronously after the current clock cycle, modeling
        // the behavior of a flip-flop.
        write_address <= write_address + 1;
    end
end

//=============================================================================
// Read Logic
//=============================================================================
// This block describes the synchronous process for read operations.
// It also uses an asynchronous, active-low reset.
always @(posedge clk or negedge reset) begin
    // Asynchronous Reset Logic: Instantly reset read pointer and data output.
    if (!reset) begin
        read_address <= 0;
        data_out     <= 0; // Good practice to reset outputs to a known state.
    end
    // Synchronous Read Logic: On a positive clock edge...
    // A read occurs only if the module is selected, a read is enabled, AND the FIFO is not empty.
    else if (chip_select && read_enable && !fifo_empty) begin
        // Read data from the memory.
        // The data at the current 'read_address' is fetched. Due to this being a
        // clocked block, this value will appear on 'data_out' AFTER this clock edge
        // (i.e., there is a one-cycle read latency).
        data_out <= FIFO[read_address[address_bit-1:0]];

        // Increment the read pointer for the next read operation.
        read_address <= read_address + 1;
    end
    // This part is optional. When no read is happening, the data output is driven
    // to 'x' (unknown). For synthesis, it's often better to remove this 'else'
    // block, which causes `data_out` to hold its previous value.
    else begin
        data_out <= {data_size{1'bx}};
    end
end

//=============================================================================
// Status Logic (Full/Empty Flags)
//=============================================================================
// These continuous assignments describe the combinational logic for the status flags.

// --- Full Condition ---
// This is the core logic that leverages the wider pointers.
// The FIFO is full when the write pointer has wrapped around the memory one more
// time than the read pointer AND they are pointing to the same memory location.
// This is checked by comparing two conditions:
// 1. The MSBs of the pointers are different (`write_address[MSB] != read_address[MSB]`).
// 2. The lower address bits are the same (`write_address[LSBs] == read_address[LSBs]`).
// This expression cleverly combines both checks into one comparison.
assign fifo_full = (write_address == {~read_address[address_bit], read_address[address_bit-1:0]});

// --- Empty Condition ---
// The FIFO is empty when both pointers are exactly equal. This means every
// item that has been written has also been read.
assign fifo_empty = (read_address == write_address);

endmodule