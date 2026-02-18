module apb_slave_dummy (
    input  wire        clk,
    input  wire        resetn,
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready
);
    
    // TIMING FIX: Register-based implementation for better timing
    reg [31:0] internal_register;
    reg [31:0] prdata_reg;

    // Write Logic (Registered)
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            internal_register <= 32'h0;
        end else if (psel && penable && pwrite) begin
            internal_register <= pwdata;
        end
    end

    // TIMING FIX: Registered read logic
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            prdata_reg <= 32'hDEADBEEF;
        end else if (psel && !penable && !pwrite) begin
            // Register data during SETUP phase for timing
            prdata_reg <= internal_register;
        end
    end

    // Output assignment
    always @(*) begin
        if (psel && !pwrite) begin
            prdata = prdata_reg;
        end else begin
            prdata = 32'hDEADBEEF;
        end
    end

    // Always ready for single cycle operation
    assign pready = psel;
    
endmodule
