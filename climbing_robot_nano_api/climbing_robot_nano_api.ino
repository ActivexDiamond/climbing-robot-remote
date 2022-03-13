#include <Servo.h>
Servo rightWheel;
Servo leftWheel;
#define rWheel_pin A1
#define lWheel_pin A0

#define cutterWorm_pin A3
#define cutterWheel_pin A2
Servo cutterWorm;
Servo cutterWheel;
#define wormOpen 170
#define wormClose 10

//#define bluetooth Serial
//SoftwareSerial bluetooth(2,7);
#define debug true

#define UD_LPWM 6
#define UD_RPWM 5
#define FB_LPWM 11
#define FB_RPWM 3

//#define trigger 8
//#define echo 9
//unsigned long usT = 0;
//Ultrasonic ultrasonic(trigger, echo);

void setup() {
  pinMode(UD_LPWM,OUTPUT); pinMode(UD_RPWM,OUTPUT); pinMode(FB_LPWM,OUTPUT); pinMode(FB_RPWM,OUTPUT);
  rightWheel.attach(rWheel_pin);
  leftWheel.attach(lWheel_pin);
  cutterWorm.attach(cutterWorm_pin);
  cutterWheel.attach(cutterWheel_pin);
  rightWheel.write(90); leftWheel.write(90);
  cutterWorm.write(wormClose); cutterWheel.write(0);
  //bluetooth.begin(9600);
  Serial.begin(9600);
//  usT = millis();

  ARM_Stop();
  Wheel_Stop();
  cutterWorm.write(wormClose);
  cutterWheel.write(0);
}

void loop() {
  while(Serial.available()){
    String c = Serial.readStringUntil(';');
    if(c=="AS") ARM_Stop();
    if(c=="AU" || c=="AD" || c=="AF" || c=="AB"){  
      int s = Serial.readStringUntil(';').toInt();
      if(c == "AU") ARM_Up(s);
      if(c == "AD") ARM_Down(s);
      if(c == "AF") ARM_Forward(s);
      if(c == "AB") ARM_Backward(s);
    }
    if(c=="WS") Wheel_Stop();
    if(c == "WR") Wheel_Right();
    if(c == "WL") Wheel_Left();
    if(c=="WF" || c=="WB"){
      int d = Serial.readStringUntil(';').toInt();
      d = map(d,75,255,90,0);
      if(c == "WF") Wheel_Forward(d);
      if(c == "WB") Wheel_Backward(d);
    }
    if(c == "CWorm"){
      int d = Serial.readStringUntil(';').toInt();
      d = map(d,0,5,wormClose,wormOpen);
      cutterWorm.write(d);
    }
    if(c == "CWheel"){
      int d = Serial.readStringUntil(';').toInt();
      d = map(d,0,10,0,180);
      cutterWheel.write(d);      
    }
  }
//  if(millis()> usT + 500){
//    int cm = 0;
//    while(cm==0) cm = ultrasonic.distanceRead();
//    bluetooth.print("us;" + String(cm) + ";");
//    if(debug) Serial.println("us;" + String(cm) + ";");
//    usT = millis();
//  }
}

void ARM_Stop(){
  analogWrite(UD_RPWM, 0); analogWrite(UD_LPWM, 0);
  analogWrite(FB_RPWM, 0); analogWrite(FB_LPWM, 0);
  if(debug) Serial.println("ARM_Stop");
}

void ARM_Up(int spd){
  analogWrite(UD_RPWM, 0); analogWrite(UD_LPWM, 0);
  analogWrite(UD_RPWM, spd);
  if(debug) {Serial.print("ARM_Up  spd="); Serial.println(spd);}
}

void ARM_Down(int spd){
  analogWrite(UD_RPWM, 0); analogWrite(UD_LPWM, 0);
  analogWrite(UD_LPWM, spd);
  if(debug) {Serial.print("ARM_Down  spd="); Serial.println(spd);}
}

void ARM_Forward(int spd){
  analogWrite(FB_RPWM, 0); analogWrite(FB_LPWM, 0);
  analogWrite(FB_RPWM, spd);
  if(debug) {Serial.print("ARM_Forward  spd="); Serial.println(spd);}
}

void ARM_Backward(int spd){
  analogWrite(FB_RPWM, 0); analogWrite(FB_LPWM, 0);
  analogWrite(FB_LPWM, spd);
  if(debug) {Serial.print("ARM_Backward  spd="); Serial.println(spd);}
}

void Wheel_Stop(){
  rightWheel.write(90); leftWheel.write(90);
  if(debug) {Serial.println("Wheel_Stop");}
}

void Wheel_Forward(int deg){
  rightWheel.write(deg); leftWheel.write(180-deg);
  if(debug) {Serial.print("Wheel_Forward  degR="); Serial.print(deg); Serial.print("  degL="); Serial.println(180-deg);}
}

void Wheel_Backward(int deg){
  rightWheel.write(180-deg); leftWheel.write(deg);
  if(debug) {Serial.print("Wheel_Backward  degR="); Serial.print(180-deg); Serial.print("  degL="); Serial.println(deg);}
}

void Wheel_Right(){
  rightWheel.write(180); leftWheel.write(180);
  if(debug) {Serial.println("Wheel_Right");}
}

void Wheel_Left(){
  rightWheel.write(0); leftWheel.write(0);
  if(debug) {Serial.println("Wheel_Left");}
}
