#!/bin/bash

#export PATH=$PATH:/usr/local/bin

AMI_ID="ami-0220d79f3f480ecf5"
ZONE_ID="Z04246872QFC8QNNXAS1U" 
DOMAIN_NAME="devopsonline.online" 
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $# -lt 2 ]; then
   echo ""