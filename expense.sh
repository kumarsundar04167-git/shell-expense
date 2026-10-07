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
   echo -e " $Y minimum two parameters required ..... [INFO] $N"
   echo -e "USAGE is: $Y $0 [create/delete] [instances1] [instance2].... $N "
   exit 1
fi

ACTION=$1
shift

if [ "$ACTION" != "create" ] && [ "$ACTION" != "delete" ]; then
   echo -e " $R [ERROR] first argument must be create or delete.....$N"
   echo -e "USAGE is: $Y $0 [create/delete] [instances1] [instance2].... $N"
   exit 1
fi

get_instance_id(){
   name=$1
   aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=expense-$name" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text

}

for instance in $@
do
    INSTANCE_ID=$(get_instance_id $instance)
    if [ "$ACTION" = "create" ]; then
        if [ "$INSTANCE_ID" = "None" ]; then
            echo "Launching Instance: expense-$instance"
            INSTANCE_ID=$( aws ec2 run-instances \
            --image-id $AMI_ID \
            --instance-type t3.micro \
            --security-groups  "expense-$instance" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=expense-$instance}]" \
            --query 'Instances[0].InstanceId' \
            --output text 
            )
            echo "Launched Instance: $INSTANCE_ID"
            aws ec2 wait instance-running --instance-ids $INSTANCE_ID
            echo "Instance is running: $INSTANCE_ID"

        else
            echo "expense-$instance already running: $INSTANCE_ID"
        fi

         # update R53 record
        if [ "$instance" = "lb" ]; then
            IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
            --query 'Reservations[*].Instances[*].PublicIpAddress' \
            --output text
            )
            R53_RECORD="$DOMAIN_NAME"
        else
            IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
            --query 'Reservations[*].Instances[*].PrivateIpAddress' \
            --output text
            )
            R53_RECORD="$instance.$DOMAIN_NAME"
        fi

        aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONE_ID \
        --change-batch '
            {
                "Comment": "Update A record to new IP",
                "Changes": [
                    {
                        "Action": "UPSERT",
                        "ResourceRecordSet": {
                            "Name": "'$R53_RECORD'",
                            "Type": "A",
                            "TTL": 1,
                            "ResourceRecords": [
                                {
                                    "Value": "'$IP'"
                                }
                            ]
                        }
                    }
                ]
            }
        '
        echo "updated R53 record for: $instance"
    else
        if [ "$INSTANCE_ID" == "None" ]; then
            echo "$instance already destroyed, nothing to do..."
        else
            aws ec2 terminate-instances --instance-ids $INSTANCE_ID
            echo "Terminating Instance: $instance"
        fi
    fi
done
