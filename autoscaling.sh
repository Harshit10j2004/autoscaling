#!/bin/bash

set -x
set -euo pipefail

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


        cpu=$(mpstat 1 1 | grep Average | awk '{print 100 - int($12)}')

        network=$(ifstat 1 1 | awk 'NR==3 {print int($1)}')
        if [ "${cpu}" -gt $USAGE_C_U ] && [ "${network}" -gt $USAGE_N_U ]; then

                tg=$(aws elbv2 describe-target-groups --target-group-arns $ARN 2>/dev/null)
                if [[ -n "$tg" ]]; then

                        vms=$(aws elbv2 describe-target-health \
                                --target-group-arn $ARN \
                                --query 'TargetHealthDescriptions[].Target.Id' \
                                --output text | wc -w )
                        if [ "${vms}" -lt $LOWER_LIMIT ]; then
                                count=$LOWER_LIMIT_C
                        else

                                count=$(( "${vms}" / $PER_NEED ))
                        fi

                        echo "CPU is gt than 70% and network is gt than 6000KB/s so starting ${count} servers at $(date)" >> "${log}"

                        instance=$(aws ec2 run-instances \
                                --image-id $AMI \
                                --count "${count}" \
                                --instance-type $INSTANCE \
                                --key-name $KEY \
                                --security-group-ids $SECURITY \
                                --query Instances[*].InstanceId \
                                --output text)

                        for i in $instance; do

                                aws ec2 describe-instances --instance-ids "$i" >/dev/null 2>&1
                                if [ $? -ne 0 ]; then
                                        echo "Failed to describe instance $i at $(date)" >> "$log"
                                        exit 1
                                fi

                                aws ec2 wait instance-status-ok --instance-ids "${i}"

                                echo "${i}" >> "${path}"
                                echo "${i} instance is created at $(date)" >> "${log}"



                                aws elbv2 register-targets \
                                        --target-group-arn $ARN \
                                        --targets Id="${i}"

                                echo " ${i} instance is connecting to the target group at $(date) " >> "${log}"
                                sleep 20


                                for j in {1..15}; do

                                        echo " Started to check the instance health before trying to add to target group at $(date) " >> "${log}"


                                        health=$(aws elbv2 describe-target-health \
                                                --target-group-arn $ARN \
                                                --targets Id="${i}" \
                                                --query 'TargetHealthDescriptions[*].TargetHealth.State' \
                                                --output text)
                                        echo " current health is ${health} at $(date) " >> "${log}"



                                        if [ "$health" == "healthy" ]; then

                                                echo "The instance ${i} is now healthy $(date)" >> "${log}"

                                                break

                                        elif [ "$health" == "initial" ]; then

                                                echo "the instance ${i} is still in initial health at $(date)" >> "${log}"

                                                sleep 10


                                        elif [ "$health" == "unhealthy" ]; then

                                                echo "Instance ${i} is still unhealthy after ${j} times checking" >> "${log}"

                                                sleep 10
                                        fi

                                        sleep 20

                                done
                        done

                        echo "Instance is attached to target group now at $(date) " >> "${log}"

                else
                        echo "The target group doesnt exist at $(date)" >> "${log}"
                fi

        fi



        if [ "${cpu}" -lt $USAGE_C_L ] && [ "${network}" -lt $USAGE_N_L ]; then

                echo "CPU usage is lower than 30% at $(date) " >> "${log}"

                lines=$(wc -l < "${path}")


                if [ $lines -eq 0 ]; then

                        echo "there is no autoscaling vms attached till yet at $(date) " >> "${log}"

                        exit 0
                fi


                instance_rm=$(head -n 1 /home/ubuntu/data/instance_id.txt)

                aws elbv2 deregister-targets \
                        --target-group-arn $ARN \
                        --targets Id="${instance_rm}"

                echo "${instance_rm} inatance is removed from the target group at $(date)" >> "${log}"

                aws ec2 terminate-instances --instance-ids "${instance_rm}"

                echo "${instance_rm} instance is terminated at $(date)" >> "${log}"

                sed -i '1d' /home/ubuntu/data/instance_id.txt


        fi

)

