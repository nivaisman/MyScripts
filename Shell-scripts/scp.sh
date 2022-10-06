#!/bin/bash

function scp_function() {
    printf "\n
    ---------------------------------------------------------------------------\n
    A Script to that simplifies files transfering using SCP mathod.\n
    SCP stands for - \"Secure Copy\" which is a file-transfer method\n
    between two hosts:\n
    side A) Your local computer.\n
    side B) A remote host, (usually a server)\n
    SCP works the same for Windows, Linux and MacOS.\n
    ---------------------------------------------------------------------------\n
    Author: Nivaisman\n
    Github: https://www.github.com/nivaisman\n"

    # the user will be prompted to choose origin and destination Operating systems
    transfer_direction=("Download" "Upload")
    #os_arr=("Linux" "Windows")

    echo "Please choose transfer Direction: "
    select direction in "${transfer_direction[@]}"; do
        case $direction in
        "Download")
            echo "You\'ve chosen: " "${transfer_direction[0]}" # Download to local computer
            break
            ;;
        "Upload")
            echo "You\'ve chosen: " "${transfer_direction[1]}" # Upload to remote computer
            break
            ;;
        *)
            echo "Not a valid option. Good-Bye"
            exit 1
            ;;
        esac
    done

    # The user will be prompted to choose origin and destination Operating systems
    #if [[ $direction == "1" ]]; then

    #local_os=read -p -r "fff"
    # select os_type in "${os_arr[@]}"; do
    #     case $os_type in

    # esac

    # The user will be prompted to enter the username and the IP or Hostname of the remote computer
    echo " "
    read -r -p "Enter the username of remote computer: " r_username
    options_one=("Hostname" "IP Address")
    printf "\n"
    echo "Please choose either Hostname or IP Address of remote computer: "
    select opt_one in "${options_one[@]}"; do
        case $opt_one in
        "Hostname")
            echo "You've selected Hostname"
            break
            ;;
        "IP Address")
            echo "You've selected IP"
            break
            ;;
        *)
            echo "Not an option, please try again"
            exit
            ;;
        esac
    done

    # validates the input and opt the user for the selected option
    if [[ ($opt_one == "1") || ($opt_one == "Hostname") ]]; then
        read -r -p "Enter the Hostname of the remote computer: " r_hostname
        printf "The Hostname is: %s" "$r_hostname"
        remote_info="$r_username"@"$r_hostname"
    elif [[ ($opt_one == "2") || ($opt_one == "IP Address") ]]; then
        read -r -p "Enter the IP-Address of the remote computer: " r_ip
        printf "The IP is: %s" "$r_ip"
        remote_info="$r_username@$r_ip"
    fi
    printf "\nThe remote computer details are: %s" "$remote_info"
    echo " "
    # after the user inserted the username and the hostname/ip-address, it's time to insert the remote path of files to transfer
    printf "\nEnter the origin path of the file you wish to transfer. for example: \
	\nif the file is on your userhome directory, enter the path as following: \
	\nFor Windows: \"c:/users/%s/\" \
	\nFor Unix:    \"/home/%s/\"\n" "$r_username" "$r_username"
    read -r -p "PATH: " origin_dir
    read -r -p "Enter the filename with extension. For example: \"File.txt\": " origin_filename
    origin_path="$origin_dir$origin_filename"
    printf "The remote file path is: \"%s\"\n" "$origin_path"
    #printf "The remote file path is: \"%s%s\"" "$r_dir" "$origin_filename"

    printf "\nEnter the destination path with forward-slash \"/\" at the end of it. \
			\nUse absolute path.\ne.g: /home/%s/\n" "$USER"
    read -r -p "Destination PATH: " dest_dir
    printf "The Destination file path is: %s" "$dest_dir"
    printf "\nEnter the filename you wish to save the file in. \
			\ndon\'t forget the file extension in the end \(if there\'s any\).\n"
    read -r -p "Filename: " dest_file
    dest_path="$dest_dir$dest_file"
    printf "The local file path is: %s" "$dest_file"
    printf "The file will be saved at: %s" "$dest_path"
    #printf "The SCP command is: \nscp %s:" $remote_info scp nivva@niv-asus:c:/users/.ssh/id_rsa.pub ~/id_rsa.pub
    printf "\nThe scp command is: \nscp %s:%s %s\n" "$remote_info" "$origin_path" "$dest_path"
    printf "\nDo you wish to continue?\n"
    options_2=("Yes" "No")
    select opt2 in "${options_2[@]}"; do
        case $opt2 in
        "Yes" | "y" | "Y" | "1")
            echo "Starting the transfer"
            sleep 2
            scp "$remote_info:$origin_path" "$dest_path"
            break
            ;;
        "No" | "n" | "N" | "2")
            echo "OK. Good-Bye"
            break
            ;;
        *)
            echo "Not a valid option."
            break
            ;;
        esac
    done
}

scp_function
