# nova_dbt — Veri Sözlüğü

Bu klasör projenin dbt kısmıdır. Ham CSV dosyaları DuckDB'ye yüklenir (`raw_` tabloları), dbt ile temizlenir (`stg_` modelleri) ve analize hazır tablolara dönüştürülür (`fct_` ve `dim_` modelleri).

Akış: `raw_ecom_churn` + `raw_inflation` → staging (`stg_`) → marts (`fct_` / `dim_`) → dashboard

Çalıştırma (bu klasörün içinden): `dbt run`, `dbt test`, `dbt docs generate`

---

## 1. Ham kaynak tablolar (raw)

### raw_ecom_churn
Kaggle e-ticaret müşteri verisi. **Her satır bir alışveriştir.** 250.000 satır, 49.673 farklı müşteri, Ocak 2020 – Eylül 2023.

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

### raw_inflation
FRED (ABD Merkez Bankası) T10YIE serisi: piyasanın beklediği 10 yıllık enflasyon oranı. **Her satır bir gündür.** 2.045 satır, Ocak 2019 – Kasım 2026.

| Sütun | Tip | Açıklama |
| :--- | :--- | :--- |
| observation_date | DATE | Gözlem günü (sadece iş günleri) |
| T10YIE | DOUBLE | 10 yıllık enflasyon beklentisi (%). Tatil günlerinde boş (84 satır) |

---

## 2. Staging modelleri (temizleme katmanı)

### stg_ecom_customers
`raw_ecom_churn` tablosunun temizlenmiş hali. Sütun adları küçük harf + alt çizgi yapıldı, veri tipleri düzeltildi, müşteri numarası boş olan satırlar çıkarıldı. Her satır bir alışveriş.

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

### stg_daily_inflation
`raw_inflation` tablosunun temizlenmiş hali. Tarihi veya değeri boş günler çıkarıldı, aylık eşleştirme için `year_month` sütunu eklendi. 1.961 satır.

| Sütun | Tip | Kaynak sütun | Açıklama |
| :--- | :--- | :--- | :--- |
| inflation_date | DATE | observation_date | Gözlem günü |
| year_month | VARCHAR | observation_date | Yıl-ay (ör. 2021-05); alışverişlerle eşleştirme anahtarı |
| inflation_rate | DECIMAL | T10YIE | O günün 10 yıllık enflasyon beklentisi (%), 0,50 – 3,02 arası |

### stg_ecom_orders
`raw_ecom_churn` tablosundan sipariş bilgilerini seçen sade model. `fct_customer_summary` tablosunu besler. Her satır bir alışveriş.

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

## 3. Mart modelleri (analiz katmanı)

### fct_customer_churn
**Alışveriş seviyesinde ana tablo.** Her satır bir alışveriş; alışverişin yapıldığı ayın ortalama enflasyon beklentisi eklendi (`stg_ecom_customers` LEFT JOIN `stg_daily_inflation`, `year_month` üzerinden). 250.000 satır. Dashboard grafiklerinde kullanılır.

| Sütun | Tip | Açıklama |
| :--- | :--- | :--- |
| purchase_id | BIGINT | Her alışverişin benzersiz numarası (dbt tarafından üretildi) |
| customer_id | INTEGER | Alışverişi yapan müşteri |
| purchase_date | DATE | Alışveriş tarihi |
| purchase_year_month | VARCHAR | Alışverişin yılı-ayı (ör. 2022-03) |
| product_category | VARCHAR | Ürün kategorisi |
| product_price | DECIMAL | Birim fiyat |
| quantity | INTEGER | Adet |
| total_purchase_amount | DECIMAL | Alışveriş toplam tutarı |
| payment_method | VARCHAR | Ödeme yöntemi |
| is_returned | INTEGER | İade edildi mi: 1 = evet, 0 = hayır (boş değerler 0 kabul edildi) |
| customer_age | INTEGER | Müşterinin yaşı |
| gender | VARCHAR | Cinsiyet |
| is_churn | INTEGER | Müşteri terk etti mi: 1 = evet, 0 = hayır |
| monthly_inflation_rate | DOUBLE | Alışveriş ayının ortalama 10 yıllık enflasyon beklentisi (%) |

### dim_customers
**Müşteri seviyesinde tablo.** Her satır bir müşteri; RFM (Recency, Frequency, Monetary) metrikleri ve churn bilgisi içerir. 49.673 satır. Müşteri bazlı KPI'larda (toplam müşteri, churn oranı) kullanılır.

| Sütun | Tip | Açıklama |
| :--- | :--- | :--- |
| customer_id | INTEGER | Müşterinin benzersiz numarası |
| customer_age | INTEGER | Müşterinin yaşı |
| gender | VARCHAR | Cinsiyet |
| first_purchase_date | DATE | İlk alışveriş tarihi |
| last_purchase_date | DATE | Son alışveriş tarihi |
| recency_days | BIGINT | **Recency:** son alışverişten veri setinin son gününe kadar geçen gün (0 – 1.353) |
| frequency | BIGINT | **Frequency:** toplam alışveriş sayısı (1 – 17) |
| monetary | DECIMAL | **Monetary:** toplam harcama tutarı |
| total_returns | HUGEINT | Toplam iade edilen alışveriş sayısı |
| avg_inflation_exposure | DOUBLE | Müşterinin alışveriş yaptığı aylardaki ortalama enflasyon beklentisi (%) |
| is_churn | INTEGER | 1 = terk etti, 0 = aktif |

### fct_customer_summary
Müşteri başına sipariş özeti (`stg_ecom_orders` üzerinden). 49.673 satır.

| Sütun | Tip | Açıklama |
| :--- | :--- | :--- |
| customer_id | BIGINT | Müşteri numarası |
| total_orders | BIGINT | Toplam sipariş sayısı |
| total_spent | HUGEINT | Toplam harcama |
| avg_order_value | DOUBLE | Ortalama sepet tutarı (toplam harcama ÷ sipariş sayısı) |

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

## 5. Kısaltmalar ve terimler

| Terim | Anlamı |
| :--- | :--- |
| Churn | Müşterinin platformu terk etmesi (müşteri kaybı) |
| RFM | Recency (yenilik), Frequency (sıklık), Monetary (parasal değer): müşteri segmentasyonu için kullanılan üç ölçü |
| T10YIE | FRED'in 10-Year Breakeven Inflation Rate serisi: piyasanın 10 yıllık enflasyon beklentisi |
| stg_ | Staging: ham verinin temizlendiği katman |
| fct_ | Fact: olay/işlem seviyesindeki tablo (ör. her alışveriş) |
| dim_ | Dimension: varlık seviyesindeki tablo (ör. her müşteri) |