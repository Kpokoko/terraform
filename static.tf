resource "yandex_storage_object" "index_html" {
  bucket  = "dangeon-bucket"
  key     = "index.html"
  source  = "front/index.html"
  content_type = "text/html"
}

resource "yandex_storage_object" "main_js" {
  bucket  = "dangeon-bucket"
  key     = "main.js"
  source  = "front/main.js"
  content_type = "application/javascript"
}

resource "yandex_storage_object" "style_css" {
  bucket  = "dangeon-bucket"
  key     = "css/style.css"
  source  = "front/css/style.css"
  content_type = "text/css"
}
