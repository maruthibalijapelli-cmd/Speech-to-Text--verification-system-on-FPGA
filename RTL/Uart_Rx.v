`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_rx
//////////////////////////////////////////////////////////////////////////////////
module uart_rx #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter BAUD_RATE   = 115200
)(
    input            clk,
    input            rx,
    output reg       rx_done = 1'b0,
    output reg [7:0] rx_data = 8'd0
);
    localparam integer BAUD_DIV = CLK_FREQ_HZ / BAUD_RATE;   // clk cycles per bit

    reg [1:0] state, next_state;

    parameter S_IDLE  = 2'b00,   // waiting for start bit (rx == 0)
              S_START = 2'b01,   // confirming start bit at bit-center
              S_DATA  = 2'b10,   // sampling 8 data bits
              S_STOP  = 2'b11;   // waiting out the stop bit

    reg [13:0] baud_cnt = 14'd0;
    reg [2:0]  bit_idx  = 3'd0;
    reg [7:0]  rx_byte  = 8'd0;

    wire cnt_done  = (baud_cnt == BAUD_DIV-1);
    wire half_done = (baud_cnt == (BAUD_DIV/2));

    always @(posedge clk) begin
        state <= next_state;
    end

    always @(*) begin
        case (state)
            S_IDLE:  next_state = (rx == 1'b0) ? S_START : S_IDLE;
            S_START: next_state = (half_done) ? S_DATA  : S_START;
            S_DATA:  next_state = (cnt_done && bit_idx == 3'd7) ? S_STOP : S_DATA;
            S_STOP:  next_state = (cnt_done) ? S_IDLE  : S_STOP;
            default: next_state = S_IDLE;
        endcase
    end

    always @(posedge clk) begin
        case (state)
            S_IDLE: begin
                baud_cnt <= 14'd0;
                bit_idx  <= 3'd0;
            end
            S_START: baud_cnt <= (half_done) ? 14'd0 : baud_cnt + 1'b1;
            S_DATA: begin
                if (cnt_done) begin
                    baud_cnt        <= 14'd0;
                    rx_byte[bit_idx] <= rx;
                    if (bit_idx != 3'd7)
                        bit_idx <= bit_idx + 1'b1;
                end else
                    baud_cnt <= baud_cnt + 1'b1;
            end
            S_STOP:  baud_cnt <= (cnt_done) ? 14'd0 : baud_cnt + 1'b1;
            default: baud_cnt <= 14'd0;
        endcase
    end

    always @(posedge clk) begin
        rx_done <= 1'b0;
        case (state)
            S_STOP: if (cnt_done) begin
                rx_data <= rx_byte;
                rx_done <= 1'b1;
            end
            default: ;
        endcase
    end

endmodule