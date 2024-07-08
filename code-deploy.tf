data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "service_level_permissions" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "ecs:DescribeServices",
          "ecs:CreateTaskSet",
          "ecs:UpdateServicePrimaryTaskSet",
          "ecs:DeleteTaskSet",
        ]
        Effect   = "Allow"
        Resource = ["*"]
      },
    ]
  })
}

resource "aws_iam_policy" "load_balancing_readonly" {
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        Sid: "Statement1",
        Effect: "Allow",
        Action: [
          "elasticloadbalancing:Describe*",
          "elasticloadbalancing:Get*"
        ],
        Resource: "*"
      },
      {
        Sid: "Statement2",
        Effect: "Allow",
        Action: [
          "ec2:DescribeInstances",
          "ec2:DescribeClassicLinkInstances",
          "ec2:DescribeSecurityGroups"
        ],
        Resource: "*"
      },
      {
        Sid: "Statement3",
        Effect: "Allow",
        Action: "arc-zonal-shift:GetManagedResource",
        Resource: "arn:aws:elasticloadbalancing:*:*:loadbalancer/*"
      },
      {
        Sid: "Statement4",
        Effect: "Allow",
        Action: [
          "arc-zonal-shift:ListManagedResources",
          "arc-zonal-shift:ListZonalShifts"
        ],
        Resource: "*"
      }
    ]
  })
}

resource "aws_iam_policy" "load_balancing" {
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        Effect: "Allow",
        Action: "elasticloadbalancing:*",
        Resource: "*"
      },
      {
        Effect: "Allow",
        Action: [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcClassicLink",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeClassicLinkInstances",
          "ec2:DescribeRouteTables",
          "ec2:DescribeCoipPools",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeVpcPeeringConnections",
          "cognito-idp:DescribeUserPoolClient"
        ],
        Resource: "*"
      },
      {
        Effect: "Allow",
        Action: "iam:CreateServiceLinkedRole",
        Resource: "*",
        Condition: {
          "StringEquals": {
            "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect: "Allow",
        Action: "arc-zonal-shift:*",
        Resource: "arn:aws:elasticloadbalancing:*:*:loadbalancer/*"
      },
      {
        Effect: "Allow",
        Action: [
          "arc-zonal-shift:ListManagedResources",
          "arc-zonal-shift:ListZonalShifts"
        ],
        Resource: "*"
      }
    ]
  })
}

resource "aws_iam_role" "app-service-codedeploy-role" {
  name               = "app-service-codedeploy-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  managed_policy_arns = [
    aws_iam_policy.service_level_permissions.arn,
    aws_iam_policy.load_balancing.arn,
    aws_iam_policy.load_balancing_readonly.arn,
  ]
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.app-service-codedeploy-role.name
}

resource "aws_codedeploy_app" "app-service" {
  name = "app-service"
  compute_platform = "ECS"
}

resource "aws_codedeploy_deployment_group" "app-service-dg" {
  app_name = aws_codedeploy_app.app-service.name
  deployment_group_name = "app-service-dg"
  service_role_arn = aws_iam_role.app-service-codedeploy-role.arn
  deployment_config_name = "CodeDeployDefault.ECSCanary10Percent5Minutes"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.app.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.app.arn]
      }
      target_group {
        name = aws_lb_target_group.app-blue.name
      }
      target_group {
        name = aws_lb_target_group.app-green.name
      }
    }
  }
}