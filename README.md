# StockIQ – Smart Inventory Management System

An IoT inventory system that measures stock automatically with weight sensors, syncs it in real time through the cloud, and shows it in a mobile app with built-in consumption analytics and an AI assistant.

Bachelor's thesis project, Politehnica University of Timișoara (Automation and Applied Informatics, 2025–2026).

<img width="1536" height="662" alt="Picture1" src="https://github.com/user-attachments/assets/a7aea8eb-fbce-4531-b57a-0067c4058610" />
<img width="220" height="393" alt="Picture3" src="https://github.com/user-attachments/assets/4dacbd58-fde4-4a31-9e39-ed627d2e2090" />
<img width="194" height="393" alt="Picture4" src="https://github.com/user-attachments/assets/d7e86574-cec8-4231-b8bf-3585115f9617" />



## Problem

Small businesses, especially with a low number of products, often have a mismatch between the stock shown in their system and the real stock. Manual inventory takes time and is error-prone, which leads to delayed orders and lost sales. StockIQ removes the manual counting step: each box measures its own contents and reports them automatically.

## Architecture

```
┌──────────────────────┐   HTTPS (PATCH)   ┌──────────────────────────┐   live sync   ┌───────────────────┐
│  Smart box           │ ────────────────► │ Firebase Realtime        │ ◄───────────► │ Flutter mobile app │
│  ESP32 + HX711       │                   │ Database                 │               │ (StockIQ)          │
│  + load cell + LED   │ ◄──────────────── │                          │               │ + AI Insights      │
└──────────────────────┘   HTTPS (GET)     └──────────────────────────┘               │ + AI Assistant ────┼──► Gemini API
        commands (tare, calibration)                                                  └───────────────────┘
```

- **Hardware layer:** ESP32 reads a load cell through an HX711 24-bit ADC and drives WS2812B RGB LEDs (green / yellow / red) to signal the stock level locally.
- **Cloud layer:** Firebase Realtime Database is the single channel between device and app. There is no direct phone-to-hardware connection: the ESP32 pushes measurements and polls for commands.
- **Application layer:** Flutter app for monitoring, orders, QR scanning, box setup/calibration and statistics.

## How the stock is measured

1. The load cell measures the weight of the products in the box.
2. The HX711 amplifies and digitizes the signal.
3. The ESP32 computes the quantity from the raw reading:

```
Q = round( (RAW_current − RAW_empty) / rawPerGram / productWeight )
```

Negative values are clamped to zero. Several readings are averaged to reduce noise.

4. The value is sent to Firebase and displayed in the app. Each box is identified by a QR code.

## Data model (Firebase Realtime Database)

| Node | Content |
|---|---|
| `boxes` | state, weight, thresholds, calibration data |
| `products` | product information and thresholds |
| `orders` | purchase orders |
| `commands` | hardware commands (tare, calibration) |
| `stockHistory` | stock evolution over time |

## Mobile app features

- Authentication and main menu
- Real-time stock monitoring
- Purchase order creation and tracking
- QR code scanning to identify boxes and products
- Box initialization and calibration
- Statistics and charts

### AI Insights (local, rule-based)

Runs entirely inside the Flutter app, with no LLM and no cloud functions:

- **Product status:** OK / Low / Critical, compared against configured thresholds
- **Average consumption:** computed from the last 14 days of stock history
- **Days until depletion:** estimated from average daily consumption
- **AI Risk Score (0–100):** combines status, urgency and consumption history

### AI Assistant (Gemini API)

A conversational assistant for the warehouse, in Romanian:

1. The user asks a question (e.g. "What should I order today?")
2. The app builds a context from `boxes`, `products`, `orders` and `stockHistory`
3. Context and question are sent to `gemini-2.5-flash-lite`
4. The answer is displayed. The assistant is advisory only and never changes data automatically.

## Repository structure

```
StockIQ/
├── firmware/       # ESP32 code (HX711 reading and calibration, Wi-Fi, Firebase, LEDs)
├── mobile-app/     # Flutter application
├── docs/           # architecture diagram, photos, screenshots
└── README.md
```

## Setup

> Fill in the exact commands for your project.

**Firmware**
1. Copy `firmware/config.example.h` to `firmware/config.h` and set your Wi-Fi credentials and Firebase database URL.
2. Build and flash to the ESP32 (Arduino IDE / PlatformIO).
3. Run the calibration procedure (tare with the empty box, then a known weight).

**Mobile app**
1. Create a Firebase project with a Realtime Database and add your configuration to the app (see `mobile-app/README` or `config.example`).
2. Set your Gemini API key in the local config file (never commit it).
3. `flutter pub get` then `flutter run`.

## Limitations

- Low accuracy for products with too little consumption history
- Sensitive to how the weight is positioned in the box
- The AI Assistant requires an internet connection
- Prototype tested on a small number of boxes
- No automated physical handling mechanisms

## Future work

- Multi-warehouse support with centralized management
- Lot traceability and expiry dates with alerts
- Roles, access control and an activity log
- Additional sensors (temperature, humidity, motion)
- E-commerce platform integration for automatic stock sync
- Management dashboard with KPIs
- Moving the analytics and API-key handling to a backend service (for example on Azure) instead of the client

## Tech stack

ESP32 · HX711 · load cells · WS2812B · Firebase Realtime Database · Flutter · Gemini API · QR codes

## Author

Andreea-Denisa Schintee
