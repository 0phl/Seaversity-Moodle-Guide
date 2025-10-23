# VM Cloning Guide

## Step 1: Clone the Template VM

1. Navigate to **Virtual Machine** → **PCI_Cluster (84)** → **Templates folder**
2. Clone the template: `"(T)-RL-9-mti-clone-mtipackage"`
3. Configure the clone settings:
   - **VM Name**: Change based on your preferred name
   - **Group**: Select the destination folder (e.g., Practice folder)
   - **Tag**: MTI
   - **Subnet**: Templates (192.168.254.0/24)
   - **Hostname**: Use default hostname
4. Enable auto-startup:
   - Check **"Auto Startup: Auto power on VM upon clone completion"**
5. Click **OK** to start the cloning process

## Step 2: Wait for Cloning Completion

Wait for the cloning process to finish before proceeding to the next step.

## Step 3: Configure Destination NAT

1. Navigate to **Topology** → **VPC Gateway**
2. Go to **Settings** → **Destination NAT**
3. Click **NEW** to create a new NAT rule
4. Configure the NAT settings:
   - **Description**: Enter a description for your VM (e.g., Practice VM)
   - **Group**: Default
   - **Source IP**: ALL
   - **Elastic IP**: Select the 2nd one (Eastern)
   - **Protocol**: TCP
   - **Port**: Choose a unique port (e.g., 300) - ensure it's not used by other VMs
   - **Internal IP**:
     - **Resource Type**: Virtual Machine
     - **Resource**: Select your cloned VM
   - **Mapped Port**: 22
5. Save the configuration

Your VM is now cloned and configured with network access.