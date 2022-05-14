//terraform {
//  backend "s3" {
//     bucket = "terraform-state-files"
//     key    = "development/nbrown/vpc.tfstate"
//     region = "eu-west-2"
//   }
// }

provider "aws" {
  region = "eu-west-2"
}

module "new_env_build" {
  source = "../module"
  instance_type = "t3.medium"
}
