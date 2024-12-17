# Copyright (c) 2023, 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

locals {
  cluster_ocid_md5 = md5(var.oke_cluster_ocid)

  # Dynamic Group
  dynamic_group_name            = "oci-kubernetes-monitoring-${local.cluster_ocid_md5}"
  dynamic_group_desc            = "Auto generated by Resource Manager Stack - oci-kubernetes-monitoring. Required for monitoring OKE Cluster - ${var.oke_cluster_ocid}"
  instances_in_compartment_rule = ["ALL {instance.compartment.id = '${var.oke_compartment_ocid}'}"]
  management_agent_rule         = ["ALL {resource.type='managementagent', resource.compartment.id='${var.oci_onm_compartment_ocid}'}"]
  service_connector_rule        = ["ALL {resource.type='serviceconnector', resource.compartment.id='${var.oci_onm_compartment_ocid}'}"]
  dynamic_group_matching_rules  = concat(local.instances_in_compartment_rule, local.management_agent_rule, local.service_connector_rule)
  complied_dynamic_group_rules  = "ANY {${join(",", local.dynamic_group_matching_rules)}}"
  defined_namespaces            = join(",", [for namespace in module.tag_namespaces.namespaces : "target.tag-namespace.name='${namespace}'"])
  tags_policy_where_clause      = length(var.tags.definedTags) == 0 ? "" : "where any {${local.defined_namespaces}}"

  # Policy
  policy_name = "oci-kubernetes-monitoring-${local.cluster_ocid_md5}"
  policy_desc = "Auto generated by Resource Manager Stack - oci-kubernetes-monitoring. Allows Fluentd and MgmtAgent Pods running inside Kubernetes Cluster to send the data to OCI Logging Analytics and OCI Monitoring respectively."

  onm_compartment_scope = var.root_compartment_ocid == var.oci_onm_compartment_ocid ? "tenancy" : "compartment id ${var.oci_onm_compartment_ocid}"
  oke_compartment_scope = var.root_compartment_ocid == var.oke_compartment_ocid ? "tenancy" : "compartment id ${var.oci_onm_compartment_ocid}"

  policy_stmts = {
    metric_upload = ["Allow dynamic-group ${local.dynamic_group_name} to use METRICS in ${local.onm_compartment_scope} WHERE target.metrics.namespace = 'mgmtagent_kubernetes_metrics'"],
    log_upload    = ["Allow dynamic-group ${local.dynamic_group_name} to {LOG_ANALYTICS_LOG_GROUP_UPLOAD_LOGS} in ${local.onm_compartment_scope}"],
    discovery_api = ["Allow dynamic-group ${local.dynamic_group_name} to {LOG_ANALYTICS_DISCOVERY_UPLOAD} in tenancy"],
    tag_namespace = ["Allow dynamic-group ${local.dynamic_group_name} to use tag-namespaces in tenancy ${local.tags_policy_where_clause}"]
    infra_discovery_stmt = [
      "Allow dynamic-group ${local.dynamic_group_name} to inspect compartments in tenancy",
      # https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/contengpolicyreference.htm
      "Allow dynamic-group ${local.dynamic_group_name} to use clusters in tenancy where target.cluster.id=${var.oke_cluster_ocid}",
      "Allow dynamic-group ${local.dynamic_group_name} to read cluster-node-pools in tenancy",
      # https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/corepolicyreference.htm
      # Note:
      # Customers will need to create additional policies to support VCN and subnets in non-OKE compartments
      "Allow dynamic-group ${local.dynamic_group_name} to read vcns in ${local.oke_compartment_scope}",
      "Allow dynamic-group ${local.dynamic_group_name} to use subnets in ${local.oke_compartment_scope}",
      # https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/lbpolicyreference.htm
      "Allow dynamic-group ${local.dynamic_group_name} to use load-balancers in ${local.oke_compartment_scope}"
    ],
    # Note:
    # In Order to read data from an existing log-group (which can we part of any compartment),
    # We must allow read access in at least, both ONM and OKE compartments
    # Compartment of Logging LogGroup is not known at the time of policy creation via stack
    # We assume that Logging Log Groups are only created in either OKE or ONM compartments
    service_discovery_stmt = var.create_service_discovery_policies ? distinct([
      "Allow dynamic-group ${local.dynamic_group_name} to manage log-groups in ${local.onm_compartment_scope}",
      "Allow dynamic-group ${local.dynamic_group_name} to manage log-groups in ${local.oke_compartment_scope}",

      "Allow dynamic-group ${local.dynamic_group_name} to read log-content in ${local.onm_compartment_scope}",
      "Allow dynamic-group ${local.dynamic_group_name} to read log-content in ${local.oke_compartment_scope}",

      # Required for LogGroup Creation; there is an internal JIRA for it
      "Allow dynamic-group ${local.dynamic_group_name} to {SUBNET_UPDATE} in ${local.onm_compartment_scope}",
      "Allow dynamic-group ${local.dynamic_group_name} to {SUBNET_UPDATE} in ${local.oke_compartment_scope}",

      # Following resources will always be created in ONM compartment
      "Allow dynamic-group ${local.dynamic_group_name} to manage serviceconnectors in ${local.onm_compartment_scope}",
      "Allow dynamic-group ${local.dynamic_group_name} to manage orm-stacks in ${local.onm_compartment_scope}",
      "Allow dynamic-group ${local.dynamic_group_name} to manage orm-jobs in ${local.onm_compartment_scope}",
      "Allow dynamic-group ${local.dynamic_group_name} to read loganalytics-entity in ${local.onm_compartment_scope}",
      "Allow dynamic-group ${local.dynamic_group_name} to use loganalytics-log-group in ${local.onm_compartment_scope}"
    ]) : []
  }

  combined_policy_statements = distinct(flatten([for policy, stmt in local.policy_stmts : stmt]))
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
  statements     = local.combined_policy_statements

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