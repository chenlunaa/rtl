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

    // 流水线暂停信号
    wire        pipeline_stall;
    // 流水线冲刷信号 (分支预测失败时冲刷 IF/ID 和 ID/EX)
    wire        pipeline_flush;

    // 取指控制信号
    reg         first_req;              // 复位后首次取指标志
    wire        id_is_ld_st;            // ID 阶段是否是访存指令
    wire        ex_is_ld_st;            // EX 阶段是否是访存指令
    wire        id_is_mul_div;          // ID 阶段是否是乘除法指令
    wire        ex_is_mul_div;          // EX 阶段是否是乘除法指令
    wire        mul_div_suspend;        // 乘除法导致的流水线暂停
    wire        mul_div_done;           // 乘除法运算完成
    wire        ex_bj_f;                // EX 阶段跳转标志
    wire [31:0] ex_bj_target;           // EX 阶段跳转目标地址

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

    wire [ 1:0] ex_npc_op;

    wire [ 2:0] ex_ram_rop;
    wire [ 3:0] ex_ram_wop;

    wire        ex_is_mul;
    wire        ex_is_div;

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
    wire        ex_br;
    wire        ex_busy;          

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
    wire [31:0] mem_pc;
    wire [31:0] mem_ext;

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
    wire [31:0] wb_pc;
    wire [31:0] wb_ext;

    // 写回数据
    reg  [31:0] wb_rf_wD;

    // =========================================================================
    // IF 阶段: 取指
    // =========================================================================
    // 首次取指标志
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst)
            first_req <= 1'b1;
        else
            first_req <= 1'b0;
    end


    // 1. 访存与乘除法的完成信号 (Done)
    wire ldst_done    = daccess_rvalid | daccess_wresp; // 读有效或写响应

    // 2. 暂停与恢复取指控制
    wire pause_ifetch  = (id_is_ld_st | ex_is_ld_st) & !ldst_done | 
                        (id_is_mul_div | ex_is_mul_div) & !mul_div_done;

    wire resume_ifetch = ldst_done | mul_div_done;

    assign ifetch_req  = !pause_ifetch & !pipeline_stall & (
                                          first_req     |    // 复位后首次取指
                                          ifetch_valid  |    // 上一条已取回，同时立即取下一条
                                          resume_ifetch |   
                                          pipeline_flush    // 静态分支预测错误，立即用正确的地址取指
                                        );   // 数据访存或乘除运算结束，继续取指
    assign ifetch_addr = if_pc;

    // NPC: 默认预测不跳转 (NPC_PC4)
    // 分支/JMP 的跳转目标在 EX 阶段才确定，预测失败时通过 flush 冲刷
    wire [31:0] npc_predict;
    NPC U_NPC (
        .op             (id_npc_op),
        .pc             (id_pc),
        .offset         (id_ext),
        .br             (1'b0),         // 静态预测: 默认不跳转
        .jalr_target    (id_rf_rd1),
        .npc            (npc_predict),
        .pc4            (if_pc4)
    );

    // EX 阶段计算正确的跳转目标 (用于预测失败时修正 PC)
    wire [31:0] ex_jmp_target;
    NPC U_NPC_EX (
        .op             (ex_npc_op),
        .pc             (ex_pc),
        .offset         (ex_ext),
        .br             (ex_br),
        .jalr_target    (ex_alu_c),
        .npc            (ex_jmp_target),
        .pc4            ()
    );

    // 预测失败时使用 EX 阶段计算的正确目标, 否则使用预测的 NPC
    reg [31:0] if_pc_q; // 保存发给 Memory 时的 PC 地址
    reg flush_q;
    assign if_npc = pipeline_flush? ex_jmp_target : (if_pc + 32'd4);

    PC U_PC (
        .clk        (cpu_clk),
        .rst        (cpu_rst),
        .npc        (if_npc),
        .fetch      (ifetch_req),
        .stall      (pipeline_stall),
        .pc         (if_pc)
    );

    // IF阶段取到的原始指令
    assign if_inst_raw = ifetch_valid ? ifetch_inst : 32'h13 /* NOP */ ;
    // =========================================================================
    // IF 阶段: 取指与地址打拍对齐
    // =========================================================================
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            if_pc_q <= 32'h0;
        end else if (pipeline_flush) begin
            if_pc_q <= ex_jmp_target;
        end else if (!pipeline_stall) begin
            // 只有在没 Stall 时，才更新发出去的 PC
            if_pc_q <= if_pc;
        end
    end
    // 1. 将 pipeline_flush 锁存一拍
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst)
            flush_q <= 1'b0;
        else
            flush_q <= pipeline_flush;
    end

    // 2. 组合逻辑：只要当前拍 Flush，或者上一拍 Flush 过（Memory 刚吐出旧指令），
    //    就把取到的指令强行替换成 NOP (0x00000013)
    wire [31:0] clean_if_inst;
    assign clean_if_inst = (pipeline_flush || flush_q) ? 32'h00000013 : if_inst_raw;

    // =========================================================================
    // IF/ID 流水寄存器
    // =========================================================================
    IF_ID_Reg U_IF_ID (
        .clk        (cpu_clk),
        .rst        (cpu_rst),
        .stall      (pipeline_stall),
        .flush      (pipeline_flush || flush_q),
        .if_pc      (if_pc_q),
        .if_pc4     (if_pc4),
        .if_inst    (clean_if_inst),
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
    // RAW 数据冒险检测 (ID 阶段)
    // =========================================================================
    // 提取 ID 阶段的 RS1/RS2 寄存器号
    wire [4:0] id_rs1 = id_inst[19:15];
    wire [4:0] id_rs2 = id_inst[24:20];

    // 推导 RS1/RS2 是否被当前指令读取
    // 利用 rf_wsel 信号判断:
    //   WB_EXT (LUI):     不读 RS1, 不读 RS2
    //   WB_PC4 (JAL/JALR): JAL 不读 RS1/RS2; JALR 读 RS1 不读 RS2
    //   其他:              R/I/S/B 型, 均读 RS1; R/S/B 型读 RS2, I 型不读 RS2
    wire is_lui  = (id_rf_wsel === `WB_EXT);
    wire is_jal  = (id_rf_wsel === `WB_PC4) & (id_alua_sel === `ALU_A_RS1) & (id_alub_sel === `ALU_B_EXT) & (id_sext_op === `EXT_J);
    wire is_jalr = (id_rf_wsel === `WB_PC4) & (id_alua_sel === `ALU_A_RS1) & (id_alub_sel === `ALU_B_EXT) & (id_sext_op === `EXT_I);

    wire id_is_store = (id_ram_wop !== `RAM_WE_N);
    wire id_rf_re1 = (id_alua_sel === `ALU_A_RS1);
    wire id_rf_re2 = (id_alub_sel === `ALU_B_RS2) | id_is_store;

    // 情形A: ID/EX 级目标寄存器与 ID 级源寄存器冲突 (相邻指令)
    // 使用 === 避免 X 态传播
    wire rs1_ex_hazard = (ex_rf_wR === id_rs1) & (ex_rf_we === 1'b1) & id_rf_re1 & (ex_rf_wR !== 5'h0);
    wire rs2_ex_hazard = (ex_rf_wR === id_rs2) & (ex_rf_we === 1'b1) & id_rf_re2 & (ex_rf_wR !== 5'h0);

    // 情形A 中需要暂停的情况: EX 级是 load 指令 (数据在 MEM 阶段才拿到)
    wire ex_is_load = (ex_rf_wsel === `WB_RAM) & ex_rf_we;
    wire rs1_ex_stall = rs1_ex_hazard & ex_is_load;
    wire rs2_ex_stall = rs2_ex_hazard & ex_is_load;

    // 情形B: EX/MEM 级目标寄存器与 ID 级源寄存器冲突 (间隔1条指令)
    wire rs1_mem_hazard = (mem_rf_wR === id_rs1) & (mem_rf_we === 1'b1) & id_rf_re1 & (mem_rf_wR !== 5'h0);
    wire rs2_mem_hazard = (mem_rf_wR === id_rs2) & (mem_rf_we === 1'b1) & id_rf_re2 & (mem_rf_wR !== 5'h0);

    // 情形C: MEM/WB 级目标寄存器与 ID 级源寄存器冲突 (间隔2条指令)
    wire rs1_wb_hazard = (wb_rf_wR === id_rs1) & (wb_rf_we === 1'b1) & id_rf_re1 & (wb_rf_wR !== 5'h0);
    wire rs2_wb_hazard = (wb_rf_wR === id_rs2) & (wb_rf_we === 1'b1) & id_rf_re2 & (wb_rf_wR !== 5'h0);

    // 流水线暂停: 综合以下情况
    //   1. load 造成的相邻 RAW 冒险 (数据在 MEM 才拿到)
    //   2. EX 阶段乘除法指令正在运算 (busy=1)
    //   3. MEM 阶段访存指令等待总线响应
    wire raw_stall   = rs1_ex_stall | rs2_ex_stall;

    wire mul_div_stall = ex_busy;                                    // 乘除法 busy 时暂停

    wire mem_req_active = (|mem_da_ren) | (|mem_da_wen);
    wire mem_req_done   = daccess_rvalid | daccess_wresp;
    wire mem_stall      = mem_req_active & !mem_req_done;
    assign pipeline_stall = raw_stall | mul_div_stall | mem_stall;

    // =========================================================================
    // 取指控制信号 (用于暂停/恢复取指)
    // =========================================================================
    // ID 阶段访存/乘除法检测
    assign id_is_ld_st   = (id_ram_rop !== `RAM_EXT_N) | (id_ram_wop !== `RAM_WE_N);
    assign id_is_mul_div = id_is_mul | id_is_div;

    // EX 阶段访存/乘除法检测
    assign ex_is_ld_st   = (ex_ram_rop !== `RAM_EXT_N) | (ex_ram_wop !== `RAM_WE_N);
    assign ex_is_mul_div = ex_is_mul | ex_is_div;

    // 乘除法暂停和完成
    assign mul_div_suspend = mul_div_stall;
    assign mul_div_done    = !ex_busy & ex_is_mul_div;

    // EX 阶段跳转标志和目标地址
    assign ex_bj_f      = pipeline_flush;
    assign ex_bj_target = ex_jmp_target;

    // =========================================================================
    // 分支预测失败检测 & 流水线冲刷 (EX 阶段)
    // =========================================================================
    // 静态预测: 默认不跳转 (br=0)
    // 冲刷条件:
    //   1. 分支指令 (NPC_BRA) 且实际跳转 (ex_br=1) → 预测失败
    //   2. JAL  (NPC_JMP)  → 无条件跳转, 需要冲刷 IF/ID 中的顺序指令
    //   3. JALR (NPC_JALR) → 无条件跳转, 需要冲刷 IF/ID 中的顺序指令
    wire ex_is_bra  = (ex_npc_op === `NPC_BRA);
    wire ex_is_jal  = (ex_npc_op === `NPC_JMP);
    wire ex_is_jalr = (ex_npc_op === `NPC_JALR);

    // 分支预测失败: 预测不跳转但实际跳转
    // 使用 === 避免 X 态误触发
    wire branch_mispredict = ex_is_bra & (ex_br === 1'b1);

    assign pipeline_flush = branch_mispredict | ex_is_jal | ex_is_jalr;

    // =========================================================================
    // 数据前递 (ID 阶段)
    // =========================================================================
    // 前递数据来源:
    //   情形A (EX):  ex_alu_c
    //   情形B (MEM): mem_rf_wsel 选择 mem_alu_c 或 mem_ram_ext 或 mem_pc4
    //   情形C (WB):  wb_rf_wD (已经是最终写回值)
    // 优先级: EX > MEM > WB

    // MEM 阶段的前递数据 (根据 mem_rf_wsel 选择)
    // 使用 === 避免 X 态传播

    // EX 阶段前递数据源选择
    wire [31:0] ex_forward_data;
    assign ex_forward_data = (ex_rf_wsel === `WB_PC4) ? ex_pc4 :
                            (ex_rf_wsel === `WB_EXT) ? ex_ext :
                            ex_alu_c; // 默认 ALU 结果

    wire [31:0] mem_forward_data;
    assign mem_forward_data = (mem_rf_wsel === `WB_ALU) ? mem_alu_c :
                              (mem_rf_wsel === `WB_RAM) ? mem_ram_ext :
                              (mem_rf_wsel === `WB_PC4) ? mem_pc4 :
                              (mem_rf_wsel === `WB_EXT) ? mem_ext :
                              32'h0;

    // RS1 前递数据选择 (优先级: EX > MEM > WB)
    wire [31:0] id_rf_rd1_forward;
    assign id_rf_rd1_forward = rs1_ex_hazard  ? ex_forward_data :
                               rs1_mem_hazard ? mem_forward_data :
                               rs1_wb_hazard  ? wb_rf_wD :
                               id_rf_rd1;

    // RS2 前递数据选择 (优先级: EX > MEM > WB)
    wire [31:0] id_rf_rd2_forward;
    assign id_rf_rd2_forward = rs2_ex_hazard  ? ex_forward_data :
                               rs2_mem_hazard ? mem_forward_data :
                               rs2_wb_hazard  ? wb_rf_wD :
                               id_rf_rd2;

    // =========================================================================
    // ID/EX 流水寄存器
    // =========================================================================
    ID_EX_Reg U_ID_EX (
        .clk            (cpu_clk),
        .rst            (cpu_rst),
        .stall          (pipeline_stall),
        .flush          (pipeline_flush),
        .id_alu_op      (id_alu_op),
        .id_alua_sel    (id_alua_sel),
        .id_alub_sel    (id_alub_sel),
        .id_npc_op      (id_npc_op),
        .id_ram_rop     (id_ram_rop),
        .id_ram_wop     (id_ram_wop),
        .id_is_mul      (id_is_mul),
        .id_is_div      (id_is_div),
        .id_rf_we       (id_rf_we),
        .id_rf_wsel     (id_rf_wsel),
        .id_rf_wR       (id_rf_wR),
        .id_pc          (id_pc),
        .id_pc4         (id_pc4),
        .id_rf_rd1      (id_rf_rd1_forward),
        .id_rf_rd2      (id_rf_rd2_forward),
        .id_ext         (id_ext),
        .ex_alu_op      (ex_alu_op),
        .ex_alua_sel    (ex_alua_sel),
        .ex_alub_sel    (ex_alub_sel),
        .ex_npc_op      (ex_npc_op),
        .ex_ram_rop     (ex_ram_rop),
        .ex_ram_wop     (ex_ram_wop),
        .ex_is_mul      (ex_is_mul),
        .ex_is_div      (ex_is_div),
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
        .br         (ex_br),
        .c          (ex_alu_c),
        .busy       (ex_busy)
    );

    // =========================================================================
    // EX/MEM 流水寄存器
    // 注意: ram_rop/ram_wop需要从ID阶段传递过来, 但ID_EX_Reg中已移除
    // 理想流水线暂不处理访存, 此处固定为NOP值
    // =========================================================================
    EX_MEM_Reg U_EX_MEM (
        .clk            (cpu_clk),
        .rst            (cpu_rst),
        .stall          (pipeline_stall),
        .ex_alu_c       (ex_alu_c),
        .ex_ram_rop     (ex_ram_rop),
        .ex_ram_wop     (ex_ram_wop),
        .ex_rf_we       (ex_rf_we),
        .ex_rf_wsel     (ex_rf_wsel),
        .ex_rf_wR       (ex_rf_wR),
        .ex_rf_rd2      (ex_rf_rd2),
        .ex_pc4         (ex_pc4),
        .ex_pc          (ex_pc),
        .ex_ext         (ex_ext),
        .mem_alu_c      (mem_alu_c),
        .mem_ram_rop    (mem_ram_rop),
        .mem_ram_wop    (mem_ram_wop),
        .mem_rf_we      (mem_rf_we),
        .mem_rf_wsel    (mem_rf_wsel),
        .mem_rf_wR      (mem_rf_wR),
        .mem_rf_rd2     (mem_rf_rd2),
        .mem_pc4        (mem_pc4),
        .mem_pc         (mem_pc),
        .mem_ext        (mem_ext)
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

    // 记录写使能是否已经发过（用于 Stall 期间强行拉低 Trace 信号）
    reg mem_we_sent;
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst)
            mem_we_sent <= 1'b0;
        else if (|daccess_wen)
            mem_we_sent <= 1'b1; // 已经发出了 1 拍，后续 Stall 期间不能再算作有效
        else if (!pipeline_stall)
            mem_we_sent <= 1'b0; // 访存结束，恢复初始状态
    end

    MEM_WB_Reg U_MEM_WB (
        .clk            (cpu_clk),
        .rst            (cpu_rst),
        .stall          (1'b0),
        .mem_ram_ext    (mem_ram_ext),
        .mem_alu_c      (mem_alu_c),
        .mem_rf_we      (mem_rf_we),
        .mem_rf_wsel    (mem_rf_wsel),
        .mem_rf_wR      (mem_rf_wR),
        .mem_pc4        (mem_pc4),
        .mem_pc         (mem_pc),
        .mem_ext        (mem_ext),
        .wb_ram_ext     (wb_ram_ext),
        .wb_alu_c       (wb_alu_c),
        .wb_rf_we       (wb_rf_we),
        .wb_rf_wsel     (wb_rf_wsel),
        .wb_rf_wR       (wb_rf_wR),
        .wb_pc4         (wb_pc4),
        .wb_pc          (wb_pc),
        .wb_ext         (wb_ext)
    );

    // =========================================================================
    // WB 阶段: 写回
    // =========================================================================
    always @(*) begin
        case (wb_rf_wsel)
            `WB_ALU : wb_rf_wD = wb_alu_c;
            `WB_RAM : wb_rf_wD = wb_ram_ext;
            `WB_PC4 : wb_rf_wD = wb_pc4;
            `WB_EXT : wb_rf_wD = wb_ext;
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
    assign debug_wb_pc    = wb_pc;
    assign debug_wb_rf_we = wb_rf_we;
    assign debug_wb_rf_wR = wb_rf_wR;
    assign debug_wb_rf_wD = wb_rf_wD;

    assign debug_mem_pc    = mem_pc;
    assign debug_mem_we    = mem_we_sent ? 4'b0 : mem_da_wen;
    assign debug_mem_waddr = mem_da_addr;
    assign debug_mem_wdata = mem_da_wdata;
`endif

endmodule
