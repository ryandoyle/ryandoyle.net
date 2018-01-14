provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "site" {
  bucket = "ryandoyle.net"
  acl = "public-read"
  website {
    index_document = "index.html"
  }
}
resource "aws_s3_bucket" "redirect" {
  bucket = "www.ryandoyle.net"
  acl = "public-read"
  website {
    redirect_all_requests_to = "ryandoyle.net"
  }
}

output "s3_bucket" {
  value = "${aws_s3_bucket.site.bucket}"
}

resource "aws_route53_record" "apex" {
  name = "ryandoyle.net"
  type = "A"
  zone_id = "Z2KH05FAS8W0B5"

  alias {
    evaluate_target_health = false
    name = "${aws_s3_bucket.site.website_domain}"
    zone_id = "${aws_s3_bucket.site.hosted_zone_id}"
  }
}

resource "aws_route53_record" "www" {
  name = "www.ryandoyle.net"
  type = "A"
  zone_id = "Z2KH05FAS8W0B5"

  alias {
    evaluate_target_health = false
    name = "${aws_s3_bucket.site.website_domain}"
    zone_id = "${aws_s3_bucket.site.hosted_zone_id}"
  }
}