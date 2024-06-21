# Copyright (c) 2023, 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

# When defined in the Terraform configuration, the following variables automatically prepopulate with values on the Console pages used to create and edit the stack.
# The stack's values are used when you select the Terraform actions Plan, Apply, and Destroy.
# - tenancy_ocid (tenancy OCID)
# - region (region)
#
# Ref - https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/terraformconfigresourcemanager_topic-schema.htm#console-howto__prepop

####
##  Provider Variables
####

variable "tenancy_ocid" {
  type = string
}

variable "region" {
  type = string
}

variable "user_ocid" {
  type    = string
  default = ""
}

variable "private_key_path" {
  type    = string
  default = ""
}

variable "fingerprint" {
  type    = string
  default = ""
}

####
## Boat configuration - Used for internal developement purpose only.
####

# Option to enable BOAT authentication.
variable "boat_auth" {
  type    = bool
  default = false
}

# OCID of BOAT tenancy.
variable "boat_tenancy_ocid" {
  type    = string
  default = ""
}

####
## Stack Variable - Auto-pupulated while running RM Stack
####

# Stack compartment - where marketplace app / Resoruce Manager stack is executed
variable "compartment_ocid" {
  type    = string
  default = ""
}

# OCID of user running the marketplace app / Resoruce Manager stack
variable "current_user_ocid" {
  type    = string
  default = ""
}

####
##  Hidden Inputs
####

variable "debug" {
  type    = bool
  default = false
}

# NOTE: This might be helpful with livelab support
# Kubernetes Namespace
# variable "kubernetes_namespace" {
#   type    = string
#   default = "oci-onm"
# }

# [Depretiated][Released][Hidden]
# Option to create Dynamic Group and Policies
# variable "opt_create_dynamicGroup_and_policies" {
#   type    = bool
#   default = false
# }

# [Released][Hidden] #TODO: Should we retire this input
# OKE Cluster Name
variable "oke_cluster_name" {
  type    = string
  default = null
  # User Facing Error
  validation {
    condition = var.oke_cluster_name == null ? true : length(regexall("(^\\S+.*$|^$)", var.oke_cluster_name)) > 0
    #TODO negative and positive test using API
    error_message = "Invalid input:oke_cluster_name | RegeEx Validation: (^\\S+.*$)"
  }
}

#### [Section]
##  Select an OKE cluster deployed in this region to start monitoring
####

# OKE Cluster Compartment
variable "oke_compartment_ocid" {
  type = string
}

# OKE Cluster OCID
variable "oke_cluster_ocid" {
  type = string
}

# OKE Cluster OCID
variable "connect_via_private_endpoint" {
  type    = bool
  default = false
}

# OKE Cluster OCID
variable "oke_subnet_or_pe_ocid" {
  type    = string
  default = null

  # User Facing Error
  validation {
    condition     = var.oke_subnet_or_pe_ocid == null ? true : length(regexall("^ocid1\\.(subnet|ormprivateendpoint)\\.\\S+$", var.oke_subnet_or_pe_ocid)) > 0
    error_message = "Incorrect format: var.oke_subnet_or_pe_ocid"
  }
}

#### [Section]
##  Create Dynamic Group and Policy (tenancy level admin access required)
####

# New Dropdown option for Dynamic Group and Policies
variable "dropdown_create_dynamic_group_and_policies" {
  type = string
}

#### [Section]
##  OCI Observability and Management Services Configuration
####

# Compartment for creating OCI Observability and Management resources
variable "oci_onm_compartment_ocid" {
  type = string
}

# Option to create Logging Analytics
variable "opt_create_new_la_log_group" {
  type    = bool
  default = false
}

# OCI Logging Analytics LogGroup OCID
variable "oci_la_log_group_ocid" {
  type    = string
  default = null
}

# New Log Group to collect Kubernetes data
variable "oci_la_log_group_name" {
  type    = string
  default = null

  # User Facing Error
  validation {
    condition = var.oci_la_log_group_name == null ? true : var.oci_la_log_group_name == "" || (
    length(var.oci_la_log_group_name) < 100 && length(regexall("\\S", var.oci_la_log_group_name)) > 0)
    error_message = "Invalid log group name."
  }
}

# Option to create Logging Analytics
variable "opt_create_oci_la_entity" {
  type    = bool
  default = true
}

# OKE Cluster Entity OCID
variable "oke_cluster_entity_ocid" {
  type    = string
  default = null

  # User Facing Error
  validation {
    condition     = var.oke_cluster_entity_ocid == null ? true : length(regexall("^(ocid1\\.loganalyticsentity\\.\\S+)$", var.oke_cluster_entity_ocid)) > 0 ? true : false
    error_message = "var.oke_cluster_entity_ocid must be set to a valid value."
  }
}

# Option to import dashboards
variable "opt_import_dashboards" {
  type    = bool
  default = true
}

#### [Section]
##  Advanced Configuration
####

# Option to hidden stack configuration
variable "show_advanced_options" {
  type    = bool
  default = false
}

# Stack Deployment Options
variable "stack_deployment_option" {
  type    = string
  default = "Full"
}

# Helm Chart version to deploy
variable "helm_chart_version" {
  type    = string
  default = null
}

# Option to deploy metric server
variable "opt_deploy_metric_server" {
  type    = bool
  default = true
}

# Fluentd Base Directory
variable "fluentd_base_dir_path" {
  type    = string
  default = "/var/log"
}

# tags
variable "tags" {
  type    = object({ freeformTags = map(string), definedTags = map(string) })
  default = { "freeformTags" = {}, "definedTags" = {} }
}

# This var is not used in stack
# Purpose: to display stack version on UI without being able to execute it
variable "template_version" {
  type    = string
  default = null
}