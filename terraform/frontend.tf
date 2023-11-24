// cloudfront

data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "allow_access_from_cloudfront" {
  statement {
    sid     = "AllowCloudFrontServicePrincipal"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = ["arn:aws:s3:::crc-s3/*"]


    condition {

      test = "StringEquals"


      variable = "AWS:SourceArn"
      values   = ["arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.crc_cf.id}"]
    }

    principals {

      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
  }
}

resource "aws_cloudfront_distribution" "crc_cf" {
  origin {
    domain_name              = aws_s3_bucket.crc_s3.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.crc_cf_oac.id
    origin_id                = "S3-${aws_s3_bucket.crc_s3.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["${var.FRONTEND_DOMAIN_NAME}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    cache_policy_id  = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    target_origin_id = "S3-${aws_s3_bucket.crc_s3.id}"

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.ACM_CERT_ARN
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

resource "aws_cloudfront_origin_access_control" "crc_cf_oac" {
  name                              = "crc-cf-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

// S3

resource "aws_s3_bucket" "crc_s3" {
  bucket        = "crc-s3"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "block_pub_access" {
  bucket = aws_s3_bucket.crc_s3.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  bucket = aws_s3_bucket.crc_s3.id
  policy = data.aws_iam_policy_document.allow_access_from_cloudfront.json
}

resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.crc_s3.id
  key    = "index.html"
  source = "../src/frontend/index.html"

  content_type = "text/html"
}

// route53

resource "aws_route53_record" "resume_cf" {
  zone_id = var.ZONE_ID_LIVE
  name    = var.FRONTEND_DOMAIN_NAME
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.crc_cf.domain_name
    zone_id                = aws_cloudfront_distribution.crc_cf.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "resume_api" {
  zone_id = var.ZONE_ID_SITE
  name    = aws_apigatewayv2_domain_name.crc_api_dname.domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.crc_api_dname.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.crc_api_dname.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
