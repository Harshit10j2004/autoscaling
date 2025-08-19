#!/bin/bash

source /home/ubuntu/data/data.env

path="/home/ubuntu/data/instance_id.txt"
log="/home/ubuntu/logs/as_log.txt"

count=1

cpu=$(mpstat 1 1 | grep Average | awk '{print 100 - int($12)}')

echo "${cpu}"
echo "hitpoint1"


if [ "${cpu}" -gt 65 ]; then

        echo "hitpoint2"

        instance=$(aws ec2 run-instances \
                --image-id $AMI \
                --count "${count}" \
                --instance-type $INSTANCE \
                --key-name $KEY \
                --security-group-ids $SECURITY \
                --query Instances[0].InstanceId \
                --output text)

        aws ec2 wait instance-status-ok --instance-ids "${instance}"

        echo "${instance}" >> "${path}"
        echo "${instance} is created $(date)" >> "${log}"

        echo "hitpoint3"

        aws elbv2 register-targets \
                --target-group-arn $ARN \
                --targets Id="${instance}"

        if aws elbv2 describe-target-health \
                --target-group-arn $ARN \
                --targets Id="${instance}" \
                --query 'TargetHealthDescriptions[*].Target.Id' \
                --output text | grep -q "${instance}"; then

                echo "hitpoint a"

                echo "${instance} added to target group $(date)" >> "${log}"
        fi


        echo "hitpoint4"

fi

echo "hitpoint5"

if [ $cpu -lt 30 ]; then

        echo "hitpoint6"

        lines=$(wc -l < "${path}")


        if [ $lines -eq 0 ]; then

                echo "there is no extra server is there"

                exit 0
        fi

        echo "hitpoint x"

        instance_rm=$(tail -n 1 /home/ubuntu/data/instance_id.txt)

        aws elbv2 deregister-targets \
                --target-group-arn $ARN \
                --targets Id="${instance_rm}"

        echo "hitpoint7"
        echo "${instance_rm} is removed from the target group $(date)" >> "${log}"

        aws ec2 terminate-instances --instance-ids "${instance_rm}"

        echo "${instance_rm} is terminated $(date)" >> "${log}"

        sed -i '$d' /home/ubuntu/data/instance_id.txt

        echo "hitpoint8"
fi
