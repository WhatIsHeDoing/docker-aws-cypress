# docker-aws-cypress

[![Docker Pulls](https://img.shields.io/docker/pulls/whatishedoing/docker-aws-cypress?style=for-the-badge)][site]
[![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/whatishedoing/docker-aws-cypress?style=for-the-badge)][site]

## 👋 Introduction

A [Docker] image designed to be used in [AWS], as a Test [CodePipeline] step that uses [CodeBuild]
to run [Cypress] tests.

## 🏃‍ Usage

The following ordered setup instructions use [Terraform] to configure AWS. They assume the tests are
located in the same repository as your website, so that they can be reviewed together with unit tests
in a Pull Request.

### CodePipeline

Configure a CodePipeline Test step:

```ruby
resource "aws_codepipeline" "website" {
  name     = "website"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.bucket.id
    type     = "S3"
  }

  # Source, Build and Deploy stages...

  stage {
    name = "smoke-tests"

    action {
      name            = "smoke-tests"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = 1
      input_artifacts = ["source"]

      # No output_artifacts, as they cannot be deployed if this step fails!
      # Instead, the build copies them somewhere useful.

      configuration = {
        ProjectName = aws_codebuild_project.smoke_tests.name
      }
    }
  }

  # Manual approval and other further deployments...
}
```

### CodeBuild

Create a CodeBuild for Cypress; note the `image` attribute of `environment`:

```ruby
resource "aws_codebuild_project" "smoke_tests" {
  name          = "smoke-tests"
  description   = "Runs smoke tests against the website."
  badge_enabled = true
  build_timeout = 20
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type                = "S3"
    location            = aws_s3_bucket.bucket.id
    packaging           = "ZIP"
    encryption_disabled = true
  }

  cache {
    type = "LOCAL"

    modes = [
      "LOCAL_DOCKER_LAYER_CACHE",
      "LOCAL_SOURCE_CACHE"
    ]
  }

  environment {
    compute_type    = "BUILD_GENERAL1_MEDIUM"
    image           = "whatishedoing/docker-aws-cypress"
    privileged_mode = false
    type            = "LINUX_CONTAINER"

    environment_variable {
      name  = "CYPRESS_BASE_URL"
      value = "https://${aws_route53_record.website.name}"
    }

    environment_variable {
      name  = "S3_ARTIFACTS_BUCKET"
      value = aws_s3_bucket.bucket.id
    }
  }

  source {
    buildspec       = "smoke-tests/buildspec.yml"
    git_clone_depth = 1
    location        = aws_codecommit_repository.website.clone_url_http
    type            = "CODECOMMIT"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = aws_cloudwatch_log_stream.codebuild.name
    }
  }

  tags = {
    Environment = "tools"
    Terraform   = true
  }
}
```

### Source Control

Finally, under the `smoke-tests` directory, add a `buildspec.yml`:

```yml
version: 0.2

env:
    variables:
        # Disable terminal colour.
        # https://docs.cypress.io/guides/references/changelog.html#3-0-0
        NO_COLOR: 1
        TERM: "xterm-mono"

phases:
    install:
        commands:
            - cd smoke-tests
            - yarn install --frozen-lockfile

    pre_build:
        commands:
            - yarn lint

    build:
        commands:
            - yarn start

    post_build:
        commands:
            # Copy screenshots to S3, rather than using CodePipeline to deploy,
            # as it will have no artifact if this fails!
            # Ignore failures, as successful tests do not yield screenshots.
            - aws s3 cp smoke-tests/cypress/screenshots/ "s3://$S3_ARTIFACTS_BUCKET/smoke-tests/" --recursive || true
            # Repeat for videos if recording.
```

## 🧪 Testing

Test changes to this container by building it locally with:

```sh
docker build -t docker-aws-cypress .
```

[aws]: https://aws.amazon.com/
[codebuild]: https://aws.amazon.com/codebuild/
[codepipeline]: https://aws.amazon.com/codepipeline/
[cypress]: https://www.cypress.io/
[docker]: https://www.docker.com/
[site]: https://hub.docker.com/r/whatishedoing/docker-aws-cypress
[terraform]: https://www.terraform.io/
