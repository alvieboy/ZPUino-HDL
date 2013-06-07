This variant includes the papilio_stepper core as a wishbone slave:
http://gadgetforge.gadgetfactory.net/gf/project/stepper_core/

There are two stepper cores connected to control two axis.

Stepper1 is connected to IO Slot 9
Stepper2 is connected to IO Slot 10

Stepper outputs are connected to PPS 5-10
	gpio_spp_data(5) <= stepper1_dir; 			-- PPS5 : 
    gpio_spp_data(6) <= stepper1_step; 			-- PPS6 : 
    gpio_spp_data(7) <= stepper1_enable;         -- PPS7 : 
	gpio_spp_data(8) <= stepper2_dir; 			-- PPS5 : 
    gpio_spp_data(9) <= stepper2_step; 			-- PPS6 : 
    gpio_spp_data(10) <= stepper2_enable;         -- PPS7 : 