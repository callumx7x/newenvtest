variable "region" {
  type = string
  default = "eu-west-2"
}

variable "main_vpc_cidr" {
  type = string
  default = "172.16.0.0/24"
}

variable "public_subnets_euw2a" {
  type = string
  default = "172.16.0.32/27"
}

variable "public_subnets_euw2b" {
  type = string
  default = "172.16.0.64/27"
}

variable "private_subnet_euw2c" {
  type = string
  default = "172.16.0.96/27"
}

variable "infrabuild" {
  type = string
  default = "environment01"
}

variable "ami" {
  type = string
  default = "ami-0476e8ece2c23831e"
}

variable "instance_count" {
  default = "2"
}

variable "instance_type" {
  default = "t3a.micro"
}

variable "ssh_key" {
  default = "callum.pem"
}
