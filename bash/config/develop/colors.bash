cecho() {
    local newline="\n"
    local fd=1
    local force_color=0
    local raw_mode=0
    
    # Parse options
    while [[ "$1" == "-"* ]]; do
        case "$1" in
            -n) newline="" ; shift ;;
            -e) shift ;; 
            -c|--force-color) force_color=1 ; shift ;;
            -r|--raw) raw_mode=1 ; force_color=1 ; shift ;;
            *) break ;;
        esac
    done

    local input="$*"
    
    # Si no hay argumentos y la entrada estándar no es una terminal interactiva, leemos del pipe.
    if [[ -z "$input" ]] && [[ ! -t 0 ]]; then
        input="$(cat)"
    fi
    
    # Replace escaped << and >> with temporary non-printable characters 
    input="${input//<</$'\x01'}"
    input="${input//>>/$'\x02'}"
    
    local -a stack=()
    local out=""
    
    # Map tags to ANSI codes
    local -A colors=(
        # Foreground colors
        [k]="\e[30m" [r]="\e[31m" [g]="\e[32m" [y]="\e[33m" 
        [b]="\e[34m" [m]="\e[35m" [c]="\e[36m" [w]="\e[37m" 
    
        # Bright foreground colors
        [bk]="\e[90m" [br]="\e[91m" [bg]="\e[92m" [by]="\e[93m" 
        [bb]="\e[94m" [bm]="\e[95m" [bc]="\e[96m" [bw]="\e[97m"
    
        # Background colors
        [bg-k]="\e[40m" [bg-r]="\e[41m" [bg-g]="\e[42m" [bg-y]="\e[43m" 
        [bg-b]="\e[44m" [bg-m]="\e[45m" [bg-c]="\e[46m" [bg-w]="\e[47m" 
    
        # Bright background colors
        [bg-bk]="\e[100m" [bg-br]="\e[101m" [bg-bg]="\e[102m" [bg-by]="\e[103m" 
        [bg-bb]="\e[104m" [bg-bm]="\e[105m" [bg-bc]="\e[106m" [bg-bw]="\e[107m"
    
        # Text formatting styles
        [bold]="\e[1m"  [dim]="\e[2m"   [i]="\e[3m"    [u]="\e[4m" 
        [blink]="\e[5m" [rev]="\e[7m"   [hide]="\e[8m" [st]="\e[9m" 

        # Partial Resets
        [/bold]="\e[22m" [/dim]="\e[22m" [/i]="\e[23m" [/u]="\e[24m"
        [/blink]="\e[25m" [/rev]="\e[27m" [/hide]="\e[28m" [/st]="\e[29m"

        # Semantic Tags (Themes)
        [error]="\e[91m\e[1m"       # Bright Red + Bold
        [warn]="\e[93m\e[1m"        # Bright Yellow + Bold
        [info]="\e[96m"             # Bright Cyan
        [success]="\e[92m\e[1m"     # Bright Green + Bold
        [file]="\e[36m\e[3m\e[4m"   # Cyan + Underline + Italic

        # Control Sequences
        [clr-line]="\r\e[2K"    # Carriage return + clear line
        [clr-scr]="\e[2J\e[H"   # Clear screen + move cursor to top-left
    
        # Reset
        [reset]="\e[0m"
    )
    
    # [F1] Check if we should use colors
    local use_color=1
    if (( force_color == 1 )); then
        use_color=1
    elif [[ -n "${NO_COLOR:-}" ]] || [[ ! -t $fd ]]; then
        use_color=0
    fi
    
    local tag_re='^([^><]+)>(.*)$'
    
    while [[ "$input" == *"<"* ]]; do
        local before="${input%%<*}"
        local remainder="${input#*<}"
        
        if [[ "$remainder" =~ $tag_re ]]; then
            out+="${before}"
            local tag="${BASH_REMATCH[1]}"
            input="${BASH_REMATCH[2]}"
            
            if [[ "$tag" == /* ]]; then
                if [[ "$tag" == "/" ]]; then
                    # Generic closing tag (</>)
                    local count=${#stack[@]}
                    if (( count > 0 )); then
                        stack=("${stack[@]:0:count-1}")
                    fi
                    
                    if (( use_color == 1 )); then
                        out+="${colors[reset]}"
                        # Rebuild stack
                        for st_tag in "${stack[@]}"; do
                            IFS=',' read -ra parts <<< "$st_tag"
                            for p in "${parts[@]}"; do
                                p="${p// /}"
                                out+="${colors[$p]}"
                            done
                        done
                    fi
                else
                    # [F6] Specific reset tag (e.g., </bold>)
                    if [[ -n "${colors[$tag]}" ]]; then
                        if (( use_color == 1 )); then
                            out+="${colors[$tag]}"
                        fi
                        # Clean up the specific style from the stack
                        local style_to_remove="${tag:1}"
                        local new_stack=()
                        for st_tag in "${stack[@]}"; do
                            local new_st=""
                            IFS=',' read -ra parts <<< "$st_tag"
                            for p in "${parts[@]}"; do
                                p="${p// /}"
                                if [[ "$p" != "$style_to_remove" ]]; then
                                    new_st+="$p,"
                                fi
                            done
                            new_st="${new_st%,}" # Remove trailing comma
                            if [[ -n "$new_st" ]]; then
                                new_stack+=("$new_st")
                            fi
                        done
                        stack=("${new_stack[@]}")
                    else
                        out+="<${tag}>"
                    fi
                fi
            else
                # Handle opening tags (colors, styles, semantics, controls)
                local is_valid=1
                local combined_ansi=""
                IFS=',' read -ra parts <<< "$tag"
                
                for p in "${parts[@]}"; do
                    p="${p// /}"
                    if [[ -n "${colors[$p]}" ]]; then
                        combined_ansi+="${colors[$p]}"
                    else
                        is_valid=0
                        break
                    fi
                done
                
                if (( is_valid == 1 && ${#parts[@]} > 0 )); then
                    # Only push to stack if it's not a control sequence
                    if [[ "$tag" != "clr-line" && "$tag" != "clr-scr" ]]; then
                        stack+=("$tag")
                    fi
                    if (( use_color == 1 )); then
                        out+="${combined_ansi}"
                    fi
                else
                    out+="<${tag}>"
                fi
            fi
        else
            out+="${before}<"
            input="$remainder"
        fi
    done
    
    out+="${input}"
    
    if (( use_color == 1 )); then
        out+="${colors[reset]}"
    fi

    # Restore escaped characters
    out="${out//$'\x01'/<}"
    out="${out//$'\x02'/>}"
    
    # --- Modificación principal para --raw ---
    if (( raw_mode == 1 )); then
        local echo_cmd="echo -e"
        # Si se usó -n, no imprimimos la nueva línea y usamos echo -en
        if [[ -z "$newline" ]]; then
            echo_cmd="echo -en"
        fi
        
        # Escapamos comillas dobles para que el comando sea válido
        local escaped_out="${out//\"/\\\"}"
        printf "%s \"%s\"\n" "$echo_cmd" "$escaped_out" >&$fd
    else
        printf "%b${newline}" "$out" >&$fd
    fi
}

cerr() { cecho "$@" >&2; }
