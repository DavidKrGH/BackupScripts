#!/bin/bash
# BackupScripts version 2.0.0
#################################### License ####################################
# MIT License Copyright (c) 2023 David Krumm                                    #
# All rights reserved.                                                          #
#                                                                               #
# This source code is licensed under the MIT license found in the               #
# LICENSE file in the root directory of this source tree.                       #
#################################################################################
#================================ BackupScripts ================================#
#################################################################################
                                                                                #     
unique_job_name="ChangeMeToUniqueName"                                          # Unique job name. Do not use space or underscore!!!
                                                                                #
path_to_BackupScripts="/PATH/TO/BackupScripts"                                  # Path to BackupScripts directory. Does not support Docker volume propagation!
                                                                                #
system_id_name="HOSTNAME"                                                       # Name to identify your System in Snapshots
                                                                                #
schedule_update_Restic_and_Rclone="monthly: 1"                                  #
                                                                                #
notify_after_completion="false"                                                 # (true/false) The notification system must be set up. See documentation.
                                                                                #
############################## Restic ###########################################
                                                                                #
                                                                                # Schedule for the execution of the Restic forget process:
schedule_backup="always"                                                        # "never", "always", "weekly: Mon, Tue, Wed, Thu, Fri, Sat, Sun", "monthly: 15"
                                                                                # Executed only once per day if the weekly or monthly pattern is used.
                                                                                #
path_to_the_directory_to_be_backed_up="/PATH/TO/DATA:ro"                        # Source directory to be backed up. Support for Docker volume propagation! E.G. "/PATH/TO/DATA:rw,slave" ro=read-only, rw=read-write 
                                                                                #
path_to_restic_repository="/PATH/TO/REPO:rw,slave"                              # Path to the backup repository. Support for Docker volume propagation! E.G. "/PATH/TO/REPO:rw,slave" ro=read-only, rw=read-write 
                                                                                #
name_restic_password_file="restic-repo.password"                                # File in Config/ResticConfig. Insert yor repository password first.
                                                                                #
restig_backup_tags="--tag FirstTag --tag SecondTag"                             # Tags to be applied to the backup snapshots
                                                                                #
name_restic_filter_file="DefaultResticFilter.txt"                               # Filter file to exclude specific files or directories from the backup
                                                                                #
restic_options=""                                                               # Additional options specific to Restic
                                                                                #
############################## Snapshot Rotation                                #     
                                                                                # Schedule for the execution of the Restic forget process:
schedule_forget="always"                                                        # "never", "always", "weekly: Mon, Tue, Wed, Thu, Fri, Sat, Sun", "monthly: 15"
                                                                                # Executed only once per day if the weekly or monthly pattern is used.
                                                                                #
keep_hourly_for="12h"                                                           # Number of hours to keep hourly snapshots
keep_daily_for="7d"                                                             # Number of days to keep daily snapshots
keep_weekly_for="3m"                                                            # Number of weeks to keep weekly snapshots
keep_monthly_for="1y"                                                           # Number of months to keep monthly snapshots
keep_yearly_for="5y"                                                            # Number of years to keep yearly snapshots
                                                                                #
############################## Prune                                            #
                                                                                # Schedule for the execution of the Restic forget process:
schedule_prune="weekly: Mon, Wed, Sat"                                          # "never", "always", "weekly: Mon, Tue, Wed, Thu, Fri, Sat, Sun", "monthly: 15"
                                                                                # Executed only once per day if the weekly or monthly pattern is used.
############################## Docker ###########################################
                                                                                #
name_docker_config_file="DockerExampleConfig.txt"                               #
                                                                                #
reverse_order_at_start="false"                                                  #
                                                                                #
############################## Rclone ###########################################
                                                                                #
schedule_rclone="monthly: 10"                                                   # Schedule for running Rclone: "never", "always", "weekly: Mon, Tue, Wed, Thu, Fri, Sat, Sun", "monthly: 15" 
                                                                                # Executed only once per day if the weekly or monthly pattern is used.
                                                                                #
rclone_remote_path="RemoteName:/PATH/ON/REMOTE"                                 # Destination remote for Rclone. Does not support Docker volume propagation!
                                                                                #
name_rclone_filter_file="DefaultRcloneFilter.txt"                               # Filter file to exclude specific files or directories from the backup to remote
                                                                                #
rclone_log_level="INFO"                                                         # Log level for Rclone: "DEBUG", "INFO", "NOTICE", "ERROR"
                                                                                #
rclone_options=""                                                               # Additional options specific to Rclone
                                                                                #
#################################################################################

              
























#################################################################################
#                                                                               #
#     Don't change anything from here if you don't know what you are doing      #
#                                                                               #
#################################################################################

############################# Setup Paths #######################################

export JOB_NAME="$unique_job_name"
export HOME_PATH="$path_to_BackupScripts"
export SOURCE="$path_to_the_directory_to_be_backed_up"
export REPOSITORY="$path_to_restic_repository"
export REMOTE="$rclone_remote_path"

export DOCKER_CONFIG="$HOME_PATH/Config/DockerConfig/$name_docker_config_file"
export RESTIC_PW="$HOME_PATH/Config/RepositoryPassword/$name_restic_password_file"
export RESTIC_FILTER="$HOME_PATH/Config/FilterConfig/ResticFilter/$name_restic_filter_file"
export RCLONE_FILTER="$HOME_PATH/Config/FilterConfig/RcloneFilter/$name_rclone_filter_file"

NOTIFIER="$HOME_PATH/Executor/Notifier"
ConditionHandler="$HOME_PATH/Executor/ConditionHandler"
DockerHandler="$HOME_PATH/Executor/DockerHandler"
ResticBackupExec="$HOME_PATH/Executor/ResticBackupExec"
ResticForgetExec="$HOME_PATH/Executor/ResticForgetExec"
ResticPruneExec="$HOME_PATH/Executor/ResticPruneExec"
RcloneExec="$HOME_PATH/Executor/RcloneExec"

############################## Check Preconditions ##############################

directory_pahts=("$HOME_PATH" "$SOURCE" "$REPOSITORY")
config_files=("$DOCKER_CONFIG" "$RESTIC_PW" "$RESTIC_FILTER" "$RCLONE_FILTER")
executable_files=("$NOTIFIER" "$ConditionHandler" "$DockerHandler" "$ResticBackupExec" "$ResticForgetExec" "$ResticPruneExec" "$RcloneExec")

for directory in "${directory_pahts[@]}"; do
    directory=$(echo "$directory" | cut -d':' -f1)
    # Check directrie exists
    if [ ! -d "$directory" ]; then
        echo "ERROR: The directory $directory does not exist."
        exit 1
    fi
done

for file in "${config_files[@]}"; do
    # Check file exists
    if [ ! -f "$file" ]; then
        echo "ERROR: The directory $file does not exist."
        exit 1
    
    # Check linebrake at file end
    elif [ "$(tail -c 1 "$file"; echo x)" != "$(echo x)" ] && [ -n "$(tail -n 1 "$file")" ]; then
        echo >> "$file"
    fi
done

for file in "${executable_files[@]}"; do

    # Check executable exists
    if [ ! -f "$file" ]; then
        echo "ERROR: $file does not exist"
        exit 1
    
    # Check executable file is executable
    elif [ ! -x "$file" ]; then
        echo "ERROR: $file exists but is not executable"

        chmod +x "$script"
        # Try to provide rights
        if [ $? -eq 0 ]; then
            echo "$file was provided with execution rights"
        else
            echo "ERROR: The attempt to assign execution rights to the $file failed."
            echo "-> Read the instructions and the setup files in the 'BackupScripts/SetupInstruction' directory"
            echo "-> Use 'sudo chmod +x $file' to give the file the required rights"
            exit 1
        fi
    fi
done

############################## Jobs #############################################

$NOTIFIER --channel "file" --timestamps "false"
$NOTIFIER --channel "file" --message "Starting '$JOB_NAME' ..."

# Check if jobs is already executed
$ConditionHandler --task "evaluate" --type "execution"
job_is_already_executed=$?
if [[ "$job_is_already_executed" == 99 ]]; then
    exit 0                                          # Job is already executed.
elif [[ "$job_is_already_executed" == 1 ]]; then
    exit 1                                          # Something went wrong
fi

############################## Update Restic & Rclone 

# Evaluate schedule
$ConditionHandler --task "evaluate" --type "lock" --process "Update" --schedule "$schedule_update_Restic_and_Rclone"
evaluation=$?

if [[ "$evaluation" == 0 ]]; then
    $DockerHandler --action "update"
fi

############################## Stop Docker 

$DockerHandler --action "stop"
stop_exit_code=$?

# If evaluation or ResticForgetExec fails
if [[ "$stop_exit_code" == 1 ]]; then
    $ConditionHandler --task "release" --type "execution"
    exit 1
fi

############################## Backup 

# Evaluate schedule
$ConditionHandler --task "evaluate" --type "lock" --process "Backup" --schedule "$schedule_backup"
evaluation=$?

if [[ "$evaluation" == 0 ]]; then
    $ResticBackupExec "$system_id_name" "$restig_backup_tags" "$restic_options"
    backup_exit_code=$?
fi

# If evaluation or ResticForgetExec fails
if [[ "$evaluation" == 1 || "$backup_exit_code" == 1 ]]; then
    $ConditionHandler --task "release" --type "execution"
    exit 1
fi

############################## Start Docker

$DockerHandler --action "start" --reverse "$reverse_order_at_start"
start_exit_code=$?

# If evaluation or ResticForgetExec fails
if [[ "$start_exit_code" == 1 ]]; then
    $ConditionHandler --task "release" --type "execution"
    exit 1
fi

############################## Forget

# Kombine keep rules
keep_rules="--keep-within-hourly $keep_hourly_for --keep-within-daily $keep_daily_for"
keep_rules+=" --keep-within-weekly $keep_weekly_for --keep-within-monthly $keep_monthly_for"
keep_rules+=" --keep-within-yearly $keep_yearly_for"

# Evaluate schedule
$ConditionHandler --task "evaluate" --type "lock" --process "Forget" --schedule "$schedule_forget"
evaluation=$?

if [[ "$evaluation" == 0 ]]; then
    $ResticForgetExec "$keep_rules"
    forget_exit_code=$?
fi

# If evaluation or ResticForgetExec fails
if [[ "$evaluation" == 1 || "$forget_exit_code" == 1 ]]; then
    $ConditionHandler --task "release" --type "execution"
    exit 1
fi

############################## Prune

# Evaluate schedule
$ConditionHandler --task "evaluate" --type "lock" --process "Prune" --schedule "$schedule_prune"
evaluation=$?

if [[ "$evaluation" == 0 ]]; then
    $ResticPruneExec
    prune_exit_code=$?
fi

# If evaluation or ResticPruneExec fails
if [[ "$evaluation" == 1 || "$prune_exit_code" == 1 ]]; then
    $ConditionHandler --task "release" --type "execution"
    exit 1
fi

############################## Rclone

# Evaluate schedule
$ConditionHandler --task "evaluate" --type "lock" --process "Rclone" --schedule "$schedule_rclone"
evaluation=$?

if [[ "$evaluation" == 0 ]]; then
    $RcloneExec "$repo" "$dest_remote" "" \
    "--log-file /LogFiles/${JOB_NAME}_$(date +'%Y-%m').log --log-level=$rclone_log_level" "$rclone_options"
    rclone_exit_code=$?
fi

# If evaluation or ResticPruneExec fails
if [[ "$evaluation" == 1 || "$rclone_exit_code" == 1 ]]; then
    $ConditionHandler --task "release" --type "execution"
    exit 1
fi

############################## Finished

$ConditionHandler --task "release" --type "execution"

completion_channel="file"
if [[ "$notify_after_completion" = "true" ]]; then
    completion_channel="system"
fi
$NOTIFIER --channel "file"
$NOTIFIER --channel "$completion_channel" --args "normal" --message "Execution of '$JOB_NAME' successfully finished"
$NOTIFIER --channel "file" --timestamps "false"

#################################################################################
#                                      End                                      #
#################################################################################