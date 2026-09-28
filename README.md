# Schintee_Andreea_Aplicatie_Practica_AIA_Licenta

## Proiect

**StockIQ - Sistem inteligent de inventariere**

## Repository cod sursă

Codul sursă complet al proiectului este disponibil la adresa:

```text
https://gitlab.upt.ro/andreea.schintee/schintee_andreea_aplicatie_practica_aia_licenta
```

Repository-ul conține codul sursă pentru aplicația mobilă Flutter și codul pentru ESP32.

---

# Pașii de compilare ai aplicației

## 1. Compilarea aplicației mobile Flutter

### Cerințe necesare

Pentru compilarea aplicației mobile sunt necesare:

- Flutter SDK instalat;
- Android Studio sau Visual Studio Code;
- Android SDK;
- emulator Android sau telefon Android conectat prin USB;
- conexiune la internet pentru instalarea dependențelor;

### Comenzi de compilare

Se deschide un terminal în directorul repository-ului și se intră în folderul aplicației mobile:

```bash
cd mobile-app
```

Se instalează dependențele proiectului:

```bash
flutter pub get
```

Se verifică dacă mediul Flutter este configurat corect:

```bash
flutter doctor
```

Se compilează/rulează aplicația în modul debug:

```bash
flutter run
```

Pentru generarea unui fișier APK se folosește comanda:

```bash
flutter build apk
```

Fișierul APK generat se va afla în directorul:

```text
mobile-app/build/app/outputs/flutter-apk/
```


## 2. Compilarea codului pentru ESP32

### Cerințe necesare

Pentru compilarea codului ESP32 sunt necesare:

- Arduino IDE sau PlatformIO;
- suportul pentru plăcile ESP32 instalat;
- placa ESP32 conectată prin USB;
- bibliotecile necesare pentru Wi-Fi, Firebase, HX711 și WS2812B/NeoPixel.

### Pași de compilare în Arduino IDE

1. Se deschide Arduino IDE.
2. Se deschide fișierul principal `.ino` din folderul:

```text
esp32/
```

3. Se selectează placa ESP32 din meniul:

```text
Tools → Board
```

4. Se selectează portul corespunzător din meniul:

```text
Tools → Port
```

5. Se instalează bibliotecile necesare din Library Manager.
6. Se completează local datele de conectare Wi-Fi și Firebase.
7. Se apasă butonul:

```text
Verify / Compile
```

8. Dacă nu apar erori, codul este compilat cu succes.

### Pași de upload pe ESP32

După compilare, programul se încarcă pe placă apăsând:

```text
Upload
```

După finalizarea încărcării, se deschide:

```text
Serial Monitor
```

pentru verificarea conectării la Wi-Fi și Firebase.

---

# Pașii de instalare ai aplicației

## 1. Instalarea aplicației mobile

Există două variante de instalare.

### Varianta 1: Instalare prin Flutter, pentru testare

1. Se clonează repository-ul:

```bash
git clone https://gitlab.upt.ro/andreea.schintee/schintee_andreea_aplicatie_practica_aia_licenta
```

2. Se intră în folderul aplicației:

```bash
cd schintee_andreea_aplicatie_practica_aia_licenta/mobile-app
```

3. Se instalează dependențele:

```bash
flutter pub get
```

4. Se conectează un telefon Android prin USB sau se pornește un emulator.

5. Se instalează și rulează aplicația cu:

```bash
flutter run
```

### Varianta 2: Instalare prin APK

1. Se generează APK-ul:

```bash
cd mobile-app
flutter build apk
```

2. Fișierul APK rezultat se copiază pe telefonul Android.

3. Pe telefon se permite instalarea aplicațiilor din surse externe, dacă este necesar.

4. Se deschide fișierul APK și se instalează aplicația.

---

## 2. Instalarea/configurarea componentei ESP32

1. Se instalează Arduino IDE sau PlatformIO.
2. Se instalează suportul pentru plăci ESP32.
3. Se instalează bibliotecile necesare proiectului.
4. Se conectează placa ESP32 la calculator prin USB.
5. Se configurează local datele Wi-Fi și Firebase.
6. Se compilează și se încarcă programul pe ESP32.
7. Se verifică funcționarea în Serial Monitor.

---

# Pașii de lansare ai aplicației

## 1. Lansarea aplicației mobile

Pentru lansarea aplicației în modul de dezvoltare:

```bash
cd mobile-app
flutter run
```

Aplicația se va deschide pe emulatorul Android sau pe telefonul conectat prin USB.

Dacă aplicația a fost instalată prin APK, aceasta se lansează direct de pe telefon, apăsând pictograma aplicației StockIQ.

---

## 2. Lansarea componentei ESP32

1. Se conectează ESP32 la alimentare sau la calculator prin USB.
2. Programul încărcat anterior pornește automat.
3. ESP32 se conectează la rețeaua Wi-Fi configurată.
4. ESP32 citește valorile de la senzorii de greutate prin modulele HX711.
5. Datele sunt transmise către Firebase Realtime Database.
6. LED-urile WS2812B indică vizual nivelul stocului.
7. Funcționarea poate fi verificată în Serial Monitor.

---

## 3. Lansarea completă a sistemului StockIQ

Pentru utilizarea completă a sistemului se urmează pașii:

1. Se pornește/conectează ESP32.
2. Se verifică în Serial Monitor conectarea la Wi-Fi.
3. Se verifică în Firebase Realtime Database că datele sunt actualizate.
4. Se lansează aplicația mobilă StockIQ.
5. Se verifică afișarea produselor și a cantităților în aplicație.
6. Se testează scanarea codurilor QR.
7. Se testează modificarea stocurilor prin adăugarea sau eliminarea produselor din cutii.
8. Se verifică semnalizarea LED-urilor pentru nivelul de stoc.
9. Se testează funcționalitățile de comenzi, statistici și AI Assistant.

