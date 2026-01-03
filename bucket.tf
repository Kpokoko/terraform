provider "yandex" {
  service_account_key_file = "test-acc.json"
  cloud_id                 = "yc-2510-75"
  folder_id                = "b1g198030ofc482vr85d"
  zone                     = "ru-central1-a"
}

# Сервисный аккаунт
resource "yandex_iam_service_account" "bucket_sa" {
  name        = "test-acc"
  description = "Service account for bucket access"
}

# Права сервисного аккаунта на папку
resource "yandex_resourcemanager_folder_iam_member" "bucket_sa_storage_editor" {
  folder_id = "b1g198030ofc482vr85d"
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.bucket_sa.id}"
}

# Бакет для сайта
resource "yandex_storage_bucket" "site_bucket" {
  bucket        = "dangeon-bucket"
  acl           = "public"
  force_destroy = true
}

# Вывод имени бакета
output "site_bucket_name" {
  value = yandex_storage_bucket.site_bucket.bucket
}
