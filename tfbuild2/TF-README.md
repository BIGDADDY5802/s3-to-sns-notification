# Packaging Lambda Code with Terraform

A beginner's guide to the `local_file` → `archive_file` → `aws_lambda_function` pattern.

---

## What This Pattern Does

AWS Lambda requires your code to be delivered as a `.zip` file. This three-step Terraform pattern handles that entire process automatically — writing the code, zipping it, and uploading it to AWS — without you ever touching a file manually.

---

## The Three Steps

### Step 1 — Write the Python file to disk (`local_file`)

```hcl
resource "local_file" "lambda_source" {
  filename = "${path.module}/lambda/sns_notify.py"
  content  = <<-PYTHON
    # your python code here
  PYTHON
}
```

`local_file` creates a real file on your computer in the same folder as your `.tf` files. It does not touch AWS. The `<<-PYTHON ... PYTHON` block is called a **heredoc** — a way to write multi-line text cleanly inside Terraform.

**Reference:** [hashicorp/local — local_file resource](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file)

---

### Step 2 — Zip the file (`archive_file`)

```hcl
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda/sns_notify.zip"

  depends_on = [local_file.lambda_source]
}
```

`archive_file` takes everything in the `./lambda/` folder and compresses it into a `.zip` — still on your local machine. Lambda does not accept a raw `.py` file; the zip is required.

`depends_on` tells Terraform to wait until the `.py` file exists before trying to zip. Without it, Terraform might zip an empty folder.

**Reference:** [hashicorp/archive — archive_file data source](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file)

---

### Step 3 — Upload to Lambda (`aws_lambda_function`)

```hcl
resource "aws_lambda_function" "s3_to_sns" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "sns_notify.lambda_handler"
  runtime          = "python3.12"
  ...
}
```

`filename` points Terraform to your local zip. Terraform reads it and uploads it to AWS.

`source_code_hash` is a fingerprint of the zip's contents. When your code changes, the hash changes, and Terraform knows to re-upload. When nothing has changed, Terraform skips the upload entirely.

`handler` tells Lambda which function to run when triggered. The format is `filename.function_name` — so `sns_notify.lambda_handler` means "run the `lambda_handler` function inside `sns_notify.py`."

**Reference:** [aws_lambda_function resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)

---

## The Full Flow

```
local_file            archive_file          aws_lambda_function
┌──────────────┐      ┌──────────────┐      ┌──────────────────┐
│ writes       │ ───► │ zips folder  │ ───► │ uploads .zip     │
│ sns_notify   │      │ to .zip on   │      │ to AWS Lambda    │
│ .py to disk  │      │ local disk   │      │                  │
└──────────────┘      └──────────────┘      └──────────────────┘
  (local only)          (local only)           (hits AWS)
```

The first two steps happen entirely on your machine. AWS is not contacted until Step 3.

---

## Key Terms

| Term | What It Means |
|---|---|
| `heredoc` (`<<-PYTHON`) | A way to write multi-line text in Terraform without quoting every line |
| `${path.module}` | A built-in Terraform variable that means "the folder this `.tf` file lives in" |
| `depends_on` | Tells Terraform to finish one resource before starting another |
| `source_code_hash` | A fingerprint of the zip — changes when code changes, triggering a re-upload |
| `handler` | Tells Lambda which function to call: format is `filename.function_name` |

---

## Source Documentation

| Topic | Link |
|---|---|
| `local_file` resource | https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file |
| `archive_file` data source | https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file |
| `aws_lambda_function` resource | https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function |
| Terraform `depends_on` | https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on |
| Terraform heredoc syntax | https://developer.hashicorp.com/terraform/language/expressions/strings#heredoc-strings |
| Terraform `path.module` | https://developer.hashicorp.com/terraform/language/expressions/references#path-module |
| AWS Lambda handler format | https://docs.aws.amazon.com/lambda/latest/dg/python-handler.html |