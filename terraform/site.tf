provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "site" {
  bucket = "ryandoyle.net"
}
resource "aws_s3_bucket_acl" "site" {
  bucket = aws_s3_bucket.site.id
  acl = "private"
}

resource "aws_acm_certificate" "site" {
  domain_name       = "ryandoyle.net"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "site_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id = "Z2KH05FAS8W0B5"
}

resource "aws_acm_certificate_validation" "site_validation" {
  certificate_arn = aws_acm_certificate.site.arn
  validation_record_fqdns = [for record in aws_route53_record.site_validation : record.fqdn]
}

resource "aws_cloudfront_origin_access_identity" "origin_identity" {
  comment = "Origin Identity for CloudFront"
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "s3_policy" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_cloudfront_distribution" "site" {
  origin {
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id   = "S3Origin"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_identity.cloudfront_access_identity_path
    }
  }

  aliases = [ "ryandoyle.net" ]

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id     = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods      = ["GET", "HEAD", "OPTIONS"]
    cached_methods       = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.site.arn
    ssl_support_method = "sni-only"
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
    name = aws_cloudfront_distribution.site.domain_name
    zone_id = aws_cloudfront_distribution.site.hosted_zone_id
  }
}
