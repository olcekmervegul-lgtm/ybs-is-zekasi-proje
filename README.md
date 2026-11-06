# E-Ticaret Müşteri Kaybı (Churn) ve Enflasyon Analizi

YBS İş Zekası ve Veri Madenciliği dersi dönem projesi.

Bu proje, bir e-ticaret şirketinin müşteri alışveriş verisini FRED aylık enflasyon beklentisi verisiyle birleştirir. Amaç, müşteri kaybının (churn), harcamanın ve satın alma davranışının enflasyon dönemleriyle ve müşteri özellikleriyle ilişkisini incelemektir. Veri, dbt ve DuckDB ile hazırlanır, sonuçlar Looker Studio dashboard'unda sunulur.

**Dashboard (Looker Studio):** [Dashboard linki buraya eklenecek]

## Veri kaynakları

| Kaynak | İçerik | Dosya |
|---|---|---|
| E-ticaret müşteri verisi | 250.000 alışveriş, 49.673 müşteri, Ocak 2020 - Eylül 2023 | `data/ecomerce verisi.csv` |
| FRED enflasyon beklentisi (T10YIE) | Günlük 10 yıllık enflasyon beklentisi (%) | `data/fred enflasyon verisi.csv` |

## Klasör yapısı

```text
.
├── data/                 # ham veri dosyaları (CSV)
├── scripts/
│   └── init_duckdb.py    # CSV dosyalarını DuckDB'ye yükler
├── nova_dbt/             # dbt projesi
│   ├── models/staging/   # temizleme modelleri
│   ├── models/marts/     # analiz tabloları ve testler
│   └── profiles.yml      # DuckDB bağlantısı
├── notebook/
│   └── analiz.ipynb      # analiz ve raporlama notebook
├── docs/
│   └── dbt_docs.html     # dbt dokümantasyonu
├── nova.duckdb           # DuckDB veritabanı
└── README.md
```

## dbt modelleri

| Katman | Model | Ne yapar |
|---|---|---|
| staging | `stg_ecom_customers` | Ham müşteri verisini okur, sütunları anlamlı adlara ve doğru türlere çevirir |
| staging | `stg_daily_inflation` | Günlük enflasyon verisini tarihe çevirir, boş değerleri ayıklar, ay bilgisini üretir |
| marts | `fct_customer_churn` | Her satır bir alışveriş. Alışverişin yapıldığı ayın ortalama enflasyon beklentisiyle birleştirilir |
| marts | `dim_customers` | Her satır bir müşteri. Recency, frequency, monetary (RFM) metrikleri ve churn bilgisi |

`dbt test` ile 9 test çalışır ve hepsi geçer. Testler `fct_customer_churn` ve `dim_customers` üzerindedir: benzersiz ve dolu kimlikler, müşteri-alışveriş ilişkisi, `is_churn` değerinin 0 veya 1 olması, enflasyon değerinin dolu olması.

## Nasıl çalıştırılır

Gereken paketler: `dbt-duckdb`, `duckdb`, `pandas`, `matplotlib`, `seaborn`.

```bash
# 1. Ham CSV dosyalarını DuckDB'ye yükle (repo ana klasöründen)
python scripts/init_duckdb.py

# 2. dbt modellerini çalıştır ve test et
cd nova_dbt
dbt run
dbt test

# 3. dbt dokümantasyonunu üret
dbt docs generate
dbt docs serve
```

Analiz notebook `notebook/analiz.ipynb` dosyasında bulunur.

## Veri hazırlama kararları

- Sütun adları küçük harfli ve alt çizgili hale getirildi (`Customer ID` → `customer_id`).
- Tarih ve sayı alanları doğru veri türlerine çevrildi.
- Boş (`Returns`) değerleri iade yok (0) olarak kabul edildi.
- Ham veride `Age` ve `Customer Age` sütunları aynı değerleri içerir, modelde yalnızca `Customer Age` kullanılır.
- Enflasyon günlük olduğundan, alışverişle eşleştirmek için aylık ortalamaya çevrildi.
- Churn bilgisi müşteri düzeyindedir (bir müşterinin tüm alışverişlerinde aynı değer). Bu yüzden churn oranı `dim_customers` üzerinden müşteri sayısına göre hesaplanır.

## Dashboard

Dashboard, dbt çıktılarından üretilen özet tablolarla Looker Studio'da hazırlanır. Ana göstergeler:

- Toplam müşteri sayısı: 49.673
- Churn oranı: %20,01
- Toplam harcama: 681.342.683
- Alışveriş sayısı: 250.000, ortalama sepet: 2.725,37

## Bulgular

- Churn cinsiyete göre neredeyse sabittir: kadınlarda %19,74, erkeklerde %20,30.
- Yaş gruplarında churn oranı %19,7 ile %21,0 arasında değişir, en yüksek 18-24 yaş grubudur.
- Müşterinin maruz kaldığı ortalama enflasyon düzeyine göre churn oranı %19,6 ile %20,5 arasındadır. Enflasyonla churn arasında belirgin bir ilişki görülmemiştir.
- Aylık harcama ile aylık enflasyon arasındaki ilişki çok zayıftır (korelasyon yaklaşık -0,08).
- Harcama payları: Credit Card %40,2, PayPal %29,9, Cash %19,9, Crypto %9,9. Kategorilerde Books %30,1, Clothing %30,0, Electronics %20,0, Home %19,9.

## Sınırlılıklar

- Bulgular ilişkiyi gösterir, nedensellik kanıtlamaz.
- Kullanılan enflasyon göstergesi (FRED T10YIE) piyasa beklentisidir, tüketici fiyat endeksi değildir.
- Eylül 2023 verisi ayın 15'ine kadardır, aylık toplamlarda bu ay yarım görünür.
- Dashboard CSV dosyalarından beslenir. Veri yenilenirse dosyaların Looker Studio'ya yeniden yüklenmesi gerekir.

## Ekip

| Üye | Katkı |
|---|---|
| Mervegül Ölçek | DuckDB altyapısı, dbt projesinin kurulumu, analiz notebook |
| Aynur Çakıroğlu | Staging modelleri, veri temizleme, analiz notebook |
| Ayşegül Esma Demircan | Mart modelleri, dbt testleri, dbt dokümantasyonu, veri sözlüğü hazırlama |
| Esma Handan Tamer | Looker Studio dashboard, README dosyasının hazırlanması |
