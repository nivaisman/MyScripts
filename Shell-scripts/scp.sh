#!/bin/bash

printf "
  =========================================
||Creator: Nivaisman                       ||
||Email: niv.devmail@gmail.com             ||
||Github: https://www.github.com/nivaisman ||
||                                         ||
  =========================================
||Description:                             ||
||A script that simplifies the SCP method  ||
||file transferring between hosts           ||
||                                         ||
||Requirements:                            ||
||Knowing the remote host's:               ||
|| 1) OS - Windows or Linux                ||
|| 2) IP or Hostname                       ||
|| 3) Username with writing permissions    ||
|| 4) Path to save the file at             ||
  =========================================
||Current Version: 1.2                     ||
||                                         ||
||Changes: see README.md                   ||
  =========================================\n"

# Global declarations
transfer_direction=("Download" "Upload")
os_arr=("Windows" "Linux")
Host_IP=("Hostname" "IP Address") # Hostname or IP of the remote host
#remote_info="${remote_user}@${Host_IP}"

# Structure:
#    1) direction - Upload or Download
#    2) os_selection - Windows, Linux
#    3) remote_details
#    4) file_details

function main() {
    printf "\nSelect local Operating System:\n"
    select local_os in "${os_arr[@]}"; do
        case $local_os in
            "Windows")
                break
                ;;
            "Linux")
                break
                ;;
            *)
                echo "Not a valid option. Good-Bye"
                exit 1
                ;;
        esac
    done
    echo "$local_os"

    printf "\nSelect remote Operating System:\n"
    select remote_os in "${os_arr[@]}"; do
        case $remote_os in
            "Windows")
                break
                ;;
            "Linux")
                break
                ;;
            *)
                echo "Not a valid option. Good-Bye"
                exit 1
                ;;
        esac
    done
    echo "$remote_os"
}

function direction() {
    printf "\nPlease choose the transfer Direction - Upload or Download: \n"
    select direction in "${transfer_direction[@]}"; do
        case $direction in
            "Download")
                echo "You've chosen: ${transfer_direction[0]} from ${remote_os} host" # Downloading from remote host
                break
                ;;
            "Upload")
                echo "You've chosen: ${transfer_direction[1]} to ${remote_os} host" # Uploading to remote host
                break
                ;;
            *)
                echo "Not a valid option. Good-Bye"
                exit 1
                ;;
        esac
    done
    if [ "$direction" == "${transfer_direction[0]}" ]; then
        echo ""
        echo "Enter the file you wish to download. use full path syntax:"
        echo "Windows = \"c:/path/to/file.extension\""
        echo "Linux = \"/path/to/file.extension\""
        read -r -p "Path: " remote_path
        echo "$remote_path"
        sleep 1
        printf "\nEnter destination path to save file at\n"
        read -r -p "(Use the same template as before): " local_path
        echo "$local_path"
        sleep 1

    elif [ "$direction" == "${transfer_direction[1]}" ]; then
        echo ""
        echo "Enter the file you wish to upload. use full path syntax:"
        echo "Windows = \"c:/path/to/file.extension\""
        echo "Linux = \"/path/to/file.extension\""
        read -r -p "Path: " local_path
        echo "$local_path"
        sleep 1
        printf "\nEnter destination path to save file at "
        read -r -p "(Use the same template as before): " remote_path
        echo "$remote_path"
        sleep 1
    fi
}

function remote_details() {
    # The user will be prompted to enter the username and the IP of the remote computer
    echo " "
    read -r -p "Enter the username of remote computer: " remote_user
    echo "Remote user is: $remote_user"
    printf "\nEnter the remote IP or Hostname of the remote computer.\n"
    read -r -p "Make sure the user has Read+Write permissions: " Host_IP
    printf "Remote IP or Hostname is: %s " "${Host_IP}"
    echo "Is this correct? $remote_user@$Host_IP"
    remote_info="${remote_user}@${Host_IP}"
    read -r -p "Enter \"y\" or \"n\"" final_answer
}

function begin() {
    # User confirmed the details and chose Download
    if [[ "$final_answer" == "Y" || "$final_answer" == "y" && "$direction" == "${transfer_direction[0]}" ]]; then
        printf "\nStarting SCP process..."
        sleep 1
        scp -v "$remote_info":"$remote_path" "$local_path"
    # User confirmed the details and chose Upload
    elif [[ "$final_answer" == "Y" || "$final_answer" == "y" && "$direction" == "${transfer_direction[1]}" ]]; then
        printf "\nStarting SCP process..."
        sleep 1
        scp -v "$local_path" "$remote_info":"$remote_path"
    # if the user declined the details the script will exit
    elif [[ "$final_answer" == "N" || "$final_answer" == "n" ]]; then
        sleep 1
        printf "Exiting the script\n Thank you. Good-Bye"
        exit
    fi
}

#functions calling
main
direction
remote_details
begin
