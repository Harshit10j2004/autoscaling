#!/bin/bash

set -x

source /home/ubuntu/data/data.env

path="/home/ubuntu/data/instance_id.txt"
log="/home/ubuntu/logs/as_log.txt"

count=1

cpu=$(mpstat 1 1 | grep Average | awk '{print 100 - int($12)}')

echo "$(date)"
echo "${cpu}"
echo "hitpoint1"


if [ "${cpu}" -gt 70 ]; then

        echo "hitpoint2 $(date)"

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

        echo "hitpoint3 $(date)"

        aws elbv2 register-targets \
                --target-group-arn $ARN \
                --targets Id="${instance}"

        count=1
        max_try=6

        while true; do

                echo "hitpoint4 $(date)"


                health=$(aws elbv2 describe-target-health \
                        --target-group-arn $ARN \
                        --targets Id="${instance}" \
                        --query 'TargetHealthDescriptions[*].TargetHealth.State' \
                        --output text)
                echo " $health $(date) "

                if [ "$count" -gt "$max_try" ]; then

                        echo "loops end here"

                        echo "hitpointn"
                        break

                fi

                if [ "$health" == "healthy" ]; then

                        echo "The instance is healthy $(date)" >> "${log}"
                        echo "hitpoint5"
                        break

                elif [ "$health" == "initial" ]; then

                        echo "the instance is added to group $(date)" >> "${log}"
                        echo "hitpoint6"
                        sleep 10


                elif [ "$health" == "unhealthy" ]; then

                        echo "target is still unhealthy after ${count} times checking" >> "${log}"

                        (( count++ ))

                        sleep 10
                        echo "hitpoint7"



                fi


        done

        echo "hitpoint8"

fi

echo "hitpoint9"

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

