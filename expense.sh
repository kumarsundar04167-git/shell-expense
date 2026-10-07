#!/bin/bash

AMI_ID="ami-0220d79f3f480ecf5"
ZONE_ID="Z04246872QFC8QNNXAS1U"
DOMAIN_NAME="devopsonline.online"

# Name prefix used in the instance Name tag.
# Existing Ansible-made instances are tagged "expence-*", so this matches them.
# Change to "expense" only if you terminated those and want new ones.
PREFIX="expense"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $# -lt 2 ]; then
    echo -e "$Y minimum two parameters required ..... [INFO] $N"
    echo -e "USAGE is: $Y $0 [create/delete] [instance1] [instance2].... $N"
    exit 1
fi

ACTION=$1
shift

if [ "$ACTION" != "create" ] && [ "$ACTION" != "delete" ]; then
    echo -e "$R [ERROR] first argument must be create or delete.....$N"
    echo -e "USAGE is: $Y $0 [create/delete] [instance1] [instance2].... $N"
    exit 1
fi

get_instance_id() {
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${PREFIX}-$1" "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].InstanceId" \
        --output text
}

for instance in "$@"
do
    INSTANCE_ID=$(get_instance_id "$instance")

    # empty or "None" both mean: no running instance found
    if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
        FOUND=false
    else
        FOUND=true
    fi

    if [ "$ACTION" = "create" ]; then
        if [ "$FOUND" = false ]; then
            echo "Launching Instance: ${PREFIX}-$instance"
            INSTANCE_ID=$(aws ec2 run-instances \
                --image-id "$AMI_ID" \
                --instance-type t3.micro \
                --security-groups "expense-$instance" \
                --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PREFIX}-$instance}]" \
                --query 'Instances[0].InstanceId' \
                --output text)

            if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
                echo -e "$R [ERROR] failed to launch $instance, skipping $N"
                continue
            fi

            echo "Launched Instance: $INSTANCE_ID"
            aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
            echo "Instance is running: $INSTANCE_ID"
        else
            echo "${PREFIX}-$instance already running: $INSTANCE_ID"
        fi

        # pick the IP and record name
        if [ "$instance" = "lb" ]; then
            IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
                --query 'Reservations[*].Instances[*].PublicIpAddress' \
                --output text)
            R53_RECORD="$DOMAIN_NAME"
        else
            IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
                --query 'Reservations[*].Instances[*].PrivateIpAddress' \
                --output text)
            R53_RECORD="$instance.$DOMAIN_NAME"
        fi

        if [ -z "$IP" ] || [ "$IP" = "None" ]; then
            echo -e "$R [ERROR] no IP found for $instance, skipping DNS $N"
            continue
        fi

        aws route53 change-resource-record-sets \
            --hosted-zone-id "$ZONE_ID" \
            --change-batch '
            {
                "Comment": "Update A record to new IP",
                "Changes": [
                    {
                        "Action": "UPSERT",
                        "ResourceRecordSet": {
                            "Name": "'"$R53_RECORD"'",
                            "Type": "A",
                            "TTL": 1,
                            "ResourceRecords": [
                                { "Value": "'"$IP"'" }
                            ]
                        }
                    }
                ]
            }
            ' > /dev/null
        echo -e "$G updated R53 record: $R53_RECORD -> $IP $N"

    else
        if [ "$FOUND" = false ]; then
            echo "$instance already destroyed, nothing to do..."
        else
            aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" > /dev/null
            echo "Terminating Instance: $instance ($INSTANCE_ID)"
        fi
    fi
done