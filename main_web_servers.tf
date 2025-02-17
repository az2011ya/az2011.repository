provider "aws" {
 region = "us-east-2"
}

resource "aws_security_group" "instance" {
 name = "terraform-example-instance"
 ingress {
 from_port = 8080
 to_port = 8080
 protocol = "tcp"
 cidr_blocks = ["0.0.0.0/0"]
 }
}
resource "aws_instance" "example" {
 ami = "ami-0fb653ca2d3203ac1"
 instance_type = "t2.micro"
 #tags = {
 vpc_security_group_ids = [aws_security_group.instance.id]
 
user_data = <<-EOF
            #!/bin/bash
            echo "Hello, World" > index.html
            echo "${data.terraform_remote_state.db.outputs.address}" >> index.html 
            echo "${data.terraform_remote_state.db.outputs.port}" >> index.html
            nohup busybox httpd -f -p ${var.server_port} &
         
            EOF   
user_data_replace_on_change = true
tags = {
 Name = "terraform-example"
 }
}

data "terraform_remote_state" "db" {
 backend = "s3"
 config = {
 #bucket = "(YOUR_BUCKET_NAME)"
 bucket = "my-unique-terraform-up-and-running-state"
 key = "stage/data-stores/mysql/terraform.tfstate"
 region = "us-east-2"
 }
}
resource "aws_launch_template" "example" {
 image_id = "ami-0fb653ca2d3203ac1"
 instance_type = "t2.micro"
 #security_groups = [aws_security_group.instance.id]
 
 # Configurer les interfaces réseau
 network_interfaces {
     associate_public_ip_address = true
     security_groups             = [aws_security_group.instance.id]
 }

 # Render the User Data script as a template
 user_data = base64encode(templatefile("user-data.sh", {
   server_port = var.server_port
   db_address = data.terraform_remote_state.db.outputs.address
   db_port = data.terraform_remote_state.db.outputs.port
   })
  )
 
# Required when using a launch configuration with an auto scaling group.
 lifecycle {
    create_before_destroy = true
 }
}
