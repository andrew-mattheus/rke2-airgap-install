# rke2-airgap-install
Install rke2 airgapped

The rke2_config.sh defines the locations of the tarballs for an offline install. 


# Specify agent mode

Specify the INSTALL_RKE2_TYPE (in the rke2_config.sh)when running the script:

sudo ./install_rke2_airgapped.sh server  #For Master Node
sudo ./install_rke2_airgapped.sh agent   #For Worker Node

(It defaults to "server" if nothing is entered).
