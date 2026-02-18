module apb_master(
    input wire clk,
    input wire resetn,

    // APB Bus Outputs
    output wire [31:0] paddr,
    output wire psel,
    output wire penable,
    output wire pwrite,
    output wire [31:0] pwdata,

    // APB Bus Inputs
    input wire [31:0] prdata,
    input wire pready,
    
    // Request/Response Interface
    input wire req_valid,
    output wire req_ready,
    input wire [31:0] req_addr,
    input wire [31:0] req_wdata,
    input wire req_write,
    output wire [31:0] resp_rdata,
    output wire resp_done
);
    
    // TIMING FIX: Enhanced pipeline registers
    reg [31:0] addr_reg, wdata_reg;
    reg write_reg;
    reg [31:0] resp_rdata_reg1, resp_rdata_reg2;
    reg resp_done_reg1, resp_done_reg2;
    
    // TIMING FIX: Correct One-Hot FSM Encoding
    localparam IDLE    = 3'b001;
    localparam SETUP   = 3'b010;
    localparam ACCESS  = 3'b100;

    (* FSM_ENCODING = "ONE_HOT" *) reg [2:0] state, next_state;

    // State Register and Request Registering
    always @(posedge clk) begin
        if (!resetn) begin
            state <= IDLE;
            addr_reg <= 32'h0;
            wdata_reg <= 32'h0;
            write_reg <= 1'b0;
        end else begin
            state <= next_state;
            if(state == IDLE && req_valid && req_ready) begin
                addr_reg <= req_addr;
                wdata_reg <= req_wdata;
                write_reg <= req_write;
            end
        end
    end

    // TIMING FIX: Pipeline response data
    always @(posedge clk) begin
        if (!resetn) begin
            resp_rdata_reg1 <= 32'h0;
            resp_done_reg1 <= 1'b0;
            resp_rdata_reg2 <= 32'h0;
            resp_done_reg2 <= 1'b0;
        end else begin
            // Stage 1
            resp_rdata_reg1 <= prdata;
            resp_done_reg1 <= (state == ACCESS && pready);
            // Stage 2
            resp_rdata_reg2 <= resp_rdata_reg1;
            resp_done_reg2 <= resp_done_reg1;
        end
    end

    // Next State Logic (Combinational)
    always @(*) begin
        next_state = state;
        case(state)
            IDLE:   if(req_valid && req_ready) next_state = SETUP;
            SETUP:  next_state = ACCESS;
            ACCESS: if(pready) next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Interface and APB Bus Assignments
    assign req_ready  = (state == IDLE);
    
    assign paddr      = addr_reg;
    assign pwdata     = wdata_reg;
    assign pwrite     = write_reg;
    assign psel       = (state != IDLE);
    assign penable    = (state == ACCESS);
    
    // TIMING FIX: Use pipelined response signals
    assign resp_rdata = resp_rdata_reg2;
    assign resp_done  = resp_done_reg2;
    
endmodule
