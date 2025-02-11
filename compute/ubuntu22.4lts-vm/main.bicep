@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the Virtual Machine.')
param vmName string

@description('The size of the Virtual Machine.')
param vmSize string = 'Standard_D2s_v5'

@description('Name of the virtual network.')
param vnetName string

@description('Address prefix for the virtual network.')
param vnetAddressPrefix string = '10.2.0.0/16'

@description('Address prefix for the Virtual Machine subnet.')
param vmSubnetAddressPrefix string = '10.2.0.0/24'

@description('Name of the Virtual Machine subnet.')
param vmSubnetName string

@description('Specify whether to use existing subnet')
param useExistingSubnet bool = false

var vmPipName = '${vmName}-pip'
var vmNicName = '${vmName}-nic'
var vmNsgName = '${vmName}-nsg'

resource vmNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = if (!useExistingSubnet) {
  name: vmNsgName
  location: location
  properties: {
    securityRules: [
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = if (!useExistingSubnet) {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: vmSubnetName
        properties: {
          addressPrefix: vmSubnetAddressPrefix
          networkSecurityGroup: {
            id: vmNsg.id
          }
        }
      }
    ]
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: vmSubnetName
}

resource existingVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = if (useExistingSubnet) {
  name: vnetName
  location: location
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: existingVirtualNetwork
  name: vmSubnetName
}

resource vmPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: vmPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource vmNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: vmNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConfig'
        properties: {
          publicIPAddress: {
            id: vmPip.id
          }
          subnet: {
            id: useExistingSubnet ? existingSubnet.id : subnet.id
          }
        }
      }
    ]
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: 'azureuser'
      adminPassword: 'Password1234!'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
        }
      ]
    }
  }
}
