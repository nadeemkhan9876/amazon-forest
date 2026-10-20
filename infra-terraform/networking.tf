# Looks up which availability zones exist in your region (read-only, free)
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" # the address range for the whole network
  enable_dns_support   = true
  enable_dns_hostnames = true # needed by EKS and RDS

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ---------- Subnets ----------
# Public subnet in the first AZ
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id # hint: which attribute holds the VPC's ID?
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0] # hint: first item = index 0
  map_public_ip_on_launch = true                                           # servers here get a public IP

  tags = {
    Name                     = "${var.project_name}-public-1"
    "kubernetes.io/role/elb" = "1"
  }
}

# TODO: public_2  -> cidr 10.0.2.0/24, second AZ (index 1)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id # hint: which attribute holds the VPC's ID?
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1] # hint: first item = index 1
  map_public_ip_on_launch = true                                           # servers here get a public IP

  tags = {
    Name                     = "${var.project_name}-public-2"
    "kubernetes.io/role/elb" = "1"
  }
}



# TODO: private_1 -> cidr 10.0.11.0/24, first AZ,  map_public_ip_on_launch = false
resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.main.id # hint: which attribute holds the VPC's ID?
  cidr_block              = "10.0.11.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0] # hint: first item = index 0
  map_public_ip_on_launch = false                                          # servers here do not get a public IP

  tags = {
    Name                     = "${var.project_name}-private-1"
    "kubernetes.io/role/elb" = "1"
  }
}

# TODO: private_2 -> cidr 10.0.12.0/24, second AZ, map_public_ip_on_launch = false
resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.main.id # hint: which attribute holds the VPC's ID?
  cidr_block              = "10.0.12.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1] # hint: first item = index 1
  map_public_ip_on_launch = false                                          # servers here do not get a public IP

  tags = {
    Name                     = "${var.project_name}-private-2"
    "kubernetes.io/role/elb" = "1"
  }
}

# ---------- Internet Gateway ----------
# The door between the VPC and the internet (free).
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id # hint: same pattern as in the subnets

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ---------- Public route table ----------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                  # "everything that isn't inside the VPC"
    gateway_id = aws_internet_gateway.main.id # send it out through the IGW
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# A route table does nothing until it is attached to subnets.
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# TODO: public_2 association, same pattern, for aws_subnet.public_2
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ---------- NAT Gateway (billable!) ----------
# A fixed public IP address for the NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id         # the IP address above
  subnet_id     = aws_subnet.public_1.id # NAT must live in a PUBLIC subnet

  tags = {
    Name = "${var.project_name}-nat"
  }

  # NAT needs the Internet Gateway to exist first (a hidden dependency)
  depends_on = [aws_internet_gateway.main]
}

# ---------- Private route table ----------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id # outbound traffic goes via NAT, NOT the IGW
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}



# TODO: two associations, private_1 and private_2, same pattern as the public ones,
#       but pointing to aws_route_table.private
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}
# ---------- Security group for the EKS nodes ----------
resource "aws_security_group" "eks" {
  name        = "${var.project_name}-eks-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Nodes can talk to each other"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    self        = true # "self" = members of this same security group
  }

  egress {
    description = "Nodes can reach the internet (via NAT)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-sg"
  }
}

# ---------- Security group for the database ----------
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow PostgreSQL only from EKS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432 # which port does PostgreSQL use?
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks.id] # source = the EKS security group, not an IP range
  }

  ingress {
    description = "PostgreSQL from EKS pods"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # source = the EKS cluster's security group, which is not the same as the node group SG
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}