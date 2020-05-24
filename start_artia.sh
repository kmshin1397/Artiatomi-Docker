#!/bin/bash

# Renders a text based list of options that can be selected by the
# user using up, down and enter keys and returns the chosen option.
#
#   Arguments   : list of options, maximum of 256
#                 "opt1" "opt2" ...
#   Return value: selected index (0 for opt1, 1 for opt2 ...)
select_option ()
{

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")

    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                         if [[ $key = $ESC[A ]]; then echo up;    fi
                         if [[ $key = $ESC[B ]]; then echo down;  fi
                         if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                   if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
}

select_opt () {
    select_option "$@" 1>&2
    local result=$?
    echo $result
    return $result
}

if $(sudo docker container ls | grep -q artia); then 
    echo "There already seems to be an Artiatomi instance running. Please remove the existing Artiatomi Docker container first." 
    exit; 
fi

echo
read -p 'Start Artiatomi instance with access to files in: ' mount_path
echo 'What would you like to do with Artiatomi?'
case `select_opt "Run Artiatomi tools except Clicker" "Run Clicker" "Quit"` in
    0)
        # Set up ssh key if necessary
        SSH_KEY=$HOME/.ssh/id_rsa.pub
        if test ! -f "$SSH_KEY"; then
            echo "Please generate an ssh key to communicate with the Artiatomi instance by running:"
            echo
            echo "ssh-keygen -t rsa"
            echo
            echo "before running the start_artia.sh script again."
            echo "(use default file locations and no password)"
            exit
        fi

        sudo docker run -d -P --gpus all --mount type=bind,source="$mount_path",target="$mount_path" --name artia --user root kmshin1397/artiatomi:latest /usr/sbin/sshd -D

        # Grab port for container and set up ssh for it
        PORT="$(sudo docker port artia | cut -f 2 -d ':')"
        echo Artiatomi is now set up on on port "$PORT"
        sshpass -p Artiatomi ssh-copy-id -p $PORT -f -o StrictHostKeyChecking=no Artiatomi@localhost

        # Set up Artiatomi user to mirror current host user
        sudo docker exec --user root artia sh -c "groupadd -g $(id -g) artiatomi && usermod -u $(id -u) -g $(id -g) Artiatomi"

        # Open shell as Artiatomi user
        sudo docker exec -it --user Artiatomi artia bash

        echo "Close down Artiatomi instance?"
        case `select_opt "Yes" "No"` in
            0)
                sudo docker stop artia 
                sudo docker rm artia;;
            1) 
                echo "To close down the Artiatomi container later, run close_artia.sh"
                exit;;
        esac

        ;;
    1)
        ORIGPERMS="$(stat -c "%a" "$mount_path")"

        # Give ownership to the files to an "artiatomi" group so that the container and the user can access
        if grep -q "artiatomi" /etc/group;
        then
            # If the artiatomi group exists, just add the user to it if necessary
            if $(groups | grep -q "artiatomi"); then
                echo "The artiatomi user group was detected. Good to proceed."
            else
                sudo usermod -a -G artiatomi $(id -un)
                echo "The user was added to the artiatomi group. Please log out and log back in so before re-running the program."
                exit;
            fi 
            ARTIAGRP=$(cut -d: -f3 < <(getent group artiatomi))
        else
            # If the artiatomi group does not exist, create it then add user to it
            echo "The artiatomi group does not exist"
            sudo groupadd artiatomi
            echo "The group was created."
            sudo usermod -a -G artiatomi $(id -un)
            echo "The user was added to the artiatomi group. Please log out and log back in so before re-running the program."
            exit;
        fi
        sudo chgrp -R artiatomi $mount_path
        sudo chmod -R g+rwx $mount_path

        sudo docker run --gpus=all --net=host --env="DISPLAY" --volume="$HOME/.Xauthority:/root/.Xauthority:rw" --mount type=bind,source="$mount_path",target="$mount_path" --user root  --group-add $ARTIAGRP --name artia-clicker kmshin1397/artiatomi:latest Clicker

        # Set up Artiatomi user to mirror current host user
        sudo docker exec --user root artia sh -c "groupadd -g $(id -g) artiatomi && usermod -u $(id -u) -g $(id -g) Artiatomi"

        # "Add" the host artiatomit group to the container as well and change primary group of user to artiatomi group so files created are accessible even while app is running
        sudo docker exec --user root artia-clicker groupadd -g $ARTIAGRP artiatomi && usermod -g artiatomi root

        echo "Closing down Artiatomi instance"
        sudo docker stop artia-clicker
        sudo docker rm artia-clicker

        # Restore mounted dir ownership to previous owner
        sudo chown -R $(id -u):$(id -g) $mount_path
        sudo chmod -R $ORIGPERMS $mount_path
        ;;
    2)
        ;;
    *) echo "invalid option $REPLY";;
esac