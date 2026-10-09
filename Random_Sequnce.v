`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Arnav Gupta
// Date: 10/27/2025
// Description: Non-sequential 4-bit counter displayed on 8 multiplexed 7-seg digits
// Sequence: 2,6,B,3,E,C,F,5
// Feature: Random “haunted” flashing when full 8-digit sequence shown
//////////////////////////////////////////////////////////////////////////////////

module Lab6_Comp(
    input CLK,       // 100 MHz system clock
    input BTNC,      // Center button to start sequence (active high)
    output [7:0] SSEG_CA,
    output [7:0] SSEG_AN
    );

    // ---------------- Parameters ----------------
    parameter CLK_1HZ_DIV = 50000000;  // 100MHz / 1Hz
    parameter CLK_MUX_DIV = 10000;     // ~5kHz multiplex
    parameter FLASH_DIV   = 2500000;   // ~20Hz flash tick (adjust for effect)
    
    // ---------------- Signals ----------------
    wire Clk_Slow, Clk_Multi;
    reg [2:0] idx;
    reg [3:0] counter;
    reg seq_done;
    reg pending_last;
    reg [7:0] Sarray [0:7];
    wire [63:0] Pass_Array;
    integer j;

    // ---------------- Sequence ----------------
    reg [3:0] seq [0:7];
    initial begin
        seq[0] = 4'h2;
        seq[1] = 4'h6;
        seq[2] = 4'hb;
        seq[3] = 4'h3;
        seq[4] = 4'he;
        seq[5] = 4'hc;
        seq[6] = 4'hf;
        seq[7] = 4'h5;
    end

    // ---------------- Clock Divider ----------------
    Clk_Divide #(CLK_1HZ_DIV, CLK_MUX_DIV) clkdiv(CLK, Clk_Slow, Clk_Multi);

    // ---------------- Sequence FSM ----------------
    always @(posedge Clk_Slow or posedge BTNC) begin
        if (BTNC) begin
            idx <= 3'b000;
            counter <= seq[0];
            seq_done <= 1'b0;
            pending_last <= 1'b0;
        end
        else if (~seq_done) begin
            counter <= seq[idx];
            if (idx < 3'd7) idx <= idx + 1;
            else begin
                if (!pending_last) pending_last <= 1'b1;
                else seq_done <= 1'b1;
            end
        end
    end

    // ---------------- Random Flash Generator ? ----------------
    reg [15:0] lfsr = 16'hACE1;     // LFSR seed
    reg [23:0] flash_counter = 0;
    reg flash_on = 0;
    wire flash_clk;

    // generate slow “flash tick” (~20Hz)
    reg [31:0] flash_div = 0;
    always @(posedge CLK) begin
        flash_div <= flash_div + 1;
        if (flash_div >= FLASH_DIV) begin
            flash_div <= 0;
            flash_counter <= flash_counter + 1;
            // LFSR for pseudo-random pattern
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            // Randomly toggle flash_on when sequence complete
            if (seq_done) begin
                if (lfsr[3:0] == 4'b0001) flash_on <= ~flash_on; // rare random toggle
            end
            else flash_on <= 0;
        end
    end

    // ---------------- Sarray mapping ----------------
    always @(*) begin
        for(j=0;j<8;j=j+1)
            Sarray[j] = 8'hFF; // blank default
        
        if (~seq_done) begin
            // phase 1: binary + hex
            Sarray[7] = 8'hFF;
            Sarray[6] = 8'hFF;
            Sarray[5] = 8'hFF;
            Sarray[4] = Digit2Seg(counter);
            Sarray[3] = Digit2Seg({3'b000, counter[3]});
            Sarray[2] = Digit2Seg({3'b000, counter[2]});
            Sarray[1] = Digit2Seg({3'b000, counter[1]});
            Sarray[0] = Digit2Seg({3'b000, counter[0]});
        end
        else begin
            // phase 2: full 8-digit sequence (haunted flash)
            if (flash_on) begin
                // spooky flicker — blank all digits sometimes
                for(j=0;j<8;j=j+1)
                    Sarray[j] = 8'hFF;
            end
            else begin
                Sarray[7] = Digit2Seg(seq[0]);
                Sarray[6] = Digit2Seg(seq[1]);
                Sarray[5] = Digit2Seg(seq[2]);
                Sarray[4] = Digit2Seg(seq[3]);
                Sarray[3] = Digit2Seg(seq[4]);
                Sarray[2] = Digit2Seg(seq[5]);
                Sarray[1] = Digit2Seg(seq[6]);
                Sarray[0] = Digit2Seg(seq[7]);
            end
        end
    end

    assign Pass_Array = {Sarray[0],Sarray[1],Sarray[2],Sarray[3],
                         Sarray[4],Sarray[5],Sarray[6],Sarray[7]};
    
    // ---------------- Display Multiplexer ----------------
    Display_Digit display(Pass_Array, Clk_Multi, SSEG_CA, SSEG_AN);

    // ---------------- Digit2Seg ----------------
    function [7:0] Digit2Seg;
        input [3:0] digit;
        begin
            case(digit)
                4'h0: Digit2Seg=8'b11000000;
                4'h1: Digit2Seg=8'b11111001;
                4'h2: Digit2Seg=8'b10100100;
                4'h3: Digit2Seg=8'b10110000;
                4'h4: Digit2Seg=8'b10011001;
                4'h5: Digit2Seg=8'b10010010;
                4'h6: Digit2Seg=8'b10000010;
                4'h7: Digit2Seg=8'b11111000;
                4'h8: Digit2Seg=8'b10000000;
                4'h9: Digit2Seg=8'b10010000;
                4'hA: Digit2Seg=8'b10001000;
                4'hB: Digit2Seg=8'b10000011;
                4'hC: Digit2Seg=8'b11000110;
                4'hD: Digit2Seg=8'b10100001;
                4'hE: Digit2Seg=8'b10000110;
                4'hF: Digit2Seg=8'b10001110;
                default: Digit2Seg=8'hFF;
            endcase
        end
    endfunction

endmodule


// ================= Clock Divider =================
module Clk_Divide #(parameter size1=50000000, size2=10000)(
    input Clk,
    output reg Clk_Slow,
    output reg Clk_multi
    );
    reg [31:0] counter1, counter2;
    initial begin
        counter1=0; counter2=0;
        Clk_Slow=0; Clk_multi=0;
    end
    always @(posedge Clk) begin
        counter1 <= counter1 + 1;
        counter2 <= counter2 + 1;
        if(counter1 >= size1) begin
            counter1 <= 0;
            Clk_Slow <= ~Clk_Slow;
        end
        if(counter2 >= size2) begin
            counter2 <= 0;
            Clk_multi <= ~Clk_multi;
        end
    end
endmodule


// ================= Display Multiplexer =================
module Display_Digit(
    input [63:0] Parray,
    input Clk,
    output reg [7:0] Segments,
    output reg [7:0] AN
    );
    reg [2:0] i;
    wire [7:0] Cath [0:7];
    assign {Cath[0],Cath[1],Cath[2],Cath[3],Cath[4],Cath[5],Cath[6],Cath[7]} = Parray;

    initial i=0;
    always @(posedge Clk) begin
        case(i)
            3'd0: begin AN=~8'b00000001; Segments=Cath[0]; end
            3'd1: begin AN=~8'b00000010; Segments=Cath[1]; end
            3'd2: begin AN=~8'b00000100; Segments=Cath[2]; end
            3'd3: begin AN=~8'b00001000; Segments=Cath[3]; end
            3'd4: begin AN=~8'b00010000; Segments=Cath[4]; end
            3'd5: begin AN=~8'b00100000; Segments=Cath[5]; end
            3'd6: begin AN=~8'b01000000; Segments=Cath[6]; end
            3'd7: begin AN=~8'b10000000; Segments=Cath[7]; end
            default: begin AN=~8'b00000000; Segments=8'hFF; end
        endcase
        i = i + 1;
        if(i>7) i=0;
    end
endmodule
