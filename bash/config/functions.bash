mkcd() {
    [[ -z "$1" ]] && return 1;
    mkdir -p "$1"
    cd "$1"
}

mksh() {
    [[ -z "$1" ]] && return 1;
    
    if [[ -d "$1" ]]; then
        cecho "<error>[error]</> -> '<file>$1</>' <g>Is a directory"
        return 1
    fi
    
    echo -e "#!/usr/bin/env bash\n" > "$1"
    chmod +x "$1"
    
    [[ -z "$2" ]] && cecho "<g>✓ created</> -> <c,u,i>$1"
    
    local editors=( "ie" "edit" "zed" "vim" )
    
    [[ -n "$2" ]] && [[ " ${editors[*]} " == *" $2 "* ]] && {
        "$2" "$1"
    }
}

alias bd='cd ..'

sclc () {
    # https://www.gnu.org/software/gawk/manual/html_node/Numeric-Functions.html
    local expression="$@"

    if [ -z "$expression" ]; then
        echo "Use: c \"<expresion_matematica>\""
        return 1
    fi

    expression="${expression//x/*}"
    expression="${expression//X/*}"
    expression="${expression//pi/atan2(0, -1)}"
    expression="${expression//e/exp(1)}"

    gawk -M -v PREC=201 'BEGIN { printf("%.60g\n", ('"${expression}"') ) }' < /dev/null
}

clc () {
    local expression="$@"
    echo -n "'"${expression}"' = "
    sclc "$expression"
}

activate() {
    venv=".venv"
    if [ "$1" != "" ]; then
        venv="$1"
    fi
    if [ -d "./$venv/bin" ]; then
        . "./$venv/bin/activate"
    elif [ -d "./$venv/Scripts" ]; then
        . "./$venv/Scripts/activate"
    else
        echo "There is not a venv directory"
        echo "Directory name: $venv"
    fi
}

lenv() {
    ENV_FILE="$1"
    
    if [ ! -f "$ENV_FILE" ]; then
        echo "The file '$ENV_FILE' does not exist" >&2
      exit 1
    fi
    
    while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^# ]] && continue
    
      key=$(echo "$line" | cut -d':' -f1 | xargs)
      value=$(echo "$line" | cut -d':' -f2- | xargs)
    
      if [[ -n "$key" ]]; then
        export "$key"="$value"
        echo "$key exported" 
      fi
    done < "$ENV_FILE"
    
    echo "Finish load: '$ENV_FILE'"
}

cjson() { 
    curl -s -D /dev/tty "$@" | jq 
}

srsync() {
    # Color codes for terminal output
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[0;33m'
    local NC='\033[0m' # No Color

    # Initialize variables to control flow and store clean arguments
    local use_sudo=false
    local rsync_args=()

    # Parse all provided arguments safely
    for arg in "$@"; do
        if [[ "$arg" == "--sudo" ]]; then
            use_sudo=true
        else
            # Keep all other arguments intact (preserves spaces in paths)
            rsync_args+=("$arg")
        fi
    done

    # Ensure at least a source and destination are provided
    if [[ ${#rsync_args[@]} -lt 2 ]]; then
        echo -e "${RED}Error:${NC} Missing arguments."
        echo -e "${YELLOW}Usage:${NC} srsync [--sudo] <source>... <destination>"
        echo -e "       similar to ${YELLOW}scp${NC}"
        return 1
    fi

    # Execute rsync based on the sudo flag
    if $use_sudo; then
        echo -e "${GREEN}Note:${NC} Target machine requires passwordless sudo configuration for 'rsync'."
        echo -e "      ${GREEN}sudo visudo${NC}"
        echo -e "      add: "
        echo -e "        - ${YELLOW}{your_remote_user} ALL=(ALL) NOPASSWD: {rsync path}${NC}"
        echo -e "        - ${YELLOW}remote ALL=(ALL) NOPASSWD: /usr/bin/rsync${NC}"
        sudo rsync -aAXHvP -e ssh --rsync-path="sudo rsync" "${rsync_args[@]}"
    else
        rsync -aAXHvP -e ssh "${rsync_args[@]}"
    fi
}

# Scripts runner
run() {
    local script="~/.fx/bash/config/scripts/$1"
    shift
    
    [[ -f "$script" ]] && { 
        "$script" "$@"
    } || {
        cecho "<error>[error]</> <g>The file '<file>$script</>' does not exist</>"
    }
}
