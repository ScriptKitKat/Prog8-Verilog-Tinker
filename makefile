SIM_OUT = sim_out
VCD     = waveform.vcd
IVFLAGS = -g2012

TB  = testbench.sv

.PHONY: all sim test wave clean

all: sim

$(SIM_OUT): $(TB)
	iverilog $(IVFLAGS) -o $(SIM_OUT) $(TB)

sim: $(SIM_OUT)
	vvp $(SIM_OUT)

test: sim

wave: sim
	gtkwave $(VCD) &

clean:
	rm -f $(SIM_OUT) $(VCD)