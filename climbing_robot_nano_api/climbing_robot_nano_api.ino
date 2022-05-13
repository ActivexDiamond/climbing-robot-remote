/// Libs
#include <Servo.h>

/// Config
#define DEBUG true

/// Pins
#define R_WHEEL_PIN A1
#define L_WHEEL_PIN A0

#define CUTTER_WORM_PIN A3
#define CUTTER_WHEEL_PIN A2

#define UD_LPWM 6
#define UD_RPWM 5
#define FB_LPWM 11
#define FB_RPWM 3

//Gearbox motor pins.
#define R_GEARBOX_PIN = 9
#define L_GEARBOX_PIN = 10

/// Formula-esc Constants
#define WORM_OPEN 170
#define WORM_CLOSE 10

/// State
Servo rWheel;
Servo lWheel;

Servo cutterWorm;
Servo cutterWheel;

/// Core API
void setup() {
    //Serial Setup
    Serial.begin(9600);

    //Pin Setup
    Serial.println("Entering setup...")
    pinMode(UD_LPWM, OUTPUT);
    pinMode(UD_RPWM, OUTPUT);
    pinMode(FB_LPWM, OUTPUT);
    pinMode(FB_RPWM, OUTPUT);

    pinMode(R_GEARBOX_PIN, OUTPUT);
    pinMode(L_GEARBOX_PIN, OUTPUT);

    //Servo Setup
    rWheel.attach(R_WHEEL_PIN);
    lWheel.attach(L_WHEEL_PIN);

    cutterWorm.attach(CUTTER_WORM_PIN);
    cutterWheel.attach(CUTTER_WHEEL_PIN);

    //Init to defaults.
    rWheel.write(90);
    lWheel.write(90);

    cutterWorm.write(wormClose);
    cutterWheel.write(0);

    ARM_Stop();
    Wheel_Stop();

    //Echo
    Serial.println("Setup complete.")
}

void loop() {
    //Poll for cmds.
    while(Serial.available()) {
        //Fetch first cmd.
        String c = Serial.readStringUntil(';');
        //Arm. [S]
        if(c=="AS") ARM_Stop();
        //Arm with speed. [U/D/F/B]
        if(c=="AU" || c=="AD" || c=="AF" || c=="AB") {
          int s = Serial.readStringUntil(';').toInt();
          if(c == "AU") ARM_Up(s);
          if(c == "AD") ARM_Down(s);
          if(c == "AF") ARM_Forward(s);
          if(c == "AB") ARM_Backward(s);
        }

        //Wheel. [S/R/L]
        if(c=="WS") Wheel_Stop();
        if(c == "WR") Wheel_Right();
        if(c == "WL") Wheel_Left();
        //Wheel with degree. [F/B]
        if(c=="WF" || c=="WB") {
          int val = Serial.readStringUntil(';').toInt();
          if(c == "WF") Wheel_Forward(val);
          if(c == "WB") Wheel_Backward(val);
        }

        //CutterWorm with degree.
        if(c == "CWorm") {
          int d = Serial.readStringUntil(';').toInt();
          d = map(d, 0, 5, wormClose, WORM_OPEN);
          cutterWorm.write(d);
        }

        //CutterWheel with degree.
        if(c == "CWheel") {
          int d = Serial.readStringUntil(';').toInt();
          d = map(d, 0, 10, 0, 180);
          cutterWheel.write(d);
        }
    }
}

void ARM_Stop() {
    analogWrite(UD_RPWM, 0); analogWrite(UD_LPWM, 0);
    analogWrite(FB_RPWM, 0); analogWrite(FB_LPWM, 0);

    if(DEBUG) {
        Serial.println("ARM_Stop");
    }
}

void ARM_Up(int spd) {
    analogWrite(UD_RPWM, 0);
    analogWrite(UD_LPWM, 0);

    analogWrite(UD_RPWM, spd);

    if(DEBUG) {
        Serial.print("ARM_Up  spd=");
        Serial.println(spd);
    }
}

void ARM_Down(int spd) {
    analogWrite(UD_RPWM, 0);
    analogWrite(UD_LPWM, 0);

    analogWrite(UD_LPWM, spd);

    if(DEBUG) {
        Serial.print("ARM_Down  spd=");
        Serial.println(spd);
    }
}

void ARM_Forward(int spd) {
    analogWrite(FB_RPWM, 0);
    analogWrite(FB_LPWM, 0);

    analogWrite(FB_RPWM, spd);

    if(DEBUG) {
        Serial.print("ARM_Forward  spd=");
        Serial.println(spd);
    }
}

void ARM_Backward(int spd) {
    analogWrite(FB_RPWM, 0);
    analogWrite(FB_LPWM, 0);

    analogWrite(FB_LPWM, spd);

    if(DEBUG) {
        Serial.print("ARM_Backward  spd=");
        Serial.println(spd);
    }
}

void Wheel_Stop() {
    rWheel.write(90);
    lWheel.write(90);

    analogWrite(R_GEARBOX_PIN, 0);
    analogWrite(L_GEARBOX_PIN, 0);

    if(DEBUG) {
        Serial.println("Wheel_Stop");
    }
}

void Wheel_Forward(int val) {
    inv deg = map(val, 75, 255, 90, 0);
    int spd = map(val, 75, 255, 0, 255);

    rWheel.write(deg);
    lWheel.write(180-deg);

    analogWrite(R_GEARBOX_PIN, spd);
    analogWrite(L_GEARBOX_PIN, spd);

    if(DEBUG) {
        Serial.print("Wheel_Forward  degR=");
        Serial.print(deg);
        Serial.print("  degL=");
        Serial.println(180-deg);
    }
}

void Wheel_Backward(int val) {
    inv deg = map(val, 75, 255, 90, 0);
    int spd = map(val, 75, 255, 0, 255);

    rWheel.write(180-deg);
    lWheel.write(deg);

    analogWrite(R_GEARBOX_PIN, spd);
    analogWrite(L_GEARBOX_PIN, spd);

    if(DEBUG) {Serial.print("Wheel_Backward  degR=");
        Serial.print(180-deg);
        Serial.print("  degL=");
        Serial.println(deg);
    }
}

void Wheel_Right() {
    rWheel.write(180);
    lWheel.write(180);

    analogWrite(R_GEARBOX_PIN, 0);
    analogWrite(L_GEARBOX_PIN, 255);

    if(DEBUG) {
        Serial.println("Wheel_Right");
    }
}

void Wheel_Left() {
    rWheel.write(0);
    lWheel.write(0);

    analogWrite(R_GEARBOX_PIN, 255);
    analogWrite(L_GEARBOX_PIN, 0);

    if(DEBUG) {
        Serial.println("Wheel_Left");
    }
}
