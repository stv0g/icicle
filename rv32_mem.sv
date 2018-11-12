`ifndef RV32_MEM
`define RV32_MEM

`include "rv32_branch.sv"

`define RV32_MEM_WIDTH_WORD 2'b00
`define RV32_MEM_WIDTH_HALF 2'b01
`define RV32_MEM_WIDTH_BYTE 2'b10

module rv32_mem (
    input clk,
    input reset,

`ifdef RISCV_FORMAL
    /* debug control in */
    input [4:0] rs1_in,
    input [4:0] rs2_in,

    /* debug data in */
    input [31:0] pc_in,
    input [31:0] next_pc_in,
    input [31:0] instr_in,
    input [31:0] rs1_value_in,

    /* debug control out */
    output logic [4:0] rs1_out,
    output logic [4:0] rs2_out,
    output logic [3:0] read_mask_out,
    output logic [3:0] write_mask_out,

    /* debug data out */
    output logic [31:0] pc_out,
    output logic [31:0] next_pc_out,
    output logic [31:0] instr_out,
    output logic [31:0] rs1_value_out,
    output logic [31:0] rs2_value_out,
    output logic [31:0] address_out,
    output logic [31:0] read_value_out,
    output logic [31:0] write_value_out,
`endif

    /* control in (from hazard) */
    input stall_in,
    input flush_in,

    /* control in */
    input branch_predicted_taken_in,
    input valid_in,
    input read_in,
    input write_in,
    input [1:0] width_in,
    input zero_extend_in,
    input [1:0] branch_op_in,
    input [4:0] rd_in,
    input rd_write_in,

    /* data in */
    input [31:0] result_in,
    input [31:0] rs2_value_in,
    input [31:0] branch_pc_in,

    /* data in (from data memory bus) */
    input [31:0] data_read_value_in,

    /* control out */
    output logic valid_out,
    output logic branch_mispredicted_out,
    output logic [4:0] rd_out,
    output logic rd_write_out,

    /* control out (to data memory bus) */
    output logic data_read_out,
    output logic data_write_out,
    output logic [3:0] data_write_mask_out,

    /* data out */
    output logic [31:0] rd_value_out,
    output logic [31:0] branch_pc_out,

    /* data out (to data memory bus) */
    output logic [31:0] data_address_out,
    output logic [31:0] data_write_value_out
);
    logic branch_mispredicted;

    /* branch unit */
    rv32_branch_unit branch_unit (
        /* control in */
        .predicted_taken_in(branch_predicted_taken_in),
        .op_in(branch_op_in),

        /* data in */
        .result_in(result_in),

        /* control out */
        .mispredicted_out(branch_mispredicted)
    );

    assign branch_pc_out = branch_pc_in;
    assign branch_mispredicted_out = branch_mispredicted && !flush_in;

    /* memory access unit */
    logic [31:0] read_value;
    logic [3:0] read_mask;

    assign data_read_out = read_in;
    assign data_write_out = write_in;
    assign data_address_out = result_in;

    always_comb begin
        /* write port */
        if (write_in) begin
            case (width_in)
                `RV32_MEM_WIDTH_WORD: begin
                    data_write_value_out = rs2_value_in;
                    data_write_mask_out = 4'b1111;
                end
                `RV32_MEM_WIDTH_HALF: begin
                    case (result_in[0])
                        1'b0: begin
                            data_write_value_out = {16'bx, rs2_value_in[15:0]};
                            data_write_mask_out = 4'b0011;
                        end
                        1'b1: begin
                            data_write_value_out = {rs2_value_in[15:0], 16'bx};
                            data_write_mask_out = 4'b1100;
                        end
                    endcase
                end
                `RV32_MEM_WIDTH_BYTE: begin
                    case (result_in[1:0])
                        2'b00: begin
                            data_write_value_out = {24'bx, rs2_value_in[7:0]};
                            data_write_mask_out = 4'b0001;
                        end
                        2'b01: begin
                            data_write_value_out = {16'bx, rs2_value_in[7:0], 8'bx};
                            data_write_mask_out = 4'b0010;
                        end
                        2'b10: begin
                            data_write_value_out = {8'bx, rs2_value_in[7:0], 16'bx};
                            data_write_mask_out = 4'b0100;
                        end
                        2'b11: begin
                            data_write_value_out = {rs2_value_in[7:0], 24'bx};
                            data_write_mask_out = 4'b1000;
                        end
                    endcase
                end
                default: begin
                    data_write_value_out = 32'bx;
                    data_write_mask_out = 4'bx;
                end
            endcase
        end else begin
            data_write_value_out = 32'bx;
            data_write_mask_out = 4'b0;
        end

        /* read port */
        if (read_in) begin
            case (width_in)
                `RV32_MEM_WIDTH_WORD: begin
                    read_value = data_read_value_in;
                    read_mask = 4'b1111;
                end
                `RV32_MEM_WIDTH_HALF: begin
                    case (result_in[0])
                        1'b0: begin
                            read_value = {{16{zero_extend_in ? 1'b0 : data_read_value_in[15]}}, data_read_value_in[15:0]};
                            read_mask = 4'b0011;
                        end
                        1'b1: begin
                            read_value = {{16{zero_extend_in ? 1'b0 : data_read_value_in[31]}}, data_read_value_in[31:16]};
                            read_mask = 4'b1100;
                        end
                    endcase
                end
                `RV32_MEM_WIDTH_BYTE: begin
                    case (result_in[1:0])
                        2'b00: begin
                            read_value = {{24{zero_extend_in ? 1'b0 : data_read_value_in[7]}},  data_read_value_in[7:0]};
                            read_mask = 4'b0001;
                        end
                        2'b01: begin
                            read_value = {{24{zero_extend_in ? 1'b0 : data_read_value_in[15]}}, data_read_value_in[15:8]};
                            read_mask = 4'b0010;
                        end
                        2'b10: begin
                            read_value = {{24{zero_extend_in ? 1'b0 : data_read_value_in[23]}}, data_read_value_in[23:16]};
                            read_mask = 4'b0100;
                        end
                        2'b11: begin
                            read_value = {{24{zero_extend_in ? 1'b0 : data_read_value_in[31]}}, data_read_value_in[31:24]};
                            read_mask = 4'b1000;
                        end
                    endcase
                end
                default: begin
                    read_value = 32'bx;
                    read_mask = 4'bx;
                end
            endcase
        end else begin
            read_value = 32'bx;
            read_mask = 4'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (!stall_in) begin
`ifdef RISCV_FORMAL
            pc_out <= pc_in;
            next_pc_out <= branch_mispredicted ? branch_pc_in : next_pc_in;
            rs1_out <= rs1_in;
            rs2_out <= rs2_in;
            instr_out <= instr_in;
            rs1_value_out <= rs1_value_in;
            rs2_value_out <= rs2_value_in;
            address_out <= result_in;
            read_mask_out <= read_mask;
            write_mask_out <= data_write_mask_out;
            read_value_out <= data_read_value_in;
            write_value_out <= data_write_value_out;
`endif

            valid_out <= valid_in;
            rd_out <= rd_in;
            rd_write_out <= rd_write_in;

            if (read_in)
                rd_value_out <= read_value;
            else
                rd_value_out <= result_in;

            if (flush_in) begin
                valid_out <= 0;
                rd_write_out <= 0;
            end
        end

        if (reset) begin
            valid_out <= 0;
            rd_out <= 0;
            rd_write_out <= 0;
            rd_value_out <= 0;
        end
    end
endmodule

`endif
