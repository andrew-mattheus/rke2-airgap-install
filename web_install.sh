#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

echo "Starting RKE2 setup..."

# Update the system and install required packages
echo "Updating the system and installing required packages..."
yum update -y && echo "System updated successfully!"
yum install -y curl tar wget zstd && echo "Required packages installed successfully!"

# Disable swap - 
echo "Disabling swap..."
echo "If you attempt to run RKE2 (or any Kubernetes setup) with swap enabled"
echo "The kubelet may throw an error unless explicitly configured to allow swap with the --fail-swap-on=false flag."
echo "Kubernetes assumes that when a pod reaches its memory limit, the system will take corrective action (e.g., evicting pods). Swap can delay this response, causing unpredictable behavior."
echo "Example error: kubelet: F0924 18:10:15.043467   81234 server.go:233] failed to run Kubelet: running with swap on is not supported; please disable swap!"
echo "The Kubernetes kubelet (the agent that runs on nodes) checks if swap is enabled. By default, if swap is not disabled, the kubelet will refuse to start."
echo "....."
swapoff -a && echo "Swap disabled successfully!"
sed -i '/ swap / s/^/#/' /etc/fstab && echo "Swap entry removed from fstab successfully!"

# Download RKE2 files
echo "Downloading RKE2 files..."
wget https://github.com/rancher/rke2/releases/download/v1.30.6%2Brke2r1/rke2-images.linux-amd64.tar.zst && echo "RKE2 images downloaded successfully!"
wget https://github.com/rancher/rke2/releases/download/v1.30.6%2Brke2r1/rke2.linux-amd64.tar.gz && echo "RKE2 binaries downloaded successfully!"
wget https://github.com/rancher/rke2/releases/download/v1.30.6%2Brke2r1/sha256sum-amd64.txt && echo "RKE2 sha256sum downloaded successfully!"

# Extract RKE2 binaries
echo "Extracting RKE2 binaries...  Processing the rke2.linux-amd64.tar.gz file to /usr/local"
tar -xvf rke2.linux-amd64.tar.gz -C /usr/local && echo "RKE2 binaries extracted successfully!"

# Verify the installation
echo "Verifying the RKE2 installation..."
rke2 --version && echo "RKE2 version verified successfully!"

# Create the RKE2 config directory and file
echo "Creating RKE2 config directory and file..."
mkdir -p /etc/rancher/rke2 && echo "RKE2 config directory created successfully!"
cat <<EOF > /etc/rancher/rke2/config.yaml
write-kubeconfig-mode: "0644"
tls-san:
  - "your-server-ip-or-hostname"
EOF
echo "RKE2 config.yaml created successfully!"

# Configure and enable the RKE2 systemd service
echo "Configuring the RKE2 systemd service..."
cp /usr/local/lib/systemd/system/rke2-server.service /etc/systemd/system/ && echo "RKE2 systemd service file copied successfully!"
systemctl daemon-reload
systemctl enable rke2-server && echo "RKE2 service enabled successfully for systemd!"
echo "This ensures that the RKE2 server or RKE2 agent runs as a system service, managed by systemd. This allows the RKE2 process to start automatically during system boot, be monitored, and be easily managed (e.g., start, stop, restart)."

# Decompress the images tarball
echo "Decompressing RKE2 images..."
zstd -d rke2-images.linux-amd64.tar.zst && echo "RKE2 images from rke2-images.linux-amd64.tar.zst decompressed successfully!"

# Move the decompressed tarball to the correct directory
echo "Moving decompressed tarball to the correct directory..."
mkdir -p /var/lib/rancher/rke2/agent/images/ && echo "RKE2 images directory created successfully!"
mv rke2-images.linux-amd64.tar /var/lib/rancher/rke2/agent/images/ && echo "RKE2 images from rke2-images.linux-amd64.tar.zst moved successfully to /var/lib/rancher/rke2/agent/images/ !"

# Start the RKE2 server
echo "Starting the RKE2 server... This may take a few minutes...."
systemctl start rke2-server && echo "RKE2 server started successfully!  Thank you for your patience."

# Check the server status
echo "Checking the RKE2 server status..."
systemctl status rke2-server --no-pager && echo "RKE2 server is running!  Just a few more things to configure...."

# Set up the kubeconfig for the root user
echo "Setting up kubeconfig for root user..."
mkdir -p ~/.kube && echo "Created .kube directory for root!"
cp /etc/rancher/rke2/rke2.yaml ~/.kube/config && echo "Copied RKE2 kubeconfig to ~/.kube/config!"
chown root:root ~/.kube/config && echo "Set ownership of kubeconfig to root!    ~/.kube/config   "

# Copy all executables from /var/lib/rancher/rke2/data/*/bin/ to /usr/local/bin
echo "Copying all RKE2 binaries to /usr/local/bin for global CLI access..."
for RKE2_BIN_DIR in /var/lib/rancher/rke2/data/*/bin/; do
    if [ -d "$RKE2_BIN_DIR" ]; then
        cp "$RKE2_BIN_DIR"/* /usr/local/bin/ && chmod +x /usr/local/bin/* && echo "RKE2 binaries from $RKE2_BIN_DIR copied to /usr/local/bin successfully!"
    else
        echo "RKE2 binary directory $RKE2_BIN_DIR not found! Exiting..."
        exit 1
    fi
done

# Display the Node Token
echo "Retrieving and displaying the node token..."
NODE_TOKEN_PATH="/var/lib/rancher/rke2/server/node-token"
if [ -f "$NODE_TOKEN_PATH" ]; then
    NODE_TOKEN=$(cat "$NODE_TOKEN_PATH")
    echo "Node token for worker nodes:"
    echo "-------------------------------------------------------------"
    echo "$NODE_TOKEN"
    echo "-------------------------------------------------------------"
else
    echo "Node token not found! Ensure the RKE2 server has started successfully."
fi

echo "RKE2 setup completed successfully!"
