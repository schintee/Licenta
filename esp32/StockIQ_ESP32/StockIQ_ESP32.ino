#include <Arduino.h>
#include "HX711.h"
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <Adafruit_NeoPixel.h>
#include <math.h>

#define WIFI_SSID       "DIGI-99aA"
#define WIFI_PASSWORD   "k3YTH2s52A"

#define API_KEY         "AIzaSyA-DCUmSH-I24_Q4zABi2AclasMuMSSVl8"
#define DATABASE_URL     "https://smart-inventory-71548-default-rtdb.europe-west1.firebasedatabase.app"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
bool signupOK = false;

#define USE_NEOPIXEL 1
#define NUM_PIXELS 1

// Cutia 1
#define LED_BOX1 33
#define DT_BOX1  32
#define SCK_BOX1 14

// Cutia 2
#define LED_BOX2 23
#define DT_BOX2  22
#define SCK_BOX2 21

// Cutia 3
#define LED_BOX3 19
#define DT_BOX3  18
#define SCK_BOX3 25


HX711 scale1;
HX711 scale2;
HX711 scale3;

#if USE_NEOPIXEL
Adafruit_NeoPixel pixel1(NUM_PIXELS, LED_BOX1, NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel pixel2(NUM_PIXELS, LED_BOX2, NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel pixel3(NUM_PIXELS, LED_BOX3, NEO_GRB + NEO_KHZ800);
#endif


const int READ_SAMPLES = 10;
const unsigned long PRINT_INTERVAL_MS = 1000;
const unsigned long FIREBASE_INTERVAL_MS = 3000;
const unsigned long COMMAND_CHECK_INTERVAL_MS = 500;
const unsigned long SETTINGS_REFRESH_INTERVAL_MS = 10000;

unsigned long lastCommandCheck = 0;
unsigned long lastSettingsRefresh = 0;

const float ERROR_MARGIN_PERCENT = 0.15; //marja de eroare +-15%
const float MIN_ALLOWED_ERROR_GRAMS = 5.0;
const float ONE_PRODUCT_TOLERANCE_PERCENT = 0.25;
const float MIN_PRODUCT_WEIGHT_GRAMS = 20.0;

struct BoxData {
  const char* id;
  const char* productId;

  HX711* scale;
  int ledPin;
  long raw;
  long emptyRaw;
  float rawPerGram;
  float grams;
  float oneProductGrams;
  int quantity;
  int candidateQuantity;
  float expectedGrams;
  float errorFromExpected;
  float allowedErrorGrams;
  bool measurementValid;

  bool productConfigured;

  int maxStock;
  int redThreshold;
  int yellowThreshold;

  unsigned long lastPrint;
  unsigned long lastFirebaseUpdate;
};


BoxData boxes[3] = {
  {
    "box1", "product_box1",
    &scale1,
    LED_BOX1,

    0,

    333274,
    -294.256,

    0,
    0,

    0,

    0, 0, 0, 0, false,

    false,

    30, 1, 2,

    0, 0
  },

  {
    "box2", "product_box2",
    &scale2,
    LED_BOX2,

    0,

    375573,
    -137.611,

    0,
    0,

    0,

    0, 0, 0, 0, false,

    false,

    15, 1, 3,

    0, 0
  },

  {
    "box3", "product_box3",
    &scale3,
    LED_BOX3,

    0,

    365786,
    -143.444,

    0,
    0,

    0,

    0, 0, 0, 0, false,

    false,

    50, 2, 4,

    0, 0
  }
};


void setBoxLed(int index, uint8_t r, uint8_t g, uint8_t b) {
#if USE_NEOPIXEL
  Adafruit_NeoPixel* p;

  if (index == 0) p = &pixel1;
  else if (index == 1) p = &pixel2;
  else p = &pixel3;

  p->setPixelColor(0, p->Color(r, g, b));
  p->show();
#else
  digitalWrite(boxes[index].ledPin, (r > 0 || g > 0 || b > 0) ? HIGH : LOW);
#endif
}

void updateLedStatus(int index) {
  BoxData &b = boxes[index];

  if (!b.productConfigured) {
    setBoxLed(index, 0, 0, 80);
    return;
  }
  if (b.quantity <= b.redThreshold) {
    setBoxLed(index, 120, 0, 0);       // rosu
  } else if (b.quantity <= b.yellowThreshold) {
    setBoxLed(index, 120, 80, 0);      // galben
  } else {
    setBoxLed(index, 0, 120, 0);       // verde
  }
}

String pathBox(const char* boxId, const char* field) {
  return String("/boxes/") + boxId + "/" + field;
}

String pathCommand(const char* boxId, const char* field) {
  return String("/commands/") + boxId + "/" + field;
}

long getFirebaseLong(const String& path, long fallback) {
  if (!Firebase.ready() || !signupOK) return fallback;

  if (Firebase.RTDB.getInt(&fbdo, path.c_str())) {
    return fbdo.intData();
  }

  return fallback;
}

float getFirebaseFloat(const String& path, float fallback) {
  if (!Firebase.ready() || !signupOK) return fallback;

  if (Firebase.RTDB.getFloat(&fbdo, path.c_str())) {
    return fbdo.floatData();
  }

  if (Firebase.RTDB.getInt(&fbdo, path.c_str())) {
    return (float)fbdo.intData();
  }

  return fallback;
}

bool getFirebaseBool(const String& path, bool fallback) {
  if (!Firebase.ready() || !signupOK) return fallback;

  if (Firebase.RTDB.getBool(&fbdo, path.c_str())) {
    return fbdo.boolData();
  }

  Serial.print("Nu pot citi bool din Firebase: ");
  Serial.print(path);
  Serial.print(" | eroare: ");
  Serial.println(fbdo.errorReason());

  return fallback;
}

void setFirebaseBool(const String& path, bool value) {
  if (!Firebase.ready() || !signupOK) return;

  if (!Firebase.RTDB.setBool(&fbdo, path.c_str(), value)) {
    Serial.print("Nu pot seta bool in Firebase: ");
    Serial.print(path);
    Serial.print(" | eroare: ");
    Serial.println(fbdo.errorReason());
  }
}


void loadSettingsFromFirebase(bool printLog = true) {
  if (!Firebase.ready() || !signupOK) return;

  if (printLog) {
    Serial.println();
    Serial.println("Citesc setari din Firebase...");
    Serial.println("Pragurile rosu/galben/maxStock/oneProductGrams se citesc din aplicatie.");
    Serial.println("emptyRaw + rawPerGram raman locale in cod.");
  }

  for (int i = 0; i < 3; i++) {
    BoxData &b = boxes[i];

    b.maxStock = (int)getFirebaseLong(pathBox(b.id, "maxStock"), b.maxStock);
    b.redThreshold = (int)getFirebaseLong(pathBox(b.id, "redThreshold"), b.redThreshold);
    b.yellowThreshold = (int)getFirebaseLong(pathBox(b.id, "yellowThreshold"), b.yellowThreshold);

 
    if (b.maxStock < 0) b.maxStock = 0;
    if (b.redThreshold < 0) b.redThreshold = 0;
    if (b.yellowThreshold < 0) b.yellowThreshold = 0;


    if (b.yellowThreshold < b.redThreshold) {
      b.yellowThreshold = b.redThreshold;
    }

  
    if (b.maxStock < b.yellowThreshold) {
      b.maxStock = b.yellowThreshold;
    }

    float fbOneProduct = getFirebaseFloat(pathBox(b.id, "oneProductGrams"), b.oneProductGrams);

    if (fbOneProduct >= MIN_PRODUCT_WEIGHT_GRAMS) {
      b.oneProductGrams = fbOneProduct;
      b.productConfigured = true;
    } else {
      b.productConfigured = false;
    }

    if (printLog) {
      Serial.printf(
        "%s | emptyRaw local=%ld | rawPerGram local=%.3f | oneProductGrams=%.1f | red=%d | yellow=%d | max=%d\n",
        b.id,
        b.emptyRaw,
        b.rawPerGram,
        b.oneProductGrams,
        b.redThreshold,
        b.yellowThreshold,
        b.maxStock
      );
    }
  }

  if (printLog) {
    Serial.println();
  }
}

void updateBoxInFirebase(BoxData &b) {
  if (!Firebase.ready() || !signupOK) return;

  FirebaseJson json;

  json.set("lastWeightRaw", b.raw);
  json.set("grams", b.grams);
  json.set("quantity", b.quantity);

  json.set("oneProductGrams", b.oneProductGrams);
  json.set("productConfigured", b.productConfigured);

  // Debug util.
  json.set("candidateQuantity", b.candidateQuantity);
  json.set("expectedGrams", b.expectedGrams);
  json.set("errorFromExpected", b.errorFromExpected);
  json.set("allowedErrorGrams", b.allowedErrorGrams);
  json.set("measurementValid", b.measurementValid);

  json.set("initialized", true);
  json.set("lastUpdate", (int)millis());

  String path = String("/boxes/") + b.id;

  if (!Firebase.RTDB.updateNode(&fbdo, path.c_str(), &json)) {
    Serial.print("Eroare update Firebase ");
    Serial.print(b.id);
    Serial.print(": ");
    Serial.println(fbdo.errorReason());
  }
}


long readRaw(BoxData &b) {
  if (b.scale->is_ready()) {
    return b.scale->read_average(READ_SAMPLES);
  }

  Serial.print("HX711 nu e gata pentru ");
  Serial.println(b.id);
  return b.raw;
}


float calculateGrams(BoxData &b) {
  if (b.rawPerGram == 0) {
    return 0;
  }

  float grams = (float)(b.raw - b.emptyRaw) / b.rawPerGram;

  if (grams < 0) {
    grams = 0;
  }

  return grams;
}

int calculateQuantity(BoxData &b) {
  if (!b.productConfigured || b.oneProductGrams < MIN_PRODUCT_WEIGHT_GRAMS) {
    b.measurementValid = false;
    b.candidateQuantity = 0;
    b.expectedGrams = 0;
    b.errorFromExpected = 0;
    b.allowedErrorGrams = 0;
    return 0;
  }

  if (b.grams < b.oneProductGrams * 0.5) {
    b.candidateQuantity = 0;
    b.expectedGrams = 0;
    b.errorFromExpected = b.grams;

    float allowedError = b.oneProductGrams * ONE_PRODUCT_TOLERANCE_PERCENT;
    if (allowedError < MIN_ALLOWED_ERROR_GRAMS) {
      allowedError = MIN_ALLOWED_ERROR_GRAMS;
    }

    b.allowedErrorGrams = allowedError;
    b.measurementValid = true;
    return 0;
  }

  float exactQuantity = b.grams / b.oneProductGrams;
  int candidate = (int)round(exactQuantity);

  if (candidate < 0) candidate = 0;
  if (candidate > b.maxStock) candidate = b.maxStock;

  float expected = candidate * b.oneProductGrams;
  float error = b.grams - expected;
  float allowedError = expected * ERROR_MARGIN_PERCENT;

  float productTolerance = b.oneProductGrams * ONE_PRODUCT_TOLERANCE_PERCENT;
  if (allowedError < productTolerance) {
    allowedError = productTolerance;
  }

  if (allowedError < MIN_ALLOWED_ERROR_GRAMS) {
    allowedError = MIN_ALLOWED_ERROR_GRAMS;
  }

  b.candidateQuantity = candidate;
  b.expectedGrams = expected;
  b.errorFromExpected = error;
  b.allowedErrorGrams = allowedError;
  b.measurementValid = fabs(error) <= allowedError;

  return candidate;
}

void updateMeasurement(BoxData &b) {
  b.raw = readRaw(b);
  b.grams = calculateGrams(b);
  b.quantity = calculateQuantity(b);
}

void tareBox(int index) {
  BoxData &b = boxes[index];

  b.raw = readRaw(b);
  b.emptyRaw = b.raw;

  b.grams = 0;
  b.quantity = 0;
  b.candidateQuantity = 0;
  b.expectedGrams = 0;
  b.errorFromExpected = 0;
  b.allowedErrorGrams = 0;
  b.measurementValid = true;

  Serial.println();
  Serial.print("TARE ");
  Serial.print(b.id);
  Serial.print(" -> emptyRaw local = ");
  Serial.println(b.emptyRaw);

  Serial.println("TARE a fost facut local in RAM.");
  Serial.println("Daca vrei sa ramana permanent, copiaza noul emptyRaw in cod.");

  updateBoxInFirebase(b);
}

void saveOneProductBox(int index) {
  BoxData &b = boxes[index];

  b.raw = readRaw(b);
  b.grams = calculateGrams(b);

  Serial.println();
  Serial.print("SAVE ONE PRODUCT ");
  Serial.println(b.id);

  Serial.print("Greutate masurata produs = ");
  Serial.print(b.grams, 1);
  Serial.println(" g");

  if (b.grams < MIN_PRODUCT_WEIGHT_GRAMS) {
    Serial.println("EROARE: greutatea masurata este prea mica.");
    Serial.println("Pune exact 1 produs in cutie si incearca din nou.");
    return;
  }
  b.oneProductGrams = b.grams;
  b.productConfigured = true;

  b.quantity = 1;
  b.candidateQuantity = 1;
  b.expectedGrams = b.oneProductGrams;
  b.errorFromExpected = 0;

  float allowedError = b.oneProductGrams * ERROR_MARGIN_PERCENT;
  float productTolerance = b.oneProductGrams * ONE_PRODUCT_TOLERANCE_PERCENT;

  if (allowedError < productTolerance) {
    allowedError = productTolerance;
  }

  if (allowedError < MIN_ALLOWED_ERROR_GRAMS) {
    allowedError = MIN_ALLOWED_ERROR_GRAMS;
  }

  b.allowedErrorGrams = allowedError;
  b.measurementValid = true;

  Serial.print("Greutate salvata pentru 1 produs in ");
  Serial.print(b.id);
  Serial.print(" = ");
  Serial.print(b.oneProductGrams, 1);
  Serial.println(" g");

  Serial.print("Marja folosita = +/-");
  Serial.print(b.allowedErrorGrams, 1);
  Serial.println(" g");

  updateBoxInFirebase(b);
}

void checkFirebaseCommands() {
  if (!Firebase.ready() || !signupOK) return;

  for (int i = 0; i < 3; i++) {
    BoxData &b = boxes[i];

    String tarePath = pathCommand(b.id, "tareRequest");
    String savePath = pathCommand(b.id, "saveOneProductRequest");

    bool tareReq = getFirebaseBool(tarePath, false);
    bool saveOneReq = getFirebaseBool(savePath, false);

    if (tareReq) {
      Serial.print("Comanda primita din aplicatie: TARE ");
      Serial.println(b.id);

      tareBox(i);
      setFirebaseBool(tarePath, false);
    }

    if (saveOneReq) {
      Serial.print("Comanda primita din aplicatie: SAVE ONE PRODUCT ");
      Serial.println(b.id);

      saveOneProductBox(i);
      setFirebaseBool(savePath, false);
    }
  }
}

void printCalibration() {
  Serial.println();
  Serial.println("SETARI LOCALE");

  for (int i = 0; i < 3; i++) {
    BoxData &b = boxes[i];

    Serial.printf(
      "%s | emptyRaw=%ld | rawPerGram=%.3f | grame=%.1f | oneProductGrams=%.1f | qty=%d | red=%d | yellow=%d | max=%d | valid=%s\n",
      b.id,
      b.emptyRaw,
      b.rawPerGram,
      b.grams,
      b.oneProductGrams,
      b.quantity,
      b.redThreshold,
      b.yellowThreshold,
      b.maxStock,
      b.measurementValid ? "DA" : "NU"
    );
  }

  Serial.println();
}

void checkSerialCommands() {
  if (!Serial.available()) return;

  String cmd = Serial.readStringUntil('\n');
  cmd.trim();
  cmd.toLowerCase();

  if (cmd == "t1") tareBox(0);
  else if (cmd == "t2") tareBox(1);
  else if (cmd == "t3") tareBox(2);
  else if (cmd == "s1") saveOneProductBox(0);
  else if (cmd == "s2") saveOneProductBox(1);
  else if (cmd == "s3") saveOneProductBox(2);
  else if (cmd == "p") printCalibration();
  else {
    Serial.println("Comenzi disponibile:");
    Serial.println("t1/t2/t3 = tare cutie goala");
    Serial.println("s1/s2/s3 = salveaza greutatea reala pentru 1 produs");
    Serial.println("p = afiseaza calibrare/setari");
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("StockIQ ESP32 - calcul stabil + comenzi rapide + praguri live");

  scale1.begin(DT_BOX1, SCK_BOX1);
  scale2.begin(DT_BOX2, SCK_BOX2);
  scale3.begin(DT_BOX3, SCK_BOX3);

#if USE_NEOPIXEL
  pixel1.begin();
  pixel2.begin();
  pixel3.begin();

  pixel1.clear();
  pixel2.clear();
  pixel3.clear();

  pixel1.show();
  pixel2.show();
  pixel3.show();
#else
  pinMode(LED_BOX1, OUTPUT);
  pinMode(LED_BOX2, OUTPUT);
  pinMode(LED_BOX3, OUTPUT);
#endif

  for (int i = 0; i < 3; i++) {
    setBoxLed(i, 0, 0, 80);
  }

  Serial.println();
  Serial.println("Calibrarea senzorilor este LOCALA:");
  Serial.println("emptyRaw + rawPerGram sunt hardcodate in ESP32.");
  Serial.println("Firebase NU le suprascrie.");
  Serial.println();

  printCalibration();

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Conectare WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(400);
  }

  Serial.println();
  Serial.print("WiFi conectat. IP: ");
  Serial.println(WiFi.localIP());

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Firebase signUp OK");
    signupOK = true;
  } else {
    Serial.print("Firebase signUp eroare: ");
    Serial.println(config.signer.signupError.message.c_str());
  }

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  delay(1000);

  loadSettingsFromFirebase(true);

  Serial.println("Pornit.");
  Serial.println("IMPORTANT:");
  Serial.println("Pentru fiecare cutie, pune exact 1 produs si trimite s1/s2/s3");
  Serial.println("sau foloseste saveOneProductRequest din Firebase.");
  Serial.println();
  Serial.println("Comenzi Serial:");
  Serial.println("t1/t2/t3 = tare pe cutia goala");
  Serial.println("s1/s2/s3 = salveaza greutatea reala a unui produs");
  Serial.println("p = afiseaza setari");
  Serial.println();
}


void loop() {
  checkSerialCommands();
  if (millis() - lastCommandCheck >= COMMAND_CHECK_INTERVAL_MS) {
    lastCommandCheck = millis();
    checkFirebaseCommands();
  }
  if (millis() - lastSettingsRefresh >= SETTINGS_REFRESH_INTERVAL_MS) {
    lastSettingsRefresh = millis();
    loadSettingsFromFirebase(false);
  }
  for (int i = 0; i < 3; i++) {
    BoxData &b = boxes[i];

    updateMeasurement(b);
    updateLedStatus(i);

    if (millis() - b.lastPrint >= PRINT_INTERVAL_MS) {
      b.lastPrint = millis();

      Serial.printf(
        "%s | RAW=%ld | grame=%.1f g | oneProduct=%.1f g | qty=%d | candidat=%d | asteptat=%.1f g | eroare=%.1f g | marja=+/-%.1f g | valid=%s | red=%d | yellow=%d | max=%d\n",
        b.id,
        b.raw,
        b.grams,
        b.oneProductGrams,
        b.quantity,
        b.candidateQuantity,
        b.expectedGrams,
        b.errorFromExpected,
        b.allowedErrorGrams,
        b.measurementValid ? "DA" : "NU",
        b.redThreshold,
        b.yellowThreshold,
        b.maxStock
      );
    }

    if (millis() - b.lastFirebaseUpdate >= FIREBASE_INTERVAL_MS) {
      b.lastFirebaseUpdate = millis();
      updateBoxInFirebase(b);
    }
  }

  delay(100);
}