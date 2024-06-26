module sorter 
  #(
    parameter SIGNATURE_WIDTH = 32, // Width of kmer signature
    parameter INDEX_WIDTH = 10, // Width of index
    parameter NUM_COMPARATORS = 8, // Number of smallest signatures to retain
    parameter LOG_COMPARATORS = 3 // Width of positions
   )
   (
    input wire valid_in,
    input wire [SIGNATURE_WIDTH-1:0] signature_in,
    input wire [INDEX_WIDTH-1:0] index_in,
    
    output reg valid_out,
    output reg [(NUM_COMPARATORS*INDEX_WIDTH)-1:0] indices_out // Packed array
  );

  // Internal storage for signatures and indices
  reg [SIGNATURE_WIDTH-1:0] signatures[NUM_COMPARATORS-1:0];
  reg [INDEX_WIDTH-1:0] indices[NUM_COMPARATORS-1:0];
  reg [LOG_COMPARATORS-1:0] positions[NUM_COMPARATORS-1:0];

  wire [NUM_COMPARATORS-1:0] is_smaller;
  wire [LOG_COMPARATORS-1:0] new_position;
  reg replace = 1'b0;

  reg [SIGNATURE_WIDTH-1:0] signature_read;
  reg [INDEX_WIDTH-1:0] index_read;
  reg [LOG_COMPARATORS-1:0] position_read;
  integer file, status;
  integer i = 0;
  initial begin
    for (i = 0; i < NUM_COMPARATORS; i = i + 1)      
          signatures[i] = 32'h12345678;
          indices[i] = 10'b0000000000;
          positions[i] = i;
      end

  genvar j;
  generate
    for (j = 0; j < NUM_COMPARATORS; j = j + 1) 
    begin: COMPONENT_INST
      compare_vectors #(
        .SIGNATURE_WIDTH(SIGNATURE_WIDTH)
      ) compare_vectors_instance (
        .signature_in(signature_in),
        .vec(signatures[j]),
        .smaller(is_smaller[j])
      );
    end
  endgenerate

  always @* begin
    replace = 1'b0;
    for (integer k = 0; k < NUM_COMPARATORS; k = k + 1) begin
      if (is_smaller[k]) begin
        if (positions[k] == 3'b000) begin
          signatures[k] = signature_in;
          indices[k] = index_in;
          replace = 1'b1;
        end else begin
          positions[k] = positions[k] + 1;
        end
      end
    end
  end

  // Instantiate bit_sum outside always block
  bit_sum #(
    .NUM_COMPARATORS(NUM_COMPARATORS),
    .LOG_COMPARATORS(LOG_COMPARATORS)
  ) bit_sum_instance (
    .vec(is_smaller),
    .sum(new_position)
  );

  always @(posedge replace) begin
    for (integer k = 0; k < NUM_COMPARATORS; k = k + 1) begin
      if (positions[k] == 3'b111) begin
        positions[k] = new_position;
      end
    end
  end

  // Output logic
  always @* begin
    for (i = 0; i < NUM_COMPARATORS; i = i + 1) begin
      indices_out[(i+1)*INDEX_WIDTH-1 -: INDEX_WIDTH] = indices[i];
    end
  end

endmodule

module compare_vectors #(parameter SIGNATURE_WIDTH = 32) (
    input [SIGNATURE_WIDTH-1:0] signature_in,
    input [SIGNATURE_WIDTH-1:0] vec,
    output reg smaller
);
    always @* begin
        if (signature_in < vec)
            smaller = 1'b1;
        else
            smaller = 1'b0;
    end
endmodule

module bit_sum #(
    parameter NUM_COMPARATORS = 8, // Number of smallest signatures to retain
    parameter LOG_COMPARATORS = 3 // Width of positions
  )(
    input [NUM_COMPARATORS-1:0] vec,
    output reg [LOG_COMPARATORS-1:0] sum
);
    integer i;
    always @* begin
        sum = 0;
        for (i = 0; i < NUM_COMPARATORS; i = i + 1) begin
            sum = sum + vec[i];
        end
    end
endmodule
