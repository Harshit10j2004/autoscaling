#!/bin/bash

set -x
lockfile="/tmp/auto.lock"
log="/home/ubuntu/logs/as_log.txt"

exec 200>$lockfile
(


        flock -n 200 || {

                echo "hitpoint s $(date)"
                echo "script is lock by diff process $(date) " >> "${log}"
                exit 1
        }


        source /home/ubuntu/data/data.env

        path="/home/ubuntu/data/instance_id.txt"

        echo "script is locked $(date) " >> "${log}"
        count=1

        cpu=$(mpstat 1 1 | grep Average | awk '{print 100 - int($12)}')

        if [ "${cpu}" -gt 70 ]; then

                echo "CPU is gt than 80% starting the server at $(date)" >> "${log}"

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
                echo "${instance} instance is created at $(date)" >> "${log}"

                aws elbv2 register-targets \
                        --target-group-arn $ARN \
                        --targets Id="${instance}"

                echo " instance is connecting to the target group at $(date) " >> "${log}"
                sleep 30

                for i in {1..15}; do

                        echo " Started to check the instance health before trying to add to target group at $(date) " >> "${log}"


                        health=$(aws elbv2 describe-target-health \
                                --target-group-arn $ARN \
                                --targets Id="${instance}" \
                                --query 'TargetHealthDescriptions[*].TargetHealth.State' \
                                --output text)
                        echo " current health is ${health} at $(date) " >> "${log}"



                        if [ "$health" == "healthy" ]; then

                                echo "The instance is now healthy $(date)" >> "${log}"

                                break

                        elif [ "$health" == "initial" ]; then

                                echo "the instance is still in initial health at $(date)" >> "${log}"

                                sleep 10


                        elif [ "$health" == "unhealthy" ]; then

                                echo "target is still unhealthy after ${i} times checking" >> "${log}"

                                sleep 10
                        fi

                        sleep 40

                done

                echo "Instance is attached to target group now at $(date) " >> "${log}"

        fi



        if [ $cpu -lt 30 ]; then

                echo "CPU usage is lower than 30% at $(date) " >> "${log}"

                lines=$(wc -l < "${path}")


                if [ $lines -eq 0 ]; then

                        echo "there is no autoscaling vms attached till yet at $(date) " >> "${log}"

                        exit 0
                fi


                instance_rm=$(tail -n 1 /home/ubuntu/data/instance_id.txt)

                aws elbv2 deregister-targets \
                        --target-group-arn $ARN \
                        --targets Id="${instance_rm}"

                echo "${instance_rm} inatance is removed from the target group at $(date)" >> "${log}"

                aws ec2 terminate-instances --instance-ids "${instance_rm}"

                echo "${instance_rm} instance is terminated at $(date)" >> "${log}"

                sed -i '$d' /home/ubuntu/data/instance_id.txt


        fi

)

