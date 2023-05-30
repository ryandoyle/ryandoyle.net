provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "site" {
  bucket = "ryandoyle.net"
}
resource "aws_s3_bucket_acl" "site" {
  bucket = aws_s3_bucket.site.id
  acl = "public-read"
}
resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket" "redirect" {
  bucket = "www.ryandoyle.net"
}
resource "aws_s3_bucket_acl" "redirect" {
  bucket = aws_s3_bucket.redirect.id
  acl = "public-read"
}
resource "aws_s3_bucket_website_configuration" "redirect" {
  bucket = aws_s3_bucket.redirect.id
  redirect_all_requests_to {
    host_name = "ryandoyle.net"
  }
}

output "s3_bucket" {
  value = aws_s3_bucket.site.bucket
}

resource "aws_route53_record" "apex" {
  name = "ryandoyle.net"
  type = "A"
  zone_id = "Z2KH05FAS8W0B5"

  alias {
    evaluate_target_health = false
    name = aws_s3_bucket_website_configuration.site.website_domain
    zone_id = aws_s3_bucket.site.hosted_zone_id
  }
}

resource "aws_route53_record" "www" {
  name = "www.ryandoyle.net"
  type = "A"
  zone_id = "Z2KH05FAS8W0B5"

  alias {
    evaluate_target_health = false
    name = aws_s3_bucket_website_configuration.redirect.website_domain
    zone_id = aws_s3_bucket.redirect.hosted_zone_id
  }
}