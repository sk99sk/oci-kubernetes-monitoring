# Copyright (c) 2023, 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

locals {
  cluster_ocid_md5 = md5(var.oke_cluster_ocid)

  # Dynamic Group
  dynamic_group_name            = "oci-kubernetes-monitoring-${local.cluster_ocid_md5}"
  dynamic_group_desc            = "Auto generated by Resource Manager Stack - oci-kubernetes-monitoring. Required for monitoring OKE Cluster - ${var.oke_cluster_ocid}"
  instances_in_compartment_rule = ["ALL {instance.compartment.id = '${var.oke_compartment_ocid}'}"]
  management_agent_rule         = ["ALL {resource.type='managementagent', resource.compartment.id='${var.oci_onm_compartment_ocid}'}"]
  dynamic_group_matching_rules  = concat(local.instances_in_compartment_rule, local.management_agent_rule)
  complied_dynamic_group_rules  = "ANY {${join(",", local.dynamic_group_matching_rules)}}"
  defined_namespaces            = join(",", [for namespace in module.tag_namespaces.namespaces : "target.tag-namespace.name='${namespace}'"])
  tags_policy_where_clause      = length(var.tags.definedTags) == 0 ? "" : " where any {${local.defined_namespaces}}"

  # Policy
  policy_name                = "oci-kubernetes-monitoring-${local.cluster_ocid_md5}"
  policy_scope               = var.root_compartment_ocid == var.oci_onm_compartment_ocid ? "tenancy" : "compartment id ${var.oci_onm_compartment_ocid}"
  policy_desc                = "Auto generated by Resource Manager Stack - oci-kubernetes-monitoring. Allows Fluentd and MgmtAgent Pods running inside Kubernetes Cluster to send the data to OCI Logging Analytics and OCI Monitoring respectively."
  mgmt_agent_stmt            = ["Allow dynamic-group ${local.dynamic_group_name} to use METRICS in ${local.policy_scope} WHERE target.metrics.namespace = 'mgmtagent_kubernetes_metrics'"]
  fluentd_agent_stmt         = ["Allow dynamic-group ${local.dynamic_group_name} to {LOG_ANALYTICS_LOG_GROUP_UPLOAD_LOGS} in ${local.policy_scope}"]
  discovery_api_stmt         = ["Allow dynamic-group ${local.dynamic_group_name} to {LOG_ANALYTICS_DISCOVERY_UPLOAD} in tenancy"]
  tag_namespace_stmt         = ["Allow dynamic-group ${local.dynamic_group_name} to use tag-namespaces in tenancy${local.tags_policy_where_clause}"]
  compiled_policy_statements = concat(local.fluentd_agent_stmt, local.mgmt_agent_stmt, local.tag_namespace_stmt, local.discovery_api_stmt)
}

# https://docs.oracle.com/en-us/iaas/api/#/en/identity/20160918/DynamicGroup/
resource "oci_identity_dynamic_group" "oke_dynamic_group" {
  name           = local.dynamic_group_name
  description    = local.dynamic_group_desc
  compartment_id = var.root_compartment_ocid
  matching_rule  = local.complied_dynamic_group_rules

  #tags
  defined_tags  = var.tags.definedTags
  freeform_tags = var.tags.freeformTags

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
}

# https://docs.oracle.com/en-us/iaas/api/#/en/identity/20160918/Policy/
resource "oci_identity_policy" "oke_monitoring_policy" {
  name           = local.policy_name
  description    = local.policy_desc
  compartment_id = var.root_compartment_ocid
  statements     = local.compiled_policy_statements

  #tags
  defined_tags  = var.tags.definedTags
  freeform_tags = var.tags.freeformTags

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }

  depends_on = [oci_identity_dynamic_group.oke_dynamic_group]
}

# Parse defined tags
module "tag_namespaces" {
  source      = "./parse_namespaces"
  definedTags = var.tags.definedTags
}

