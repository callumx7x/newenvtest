provider "aws" {
   region = var.region
   access_key = "myaccesskey1"
   secret_key = "mysecretkey2"
 }

//terraform {
//   backend "s3" {
//     bucket = "terraform-state-files"
//     key    = "development/nbrown/nbrownenv.tfstate"
//     region = "eu-west-2"
//   }
// }


resource "aws_vpc" "main_vpc" {
  cidr_block       = var.main_vpc_cidr
  tags = {
    Name = "${var.infrabuild}_vpc"
  }
}

//Create the internet gateway and attach it to VPC the vpc id is being called from the resource so it knows what to attach to
resource "aws_internet_gateway" "aws_igwatt" {
   vpc_id =  aws_vpc.main_vpc.id
   tags = {
     Name = "${var.infrabuild}_igwatt"
   }
}

//Creating a public subnet for systems we do need accessible via the internet, store the subnet range as a var
resource "aws_subnet" "aws_pub_subnet_euw2a" {
  vpc_id =  aws_vpc.main_vpc.id
  cidr_block = var.public_subnets_euw2a
  availability_zone = "eu-west-2a"
  tags = {
    Name = "${var.infrabuild}_pubsubnet_euw2a"
  }
}

resource "aws_subnet" "aws_pub_subnet_euw2b" {
  vpc_id =  aws_vpc.main_vpc.id
  cidr_block = var.public_subnets_euw2b
  availability_zone = "eu-west-2b"
  tags = {
    Name = "${var.infrabuild}_pubsubnet_euw2b"
  }
}

//Creating a private subnet for systems we don't need accessible via the internet, store the subnet range as a var
resource "aws_subnet" "aws_priv_subnet" {
  vpc_id =  aws_vpc.main_vpc.id
  cidr_block = var.private_subnet_euw2c
  availability_zone = "eu-west-2c"
  tags = {
    Name = "${var.infrabuild}_privsubnet"
  }
}

//Create the routing table for the public subnet to allow internet access and route all traffic via it 0.0.0.0 via the internet gateway attachment
resource "aws_route_table" "aws_pub_rt" {
   vpc_id =  aws_vpc.main_vpc.id
   route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.aws_igwatt.id
    }
    tags = {
      Name = "${var.infrabuild}_publicrt"
    }
}

//Create the routing table which is used by the Private Subnet's to be funneled through the NAT GW to the internet etc. Allowing private instances to reach the outside world.
resource "aws_route_table" "aws_priv_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
  cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.aws_natgw.id
  }
  tags = {
    Name = "${var.infrabuild}_privatert"
  }
}

//Attach the Public route table with the public subnet so traffic have a route
resource "aws_route_table_association" "aws_public_rta_euw2a" {
   subnet_id = aws_subnet.aws_pub_subnet_euw2a.id
   route_table_id = aws_route_table.aws_pub_rt.id
}

resource "aws_route_table_association" "aws_public_rta_euw2b" {
   subnet_id = aws_subnet.aws_pub_subnet_euw2b.id
   route_table_id = aws_route_table.aws_pub_rt.id
}

//Attach the private route table with the private subnet so traffic have a route
resource "aws_route_table_association" "aws_private_rta" {
   subnet_id = aws_subnet.aws_priv_subnet.id
   route_table_id = aws_route_table.aws_priv_rt.id
}

// Create an EIP to attach to our NAT GW so we can route out publicly
resource "aws_eip" "aws_eip" {
  vpc   = true
  tags = {
    Name = "${var.infrabuild}_elasticip"
  }
}

//Create the NAT Gateway for the private subnet and allocate an elastic IP to allow internet access
resource "aws_nat_gateway" "aws_natgw" {
  allocation_id = aws_eip.aws_eip.id
  subnet_id = aws_subnet.aws_priv_subnet.id
  tags = {
    Name = "${var.infrabuild}_natgw"
  }
}

resource "aws_security_group" "public_sg" {
    name = "frontend_sg"
    description = "Allow public access to the servers"
    vpc_id = aws_vpc.main_vpc.id
}

resource "aws_security_group" "frontend_sg" {
  name        = "terraform_alb_security_group"
  description = "Terraform load balancer security group"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
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
  tags = {
    Name = "${var.infrabuild}_web_access"
  }
}

resource "aws_security_group" "aws_db_access" {
  name        = "db_port_access"
  description = "Allow MYSQL port access to our environment"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = [var.public_subnets_euw2a, var.public_subnets_euw2b]
  }
  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.infrabuild}_db_access"
  }
}

resource "aws_security_group" "ssh_access" {
  name = "ssh_access"
  description = "Allow SSH port access to our environment"
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    cidr_blocks = [
      "172.0.0.0/20"
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
 tags = {
   Name = "${var.infrabuild}_ssh_access"
 }
}

resource "aws_instance" "frontend" {
  ami           = var.ami
  instance_type = var.instance_type
  count = var.instance_count
  key_name    = var.ssh_key
  security_groups = [aws_security_group.frontend_sg.id, aws_security_group.ssh_access.id]
  tags = {
    Name = "frontend-${count.index + 1}"
  }
}

resource "aws_instance" "db_server" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name    = var.ssh_key
  security_groups = [aws_security_group.aws_db_access.id, aws_security_group.ssh_access.id]
  tags = {
    Name = "db-1"
  }
}

resource "aws_ebs_volume" "db_vol" {
  availability_zone = "eu-west-2c"
  size = 10
  tags = {
    Name = "db-volume"
  }
}

resource "aws_volume_attachment" "db_vol_attach" {
 device_name = "/dev/sdh"
 volume_id = aws_ebs_volume.db_vol.id
 instance_id = aws_instance.db_server.id
}
