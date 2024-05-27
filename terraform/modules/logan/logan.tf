# Copyright (c) 2023, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

locals {
  oci_la_namespace = data.oci_log_analytics_namespaces.logan_namespaces.namespace_collection[0].items[0].namespace
  k8s_entity_type  = "Kubernetes Cluster"

  create_new_logGroup   = var.logGroup_ocid == null #var.new_logGroup_name != null
  create_new_k8s_entity = var.entity_ocid == null   #var.new_oke_entity_name != null
}

data "oci_log_analytics_log_analytics_entity" "user_provided_entity" {
  count                   = !local.create_new_k8s_entity ? 1 : 0
  log_analytics_entity_id = var.entity_ocid
  namespace               = local.oci_la_namespace
}

resource "null_resource" "user_provided_entity_check" {
  count = !local.create_new_k8s_entity ? 1 : 0
  lifecycle {
    precondition {
      # Incorrect Entity ID check
      condition     = !(data.oci_log_analytics_log_analytics_entity.user_provided_entity[0].entity_type_name == null)
      error_message = <<-EOT
        Invalid entity OCID: ${var.entity_ocid}
      EOT
    }

    precondition {
      # Incorrect Entity Type check
      condition     = data.oci_log_analytics_log_analytics_entity.user_provided_entity[0].entity_type_name == local.k8s_entity_type
      error_message = <<-EOT
        Incorrect entity Type Error:
        Entity: ${var.entity_ocid} is not of type: Kubenetes Cluster
      EOT
    }
  }
}

resource "oci_log_analytics_log_analytics_log_group" "new_log_group" {
  count = local.create_new_logGroup ? 1 : 0
  #Required
  compartment_id = var.compartment_ocid
  display_name   = var.new_logGroup_name
  namespace      = local.oci_la_namespace
  description    = "LogGroup for Kubernetes Logs"

  #tags
  defined_tags  = var.tags.definedTags
  freeform_tags = var.tags.freeformTags

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }

  #Optional
  # lifecycle {
  #   precondition {
  #     condition     = data.oci_log_analytics_namespaces.logan_namespaces.namespace_collection[0].items[0].is_onboarded == true
  #     error_message = "Tenancy is not on-boarded to OCI Logging Analytics Service in ${var.region} region."
  #   }
  # }
}

resource "oci_log_analytics_log_analytics_entity" "oke" {
  count = local.create_new_k8s_entity ? 1 : 0
  #Required
  compartment_id   = var.compartment_ocid
  entity_type_name = local.k8s_entity_type
  name             = var.new_oke_entity_name
  namespace        = local.oci_la_namespace
  #Optional
  cloud_resource_id = null #TODO add ocid of OKE later ?
  #tags
  defined_tags  = var.tags.definedTags
  freeform_tags = var.tags.freeformTags

  lifecycle {
    ignore_changes = [name, defined_tags, freeform_tags]
    precondition {
      condition     = !(var.entity_ocid == null && var.new_oke_entity_name == null)
      error_message = "Logical Error: var.new_oke_entity_name and var.entity_ocid, both can not be null."
    }
    ## name:
    ##    Default entity name is generated from default OKE cluster name at the time of stack execution.
    ##    When OKE cluster name is udpated via UI, we should need deleate &create a new entity
  }

}

data "oci_log_analytics_namespaces" "logan_namespaces" {
  compartment_id = var.tenancy_ocid
}