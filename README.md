# Cryptostrat - Core Screening Module

Module ini berisi bagian INTI Cryptostrat yang spesifik crypto:
models, koneksi Binance API, kalkulasi indikator, dan 9 strategi
screening (4 Futures + 5 Spot), plus `main.dart` minimal sebagai
entry point test build. Folder `android/`, `ios/`, dll SENGAJA TIDAK
disimpan di repo - akan digenerate otomatis oleh `flutter create` di
dalam GitHub Actions setiap kali build (lihat
`.github/workflows/build-apk.yml`), supaya selalu cocok dengan versi
Flutter SDK yang dipakai dan bebas risiko salah tulis manual.

UI sesungguhnya (mode switching Spot/Futures, halaman hasil sinyal,
settings, BYOK Gemini, donasi QRIS, update checker - mengikuti gaya
Cuanstrat) BELUM dibuat di sini. `main.dart` saat ini hanya halaman
test sederhana untuk validasi bahwa semua kode bisa di-compile dan
`ScreeningEngine` bisa dipanggil.

## Cara pakai (lihat panduan step-by-step lengkap di percakapan)

1. Buat repo GitHub baru, upload isi folder ini (TANPA folder
   `android/` - tidak ada di sini, memang sengaja).
2. Push ke branch `main` - GitHub Actions otomatis jalan, generate
   project Flutter lengkap, inject `lib/` dan `pubspec.yaml` kita,
   lalu build APK.
3. Download hasil APK dari tab "Actions" -> pilih run terbaru ->
   bagian "Artifacts".

## Yang BELUM selesai / butuh keputusan lanjutan (lihat TODO di kode)

1. **Status "top market cap"** - dibutuhkan oleh Low Cap Hunter (Spot)
   dan Low Cap Momentum (Futures), tapi Binance TIDAK punya endpoint
   market cap. Saat ini di `screening_engine.dart` dipakai daftar
   hardcode 20 simbol sebagai placeholder sementara. Opsi untuk
   keputusan final:
   - Tetap hardcode, update manual sesekali (paling simpel, tanpa
     dependency API eksternal)
   - Fetch dari CoinGecko/CoinMarketCap public API (butuh request
     tambahan + handle rate limit API lain)
   - Pakai proxy `quoteVolume` dari ticker Binance sendiri (rank by
     volume sebagai pengganti market cap)

2. **Rata-rata volume 7 hari untuk Trend Confirm (Futures)** - di
   skeleton ini disederhanakan pakai `quoteVolume` ticker saat ini
   sebagai placeholder (lihat komentar TODO di
   `screening_engine.dart`). Perlu diganti dengan kalkulasi asli dari
   klines histori 7 hari, sama seperti pendekatan di strategi Spot.

3. **Histori funding rate untuk Divergence Hunter** - Binance punya
   endpoint `/fapi/v1/fundingRate` untuk histori funding rate per
   symbol (belum diimplementasikan di `BinanceApiService`). Saat ini
   `previousFundingRatePercent` di-isi dengan funding rate SAAT INI
   sebagai placeholder, sehingga kondisi "funding makin memburuk"
   belum benar-benar terdeteksi. Perlu method baru di
   `binance_api_service.dart` untuk fetch histori ini.

4. **Whale Watch order book** - di `screening_engine.dart`, order book
   hanya di-fetch untuk symbol yang lolos filter awal tertentu (lihat
   variable `worthCheckingOrderBook`) supaya tidak membebani rate
   limit. Threshold filter awal ini ASUMSI sementara, silakan
   disesuaikan setelah lihat hasil nyata.

5. **Struktur folder Flutter detail, caching strategy persistent (jika
   diperlukan di luar in-memory), UI mode switching Spot/Futures,
   disclaimer copy leverage** - belum dibahas sama sekali, sesuai
   catatan PR di `cryptostrat_context.md`.

## Struktur file

```
lib/
  models/
    ticker_model.dart          - data /ticker/24hr
    kline_model.dart           - data candlestick OHLCV
    funding_rate_model.dart    - data /premiumIndex (Futures)
    open_interest_model.dart   - data OI snapshot & histori (Futures)
    orderbook_model.dart       - data /depth (order book)
    strategy_signal.dart       - format output umum semua strategi
  services/
    binance_api_service.dart   - semua HTTP call ke Binance public API
    cache_service.dart         - cache in-memory dengan TTL
  utils/
    indicators.dart            - EMA, RSI, ATR, Bollinger Bands, dll
  strategies/
    strategy_base.dart         - daftar nama strategi (konstanta)
    spot/
      momentum_breakout_strategy.dart
      whale_watch_strategy.dart
      low_cap_hunter_strategy.dart
      volume_surge_strategy.dart
      accumulation_zone_strategy.dart
    futures/
      trend_confirm_strategy.dart
      squeeze_radar_strategy.dart
      low_cap_momentum_strategy.dart
      divergence_hunter_strategy.dart
  screening/
    screening_engine.dart      - orchestrator alur hybrid 2 tahap
```

## Catatan desain penting

- Semua strategi TIDAK melakukan fetch API sendiri - data disuplai
  dari `ScreeningEngine`. Ini supaya logic strategi murni testable
  tanpa network, dan semua kontrol rate limit/caching terpusat di satu
  tempat.
- `ScreeningEngine` mengikuti alur hybrid 2 tahap yang sudah
  didiskusikan: broad filter murah (semua pairs sekaligus) -> deep
  filter mahal (hanya shortlist).
- Tidak ada API key Binance sama sekali di module ini (fase 1 =
  read-only screening, sesuai keputusan project).
