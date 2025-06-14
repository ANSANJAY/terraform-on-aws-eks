# Terraform Small Utility Project 

## Step-01: Introduction
### Current Problem: 
- We are not able to create EC2 Instances in all the subnets of our VPC which are spread across all availability zones in that region
### Approach to  a Solution:
- We need to find a solution to say that our desired EC2 Instance Type `example: t3.micro` is supported in that availability zone or not
- In simple terms, give me the availability zone list in a particular region where by desired EC2 Instance Type (t3.micro) is supported
### Why utility project?
- In Terraform, we should `not` go and try things directly in large code base. 
- First try your requirements in small chunks and integrate that to main code base.
- We are going to do the same now.

## Step-02: c1-versions.tf
- Hard-coded the region as we are not going to use any `variables.tf` in this utility project
```t
# Provider Block
provider "aws" {
  region  = "us-east-1"
}
```

## Step-03: c2-v1-get-instancetype-supported-per-az-in-a-region.tf
- We are first going to explore the datasource and it outputs
```t
# Determine which Availability Zones support your instance type
aws ec2 describe-instance-type-offerings --location-type availability-zone  --filters Name=instance-type,Values=t3.micro --region us-east-1 --output table
```
### Step-03-01: Review / Create the datasource and its output
```t
# Datasource
data "aws_ec2_instance_type_offerings" "my_ins_type1" {
  filter {
    name   = "instance-type"
    values = ["t3.micro"]
  }
  filter {
    name   = "location"
    values = ["us-east-1a"]
    #values = ["us-east-1e"]    
  }
  location_type = "availability-zone"
}


# Output
output "output_v1_1" {
 value = data.aws_ec2_instance_type_offerings.my_ins_type1.instance_types
}
```
### Step-03-02: Execute Terraform Commands
```t
# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan
terraform apply -auto-approve
Observation: 
1. Output should have the instance value `t3.micro` when `values = ["us-east-1a"]` in location filter
# Sample Output
output_v1_1 = toset([
  "t3.micro",
])

# Make a change
Switch the values in `location` filter to `values = ["us-east-1e"]` and test again with `terraform plan`

# Terraform Plan
terraform plan
terraform apply -auto-approve
Observation: 
1. Output should have the instance value empty `[]` when `values = ["us-east-1e"]` in location filter
# Sample Output
output_v1_1 = toset([])
```

## Step-04: c2-v2-get-instancetype-supported-per-az-in-a-region.tf
- Using `for_each` create multiple instances of datasource and loop it with hard-coded availability zones in `for_each`
### Step-04-01: Review / Create the datasource and its output with for_each
```t
# Check if that respective Instance Type is supported in that Specific Region in list of availability Zones
# Get the List of Availability Zones in a Particular region where that respective Instance Type is supported
data "aws_ec2_instance_type_offerings" "my_ins_type2" {
  for_each = toset([ "us-east-1a", "us-east-1e" ])
  filter {
    name   = "instance-type"
    values = ["t3.micro"]
  }
  filter {
    name   = "location"
    values = [each.key]
  }
  location_type = "availability-zone"
}


# Important Note: Once for_each is set, its attributes must be accessed on specific instances
output "output_v2_1" {
 #value = data.aws_ec2_instance_type_offerings.my_ins_type1.instance_types
 value = toset([
      for t in data.aws_ec2_instance_type_offerings.my_ins_type2 : t.instance_types
    ])  
}

# Create a Map with Key as Availability Zone and value as Instance Type supported
output "output_v2_2" {
 value = { for az, details in data.aws_ec2_instance_type_offerings.my_ins_type2 :
  az => details.instance_types }   
}
```

### Step-04-02: Execute Terraform Commands
```t
# Terraform Plan
terraform plan
terraform apply -auto-approve
Observation: refer sample output
# Sample Output
output_v2_1 = toset([
  toset([
    "t3.micro",
  ]),
  toset([]),
])
output_v2_2 = {
  "us-east-1a" = toset([
    "t3.micro",
  ])
  "us-east-1e" = toset([])
}
```

## Step-05: c2-v3-get-instancetype-supported-per-az-in-a-region.tf

### Step-05-01: Add new datasource aws_availability_zones
- Get List of Availability Zones in a Specific Region
```t
# Get List of Availability Zones in a Specific Region
# Region is set in c1-versions.tf in Provider Block
data "aws_availability_zones" "my_azones" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
```

### Step-05-02: Update for_each with new datasource
```t
# Check if that respective Instance Type is supported in that Specific Region in list of availability Zones
# Get the List of Availability Zones in a Particular region where that respective Instance Type is supported
data "aws_ec2_instance_type_offerings" "my_ins_type" {
for_each=toset(data.aws_availability_zones.my_azones.names)
  filter {
    name   = "instance-type"
    values = ["t3.micro"]
  }
  filter {
    name   = "location"
    values = [each.key]
  }
  location_type = "availability-zone"
}
```

### Step-05-03: Implement Incremental Outputs till we reach what is required
```t
# Basic Output: All Availability Zones mapped to Supported Instance Types
output "output_v3_1" {
 value = { for az, details in data.aws_ec2_instance_type_offerings.my_ins_type :
  az => details.instance_types }   
}

# Filtered Output: Exclude Unsupported Availability Zones
output "output_v3_2" {
  value = { for az, details in data.aws_ec2_instance_type_offerings.my_ins_type :
  az => details.instance_types if length(details.instance_types) != 0 }
}

# Filtered Output: with Keys Function - Which gets keys from a Map
# This will return the list of availability zones supported for a instance type
output "output_v3_3" {
  value = keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type :
  az => details.instance_types if length(details.instance_types) != 0 }) 
}

# Filtered Output: As the output is list now, get the first item from list (just for learning)
output "output_v3_4" {
  value = keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type :
  az => details.instance_types if length(details.instance_types) != 0 })[0]
}
```

### Step-05-04: Execute Terraform Commands
```t
# Terraform Plan
terraform plan
terraform appy -auto-approve
Observation: refer sample output
1. In the final output you will only get the availability zones list in which `t3.micro` instance is supported
# Sample Output
output_v3_1 = {
  "us-east-1a" = toset([
    "t3.micro",
  ])
  "us-east-1b" = toset([
    "t3.micro",
  ])
  "us-east-1c" = toset([
    "t3.micro",
  ])
  "us-east-1d" = toset([
    "t3.micro",
  ])
  "us-east-1e" = toset([])
  "us-east-1f" = toset([
    "t3.micro",
  ])
}
output_v3_2 = {
  "us-east-1a" = toset([
    "t3.micro",
  ])
  "us-east-1b" = toset([
    "t3.micro",
  ])
  "us-east-1c" = toset([
    "t3.micro",
  ])
  "us-east-1d" = toset([
    "t3.micro",
  ])
  "us-east-1f" = toset([
    "t3.micro",
  ])
}
output_v3_3 = [
  "us-east-1a",
  "us-east-1b",
  "us-east-1c",
  "us-east-1d",
  "us-east-1f",
]
output_v3_4 = "us-east-1a"
```

## Step-06: Clean-Up
```t
# Terraform Destroy
terraform destroy -auto-approve

# Delete Files
rm -rf .terraform*
rm -rf terraform.tfstate*
```

---

Here’s the enriched guide for your:

# **Terraform Small Utility Project: Determine Supported Availability Zones for EC2 Instance Types**

---

## ✅ Simplified Explanation

### 🎯 **Goal**

Identify **which Availability Zones (AZs)** in a region support a specific EC2 instance type (`t3.micro`) — and **only use those AZs** for launching instances.

---

### 🧩 Why This Utility Project?

* Terraform code can break if you try to launch an instance in an AZ that **doesn't support the desired instance type**.
* Instead of failing mid-deployment, build this utility to **pre-filter supported AZs**.
* It’s modular and safe to **integrate into your main infra pipeline later**.

---

### 🔧 Step-by-Step Breakdown

---

### 🧱 **Step 1–2**: Set Up Provider

```hcl
provider "aws" {
  region = "us-east-1"
}
```

No variables — this is a self-contained, quick utility.

---

### 🔍 **Step 3: Validate One AZ Manually**

You check **manually** if `t3.micro` is supported in a specific AZ:

```hcl
data "aws_ec2_instance_type_offerings" "my_ins_type1" {
  filter {
    name   = "instance-type"
    values = ["t3.micro"]
  }
  filter {
    name   = "location"
    values = ["us-east-1a"]  # try "us-east-1e" to see failure
  }
  location_type = "availability-zone"
}
```

👉 **Output:**

```hcl
output = toset(["t3.micro"])   # or toset([]) if not supported
```

---

### 🔁 **Step 4: Loop Over Hardcoded AZs**

You loop over two AZs using `for_each`:

```hcl
for_each = toset(["us-east-1a", "us-east-1e"])
```

👉 Output:

* One zone supports the type → `["t3.micro"]`
* One does not → `[]`

You can now **create a map**:

```hcl
{ "us-east-1a" = ["t3.micro"], "us-east-1e" = [] }
```

---

### 🌐 **Step 5: Make It Dynamic With `aws_availability_zones`**

Instead of hardcoding, use this:

```hcl
data "aws_availability_zones" "my_azones" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
```

Then use all AZs dynamically:

```hcl
for_each = toset(data.aws_availability_zones.my_azones.names)
```

---

### ✅ Output Filtering Progression

#### 1. **Raw Map:**

```hcl
output_v3_1 = {
  "us-east-1a" = ["t3.micro"],
  "us-east-1e" = []
}
```

#### 2. **Filtered (exclude unsupported):**

```hcl
output_v3_2 = {
  "us-east-1a" = ["t3.micro"],
  "us-east-1b" = ["t3.micro"],
  ...
}
```

#### 3. **Just list AZs that support the type:**

```hcl
output_v3_3 = ["us-east-1a", "us-east-1b", "us-east-1c"]
```

#### 4. **Pick the first supported AZ (for demo):**

```hcl
output_v3_4 = "us-east-1a"
```

---

## 🧠 Interview Questions + Answers

### ❓ Why can an EC2 instance creation fail in Terraform even when the AZ seems valid?

**✅ A:** Because not all AZs support all EC2 instance types. Terraform may fail if you try to launch an unsupported type (e.g., `t3.micro` in `us-east-1e`).

---

### ❓ How can you programmatically get AZs that support a specific instance type?

**✅ A:**

* Use `aws_ec2_instance_type_offerings`
* Filter by `instance-type` and `location`
* Use `location_type = "availability-zone"`

---

### ❓ What Terraform data sources and functions did you use in this utility?

**✅ A:**

* `aws_ec2_instance_type_offerings`
* `aws_availability_zones`
* `for_each`
* `toset`, `keys()`, `length()`, map filtering

---

### ❓ Why build a utility like this before integrating into the main module?

**✅ A:**
To safely test edge cases like unsupported AZs or dynamic filtering before affecting your main production code. This promotes modular, fault-tolerant infrastructure.

---

## 🌍 Real-World Usage

| Scenario                                     | Value                                                      |
| -------------------------------------------- | ---------------------------------------------------------- |
| **Production-ready EC2 launch logic**        | Launch only in supported AZs                               |
| **Disaster recovery / HA design**            | Know which AZs are reliably compatible                     |
| **Region-level instance placement strategy** | Dynamically update supported AZs during automation         |
| **Cost-aware provisioning**                  | Pair with pricing API to choose cheapest *supported* AZs   |
| **Instance scheduling automation**           | Build tooling around availability + compatibility of types |

---

Would you like me to help you integrate this utility output into a production EC2 provisioning module using `for_each`?
