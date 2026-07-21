# 📘 คู่มือเตรียมสัมภาษณ์ Flutter Developer (AIS)

> สรุปจากการวิเคราะห์โปรเจกต์ Fullstack_ecommerceApp + Q&A concept ทั้งหมด
> อัพเดทล่าสุด: กรกฎาคม 2026

---

## สารบัญ

1. [ภาพรวมโปรเจกต์: จุดแข็ง](#1-จุดแข็งของโปรเจกต์)
2. [จุดอ่อนเดิม + การ Refactor ที่ทำไปแล้ว](#2-จุดอ่อนเดิม--สิ่งที่-refactor-แล้ว)
3. [Multi-Environment & Flavors](#3-multi-environment--flavors)
4. [Q&A Concept รายตัว](#4-qa-concept-รายตัว)
5. [เทียบ Riverpod ↔ BLoC ↔ GetX](#5-เทียบ-riverpod--bloc--getx)
6. [Concept ที่โปรเจกต์ยังไม่มี (ต้องอ่านเพิ่ม)](#6-concept-ที่ยังไม่มีในโปรเจกต์)
7. [คำถามสัมภาษณ์ที่คาดว่าจะโดน + แนวตอบ](#7-คำถามสัมภาษณ์ที่น่าจะโดนถาม)

---

# 1. จุดแข็งของโปรเจกต์

เปิดด้วยพวกนี้เวลาโดนถาม **"เล่าโปรเจกต์ให้ฟังหน่อย"**

- **Feature-first clean architecture** — `lib/features/<feature>/{model, repository, provider, screen}` + `lib/core`
  พูดคำว่า *"separation of concerns — แยก UI, state, data layer"*
- **Riverpod state management** — `NotifierProvider` (auth), `AsyncNotifierProvider` (cart),
  `FutureProvider` (products), `FutureProvider.family` (product detail)
  จุดเด็ด: `productsProvider` watch `categoryProvider` + `searchProvider` → เปลี่ยน filter แล้ว refetch อัตโนมัติ (declarative dependency graph)
- **GoRouter + auth guard รวมศูนย์** — `redirect` เดียวคุมทั้งแอพ, role-based routing (admin/user),
  **open-redirect protection** ใน `postLoginLocation` (reject URL ที่มี scheme/authority หรือ `//`) — พูดเองไม่ต้องรอถาม เป็นแต้มใหญ่สำหรับ telecom
- **Networking** — Dio interceptor แนบ Bearer token อัตโนมัติ, จัดการ 401 แบบ state-driven,
  base-URL failover เฉพาะ dev, JWT เก็บใน `flutter_secure_storage` (Keychain/EncryptedSharedPreferences)
- **Dart 3 สมัยใหม่** — records `({String token, UserModel user})`, sealed classes, switch expressions
- **UI quality** — `AsyncValue.when` ครบ loading/error/data, `friendlyError()` ไม่โชว์ raw exception,
  slivers + builder delegates (lazy), `ValueKey` บน `Dismissible`, `cached_network_image`, dark mode, EN/TH
- **มีเทสจริง 31 ตัว** — provider tests (ProviderContainer + override), widget tests, router guard tests

---

# 2. จุดอ่อนเดิม + สิ่งที่ Refactor แล้ว

> 💡 สตอรี่ทรงพลังตอนสัมภาษณ์: *"ผม review โค้ดตัวเองเจอจุดอ่อนพวกนี้ แล้วลงมือ refactor แก้แล้ว"*

## ✅ แก้แล้ว

| จุดอ่อนเดิม | สิ่งที่แก้ |
|---|---|
| `AuthState` เป็น boolean-flag soup (`loading`, `bootstrapped`, `user?` ประกอบเป็น state ที่เป็นไปไม่ได้) | **Sealed class hierarchy**: `AuthInitial / Authenticating / Authenticated / Unauthenticated` — impossible states เขียนไม่ได้ตั้งแต่ compile |
| `DioClient` static singleton — mock ไม่ได้ ทำลาย DI | **`dioProvider`** + repository รับ `Dio` ผ่าน **constructor injection** — เทสด้วย `overrideWithValue` ได้ |
| Interceptor 401 navigate เองผ่าน GlobalKey (data layer สั่ง UI) | 401 → แจ้ง `AuthNotifier.handleUnauthorized()` → state เปลี่ยน → **router redirect ตาม state** (และไม่ทำงานตอน login ล้มเหลว เพราะรหัสผิด ≠ session หมดอายุ) |
| Business logic ใน `CartScreen` (เรียก repository ตรง + invalidate ทุกครั้ง) | **`CartNotifier` (AsyncNotifier)** พร้อม **optimistic update + rollback** เมื่อ fail |
| `StateNotifier` (legacy Riverpod) | Migrate เป็น `Notifier` / `AsyncNotifier` (Riverpod 2.x) |
| `analysis_options.yaml` แทบว่าง | เปิด `strict-casts / strict-inference / strict-raw-types` + lint เพิ่ม, analyze = 0 issues |
| `flutter_hooks`/`hooks_riverpod` ค้างใน pubspec แต่ไม่ได้ใช้ | ลบทิ้งแล้ว |
| Base-URL failover มี recursive retry risk | ใส่ flag กัน retry ซ้อน + ปิดตัวเองเมื่อมี `API_BASE_URL` |
| มี environment เดียว | เพิ่ม **dev/staging/prod** ผ่าน `--dart-define-from-file` (ดูหัวข้อ 3) |

## ⏳ ยังไม่แก้ (เตรียมคำตอบ "ผมรู้ และจะแก้แบบนี้")

- **i18n เขียนเอง** — `tr(ref, 'EN', 'ไทย')` ใช้ได้แต่ไม่ scale → ของจริงคือ **ARB files + `flutter gen-l10n`** (มี plural/ICU) — บริษัทไทยถามแน่
- **Theming ไม่สม่ำเสมอ** — มี hardcode `AppTheme.primary`, `Colors.white` ปนกับ `colorScheme` → ควรผ่าน `Theme.of(context)` ทั้งหมด
- **ไม่มี pagination** — repo รองรับ page/limit แล้วแต่ UI ยังไม่ infinite scroll
- **ไม่มี refresh token** — token หมดอายุ = บังคับ logout
- **ไม่มี crash reporting** — `FlutterError.onError` + Crashlytics/Sentry
- **fromJson เขียนมือ** — พูดถึง `freezed` + `json_serializable` + `build_runner` ได้
- **ไม่มี debounce ตอน search**, ไม่มี `select()` ลด rebuild ของ cart badge

---

# 3. Multi-Environment & Flavors

## ที่ทำแล้ว: `--dart-define-from-file`

```
frontend/env/dev.json      → APP_ENV=dev (localhost + failover)
frontend/env/staging.json  → APP_ENV=staging + API_BASE_URL test server
frontend/env/prod.json     → APP_ENV=prod + API_BASE_URL production
```

```bash
flutter run --dart-define-from-file=env/dev.json
flutter build apk --dart-define-from-file=env/prod.json
```

กฎในโค้ด (`lib/core/config/env_config.dart`):
- staging/prod **ไม่มี URL → throw ตอนเปิดแอพ (fail fast)** — กัน prod ยิง localhost เงียบ ๆ
- build ที่ไม่ใช่ prod มี**แถบมุมจอ DEV/STAGING** ให้ QA รู้ว่าเทสกับ server ไหน
- ค่าเป็น compile-time constant อ่านผ่าน `String.fromEnvironment`

## Flavors คืออะไร (ขั้นกว่า — ระดับ native)

| | dart-define-from-file | Flavors |
|---|---|---|
| ระดับ | Dart เท่านั้น | Native (Gradle / Xcode) |
| Application ID | ตัวเดียว | คนละตัวได้ (`com.app.dev` / `com.app`) |
| ลง dev+prod คู่กันในเครื่อง | ❌ | ✅ |
| ชื่อแอพ/ไอคอนแยก | ❌ | ✅ |
| `google-services.json` แยก env | ❌ | ✅ (วางใน `src/dev/`, `src/prod/`) |

```groovy
// android/app/build.gradle
android {
  flavorDimensions "environment"
  productFlavors {
    dev  { dimension "environment"; applicationIdSuffix ".dev" }
    prod { dimension "environment" }
  }
}
```

```bash
flutter run --flavor dev --target lib/main_dev.dart
```
- `--flavor` เลือกฝั่ง native / `--target` เลือก Dart entrypoint (main_dev.dart, main_prod.dart)
- iOS ใช้ **Xcode scheme + build configuration** ชื่อตรงกับ flavor
- 3 ระดับจำง่าย: **dart-define** (เบา) → **flavors** (native) → **remote config** (สลับหลัง deploy)

---

# 4. Q&A Concept รายตัว

## 4.1 Dio คืออะไร?

- **คืออะไร**: HTTP client — ทำหน้าที่แบบ `http` package แต่มี **Interceptor, BaseOptions (baseUrl/timeout รวมศูนย์), DioException แยก type, CancelToken, JSON auto-parse**
- **ทำไม**: งานที่ต้องทำกับ "ทุก request" (แนบ token, จัดการ 401, log) ควรเขียนที่เดียวใน interceptor ไม่ใช่ copy ทุก endpoint
- **เมื่อไหร่**: ทุกโปรเจกต์ที่ยิง API จริงจัง

```dart
class AuthTokenInterceptor extends Interceptor {
  @override
  Future<void> onRequest(options, handler) async {
    final token = await storage.read(key: 'token');
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);   // ปล่อย request วิ่งต่อ (next/resolve/reject)
  }
  @override
  void onError(DioException err, handler) {
    if (err.response?.statusCode == 401) onUnauthorized();
    handler.next(err);
  }
}
```

## 4.2 Provider (Riverpod) คืออะไร?

- **คืออะไร**: กลไกทำ 2 หน้าที่ — (1) **แชร์ state แบบ reactive** (widget watch แล้ว rebuild เอง) (2) **Dependency Injection** (ฉีด object สลับตัวปลอมตอนเทสได้)
- ชนิดที่ใช้ในโปรเจกต์:

| ชนิด | ใช้กับ | ตัวอย่างในโปรเจกต์ |
|---|---|---|
| `Provider` | object นิ่ง ๆ (DI) | `dioProvider`, `authRepositoryProvider` |
| `StateProvider` | ค่า simple UI แก้ตรง ๆ | `categoryProvider`, `searchProvider` |
| `FutureProvider` | โหลดข้อมูล async (ได้ AsyncValue ฟรี) | `productsProvider` |
| `FutureProvider.family` | async + parameter (cache แยกตาม key) | `productDetailProvider(id)` |
| `NotifierProvider` | state มี business logic | `authProvider` |
| `AsyncNotifierProvider` | state async + มี method | `cartProvider` |

- **กฎ**: `ref.watch` ใน build (subscribe → rebuild), `ref.read` ใน callback (อ่านครั้งเดียว)
- ประโยคเด็ด: **"Riverpod = state sharing + async handling + DI ในตัวเดียว"**

## 4.3 DI (Dependency Injection) คืออะไร?

- **คืออะไร**: class **ไม่สร้าง dependency เอง แต่รับจากข้างนอก** — จุดชี้วัด: *สลับเป็นตัวปลอมตอนเทสได้โดยไม่แก้โค้ดข้างในไหม?*
- ⚠️ **DI ≠ import/export** — import คือแชร์"โค้ด" DI คือแชร์"instance แบบสลับได้"

```dart
// ❌ ไม่ใช่ DI — ผูกตายกับ singleton
class AuthRepository { Future<User> me() => DioClient.dio.get('/users/me'); }

// ✅ DI — constructor injection
class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;
}
// ตอนเทส: AuthRepository(mockDio)
```

- **4 รูปแบบใน Flutter**: (1) Constructor injection (พื้นฐาน ดีสุด) (2) Provider-based (Riverpod — ที่ใช้อยู่) (3) Service locator (`get_it`+`injectable` — คู่กับ BLoC, หรือ `Get.find` ของ GetX) (4) InheritedWidget (กลไกดิบที่ Provider ครอบไว้)
- **ทำไม**: Testability / สลับ env / Decoupling

## 4.4 compute() = multi-thread จริงไหม?

- **ใช่ — เป็น parallelism จริง ไม่ใช่ lazy load** — spawn **Isolate** ใหม่ = Dart runtime อีกตัว มี thread + memory heap + event loop ของตัวเอง
- **`async/await` vs `compute()`**:
  - `await` = "รอโดยไม่ block" — เหมาะกับ **I/O-bound** (network, file) — ตอนรอคืน thread ให้ event loop
  - `compute` = "เอางานไปทำที่อื่น" — เหมาะกับ **CPU-bound** (parse JSON ใหญ่, ย่อรูป, เข้ารหัส)
  - งาน CPU หนักใน async **ยังค้าง UI อยู่ดี** เพราะกิน CPU บน thread เดิม
- **กฎ**: งาน CPU เกิน ~16ms (งบต่อเฟรม 60fps) → ย้ายไป compute
- Isolate **ไม่แชร์ memory** — สื่อสารด้วย message passing (copy ข้อมูลข้าม) → ไม่มี race condition by design → Dart เลยไม่มี `synchronized`
- ตัวอื่นในตระกูล: `Isolate.run()` (ใหม่กว่า ใช้ closure ได้), `Isolate.spawn` (isolate อายุยาว คุยผ่าน SendPort/ReceivePort)
- **เทียบ ExecutorService (Android)**: เป้าหมายเดียวกัน แต่ ExecutorService = shared-memory threading (ต้องคุม lock เอง) ส่วน Isolate = **Actor Model** (แยก memory ขาด) — ไม่ได้ base on กัน, Dart VM จัดการ OS thread เอง ไม่ผ่าน JVM

```dart
List<Product> parseProducts(String json) { ... }  // ต้อง top-level/static
final products = await compute(parseProducts, jsonString);
```

## 4.5 UI Thread กับ GPU

- Flutter engine มี **4 threads**: Platform / **UI** (รัน Dart) / **Raster** / IO (decode รูป)
- Pipeline ต่อเฟรม: UI thread รัน `build` → layout → paint (ผลิต "ใบสั่งวาด" layer tree — งาน CPU) → Raster thread แปลงเป็นคำสั่ง GPU ผ่าน **Impeller** (Vulkan บน Android, Metal บน iOS) → **GPU วาดพิกเซลจริง**
- **GPU ถูกใช้เต็มที่อยู่แล้ว** — แต่ไม่ใช่โดย UI thread และ Dart รันบน GPU ไม่ได้
- **Jank มี 2 สายพันธุ์**:
  - **UI thread jank** (CPU) — Dart ทำงานเกิน 16ms → แก้ด้วย const, แตก widget, Isolate
  - **Raster jank** (GPU) — blur/`saveLayer`/Opacity ซ้อน/รูปใหญ่ → แก้ด้วยลด effect, `RepaintBoundary`, `cacheWidth` — **Isolate ช่วยเคสนี้ไม่ได้**
  - ดูจาก DevTools frame timeline ว่าแถบไหนพุ่ง
- ทำไมเปลี่ยน Skia → Impeller: แก้ **shader compilation jank** (กระตุกครั้งแรก) โดย precompile shader ตอน build
- Dev จิ้ม GPU ตรง ๆ ได้ผ่าน **fragment shader** (`FragmentProgram.fromAsset`)

## 4.6 @override คืออะไร?

- **คืออะไร**: annotation บอก analyzer ว่า *"ตั้งใจเขียนทับสมาชิกของ superclass"* — **ไม่มีผลตอน runtime**
- **ทำไม**: กันสะกดผิด/signature ไม่ตรง — ถ้าพิมพ์ `onErorr` โดยไม่มี @override → กลายเป็น method ใหม่เงียบ ๆ interceptor ไม่ถูกเรียกเลยและไม่มี error บอก / ใส่แล้ว analyzer ฟ้องทันที
- **เมื่อไหร่**: ทุกครั้งที่ override — `build`, `initState`, `dispose`, `toString`, `==`, `hashCode`, contract ของ library (Interceptor), getter ของ sealed class

## 4.7 super.key คืออะไร?

- **คืออะไร**: super parameter — "รับ `key` แล้วส่งต่อให้ constructor ของ class แม่ (Widget) ทันที"
- ย่อจาก `const MyWidget({Key? key}) : super(key: key);`
- **key** = ป้าย identity ที่ Flutter ใช้จับคู่ widget ↔ element เดิมตอน rebuild (ตัวเดียวกับ `ValueKey(productId)` บน Dismissible)
- **เมื่อไหร่**: ทุก public widget constructor (lint `use_key_in_widget_constructors` บังคับ)

## 4.8 var / final / const / late และปริศนา `state = ...`

| Keyword | ความหมาย |
|---|---|
| `var` | ให้ Dart เดา type, แก้ค่าได้ |
| `final` | กำหนดครั้งเดียวตอน **runtime** แล้วห้ามแก้ |
| `const` | คงที่ตั้งแต่ **compile time** |
| `late` | สัญญาว่าจะใส่ค่าก่อนใช้ (พลาด = crash) — ใช้น้อยที่สุด |

- หลักเลือก: **const > final > var** (lint `prefer_final_locals`)
- **`state = const Authenticating()` ไม่ใช่การประกาศตัวแปร!** — `state` เป็น **property (getter+setter) ที่ inherit จาก `Notifier<T>`** — การ assign คือเรียก setter ซึ่งแอบ**แจ้งทุก subscriber ให้ rebuild** ด้วย
- `const` หน้า constructor (`const Authenticating()`) = **const object** (canonical instance — สร้างครั้งเดียว reuse ตลอด) ไม่ใช่ const ตัวแปร

## 4.9 "Subscribe" คืออะไร?

- **คืออะไร**: ลงทะเบียนขอถูกแจ้งเตือนเมื่อมีข้อมูล/เหตุการณ์ใหม่ (**Observer pattern**, push แทน pull) — เหมือนกดกระดิ่ง YouTube
- หน้าตาใน Flutter:
  - `ref.watch(provider)` = subscribe provider → rebuild เมื่อเปลี่ยน (`ref.read` = ไม่ subscribe)
  - `ref.listen` = subscribe แบบทำ side effect (snackbar) ไม่ rebuild
  - `stream.listen()` → ได้ `StreamSubscription` — **ต้อง `.cancel()` ใน dispose ไม่งั้น memory leak**
  - `ChangeNotifier.addListener/removeListener` (TextEditingController, ScrollController)
- Riverpod / StreamBuilder จัดการ unsubscribe ให้อัตโนมัติ — เหตุผลที่ควรใช้ declarative builder แทน listen เอง

## 4.10 Parent ↔ Child: "Data down, Events up"

- **ข้อมูลไหลลง**ทางเดียวผ่าน constructor — child แก้ค่าใน parent ตรง ๆ ไม่ได้
- **แต่ child สื่อสารขึ้นได้ผ่าน callback** ที่ parent ส่งลงมาให้เรียก:

```dart
// PARENT — เจ้าของ state
_CartFooter(
  selectedTotal: selectedTotal,          // ⬇️ data ลง
  onSelectAll: (checked) => setState(...) // ⬇️ ส่งฟังก์ชันลง
)
// CHILD — ไม่รู้จัก parent เลย
Checkbox(onChanged: (v) => onSelectAll(v ?? false))  // ⬆️ event ขึ้น
```

- **Lifting state up**: state อยู่ที่บรรพบุรุษร่วมต่ำสุดของทุกคนที่ใช้มัน
- tree ลึกจน prop drilling → Provider/InheritedWidget (ยังนับเป็นไหล "ลง" แค่ข้ามชั้น)
- ช่องทางไหล "ขึ้น" พิเศษ: **NotificationListener** (ScrollNotification bubble ขึ้น), **GlobalKey** (parent เอื้อมจับ child ตรง ๆ — ใช้น้อยที่สุด เช่น `formKey.currentState.validate()`)

## 4.11 Stream (สำคัญมากถ้าทีมใช้ BLoC)

- **คืออะไร**: **async sequence** — `Future` ให้ค่า 1 ครั้ง / `Stream` ให้ 0..∞ ค่า ตามเวลา + error + done
- สร้าง: `StreamController` (ยัดค่าเอง `add/close`) หรือ `async* + yield` (ฟังก์ชันทยอยคายค่า)
- บริโภค: `.listen()` (manual — ต้อง cancel) / `await for` / `StreamBuilder` (widget, auto-unsubscribe)
- **BLoC ทั้งตัวคือ Stream**: event เข้า → bloc แปลง → `Stream<State>` ออก → `BlocBuilder` subscribe
  - `emit(state)` ของ BLoC = `state = ...` ของ Notifier — ต่างแค่กลไกข้างใต้เป็น stream ตรง ๆ
- ใช้กับ: BLoC, WebSocket, GPS, onAuthStateChanged, debounced search — ❌ API ครั้งเดียวจบใช้ Future พอ

## 4.12 ListView.builder — มากกว่า lazy load

1. **Lazy สองทาง**: สร้างเฉพาะใน viewport **และ dispose ตัวที่หลุดจอ** — memory คงที่ไม่ว่า list ยาวแค่ไหน
   - ผลข้างเคียง: **state ของ item ที่หลุดจอหาย** → ยก state ขึ้น parent (แบบ `selectedProductIds` ใน CartScreen) หรือ `AutomaticKeepAliveClientMixin`
2. **cacheExtent** (~250px): สร้างเผื่อนอกจอ กัน item โผล่ขาว ๆ ตอนเลื่อน
3. **ของแถมอัตโนมัติ**: ครอบ `RepaintBoundary` ให้ทุก item (repaint ไม่ลามทั้ง list), keepAlive support
4. **ตัวจริงคือ Sliver**: `ListView` = `CustomScrollView` + `SliverList` สำเร็จรูป
5. Optimization เพิ่ม: `itemExtent`/`prototypeItem` — item สูงเท่ากันบอกไปเลย ข้าม layout pass

## 4.13 GridView.builder

- = `ListView.builder` เวอร์ชันหลายคอลัมน์ — lazy เหมือนกันทุกอย่าง ต่างแค่เพิ่ม **`gridDelegate`**:
  - `SliverGridDelegateWithFixedCrossAxisCount` — ล็อกจำนวนคอลัมน์ (จอใหญ่ช่องบาน)
  - `SliverGridDelegateWithMaxCrossAxisExtent` — ล็อกความกว้างช่อง → **responsive ฟรี** (มือถือ 2 คอลัมน์ / tablet 4 คอลัมน์ อัตโนมัติ ไม่ต้อง MediaQuery)
- โปรเจกต์นี้ใช้ `SliverGrid` + `SliverChildBuilderDelegate` ตรง ๆ ใน `CustomScrollView` เพราะหน้า Home มี header + search + chips ต้อง**เลื่อนร่วมผืนเดียว**กับ grid
- Grid แบบช่องไม่เท่ากัน (Pinterest) → package `flutter_staggered_grid_view`

## 4.14 Widget ทำงานยังไง (พื้นฐานที่โดนถามแน่)

- **3 trees**: Widget (immutable config — พิมพ์เขียว) / Element (ตัวกลางอายุยาว จับคู่เก่า-ใหม่) / RenderObject (layout + paint จริง)
- rebuild ไม่ได้วาดใหม่หมด — เทียบ type + key ถ้าตรงกัน update ค่าเฉย ๆ
- **BuildContext = Element ของ widget นั้นเอง** — ใช้ lookup ของเหนือเรา (`Theme.of`, `Navigator.of`) — ห้ามใช้หลัง `await` โดยไม่เช็ค `context.mounted`
- **State lifecycle**: `createState → initState → didChangeDependencies → build → (setState → build) → didUpdateWidget → dispose`
- **Keys**: รักษา identity ใน list ที่เปลี่ยน (`ValueKey`) / `GlobalKey` ใช้เท่าที่จำเป็น / ห้าม `UniqueKey` ใน build
- **const constructor**: สร้างครั้งเดียวตอน compile + Flutter skip rebuild subtree นั้น — optimization ที่ถูกที่สุด

## 4.15 Performance checklist

- const widgets, แตก widget เป็น class (ไม่ใช่ `_buildXxx()` method — class แยกได้ element + const ได้)
- `ref.watch(provider.select(...))` — rebuild เฉพาะ field ที่ใช้
- builder-based lists (ListView.builder / SliverGrid)
- รูป: cache + `memCacheWidth`/`cacheWidth` decode เท่าที่แสดง
- ห้ามงานหนักใน `build` (sort/filter → ไปทำใน provider)
- `RepaintBoundary` ครอบส่วนที่ repaint บ่อย
- วัดด้วย DevTools: frame timeline (UI vs Raster), rebuild stats

## 4.16 Testing

- **3 ระดับ**: unit (logic ล้วน) / widget (pump + interact) / integration (เครื่องจริงทั้ง flow)
- เทส provider: `ProviderContainer` + `overrides: [repoProvider.overrideWithValue(fake)]` — ไม่ยิง network จริง
- ยึด pattern: ทุก state transition มีเทสทั้ง success และ failure path (เช่น optimistic update ต้องเทสว่า rollback จริง)
- ที่ยังไม่มี: golden tests, integration_test, CI pipeline

---

# 5. เทียบ Riverpod ↔ BLoC ↔ GetX

> AIS มีแนวโน้มใช้ **BLoC + freezed + get_it/injectable + dio** (บริษัทใหญ่ไทยนิยม เพราะ event→state มี audit trail)

| หลักการ | Riverpod (โปรเจกต์เรา) | BLoC | GetX |
|---|---|---|---|
| State container | `Notifier`/`AsyncNotifier` | `Bloc<Event, State>` | `GetxController` |
| สั่งเปลี่ยน state | เรียก method → `state = ...` | ส่ง **event** → bloc `emit(state)` | แก้ `.obs` / `update()` |
| UI consumer | `ref.watch` / ConsumerWidget | `BlocBuilder` | `Obx` / `GetBuilder` |
| Side effect (snackbar) | `ref.listen` | `BlocListener` | `ever()` / `once()` |
| Selector | `provider.select(...)` | `BlocSelector` / `buildWhen` | `GetBuilder` + id |
| DI | Provider graph | `get_it` + `injectable` | `Get.put` / `Get.find` |
| Testing | `ProviderContainer` | `blocTest()` | controller ตรง ๆ |

**ประโยคทอง**: *"ผมเลือก Riverpod เพราะ compile-safe DI และ provider composition แต่ architecture — sealed state, repository layer, injected dependencies, unidirectional flow — เหมือนกันหมดทุกตัว state container เป็นแค่ detail ครับ การวาง layer ต่างหากคือ skill"*

**GetX**: เร็วแต่แลกด้วย implicit global state + เทสยาก — อย่าด่า ให้พูดว่า *"เหมาะ prototype ผมชอบ explicit DI สำหรับ team codebase มากกว่า"*

**การบ้านก่อนสัมภาษณ์**: ลองเขียน `AuthBloc` (events: `AuthBootstrapRequested`, `LoginRequested`, `LogoutRequested`) + 1 `blocTest` — วาด flow ทั้งสองแบบบนกระดาษได้ = สัญญาณแรงสุด

---

# 6. Concept ที่ยังไม่มีในโปรเจกต์

เรียงตามโอกาสโดนถาม (ควรอ่านเพิ่ม):

1. **Streams & StreamBuilder** — พื้นของ BLoC (สรุปไว้แล้วใน 4.11 — ซ้อมเขียน StreamController + countdown จากมือเปล่า)
2. **Isolates & compute()** — สรุปใน 4.4 — ซ้อมตอบปากเปล่า "parse JSON 10MB ไม่ให้ UI ค้าง"
3. **Animations** — บันได: implicit (`AnimatedContainer`) → `AnimationController` + `Tween` + `AnimatedBuilder` → `Hero`
4. **Codegen**: `freezed` + `json_serializable` + `build_runner` — enterprise ใช้กันแทบทุกที่
5. **ARB l10n** (`flutter gen-l10n`) — บริษัทไทยถามเรื่อง TH/EN แน่นอน
6. **Local persistence** — `shared_preferences` (settings) / Hive / sqflite / Drift (offline cache)
7. **Platform channels** — `MethodChannel` คุยกับ Kotlin/Swift
8. **Push notifications (FCM) + flavors**
9. **Integration/golden tests + CI** (GitHub Actions: analyze + test)
10. **Rendering internals** — 3 trees, BuildContext = Element, RepaintBoundary, DevTools (สรุปใน 4.5, 4.14)
11. **WebSockets/gRPC** — telco ชอบ real-time (รู้จัก `web_socket_channel` + วางใน repository เป็น stream)

---

# 7. คำถามสัมภาษณ์ที่น่าจะโดนถาม

1. **"ทำไม Riverpod ไม่ใช่ BLoC/GetX?"** → compile-safe, ProviderContainer เทสได้, auto-dispose, composition + *"พร้อมปรับไป BLoC เพราะ architecture เดียวกัน"*
2. **"อธิบาย auth flow ต้นจนจบ"** → bootstrap → อ่าน token จาก secure storage → เช็ค `exp` → `/users/me` → router redirect ตาม sealed state (วาดได้จากความจำ — แตะครบ storage/network/state/routing)
3. **"ลด rebuild ยังไง?"** → const, แตก widget class, select, builder delegates, RepaintBoundary
4. **"Stateless vs Stateful / setState เมื่อไหร่?"** → CartScreen: selection = local setState, server data = Riverpod (local vs shared)
5. **"เทส provider ยังไง?"** → ProviderContainer + overrideWithValue (มีไฟล์จริง `auth_provider_test.dart`, `cart_provider_test.dart`)
6. **"Key มีไว้ทำไม?"** → `ValueKey(productId)` บน Dismissible — identity ใน list ที่เปลี่ยน
7. **"จัดการหลาย environment ยังไง?"** → dart-define-from-file + fail fast + banner (หัวข้อ 3) → ขั้นกว่า: flavors, remote config
8. **Security (telco ถามแน่)** → secure storage ≠ SharedPreferences / HTTPS + cert pinning (dev เป็น HTTP, prod ต้อง HTTPS + pinning) / open-redirect guard / **backend ต้อง enforce authorization เสมอ — client role check ใช้แค่คุม UI**
9. **"แอพกระตุกจะ debug ยังไง?"** → DevTools แยก UI jank (CPU→const/Isolate) vs Raster jank (GPU→ลด effect/RepaintBoundary)
10. **"Future vs Stream / async vs Isolate?"** → 4.4 + 4.11

---

## 💡 เคล็ดลับสุดท้าย

- **อย่าท่อง** — ผูกทุกคำตอบกลับมาที่โค้ดจริง: *"ในโปรเจกต์ผมใช้ตรงนี้กับ..."*
- สตอรี่ refactor ทรงพลังกว่าโค้ดเพอร์เฟกต์: *"ผม review เจอจุดอ่อน แล้วแก้แบบนี้ เพราะเหตุผลนี้"*
- ตอบจบทุกข้อด้วย trade-off ("ข้อดี...แลกกับ...") = สัญญาณ mid-level+
- รันโปรเจกต์ให้พร้อม demo: `docker compose up --build` + `flutter run --dart-define-from-file=env/dev.json`
- บัญชีเทส: `test@example.com` / `seller@example.com` / `admin@example.com` (รหัส `abc12345`)
