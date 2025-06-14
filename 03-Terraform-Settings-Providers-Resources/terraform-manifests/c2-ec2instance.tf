# Resource: EC2 Instance
resource "aws_instance" "myec2vm" {
  ami = "ami-09e6f87a47903347c"
  instance_type = "t3.micro"
  user_data = file("${path.module}/app1-install.sh")
  tags = {
    "Name" = "EC2 Demo"
  }
}

