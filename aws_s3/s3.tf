provider "aws" {
	region = "eu-central-1"
	profile = "gentoo"
}

resource "aws_kms_key" "zlogene_key" {
	description = "zlogene-key"
	deletion_window_in_days = 10
}

resource "aws_s3_bucket" "bucket" {
	bucket = "zlogene-small-bucket"
	acl = "private"

	lifecycle_rule {
		enabled = true

		transition {
			days = 30
			storage_class = "STANDARD_IA"
		}

		transition {
			days = 60
			storage_class = "GLACIER"
		}
	}

	server_side_encryption_configuration {
		rule { 
		apply_server_side_encryption_by_default {
			kms_master_key_id = aws_kms_key.zlogene_key.arn
			sse_algorithm = "aws:kms"
		}
	}
		}
}
