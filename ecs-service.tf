resource "aws_ecs_cluster" "main" {
  name = "main-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = aws_subnet.public.*.id
    security_groups  = [aws_security_group.alb.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app-blue.arn
    container_name   = "app"
    container_port   = 80
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  force_new_deployment = false

  depends_on = [
    aws_lb_listener.app
  ]
}
