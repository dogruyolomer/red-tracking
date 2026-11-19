# Red Tracking

A real-time HDMI video-processing demo for the PYNQ-Z2 FPGA board.
It highlights red pixels against a grayscale background and draws a white
crosshair at the center of the detected bounding box in the next frame.

## Hardware setup

Connect the laptop to PYNQ-Z2 HDMI IN and an external monitor to HDMI OUT.

## Build with Vivado 2023.2

1. Create an RTL project for the PYNQ-Z2.
2. Add Digilent vivado-library to the project's IP repositories for dvi2rgb and rgb2dvi.
3. Add `rtl/color_tracking_filter.v` as a design source.
4. Add `constraints/pynq_hdmi.xdc` as a constraints file.
5. Run `source {/absolute/path/to/vivado/hdmi_bypass.tcl}` in the Tcl Console,
   replacing the path with the actual location of the script.
6. Create an HDL wrapper for `hdmi_bypass` and generate the bitstream.

## Validation

Red highlighting and the crosshair were tested on a physical PYNQ-Z2.
HDMI pixel-clock timing closure has not been verified.
