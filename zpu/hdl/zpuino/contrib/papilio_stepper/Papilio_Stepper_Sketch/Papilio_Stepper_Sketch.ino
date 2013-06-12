/*
  Gadget Factory
  Papilio Stepper Test
 
 Quick Test of the Papilio Stepper Wishbone core
 
 To learn more about this example visit its home page at the Papilio Audio Wiki:
http://gadgetforge.gadgetfactory.net/gf/project/stepper_core/
 
 To learn more about the Papilio and Gadget Factory products visit:
 http://www.GadgetFactory.net
 
 Hardware:

 *******IMPORTANT********************
 Be sure to load the ZPUino "Stepper" variant to the Papilio's SPI Flash before loading this sketch.

 created 2013
 by Jack Gassett 

 http://www.gadgetfactory.net
 
 This example code is Creative Commons Attribution.
 */

#define STEPPER1_DIR WING_A_0          
#define STEPPER1_STEP WING_A_1
#define STEPPER1_ENABLE WING_A_2

#define STEPPER2_DIR WING_C_0          
#define STEPPER2_STEP WING_C_1
#define STEPPER2_ENABLE WING_C_2

#define STEPPER1BASE IO_SLOT(9)
#define STEPPER1REG(x) REGISTER(STEPPER1BASE,x)

#define STEPPER2BASE IO_SLOT(10)
#define STEPPER2REG(x) REGISTER(STEPPER2BASE,x)

void setup(){
  Serial.begin(9600);

  //Move the stepper1 pins to the appropriate pins on the Papilio Hardware
  pinMode(STEPPER1_DIR,OUTPUT);
  digitalWrite(STEPPER1_DIR,HIGH);
  outputPinForFunction(STEPPER1_DIR, 5);
  pinModePPS(STEPPER1_DIR, HIGH);
  
  pinMode(STEPPER1_STEP,OUTPUT);
  digitalWrite(STEPPER1_STEP,HIGH);
  outputPinForFunction(STEPPER1_STEP, 6);
  pinModePPS(STEPPER1_STEP, HIGH);  
  
  pinMode(STEPPER1_ENABLE,OUTPUT);
  digitalWrite(STEPPER1_ENABLE,HIGH);
  outputPinForFunction(STEPPER1_ENABLE, 7);
  pinModePPS(STEPPER1_ENABLE, HIGH); 
  
  //Move the stepper2 pins to the appropriate pins on the Papilio Hardware
  pinMode(STEPPER2_DIR,OUTPUT);
  digitalWrite(STEPPER2_DIR,HIGH);
  outputPinForFunction(STEPPER2_DIR, 8);
  pinModePPS(STEPPER2_DIR, HIGH);
  
  pinMode(STEPPER2_STEP,OUTPUT);
  digitalWrite(STEPPER2_STEP,HIGH);
  outputPinForFunction(STEPPER2_STEP, 9);
  pinModePPS(STEPPER2_STEP, HIGH);  
  
  pinMode(STEPPER2_ENABLE,OUTPUT);
  digitalWrite(STEPPER2_ENABLE,HIGH);
  outputPinForFunction(STEPPER2_ENABLE, 10);
  pinModePPS(STEPPER2_ENABLE, HIGH);   

//Setup and start stepper1
  //Set Timebase
  STEPPER1REG(1) = 0x08;
  //Set Period
  STEPPER1REG(2) = 0x07D0;
  //Set Step Count (steps before interupt)
  STEPPER1REG(3) = 0x04;
  //Set Control Register (Starts motor and does interupt after 4 steps
  STEPPER1REG(0) = 0x1F0;
   
//Setup and start stepper2
  //Set Timebase
  STEPPER2REG(1) = 0x08;
  //Set Period
  STEPPER2REG(2) = 0x07D0;
  //Set Step Count (steps before interupt)
  STEPPER2REG(3) = 0x04;
  //Set Control Register (Starts motor and does interupt after 4 steps
  STEPPER2REG(0) = 0x1F8;

}

void loop(){

  
}
