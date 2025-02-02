provider "aws" {
 region = "us-east-2"
}

resource "aws_security_group" "instance" {
 name = "terraform-example-instance"
 ingress {
 from_port = var.server_port 
 to_port = var.server_port
 protocol = "tcp"
 cidr_blocks = ["0.0.0.0/0"]
 }
}

resource "aws_instance" "example" {
 ami = "ami-0fb653ca2d3203ac1"
 instance_type = "t2.micro"
 vpc_security_group_ids = [aws_security_group.instance.id]
 
user_data = <<-EOF
            #!/bin/bash
            echo "Hello, World" > index.html
            nohup busybox httpd -f -p ${var.server_port} &
         
           EOF   

user_data_replace_on_change = true


tags = {
 Name = "terraform-example"
 }
}

output "public_ip" {
 value = aws_instance.example.public_ip
 description = "The public IP address of the web server"
}

resource "aws_launch_template" "example" {
   name     = "example-launch-template"
   image_id = "ami-0fb653ca2d3203ac1"
   instance_type = "t2.micro"
   # security_groups = [aws_security_group.instance.id]
   

   # Configurer les interfaces réseau
   network_interfaces {
     associate_public_ip_address = true
     security_groups             = [aws_security_group.instance.id]
  }
 
   user_data = base64encode(<<EOF
             #!/bin/bash
             echo "Hello, World" > index.html
             nohup busybox httpd -f -p ${var.server_port} &
             EOF
             )

   # Required when using a launch configuration with an auto scaling group.
   lifecycle {
     create_before_destroy = true
   }

}

resource "aws_autoscaling_group" "example" {
   #launch_configuration = aws_launch_configuration.example.name
   vpc_zone_identifier = data.aws_subnets.default.ids   
  # desired_capacity     = 1
   min_size = 2
   max_size = 10 
 
   tag {
     key = "Name"
     value = "terraform-asg-example"
     propagate_at_launch = true
  }

   launch_template {
    name = aws_launch_template.example.name
    version             = "$Latest"
  }
}


data "aws_vpc" "default" {
 default = true
}

data "aws_subnets" "default" {
 filter {
 name = "vpc-id"
 values = [data.aws_vpc.default.id]
 }
}
