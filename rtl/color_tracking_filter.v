module color_tracking_filter (
    input  wire        clk_pixel,
    input  wire [23:0] data_in,
    input  wire        hsync_in,
    input  wire        vsync_in,
    input  wire        vde_in,
    
    output reg  [23:0] data_out,
    output reg         hsync_out,
    output reg         vsync_out,
    output reg         vde_out
);

    // --- PIPELINE STAGE: INPUT REGISTERS ---
    // Improves timing stability at 74.25 MHz
    reg [23:0] data_reg;
    reg hsync_r, vsync_r, vde_r;
    
    always @(posedge clk_pixel) begin
        data_reg <= data_in;
        hsync_r  <= hsync_in;
        vsync_r  <= vsync_in;
        vde_r    <= vde_in;
    end
// --- COLOR EXTRACTION & THRESHOLDING ---
    wire [7:0] red_val   = data_reg[23:16];
    wire [7:0] green_val = data_reg[15:8];
    wire [7:0] blue_val  = data_reg[7:0];

    wire [7:0] gray_val = (red_val + (green_val << 1) + blue_val) >> 2;

    // Custom threshold values for red detection
    // Red must be higher than 100 to catch dark reds
    // Green and Blue must be within a specific range to ignore black/gray noise
    wire is_red = (red_val > 100) && 
                  (green_val > 15 && green_val < 70) && 
                  (blue_val > 15 && blue_val < 70);
             
             
    // --- HARDWARE NOISE FILTER (DEBOUNCER) ---
    // Ignore random 1-pixel glitches. Require 8 consecutive red pixels.
    reg [3:0] solid_red_count = 0;
    wire valid_object = (solid_red_count > 8);

    // --- COORDINATE COUNTERS ---
    reg [11:0] x_pos = 0;
    reg [11:0] y_pos = 0;
    reg vde_prev = 0;
    reg vsync_prev = 0;

    // --- BOUNDING BOX REGISTERS ---
    reg [11:0] x_min = 12'hFFF;
    reg [11:0] x_max = 0;
    reg [11:0] y_min = 12'hFFF;
    reg [11:0] y_max = 0;

    // --- CALCULATED CENTER COORDINATES ---
    reg [11:0] center_x = 12'hFFF; // Default to off-screen
    reg [11:0] center_y = 12'hFFF;

    always @(posedge clk_pixel) begin
        hsync_out  <= hsync_r;
        vsync_out  <= vsync_r;
        vde_out    <= vde_r;
        vde_prev   <= vde_r;
        vsync_prev <= vsync_r;
        
        // Update X and Y position counters
        if (vde_r) begin
            x_pos <= x_pos + 1;
            
            // Noise filter logic: count consecutive red pixels
            if (is_red) begin
                if (solid_red_count < 15) 
                    solid_red_count <= solid_red_count + 1;
            end else begin
                solid_red_count <= 0;
            end
        end else begin
            x_pos <= 0;
        end

        if (vde_prev == 1 && vde_r == 0) begin
            y_pos <= y_pos + 1;
        end

        if (vsync_r) begin
            y_pos <= 0;
        end

        // --- TRACKING LOGIC (FILTERED) ---
        // Only update bounding box if the noise filter confirms a solid object
        if (vde_r && valid_object) begin
            if (x_pos < x_min) x_min <= x_pos;
            if (x_pos > x_max) x_max <= x_pos;
            if (y_pos < y_min) y_min <= y_pos;
            if (y_pos > y_max) y_max <= y_pos;
        end

        // --- END OF FRAME CALCULATION ---
        if (vsync_r == 1 && vsync_prev == 0) begin
            if (x_max > x_min) begin
                // Solid object detected, calculate centroid
                center_x <= (x_min + x_max) >> 1;
                center_y <= (y_min + y_max) >> 1;
            end else begin
                // No valid object found, hide the crosshair
                center_x <= 12'hFFF;
                center_y <= 12'hFFF;
            end
            
            // Reset bounding box registers for the next video frame
            x_min <= 12'hFFF;
            x_max <= 0;
            y_min <= 12'hFFF;
            y_max <= 0;
        end
        
        // --- OUTPUT MULTIPLEXER (DRAWING) ---
        if (vde_r) begin
            // Draw a 20x20 White Crosshair
            if ( (x_pos == center_x && y_pos >= center_y - 10 && y_pos <= center_y + 10) || 
                 (y_pos == center_y && x_pos >= center_x - 10 && x_pos <= center_x + 10) ) begin
                data_out <= 24'hFFFFFF; // Pure White Target
            end 
            else if (is_red) begin
                data_out <= 24'hFF0000; // Highlight the red target
            end 
            else begin
                data_out <= {gray_val, gray_val, gray_val}; // Grayscale background
            end
        end else begin
            data_out <= 24'h000000;
        end
    end

endmodule