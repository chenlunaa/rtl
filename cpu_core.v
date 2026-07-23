`timescale 1ns / 1ps

`include "defines.vh"

module cpu_core(
    input  wire         cpu_rst,
    input  wire         cpu_clk,

    // Instruction Fetch Interface
    output wire         ifetch_req   /* verilator public */ ,
    output wire [31:0]  ifetch_addr  /* verilator public */ ,
    input  wire         ifetch_valid /* verilator public */ ,
    input  wire [31:0]  ifetch_inst,
    
    // Data Access Interface
    output reg  [ 3:0]  daccess_ren,
    output reg  [31:0]  daccess_addr,
    input  wire         daccess_rvalid,
    input  wire [31:0]  daccess_rdata,
    output reg  [ 3:0]  daccess_wen,
    output reg  [31:0]  daccess_wdata,
    input  wire         daccess_wresp
);

    // =========================================================================
    // IF 阶段信号
    // =========================================================================
    wire [31:0] if_pc;
    wire [31:0] if_npc;
    wire [31:0] if_pc4;
    wire [31:0] if_inst_raw;

    // =========================================================================
    // ID 阶段信号 (IF/ID流水寄存器输出)
    // =========================================================================
    wire [31:0] id_pc;
    wire [31:0] id_pc4;
    wire [31:0] id_inst;

    // Controller输出
    wire [ 1:0] id_npc_op;
    wire [ 1:0] id_rf_wsel;
    wire [ 2:0] id_sext_op;
    wire [ 4:0] id_alu_op;
    wire        id_alua_sel;
    wire        id_alub_sel;
    wire [ 2:0] id_ram_rop;
    wire [ 3:0] id_ram_wop;
    wire        id_is_mul;
    wire        id_is_div;
    wire        id_rf_we;
    wire [ 4:0] id_rf_wR;

    // RF读数据
    wire [31:0] id_rf_rd1;
    wire [31:0] id_rf_rd2;

    // SEXT输出
    wire [31:0] id_ext;

    // =========================================================================
    // EX 阶段信号 (ID/EX流水寄存器输出)
    // =========================================================================
    wire [ 4:0] ex_alu_op;
    wire        ex_alua_sel;
    wire        ex_alub_sel;

    wire        ex_rf_we;
    wire [ 1:0] ex_rf_wsel;
    wire [ 4:0] ex_rf_wR;

    wire [31:0] ex_pc;
    wire [31:0] ex_pc4;
    wire [31:0] ex_rf_rd1;
    wire [31:0] ex_rf_rd2;
    wire [31:0] ex_ext;

    // ALU
    wire [31:0] ex_alu_a;
    wire [31:0] ex_alu_b;
    wire [31:0] ex_alu_c;
    wire        ex_br_dummy;            
    wire        ex_busy_dummy;          

    // =========================================================================
    // MEM 阶段信号 (EX/MEM流水寄存器输出)
    // =========================================================================
    wire [31:0] mem_alu_c;

    wire [ 2:0] mem_ram_rop;
    wire [ 3:0] mem_ram_wop;

    wire        mem_rf_we;
    wire [ 1:0] mem_rf_wsel;
    wire [ 4:0] mem_rf_wR;

    wire [31:0] mem_rf_rd2;
    wire [31:0] mem_pc4;

    // 访存
    wire [ 3:0] mem_da_ren;
    wire [31:0] mem_da_addr;
    wire [ 3:0] mem_da_wen;
    wire [31:0] mem_da_wdata;
    wire [31:0] mem_ram_ext;

    // =========================================================================
    // WB 阶段信号 (MEM/WB流水寄存器输出)
    // =========================================================================
    wire [31:0] wb_ram_ext;
    wire [31:0] wb_alu_c;

    wire        wb_rf_we;
    wire [ 1:0] wb_rf_wsel;
    wire [ 4:0] wb_rf_wR;

    wire [31:0] wb_pc4;

    // 写回数据
    reg  [31:0] wb_rf_wD;

    // =========================================================================
    // IF 阶段: 取指
    // =========================================================================
    // 理想流水线: 每个周期都取指
    assign ifetch_req  = 1'b1;
    assign ifetch_addr = if_pc;

    // 理想流水线: 固定PC+4 (不考虑分支跳转)
    assign if_npc = if_pc + 32'h4;
    assign if_pc4 = if_pc + 32'h4;

    PC U_PC (
        .clk        (cpu_clk),
        .rst        (cpu_rst),
        .npc        (if_npc),
        .fetch      (1'b1),
        .pc         (if_pc)
    );

    // IF阶段取到的原始指令
    assign if_inst_raw = ifetch_valid ? ifetch_inst : 32'h13 /* NOP */ ;

    // =========================================================================
    // IF/ID 流水寄存器
    // =========================================================================
    IF_ID_Reg U_IF_ID (
        .clk        (cpu_clk),
        .rst        (cpu_rst),
        .if_pc      (if_pc),
        .if_pc4     (if_pc4),
        .if_inst    (if_inst_raw),
        .id_pc      (id_pc),
        .id_pc4     (id_pc4),
        .id_inst    (id_inst)
    );

    // =========================================================================
    // ID 阶段: 译码
    // =========================================================================
    assign id_rf_wR = id_inst[11:7];

    Controller U_CU (
        .opcode         (id_inst[6:0]),
        .funct3         (id_inst[14:12]),
        .funct7         (id_inst[31:25]),
        .npc_op         (id_npc_op),
        .sext_op        (id_sext_op),
        .alu_op         (id_alu_op),
        .alua_sel       (id_alua_sel),
        .alub_sel       (id_alub_sel),
        .is_mul         (id_is_mul),
        .is_div         (id_is_div),
        .ram_r_op       (id_ram_rop),
        .ram_w_op       (id_ram_wop),
        .rf_we          (id_rf_we),
        .rf_wsel        (id_rf_wsel)
    );

    RF U_RF (
        .clk        (cpu_clk),
        .rR1        (id_inst[19:15]),
        .rR2        (id_inst[24:20]),
        .rD1        (id_rf_rd1),
        .rD2        (id_rf_rd2),
        .we         (wb_rf_we),
        .wR         (wb_rf_wR),
        .wD         (wb_rf_wD)
    );

    SEXT U_SEXT (
        .op         (id_sext_op),
        .imm        (id_inst[31:7]),
        .ext        (id_ext)
    );

    // =========================================================================
    // ID/EX 流水寄存器
    // =========================================================================
    ID_EX_Reg U_ID_EX (
        .clk            (cpu_clk),
        .rst            (cpu_rst),
        .id_alu_op      (id_alu_op),
        .id_alua_sel    (id_alua_sel),
        .id_alub_sel    (id_alub_sel),
        .id_rf_we       (id_rf_we),
        .id_rf_wsel     (id_rf_wsel),
        .id_rf_wR       (id_rf_wR),
        .id_pc          (id_pc),
        .id_pc4         (id_pc4),
        .id_rf_rd1      (id_rf_rd1),
        .id_rf_rd2      (id_rf_rd2),
        .id_ext         (id_ext),
        .ex_alu_op      (ex_alu_op),
        .ex_alua_sel    (ex_alua_sel),
        .ex_alub_sel    (ex_alub_sel),
        .ex_rf_we       (ex_rf_we),
        .ex_rf_wsel     (ex_rf_wsel),
        .ex_rf_wR       (ex_rf_wR),
        .ex_pc          (ex_pc),
        .ex_pc4         (ex_pc4),
        .ex_rf_rd1      (ex_rf_rd1),
        .ex_rf_rd2      (ex_rf_rd2),
        .ex_ext         (ex_ext)
    );

    // =========================================================================
    // EX 阶段: 执行
    // =========================================================================
    assign ex_alu_a = ex_alua_sel ? ex_pc      : ex_rf_rd1;
    assign ex_alu_b = ex_alub_sel ? ex_ext     : ex_rf_rd2;

    ALU U_ALU (
        .rst        (cpu_rst),
        .clk        (cpu_clk),
        .op         (ex_alu_op),
        .a          (ex_alu_a),
        .b          (ex_alu_b),
        .br         (ex_br_dummy),      // 理想流水线暂不使用
        .c          (ex_alu_c),
        .busy       (ex_busy_dummy)     // 理想流水线暂不使用
    );

    // =========================================================================
    // EX/MEM 流水寄存器
    // 注意: ram_rop/ram_wop需要从ID阶段传递过来, 但ID_EX_Reg中已移除
    // 理想流水线暂不处理访存, 此处固定为NOP值
    // =========================================================================
    EX_MEM_Reg U_EX_MEM (
        .clk            (cpu_clk),
        .rst            (cpu_rst),
        .ex_alu_c       (ex_alu_c),
        .ex_ram_rop     (`RAM_EXT_N),       // 理想流水线: 无访存
        .ex_ram_wop     (`RAM_WE_N),        // 理想流水线: 无访存
        .ex_rf_we       (ex_rf_we),
        .ex_rf_wsel     (ex_rf_wsel),
        .ex_rf_wR       (ex_rf_wR),
        .ex_rf_rd2      (ex_rf_rd2),
        .ex_pc4         (ex_pc4),
        .mem_alu_c      (mem_alu_c),
        .mem_ram_rop    (mem_ram_rop),
        .mem_ram_wop    (mem_ram_wop),
        .mem_rf_we      (mem_rf_we),
        .mem_rf_wsel    (mem_rf_wsel),
        .mem_rf_wR      (mem_rf_wR),
        .mem_rf_rd2     (mem_rf_rd2),
        .mem_pc4        (mem_pc4)
    );

    // =========================================================================
    // MEM 阶段: 访存
    // =========================================================================
    MREQ U_MEM_REQ (
        .ram_addr   (mem_alu_c),
        .ram_rop    (mem_ram_rop),
        .da_ren     (mem_da_ren),
        .da_addr    (mem_da_addr),
        .ram_wop    (mem_ram_wop),
        .ram_wdata  (mem_rf_rd2),
        .da_wen     (mem_da_wen),
        .da_wdata   (mem_da_wdata)
    );

    MEXT U_MEM_EXT (
        .op             (mem_ram_rop),
        .din            (daccess_rdata),
        .byte_offs      (mem_alu_c[1:0]),
        .ext            (mem_ram_ext)
    );

    // 总线接口
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            daccess_ren   <= 4'h0;
            daccess_wen   <= 4'h0;
        end else begin
            daccess_ren   <= mem_da_ren;
            daccess_addr  <= mem_da_addr;
            daccess_wen   <= mem_da_wen;
            daccess_wdata <= mem_da_wdata;
        end
    end

    // =========================================================================
    // MEM/WB 流水寄存器
    // =========================================================================
    MEM_WB_Reg U_MEM_WB (
        .clk            (cpu_clk),
        .rst            (cpu_rst),
        .mem_ram_ext    (mem_ram_ext),
        .mem_alu_c      (mem_alu_c),
        .mem_rf_we      (mem_rf_we),
        .mem_rf_wsel    (mem_rf_wsel),
        .mem_rf_wR      (mem_rf_wR),
        .mem_pc4        (mem_pc4),
        .wb_ram_ext     (wb_ram_ext),
        .wb_alu_c       (wb_alu_c),
        .wb_rf_we       (wb_rf_we),
        .wb_rf_wsel     (wb_rf_wsel),
        .wb_rf_wR       (wb_rf_wR),
        .wb_pc4         (wb_pc4)
    );

    // =========================================================================
    // WB 阶段: 写回
    // =========================================================================
    always @(*) begin
        case (wb_rf_wsel)
            `WB_ALU : wb_rf_wD = wb_alu_c;
            `WB_RAM : wb_rf_wD = wb_ram_ext;
            `WB_PC4 : wb_rf_wD = wb_pc4;
            `WB_EXT : wb_rf_wD = 32'h0;     // LUI需要ext, 理想流水线暂简化
            default : wb_rf_wD = 32'h0;
        endcase
    end


    /********************* Your CPU ends here *********************/

`ifdef RUN_TRACE
    wire [31:0] debug_wb_pc    /* verilator public */ ;     // WB阶段的PC
    wire        debug_wb_rf_we /* verilator public */ ;     // WB阶段的寄存器写使能
    wire [ 4:0] debug_wb_rf_wR /* verilator public */ ;     // WB阶段的目标寄存器   (若wb_rf_we为0，此项可为任意值)
    wire [31:0] debug_wb_rf_wD /* verilator public */ ;     // WB阶段写入寄存器的值 (若wb_rf_we为0，此项可为任意值)

    wire [31:0] debug_mem_pc    /* verilator public */ ;    // MEM阶段的PC
    wire [ 3:0] debug_mem_we    /* verilator public */ ;    // MEM阶段写访存时的写使能
    wire [31:0] debug_mem_waddr /* verilator public */ ;    // MEM阶段写访存时的写地址 (若mem_we为0，此项可为任意值)
    wire [31:0] debug_mem_wdata /* verilator public */ ;    // MEM阶段写访存时的写数据 (若mem_we为0，此项可为任意值)

    // 理想流水线: debug信号暂用WB/MEM阶段信号
    assign debug_wb_pc    = 32'h0;          // 理想流水线暂不追踪PC
    assign debug_wb_rf_we = wb_rf_we;
    assign debug_wb_rf_wR = wb_rf_wR;
    assign debug_wb_rf_wD = wb_rf_wD;

    assign debug_mem_pc    = 32'h0;
    assign debug_mem_we    = daccess_wen;
    assign debug_mem_waddr = daccess_addr;
    assign debug_mem_wdata = daccess_wdata;
`endif

endmodule
