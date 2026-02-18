module axi_apb_bridge_core (
    input  wire          clk,
    input  wire          resetn,

    // AXI4-Lite Slave Interface
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // Single APB Master Interface
    output wire [31:0] apb_paddr,
    output wire        apb_psel,
    output wire        apb_penable,
    output wire        apb_pwrite,
    output wire [31:0] apb_pwdata,
    input  wire [31:0] apb_prdata,
    input  wire        apb_pready
);

    // Internal signals between request converter and APB master
    wire          req_valid;
    wire          req_ready;
    wire [31:0] req_addr;
    wire [31:0] req_wdata;
    wire          req_write;
    wire [31:0] resp_rdata;
    wire          resp_done;

    // Instantiate AXI to Request Converter
    axi_to_req_converter u_axi_to_req (
        .clk(clk),
        .resetn(resetn),

        // AXI4-Lite interface
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        // Request/Response interface
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_write(req_write),
        .resp_rdata(resp_rdata),
        .resp_done(resp_done)
    );

    // Instantiate APB Master
    apb_master u_apb_master (
        .clk(clk),
        .resetn(resetn),

        // Request/Response interface
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_write(req_write),
        .resp_rdata(resp_rdata),
        .resp_done(resp_done),

        // APB bus
        .paddr(apb_paddr),
        .psel(apb_psel),
        .penable(apb_penable),
        .pwrite(apb_pwrite),
        .pwdata(apb_pwdata),
        .prdata(apb_prdata),
        .pready(apb_pready)
    );

endmodule
