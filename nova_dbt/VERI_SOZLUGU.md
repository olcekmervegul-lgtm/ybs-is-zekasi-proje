# Veri Sözlüğü

Bu dosya projedeki tüm tabloların ve sütunların açıklamasını içerir. Projede iki veri seti kullanılır; her biri önce ham tablo olarak DuckDB'ye yüklenir, sonra dbt ile temizlenir (staging) ve son olarak analize hazır mart tablolarında birleştirilir.

Akış: ham tablolar (`raw_`) → staging (`stg_`) → mart tabloları (`fct_` / `dim_`) → dashboard

---

## 1. Veri seti: E-Ticaret Müşteri Verisi

Kaynak: Kaggle e-ticaret müşteri verisi (`data/ecomerce verisi.csv`). **Her satır bir alışveriştir.** 250.000 satır, 49.673 farklı müşteri, Ocak 2020 – Eylül 2023.

### 1.1 Ham tablo: raw_ecom_churn

| Sütun | Tip | Açıklama |
| :--- | :--- | :--- |
| Customer ID | BIGINT | Müşteri numarası (bir müşterinin birden çok alışverişi olabilir) |
| Purchase Date | TIMESTAMP | Alışveriş tarihi ve saati |
| Product Category | VARCHAR | Ürün kategorisi: Books, Clothing, Electronics, Home |
| Product Price | BIGINT | Ürünün birim fiyatı (10 – 500) |
| Quantity | BIGINT | Alınan adet (1 – 5) |
| Total Purchase Amount | BIGINT | Alışverişin toplam tutarı (100 – 5.350). Kaynak veride hazır gelir; fiyat × adet ile birebir eşleşmez |
| Payment Method | VARCHAR | Ödeme yöntemi: Credit Card, PayPal, Cash, Crypto |
| Customer Age | BIGINT | Müşterinin yaşı (18 – 70) |
| Returns | DOUBLE | İade durumu: 1 = iade edildi, 0 = edilmedi. 47.596 satırda boş |
| Customer Name | VARCHAR | Müşteri adı (sentetik) |
| Age | BIGINT | `Customer Age` ile aynı bilgi; modellerde kullanılmaz |
| Gender | VARCHAR | Cinsiyet: Male, Female |
| Churn | BIGINT | Hedef değişken: 1 = müşteri terk etti, 0 = devam ediyor |

### 1.2 Staging: stg_ecom_customers

Ham tablonun temizlenmiş hali. Sütun adları küçük harf + alt çizgi yapıldı, veri tipleri düzeltildi, müşteri numarası boş olan satırlar çıkarıldı. Her satır bir alışveriş.

| Sütun | Tip | Kaynak sütun | Açıklama |
| :--- | :--- | :--- | :--- |
| customer_id | INTEGER | Customer ID | Müşteri numarası |
| customer_name | VARCHAR | Customer Name | Müşteri adı |
| customer_age | INTEGER | Customer Age | Müşterinin yaşı |
| gender | VARCHAR | Gender | Cinsiyet |
| purchase_date | DATE | Purchase Date | Alışveriş tarihi (saat bilgisi atıldı) |
| product_category | VARCHAR | Product Category | Ürün kategorisi |
| product_price | DECIMAL | Product Price | Birim fiyat |
| quantity | INTEGER | Quantity | Adet |
| total_purchase_amount | DECIMAL | Total Purchase Amount | Alışveriş toplam tutarı |
| payment_method | VARCHAR | Payment Method | Ödeme yöntemi |
| returns | INTEGER | Returns | İade durumu (1/0, boş olabilir) |
| is_churn | INTEGER | Churn | 1 = terk etti, 0 = devam ediyor |

### 1.3 Staging: stg_ecom_orders

Ham tablodan sipariş bilgilerini seçen sade model; `fct_customer_summary` tablosunu besler. Her satır bir alışveriş.

| Sütun | Tip | Açıklama |
| :--- | :--- | :--- |
| customer_id | BIGINT | Müşteri numarası |
| product_category | VARCHAR | Ürün kategorisi |
| product_price | BIGINT | Birim fiyat |
| quantity | BIGINT | Adet |
| total_purchase_amount | BIGINT | Alışveriş toplam tutarı |
| payment_method | VARCHAR | Ödeme yöntemi |
| purchase_date | TIMESTAMP | Alışveriş tarihi ve saati |

---

## 2. Veri seti: FRED Enflasyon Verisi

Kaynak: FRED (ABD Merkez Bankası), T10YIE serisi – 10-Year Breakeven Inflation Rate (`data/fred enflasyon verisi.csv`). Piyasanın önümüzdeki 10 yıl için beklediği yıllık enflasyon oranını gösterir. **Her satır bir gündür.** 2.045 satır, Ocak 2019 – Kasım 2026.

### 2.1 Ham tablo: raw_inflation

| Sütun | Tip | Açıklama |
| :--- | :--- | :--- |
| observation_date | DATE | Gözlem günü (sadece iş günleri) |
| T10YIE | DOUBLE | 10 yıllık enflasyon beklentisi (%). Tatil günlerinde boş (84 satır) |

### 2.2 Staging: stg_daily_inflation

Ham tablonun temizlenmiş hali. Tarihi veya değeri boş günler çıkarıldı, aylık eşleştirme için `year_month` eklendi. 1.961 satır.

| Sütun | Tip | Kaynak sütun | Açıklama |
| :--- | :--- | :--- | :--- |
| inflation_date | DATE | observation_date | Gözlem günü |
| year_month | VARCHAR | observation_date | Yıl-ay (ör. 2021-05); alışverişlerle eşleştirme anahtarı |
| inflation_rate | DECIMAL | T10YIE | O günün 10 yıllık enflasyon beklentisi (%), 0,50 – 3,02 arası |

---

## 3. Mart tabloları (analiz katmanı)

Mart tabloları iki veri setini birleştirir. Günlük enflasyon değerlerinin aylık ortalaması alınır ve alışverişin yapıldığı aya göre e-ticaret verisine eklenir (`purchase_year_month` = `year_month`).

### 3.1 fct_customer_churn

**Alışveriş seviyesinde ana tablo.** Her satır bir alışveriş (250.000 satır). `stg_ecom_customers` LEFT JOIN `stg_daily_inflation`. Dashboard grafiklerinde kullanılır.

| Sütun | Tip | Kaynak veri seti | Açıklama |
| :--- | :--- | :--- | :--- |
| purchase_id | BIGINT | (dbt) | Her alışverişin benzersiz numarası |
| customer_id | INTEGER | E-ticaret | Alışverişi yapan müşteri |
| purchase_date | DATE | E-ticaret | Alışveriş tarihi |
| purchase_year_month | VARCHAR | E-ticaret | Alışverişin yılı-ayı (ör. 2022-03); enflasyonla eşleştirme anahtarı |
| product_category | VARCHAR | E-ticaret | Ürün kategorisi |
| product_price | DECIMAL | E-ticaret | Birim fiyat |
| quantity | INTEGER | E-ticaret | Adet |
| total_purchase_amount | DECIMAL | E-ticaret | Alışveriş toplam tutarı |
| payment_method | VARCHAR | E-ticaret | Ödeme yöntemi |
| is_returned | INTEGER | E-ticaret | İade edildi mi: 1 = evet, 0 = hayır (boş değerler 0 kabul edildi) |
| customer_age | INTEGER | E-ticaret | Müşterinin yaşı |
| gender | VARCHAR | E-ticaret | Cinsiyet |
| is_churn | INTEGER | E-ticaret | Müşteri terk etti mi: 1 = evet, 0 = hayır |
| monthly_inflation_rate | DOUBLE | FRED | Alışveriş ayının ortalama 10 yıllık enflasyon beklentisi (%) |

### 3.2 dim_customers

**Müşteri seviyesinde tablo.** Her satır bir müşteri (49.673 satır); RFM (Recency, Frequency, Monetary) metrikleri ve churn bilgisi. `fct_customer_churn` tablosundan üretilir. Müşteri bazlı KPI'larda (toplam müşteri, churn oranı) kullanılır.

| Sütun | Tip | Kaynak veri seti | Açıklama |
| :--- | :--- | :--- | :--- |
| customer_id | INTEGER | E-ticaret | Müşterinin benzersiz numarası |
| customer_age | INTEGER | E-ticaret | Müşterinin yaşı |
| gender | VARCHAR | E-ticaret | Cinsiyet |
| first_purchase_date | DATE | E-ticaret | İlk alışveriş tarihi |
| last_purchase_date | DATE | E-ticaret | Son alışveriş tarihi |
| recency_days | BIGINT | E-ticaret | **Recency:** son alışverişten veri setinin son gününe kadar geçen gün (0 – 1.353) |
| frequency | BIGINT | E-ticaret | **Frequency:** toplam alışveriş sayısı (1 – 17) |
| monetary | DECIMAL | E-ticaret | **Monetary:** toplam harcama tutarı |
| total_returns | HUGEINT | E-ticaret | Toplam iade edilen alışveriş sayısı |
| avg_inflation_exposure | DOUBLE | FRED | Müşterinin alışveriş yaptığı aylardaki ortalama enflasyon beklentisi (%) |
| is_churn | INTEGER | E-ticaret | 1 = terk etti, 0 = aktif |

### 3.3 fct_customer_summary

Müşteri başına sipariş özeti (49.673 satır). `stg_ecom_orders` tablosundan üretilir.

| Sütun | Tip | Kaynak veri seti | Açıklama |
| :--- | :--- | :--- | :--- |
| customer_id | BIGINT | E-ticaret | Müşteri numarası |
| total_orders | BIGINT | E-ticaret | Toplam sipariş sayısı |
| total_spent | HUGEINT | E-ticaret | Toplam harcama |
| avg_order_value | DOUBLE | E-ticaret | Ortalama sepet tutarı (toplam harcama ÷ sipariş sayısı) |

---

## 4. dbt testleri

Testler `models/marts/schema.yml` dosyasında tanımlıdır. `dbt test` ile 9 testin hepsi geçer.

| Tablo | Sütun | Test | Ne kontrol eder |
| :--- | :--- | :--- | :--- |
| fct_customer_churn | purchase_id | unique, not_null | Her alışverişin numarası tek ve dolu |
| fct_customer_churn | customer_id | not_null | Her alışverişin bir müşterisi var |
| fct_customer_churn | customer_id | relationships → dim_customers | Alışverişteki her müşteri müşteri tablosunda da var |
| fct_customer_churn | is_churn | accepted_values [0, 1] | Churn sadece 0 veya 1 |
| fct_customer_churn | monthly_inflation_rate | not_null | Her alışverişe enflasyon değeri eşleşmiş |
| dim_customers | customer_id | unique, not_null | Her müşteri tabloda bir kez geçiyor |
| dim_customers | is_churn | not_null | Her müşterinin churn bilgisi var |

---

## 5. Terimler

| Terim | Anlamı |
| :--- | :--- |
| Churn | Müşterinin platformu terk etmesi (müşteri kaybı) |
| RFM | Recency (yenilik), Frequency (sıklık), Monetary (parasal değer): müşteri segmentasyonu için kullanılan üç ölçü |
| T10YIE | FRED'in 10-Year Breakeven Inflation Rate serisi: piyasanın 10 yıllık enflasyon beklentisi |
| stg_ | Staging: ham verinin temizlendiği katman |
| fct_ | Fact: olay/işlem seviyesindeki tablo (ör. her alışveriş) |
| dim_ | Dimension: varlık seviyesindeki tablo (ör. her müşteri) |