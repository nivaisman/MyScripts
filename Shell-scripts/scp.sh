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
remote_info="${r_username}+@+${Host_IP}"

# Structure:
#    1) direction - Upload or Download
#    2) os_selection - Windows, Linux
#    3) remote_details
#    4) file_details

function main() {
    printf "Select your local Operating System:\n"
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

    printf "Select remote Operating System:\n"
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
    echo "Please choose the transfer Direction (Upload or Download): "
    select direction in "${transfer_direction[@]}"; do
        case $direction in
            "Download")
                echo "You've chosen: " "${transfer_direction[0]}" # Download from remote host to localhost
                break
                ;;
            "Upload")
                echo "You've chosen: " "${transfer_direction[1]}" # Upload from localhost to remote host
                break
                ;;
            *)
                echo "Not a valid option. Good-Bye"
                exit 1
                ;;
        esac
    done
}

if [ $direction = ${transfer_direction[0]} ]; then
    # The user will be prompted to choose local and remote Operating systems
    function dl_os_selection() {

        echo "You've chosen: $direction"
        if [[ $direction == "${transfer_direction[0]}" ]]; then
            echo "test"
        fi
    }

elif [ $direction = ${transfer_direction[1]} ]; then
    function ul_os_selection() {
        echo "test2"

    }
fi
    if [[ $local_os == "${os_arr[0]}" ]]; then
        echo "Your local os is: \"${os_arr[0]}\""
        select remote_os in "${os_arr[@]}"; do
            printf "Select the remote Operating System:\n"
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

elif     [[ $local_os == "${os_arr[1]}" ]]; then
        echo "Your local os is: \"${os_arr[1]}\""
        select remote_os in "${os_arr[@]}"; do
            printf "Select the remote Operating System:\n"
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
fi

    if [[ $direction == "Download" ]]; then
        echo "Downloading from $remote_os to $local_os"
elif     [[ $direction == "Upload" ]]; then
        echo "Uploading from $local_os to $remote_os"
fi

function remote_details() {
    # The user will be prompted to enter the username and the IP or Hostname of the remote computer
    echo " "
    read -r -p "Enter the username of remote computer: " r_username
    $r_username
    #options_one=("Hostname" "IP Address")
    printf "\n"
    echo "Please choose either Hostname or IP Address of remote computer: "
    select opt_one in "${options_one[@]}"; do
        case $opt_one in
            "Hostname")
                echo "You've selected: Hostname. Please enter it:"
                #remote_host=$(read -r)
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

}

#functions calling
main
#direction
#os_selection
