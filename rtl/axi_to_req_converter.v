module axi_to_req_converter (
    input  wire          clk,
    input  wire          resetn,
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg          s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg          s_axi_wready,
    output reg  [1:0]  s_axi_bresp,
    output reg          s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg          s_axi_arready,
    output reg [31:0]  s_axi_rdata,
    output reg [1:0]   s_axi_rresp,
    output reg          s_axi_rvalid,
    input  wire        s_axi_rready,
    output reg          req_valid,
    input  wire          req_ready,
    output reg [31:0]  req_addr,
    output reg [31:0]  req_wdata,
    output reg          req_write,
    input  wire [31:0] resp_rdata,
    input  wire          resp_done
);

    // Keep your original states
    localparam IDLE         = 7'b0000001;
    localparam WRITE_REQ    = 7'b0000010;
    localparam WRITE_WAIT   = 7'b0000100;
    localparam WRITE_RESP   = 7'b0001000;
    localparam READ_REQ     = 7'b0010000;
    localparam READ_WAIT    = 7'b0100000;
    localparam READ_RESP    = 7'b1000000;

    (* FSM_ENCODING = "ONE_HOT" *) reg [6:0] state, next_state;

    // TIMING FIX: Add action pipeline registers
    reg        do_aw_ready, do_w_ready, do_ar_ready;
    reg        do_req_valid, do_b_valid, do_r_valid;
    reg [31:0] stored_addr, stored_wdata, stored_rdata;
    reg        stored_write;
    reg [31:0] resp_rdata_reg;
    reg        resp_done_reg;

    // Pipeline response signals
    always @(posedge clk) begin
        if (!resetn) begin
            resp_rdata_reg <= 32'h0;
            resp_done_reg <= 1'b0;
        end else begin
            resp_rdata_reg <= resp_rdata;
            resp_done_reg <= resp_done;
        end
    end

    // State register
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // STAGE 1: FSM Logic (simplified - just decides actions)
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            do_aw_ready <= 1'b0;
            do_w_ready <= 1'b0;
            do_ar_ready <= 1'b0;
            do_req_valid <= 1'b0;
            do_b_valid <= 1'b0;
            do_r_valid <= 1'b0;
            stored_addr <= 32'h0;
            stored_wdata <= 32'h0;
            stored_rdata <= 32'h0;
            stored_write <= 1'b0;
        end else begin
            // Default - clear all actions
            do_aw_ready <= 1'b0;
            do_w_ready <= 1'b0;
            do_ar_ready <= 1'b0;

            case (state)
                IDLE: begin
                    do_req_valid <= 1'b0;
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        do_aw_ready <= 1'b1;
                        do_w_ready <= 1'b1;
                        stored_addr <= s_axi_awaddr;
                        stored_wdata <= s_axi_wdata;
                        stored_write <= 1'b1;
                    end else if (s_axi_arvalid) begin
                        do_ar_ready <= 1'b1;
                        stored_addr <= s_axi_araddr;
                        stored_write <= 1'b0;
                    end
                end

                WRITE_REQ, READ_REQ: begin
                    do_req_valid <= 1'b1;
                end

                WRITE_WAIT: begin
                    do_req_valid <= 1'b0;
                    if (resp_done_reg) begin
                        do_b_valid <= 1'b1;
                    end
                end

                WRITE_RESP: begin
                    if (s_axi_bready) begin
                        do_b_valid <= 1'b0;
                    end
                end

                READ_WAIT: begin
                    do_req_valid <= 1'b0;
                    if (resp_done_reg) begin
                        do_r_valid <= 1'b1;
                        stored_rdata <= resp_rdata_reg;
                    end
                end

                READ_RESP: begin
                    if (s_axi_rready) begin
                        do_r_valid <= 1'b0;
                    end
                end

                default: begin
                    do_req_valid <= 1'b0;
                    do_b_valid <= 1'b0;
                    do_r_valid <= 1'b0;
                end
            endcase
        end
    end

    // STAGE 2: Output Logic (simple assignments - breaks timing paths)
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready <= 1'b0;
            s_axi_arready <= 1'b0;
            s_axi_bresp <= 2'b00;
            s_axi_bvalid <= 1'b0;
            s_axi_rdata <= 32'h0;
            s_axi_rresp <= 2'b00;
            s_axi_rvalid <= 1'b0;
            req_valid <= 1'b0;
            req_addr <= 32'h0;
            req_wdata <= 32'h0;
            req_write <= 1'b0;
        end else begin
            // Simple register transfers (fast timing)
            s_axi_awready <= do_aw_ready;
            s_axi_wready <= do_w_ready;
            s_axi_arready <= do_ar_ready;
            req_valid <= do_req_valid;
            s_axi_bvalid <= do_b_valid;
            s_axi_rvalid <= do_r_valid;
            
            // Data assignments
            req_addr <= stored_addr;
            req_wdata <= stored_wdata;
            req_write <= stored_write;
            s_axi_rdata <= stored_rdata;
            
            // Fixed responses
            s_axi_bresp <= 2'b00;
            s_axi_rresp <= 2'b00;
        end
    end

    // Next state logic (kept original)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (s_axi_awvalid && s_axi_wvalid) begin
                    next_state = WRITE_REQ;
                end else if (s_axi_arvalid) begin
                    next_state = READ_REQ;
                end
            end
            WRITE_REQ: begin
                if (req_ready) begin
                    next_state = WRITE_WAIT;
                end
            end
            WRITE_WAIT: begin
                if (resp_done_reg) begin
                    next_state = WRITE_RESP;
                end
            end
            WRITE_RESP: begin
                if (s_axi_bready) begin
                    next_state = IDLE;
                end
            end
            READ_REQ: begin
                if (req_ready) begin
                    next_state = READ_WAIT;
                end
            end
            READ_WAIT: begin
                if (resp_done_reg) begin
                    next_state = READ_RESP;
                end
            end
            READ_RESP: begin
                if (s_axi_rready) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
