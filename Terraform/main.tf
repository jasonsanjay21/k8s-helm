provider "aws" {
  region = "eu-north-1"  # Stockholm
}

# Security Group
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-sg"
  description = "K8s master and worker SG"

  # Master API port
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kubernetes API Server"
  }

  # NodePort App
  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "App NodePort"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Master Node
resource "aws_instance" "master" {
  ami                         = "ami-0c02fb55956c7d316" # Ubuntu 22.04 LTS
  instance_type               = "t3.medium"
  key_name                    = "OctKey"
  vpc_security_group_ids      = [aws_security_group.k8s_sg.id]
  associate_public_ip_address = true

  tags = { Name = "k8s-master" }
}

# Worker Node
resource "aws_instance" "worker" {
  ami                         = "ami-0c02fb55956c7d316" # Ubuntu 22.04 LTS
  instance_type               = "t3.small"
  key_name                    = "OctKey"
  vpc_security_group_ids      = [aws_security_group.k8s_sg.id]
  associate_public_ip_address = true

  tags = { Name = "k8s-worker" }

  depends_on = [aws_instance.master]
}
