# EventHub Mobile (Flutter)

Aplicación móvil oficial de **EventHub** para la compra exclusiva de entradas y gestión de tickets digitales con soporte para la pasarela automatizada **BNB QR Simple** (Banco Nacional de Bolivia), billetera local sin login y exportación nativa a **Apple Wallet** y **Google Wallet**.

---

## Características Principales

1. **Catálogo de Eventos (`events_screen.dart`)**:
   - Visualización de eventos activos con flyers, fechas, ubicación y precios mínimos en Bs.
   - Filtro por categorías.
   - Acceso directo a la billetera **Mis Entradas**.

2. **Detalle y Selección de Sectores (`event_detail_screen.dart`)**:
   - Ficha completa del evento.
   - Selector de sectores (`General`, `VIP`, etc.) con cupos disponibles y cálculo de subtotal en tiempo real.
   - Contador de cantidad de entradas.

3. **Registro Nominal de Asistentes (`checkout_screen.dart`)**:
   - Datos del comprador.
   - Registro de **Nombre Completo** y **C.I. / Carnet de Identidad** por cada entrada adquirida (requerido para el algoritmo criptográfico de validación de EventHub).

4. **Pasarela de Pago BNB QR Simple (`bnb_payment_screen.dart`)**:
   - Muestra el código QR Simple en Base64 emitido por el BNB en alta calidad y alto contraste.
   - Monto en Bolivianos (BOB) y glosa bancaria.
   - Cuenta regresiva de expiración (15 min).
   - **Botón interactivo "Ya realicé el pago"**: Consulta inmediata a la API del banco.
   - **Sondeo automático suave**: Verifica en segundo plano cada 4 segundos sin bloquear la pantalla.

5. **Billetera Offline sin Contraseñas (`tickets_screen.dart`)**:
   - Las compras se guardan automáticamente en el dispositivo (`SharedPreferences`).
   - Cero fricción: el usuario no necesita crearse cuentas ni recordar contraseñas.
   - Accesible en la puerta del evento incluso **sin conexión a internet**.
   - Renderizado del código QR criptográfico de acceso en pantalla completa para ser escaneado por el personal de puerta (`/admin/scanner`).

6. **Integración con Billeteras Nativas (Apple & Google Wallet)**:
   - En **iOS**: Botón *"Añadir a Apple Wallet"* (archivo `.pkpass`).
   - En **Android**: Botón *"Añadir a Google Wallet"* (Google Pay Passes API).

---

## Cómo Ejecutar la Aplicación

### 1. Instalar dependencias
```bash
cd EventHub_mobile
flutter pub get
```

### 2. Configuración del Servidor Backend
Por defecto, la app detecta automáticamente el host:
* **En Emulador Android**: Se conecta automáticamente a `http://10.0.2.2:4000/api`.
* **En iOS Simulator / Web / Desktop**: Se conecta a `http://localhost:4000/api`.
* **En Celular Físico (WiFi)**: Ejecutá indicando la IP de tu computadora en tu red local:
  ```bash
  flutter run --dart-define=API_URL=http://192.168.1.50:4000/api
  ```
  *(O usando `ApiConfig.setCustomHost("http://192.168.1.50:4000/api")` en `main.dart`)*.

### 3. Compilar APK para pruebas
```bash
flutter build apk --debug
# El APK se genera en: build/app/outputs/flutter-apk/app-debug.apk
```
