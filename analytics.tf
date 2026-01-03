# Папка для логов бакета
resource "yandex_storage_object" "analytics_init" {
  bucket  = "dangeon-bucket"
  key     = "analytics/.keep"  # пустой объект для создания папки
  content = ""
}
