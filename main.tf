# Create
resource "azurerm_resource_group" "vnet" {
  name     = var.vnet_resource_group_name
  location = var.location
}

resource "azurerm_resource_group" "kube" {
  name     = var.kube_resource_group_name
  location = var.location
}

# Create Virtual Network
resource "azurerm_virtual_network" "aksvnet" {
  name                = "aks-rnd-network"
  location            = azurerm_resource_group.vnet.location
  resource_group_name = azurerm_resource_group.vnet.name
  address_space       = ["10.1.0.0/16"]
}

# Create a Subnet for AKS
resource "azurerm_subnet" "aks-default" {
  name                 = "aks-rnd-default-subnet"
  virtual_network_name = azurerm_virtual_network.aksvnet.name
  resource_group_name  = azurerm_resource_group.vnet.name
  address_prefixes     = ["10.1.4.0/22"]
}

# Create log analytics
resource "random_id" "log_analytics_workspace_name_suffix" {
    byte_length = 8
}

resource "azurerm_log_analytics_workspace" "test" {
    # The WorkSpace name has to be unique across the whole of azure, not just the current subscription/tenant.
    name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
    location            = var.log_analytics_workspace_location
    resource_group_name = azurerm_resource_group.kube.name
    sku                 = var.log_analytics_workspace_sku
}

#resource "azurerm_log_analytics_solution" "test" {
#    solution_name         = "Containers"
#    location              = azurerm_log_analytics_workspace.test.location
#    resource_group_name   = azurerm_resource_group.kube.name
#    workspace_resource_id = azurerm_log_analytics_workspace.test.id
#    workspace_name        = azurerm_log_analytics_workspace.test.name

#    plan {
#        publisher = "Microsoft"
#        product   = "OMSGallery/Containers"
#    }
#}

# Create AKS Cluster
resource "azurerm_kubernetes_cluster" "k8s" {
    name                = var.cluster_name
    location            = azurerm_resource_group.kube.location
    resource_group_name = azurerm_resource_group.kube.name
    dns_prefix          = var.dns_prefix
    public_network_access_enabled = true
    kubernetes_version  = "1.22.6"
   
    default_node_pool {
        name            = "agentpool"
        node_count      = var.agent_count
        availability_zones = ["1", "2", "3"]
        vm_size         = "Standard_D2_v2"
        vnet_subnet_id  = azurerm_subnet.aks-default.id
        
    }

     identity {
        type = "SystemAssigned"
    }


    addon_profile {
        oms_agent {
        enabled                    = true
        log_analytics_workspace_id = azurerm_log_analytics_workspace.test.id
        }
    }

    network_profile {
        load_balancer_sku = "Standard"
        network_plugin    = "azure"
        network_policy    = "calico"
    }

    tags = {
        Environment = "Development"
    }
}
