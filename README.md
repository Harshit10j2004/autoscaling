Overview

This Bash script automates scaling EC2 instances in an AWS environment based on CPU and network usage. It monitors the system metrics and dynamically launches new instances or terminates underutilized instances, while ensuring they are properly registered with an ELB target group.

It is designed for robust operation:

Prevents multiple simultaneous executions using a lock file.

Logs all actions and errors to a dedicated log file.

Verifies instance health before adding to the target group.

Features

Automatic scaling up when CPU and network usage exceed configured thresholds.

Automatic scaling down when CPU and network usage fall below configured thresholds.

Health checks on new instances before registering them with the ELB target group.

Maintains a record of instance IDs for tracking and termination.

Thread-safe execution with file-based locking to avoid concurrent runs.

Prerequisites

AWS CLI installed and configured with proper IAM permissions.

Bash environment (Ubuntu recommended).

Required tools: mpstat, ifstat, awk, flock.

Environment variables defined in /home/ubuntu/data/data.env:
