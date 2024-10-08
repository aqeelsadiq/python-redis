resource "aws_security_group" "python_sg" {
  vpc_id = aws_vpc.main-vpc.id

    ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "redis_sg" {
  vpc_id = aws_vpc.main-vpc.id

    ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "pythonredis_cluster" {
  name = "${var.resource-name}-pythonredis-cluster"
}


resource "aws_iam_role" "ecs_task_execution_role" {
  name = "aqeelecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_service_discovery_private_dns_namespace" "namespace" {
  name        = "myapp.local"
  description = "Private DNS namespace for my app"
  vpc         = aws_vpc.main-vpc.id
}

resource "aws_service_discovery_service" "redis" {
  name = "redis"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_ecs_task_definition" "redis-task" {
  family                   = "redis-task"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = "256"
  memory                  = "512"
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "redis"
      image     = "redis:latest"
      essential = true
      portMappings = [
        {
          containerPort = 6379
          protocol = "tcp"
          hostPort      = 6379
        },
      ]
    },
  ])
}


resource "aws_ecs_task_definition" "python" {
  family                   = "python-task"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = "256"
  memory                  = "512"
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "python"
      image     = "aqeelsadiq/newpy3"
      essential = true
      environment = [
        {
          name  = "REDIS_HOST"
          value = "redis.myapp.local"
        },
      ]
      
      portMappings = [
        {
          containerPort = 5000
          protocol = "tcp"
          hostPort = 5000
        },
      ]
    },
  ])
}

resource "aws_ecs_service" "redis-task" {
  name            = "redis-"
  cluster         = aws_ecs_cluster.pythonredis_cluster.id
  task_definition = aws_ecs_task_definition.redis-task.arn
  scheduling_strategy = "REPLICA"
  desired_count   = 1
  launch_type     = "FARGATE"
  depends_on      = [aws_iam_role.ecs_task_execution_role]

  network_configuration {
    subnets          = aws_subnet.pri-subnet1.*.id           
    security_groups  = [aws_security_group.redis_sg.id]
    assign_public_ip = false
  }
}



resource "aws_ecs_service" "python_service" {
  name            = "python_service"
  cluster         = aws_ecs_cluster.pythonredis_cluster.id
  task_definition = aws_ecs_task_definition.python.arn
  scheduling_strategy = "REPLICA"
  desired_count   = 1
  launch_type     = "FARGATE"
  depends_on      = [aws_iam_role.ecs_task_execution_role]

  network_configuration {
    subnets          = [aws_subnet.pub-subnet1[0].id, aws_subnet.pub-subnet1[1].id]
    security_groups  = [aws_security_group.python_sg.id]
    assign_public_ip = true
  }
}
