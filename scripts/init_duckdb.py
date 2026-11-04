import duckdb

# DuckDB veritabanı dosyasını oluşturur/bağlar
con = duckdb.connect("nova.duckdb")

print("Müşteri verisi DuckDB'ye aktarılıyor...")
con.execute(
    "CREATE TABLE IF NOT EXISTS raw_ecom_churn AS SELECT * FROM read_csv_auto('data/ecomerce verisi.csv');"
)

print("FRED Enflasyon verisi DuckDB'ye aktarılıyor...")
con.execute(
    "CREATE TABLE IF NOT EXISTS raw_inflation AS SELECT * FROM read_csv_auto('data/fred enflasyon verisi.csv');"
)

print("Yükleme tamamlandı! Mevcut Tablolar:", con.execute("SHOW TABLES;").fetchall())
con.close()