terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Empaquetado: .zip estándar de Lambda desde lambda/src/ (contiene agent/).
# El source_code_hash cuelga del zip: cambiar el código redepliega.
# ---------------------------------------------------------------------------
data "archive_file" "agent" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/src"
  output_path = "${path.module}/../../../lambda/dist/agent.zip"
  excludes    = ["**/__pycache__", "**/*.pyc"]
}

# ---------------------------------------------------------------------------
# Log group explícito: permite acotar los permisos de logs a su ARN.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name_prefix}-agent"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ---------------------------------------------------------------------------
# Rol de ejecución — mínimo privilegio (sin Action ni Resource "*").
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${var.name_prefix}-agent-exec"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "exec" {
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }

  statement {
    sid       = "InvokeGenerationModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = ["arn:aws:bedrock:${var.region}::foundation-model/${var.model_id}"]
  }

  statement {
    sid       = "RetrieveFromKnowledgeBase"
    effect    = "Allow"
    actions   = ["bedrock:Retrieve"]
    resources = [var.knowledge_base_arn]
  }
}

resource "aws_iam_role_policy" "exec" {
  name   = "${var.name_prefix}-agent-policy"
  role   = aws_iam_role.exec.id
  policy = data.aws_iam_policy_document.exec.json
}

# ---------------------------------------------------------------------------
# La función.
# ---------------------------------------------------------------------------
resource "aws_lambda_function" "agent" {
  function_name = "${var.name_prefix}-agent"
  role          = aws_iam_role.exec.arn
  runtime       = "python3.13"
  handler       = "agent.handler.lambda_handler"

  filename         = data.archive_file.agent.output_path
  source_code_hash = data.archive_file.agent.output_base64sha256

  timeout     = 30
  memory_size = 256

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = var.knowledge_base_id
      MODEL_ID          = var.model_id
      TOP_K             = tostring(var.top_k)
      MIN_SCORE         = tostring(var.min_score)
    }
  }

  depends_on = [
    aws_iam_role_policy.exec,
    aws_cloudwatch_log_group.this,
  ]

  tags = var.tags
}
