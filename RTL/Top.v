module top(

    input clk,
    input UART_rxd,
    output UART_txd

);

wire rx_done;
wire [7:0] rx_data;

reg tx_start = 0;
reg [7:0] tx_data = 0;
wire tx_done;

uart_rx U_RX(
    .clk(clk),
    .rx(UART_rxd),
    .rx_done(rx_done),
    .rx_data(rx_data)
);

uart_tx U_TX(
    .clk(clk),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .tx(UART_txd),
    .tx_done(tx_done)
);

reg [7:0] ref_word [0:15];
reg [7:0] inp_word [0:15];

reg [3:0] ref_len = 0;
reg [3:0] inp_len = 0;

reg ref_stored = 0;

integer i;
reg match;

parameter RECEIVE = 1'b0;
parameter COMPARE = 1'b1;

reg state = RECEIVE;

always @(posedge clk)
begin

    tx_start <= 0;

    case(state)

    RECEIVE:
    begin

        if(rx_done)
        begin

            if(rx_data == 8'h0D)
            begin

                if(ref_stored == 0)
                begin

                    ref_len <= inp_len;

                    for(i=0;i<16;i=i+1)
                        ref_word[i] <= inp_word[i];

                    inp_len <= 0;
                    ref_stored <= 1;

                end
                else
                begin

                    state <= COMPARE;

                end

            end
            else
            begin

                if(inp_len < 16)
                begin

                    // Ignore punctuation
                    if(rx_data=="?" || rx_data=="." ||
                       rx_data=="," || rx_data=="!")
                    begin
                    end
                    else
                    begin

                        // Convert uppercase to lowercase
                        if(rx_data >= "A" && rx_data <= "Z")
                            inp_word[inp_len] <= rx_data + 8'd32;
                        else
                            inp_word[inp_len] <= rx_data;

                        inp_len <= inp_len + 1;

                    end

                end

            end

        end

    end

    COMPARE:
    begin

        match = 1'b1;

        if(ref_len != inp_len)
            match = 1'b0;

        for(i=0;i<16;i=i+1)
        begin
            if(i < ref_len)
            begin
                if(ref_word[i] != inp_word[i])
                    match = 1'b0;
            end
        end

        if(match)
            tx_data <= "Y";
        else
            tx_data <= "N";

        tx_start <= 1'b1;

        inp_len <= 0;
        ref_stored <= 0;

        state <= RECEIVE;

    end

    endcase

end

endmodule