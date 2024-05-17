#!/bin/bash

# Update package & system
echo "Updating System..."
sudo apt-get update -y && sudo apt-get upgrade -y

# Install Java 17
echo "Installing Java 17..."
sudo apt-get install openjdk-17-jdk -y

# Install Jenkins
echo "Installing Jenkins..."
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update -y
sudo apt-get install jenkins -y
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Install Docker
echo "Installing Docker..."
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update -y
sudo apt-get install docker-ce -y

echo "Installation completed!"
