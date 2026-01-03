resource "yandex_storage_bucket" "site_bucket" {
  bucket = "dangeon-bucket"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  force_destroy = false
}
