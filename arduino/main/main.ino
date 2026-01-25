// Vehicle Voltage Monitor
// Reads 12V-14.4V battery via voltage divider on A0
// Outputs to Serial for PC monitoring

// Pin definitions
const int PIN_VBAT = A0;  // Vehicle voltage input (via divider)

// Voltage divider constants
// Divider: 100k upper (to Vin), 47k lower (to GND)
// Vout = Vin * (47k / (100k + 47k)) = Vin * 0.3197
// So Vin = Vout / 0.3197
// At 12V: ADC sees 3.84V | At 14.4V: ADC sees 4.60V
const float DIVIDER_RATIO = 47.0 / (100.0 + 47.0);  // ~0.3197
const float ADC_REF = 5.0;
const int ADC_MAX = 1023;

void setup() {
  Serial.begin(9600);
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  // Read and calculate voltage
  int rawAdc = analogRead(PIN_VBAT);
  float vDivider = (rawAdc / (float)ADC_MAX) * ADC_REF;
  float vBattery = vDivider / DIVIDER_RATIO;

  // Output to serial
  Serial.print("ADC: ");
  Serial.print(rawAdc);
  Serial.print(" | V_bat: ");
  Serial.print(vBattery, 2);
  Serial.println("V");

  // Heartbeat blink
  digitalWrite(LED_BUILTIN, HIGH);
  delay(50);
  digitalWrite(LED_BUILTIN, LOW);

  delay(1000);  // 1Hz update rate
}
