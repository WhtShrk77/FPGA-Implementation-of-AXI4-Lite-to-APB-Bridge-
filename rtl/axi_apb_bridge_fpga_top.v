module axi_apb_bridge_fpga_top (
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
    input  wire        s_axi_rready
);

    // APB Slave Base Addresses (Internal to the module)
    localparam APB0_BASE = 32'h4000_0000; // UART
    localparam APB1_BASE = 32'h4001_0000; // GPIO
    localparam APB2_BASE = 32'h4002_0000; // SPI
    localparam APB3_BASE = 32'h4003_0000; // Timer
    localparam APB_RANGE = 32'h0001_0000;

    // ----------------------------------------------------------
    // Internal Wires for the APB Bus (from the APB Master Core)
    // ----------------------------------------------------------
    wire [31:0] master_paddr;
    wire        master_psel;
    wire        master_penable;
    wire        master_pwrite;
    wire [31:0] master_pwdata;

    // Wires for the APB slaves (prdata/pready)
    wire [31:0] apb0_prdata, apb1_prdata, apb2_prdata, apb3_prdata;
    wire        apb0_pready, apb1_pready, apb2_pready, apb3_pready;

    // Wires for the APB slaves (psel/penable outputs after decoding)
    wire        apb0_psel_o, apb1_psel_o, apb2_psel_o, apb3_psel_o;
    wire        apb0_penable_o, apb1_penable_o, apb2_penable_o, apb3_penable_o;

    // TIMING FIX: Enhanced Pipeline Registers (3-stage pipeline)
    reg [3:0]   slave_select_reg1, slave_select_reg2;
    reg [31:0]  master_prdata_reg1, master_prdata_reg2, master_prdata_reg3;
    reg         master_pready_reg1, master_pready_reg2, master_pready_reg3;
    reg [31:0]  master_paddr_reg;
    
    // FIX: Change slave_select_comb from wire to reg since it's assigned in always block
    reg [3:0]   slave_select_comb;
    
    // ----------------------------------------------------------
    // A. TIMING OPTIMIZED Address Decoding 
    // ----------------------------------------------------------

    // Pipeline Stage 1: Register address for faster decode
    always @(posedge clk) begin
        if (!resetn) begin
            master_paddr_reg <= 32'h0;
        end else if (master_psel) begin
            master_paddr_reg <= master_paddr;
        end
    end

    // Pipeline Stage 2: Optimized Address Decode (uses MSBs for speed)
    // FIX: Use always block since slave_select_comb is now reg
    always @(*) begin
        case (master_paddr_reg[19:16]) // Use MSBs for faster decode
            4'h0: slave_select_comb = 4'b0001; // APB0
            4'h1: slave_select_comb = 4'b0010; // APB1  
            4'h2: slave_select_comb = 4'b0100; // APB2
            4'h3: slave_select_comb = 4'b1000; // APB3
            default: slave_select_comb = 4'b0000;
        endcase
    end

    // Pipeline Stage 3: Register slave select
    always @(posedge clk) begin
        if (!resetn) begin
            slave_select_reg1 <= 4'b0000;
            slave_select_reg2 <= 4'b0000;
        end else begin
            slave_select_reg1 <= slave_select_comb;
            slave_select_reg2 <= slave_select_reg1;
        end
    end

    // Demultiplex PSEL and PENABLE to individual slaves (using pipelined select)
    assign apb0_psel_o    = master_psel && slave_select_reg1[0];
    assign apb0_penable_o = master_penable && apb0_psel_o;
    
    assign apb1_psel_o    = master_psel && slave_select_reg1[1];
    assign apb1_penable_o = master_penable && apb1_psel_o;

    assign apb2_psel_o    = master_psel && slave_select_reg1[2];
    assign apb2_penable_o = master_penable && apb2_psel_o;
    
    assign apb3_psel_o    = master_psel && slave_select_reg1[3];
    assign apb3_penable_o = master_penable && apb3_psel_o;

    // TIMING FIX: Multi-stage Pipeline for MUX Logic
    wire [31:0] comb_master_prdata;
    wire        comb_master_pready;
    
    // Combinational MUX (now feeds into deep pipeline)
    assign comb_master_prdata = (slave_select_reg1[0]) ? apb0_prdata :
                               (slave_select_reg1[1]) ? apb1_prdata :
                               (slave_select_reg1[2]) ? apb2_prdata :
                               (slave_select_reg1[3]) ? apb3_prdata :
                               32'hDEADBEEF;

    assign comb_master_pready = (slave_select_reg1[0]) ? apb0_pready :
                               (slave_select_reg1[1]) ? apb1_pready :
                               (slave_select_reg1[2]) ? apb2_pready :
                               (slave_select_reg1[3]) ? apb3_pready :
                               1'b1;

    // 3-Stage Pipeline for Data Path (breaks critical timing path)
    always @(posedge clk) begin
        if (!resetn) begin
            master_prdata_reg1 <= 32'h0;
            master_pready_reg1 <= 1'b0;
            master_prdata_reg2 <= 32'h0;
            master_pready_reg2 <= 1'b0;
            master_prdata_reg3 <= 32'h0;
            master_pready_reg3 <= 1'b0;
        end else begin
            // Pipeline Stage 1
            master_prdata_reg1 <= comb_master_prdata;
            master_pready_reg1 <= comb_master_pready;
            
            // Pipeline Stage 2
            master_prdata_reg2 <= master_prdata_reg1;
            master_pready_reg2 <= master_pready_reg1;
            
            // Pipeline Stage 3 (final output)
            master_prdata_reg3 <= master_prdata_reg2;
            master_pready_reg3 <= master_pready_reg2;
        end
    end
    
    // ----------------------------------------------------------
    // B. Bridge Core Instantiation
    // ----------------------------------------------------------

    axi_apb_bridge_core u_bridge_core (
        .clk(clk),
        .resetn(resetn),

        // AXI4-Lite Slave Interface
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

        // Single APB Master Interface (connects to final pipeline stage)
        .apb_paddr(master_paddr),
        .apb_psel(master_psel),
        .apb_penable(master_penable),
        .apb_pwrite(master_pwrite),
        .apb_pwdata(master_pwdata),
        .apb_prdata(master_prdata_reg3), // TIMING FIX: Use final pipeline stage
        .apb_pready(master_pready_reg3)  // TIMING FIX: Use final pipeline stage
    );
    
    // ----------------------------------------------------------
    // C. APB Slave Instantiations
    // ----------------------------------------------------------
    
    apb_slave_dummy u_uart (
        .clk(clk), .resetn(resetn), .paddr(master_paddr), .psel(apb0_psel_o), 
        .penable(apb0_penable_o), .pwrite(master_pwrite), .pwdata(master_pwdata), 
        .prdata(apb0_prdata), .pready(apb0_pready)
    );

    apb_slave_dummy u_gpio (
        .clk(clk), .resetn(resetn), .paddr(master_paddr), .psel(apb1_psel_o), 
        .penable(apb1_penable_o), .pwrite(master_pwrite), .pwdata(master_pwdata), 
        .prdata(apb1_prdata), .pready(apb1_pready)
    );

    apb_slave_dummy u_spi (
        .clk(clk), .resetn(resetn), .paddr(master_paddr), .psel(apb2_psel_o), 
        .penable(apb2_penable_o), .pwrite(master_pwrite), .pwdata(master_pwdata), 
        .prdata(apb2_prdata), .pready(apb2_pready)
    );

    apb_slave_dummy u_timer (
        .clk(clk), .resetn(resetn), .paddr(master_paddr), .psel(apb3_psel_o), 
        .penable(apb3_penable_o), .pwrite(master_pwrite), .pwdata(master_pwdata), 
        .prdata(apb3_prdata), .pready(apb3_pready)
    );

endmodule
