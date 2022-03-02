data "archive_file" "lambda_python_boto_layer" {
  type = "zip"

  source_dir  = "${path.module}/lambda-layers/python-layers/"
  output_path = "${path.module}/lambda-layers/boto.zip"
}

resource "aws_s3_object" "lambda_python_boto_layer" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "boto.zip"
  source = data.archive_file.lambda_python_boto_layer.output_path

  etag = filemd5(data.archive_file.lambda_python_boto_layer.output_path)
}

resource "aws_lambda_layer_version" "lambda_python_boto_layer" {
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_python_boto_layer.key

  layer_name = "boto2-test"

  compatible_architectures = ["x86_64"]
  compatible_runtimes = ["python3.9"]

  source_code_hash = data.archive_file.lambda_python_boto_layer.output_base64sha256
  
  description = "boto package layer for Python 3.9"
}
