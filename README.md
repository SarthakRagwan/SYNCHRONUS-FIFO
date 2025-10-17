# SYNCHRONUS-FIFO
A synthesizable, parameterized synchronous First-In-First-Out (FIFO) buffer designed in Verilog. This project includes a comprehensive testbench to verify correct functionality across various operational scenarios, making it a robust and reusable IP block.

📖 Description
This FIFO is designed using a standard synchronous methodology. It uses read and write pointers that are one bit wider than the address space, allowing for robust and unambiguous detection of full and empty conditions. The design is fully parameterized for data width and FIFO depth, making it easily adaptable for various applications.

✨ Key Features
Parameterized: Easily configure DATA_WIDTH and FIFO_DEPTH to fit any design requirement.
Synchronous Design: Operates on a single clock with an active-low asynchronous reset, ensuring predictable behavior in synchronous systems.
Robust Status Flags: Implements reliable fifo_full and fifo_empty logic using the industry-standard one-bit wider pointer method.
Comprehensive Verification: Includes a task-based testbench that verifies:
Basic read/write operations
Interleaved reads and writes
Corner cases (writing when full, reading when empty)

🧠 Theory of Operation
This section details the design principles behind the synchronous FIFO, focusing on the method used for status detection.

The Challenge: Distinguishing Full vs. Empty
A simple FIFO could use read and write pointers with a width of $clog2(DEPTH). However, this leads to a critical ambiguity:
When the FIFO is empty, read_ptr == write_ptr.
After the FIFO is filled, the write pointer wraps around and once again becomes equal to the read pointer, read_ptr == write_ptr.
Without additional logic, it's impossible to tell if the pointers are equal because the FIFO is empty or because it's full.

The Solution: One-Bit Wider Pointers
To solve this, we make the pointers one bit wider than the address bus. For a FIFO of depth 4, the address is 2 bits ([1:0]), so our pointers become 3 bits ([2:0]). This extra Most Significant Bit (MSB) acts as a "lap counter" or a "wrap-around indicator", keeping track of how many times the pointer has cycled through the entire memory space.

Empty Condition
The FIFO is considered empty only when the pointers are exactly identical in every bit. This signifies that the write pointer has not advanced past the read pointer.
Verilog Code:
assign fifo_empty = (read_address == write_address);

Full Condition
The FIFO is full when the write pointer has wrapped around the memory one full "lap" ahead of the read pointer. This state is detected when the MSBs (lap counters) are different, but the lower address bits are the same.
Verilog Code;
assign fifo_full = (write_address == {~read_address[address_bit], read_address[address_bit-1:0]});

Read Latency
This FIFO has a read latency of 1. When a read is requested on a clock edge, the corresponding data becomes available on the data_out port on the next clock edge. The included testbench is designed to correctly handle this latency.

📈 Example Waveform

<img width="1818" height="348" alt="Screenshot (358)" src="https://github.com/user-attachments/assets/53f58490-667e-461d-8c4a-e5102a0d1001" />

