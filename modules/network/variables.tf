variable "name_prefix" {
  description = "Prefix used in resource names, e.g. aksplat-dev."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the hub and spoke virtual networks."
  type        = string
}

variable "hub_address_space" {
  description = "CIDR block of the hub virtual network."
  type        = string
}

variable "spoke_address_space" {
  description = "CIDR block of the spoke virtual network."
  type        = string
}

variable "hub_subnets" {
  description = "Hub subnets keyed by short name. Each subnet gets its own NSG with the given rules."
  type = map(object({
    address_prefixes = list(string)
    nsg_rules = optional(list(object({
      name                       = string
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      source_port_range          = optional(string, "*")
      destination_port_range     = string
      source_address_prefix      = string
      destination_address_prefix = optional(string, "*")
    })), [])
  }))
}

variable "spoke_subnets" {
  description = "Spoke subnets keyed by short name. Each subnet gets its own NSG with the given rules."
  type = map(object({
    address_prefixes = list(string)
    nsg_rules = optional(list(object({
      name                       = string
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      source_port_range          = optional(string, "*")
      destination_port_range     = string
      source_address_prefix      = string
      destination_address_prefix = optional(string, "*")
    })), [])
  }))
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
