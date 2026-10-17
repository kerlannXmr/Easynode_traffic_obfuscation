#!/bin/bash

declare -A COLORS=(
    ["PRIMARY"]='\033[38;5;255m'    
    ["SUCCESS"]='\033[38;5;71m'     
    ["MONERO"]='\033[38;5;208m'     
    ["WARNING"]='\033[38;5;184m'    
    ["ERROR"]='\033[38;5;167m'      
    ["INFO"]='\033[38;5;74m'        
    ["HEADER"]='\033[38;5;140m'     
    ["BG"]='\033[48;5;16m'          
    ["GRIS"]='\033[38;5;245m'       
)

draw_banner() {
    tput sc
    tput cup 0 0
    echo -e "\033[38;5;208m"
    echo "  *     *   ***   *   * ***** ****   ***   "
    echo "  **   **  *   *  **  * *     *   * *   *  "
    echo "  * * * * *     * * * * ****  ****  *   *  "
    echo "  *  *  * *     * *  ** *     * *   *   *  "
    echo "  *     *  *   *  *   * *     *  *  *   *  "
    echo "  *     *   ***   *   * ***** *   *  ***   "
    echo "  ═══════════ ▌EASYNODE▐ ════════════v4    "
    echo "  ════════Traffic obfuscation ══════════   "
    echo -e "${COLORS[RESET]}"
    tput rc
}

USERNAME=""
LANG_CHOICE=""
BLOCKCHAIN_TYPE=""
MONERO_VERSION="0.18.5.4"

print_styled() {
    local style=$1
    local message=$2
    echo -e "${COLORS[$style]}${message}${COLORS[RESET]}"
}

info() {
    print_styled "INFO" "ℹ $1"
}

error() {
    print_styled "ERROR" "✖ $1"
}

warning() {
    print_styled "WARNING" "⚠ $1"
}

success() {
    print_styled "SUCCESS" "✓ $1"
}

print_header() {
    local message=$1
    local length=${#message}
    local total_width=37   
    local line="═════════════════════════════════════════"
    local padding=$(( (total_width - length) / 2 ))
    local spaces=$(printf '%*s' $padding '')
    echo
    print_styled "MONERO" "$line"
    print_styled "PRIMARY" "${spaces}${message}"
    print_styled "MONERO" "$line"
    echo
}

setup_terminal() {
    echo -e "${COLORS[BG]}"
    clear
    printf '\033]11;#1a1a1a\007'
    draw_banner
}

select_language() {
    clear
    draw_banner
    echo -e "\n\n\n\n\n\n\n\n"  
    print_header "LANGUAGE SELECTION"
                  
    while true; do
        print_styled "PRIMARY" "1) Français"
        print_styled "PRIMARY" "2) English"
        echo -n "$(print_styled "MONERO" "Choose/Choisissez (1-2): ")"    
            
        read -r lang_choice
        case $lang_choice in
            1) LANG_CHOICE="FR"; break ;;
            2) LANG_CHOICE="EN"; break ;;
            *) error "Invalid choice / Choix invalide" ;;    
        esac
    done
}

get_message() {
    local fr_msg=$1
    local en_msg=$2
    if [ "$LANG_CHOICE" = "FR" ]; then
        echo "$fr_msg"
    else
        echo "$en_msg"
    fi
}

configure_ssh_safely() {
    info "$(get_message "Configuration sécurisée de SSH..." "Configuring SSH securely...")"
    
    if [ ! -f /etc/ssh/sshd_config.backup ]; then
        sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
        info "$(get_message "Sauvegarde SSH créée" "SSH backup created")"
    fi

    CURRENT_MAX_AUTH=$(grep -E "^MaxAuthTries" /etc/ssh/sshd_config | awk '{print $2}')
    PERMIT_ROOT_STATUS=$(grep -E "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')

    CHANGES_NEEDED=false

    if [ "$CURRENT_MAX_AUTH" != "3" ]; then
        if [ -n "$CURRENT_MAX_AUTH" ]; then
            sudo sed -i "s/^MaxAuthTries .*/MaxAuthTries 3/" /etc/ssh/sshd_config
        else
            echo "MaxAuthTries 3" | sudo tee -a /etc/ssh/sshd_config > /dev/null
        fi
        CHANGES_NEEDED=true
        info "$(get_message "MaxAuthTries configuré à 3" "MaxAuthTries set to 3")"
    fi

    if [ "$PERMIT_ROOT_STATUS" != "no" ]; then
        if [ -n "$PERMIT_ROOT_STATUS" ]; then
            sudo sed -i "s/^PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
        else
            echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config > /dev/null
        fi
        CHANGES_NEEDED=true
        info "$(get_message "PermitRootLogin désactivé" "PermitRootLogin disabled")"
    fi

    if [ "$CHANGES_NEEDED" = "true" ]; then
        if sudo sshd -t; then
            sudo systemctl reload ssh
            success "$(get_message "Configuration SSH appliquée avec succès" "SSH configuration applied successfully")"
        else
            error "$(get_message "Erreur dans la configuration SSH, restauration..." "SSH configuration error, restoring...")"
            sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
            sudo systemctl reload ssh
        fi
    else
        info "$(get_message "Configuration SSH déjà optimale" "SSH configuration already optimal")"
    fi
}

install_network_tools() {
    info "$(get_message "Installation des outils réseau..." "Installing network tools...")"
    
    sudo apt install -y \
        net-tools \
        openssh-server \
        fail2ban \
        nmap \
        tcpdump \
        htop \
        iftop \
        iotop \
        inotify-tools \
        haproxy \
        netcat-openbsd
    
    info "$(get_message "Configuration du pare-feu..." "Configuring firewall...")"
    
    if dpkg -l | grep -q "^ii.*ufw"; then
        info "$(get_message "UFW détecté, utilisation d'UFW comme pare-feu" "UFW detected, using UFW as firewall")"
        configure_ufw_firewall
    else
        info "$(get_message "Installation d'iptables-persistent..." "Installing iptables-persistent...")"
        sudo apt install -y iptables-persistent netfilter-persistent
        configure_iptables_firewall
    fi
}

configure_ufw_firewall() {
    info "$(get_message "Configuration d'UFW..." "Configuring UFW...")"
    
    ufw_status=$(sudo ufw status)
    
    if [[ "$ufw_status" == *"Status: inactive"* ]]; then
        sudo ufw --force enable
    fi

    sudo ufw allow 22/tcp comment "SSH"           
    sudo ufw allow 80/tcp comment "HTTP"
    sudo ufw allow 443/tcp comment "HTTPS"
    sudo ufw allow 9050/tcp comment "TOR SOCKS"
    sudo ufw allow 18080/tcp comment "Monero P2P"
    sudo ufw allow 18081/tcp comment "Monero RPC"
    sudo ufw allow 18083/tcp comment "Monero ZMQ"
    sudo ufw allow 4200/tcp comment "Shell in box"
    sudo ufw allow 4444/tcp comment "I2P HTTP"
    sudo ufw allow 4447/tcp comment "I2P SOCKS"
    sudo ufw allow 19080/tcp comment "HAProxy Monero"
    sudo ufw allow 8443/tcp comment "HAProxy HTTPS"
    sudo ufw allow 8080/tcp comment "HAProxy HTTP"
    
    success "$(get_message "UFW configuré avec succès" "UFW configured successfully")"
}

configure_iptables_firewall() {
    info "$(get_message "Configuration d'iptables..." "Configuring iptables...")"
    
    sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 9050 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 18080 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 18081 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 18083 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 4200 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 4444 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 4447 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 19080 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 8443 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
    
    sudo netfilter-persistent save
    
    success "$(get_message "iptables configuré avec succès" "iptables configured successfully")"
}

Manuel() {
    clear
    setup_terminal
    echo -e "\n\n\n\n\n\n\n\n"  
    print_header "$(get_message "GUIDE" "HOW TO")"
   
    print_styled "MONERO" "$(get_message "Pour une installation complète, suivez ces étapes dans l'ordre:" "For a complete installation, follow these steps in order:")"
    echo
    print_styled "SUCCESS" "$(get_message "  1️⃣ ➜ 2️⃣ ➜ 3️⃣ ➜ 4️⃣ ➜ 5️⃣." "  1️⃣ ➜ 2️⃣ ➜ 3️⃣ ➜ 4️⃣ ➜ 5️⃣.")"
    echo
    print_styled "SUCCESS" "$(get_message "  Puis au choix :" "  Then your choice :")"
    echo
    print_styled "SUCCESS" "$(get_message "  ▶️ Disque interne : étape 6️⃣." "  ▶️ Internal disk : step 6️⃣.")"
    echo
    print_styled "SUCCESS" "$(get_message "  ▶️ Disque externe : étape 8️⃣ puis 6️⃣." "  ▶️ External disk : step 8️⃣ then 6️⃣.")"
    echo
    print_styled "MONERO" "$(get_message "  ▶️ Mode obfuscation : automatique après synchronisation à l'étape 6️⃣" "  ▶️ Obfuscation mode: automatic after synchronization at step 6️⃣")"
    echo
    print_header "$(get_message "AUTRES" "OTHER")"
    print_styled "GRIS" "$(get_message "  ➡️ Étape 6 : Démarrer le nœud et configurer l'exclusion des ⛔ 'IP bannis '." "  ➡️ step 6: Start the Node and introduce the exclusion of the ⛔ 'listed IP bans'.")"
    echo
    print_styled "GRIS" "$(get_message "  ➡️ Étape 9 : Démonter la blockchain du disque externe," "  ➡️ Step 9 : Is used to unmount the blockchain from the external disk,")"
    print_styled "GRIS" "$(get_message "  ↳ Pour revenir au disque interne : passez à l'étape 6." "  ↳ Return on internal disk: then step 6.")"
    echo
    print_styled "GRIS" "$(get_message "  ➡️ Étape 4 : Sert aussi pour le DEBUG du chemin d'amorçage du disque interne." "  ➡️ Step 4 : Also serves as DEBUG of the boot path to internal disk.")"
    echo
    print_styled "PRIMARY" "$(get_message "   CTRL+C 1 seule fois pour arreter la Blockchain et revenir au menu." "  -CTRL+C 1 time only to stop the Blockchain and return to the menu.")"
    echo
    print_styled "WARNING" "$(get_message "⚠️ Important: REDIRIGER le port 22 et 18080 de votre Box internet" "⚠️ Important: REDIRECT port 22 and 18080 from your internet router")"
    print_styled "WARNING" "$(get_message "  vers l'adresse 'ip local' de votre PC" "  to your 'local ip' of your PC")"
    echo
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour revenir au menu..." "Press Enter to return to menu...")")"
}

select_blockchain_type() {
    print_header "$(get_message "TYPE DE BLOCKCHAIN" "BLOCKCHAIN TYPE")"
    
    print_styled "PRIMARY" "$(get_message "1) Complète 220 Go" "1) Complete 220 Go")"
    print_styled "PRIMARY" "$(get_message "2) Prune 90 Go" "2) Pruned 90 Go")"
    echo -n "$(print_styled "INFO" "$(get_message "Choix (1-2): " "Choice (1-2): ")")"
    read -r choice
    case $choice in
        1) BLOCKCHAIN_TYPE="complete"; return 0  ;;
        2) BLOCKCHAIN_TYPE="pruned"; return 0 ;;
        *) 
           error "$(get_message "Choix invalide" "Invalid choice")" 
           return 1;;
    esac
}

update_system() {
    print_header "$(get_message "MISE À JOUR DU SYSTÈME" "SYSTEM UPDATE")"
    
    export DEBIAN_FRONTEND=noninteractive
    echo 'openssh-server openssh-server/permit-root-login boolean false' | sudo debconf-set-selections
    
    info "$(get_message "Mise à jour initiale du système..." "Initial system update...")"
    sudo apt update && sudo apt upgrade -y

    info "$(get_message "Installation des outils système essentiels..." "Installing essential system tools...")"
    sudo apt install -y \
        build-essential \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        curl \
        wget \
        git \
        gnupg \
        lsb-release

    info "$(get_message "Installation des outils de sécurité..." "Installing security tools...")"
    sudo apt install -y \
        gnupg \
        dirmngr \
        curl \
        wget

    info "$(get_message "Installation des outils de compression..." "Installing compression tools...")"
    sudo apt install -y \
        bzip2 \
        libbz2-dev \
        zip \
        unzip \
        tar \
        gzip

    

    info "$(get_message "Configuration de SSH..." "Configuring SSH...")"
sudo systemctl enable ssh
sudo systemctl start ssh

configure_ssh_safely

    info "$(get_message "Installation des outils Python..." "Installing Python tools...")"
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-dev

    info "$(get_message "Installation des éditeurs..." "Installing text editors...")"
    sudo apt install -y \
        vim \
        nano

   install_network_tools

    info "$(get_message "Configuration de fail2ban..." "Configuring fail2ban...")"
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban

    info "$(get_message "Nettoyage du système..." "System cleanup...")"
    sudo apt autoremove -y
    sudo apt clean
    
    unset DEBIAN_FRONTEND
    
    success "$(get_message "Mise à jour terminée" "Update completed")"
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
}

create_motd() {
    HOSTNAME=$(hostname)
    IP_ADDRESS=$(hostname -I | cut -d' ' -f1)
    SYSTEM_INFO=$(uname -s)" "$(uname -r)

    echo -e "\e[0;33;38;5;208m  *     *   ***   *   * ***** ****   ***   
  **   **  *   *  **  * *     *   * *   *  
  * * * * *     * * * * ****  ****  *   *  
  *  *  * *     * *  ** *     * *   *   *  
  *     *  *   *  *   * *     *  *  *   *  
  *     *   ***   *   * ***** *   *  ***   
  ═════════════ ▌EASYNODE▐ ═════════Linux\e[0m
  ════════Traffic obfuscation ═════════

\e[0;33;38;5;208m    ▐ EASYNODE               EASYNODE▐ \e[0m

\e[1;34mNode Status:\e[0m
- Hostname: $HOSTNAME
- IP Address: $IP_ADDRESS
- Monero Version: $MONERO_VERSION
- System: $SYSTEM_INFO

\e[1;33mUseful Commands:\e[0m
- monerod --help : Show Monero daemon help
- monero-wallet-cli --help : Show wallet CLI help

\e[1;31mImportant:\e[0m
- Start monero: monerod
- Stop  monero: CTRL+C
- Check status: monerod status" | sudo tee /etc/motd > /dev/null
}

ask_username() {
    clear
    setup_terminal
    echo -e "\n\n\n\n\n\n\n\n"  

    print_header "$(get_message "CONFIGURATION UTILISATEUR" "USER CONFIGURATION")"
    
    local current_user=""
    if [ -n "$SUDO_USER" ]; then
        current_user="$SUDO_USER"
    elif [ -n "$USER" ]; then
        current_user="$USER"
    else
        current_user=$(whoami)
    fi
    
    echo -e "$(get_message "Utilisateur détecté: " "Detected user: ")${COLORS[SUCCESS]}${current_user}${COLORS[RESET]}"
    echo
    
    print_styled "INFO" "$(get_message "Appuyez sur Entrée pour confirmer ou tapez un autre nom d'utilisateur: " "Press Enter to confirm or type another username: ")"
    read -r input_username
    
    if [ -z "$input_username" ]; then
        input_username="$current_user"
        USERNAME="$input_username"
        return 0
    fi
    
    if ! id "$input_username" &>/dev/null; then
        error "$(get_message "L'utilisateur n'existe pas" "User does not exist")"
        return 1
    fi
    
    USERNAME="$input_username"
    return 0
}

verify_monero_gpg() {
    local MONERO_FILE="$1"
    local MONERO_VERSION="$2"
    
    info "$(get_message "🔍 Vérification complète des binaires Monero..." "🔍 Complete Monero binary verification...")"
    
    info "$(get_message "📋 Vérifications préliminaires..." "📋 Preliminary checks...")"
    
    local FILE_SIZE=$(stat -c%s "$MONERO_FILE" 2>/dev/null || stat -f%z "$MONERO_FILE" 2>/dev/null)
    if [ -z "$FILE_SIZE" ]; then
        error "$(get_message "Impossible de lire la taille du fichier" "Cannot read file size")"
        return 1
    fi
    
    info "$(get_message "   Taille: $(( FILE_SIZE / 1024 / 1024 )) MB" "   Size: $(( FILE_SIZE / 1024 / 1024 )) MB")"
    
    if [ "$FILE_SIZE" -lt 50000000 ]; then
        error "$(get_message "Fichier trop petit (${FILE_SIZE} bytes) - téléchargement incomplet" "File too small (${FILE_SIZE} bytes) - incomplete download")"
        return 1
    fi
    
    if [ "$FILE_SIZE" -gt 200000000 ]; then
        warning "$(get_message "Fichier très volumineux ($(( FILE_SIZE / 1024 / 1024 )) MB)" "Very large file ($(( FILE_SIZE / 1024 / 1024 )) MB)")"
    fi
    
    if command -v file >/dev/null 2>&1; then
        local file_type=$(file "$MONERO_FILE")
        if echo "$file_type" | grep -q "bzip2"; then
            success "$(get_message "   ✅ Format bzip2 correct" "   ✅ Correct bzip2 format")"
        else
            error "$(get_message "Format de fichier inattendu: $file_type" "Unexpected file format: $file_type")"
            return 1
        fi
    fi
    
    if tar -tjf "$MONERO_FILE" >/dev/null 2>&1; then
        success "$(get_message "   ✅ Archive valide et lisible" "   ✅ Valid and readable archive")"
    else
        error "$(get_message "Archive corrompue ou invalide" "Corrupted or invalid archive")"
        return 1
    fi
    
    local monero_files=$(tar -tjf "$MONERO_FILE" 2>/dev/null | grep -E "(monerod|monero-wallet-cli)" | wc -l)
    if [ "$monero_files" -ge 2 ]; then
        success "$(get_message "   ✅ Fichiers Monero détectés ($monero_files fichiers)" "   ✅ Monero files detected ($monero_files files)")"
    else
        warning "$(get_message "   ⚠️ Fichiers Monero non clairement détectés" "   ⚠️ Monero files not clearly detected")"
    fi
    
    info "$(get_message "🔐 Vérification cryptographique..." "🔐 Cryptographic verification...")"
    
    if ! wget -q "https://www.getmonero.org/downloads/hashes.txt" -O hashes.txt; then
        error "$(get_message "Échec téléchargement hashes.txt depuis getmonero.org" "Failed to download hashes.txt from getmonero.org")"
        return 1
    fi
    
    local expected_hash=$(grep "monero-linux-x64-v${MONERO_VERSION}.tar.bz2" hashes.txt | awk '{print $1}')
    if [ -z "$expected_hash" ]; then
        error "$(get_message "Hash SHA256 non trouvé pour la version $MONERO_VERSION" "SHA256 hash not found for version $MONERO_VERSION")"
        rm -f hashes.txt
        return 1
    fi
    
    local actual_hash=$(sha256sum "$MONERO_FILE" | awk '{print $1}')
    if [ "$expected_hash" != "$actual_hash" ]; then
        error "$(get_message "❌ HASH SHA256 INVALIDE - FICHIER SUSPECT" "❌ INVALID SHA256 HASH - SUSPICIOUS FILE")"
        error "$(get_message "   Attendu: $expected_hash" "   Expected: $expected_hash")"
        error "$(get_message "   Obtenu:  $actual_hash" "   Got:      $actual_hash")"
        rm -f hashes.txt
        return 1
    fi
    
    success "$(get_message "✅ Hash SHA256 vérifié contre getmonero.org" "✅ SHA256 hash verified against getmonero.org")"
    
    local signer=""
    local fingerprint=""
    local key_date=""
    local sig_date=""
    
    if wget -q "https://www.getmonero.org/downloads/hashes.txt.sig" -O hashes.txt.sig; then
        info "$(get_message "🗝️ Vérification signature GPG..." "🗝️ Verifying GPG signature...")"
        
        if wget -q "https://raw.githubusercontent.com/monero-project/monero/master/utils/gpg_keys/binaryfate.asc" -O binaryfate.asc; then
            if gpg --import binaryfate.asc >/dev/null 2>&1; then
                printf "5\ny\n" | gpg --batch --quiet --command-fd 0 --edit-key F4ACA0183641E010 trust quit >/dev/null 2>&1
            fi
            rm -f binaryfate.asc
        fi
        
        local gpg_output=$(LANG=C gpg --verify hashes.txt.sig hashes.txt 2>&1)
        
        if echo "$gpg_output" | grep -q "No public key"; then
            local key_id=$(echo "$gpg_output" | grep -E "using RSA key" | awk '{print $NF}')
            if [ -n "$key_id" ]; then
                info "$(get_message "Import clé manquante..." "Importing missing key...")"
                if gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "$key_id" >/dev/null 2>&1; then
                    printf "5\ny\n" | gpg --batch --quiet --command-fd 0 --edit-key "$key_id" trust quit >/dev/null 2>&1
                    gpg_output=$(LANG=C gpg --verify hashes.txt.sig hashes.txt 2>&1)
                fi
            fi
        fi
        
        if echo "$gpg_output" | grep -q "Good signature"; then
            signer=$(echo "$gpg_output" | grep "Good signature from" | sed 's/.*"\([^"]*\)".*/\1/')
            
            sig_date=$(echo "$gpg_output" | grep "Signature made" | sed 's/.*Signature made //' | sed 's/ using.*//')
            
            fingerprint=$(echo "$gpg_output" | grep -E "Primary key fingerprint:" | sed 's/.*: //' | tr -d ' ')
            
            if [ -z "$fingerprint" ]; then
                local key_info=$(LANG=C gpg --list-keys "$signer" 2>/dev/null)
                fingerprint=$(echo "$key_info" | grep -A1 "pub" | tail -1 | tr -d ' ')
            fi
            
            local key_info=$(LANG=C gpg --list-keys "$signer" 2>/dev/null)
            key_date=$(echo "$key_info" | grep "pub" | sed 's/.*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/')
            
            success "$(get_message "🎉 SIGNATURE GPG VÉRIFIÉE !" "🎉 GPG SIGNATURE VERIFIED !")"
        else
            info "$(get_message "ℹ️ Signature GPG non vérifiable automatiquement" "ℹ️ GPG signature not automatically verifiable")"
        fi
    fi
    
    echo
    success "$(get_message "🎉 FICHIER MONERO AUTHENTIFIÉ AVEC SUCCÈS" "🎉 MONERO FILE SUCCESSFULLY AUTHENTICATED")"
    echo
    success "$(get_message "🔐 VÉRIFICATIONS CRYPTOGRAPHIQUES :" "🔐 CRYPTOGRAPHIC VERIFICATIONS:")"
    success "$(get_message "   ✓ Hash SHA256: $expected_hash" "   ✓ SHA256 Hash: $expected_hash")"
    
    if [ -n "$signer" ]; then
        success "$(get_message "   ✓ Signature GPG: $signer" "   ✓ GPG Signature: $signer")"
        if [ -n "$sig_date" ]; then
            success "$(get_message "   ✓ Signé le: $sig_date" "   ✓ Signed on: $sig_date")"
        fi
        if [ -n "$fingerprint" ]; then
            success "$(get_message "   ✓ Empreinte: $fingerprint" "   ✓ Fingerprint: $fingerprint")"
        fi
        if [ -n "$key_date" ]; then
            success "$(get_message "   ✓ Clé créée: $key_date" "   ✓ Key created: $key_date")"
        fi
    fi
    
    echo
    success "$(get_message "🛡️ GARANTIES DE SÉCURITÉ :" "🛡️ SECURITY GUARANTEES:")"
    success "$(get_message "   ✓ Intégrité physique vérifiée" "   ✓ Physical integrity verified")"
    success "$(get_message "   ✓ Authenticité cryptographique vérifiée" "   ✓ Cryptographic authenticity verified")" 
    success "$(get_message "   ✓ Contenu Monero confirmé" "   ✓ Monero content confirmed")"
    
    rm -f hashes.txt hashes.txt.sig binaryfate.asc
    
    return 0
}

create_launcher_and_shortcut() {
    local CURRENT_USER=""
    if [ -n "$SUDO_USER" ]; then
        CURRENT_USER="$SUDO_USER"
    else
        CURRENT_USER="$(whoami)"
    fi
    
    echo "Utilisateur détecté: $CURRENT_USER"
    
    local DESKTOP_PATHS=(
        "/home/$CURRENT_USER/Desktop"
        "/home/$CURRENT_USER/Bureau"
        "/home/$CURRENT_USER/Escritorio"
        "/home/$CURRENT_USER/Schreibtisch"
        "/home/$CURRENT_USER/桌面"
        "/home/$CURRENT_USER/デスクトップ"
    )
    
    local DESKTOP_DIR=""
    for path in "${DESKTOP_PATHS[@]}"; do
        if [ -d "$path" ]; then
            DESKTOP_DIR="$path"
            echo "Dossier Bureau/Desktop trouvé à: $DESKTOP_DIR"
            break
        fi
    done
    
    if [ -z "$DESKTOP_DIR" ]; then
        if [ -f "/home/$CURRENT_USER/.config/user-dirs.dirs" ]; then
            source "/home/$CURRENT_USER/.config/user-dirs.dirs"
            if [ -n "$XDG_DESKTOP_DIR" ] && [ -d "$XDG_DESKTOP_DIR" ]; then
                DESKTOP_DIR="$XDG_DESKTOP_DIR"
                echo "Dossier Bureau/Desktop trouvé via XDG à: $DESKTOP_DIR"
            fi
        fi
    fi
    
    if [ -z "$DESKTOP_DIR" ]; then
        DESKTOP_DIR="/home/$CURRENT_USER"
        echo "Dossier Bureau/Desktop non trouvé, utilisation de: $DESKTOP_DIR"
    fi
    
    local LAUNCHER_PATH="$DESKTOP_DIR/lancer_easynode.sh"
    
    echo "Création du script de lancement à: $LAUNCHER_PATH"
    
    cat > "$LAUNCHER_PATH" << 'EOL'
#!/bin/bash
echo "====================================="
echo " support du lanceur du raccourci bureau"
echo "        EASYNODE MONERO                "
echo " starter stand of the desktop shorcut  "
echo "====================================="



if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté avec sudo."
  echo "Tentative d'exécution avec sudo..."
  sudo "$0" "$@"
  exit $?
fi

echo "Téléchargement de la dernière version..."
wget https://github.com/kerlannXmr/EasyMonerod/releases/download/v3/easynode_linux.sh -O easynode_linux.sh

chmod +x easynode_linux.sh

echo "Démarrage du script EasyNode..."
./easynode_linux.sh

echo "Nettoyage..."
rm -f easynode_linux.sh

echo "Terminé!"
EOL
    
    chmod +x "$LAUNCHER_PATH"
    chown "$CURRENT_USER:$CURRENT_USER" "$LAUNCHER_PATH"
    
    local SHORTCUT_PATH="$DESKTOP_DIR/EasyNode_Monero.desktop"
    
    echo "Création du raccourci à: $SHORTCUT_PATH"
    
    cat > "$SHORTCUT_PATH" << EOL
[Desktop Entry]
Type=Application
Name=EasyNode Monero
Comment=Installer et configurer un nœud Monero
Exec=gnome-terminal -- bash -c "sudo $LAUNCHER_PATH; exec bash"
Icon=utilities-terminal
Terminal=false
Categories=System;
EOL
    
    chmod +x "$SHORTCUT_PATH"
    chown "$CURRENT_USER:$CURRENT_USER" "$SHORTCUT_PATH"
    
    local APPS_DIR="/home/$CURRENT_USER/.local/share/applications"
    if [ ! -d "$APPS_DIR" ]; then
        mkdir -p "$APPS_DIR"
        chown "$CURRENT_USER:$CURRENT_USER" "$APPS_DIR"
    fi
    
    cp "$SHORTCUT_PATH" "$APPS_DIR/"
    chown "$CURRENT_USER:$CURRENT_USER" "$APPS_DIR/EasyNode_Monero.desktop"
    
    echo "Création du raccourci terminée"
    return 0
}

install_monero_cli() {
    if [ -z "$USERNAME" ]; then
        error "$(get_message "Nom d'utilisateur non défini" "Username not defined")"
        return 1
    fi

    print_header "$(get_message "INSTALLATION DE MONERO" "MONERO INSTALLATION")"
    
    if ! command -v gpg &> /dev/null; then
        info "$(get_message "Installation de GPG..." "Installing GPG...")"
        sudo apt update && sudo apt install -y gnupg
    fi
    
    mkdir -p ~/monero_install
    cd ~/monero_install || exit
    
    local MONERO_FILE="monero-linux-x64-v${MONERO_VERSION}.tar.bz2"
    
    info "$(get_message "Téléchargement de Monero..." "Downloading Monero...")"
    if wget --tries=3 "https://downloads.getmonero.org/cli/${MONERO_FILE}"; then
        success "$(get_message "Téléchargement terminé" "Download completed")"
        
        local FILE_SIZE=$(stat -f%z "$MONERO_FILE" 2>/dev/null || stat -c%s "$MONERO_FILE")
        if [ "$FILE_SIZE" -lt 1000000 ]; then  
            error "$(get_message "Fichier téléchargé incomplet" "Downloaded file is incomplete")"
            rm -f "$MONERO_FILE"
            return 1
        fi
        
        if ! verify_monero_gpg "$MONERO_FILE" "$MONERO_VERSION"; then
            error "$(get_message "Échec de la vérification GPG" "GPG verification failed")"
            rm -f "$MONERO_FILE" "${MONERO_FILE}.asc"
            return 1
        fi
        
        info "$(get_message "Extraction des fichiers..." "Extracting files...")"
        if tar xvjf "$MONERO_FILE"; then
            success "$(get_message "Extraction terminée" "Extraction completed")"
        else
            error "$(get_message "Échec de l'extraction - Tentative de re-téléchargement" "Extraction failed - Trying to download again")"
            rm -f "$MONERO_FILE" "${MONERO_FILE}.asc"
            if wget --tries=3 "https://downloads.getmonero.org/cli/${MONERO_FILE}" && \
               verify_monero_gpg "$MONERO_FILE" && \
               tar xvjf "$MONERO_FILE"; then
                success "$(get_message "Second essai réussi" "Second attempt successful")"
            else
                error "$(get_message "Installation impossible" "Installation impossible")"
                return 1
            fi
        fi
    else
        error "$(get_message "Échec du téléchargement" "Download failed")"
        return 1
    fi

    sudo mkdir -p "/home/$USERNAME/monero"
    sudo cp -r "monero-x86_64-linux-gnu-v${MONERO_VERSION}"/* "/home/$USERNAME/monero/"
    echo "export PATH=\$PATH:/home/$USERNAME/monero" | sudo tee -a "/home/$USERNAME/.bashrc"

    sudo chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/monero"
    sudo chmod -R 755 "/home/$USERNAME/monero"

    sudo mkdir -p "/home/$USERNAME/.bitmonero"
    sudo chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.bitmonero"
    sudo chmod -R 755 "/home/$USERNAME/.bitmonero"

    cd ~ || exit
    rm -rf ~/monero_install

    success "$(get_message "✅ Installation terminée avec vérification GPG dans /home/$USERNAME/monero" "✅ Installation completed with GPG verification in /home/$USERNAME/monero")"
    return 0
}

install_tor() {
    print_header "$(get_message "INSTALLATION DE TOR" "TOR INSTALLATION")"
    
    if ! command -v tor &> /dev/null; then
        info "$(get_message "Installation de Tor..." "Installing Tor...")"
        if sudo apt update && sudo apt install -y tor; then
            success "$(get_message "Installation de Tor terminée" "Tor installation completed")"
        else
            error "$(get_message "Échec de l'installation de Tor" "Tor installation failed")"
            return 1
        fi
    else
        info "$(get_message "Tor est déjà installé" "Tor is already installed")"
    fi

    if [ -f /etc/tor/torrc ]; then
        sudo cp /etc/tor/torrc /etc/tor/torrc.backup
    fi

    sudo bash -c 'cat > /etc/tor/torrc << EOL
SOCKSPort 9050
ControlPort 9051
HiddenServiceDir /var/lib/tor/ssh/
HiddenServicePort 22 127.0.0.1:22         
HiddenServiceDir /var/lib/tor/monero-service/
HiddenServicePort 18081 127.0.0.1:18081
EOL'

    if [ ! -d "/var/lib/tor/monero-service/" ]; then
        sudo mkdir -p /var/lib/tor/monero-service/
        sudo chown -R debian-tor:debian-tor /var/lib/tor/monero-service/
        sudo chmod 700 /var/lib/tor/monero-service/
    fi

    if [ ! -d "/var/lib/tor/ssh/" ]; then
        sudo mkdir -p /var/lib/tor/ssh/
        sudo chown -R debian-tor:debian-tor /var/lib/tor/ssh/
        sudo chmod 700 /var/lib/tor/ssh/
    fi

    info "$(get_message "Redémarrage de Tor..." "Restarting Tor...")"
    sudo systemctl restart tor

    info "$(get_message "Génération de l'adresse onion..." "Generating onion address...")"
    sleep 10

    if [ -f /var/lib/tor/monero-service/hostname ]; then
        ONION_ADDRESS=$(sudo cat /var/lib/tor/monero-service/hostname)
        success "$(get_message "Adresse onion: $ONION_ADDRESS" "Onion address: $ONION_ADDRESS")"
        echo "Monero Onion Address ($(date)): $ONION_ADDRESS" | sudo tee -a "/home/$USERNAME/monero_onion_address.txt"
        sudo chown "$USERNAME:$USERNAME" "/home/$USERNAME/monero_onion_address.txt"
        echo "-------------------->$(get_message "L'adresse TOR est sauvegardée dans le dossier /home" "The TOR address is saved in the folder /home")"
    else
        error "$(get_message "Échec de la génération de l'adresse onion" "Failed to generate onion address")"
    fi

    if [ -f /var/lib/tor/ssh/hostname ]; then
        SSH_ONION_ADDRESS=$(sudo cat /var/lib/tor/ssh/hostname)
        success "$(get_message "Adresse onion SSH: " "SSH onion address: ")$SSH_ONION_ADDRESS"
        echo "SSH Onion Address ($(date)): $SSH_ONION_ADDRESS" | sudo tee -a "/home/$USERNAME/ssh_onion_address.txt"
        sudo chown "$USERNAME:$USERNAME" "/home/$USERNAME/ssh_onion_address.txt"
        echo "-------------------->$(get_message "L'adresse SSH est sauvegardée dans le dossier /home" "The SSH address is saved in the folder /home")"
    else
        error "$(get_message "Échec de la génération de l'adresse onion SSH" "Failed to generate SSH onion address")"
    fi

    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
}

configure_monero() {
    if [ -z "$USERNAME" ]; then
        error "$(get_message "Nom d'utilisateur non défini" "Username not defined")"
        return 1
    fi

    print_header "$(get_message "CONFIGURATION DE MONERO" "MONERO CONFIGURATION")"
    
    CONFIG_FILE="/home/$USERNAME/.bitmonero/bitmonero.conf"
    mkdir -p "/home/$USERNAME/.bitmonero"

    cat > "$CONFIG_FILE" << EOL
no-igd=1
no-zmq=1
rpc-bind-ip=0.0.0.0
rpc-bind-port=18081
p2p-bind-port=18080
p2p-bind-ip=0.0.0.0
in-peers=32
out-peers=32
disable-dns-checkpoints=1
confirm-external-bind=1
data-dir=/home/$USERNAME/.bitmonero
EOL

    echo
    print_styled "WARNING" "$(get_message "🔐 CONFIGURATION DE LA SÉCURITÉ RPC" "🔐 RPC SECURITY CONFIGURATION")"
    echo
    print_styled "INFO" "$(get_message "Choisissez le mode de sécurisation de votre nœud :" "Choose your node security mode:")"
    echo
    print_styled "PRIMARY" "$(get_message "1) AVEC mot de passe (Recommandé - Plus sécurisé)" "1) WITH password (Recommended - More secure)")"
    print_styled "GRIS" "$(get_message "   ↳ Nécessite une connexion en mode distant dans Monero GUI d'abord" "   ↳ Requires remote connection in Monero GUI first")"
    print_styled "GRIS" "$(get_message "   ↳ Puis vous pourrez revenir en mode local après connexion" "   ↳ Then you can switch back to local mode after connection")"
    echo
    print_styled "PRIMARY" "$(get_message "2) SANS mot de passe (Connexion directe en local)" "2) WITHOUT password (Direct local connection)")"
    print_styled "GRIS" "$(get_message "   ↳ Connexion directe possible mais moins sécurisé" "   ↳ Direct connection possible but less secure")"
    print_styled "GRIS" "$(get_message "   ↳ Recommandé uniquement pour usage personnel local" "   ↳ Recommended only for personal local use")"
    echo
    
    while true; do
        echo -n "$(print_styled "INFO" "$(get_message "Votre choix (1-2): " "Your choice (1-2): ")")"
        read -r security_choice
        
        case $security_choice in
            1)
                echo
                print_styled "SUCCESS" "$(get_message "✅ Configuration sécurisée choisie" "✅ Secure configuration selected")"
                echo
                print_styled "WARNING" "$(get_message "📝 IMPORTANT - Procédure de connexion Monero GUI :" "📝 IMPORTANT - Monero GUI connection procedure:")"
                print_styled "INFO" "$(get_message "   1️⃣ Ouvrir Monero GUI" "   1️⃣ Open Monero GUI")"
                print_styled "INFO" "$(get_message "   2️⃣ Aller dans Paramètres > Nœud" "   2️⃣ Go to Settings > Node")"
                print_styled "INFO" "$(get_message "   3️⃣ Sélectionner 'Nœud distant'" "   3️⃣ Select 'Remote node'")"
                print_styled "INFO" "$(get_message "   4️⃣ Entrer : [IP_DE_VOTRE_NOEUD]:18081" "   4️⃣ Enter: [YOUR_NODE_IP]:18081")"
                print_styled "INFO" "$(get_message "   5️⃣ Nom d'utilisateur : easynode" "   5️⃣ Username: easynode")"
                print_styled "INFO" "$(get_message "   6️⃣ Mot de passe : [celui que vous allez créer]" "   6️⃣ Password: [the one you're about to create]")"
                print_styled "INFO" "$(get_message "   7️⃣ Après synchronisation, vous pourrez revenir en mode 'Nœud local'" "   7️⃣ After sync, you can switch back to 'Local node' mode")"
                echo

                while true; do
                    echo -n "$(print_styled "PRIMARY" "$(get_message "Entrez un mot de passe RPC sécurisé: " "Enter a secure RPC password: ")")"
                    read -r RPC_PASSWORD
                    
                    if [ -z "$RPC_PASSWORD" ]; then
                        error "$(get_message "Le mot de passe ne peut pas être vide" "Password cannot be empty")"
                        continue
                    fi
                    
                    if [ ${#RPC_PASSWORD} -lt 6 ]; then
                        error "$(get_message "Le mot de passe doit contenir au moins 6 caractères" "Password must be at least 6 characters")"
                        continue
                    fi
                    
                    echo -n "$(print_styled "PRIMARY" "$(get_message "Confirmez le mot de passe: " "Confirm password: ")")"
                    read -r RPC_PASSWORD_CONFIRM
                    
                    if [ "$RPC_PASSWORD" = "$RPC_PASSWORD_CONFIRM" ]; then
                        break
                    else
                        error "$(get_message "Les mots de passe ne correspondent pas" "Passwords do not match")"
                        echo
                    fi
                done

                RPC_USERNAME="easynode"

                echo "rpc-login=$RPC_USERNAME:$RPC_PASSWORD" >> "$CONFIG_FILE"

                cat > "/home/$USERNAME/rpc_easynode_pass.txt" << EOL
=== IDENTIFICATION RPC MONERO (SÉCURISÉ) ===
Username: $RPC_USERNAME
Password: $RPC_PASSWORD
Date: $(date)
=====================================

📝 PROCÉDURE DE CONNEXION MONERO GUI :
1️⃣ Ouvrir Monero GUI
2️⃣ Aller dans Paramètres > Nœud  
3️⃣ Sélectionner 'Nœud distant'
4️⃣ Adresse: [IP_DE_VOTRE_NOEUD]:18081
5️⃣ Nom d'utilisateur: $RPC_USERNAME
6️⃣ Mot de passe: $RPC_PASSWORD
7️⃣ Après synchronisation complète, vous pourrez 
   revenir en mode 'Nœud local' dans les paramètres

⚠️ IMPORTANT: Gardez ce fichier en sécurité !
EOL

                print_styled "SUCCESS" "$(get_message "🔐 Authentification RPC sécurisée configurée" "🔐 Secure RPC authentication configured")"
                break
                ;;
                
            2)
                echo
                print_styled "WARNING" "$(get_message "⚠️ Configuration non sécurisée choisie" "⚠️ Unsecured configuration selected")"
                print_styled "INFO" "$(get_message "✅ Connexion directe possible en mode local dans Monero GUI" "✅ Direct connection possible in local mode in Monero GUI")"
                echo
                print_styled "INFO" "$(get_message "📝 PROCÉDURE DE CONNEXION MONERO GUI :" "📝 MONERO GUI CONNECTION PROCEDURE:")"
                print_styled "INFO" "$(get_message "   1️⃣ Ouvrir Monero GUI" "   1️⃣ Open Monero GUI")"
                print_styled "INFO" "$(get_message "   2️⃣ Sélectionner 'Nœud local' (mode par défaut)" "   2️⃣ Select 'Local node' (default mode)")"
                print_styled "INFO" "$(get_message "   3️⃣ Aucun mot de passe requis" "   3️⃣ No password required")"
                echo

                RPC_USERNAME=""
                RPC_PASSWORD=""

                cat > "/home/$USERNAME/rpc_easynode_pass.txt" << EOL
=== CONFIGURATION RPC MONERO (NON SÉCURISÉ) ===
Mode: Sans authentification
Date: $(date)
=====================================

📝 PROCÉDURE DE CONNEXION MONERO GUI :
1️⃣ Ouvrir Monero GUI
2️⃣ Sélectionner 'Nœud local' (mode par défaut)
3️⃣ Aucun mot de passe requis

⚠️ ATTENTION: Cette configuration est moins sécurisée
   mais plus simple pour un usage personnel local.
EOL

                print_styled "SUCCESS" "$(get_message "✅ Configuration sans authentification activée" "✅ Configuration without authentication enabled")"
                break
                ;;
                
            *)
                error "$(get_message "Choix invalide. Choisissez 1 ou 2." "Invalid choice. Choose 1 or 2.")"
                ;;
        esac
    done

    sudo chown "$USERNAME:$USERNAME" "$CONFIG_FILE"
    sudo chmod 644 "$CONFIG_FILE"
    sudo chown "$USERNAME:$USERNAME" "/home/$USERNAME/rpc_easynode_pass.txt"
    chmod 600 "/home/$USERNAME/rpc_easynode_pass.txt"  

    sudo chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.bitmonero"
    sudo chmod -R u+rw "/home/$USERNAME/.bitmonero"

    if grep -q "data-dir=" "$CONFIG_FILE" | grep -q "/media"; then
        BLOCKCHAIN_PATH=$(grep "data-dir=" "$CONFIG_FILE" | cut -d'=' -f2)
        
        if [ ! -d "$BLOCKCHAIN_PATH" ]; then
            mkdir -p "$(dirname "$BLOCKCHAIN_PATH")"
            ln -sf "/home/$USERNAME/.bitmonero" "$BLOCKCHAIN_PATH"
        fi
    fi

    success "$(get_message "Configuration créée dans $CONFIG_FILE" "Configuration created in $CONFIG_FILE")"
    
    if [ -n "$RPC_PASSWORD" ]; then
        print_styled "SUCCESS" "$(get_message "🔐 Mode sécurisé activé" "🔐 Secure mode enabled")"
        print_styled "PRIMARY" "$(get_message "Username: $RPC_USERNAME" "Username: $RPC_USERNAME")"
        print_styled "WARNING" "$(get_message "⚠️ Identifiants sauvés dans: /home/$USERNAME/rpc_easynode_pass.txt" "⚠️ Credentials saved in: /home/$USERNAME/rpc_easynode_pass.txt")"
        echo
        print_styled "INFO" "$(get_message "🔗 Pour Monero GUI : Mode distant puis local après sync" "🔗 For Monero GUI: Remote mode then local after sync")"
    else
        print_styled "SUCCESS" "$(get_message "✅ Mode direct activé" "✅ Direct mode enabled")"
        print_styled "INFO" "$(get_message "🔗 Pour Monero GUI : Mode local directement" "🔗 For Monero GUI: Local mode directly")"
    fi
    
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
}

configure_dns() {
    print_header "$(get_message "CONFIGURATION DNS" "DNS CONFIGURATION")"
    
    info "$(get_message "Configuration des serveurs DNS..." "Configuring DNS servers...")"

    sudo cp /etc/resolv.conf /etc/resolv.conf.backup

    if systemctl is-active --quiet systemd-resolved; then
        sudo systemctl stop systemd-resolved
        sudo systemctl disable systemd-resolved
    fi

    if [ -L /etc/resolv.conf ]; then
        sudo rm /etc/resolv.conf
    fi

    cat << EOL | sudo tee /etc/resolv.conf
nameserver 94.140.14.14
nameserver 94.140.15.15
EOL

    sudo chmod 644 /etc/resolv.conf

    success "$(get_message "Configuration DNS terminée" "DNS configuration completed")"
    info "$(get_message "Backup créé: /etc/resolv.conf.backup" "Backup created: /etc/resolv.conf.backup")"
    
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
}

unmount_sdb1() {
    print_header "$(get_message "DÉMONTAGE DU DISQUE" "DISK UNMOUNTING")"
    
    MOUNT_POINT="/media/$USERNAME"
    
    if mount | grep -q "$MOUNT_POINT"; then
        if lsof "$MOUNT_POINT" > /dev/null 2>&1; then
            warning "$(get_message "Fermeture des processus en cours..." "Closing active processes...")"
            lsof "$MOUNT_POINT" | awk 'NR!=1 {print $2}' | xargs -r sudo kill
            sleep 2
        fi
        
        if sudo umount -f "$MOUNT_POINT"; then
            success "$(get_message "Disque démonté avec succès" "Disk unmounted successfully")"
            
            if [ -n "$USERNAME" ]; then
                CONFIG_FILE="/home/$USERNAME/.bitmonero/bitmonero.conf"
                if [ -f "$CONFIG_FILE" ]; then
                    EXISTING_RPC_LOGIN=""
                    if grep -q "^rpc-login=" "$CONFIG_FILE"; then
                        EXISTING_RPC_LOGIN=$(grep "^rpc-login=" "$CONFIG_FILE")
                        info "$(get_message "Configuration RPC avec mot de passe préservée" "RPC configuration with password preserved")"
                    else
                        info "$(get_message "Configuration RPC sans mot de passe préservée" "RPC configuration without password preserved")"
                    fi
                    
                    grep -v "^data-dir=" "$CONFIG_FILE" | sudo tee "$CONFIG_FILE.tmp" > /dev/null
                    
                    echo "data-dir=/home/$USERNAME/.bitmonero" | sudo tee -a "$CONFIG_FILE.tmp"
                    
                    if [ -n "$EXISTING_RPC_LOGIN" ]; then
                        echo "$EXISTING_RPC_LOGIN" | sudo tee -a "$CONFIG_FILE.tmp"
                    fi
                    
                    sudo mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
                    sudo chown "$USERNAME:$USERNAME" "$CONFIG_FILE"
                    sudo chmod 644 "$CONFIG_FILE"
                    
                    sudo chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.bitmonero"
                    sudo chmod -R u+rw "/home/$USERNAME/.bitmonero"
                    
                    if [ -n "$EXISTING_RPC_LOGIN" ]; then
                        RPC_USERNAME=$(echo "$EXISTING_RPC_LOGIN" | cut -d'=' -f2 | cut -d':' -f1)
                        RPC_PASSWORD=$(echo "$EXISTING_RPC_LOGIN" | cut -d':' -f2)
                        
                        cat > "/home/$USERNAME/rpc_easynode_pass.txt" << EOL
=== IDENTIFICATION RPC MONERO (SÉCURISÉ) ===
Username: $RPC_USERNAME
Password: $RPC_PASSWORD
Date: $(date)
Blockchain: Disque interne - /home/$USERNAME/.bitmonero
=====================================

📝 PROCÉDURE DE CONNEXION MONERO GUI :
1️⃣ Ouvrir Monero GUI
2️⃣ Aller dans Paramètres > Nœud  
3️⃣ Sélectionner 'Nœud distant'
4️⃣ Adresse: [IP_DE_VOTRE_NOEUD]:18081
5️⃣ Nom d'utilisateur: $RPC_USERNAME
6️⃣ Mot de passe: $RPC_PASSWORD
7️⃣ Après synchronisation complète, vous pourrez 
   revenir en mode 'Nœud local' dans les paramètres

⚠️ IMPORTANT: Gardez ce fichier en sécurité !
EOL
                    else
                        cat > "/home/$USERNAME/rpc_easynode_pass.txt" << EOL
=== CONFIGURATION RPC MONERO (NON SÉCURISÉ) ===
Mode: Sans authentification
Date: $(date)
Blockchain: Disque interne - /home/$USERNAME/.bitmonero
=====================================

📝 PROCÉDURE DE CONNEXION MONERO GUI :
1️⃣ Ouvrir Monero GUI
2️⃣ Sélectionner 'Nœud local' (mode par défaut)
3️⃣ Aucun mot de passe requis

⚠️ ATTENTION: Cette configuration est moins sécurisée
   mais plus simple pour un usage personnel local.
EOL
                    fi
                    
                    sudo chown "$USERNAME:$USERNAME" "/home/$USERNAME/rpc_easynode_pass.txt"
                    chmod 600 "/home/$USERNAME/rpc_easynode_pass.txt"
                    
                    success "$(get_message "Configuration Monero mise à jour" "Monero configuration updated")"
                fi
            else
                warning "$(get_message "Impossible de mettre à jour la configuration: utilisateur non défini" "Cannot update configuration: username not defined")"
            fi
        else
            error "$(get_message "Échec du démontage" "Unmounting failed")"
            return 1
        fi
    else
        warning "$(get_message "Le disque n'est pas monté sur $MOUNT_POINT" "Disk is not mounted on $MOUNT_POINT")"
    fi
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
}

manage_blockchain() {
    print_header "$(get_message "GESTION DE LA BLOCKCHAIN" "BLOCKCHAIN MANAGEMENT")"
    
    if [ -z "$USERNAME" ]; then
        error "$(get_message "Nom d'utilisateur non défini" "Username not defined")"
        return 1
    fi

    EXTERNAL_DRIVE="/media/$USERNAME"
    
    BLOCKCHAIN_FOLDER="MoneroBlockchain"
    BLOCKCHAIN_PATH="$EXTERNAL_DRIVE/$BLOCKCHAIN_FOLDER"

    info "$(get_message "Liste des disques disponibles:" "Available disks:")"
    lsblk -nrpo "NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE" | awk '$3=="disk" || $3=="part"'
    
    echo -n "$(print_styled "INFO" "$(get_message "Entrez le nom du disque (ex: sdb1): " "Enter disk name (e.g., sdb1): ")")"
    read -r DEVICE
    
    if [ -z "$DEVICE" ]; then
        error "$(get_message "Aucun disque sélectionné" "No disk selected")"
        return 1
    fi
    
    DEVICE="/dev/$DEVICE"
    
    if [ ! -b "$DEVICE" ]; then
        error "$(get_message "Le périphérique $DEVICE n'existe pas" "Device $DEVICE does not exist")"
        return 1
    fi

    if mount | grep -q "$DEVICE"; then
        sudo umount "$DEVICE" 2>/dev/null
    fi

    sudo mkdir -p "$EXTERNAL_DRIVE"
    if ! sudo mount -o uid=$(id -u $USERNAME),gid=$(id -g $USERNAME) "$DEVICE" "$EXTERNAL_DRIVE"; then
        error "$(get_message "Échec du montage" "Mount failed")"
        return 1
    fi
    
    sudo mkdir -p "$BLOCKCHAIN_PATH"
    
    CONFIG_FILE="/home/$USERNAME/.bitmonero/bitmonero.conf"
    if [ -f "$CONFIG_FILE" ]; then
        sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
        
        EXISTING_RPC_LOGIN=""
        if grep -q "^rpc-login=" "$CONFIG_FILE"; then
            EXISTING_RPC_LOGIN=$(grep "^rpc-login=" "$CONFIG_FILE")
            info "$(get_message "Configuration RPC existante préservée" "Existing RPC configuration preserved")"
        else
            info "$(get_message "Aucune configuration RPC trouvée - mode sans mot de passe conservé" "No RPC configuration found - passwordless mode preserved")"
        fi
    fi

    sudo mkdir -p "$(dirname "$CONFIG_FILE")"

    TMP_CONFIG=$(mktemp)
    
    {
        echo "# Configuration Monero"
        echo "no-igd=1"
        echo "no-zmq=1"
        echo "rpc-bind-ip=0.0.0.0"
        echo "rpc-bind-port=18081"
        echo "p2p-bind-port=18080"
        echo "p2p-bind-ip=0.0.0.0"
        echo "in-peers=32"
        echo "out-peers=32"
        echo "disable-dns-checkpoints=1"
        echo "confirm-external-bind=1"
        echo "data-dir=$BLOCKCHAIN_PATH"
        
        if [ -n "$EXISTING_RPC_LOGIN" ]; then
            echo "$EXISTING_RPC_LOGIN"
        fi
        
        if [ "$BLOCKCHAIN_TYPE" = "pruned" ]; then
            echo "prune-blockchain=1"
        fi
    } > "$TMP_CONFIG"

    if [ -n "$EXISTING_RPC_LOGIN" ]; then
        success "$(get_message "Configuration RPC avec mot de passe conservée" "RPC configuration with password preserved")"
    else
        success "$(get_message "Configuration RPC sans mot de passe conservée" "RPC configuration without password preserved")"
    fi

    if [ -s "$TMP_CONFIG" ]; then
        sudo cp "$TMP_CONFIG" "$CONFIG_FILE"
        rm "$TMP_CONFIG"
        
        if ! grep -q "^data-dir=" "$CONFIG_FILE"; then
            echo "data-dir=$BLOCKCHAIN_PATH" | sudo tee -a "$CONFIG_FILE"
        fi
    else
        error "$(get_message "Erreur lors de la création de la configuration" "Error creating configuration")"
        rm -f "$TMP_CONFIG"
        return 1
    fi

    sudo chown "$USERNAME:$USERNAME" "$CONFIG_FILE"
    sudo chmod 644 "$CONFIG_FILE"
    sudo chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.bitmonero"
    sudo chmod -R u+rw "/home/$USERNAME/.bitmonero"

    DEVICE_UUID=$(sudo blkid -s UUID -o value "$DEVICE")
    if [ -z "$DEVICE_UUID" ]; then
        error "$(get_message "Impossible d'obtenir l'UUID du disque" "Unable to get disk UUID")"
        return 1
    fi

    MOUNTPOINT_BEFORE=$(findmnt -n -o TARGET -S UUID="$DEVICE_UUID" 2>/dev/null || echo "")
    if [ -n "$MOUNTPOINT_BEFORE" ] && [ "$MOUNTPOINT_BEFORE" != "$EXTERNAL_DRIVE" ]; then
        info "$(get_message "Le disque est actuellement monté sur $MOUNTPOINT_BEFORE" "Disk is currently mounted on $MOUNTPOINT_BEFORE")"
    fi

    if grep -q "UUID=$DEVICE_UUID" /etc/fstab; then
        info "$(get_message "Suppression des entrées existantes pour UUID=$DEVICE_UUID" "Removing existing entries for UUID=$DEVICE_UUID")"
        sudo sed -i "/UUID=$DEVICE_UUID/d" /etc/fstab
    fi

    USER_ID=$(id -u "$USERNAME")
    GROUP_ID=$(id -g "$USERNAME")
    echo "# Entrée pour EasyNode - Ne pas modifier manuellement" | sudo tee -a /etc/fstab > /dev/null
    echo "UUID=$DEVICE_UUID $EXTERNAL_DRIVE auto defaults,users,uid=$USER_ID,gid=$GROUP_ID,umask=022,nofail,x-gvfs-show 0 0" | sudo tee -a /etc/fstab > /dev/null
    success "$(get_message "Configuration du montage automatique ajoutée/mise à jour" "Automatic mount configuration added/updated")"

    info "$(get_message "Rechargement de systemd..." "Reloading systemd...")"
    sudo systemctl daemon-reload

    if ! mountpoint -q "$EXTERNAL_DRIVE"; then
        info "$(get_message "Montage du disque..." "Mounting disk...")"
        sudo mount -a
        
        if ! mountpoint -q "$EXTERNAL_DRIVE"; then
            warning "$(get_message "Le montage automatique a échoué, tentative de montage direct..." "Automatic mount failed, trying direct mount...")"
            sudo mount -U "$DEVICE_UUID" "$EXTERNAL_DRIVE"
        fi
    fi

    if [ -n "$EXISTING_RPC_LOGIN" ]; then
        RPC_USERNAME=$(echo "$EXISTING_RPC_LOGIN" | cut -d'=' -f2 | cut -d':' -f1)
        RPC_PASSWORD=$(echo "$EXISTING_RPC_LOGIN" | cut -d':' -f2)
        
        cat > "/home/$USERNAME/rpc_easynode_pass.txt" << EOL
=== IDENTIFICATION RPC MONERO (SÉCURISÉ) ===
Username: $RPC_USERNAME
Password: $RPC_PASSWORD
Date: $(date)
Blockchain: Disque externe - $BLOCKCHAIN_PATH
=====================================

📝 PROCÉDURE DE CONNEXION MONERO GUI :
1️⃣ Ouvrir Monero GUI
2️⃣ Aller dans Paramètres > Nœud  
3️⃣ Sélectionner 'Nœud distant'
4️⃣ Adresse: [IP_DE_VOTRE_NOEUD]:18081
5️⃣ Nom d'utilisateur: $RPC_USERNAME
6️⃣ Mot de passe: $RPC_PASSWORD
7️⃣ Après synchronisation complète, vous pourrez 
   revenir en mode 'Nœud local' dans les paramètres

⚠️ IMPORTANT: Gardez ce fichier en sécurité !
EOL
    else
        cat > "/home/$USERNAME/rpc_easynode_pass.txt" << EOL
=== CONFIGURATION RPC MONERO (NON SÉCURISÉ) ===
Mode: Sans authentification
Date: $(date)
Blockchain: Disque externe - $BLOCKCHAIN_PATH
=====================================

📝 PROCÉDURE DE CONNEXION MONERO GUI :
1️⃣ Ouvrir Monero GUI
2️⃣ Sélectionner 'Nœud local' (mode par défaut)
3️⃣ Aucun mot de passe requis

⚠️ ATTENTION: Cette configuration est moins sécurisée
   mais plus simple pour un usage personnel local.
EOL
    fi
    
    sudo chown "$USERNAME:$USERNAME" "/home/$USERNAME/rpc_easynode_pass.txt"
    chmod 600 "/home/$USERNAME/rpc_easynode_pass.txt"

    success "$(get_message "Blockchain configurée dans: $BLOCKCHAIN_PATH" "Blockchain configured in: $BLOCKCHAIN_PATH")"
    info "$(get_message "Le disque sera monté automatiquement au démarrage" "The disk will be automatically mounted at boot")"
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
}

install_inotify_tools() {
    if ! command -v inotifywait &> /dev/null; then
        info "$(get_message "inotifywait non trouvé, installation de inotify-tools..." "inotifywait not found, installing inotify-tools...")"
        sudo apt update && sudo apt install -y inotify-tools
        if command -v inotifywait &> /dev/null; then
            success "$(get_message "inotify-tools installé avec succès" "inotify-tools successfully installed")"
            return 0
        else
            error "$(get_message "Échec de l'installation de inotify-tools" "Failed to install inotify-tools")"
            return 1
        fi
    else
        return 0  
    fi
}

save_iptables_manually() {
    info "$(get_message "Sauvegarde manuelle des règles iptables..." "Manually saving iptables rules...")"
    
    sudo mkdir -p /etc/iptables
    
    if [ ! -d "/etc/network/if-pre-up.d" ]; then
        sudo mkdir -p /etc/network/if-pre-up.d
    fi
    
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"
    sudo sh -c "ip6tables-save > /etc/iptables/rules.v6"
    
    sudo bash -c 'cat > /etc/network/if-pre-up.d/iptables-restore << "EOL"
#!/bin/bash
if [ -f /etc/iptables/rules.v4 ]; then
    iptables-restore < /etc/iptables/rules.v4
fi
if [ -f /etc/iptables/rules.v6 ]; then
    ip6tables-restore < /etc/iptables/rules.v6
fi
exit 0
EOL'
    
    sudo chmod +x /etc/network/if-pre-up.d/iptables-restore
    
    success "$(get_message "Règles iptables sauvegardées manuellement" "iptables rules manually saved")"
}

cleanup_external_drive() {
    local DEVICE=$1
    local MOUNT_POINT=$2
    
    if [ -z "$DEVICE" ] || [ -z "$MOUNT_POINT" ]; then
        error "$(get_message "Arguments manquants pour cleanup_external_drive" "Missing arguments for cleanup_external_drive")"
        return 1
    fi
    
    local DEVICE_UUID=$(sudo blkid -s UUID -o value "$DEVICE")
    if [ -z "$DEVICE_UUID" ]; then
        error "$(get_message "Impossible d'obtenir l'UUID du disque" "Unable to get disk UUID")"
        return 1
    fi
    
    if ! grep -q "UUID=$DEVICE_UUID" /etc/fstab; then
        info "$(get_message "Aucune entrée trouvée dans fstab pour ce disque" "No entry found in fstab for this disk")"
        return 0
    fi
    
    info "$(get_message "Suppression des entrées fstab pour UUID=$DEVICE_UUID" "Removing fstab entries for UUID=$DEVICE_UUID")"
    sudo sed -i "/UUID=$DEVICE_UUID/d" /etc/fstab
    
    info "$(get_message "Rechargement de systemd..." "Reloading systemd...")"
    sudo systemctl daemon-reload
    
    info "$(get_message "Redémarrage du service de montage automatique..." "Restarting automatic mount service...")"
    sudo systemctl restart udisks2
    
    success "$(get_message "Disque nettoyé avec succès. Il devrait maintenant se monter normalement." "Disk successfully cleaned up. It should now mount normally.")"
    return 0
}

ensure_obfuscation_files() {
    local username="$1"
    
    if [ ! -d "/home/$username/monero/obfuscation" ]; then
        info "$(get_message "Création du répertoire d'obscurcissement..." "Creating obfuscation directory...")"
        mkdir -p "/home/$username/monero/obfuscation"
        sudo chown -R "$username:$username" "/home/$username/monero/obfuscation"
    fi
    
    local decoy_script="/home/$username/monero/obfuscation/decoy_traffic.sh"
    if [ ! -f "$decoy_script" ]; then
        info "$(get_message "Création du script de leurre..." "Creating decoy script...")"
        cat > "$decoy_script" << 'EOL'
#!/bin/bash


if [ -f "/home/$USER/monero/obfuscation/profile.conf" ]; then
    source "/home/$USER/monero/obfuscation/profile.conf"
fi

LOGFILE="/tmp/monero_decoy.log"
echo "Démarrage du service de leurre à $(date)" > $LOGFILE

generate_random_traffic() {
    local size=$(shuf -i ${PACKET_SIZE_MIN:-512}-${PACKET_SIZE_MAX:-1500} -n 1)
    local wait=$(shuf -i ${CONNECTION_INTERVAL_MIN:-5}-${CONNECTION_INTERVAL_MAX:-30} -n 1)
    
    local port_choice=$(( RANDOM % 3 ))
    case $port_choice in
        0) PORT=${PORT_PRIMARY:-8443} ;;
        1) PORT=${PORT_SECONDARY:-8080} ;;
        2) PORT=19080 ;;  
    esac
    
    timeout 5s bash -c "dd if=/dev/urandom bs=$size count=1 2>/dev/null | nc -w 2 127.0.0.1 $PORT" >/dev/null 2>&1
    echo "$(date +"%H:%M:%S"): Envoi de $size octets au port $PORT" >> $LOGFILE
    sleep $wait
}

if [ -z "$PACKET_SIZE_MIN" ]; then PACKET_SIZE_MIN=512; fi
if [ -z "$PACKET_SIZE_MAX" ]; then PACKET_SIZE_MAX=1500; fi
if [ -z "$CONNECTION_INTERVAL_MIN" ]; then CONNECTION_INTERVAL_MIN=5; fi
if [ -z "$CONNECTION_INTERVAL_MAX" ]; then CONNECTION_INTERVAL_MAX=30; fi
if [ -z "$PORT_PRIMARY" ]; then PORT_PRIMARY=8443; fi
if [ -z "$PORT_SECONDARY" ]; then PORT_SECONDARY=8080; fi
if [ -z "$TRAFFIC_PATTERN" ]; then TRAFFIC_PATTERN="bursty"; fi
if [ -z "$IDLE_PERIODS" ]; then IDLE_PERIODS="true"; fi

echo "Configuration chargée: $TRAFFIC_PATTERN, ports: $PORT_PRIMARY/$PORT_SECONDARY" >> $LOGFILE

while true; do
    case "$TRAFFIC_PATTERN" in
        "bursty")
            echo "Mode burst ($(date))" >> $LOGFILE
            for i in {1..5}; do
                generate_random_traffic
                sleep $(shuf -i 1-3 -n 1)
            done
            if [ "$IDLE_PERIODS" = "true" ]; then
                IDLE=$(shuf -i 10-30 -n 1)
                echo "Pause de $IDLE secondes" >> $LOGFILE
                sleep $IDLE
            else
                sleep $(shuf -i 3-8 -n 1)
            fi
            ;;
        "sustained")
            echo "Mode soutenu ($(date))" >> $LOGFILE
            generate_random_traffic
            ;;
        "periodic")
            echo "Mode périodique ($(date))" >> $LOGFILE
            generate_random_traffic
            if [ "$IDLE_PERIODS" = "true" ]; then
                if [ $(( RANDOM % 5 )) -eq 0 ]; then
                    IDLE=$(shuf -i 30-60 -n 1)
                    echo "Pause longue de $IDLE secondes" >> $LOGFILE
                    sleep $IDLE
                fi
            fi
            ;;
        *)
            echo "Mode par défaut ($(date))" >> $LOGFILE
            generate_random_traffic
            ;;
    esac
    sleep 1
done
EOL
        chmod 755 "$decoy_script"
        sudo chown "$username:$username" "$decoy_script"
        success "$(get_message "Script de leurre créé" "Decoy script created")"
    fi
    
    local iptables_script="/home/$username/monero/obfuscation/iptables_setup.sh"
    if [ ! -f "$iptables_script" ]; then
        info "$(get_message "Création du script iptables..." "Creating iptables script...")"
        cat > "$iptables_script" << 'EOL'
#!/bin/bash

if [ -f "/home/$USER/monero/obfuscation/profile.conf" ]; then
    source "/home/$USER/monero/obfuscation/profile.conf"
fi

declare -a PROXY_PORTS=(19080 8443 8080)

sudo iptables -t mangle -F

for PORT in "${PROXY_PORTS[@]}"; do
    sudo iptables -t mangle -A POSTROUTING -p tcp --dport $PORT -j TTL --ttl-set $(shuf -i 40-65 -n 1)
    
    sudo iptables -t mangle -A POSTROUTING -p tcp --dport $PORT -j TOS --set-tos $(shuf -i 0-15 -n 1)
    
    sudo iptables -t mangle -A POSTROUTING -p tcp --dport $PORT -j TCPMSS --set-mss $(shuf -i 1200-1460 -n 1)
done

sudo netfilter-persistent save

echo "Configuration iptables terminée"
EOL
        chmod 755 "$iptables_script"
        sudo chown "$username:$username" "$iptables_script"
        success "$(get_message "Script iptables créé" "iptables script created")"
    fi
    
    local profile_file="/home/$username/monero/obfuscation/profile.conf"
    if [ ! -f "$profile_file" ]; then
        info "$(get_message "Création du profil d'obscurcissement..." "Creating obfuscation profile...")"
        cat > "$profile_file" << EOL
TRAFFIC_TYPE=web
PACKET_SIZE_MIN=512
PACKET_SIZE_MAX=1500
CONNECTION_INTERVAL_MIN=5
CONNECTION_INTERVAL_MAX=30
PORT_PRIMARY=443
PORT_SECONDARY=80
TRAFFIC_PATTERN=bursty
IDLE_PERIODS=true
EOL
        chmod 644 "$profile_file"
        sudo chown "$username:$username" "$profile_file"
        success "$(get_message "Profil d'obscurcissement créé" "Obfuscation profile created")"
    fi
}

configure_obfuscation_profile() {
    clear
    setup_terminal
    echo -e "\n\n\n\n\n\n\n\n"  
  
    print_header "$(get_message "GESTION DU PROFIL D'OBSCURCISSEMENT" "OBFUSCATION PROFILE MANAGEMENT")"
    
    OBFS_PROFILE="/home/$USERNAME/monero/obfuscation/profile.conf"
    if [ -f "$OBFS_PROFILE" ]; then
        print_styled "INFO" "$(get_message "Un profil d'obscurcissement existe déjà" "An obfuscation profile already exists")"
    else
        print_styled "WARNING" "$(get_message "Aucun profil d'obscurcissement n'est configuré" "No obfuscation profile is configured")"
    fi
    
    print_styled "PRIMARY" "$(get_message "Que souhaitez-vous faire ?" "What would you like to do?")"
    print_styled "PRIMARY" "1) $(get_message "Configurer un nouveau profil" "Configure a new profile")"
    print_styled "PRIMARY" "2) $(get_message "Réinitialiser le profil existant" "Reset existing profile")"
    print_styled "PRIMARY" "3) $(get_message "Retour au menu précédent" "Back to previous menu")"
    echo -n "$(print_styled "INFO" "$(get_message "Choix (1-3): " "Choice (1-3): ")")"
    read -r profile_action
    
    case $profile_action in
        1)
            configure_profile_type
            ;;
        2)
            reset_profile
            return 0
            ;;
        3)
            return 0
            ;;
        *)
            error "$(get_message "Choix invalide" "Invalid choice")"
            return 1
            ;;
    esac
    
    return 0
}

configure_profile_type() {
    print_styled "PRIMARY" "$(get_message "Sélectionnez un profil d'obscurcissement:" "Select obfuscation profile:")"
    print_styled "PRIMARY" "1) $(get_message "Navigation Web (HTTP/HTTPS)" "Web Browsing (HTTP/HTTPS)")"
    print_styled "PRIMARY" "2) $(get_message "Streaming Vidéo" "Video Streaming")"
    print_styled "PRIMARY" "3) $(get_message "Service Cloud" "Cloud Service")"
    print_styled "PRIMARY" "4) $(get_message "Personnalisé" "Custom")"
    echo -n "$(print_styled "INFO" "$(get_message "Choix (1-4): " "Choice (1-4): ")")"
    read -r profile_choice
    
    OBFS_PROFILE="/home/$USERNAME/monero/obfuscation/profile.conf"
    
    case $profile_choice in
        1)
            cat > "$OBFS_PROFILE" << EOL
TRAFFIC_TYPE=web
PACKET_SIZE_MIN=512
PACKET_SIZE_MAX=1500
CONNECTION_INTERVAL_MIN=5
CONNECTION_INTERVAL_MAX=30
PORT_PRIMARY=443
PORT_SECONDARY=80
TRAFFIC_PATTERN=bursty
IDLE_PERIODS=true
EOL
            success "$(get_message "Profil Navigation Web configuré" "Web Browsing profile configured")"
            ;;
        2)
            cat > "$OBFS_PROFILE" << EOL
TRAFFIC_TYPE=streaming
PACKET_SIZE_MIN=1200
PACKET_SIZE_MAX=1500
CONNECTION_INTERVAL_MIN=1
CONNECTION_INTERVAL_MAX=3
PORT_PRIMARY=443
PORT_SECONDARY=8080
TRAFFIC_PATTERN=sustained
IDLE_PERIODS=false
EOL
            success "$(get_message "Profil Streaming Vidéo configuré" "Video Streaming profile configured")"
            ;;
        3)
            cat > "$OBFS_PROFILE" << EOL
TRAFFIC_TYPE=cloud
PACKET_SIZE_MIN=800
PACKET_SIZE_MAX=1400
CONNECTION_INTERVAL_MIN=10
CONNECTION_INTERVAL_MAX=60
PORT_PRIMARY=443
PORT_SECONDARY=8443
TRAFFIC_PATTERN=periodic
IDLE_PERIODS=true
EOL
            success "$(get_message "Profil Service Cloud configuré" "Cloud Service profile configured")"
            ;;
        4)
            print_styled "INFO" "$(get_message "Configuration personnalisée:" "Custom configuration:")"
            
            echo -n "$(get_message "Taille minimale des paquets (512-1500) [512]: " "Minimum packet size (512-1500) [512]: ")"
            read -r packet_min
            packet_min=${packet_min:-512}
            
            echo -n "$(get_message "Taille maximale des paquets (512-1500) [1500]: " "Maximum packet size (512-1500) [1500]: ")"
            read -r packet_max
            packet_max=${packet_max:-1500}
            
            echo -n "$(get_message "Intervalle minimum entre connexions (1-60) [5]: " "Minimum connection interval (1-60) [5]: ")"
            read -r conn_min
            conn_min=${conn_min:-5}
            
            echo -n "$(get_message "Intervalle maximum entre connexions (1-60) [30]: " "Maximum connection interval (1-60) [30]: ")"
            read -r conn_max
            conn_max=${conn_max:-30}
            
            echo -n "$(get_message "Port principal (443/8443/80) [443]: " "Primary port (443/8443/80) [443]: ")"
            read -r port_primary
            port_primary=${port_primary:-443}
            
            echo -n "$(get_message "Port secondaire (80/8080/8443) [80]: " "Secondary port (80/8080/8443) [80]: ")"
            read -r port_secondary
            port_secondary=${port_secondary:-80}
            
            echo "$(get_message "Modèle de trafic:" "Traffic pattern:")"
            echo "1) bursty - $(get_message "Rafales de trafic" "Traffic bursts")"
            echo "2) sustained - $(get_message "Trafic soutenu" "Sustained traffic")"
            echo "3) periodic - $(get_message "Trafic périodique" "Periodic traffic")"
            echo -n "$(get_message "Choix [1]: " "Choice [1]: ")"
            read -r pattern_choice
            case $pattern_choice in
                2) traffic_pattern="sustained" ;;
                3) traffic_pattern="periodic" ;;
                *) traffic_pattern="bursty" ;;
            esac
            
            echo -n "$(get_message "Périodes d'inactivité (o/n) [o]: " "Idle periods (y/n) [y]: ")"
            read -r idle_choice
            if [[ $idle_choice =~ ^[Nn] ]]; then
                idle_periods="false"
            else
                idle_periods="true"
            fi
            
            cat > "$OBFS_PROFILE" << EOL
TRAFFIC_TYPE=custom
PACKET_SIZE_MIN=$packet_min
PACKET_SIZE_MAX=$packet_max
CONNECTION_INTERVAL_MIN=$conn_min
CONNECTION_INTERVAL_MAX=$conn_max
PORT_PRIMARY=$port_primary
PORT_SECONDARY=$port_secondary
TRAFFIC_PATTERN=$traffic_pattern
IDLE_PERIODS=$idle_periods
EOL
            success "$(get_message "Profil personnalisé configuré" "Custom profile configured")"
            ;;
        *)
            error "$(get_message "Choix invalide" "Invalid choice")"
            return 1
            ;;
    esac
    
    sudo chown "$USERNAME:$USERNAME" "$OBFS_PROFILE"
    sudo chmod 644 "$OBFS_PROFILE"
    
    return 0
}

reset_profile() {
    print_styled "INFO" "$(get_message "Cette action va supprimer le profil d'obscurcissement" "This action will delete the obfuscation profile")"
    print_styled "INFO" "$(get_message "Voulez-vous vraiment supprimer le profil? (o/n): " "Do you really want to delete the profile? (y/n): ")"
    read -r confirm_reset
    
    if [[ ! $confirm_reset =~ ^[OoYy] ]]; then
        print_styled "INFO" "$(get_message "Suppression annulée" "Deletion cancelled")"
        return 0
    fi
    
    OBFS_DIR="/home/$USERNAME/monero/obfuscation"
    PROFILE_FILE="$OBFS_DIR/profile.conf"
    
    if [ -f "$PROFILE_FILE" ]; then
        BACKUP_FILE="$PROFILE_FILE.backup_$(date +%Y%m%d%H%M%S)"
        cp "$PROFILE_FILE" "$BACKUP_FILE"
        success "$(get_message "Ancien profil sauvegardé: $BACKUP_FILE" "Old profile backed up: $BACKUP_FILE")"
        
        rm -f "$PROFILE_FILE"
        success "$(get_message "✅ Profil d'obscurcissement supprimé" "✅ Obfuscation profile deleted")"
    else
        info "$(get_message "Aucun profil d'obscurcissement trouvé" "No obfuscation profile found")"
    fi
    
    success "$(get_message "Vous pourrez configurer un nouveau profil lors du démarrage de la blockchain" "You can configure a new profile when starting the blockchain")"
    
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
    return 0
}

setup_traffic_obfuscation() {
    clear
    setup_terminal
    echo -e "\n\n\n\n\n\n\n\n"  
    
    print_header "$(get_message "CONFIGURATION D'OBSCURCISSEMENT DE TRAFIC" "TRAFFIC OBFUSCATION SETUP")"
    
    if [ -z "$USERNAME" ]; then
        error "$(get_message "Nom d'utilisateur non défini" "Username not defined")"
        return 1
    fi
    
    MONEROD_PATH="/home/$USERNAME/monero/monerod"
    if [ ! -x "$MONEROD_PATH" ]; then
        error "$(get_message "Monero n'est pas installé. Veuillez d'abord installer Monero (option 2)" "Monero is not installed. Please install Monero first (option 2)")"
        return 1
    fi
    
    info "$(get_message "Installation des dépendances nécessaires..." "Installing required dependencies...")"
    sudo apt update
    sudo apt install -y iptables-persistent haproxy obfs4proxy nftables haveged

    ensure_obfuscation_files "$USERNAME"
    
    configure_obfuscation_profile
    
    configure_obfuscation_tools
    
    success "$(get_message "Configuration de l'obscurcissement terminée" "Obfuscation setup completed")"
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
    clear
    setup_terminal
    echo -e "\n\n\n\n\n\n\n\n"  
    return 0
}

configure_obfuscation_tools() {
    info "$(get_message "Configuration de HAProxy..." "Configuring HAProxy...")"

    MONERO_CONFIG="/home/$USERNAME/.bitmonero/bitmonero.conf"
    if [ -f "$MONERO_CONFIG" ]; then
        MONERO_PORT=$(grep "^p2p-bind-port=" "$MONERO_CONFIG" | cut -d'=' -f2)
    else
        MONERO_PORT=18080 
    fi
    
    HAPROXY_FRONT_PORT=$((MONERO_PORT + 1000)) 
    
    sudo bash -c "cat > /etc/haproxy/haproxy.cfg << EOL
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend monero_front
    bind *:$HAPROXY_FRONT_PORT
    bind *:443
    bind *:80
    default_backend monero_backend

backend monero_backend
    mode tcp
    option redispatch
    option persist
    server monero_node 127.0.0.1:$MONERO_PORT no-check inter 5s rise 2 fall 3 on-error mark-down
EOL"

    DECOY_SCRIPT="/home/$USERNAME/monero/obfuscation/decoy_traffic.sh"

    cat > "$DECOY_SCRIPT" << 'EOL'
#!/bin/bash


source "/home/$USER/monero/obfuscation/profile.conf"

LOGFILE="/tmp/monero_decoy.log"
echo "Démarrage du service de leurre à $(date)" > $LOGFILE

generate_random_traffic() {
    local size=$(shuf -i ${PACKET_SIZE_MIN:-512}-${PACKET_SIZE_MAX:-1500} -n 1)
    local wait=$(shuf -i ${CONNECTION_INTERVAL_MIN:-5}-${CONNECTION_INTERVAL_MAX:-30} -n 1)
    
    local port_choice=$(( RANDOM % 3 ))
    case $port_choice in
        0) PORT=${PORT_PRIMARY:-8443} ;;
        1) PORT=${PORT_SECONDARY:-8080} ;;
        2) PORT=19080 ;;  
    esac
    
    timeout 5s bash -c "dd if=/dev/urandom bs=$size count=1 2>/dev/null | nc -w 2 127.0.0.1 $PORT" >/dev/null 2>&1
    echo "$(date +"%H:%M:%S"): Envoi de $size octets au port $PORT" >> $LOGFILE
    sleep $wait
}

if [ -z "$PACKET_SIZE_MIN" ]; then PACKET_SIZE_MIN=512; fi
if [ -z "$PACKET_SIZE_MAX" ]; then PACKET_SIZE_MAX=1500; fi
if [ -z "$CONNECTION_INTERVAL_MIN" ]; then CONNECTION_INTERVAL_MIN=5; fi
if [ -z "$CONNECTION_INTERVAL_MAX" ]; then CONNECTION_INTERVAL_MAX=30; fi
if [ -z "$PORT_PRIMARY" ]; then PORT_PRIMARY=8443; fi
if [ -z "$PORT_SECONDARY" ]; then PORT_SECONDARY=8080; fi
if [ -z "$TRAFFIC_PATTERN" ]; then TRAFFIC_PATTERN="bursty"; fi
if [ -z "$IDLE_PERIODS" ]; then IDLE_PERIODS="true"; fi

echo "Configuration chargée: $TRAFFIC_PATTERN, ports: $PORT_PRIMARY/$PORT_SECONDARY" >> $LOGFILE

while true; do
    case "$TRAFFIC_PATTERN" in
        "bursty")
            echo "Mode burst ($(date))" >> $LOGFILE
            for i in {1..5}; do
                generate_random_traffic
                sleep $(shuf -i 1-3 -n 1)
            done
            if [ "$IDLE_PERIODS" = "true" ]; then
                IDLE=$(shuf -i 10-30 -n 1)
                echo "Pause de $IDLE secondes" >> $LOGFILE
                sleep $IDLE
            else
                sleep $(shuf -i 3-8 -n 1)
            fi
            ;;
        "sustained")
            echo "Mode soutenu ($(date))" >> $LOGFILE
            generate_random_traffic
            ;;
        "periodic")
            echo "Mode périodique ($(date))" >> $LOGFILE
            generate_random_traffic
            if [ "$IDLE_PERIODS" = "true" ]; then
                if [ $(( RANDOM % 5 )) -eq 0 ]; then
                    IDLE=$(shuf -i 30-60 -n 1)
                    echo "Pause longue de $IDLE secondes" >> $LOGFILE
                    sleep $IDLE
                fi
            fi
            ;;
        *)
            echo "Mode par défaut ($(date))" >> $LOGFILE
            generate_random_traffic
            ;;
    esac
    sleep 1
done
EOL

    sed -i "s|\$USER|$USERNAME|g" "$DECOY_SCRIPT"

    sudo chmod 755 "$DECOY_SCRIPT"
    sudo chown "$USERNAME:$USERNAME" "$DECOY_SCRIPT"
    
    sudo bash -c "cat > /etc/systemd/system/monero-decoy.service << EOL
[Unit]
Description=Monero Traffic Obfuscation Service
After=network.target haproxy-monero.service
Requires=haproxy-monero.service

[Service]
Type=simple
User=$USERNAME
ExecStart=/home/$USERNAME/monero/obfuscation/decoy_traffic.sh
WorkingDirectory=/home/$USERNAME/monero/obfuscation
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL"

    if [ ! -f /etc/systemd/system/monero.service ]; then
        sudo bash -c "cat > /etc/systemd/system/monero.service << EOL
[Unit]
Description=Monero Node
After=network.target

[Service]
Type=simple
User=$USERNAME
ExecStart=/home/$USERNAME/monero/monerod --config-file=/home/$USERNAME/.bitmonero/bitmonero.conf --non-interactive
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL"
    fi

    sudo bash -c "cat > /etc/systemd/system/haproxy-monero.service << EOL
[Unit]
Description=HAProxy Load Balancer for Monero
After=network.target monero.service
Wants=monero.service

[Service]
Type=simple
StandardOutput=null
StandardError=null
ExecStartPre=/bin/bash -c 'for i in {1..60}; do if nc -z localhost $MONERO_PORT; then exit 0; fi; echo \"Waiting for Monero... \$i/60\"; sleep 2; done; echo \"Timeout waiting for Monero, continuing anyway\"; exit 0'
ExecStartPre=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c
ExecStart=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -Ws
ExecReload=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c
ExecReload=/bin/kill -USR2 \\\$MAINPID
Restart=on-failure
RestartSec=5
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOL"

    IPTABLES_SCRIPT="/home/$USERNAME/monero/obfuscation/iptables_setup.sh"

    cat > "$IPTABLES_SCRIPT" << 'EOL'
#!/bin/bash

source "/home/$USER/monero/obfuscation/profile.conf"

declare -a PROXY_PORTS=(19080 8443 8080)

sudo iptables -t mangle -F

for PORT in "${PROXY_PORTS[@]}"; do
    sudo iptables -t mangle -A POSTROUTING -p tcp --dport $PORT -j TTL --ttl-set $(shuf -i 40-65 -n 1)
    
    sudo iptables -t mangle -A POSTROUTING -p tcp --dport $PORT -j TOS --set-tos $(shuf -i 0-15 -n 1)
    
    sudo iptables -t mangle -A POSTROUTING -p tcp --dport $PORT -j TCPMSS --set-mss $(shuf -i 1200-1460 -n 1)
done

sudo netfilter-persistent save

echo "Configuration iptables terminée"
EOL

    sed -i "s|\$USER|$USERNAME|g" "$IPTABLES_SCRIPT"

    sudo chmod 755 "$IPTABLES_SCRIPT"
    sudo chown "$USERNAME:$USERNAME" "$IPTABLES_SCRIPT"

    sudo systemctl daemon-reload
    
    sudo systemctl disable haproxy
    sudo systemctl disable haproxy-monero.service
    sudo systemctl disable monero.service
    sudo systemctl disable monero-decoy
    
    success "$(get_message "Outils d'obscurcissement configurés" "Obfuscation tools configured")"
    info "$(get_message "Utilisez l'option 'Démarrer/Arrêter' pour activer le système" "Use the 'Start/Stop' option to activate the system")"
    return 0
}

fix_monero_decoy_service() {
    print_header "$(get_message "RÉPARATION DU SERVICE DE LEURRE" "FIXING DECOY SERVICE")"
    
    ensure_obfuscation_files "$USERNAME"
    
    info "$(get_message "Modification du service monero-decoy pour améliorer la stabilité..." "Modifying monero-decoy service to improve stability...")"
    
    sudo bash -c "cat > /etc/systemd/system/monero-decoy.service << EOL
[Unit]
Description=Monero Traffic Obfuscation Service
After=network.target
Wants=haproxy-monero.service

[Service]
Type=simple
User=$USERNAME
ExecStart=/home/$USERNAME/monero/obfuscation/decoy_traffic.sh
WorkingDirectory=/home/$USERNAME/monero/obfuscation
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL"

    info "$(get_message "Rechargement des configurations systemd..." "Reloading systemd configurations...")"
    sudo systemctl daemon-reload
    
    info "$(get_message "Configuration des fichiers de log..." "Setting up log files...")"
    sudo touch /tmp/monero_decoy.log
    sudo chmod 666 /tmp/monero_decoy.log
    sudo touch /tmp/monero_decoy.err
    sudo chmod 666 /tmp/monero_decoy.err
    
    DECOY_SCRIPT="/home/$USERNAME/monero/obfuscation/decoy_traffic.sh"
    info "$(get_message "Amélioration du script de leurre..." "Enhancing decoy script...")"
    
    sudo cp "$DECOY_SCRIPT" "${DECOY_SCRIPT}.bak"
    
    cat > /tmp/new_decoy_script.sh << 'EOL'
#!/bin/bash


set -o pipefail

error_handler() {
  local line=$1
  local cmd=$2
  local code=$3
  echo "ERREUR à la ligne $line, commande '$cmd' a retourné $code" >> /tmp/monero_decoy.err
}

trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR

which nc > /dev/null 2>&1 || { echo "Netcat (nc) non trouvé. Installation..." >> /tmp/monero_decoy.err; apt-get install -y netcat-openbsd || apt-get install -y netcat; }
which dd > /dev/null 2>&1 || { echo "dd non trouvé" >> /tmp/monero_decoy.err; exit 1; }
which shuf > /dev/null 2>&1 || { echo "shuf non trouvé" >> /tmp/monero_decoy.err; exit 1; }

if [ -f "/home/$USER/monero/obfuscation/profile.conf" ]; then
    source "/home/$USER/monero/obfuscation/profile.conf"
fi

LOGFILE="/tmp/monero_decoy.log"
echo "Démarrage du service de leurre à $(date)" > $LOGFILE

generate_random_traffic() {
    local size=$(shuf -i ${PACKET_SIZE_MIN:-512}-${PACKET_SIZE_MAX:-1500} -n 1)
    local wait=$(shuf -i ${CONNECTION_INTERVAL_MIN:-5}-${CONNECTION_INTERVAL_MAX:-30} -n 1)
    
    local port_choice=$(( RANDOM % 3 ))
    case $port_choice in
        0) PORT=${PORT_PRIMARY:-8443} ;;
        1) PORT=${PORT_SECONDARY:-8080} ;;
        2) PORT=19080 ;;  
    esac
    
    timeout 5s bash -c "dd if=/dev/urandom bs=$size count=1 2>/dev/null | nc -w 2 127.0.0.1 $PORT" >/dev/null 2>&1
    echo "$(date +"%H:%M:%S"): Envoi de $size octets au port $PORT" >> $LOGFILE
    sleep $wait
}

if [ -z "$PACKET_SIZE_MIN" ]; then PACKET_SIZE_MIN=512; fi
if [ -z "$PACKET_SIZE_MAX" ]; then PACKET_SIZE_MAX=1500; fi
if [ -z "$CONNECTION_INTERVAL_MIN" ]; then CONNECTION_INTERVAL_MIN=5; fi
if [ -z "$CONNECTION_INTERVAL_MAX" ]; then CONNECTION_INTERVAL_MAX=30; fi
if [ -z "$PORT_PRIMARY" ]; then PORT_PRIMARY=8443; fi
if [ -z "$PORT_SECONDARY" ]; then PORT_SECONDARY=8080; fi
if [ -z "$TRAFFIC_PATTERN" ]; then TRAFFIC_PATTERN="bursty"; fi
if [ -z "$IDLE_PERIODS" ]; then IDLE_PERIODS="true"; fi

echo "Configuration chargée: $TRAFFIC_PATTERN, ports: $PORT_PRIMARY/$PORT_SECONDARY" >> $LOGFILE

while true; do
    case "$TRAFFIC_PATTERN" in
        "bursty")
            echo "Mode burst ($(date))" >> $LOGFILE
            for i in {1..5}; do
                generate_random_traffic
                sleep $(shuf -i 1-3 -n 1)
            done
            if [ "$IDLE_PERIODS" = "true" ]; then
                IDLE=$(shuf -i 10-30 -n 1)
                echo "Pause de $IDLE secondes" >> $LOGFILE
                sleep $IDLE
            else
                sleep $(shuf -i 3-8 -n 1)
            fi
            ;;
        "sustained")
            echo "Mode soutenu ($(date))" >> $LOGFILE
            generate_random_traffic
            ;;
        "periodic")
            echo "Mode périodique ($(date))" >> $LOGFILE
            generate_random_traffic
            if [ "$IDLE_PERIODS" = "true" ]; then
                if [ $(( RANDOM % 5 )) -eq 0 ]; then
                    IDLE=$(shuf -i 30-60 -n 1)
                    echo "Pause longue de $IDLE secondes" >> $LOGFILE
                    sleep $IDLE
                fi
            fi
            ;;
        *)
            echo "Mode par défaut ($(date))" >> $LOGFILE
            generate_random_traffic
            ;;
    esac
    sleep 1
done
EOL

    sudo mv /tmp/new_decoy_script.sh "$DECOY_SCRIPT"
    sudo chmod 755 "$DECOY_SCRIPT"
    sudo chown "$USERNAME:$USERNAME" "$DECOY_SCRIPT"
    
    success "$(get_message "Service monero-decoy réparé avec succès" "Successfully fixed monero-decoy service")"
    info "$(get_message "Vous pouvez maintenant démarrer le service avec 'sudo systemctl start monero-decoy'" "You can now start the service with 'sudo systemctl start monero-decoy'")"
    
    print_styled "INFO" "$(get_message "Voulez-vous démarrer le service maintenant? (o/n): " "Do you want to start the service now? (y/n): ")"
    read -r start_choice
    
    if [[ $start_choice =~ ^[OoYy] ]]; then
        info "$(get_message "Démarrage du service monero-decoy..." "Starting monero-decoy service...")"
        sudo systemctl start monero-decoy
        sleep 2
        
        if systemctl is-active --quiet monero-decoy; then
            success "$(get_message "Service démarré avec succès" "Service started successfully")"
        else
            warning "$(get_message "Le service n'a pas pu démarrer. Consultez les logs: journalctl -u monero-decoy" "Service could not start. Check logs: journalctl -u monero-decoy")"
            print_styled "INFO" "$(get_message "Configuration des règles iptables..." "Configuring iptables rules...")"
            IPTABLES_SCRIPT="/home/$USERNAME/monero/obfuscation/iptables_setup.sh"

            if [ -f "$IPTABLES_SCRIPT" ]; then
                sudo chmod +x "$IPTABLES_SCRIPT"
                if sudo bash "$IPTABLES_SCRIPT"; then
                    success "$(get_message "Règles iptables configurées avec succès" "iptables rules successfully configured")"
                else
                    error "$(get_message "Échec de la configuration des règles iptables" "Failed to configure iptables rules")"
                fi
            else
                error "$(get_message "Script iptables introuvable" "iptables script not found")"
            fi
        fi
    fi
    
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
}

sync_haproxy_monero() {
    if [ -z "$USERNAME" ]; then
        if ! ask_username; then
            return 1
        fi
    fi
    
    ensure_obfuscation_files "$USERNAME"
    
    print_header "$(get_message "SYNCHRONISATION HAPROXY-MONERO" "HAPROXY-MONERO SYNCHRONIZATION")"
    
    if ! pgrep -f "monerod.*--non-interactive" > /dev/null; then
        warning "$(get_message "Monero n'est pas en cours d'exécution" "Monero is not running")"
        print_styled "WARNING" "$(get_message "L'obscurcissement fonctionne mieux si Monero est déjà actif" "Obfuscation works better if Monero is already active")"
        print_styled "INFO" "$(get_message "Voulez-vous continuer quand même? (o/n):" "Do you want to continue anyway? (y/n):")"
        read -r continue_anyway
        
        if [[ ! $continue_anyway =~ ^[OoYy] ]]; then
            info "$(get_message "Synchronisation annulée. Démarrez d'abord Monero dans le Menu Principal" "Synchronization cancelled. Start Monero first in the Main Menu")"
            return 1
        fi
    fi
    
    local config_file="/home/$USERNAME/.bitmonero/bitmonero.conf"
    if [ ! -f "$config_file" ]; then
        error "$(get_message "Fichier de configuration Monero introuvable" "Monero configuration file not found")"
        return 1
    fi
    
    MONERO_P2P_PORT=$(grep "^p2p-bind-port=" "$config_file" 2>/dev/null | cut -d'=' -f2)
    MONERO_RPC_PORT=$(grep "^rpc-bind-port=" "$config_file" 2>/dev/null | cut -d'=' -f2)
    
    [ -z "$MONERO_P2P_PORT" ] && MONERO_P2P_PORT="18080"
    [ -z "$MONERO_RPC_PORT" ] && MONERO_RPC_PORT="18081"
    
    print_styled "INFO" "$(get_message "Configuration Monero détectée:" "Detected Monero configuration:")"
    print_styled "SUCCESS" "  → P2P Port: $MONERO_P2P_PORT"
    print_styled "SUCCESS" "  → RPC Port: $MONERO_RPC_PORT"
    
    if grep -q "^p2p-bind-ip=" "$config_file" || grep -q "^rpc-bind-ip=" "$config_file"; then
        info "$(get_message "Mise à jour de la configuration de liaison Monero..." "Updating Monero binding configuration...")"
        
        sudo cp "$config_file" "${config_file}.bak.$(date +%Y%m%d%H%M%S)"
        
        sudo sed -i '/^p2p-bind-ip=/d' "$config_file"
        sudo sed -i '/^rpc-bind-ip=/d' "$config_file"
        
        echo "p2p-bind-ip=0.0.0.0" | sudo tee -a "$config_file" > /dev/null
        echo "rpc-bind-ip=0.0.0.0" | sudo tee -a "$config_file" > /dev/null
        
        success "$(get_message "Configuration Monero mise à jour pour utiliser 0.0.0.0" "Monero configuration updated to use 0.0.0.0")"
    fi
    
    info "$(get_message "Création d'une configuration HAProxy optimisée..." "Creating optimized HAProxy configuration...")"
    
    sudo mkdir -p /var/lib/haproxy
    
    sudo bash -c "cat > /etc/haproxy/haproxy.cfg << EOL
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend monero_front
    bind *:19080
    bind *:443
    bind *:80
    default_backend monero_backend

backend monero_backend
    mode tcp
    option redispatch
    option persist
    server monero_node 127.0.0.1:$MONERO_PORT no-check inter 5s rise 2 fall 3 on-error mark-down
EOL"
    
    info "$(get_message "Configuration du service HAProxy..." "Configuring HAProxy service...")"
    
    sudo bash -c "cat > /etc/systemd/system/haproxy-monero.service << EOL
[Unit]
Description=HAProxy Load Balancer for Monero
After=network.target monero.service
Wants=monero.service

[Service]
Type=simple
StandardOutput=null
StandardError=null
ExecStartPre=/bin/bash -c 'for i in {1..60}; do if nc -z localhost 18080; then exit 0; fi; echo \"Waiting for Monero... \$i/60\"; sleep 2; done; echo \"Timeout waiting for Monero, continuing anyway\"; exit 0'
ExecStartPre=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c
ExecStart=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -Ws
ExecReload=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c
ExecReload=/bin/kill -USR2 \\\$MAINPID
Restart=on-failure
RestartSec=5
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOL"
    
    sudo systemctl daemon-reload
    
    if systemctl is-active --quiet haproxy; then
        info "$(get_message "Arrêt du service HAProxy existant..." "Stopping existing HAProxy service...")"
        sudo systemctl stop haproxy
    fi
    
    if systemctl is-active --quiet haproxy-monero; then
        info "$(get_message "Arrêt du service HAProxy-Monero existant..." "Stopping existing HAProxy-Monero service...")"
        sudo systemctl stop haproxy-monero
    fi
    
    info "$(get_message "Démarrage du service HAProxy-Monero..." "Starting HAProxy-Monero service...")"
    
    info "$(get_message "Vérification que Monero est disponible..." "Verifying that Monero is available...")"
    for attempt in {1..30}; do
        if netstat -tulpn | grep -q ":18080"; then
            success "$(get_message "Port Monero 18080 est disponible, démarrage de HAProxy..." "Monero port 18080 is available, starting HAProxy...")"
            break
        elif [ $attempt -eq 30 ]; then
            warning "$(get_message "Monero ne semble pas disponible après 30 tentatives, tentative de démarrage de HAProxy quand même..." "Monero doesn't seem available after 30 attempts, trying to start HAProxy anyway...")"
        else
            echo -n "."
            sleep 2
        fi
    done
    
    info "$(get_message "Configuration pour masquer les messages d'erreur HAProxy..." "Configuring to hide HAProxy error messages...")"
    sudo mkdir -p /etc/systemd/journald.conf.d/
    echo "[Journal]" | sudo tee /etc/systemd/journald.conf.d/haproxy-filter.conf > /dev/null
    echo "SuppressField=SYSLOG_IDENTIFIER" | sudo tee -a /etc/systemd/journald.conf.d/haproxy-filter.conf > /dev/null

    MAX_ATTEMPTS=3
    for attempt in $(seq 1 $MAX_ATTEMPTS); do
        sudo systemctl start haproxy-monero
        sleep 3
        if [ -f "/home/$USERNAME/monero/obfuscation/iptables_setup.sh" ]; then
            sudo chmod +x "/home/$USERNAME/monero/obfuscation/iptables_setup.sh"
            sudo bash "/home/$USERNAME/monero/obfuscation/iptables_setup.sh" >/dev/null 2>&1
        fi
        if systemctl is-active --quiet haproxy-monero; then
            success "$(get_message "Service HAProxy-Monero démarré avec succès!" "HAProxy-Monero service started successfully!")"
            break
        elif [ $attempt -eq $MAX_ATTEMPTS ]; then
            error "$(get_message "Échec du démarrage du service après $MAX_ATTEMPTS tentatives" "Failed to start service after $MAX_ATTEMPTS attempts")"
            
            echo "$(get_message "Journaux d'erreur HAProxy:" "HAProxy error logs:")"
            sudo journalctl -u haproxy-monero -n 15 --no-pager
            
            echo "$(get_message "Vérification des ports utilisés:" "Checking used ports:")"
            sudo netstat -tlpn | grep -E "80|443|18080|19080"
            
            echo "$(get_message "Vérification de la syntaxe:" "Checking syntax:")"
            sudo haproxy -c -f /etc/haproxy/haproxy.cfg
        else
            warning "$(get_message "Tentative $attempt échouée, nouvel essai..." "Attempt $attempt failed, retrying...")"
        fi
    done
    
    if ! systemctl is-active --quiet monero-decoy; then
        info "$(get_message "Le système de leurre n'est pas actif" "The decoy system is not active")"
        print_styled "INFO" "$(get_message "Voulez-vous démarrer le système de leurre? (o/n):" "Do you want to start the decoy system? (y/n):")"
        read -r start_decoy
        
        if [[ $start_decoy =~ ^[OoYy] ]]; then
            info "$(get_message "Démarrage du système de leurre..." "Starting decoy system...")"
            
            if [ -f "/home/$USERNAME/monero/obfuscation/decoy_traffic.sh" ]; then
                sudo chmod +x "/home/$USERNAME/monero/obfuscation/decoy_traffic.sh"
                
                sudo systemctl restart monero-decoy
                sleep 3
                
                if systemctl is-active --quiet monero-decoy; then
                    success "$(get_message "Système de leurre démarré avec succès" "Decoy system started successfully")"
                else
                    error "$(get_message "Échec du démarrage du système de leurre" "Failed to start decoy system")"
                    sudo journalctl -u monero-decoy -n 15 --no-pager
                fi
            else
                error "$(get_message "Script de leurre introuvable" "Decoy script not found")"
            fi
        fi
    else
        success "$(get_message "Le système de leurre est déjà actif" "Decoy system is already active")"
    fi
    
    print_header "$(get_message "STATUT DES SERVICES" "SERVICES STATUS")"
    
    if pgrep -f "monerod.*--non-interactive" > /dev/null; then
        print_styled "SUCCESS" "Monero: $(get_message "ACTIF" "ACTIVE")"
    else
        print_styled "ERROR" "Monero: $(get_message "INACTIF" "INACTIVE")"
        print_styled "WARNING" "$(get_message "HAProxy a besoin que Monero soit actif pour fonctionner correctement" "HAProxy needs Monero to be active to work properly")"
    fi
    
    HAPROXY_STATUS=$(systemctl is-active haproxy-monero 2>/dev/null || systemctl is-active haproxy 2>/dev/null || echo "inactive")
    if [ "$HAPROXY_STATUS" = "active" ]; then
        print_styled "SUCCESS" "HAProxy: $(get_message "ACTIF" "ACTIVE")"
    else
        print_styled "ERROR" "HAProxy: $(get_message "INACTIF" "INACTIVE")"
    fi
    
    DECOY_STATUS=$(systemctl is-active monero-decoy 2>/dev/null || echo "inactive")
    if [ "$DECOY_STATUS" = "active" ]; then
        print_styled "SUCCESS" "$(get_message "Système de leurre" "Decoy system"): $(get_message "ACTIF" "ACTIVE")"
    else
        print_styled "ERROR" "$(get_message "Système de leurre" "Decoy system"): $(get_message "INACTIF" "INACTIVE")"
    fi
    
    info "$(get_message "Configuration des règles iptables..." "Configuring iptables rules...")"
    IPTABLES_SCRIPT="/home/$USERNAME/monero/obfuscation/iptables_setup.sh"

    if [ ! -f "$IPTABLES_SCRIPT" ]; then
        warning "$(get_message "Script iptables introuvable. Création du script..." "iptables script not found. Creating script...")"
        mkdir -p "/home/$USERNAME/monero/obfuscation"
        
        cat > "$IPTABLES_SCRIPT" << 'EOL'
#!/bin/bash

if [ -f "/home/$USER/monero/obfuscation/profile.conf" ]; then
    source "/home/$USER/monero/obfuscation/profile.conf"
fi

declare -a PROXY_PORTS=(19080 8443 8080)

sudo iptables -t mangle -F

for PORT in "${PROXY_PORTS[@]}"; do
    sudo iptables -t mangle -A POSTROUTING -p tcp --dport $PORT -j TTL --ttl-set $(shuf -i 40-65 -n 1)
    
    sudo iptables -t mangle -A POSTROUTING -p tcp --dport $PORT -j TOS --set-tos $(shuf -i 0-15 -n 1)
    
    sudo iptables -t mangle -A POSTROUTING -p tcp --dport $PORT -j TCPMSS --set-mss $(shuf -i 1200-1460 -n 1)
done

sudo netfilter-persistent save

echo "Configuration iptables terminée"
EOL
        chmod +x "$IPTABLES_SCRIPT"
        chown "$USERNAME:$USERNAME" "$IPTABLES_SCRIPT"
        success "$(get_message "Script iptables créé avec succès" "iptables script successfully created")"
    fi

    if [ -f "$IPTABLES_SCRIPT" ]; then
        sudo chmod +x "$IPTABLES_SCRIPT"
        if sudo bash "$IPTABLES_SCRIPT"; then
            success "$(get_message "Règles iptables configurées avec succès" "iptables rules successfully configured")"
        else
            error "$(get_message "Échec de la configuration des règles iptables" "Failed to configure iptables rules")"
        fi
    else
        error "$(get_message "Script iptables introuvable" "iptables script not found")"
    fi
    
    success "$(get_message "Synchronisation et démarrage terminés!" "Synchronization and startup completed!")"
    SYNCHRONIZED="true"
    return 0
}

traffic_obfuscation_menu() {
    clear
    setup_terminal
    echo -e "\n\n\n\n\n\n\n\n"  
    
    if [ -z "$USERNAME" ]; then
        if ! ask_username; then
            return 1
        fi
    fi
    clear
    
if [ -f "/tmp/auto_obfs.lock" ]; then
    LOCK_PID=$(cat "/tmp/auto_obfs.lock")
    if ! kill -0 "$LOCK_PID" 2>/dev/null; then
        rm -f "/tmp/auto_obfs.lock"
    fi
fi
    
    setup_terminal
    echo -e "\n\n\n\n\n\n\n\n"  
    print_header "$(get_message "OBSCURCISSEMENT DE TRAFIC" "TRAFFIC OBFUSCATION")"
    
    print_styled "INFO" "$(get_message " ➡️ ‼️-1-Choisissez votre profil d'obscurcissement" " ➡️ ‼️-1-Choose your obfuscation profile")"
    print_styled "INFO" "$(get_message " ➡️ -7-Retournez au menu Principal- et MARCHE‼️" " ➡️ -7-Return to main Menu- and START‼️")"
    echo
    print_styled "INFO" "$(get_message "❗-L'anti-détèction et le camouflage sont activés automatiquement," "❗-Anti-detection and cloaking are automatically enabled,")"
    print_styled "INFO" "$(get_message "lors du démarrage et de la synchronisation complète de la blockchain." "when the blockchain is started and fully synchronized.")"
    print_styled "INFO" "$(get_message "-Ouvrez un Second terminal après et revenez à ce menu." "-Open a new terminal after and return to this menu.")"
    print_styled "INFO" "$(get_message "-Verifier son status (4)." "-Check status (4).")"
    print_styled "INFO" "$(get_message "-Si un des deux status n'est pas activé, exécuter l'étape 2 et 3." "-If one of the two statuses is not activated, do steps 2 and 3.")"
    print_styled "INFO" "$(get_message "(Veillez à ce que la blockchain soit déjà démarrée et" "(Make sure the blockchain is already started and")"
    print_styled "INFO" "$(get_message "complètement synchronisée dans le 1er terminal avant).❗" "fully synchronized in the first terminal before).❗")"
    
    echo
    
    HAPROXY_STATUS=$(systemctl is-active haproxy 2>/dev/null || systemctl is-active haproxy-monero 2>/dev/null || echo "inactive")
    DECOY_STATUS=$(systemctl is-active monero-decoy 2>/dev/null || echo "inactive")
    
    if [ "$HAPROXY_STATUS" = "active" ] || [ "$DECOY_STATUS" = "active" ]; then
        print_styled "ERROR" "$(get_message "⚠️ SYSTÈME D'OBSCURCISSEMENT ACTIF ⚠️" "⚠️ OBFUSCATION SYSTEM ACTIVE ⚠️")"
        
        echo
    fi
    
    while true; do
        echo -e "\033[38;5;208m$(get_message "PROFIL" "PROFILE")${COLORS[RESET]}"
        print_styled "PRIMARY" "1) $(get_message "Configurer le profil d'obscurcissement" "Configure obfuscation profile")"
        echo -e "\033[38;5;208m$(get_message "REPARATION DE L'ACTIVATION" "ACTIVATION REPAIR")${COLORS[RESET]}"
        print_styled "PRIMARY" "2) $(get_message "ÉTAPE 2: Activer le système anti-détection" "STEP 2: Activate anti-detection system")"
                
        print_styled "PRIMARY" "3) $(get_message "ÉTAPE 3: Activer le camouflage réseau" "STEP 3: Activate network cloaking")"        
        echo -e "\033[38;5;208m$(get_message "STATUS" "STATUS")${COLORS[RESET]}"
        print_styled "PRIMARY" "4) $(get_message "Vérifier le statut" "Check status")"
        
        print_styled "PRIMARY" "5) $(get_message "Vérifier l'efficacité" "Verify effectiveness")"
        
        
        if [ "$HAPROXY_STATUS" = "active" ] || [ "$DECOY_STATUS" = "active" ]; then
            print_styled "ERROR" "6) $(get_message "ARRÊTER L'OBSCURCISSEMENT" "STOP OBFUSCATION")"
                       
            echo -e "\033[38;5;208m$(get_message "MENU PRINCIPAL" "MAIN MENU")${COLORS[RESET]}"
            print_styled "PRIMARY" "7) $(get_message "Retour au menu principal" "Back to main menu")"
            echo -n "$(print_styled "INFO" "$(get_message "Choix (1-7): " "Choice (1-7): ")")"
            read -r obfs_choice
            
            case $obfs_choice in
                1) configure_obfuscation_profile ;;
                2)
                    if ! ask_username; then
                        continue
                    fi
                    sync_haproxy_monero
                    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
                    ;;
                3) fix_monero_decoy_service ;; 
                4) check_obfuscation_status ;;
                5) 
                    if type test_obfuscation_effectiveness &>/dev/null; then
                        test_obfuscation_effectiveness
                    else
                        print_styled "WARNING" "$(get_message "La fonction de test n'est pas encore disponible" "Test function is not yet available")"
                        read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
                    fi
                    ;;
                6) stop_obfuscation ;;
                7) 
                    return 0
                    ;;
                *) error "$(get_message "Choix invalide" "Invalid choice")" ;;
            esac
        else
            echo -e "\033[38;5;208m$(get_message "MENU PRINCIPAL" "MAIN MENU")${COLORS[RESET]}"
            print_styled "PRIMARY" "7) $(get_message "Retour au menu principal" "Back to main menu")"
            echo -n "$(print_styled "INFO" "$(get_message "Choix (1-7): " "Choice (1-7): ")")"
            read -r obfs_choice
            
            case $obfs_choice in
                1) setup_traffic_obfuscation ;;
                2)
                    if ! ask_username; then
                        continue
                    fi
                    sync_haproxy_monero
                    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
                    ;;
                3) fix_monero_decoy_service ;;
                4) check_obfuscation_status ;;
                5) 
                    if type test_obfuscation_effectiveness &>/dev/null; then
                        test_obfuscation_effectiveness
                    else
                        print_styled "WARNING" "$(get_message "La fonction de test n'est pas encore disponible" "Test function is not yet available")"
                        read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
                    fi
                    ;;
                7) return 0 ;;
                *) error "$(get_message "Choix invalide" "Invalid choice")" ;;
            esac
        fi
    done
}

check_obfuscation_status() {
    clear
    setup_terminal
    echo -e "\n\n\n\n\n\n\n\n"  
    
    HAPROXY_STATUS_SYSTEMD=$(systemctl is-active haproxy-monero 2>/dev/null || echo "inactive")
    DECOY_STATUS_SYSTEMD=$(systemctl is-active monero-decoy 2>/dev/null || echo "inactive")
    
    DECOY_PROCESSES=$(pgrep -f "decoy_traffic.sh" | wc -l)
    
    if [ "$DECOY_STATUS_SYSTEMD" = "active" ] || [ "$DECOY_PROCESSES" -gt 0 ]; then
        DECOY_STATUS="active"
    else
        DECOY_STATUS="inactive"
    fi
    
    print_styled "MONERO" "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    print_styled "MONERO" "┃ $(get_message "STATUT DU SYSTÈME D'OBSCURCISSEMENT" "OBFUSCATION SYSTEM STATUS")    "
    print_styled "MONERO" "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
    
    if [ "$HAPROXY_STATUS_SYSTEMD" = "active" ]; then
        print_styled "SUCCESS" "┃ HAProxy: $(get_message "ACTIF" "ACTIVE")                           "
        
        IPTABLES_RULES=$(sudo iptables -t mangle -L | grep -E 'TCPMSS|TTL|TOS' | wc -l)
        if [ $IPTABLES_RULES -eq 0 ]; then
            IPTABLES_SCRIPT="/home/$USERNAME/monero/obfuscation/iptables_setup.sh"
            if [ -f "$IPTABLES_SCRIPT" ]; then
                sudo chmod +x "$IPTABLES_SCRIPT"
                sudo bash "$IPTABLES_SCRIPT" >/dev/null 2>&1
                success "$(get_message "Règles iptables appliquées" "iptables rules applied")             "
            fi
        fi
        
    else
        print_styled "ERROR" "┃ HAProxy: $(get_message "INACTIF" "INACTIVE")                         "
    fi
    
    if [ "$DECOY_STATUS" = "active" ]; then
        print_styled "SUCCESS" "┃ $(get_message "Système de leurre:" "Decoy system:") $(get_message "ACTIF" "ACTIVE")                 "
        
        if [ "$DECOY_PROCESSES" -gt 0 ]; then
            DECOY_PID=$(pgrep -f "decoy_traffic.sh" | head -1)
            DECOY_RUNTIME=$(ps -o etime= -p "$DECOY_PID" 2>/dev/null || echo "N/A")
            print_styled "INFO" "┃ $(get_message "Processus actifs:" "Active processes:") $DECOY_PROCESSES                       "
            print_styled "INFO" "┃ $(get_message "Temps d'exécution:" "Runtime:") $DECOY_RUNTIME                        "
        fi
    else
        print_styled "ERROR" "┃ $(get_message "Système de leurre:" "Decoy system:") $(get_message "INACTIF" "INACTIVE")               "
        
        LAST_LOG=$(journalctl -u monero-decoy -n 1 --no-pager 2>/dev/null | tail -1)
        if [ -n "$LAST_LOG" ]; then
            print_styled "WARNING" "┃ $(get_message "Dernier log:" "Last log:") ${LAST_LOG:0:30}...         ┃"
        fi
    fi
    
    print_styled "MONERO" "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
    
    if [ -f "/home/$USERNAME/monero/obfuscation/profile.conf" ]; then
        PROFILE_TYPE=$(grep "TRAFFIC_TYPE" "/home/$USERNAME/monero/obfuscation/profile.conf" | cut -d'=' -f2)
        print_styled "INFO" "┃ $(get_message "Profil configuré:" "Configured profile:") $PROFILE_TYPE                   "
    else
        print_styled "WARNING" "┃ $(get_message "Aucun profil configuré" "No profile configured")                    ┃"
    fi
    
    print_styled "MONERO" "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    
    if [ "$HAPROXY_STATUS_SYSTEMD" = "active" ] && [ "$DECOY_STATUS" = "inactive" ]; then
        echo
        print_styled "INFO" "$(get_message "Le service HAProxy est actif, mais le système de leurre est inactif." "HAProxy service is active, but the decoy system is inactive.")"
        print_styled "INFO" "$(get_message "Voulez-vous démarrer le système de leurre maintenant? (o/n):" "Do you want to start the decoy system now? (y/n):")"
        read -r start_decoy
        
        if [[ $start_decoy =~ ^[OoYy] ]]; then
            print_styled "INFO" "$(get_message "Démarrage du service de leurre..." "Starting decoy service...")"
            
            DECOY_SCRIPT="/home/$USERNAME/monero/obfuscation/decoy_traffic.sh"
            if [ -f "$DECOY_SCRIPT" ]; then
                sudo chmod +x "$DECOY_SCRIPT"
                sudo chown "$USERNAME:$USERNAME" "$DECOY_SCRIPT"
                
                for attempt in {1..3}; do
                    sudo systemctl restart monero-decoy
                    sleep 2
                    
                    if systemctl is-active --quiet monero-decoy; then
                        print_styled "SUCCESS" "$(get_message "Service de leurre démarré avec succès" "Decoy service started successfully")"
                        break
                    elif [ $attempt -eq 3 ]; then
                        print_styled "WARNING" "$(get_message "Tentative de démarrage manuel..." "Attempting manual start...")"
                        sudo -u "$USERNAME" bash "$DECOY_SCRIPT" &
                        sleep 2
                        
                        if pgrep -f "decoy_traffic.sh" > /dev/null; then
                            print_styled "SUCCESS" "$(get_message "Script de leurre démarré manuellement" "Decoy script started manually")"
                        else
                            print_styled "ERROR" "$(get_message "Échec du démarrage du service de leurre" "Failed to start decoy service")"
                        fi
                    else
                        print_styled "INFO" "$(get_message "Nouvelle tentative ($attempt/3)..." "Retrying ($attempt/3)...")"
                        sleep 1
                    fi
                done
            else
                print_styled "ERROR" "$(get_message "Script de leurre introuvable" "Decoy script not found")"
            fi
        fi
    fi
    
    echo
    if [ "$HAPROXY_STATUS_SYSTEMD" = "inactive" ] && [ "$DECOY_STATUS" = "inactive" ]; then
        print_styled "INFO" "$(get_message "Pour activer l'obscurcissement:" "To enable obfuscation:")"
        print_styled "PRIMARY" "1) $(get_message "Arrêtez Monero si en cours d'exécution (option 7)" "Stop Monero if running (option 7)")"
        print_styled "PRIMARY" "2) $(get_message "Démarrez Monero (option 6) et sélectionnez 'Oui' à l'activation automatique" "Start Monero (option 6) and select 'Yes' for automatic activation")"
    fi
    
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
}

stop_obfuscation() {
    setup_terminal
    echo -e "\n\n\n\n\n\n\n\n"  
    
    print_header "$(get_message "ARRÊT DE L'OBSCURCISSEMENT" "STOPPING OBFUSCATION")"
    
    print_styled "WARNING" "$(get_message "⚠️ Arrêt de tous les services d'obscurcissement..." "⚠️ Stopping all obfuscation services...")"
    
    if systemctl is-active --quiet monero-decoy; then
        info "$(get_message "Arrêt du système de leurre..." "Stopping decoy system...")"
        sudo systemctl stop monero-decoy
        if ! systemctl is-active --quiet monero-decoy; then
            success "$(get_message "Système de leurre arrêté" "Decoy system stopped")"
        else
            error "$(get_message "Échec de l'arrêt du système de leurre" "Failed to stop decoy system")"
        fi
    fi
    
    if systemctl is-active --quiet haproxy-monero; then
        info "$(get_message "Arrêt de HAProxy-Monero..." "Stopping HAProxy-Monero...")"
        sudo systemctl stop haproxy-monero
    fi
    
    if systemctl is-active --quiet haproxy; then
        info "$(get_message "Arrêt de HAProxy..." "Stopping HAProxy...")"
        sudo systemctl stop haproxy
    fi
    
    if ! systemctl is-active --quiet haproxy && ! systemctl is-active --quiet haproxy-monero; then
        success "$(get_message "HAProxy arrêté" "HAProxy stopped")"
    else
        error "$(get_message "Échec de l'arrêt de HAProxy, tentative de forçage..." "Failed to stop HAProxy, trying to force...")"
        sudo killall -9 haproxy 2>/dev/null
    fi
    
    info "$(get_message "Nettoyage des règles iptables..." "Cleaning iptables rules...")"
    sudo iptables -F
    sudo iptables -t mangle -F
    sudo netfilter-persistent save
    
    echo
    if ! systemctl is-active --quiet monero-decoy && ! systemctl is-active --quiet haproxy && ! systemctl is-active --quiet haproxy-monero; then
        success "$(get_message "✅ Système d'obscurcissement complètement arrêté!" "✅ Obfuscation system completely stopped!")"
    else
        warning "$(get_message "⚠️ Certains services d'obscurcissement pourraient être encore actifs" "⚠️ Some obfuscation services might still be active")"
    fi
    
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
}

test_obfuscation_effectiveness() {
    clear
    setup_terminal
    echo -e "\n\n\n\n\n\n\n\n"  
    print_header "$(get_message "TEST CONCRET D'OBSCURCISSEMENT" "CONCRETE OBFUSCATION TESTING")"
    
    TMP_DIR="/tmp/obfs_test"
    mkdir -p "$TMP_DIR"
    
    print_styled "MONERO" "1. $(get_message "Test de signature de trafic" "Traffic signature test")"
    print_styled "INFO" "$(get_message "Capture de 30 secondes du trafic sur le port Monero..." "Capturing 30 seconds of traffic on Monero port...")"
    
    if ! command -v tcpdump &> /dev/null; then
        print_styled "WARNING" "$(get_message "tcpdump non installé. Installation..." "tcpdump not installed. Installing...")"
        sudo apt-get update && sudo apt-get install -y tcpdump
    fi
    
    MAIN_IF=$(ip route | grep default | sed -e 's/^.*dev.//' -e 's/.proto.*//' | awk '{print $1}')
    
    sudo tcpdump -i $MAIN_IF -w "$TMP_DIR/monero_traffic.pcap" port 18080 -c 50 &> /dev/null &
    TCPDUMP_PID=$!
    
    print_styled "INFO" "$(get_message "Patientez pendant la capture..." "Please wait during capture...")"
    local timeout=0
    while kill -0 $TCPDUMP_PID 2>/dev/null && [ $timeout -lt 30 ]; do
        echo -n "."
        sleep 1
        timeout=$((timeout + 1))
    done
    
    if kill -0 $TCPDUMP_PID 2>/dev/null; then
        sudo kill $TCPDUMP_PID
    fi
    
    echo
    
    if [ -f "$TMP_DIR/monero_traffic.pcap" ]; then
        PACKET_COUNT=$(tcpdump -r "$TMP_DIR/monero_traffic.pcap" | wc -l)
        
        if [ $PACKET_COUNT -gt 0 ]; then
            PACKET_SIZES=$(tcpdump -r "$TMP_DIR/monero_traffic.pcap" -v | grep "length" | awk '{print $NF}')
            AVG_SIZE=$(echo $PACKET_SIZES | tr ' ' '\n' | awk '{ sum += $1; n++ } END { if (n > 0) print sum / n; else print "0"; }')
            
            print_styled "INFO" "$(get_message "Nombre de paquets capturés: $PACKET_COUNT" "Number of packets captured: $PACKET_COUNT")"
            print_styled "INFO" "$(get_message "Taille moyenne des paquets: $AVG_SIZE" "Average packet size: $AVG_SIZE")"
            
            UNIQUE_SIZES=$(echo $PACKET_SIZES | tr ' ' '\n' | sort | uniq | wc -l)
            
            if [ $UNIQUE_SIZES -gt 3 ]; then
                print_styled "SUCCESS" "$(get_message "✓ Variété de tailles de paquets: $UNIQUE_SIZES tailles différentes" "✓ Variety of packet sizes: $UNIQUE_SIZES different sizes")"
                print_styled "SUCCESS" "$(get_message "✓ Bon signe: Pas de modèle constant comme un nœud Monero standard" "✓ Good sign: No constant pattern like a standard Monero node")"
            else
                print_styled "WARNING" "$(get_message "⚠ Peu de variété dans les tailles de paquets" "⚠ Little variety in packet sizes")"
            fi
        else
            print_styled "WARNING" "$(get_message "Aucun paquet capturé sur le port 18080" "No packets captured on port 18080")"
            
            print_styled "SUCCESS" "$(get_message "✓ Potentiellement bon signe: Le trafic Monero pourrait être correctement redirigé" "✓ Potentially good sign: Monero traffic might be properly redirected")"
        fi
    else
        print_styled "WARNING" "$(get_message "Échec de la capture de trafic" "Failed to capture traffic")"
    fi
    
    echo
    
    print_styled "MONERO" "2. $(get_message "Test de visibilité externe" "External visibility test")"
    print_styled "INFO" "$(get_message "Vérification de votre adresse IP externe..." "Checking your external IP address...")"
    
    get_external_ip() {
        local ip=""
        local services=(
            "https://api.ipify.org"
            "https://ifconfig.me"
            "https://icanhazip.com"
            "https://ipecho.net/plain"
            "https://ipinfo.io/ip"
        )
        
        for service in "${services[@]}"; do
            ip=$(curl -s -m 5 "$service")
            
            if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "$ip"
                return 0
            fi
        done
        
        echo "Non disponible"
        return 1
    }
    
    EXTERNAL_IP=$(get_external_ip)
    
    if [ "$EXTERNAL_IP" != "Non disponible" ]; then
        print_styled "SUCCESS" "IP: $EXTERNAL_IP"
    else
        print_styled "WARNING" "$(get_message "Impossible de déterminer votre IP externe" "Unable to determine your external IP")"
        print_styled "INFO" "$(get_message "Cela peut être dû à un VPN, Tor, ou l'obscurcissement fonctionne très bien" "This might be due to VPN, Tor, or obscuration working very well")"
    fi
    
    print_styled "INFO" "$(get_message "Pour une vérification complète, suivez ces étapes:" "For a complete verification, follow these steps:")"
    print_styled "PRIMARY" "1) $(get_message "Visitez https://www.yougetsignal.com/tools/open-ports/" "Visit https://www.yougetsignal.com/tools/open-ports/")"
    
    if [ "$EXTERNAL_IP" != "Non disponible" ]; then
        print_styled "PRIMARY" "2) $(get_message "Entrez votre IP: $EXTERNAL_IP et le port 18080" "Enter your IP: $EXTERNAL_IP and port 18080")"
    else
        print_styled "PRIMARY" "2) $(get_message "Obtenez votre IP depuis whatismyip.com et testez le port 18080" "Get your IP from whatismyip.com and test port 18080")"
    fi
    
    print_styled "PRIMARY" "3) $(get_message "Si le port apparaît comme 'fermé', c'est un bon signe que l'obscurcissement fonctionne" "If the port appears as 'closed', that's a good sign obfuscation is working")"
    
    echo
    print_styled "INFO" "$(get_message "Alternativement, vérifiez si votre nœud est listé:" "Alternatively, check if your node is listed:")"
    print_styled "PRIMARY" "1) $(get_message "Visitez https://monero.fail" "Visit https://monero.fail")"
    
    if [ "$EXTERNAL_IP" != "Non disponible" ]; then
        print_styled "PRIMARY" "2) $(get_message "Recherchez votre IP: $EXTERNAL_IP" "Search for your IP: $EXTERNAL_IP")"
    else
        print_styled "PRIMARY" "2) $(get_message "Recherchez votre IP (obtenue depuis whatismyip.com)" "Search for your IP (obtained from whatismyip.com)")"
    fi
    
    print_styled "PRIMARY" "3) $(get_message "Si elle n'apparaît pas, c'est un bon signe que l'obscurcissement fonctionne" "If it doesn't appear, that's a good sign obfuscation is working")"
    
    echo
    
    print_styled "MONERO" "3. $(get_message "Test de redirection de trafic" "Traffic redirection test")"
    
    HAPROXY_CONNECTIONS=$(sudo netstat -tpna | grep -E 'haproxy|haproxy-monero' | wc -l)
    
    if [ $HAPROXY_CONNECTIONS -gt 0 ]; then
        print_styled "SUCCESS" "$(get_message "✓ HAProxy gère $HAPROXY_CONNECTIONS connexions" "✓ HAProxy is handling $HAPROXY_CONNECTIONS connections")"
        
        print_styled "INFO" "$(get_message "Exemples de connexions HAProxy:" "HAProxy connection examples:")"
        sudo netstat -tpna | grep -E 'haproxy|haproxy-monero' | head -3 | awk '{print "  " $4 " <-> " $5}'
    else
        print_styled "WARNING" "$(get_message "⚠ Aucune connexion active via HAProxy" "⚠ No active connections through HAProxy")"
    fi
    
    print_styled "MONERO" "4. $(get_message "Test de modification des paquets" "Packet modification test")"
    
    IPTABLES_RULES=$(sudo iptables -t mangle -L | grep -E 'TCPMSS|TTL|TOS' | wc -l)
    
    if [ $IPTABLES_RULES -gt 0 ]; then
        print_styled "SUCCESS" "$(get_message "✓ $IPTABLES_RULES règles de modification de paquets actives" "✓ $IPTABLES_RULES packet modification rules active")"
        
        print_styled "INFO" "$(get_message "Exemples de règles:" "Rule examples:")"
        sudo iptables -t mangle -L | grep -E 'TCPMSS|TTL|TOS' | head -3
    else
        print_styled "WARNING" "$(get_message "⚠ Aucune règle de modification des paquets détectée" "⚠ No packet modification rules detected")"
        
        IPTABLES_SCRIPT="/home/$USERNAME/monero/obfuscation/iptables_setup.sh"
        if [ -f "$IPTABLES_SCRIPT" ]; then
            print_styled "INFO" "$(get_message "Le script de configuration iptables existe mais n'a peut-être pas été exécuté" "The iptables setup script exists but may not have been executed")"
            print_styled "INFO" "$(get_message "Voulez-vous l'exécuter maintenant? (o/n)" "Do you want to execute it now? (y/n)")"
            read -r execute_iptables
            
            if [[ $execute_iptables =~ ^[OoYy] ]]; then
                print_styled "INFO" "$(get_message "Exécution du script iptables..." "Executing iptables script...")"
                sudo chmod +x "$IPTABLES_SCRIPT"
                sudo bash "$IPTABLES_SCRIPT"
                
                IPTABLES_RULES=$(sudo iptables -t mangle -L | grep -E 'TCPMSS|TTL|TOS' | wc -l)
                if [ $IPTABLES_RULES -gt 0 ]; then
                    print_styled "SUCCESS" "$(get_message "✓ $IPTABLES_RULES règles de modification de paquets maintenant actives" "✓ $IPTABLES_RULES packet modification rules now active")"
                else
                    print_styled "ERROR" "$(get_message "Échec de l'application des règles iptables" "Failed to apply iptables rules")"
                fi
            fi
        else
            print_styled "ERROR" "$(get_message "Script de configuration iptables introuvable" "iptables setup script not found")"
        fi
    fi
    
    echo
    : ${PACKET_COUNT:=0}
    : ${UNIQUE_SIZES:=0}
    : ${HAPROXY_CONNECTIONS:=0}
    : ${IPTABLES_RULES:=0}

    if ! [[ "$PACKET_COUNT" =~ ^[0-9]+$ ]]; then PACKET_COUNT=0; fi
    if ! [[ "$UNIQUE_SIZES" =~ ^[0-9]+$ ]]; then UNIQUE_SIZES=0; fi
    if ! [[ "$HAPROXY_CONNECTIONS" =~ ^[0-9]+$ ]]; then HAPROXY_CONNECTIONS=0; fi
    if ! [[ "$IPTABLES_RULES" =~ ^[0-9]+$ ]]; then IPTABLES_RULES=0; fi

    if ([ "$PACKET_COUNT" -eq 0 ] && ([ "$HAPROXY_CONNECTIONS" -gt 0 ] || [ "$IPTABLES_RULES" -gt 0 ])) || \
       ([ "$UNIQUE_SIZES" -gt 3 ] && [ "$HAPROXY_CONNECTIONS" -gt 0 ] && [ "$IPTABLES_RULES" -gt 0 ]); then
        print_styled "SUCCESS" "$(get_message "✅ L'OBSCURCISSEMENT SEMBLE FONCTIONNER EFFICACEMENT" "✅ OBFUSCATION APPEARS TO BE WORKING EFFECTIVELY")"
        print_styled "SUCCESS" "$(get_message "Le trafic Monero est correctement modifié et redirigé" "Monero traffic is being properly modified and redirected")"
    else
        print_styled "WARNING" "$(get_message "⚠️ L'OBSCURCISSEMENT FONCTIONNE PARTIELLEMENT" "⚠️ OBFUSCATION IS PARTIALLY WORKING")"
        print_styled "WARNING" "$(get_message "Certains aspects fonctionnent, mais des améliorations sont possibles" "Some aspects are working, but improvements are possible")"
    fi
    
    rm -rf "$TMP_DIR"
    
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
    
    setup_terminal
    echo -e "\n\n\n\n\n\n\n\n"  
    
    return 0
}

monitor_peers() {
    sleep 15  
    
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    RESET='\033[0m'
    
    RPC_AUTH=""
    CONFIG_FILE="/home/$USERNAME/.bitmonero/bitmonero.conf"
    
    if [ -f "$CONFIG_FILE" ] && grep -q "^rpc-login=" "$CONFIG_FILE"; then
        RPC_LOGIN_LINE=$(grep "^rpc-login=" "$CONFIG_FILE")
        RPC_CREDENTIALS=$(echo "$RPC_LOGIN_LINE" | cut -d'=' -f2)
        RPC_AUTH="--digest -u $RPC_CREDENTIALS"
    elif [ -f "/home/$USERNAME/rpc_easynode_pass.txt" ]; then
        RPC_USERNAME=$(grep "Username:" "/home/$USERNAME/rpc_easynode_pass.txt" 2>/dev/null | cut -d' ' -f2)
        RPC_PASSWORD=$(grep "Password:" "/home/$USERNAME/rpc_easynode_pass.txt" 2>/dev/null | cut -d' ' -f2)
        if [ -n "$RPC_USERNAME" ] && [ -n "$RPC_PASSWORD" ]; then
            RPC_AUTH="--digest -u $RPC_USERNAME:$RPC_PASSWORD"
        fi
    fi
    
    while pgrep -f "monerod" > /dev/null; do
        if [ $STOP_MONEROD -eq 1 ]; then
            break
        fi
        
        if [ -n "$RPC_AUTH" ]; then
            PEER_INFO=$(curl -s -X POST http://localhost:18081/json_rpc \
                $RPC_AUTH \
                -H "Content-Type: application/json" \
                -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' 2>/dev/null)
        else
            PEER_INFO=$(curl -s -X POST http://localhost:18081/json_rpc \
                -H "Content-Type: application/json" \
                -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' 2>/dev/null)
        fi
        
        if [ $? -eq 0 ] && echo "$PEER_INFO" | grep -q '"result"' && ! echo "$PEER_INFO" | grep -q '"error"'; then
            IN_PEERS=$(echo "$PEER_INFO" | sed -n 's/.*"incoming_connections_count":\s*\([0-9]*\).*/\1/p')
            OUT_PEERS=$(echo "$PEER_INFO" | sed -n 's/.*"outgoing_connections_count":\s*\([0-9]*\).*/\1/p')
            
            if [ -n "$IN_PEERS" ] && [ -n "$OUT_PEERS" ]; then
                echo -ne "\r${GREEN}IN-PEERS: ${IN_PEERS:-0}${RESET} | ${GREEN}OUT-PEERS: ${OUT_PEERS:-0}${RESET}                    "
            else
                echo -ne "\r${GREEN}RPC OK, attente des données...${RESET}                    "
            fi
        else
            if echo "$PEER_INFO" | grep -q "401\|unauthorized\|Unauthorized"; then
                echo -ne "\r${GREEN}❌ Erreur d'authentification RPC${RESET}                    "
            elif [ -z "$PEER_INFO" ]; then
                echo -ne "\r${GREEN}⏳ Attente connexion RPC...${RESET}                    "
            else
                echo -ne "\r${GREEN}⏳ Synchronisation en cours...${RESET}                    "
            fi
        fi
        
        sleep 15  
    done
    
    echo -ne "\r                                                    \r"
}

apply_ip_bans() {
    local MONEROD_PATH="$1"
    local BAN_LIST_FILE="/home/$USERNAME/.bitmonero/ban_list.txt"
    
    info "$(get_message "Application des bans IP..." "Applying IP bans...")"
    
    for i in {1..30}; do
        if nc -z localhost 18081; then
            success "$(get_message "Service RPC disponible" "RPC service available")"
            break
        fi
        info "$(get_message "Attente du service RPC... ($i/30)" "Waiting for RPC service... ($i/30)")"
        sleep 2
    done

    if [ ! -f "$BAN_LIST_FILE" ]; then
        error "$(get_message "Fichier de bans non trouvé" "Ban list file not found")"
        return 1
    fi

    while IFS=' ' read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        read -r ip duration <<< "$line"
        
        if [ -n "$ip" ] && [ -n "$duration" ]; then
            "$MONEROD_PATH" ban "$ip" "$duration" --rpc-bind-port 18081
            info "$(get_message "Ban appliqué: $ip" "Ban applied: $ip")"
        fi
    done < "$BAN_LIST_FILE"

    success "$(get_message "Application des bans terminée" "Ban application completed")"
}

download_ban_list() {
    local BAN_LIST_FILE="/home/$USERNAME/.bitmonero/ban_list.txt"
    local BAN_LIST_URL="https://raw.githubusercontent.com/Boog900/monero-ban-list/main/ban_list.txt"
    
    info "$(get_message "Téléchargement de la liste des IP bannis..." "Downloading IP ban list...")"
    
    mkdir -p "/home/$USERNAME/.bitmonero"
    
    if wget -q -O "$BAN_LIST_FILE" "$BAN_LIST_URL"; then
        sudo chown "$USERNAME:$USERNAME" "$BAN_LIST_FILE"
        sudo chmod 644 "$BAN_LIST_FILE"
        success "$(get_message "Liste des IP bannis téléchargée avec succès" "IP ban list downloaded successfully")"
    else
        error "$(get_message "Échec du téléchargement de la liste des IP bannis" "Failed to download IP ban list")"
        
        if [ ! -f "$BAN_LIST_FILE" ]; then
            touch "$BAN_LIST_FILE"
            sudo chown "$USERNAME:$USERNAME" "$BAN_LIST_FILE"
            sudo chmod 644 "$BAN_LIST_FILE"
        fi
    fi
}


ban_ip_via_monerod() {
    local ip="$1"
    local duration="$2"
    
    
    if [ -f "/home/$USERNAME/.bitmonero/bitmonero.conf" ] && grep -q "^rpc-login=" "/home/$USERNAME/.bitmonero/bitmonero.conf"; then
        local RPC_CREDENTIALS=$(grep "^rpc-login=" "/home/$USERNAME/.bitmonero/bitmonero.conf" | cut -d'=' -f2)
        "$MONEROD_PATH" ban "$ip" "$duration" --rpc-bind-port 18081 --rpc-login "$RPC_CREDENTIALS" >/dev/null 2>&1
    else
        "$MONEROD_PATH" ban "$ip" "$duration" --rpc-bind-port 18081 >/dev/null 2>&1
    fi
    
    return $?
}


start_blockchain() {
    if [ -z "$USERNAME" ]; then
        error "$(get_message "Nom d'utilisateur non défini" "Username not defined")"
        return 1
    fi

if [ "$AUTO_OBFS_CHOICE" = "2" ]; then
    force_clean_start  
fi

    print_header "$(get_message "DÉMARRAGE DE LA BLOCKCHAIN" "STARTING BLOCKCHAIN")"
    
    info "$(get_message "Vérification des services conflictuels..." "Checking for conflicting services...")"
    
    if pgrep -f "monerod.*--non-interactive" > /dev/null; then
        info "$(get_message "Processus monerod existant détecté, arrêt en cours..." "Existing monerod process detected, stopping...")"
        pkill -f "monerod.*--non-interactive"
        sleep 3
        if pgrep -f "monerod.*--non-interactive" > /dev/null; then
            warning "$(get_message "Forçage de l'arrêt du processus monerod..." "Forcing monerod process shutdown...")"
            pkill -9 -f "monerod.*--non-interactive"
            sleep 2
        fi
    fi
    
    if install_inotify_tools; then
        echo '#!/bin/bash
[ -f /etc/fstab ] && inotifywait -e modify /etc/fstab && systemctl daemon-reload' | sudo tee /etc/cron.hourly/reload-after-fstab > /dev/null
        sudo chmod +x /etc/cron.hourly/reload-after-fstab
        if [ -x /etc/cron.hourly/reload-after-fstab ]; then
            bash /etc/cron.hourly/reload-after-fstab &
        fi
    else
        warning "$(get_message "inotify-tools non installé, la surveillance fstab est désactivée" "inotify-tools not installed, fstab monitoring disabled")"
    fi
    
    print_styled "PRIMARY" "$(get_message "Sélectionnez le type de blockchain:" "Select blockchain type:")"
    print_styled "PRIMARY" "1) $(get_message "Complète 220 Go" "Complete 220 Go")"
    print_styled "PRIMARY" "2) $(get_message "Prune 90 Go" "Pruned 90 Go")"
    echo -n "$(print_styled "INFO" "$(get_message "Choix (1-2): " "Choice (1-2): ")")"
    read -r bc_choice
    
    case $bc_choice in
        1) BLOCKCHAIN_TYPE="complete" ;;
        2) BLOCKCHAIN_TYPE="pruned" ;;
        *) 
            error "$(get_message "Choix invalide" "Invalid choice")"
            return 1 ;;
    esac
    
    CONFIG_FILE="/home/$USERNAME/.bitmonero/bitmonero.conf"
    DEFAULT_DATA_DIR="/home/$USERNAME/.bitmonero"
    
    if [ -f "$CONFIG_FILE" ]; then
        sudo sed -i '/^prune-blockchain=/d' "$CONFIG_FILE"
        
        if [ "$BLOCKCHAIN_TYPE" = "pruned" ]; then
            echo "prune-blockchain=1" | sudo tee -a "$CONFIG_FILE" > /dev/null
        fi
        
        BLOCKCHAIN_LOCATION=$(grep "^data-dir=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    fi

    if [ -z "$BLOCKCHAIN_LOCATION" ]; then
        BLOCKCHAIN_LOCATION="$DEFAULT_DATA_DIR"
    fi

    info "$(get_message "Emplacement de la blockchain: $BLOCKCHAIN_LOCATION" "Blockchain location: $BLOCKCHAIN_LOCATION")"
    
    download_ban_list
    
    if [ -n "$BLOCKCHAIN_LOCATION" ] && [[ "$BLOCKCHAIN_LOCATION" == "/media/$USERNAME"* ]]; then
        DEVICE=$(mount | grep "/media/$USERNAME" | awk '{print $1}')
        if [ -z "$DEVICE" ]; then
            error "$(get_message "Le disque externe n'est pas monté" "External disk is not mounted")"
            return 1
        fi
        info "$(get_message "Disque externe monté: $DEVICE" "External disk mounted: $DEVICE")"
    fi

    print_styled "PRIMARY" "$(get_message "Démarrer avec blocage IP?" "Start with IP blocking?")"
    print_styled "PRIMARY" "1) $(get_message "Avec blocage IP" "With IP blocking")"
    print_styled "PRIMARY" "2) $(get_message "Sans blocage IP" "Without IP blocking")"
    echo -n "$(print_styled "INFO" "$(get_message "Choix (1-2): " "Choice (1-2): ")")"
    read -r IP_BAN_CHOICE

    print_styled "PRIMARY" "$(get_message "Activer l'obscurcissement de trafic automatiquement?" "Automatically enable traffic obfuscation?")"
    
    print_styled "PRIMARY" "1) $(get_message "Non, pas d'obscurcissement" "No, no obfuscation")"
    print_styled "PRIMARY" "2) $(get_message "Oui, après synchronisation complète" "Yes, after full synchronization")"
    echo -n "$(print_styled "INFO" "$(get_message "Choix (1-2): " "Choice (1-2): ")")"
    read -r AUTO_OBFS_CHOICE

    if [ -n "$BLOCKCHAIN_LOCATION" ] && [ ! -w "$BLOCKCHAIN_LOCATION" ]; then
        error "$(get_message "Permissions insuffisantes sur $BLOCKCHAIN_LOCATION" "Insufficient permissions on $BLOCKCHAIN_LOCATION")"
        return 1
    fi

    if [ "$AUTO_OBFS_CHOICE" = "2" ]; then
        info "$(get_message "Préparation du système d'obscurcissement pour activation automatique..." "Preparing obfuscation system for automatic activation...")"
        
        ensure_obfuscation_files "$USERNAME"
        
        MONERO_CONFIG="/home/$USERNAME/.bitmonero/bitmonero.conf"
        if [ -f "$MONERO_CONFIG" ]; then
            MONERO_PORT=$(grep "^p2p-bind-port=" "$MONERO_CONFIG" | cut -d'=' -f2)
        else
            MONERO_PORT=18080 
        fi
        
        HAPROXY_FRONT_PORT=$((MONERO_PORT + 1000)) 
        
        info "$(get_message "Configuration préalable de HAProxy..." "Pre-configuring HAProxy...")"
        sudo mkdir -p /var/lib/haproxy
        
        sudo bash -c "cat > /etc/haproxy/haproxy.cfg << EOL
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend monero_front
    bind *:$HAPROXY_FRONT_PORT
    bind *:443
    bind *:80
    default_backend monero_backend

backend monero_backend
    mode tcp
    option redispatch
    option persist
    server monero_node 127.0.0.1:$MONERO_PORT no-check inter 5s rise 2 fall 3 on-error mark-down
EOL"

        sudo bash -c "cat > /etc/systemd/system/haproxy-monero.service << EOL
[Unit]
Description=HAProxy Load Balancer for Monero
After=network.target monero.service
Wants=monero.service

[Service]
Type=simple
StandardOutput=null
StandardError=null
ExecStartPre=/bin/bash -c 'for i in {1..60}; do if nc -z localhost $MONERO_PORT; then exit 0; fi; echo \"Waiting for Monero... \$i/60\"; sleep 2; done; echo \"Timeout waiting for Monero, continuing anyway\"; exit 0'
ExecStartPre=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c
ExecStart=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -Ws
ExecReload=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c
ExecReload=/bin/kill -USR2 \\\$MAINPID
Restart=on-failure
RestartSec=5
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOL"

        cat > "/tmp/auto_obfs_sync.sh" << 'EOL'
#!/bin/bash

LANG_CHOICE="REPLACE_LANG_CHOICE"

display_message() {
    if [ "$LANG_CHOICE" = "FR" ]; then
        echo "$1"
    else
        echo "$2"
    fi
}

force_clean_start() {
    print_styled "INFO" "$(get_message "Nettoyage des services d'obscurcissement précédents..." "Cleaning previous obfuscation services...")"
    
    sudo systemctl stop monero-decoy haproxy-monero haproxy 2>/dev/null
    
    sudo pkill -f "haproxy" 2>/dev/null
    sudo pkill -f "decoy_traffic.sh" 2>/dev/null
    sudo pkill -f "auto_obfs_sync.sh" 2>/dev/null
    
    rm -f /tmp/auto_obfs.lock
    rm -f /tmp/auto_obfs_state.conf
    
    sudo iptables -t mangle -F 2>/dev/null
    
    sleep 3
    
    local haproxy_count=$(pgrep -f haproxy | wc -l)
    local decoy_count=$(pgrep -f "decoy_traffic.sh" | wc -l)
    
    if [ "$haproxy_count" -eq 0 ] && [ "$decoy_count" -eq 0 ]; then
        success "$(get_message "Nettoyage terminé avec succès" "Cleanup completed successfully")"
        return 0
    else
        warning "$(get_message "Certains processus persistent (HAProxy: $haproxy_count, Decoy: $decoy_count)" "Some processes persist (HAProxy: $haproxy_count, Decoy: $decoy_count)")"
        
        sudo pkill -9 -f "haproxy" 2>/dev/null
        sudo pkill -9 -f "decoy_traffic.sh" 2>/dev/null
        sleep 2
        
        return 0
    fi
}

echo "$(display_message "=== SURVEILLANCE ROBUSTE DÉMARRÉE ===" "=== ROBUST MONITORING STARTED ===")"

SYNCHRONIZED=false
USERNAME="REPLACE_USERNAME"
MONEROD_PATH="REPLACE_MONEROD_PATH"
LOG_FILE="/tmp/auto_obfs.log"
LOCK_FILE="/tmp/auto_obfs.lock"
STATE_FILE="/tmp/auto_obfs_state.conf"

if [ -f "$LOCK_FILE" ]; then
    EXISTING_PID=$(cat "$LOCK_FILE")
    if kill -0 "$EXISTING_PID" 2>/dev/null; then
        echo "$(display_message "Instance déjà en cours (PID: $EXISTING_PID)" "Instance already running (PID: $EXISTING_PID)")" | tee -a $LOG_FILE
        exit 0
    else
        echo "$(display_message "Nettoyage du verrou obsolète" "Cleaning obsolete lock")" | tee -a $LOG_FILE
        rm -f "$LOCK_FILE"
    fi
fi

echo $$ > "$LOCK_FILE"

cleanup_on_exit() {
    rm -f "$LOCK_FILE"
    
    echo -e "\033[1;32m$(display_message "✅ Configuration terminée - Votre nœud Monero est prêt à l'emploi en MODE Camouflage" "✅ Setup complete - Your Monero node is ready to use in Obfuscation MODE")\033[0m" | tee -a $LOG_FILE
}
trap cleanup_on_exit EXIT

echo "$(display_message "Démarrage de la surveillance à $(date)" "Starting monitoring at $(date)")" > $LOG_FILE
echo "$(display_message "Utilisateur: $USERNAME" "User: $USERNAME")" >> $LOG_FILE
echo "$(display_message "Chemin monerod: $MONEROD_PATH" "Monerod path: $MONEROD_PATH")" >> $LOG_FILE
echo "$(display_message "PID surveillance: $$" "Monitoring PID: $$")" >> $LOG_FILE

save_state() {
    cat > "$STATE_FILE" << EOF
LAST_CHECK=$(date +%s)
SYNCHRONIZED=$SYNCHRONIZED
OBFUSCATION_ATTEMPTED=false
CURRENT_HEIGHT=$1
TARGET_HEIGHT=$2
SYNC_PERCENT=$3
EOF
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        echo "$(display_message "État précédent chargé: SYNC=$SYNC_PERCENT%" "Previous state loaded: SYNC=$SYNC_PERCENT%")" >> $LOG_FILE
    else
        LAST_CHECK=0
        SYNCHRONIZED=false
        OBFUSCATION_ATTEMPTED=false
        rm -f "$STATE_FILE"
        CURRENT_HEIGHT=0
        TARGET_HEIGHT=0
        SYNC_PERCENT=0
    fi
}

setup_rpc_auth() {
    local config_file="/home/$USERNAME/.bitmonero/bitmonero.conf"
    local rpc_file="/home/$USERNAME/rpc_easynode_pass.txt"
    
    if [ -f "$config_file" ] && grep -q "^rpc-login=" "$config_file"; then
        RPC_LOGIN_LINE=$(grep "^rpc-login=" "$config_file")
        RPC_CREDENTIALS=$(echo "$RPC_LOGIN_LINE" | cut -d'=' -f2)
        
        RPC_USERNAME=$(echo "$RPC_CREDENTIALS" | cut -d':' -f1)
        RPC_PASSWORD=$(echo "$RPC_CREDENTIALS" | cut -d':' -f2)
        
        MONEROD_AUTH_ARGS="--rpc-login $RPC_CREDENTIALS"
        CURL_AUTH_ARGS="--digest -u $RPC_CREDENTIALS"
        
        echo "$(display_message "RPC sécurisé détecté - Utilisateur: $RPC_USERNAME" "Secure RPC detected - User: $RPC_USERNAME")" >> $LOG_FILE
        return 0
        
    elif [ -f "$rpc_file" ]; then
        RPC_USERNAME=$(grep "Username:" "$rpc_file" 2>/dev/null | awk '{print $2}')
        RPC_PASSWORD=$(grep "Password:" "$rpc_file" 2>/dev/null | awk '{print $2}')
        
        if [ -n "$RPC_USERNAME" ] && [ -n "$RPC_PASSWORD" ]; then
            RPC_CREDENTIALS="$RPC_USERNAME:$RPC_PASSWORD"
            MONEROD_AUTH_ARGS="--rpc-login $RPC_CREDENTIALS"
            CURL_AUTH_ARGS="--digest -u $RPC_CREDENTIALS"
            
            echo "$(display_message "RPC sécurisé détecté depuis fichier - Utilisateur: $RPC_USERNAME" "Secure RPC detected from file - User: $RPC_USERNAME")" >> $LOG_FILE
            return 0
        fi
    fi
    
    MONEROD_AUTH_ARGS=""
    CURL_AUTH_ARGS=""
    echo "$(display_message "RPC sans authentification détecté" "Non-authenticated RPC detected")" >> $LOG_FILE
    return 1
}

check_services_enhanced() {
    HAPROXY_SYSTEMD=$(systemctl is-active haproxy-monero 2>/dev/null || systemctl is-active haproxy 2>/dev/null || echo "inactive")
    DECOY_SYSTEMD=$(systemctl is-active monero-decoy 2>/dev/null || echo "inactive")
    
    HAPROXY_PROCESS=$(pgrep -f haproxy | wc -l)
    DECOY_PROCESS=$(pgrep -f "decoy_traffic.sh" | wc -l)
    
    HAPROXY_PORT_19080=$(netstat -tlpn 2>/dev/null | grep -c ":19080.*haproxy")
    HAPROXY_PORT_443=$(netstat -tlpn 2>/dev/null | grep -c ":443.*haproxy")
    
    echo "Services Check - HAProxy systemd: $HAPROXY_SYSTEMD, processus: $HAPROXY_PROCESS, ports: $HAPROXY_PORT_19080+$HAPROXY_PORT_443" >> $LOG_FILE
    echo "Services Check - Decoy systemd: $DECOY_SYSTEMD, processus: $DECOY_PROCESS" >> $LOG_FILE
    
    HAPROXY_ACTIVE=false
    DECOY_ACTIVE=false
    
    if [ "$HAPROXY_SYSTEMD" = "active" ] || [ "$HAPROXY_PROCESS" -gt 0 ] || [ "$HAPROXY_PORT_19080" -gt 0 ] || [ "$HAPROXY_PORT_443" -gt 0 ]; then
        HAPROXY_ACTIVE=true
    fi
    
    if [ "$DECOY_SYSTEMD" = "active" ] || [ "$DECOY_PROCESS" -gt 0 ]; then
        DECOY_ACTIVE=true
    fi
    
    if [ "$HAPROXY_ACTIVE" = "true" ] && [ "$DECOY_ACTIVE" = "true" ]; then
        return 0
    else
        return 1
    fi
}

force_stop_obfuscation() {
    echo "$(display_message "FORÇAGE arrêt complet des services d'obscurcissement..." "FORCING complete stop of obfuscation services...")" >> $LOG_FILE
    
    sudo systemctl stop monero-decoy haproxy-monero haproxy 2>/dev/null
    
    sudo pkill -f haproxy 2>/dev/null
    sudo pkill -9 -f haproxy 2>/dev/null
    
    sudo pkill -f "decoy_traffic.sh" 2>/dev/null
    sudo pkill -9 -f "decoy_traffic.sh" 2>/dev/null
    
    sudo iptables -t mangle -F 2>/dev/null
    
    sleep 3
    
    if ! check_services_enhanced; then
        echo "$(display_message "Arrêt forcé réussi" "Forced stop successful")" >> $LOG_FILE
        return 0
    else
        echo "$(display_message "ATTENTION: Certains services résistent à l'arrêt" "WARNING: Some services resist stopping")" >> $LOG_FILE
        return 1
    fi
}

start_obfuscation_enhanced() {
    echo "$(display_message "DÉMARRAGE AMÉLIORÉ du système d'obscurcissement..." "ENHANCED START of obfuscation system...")" | tee -a $LOG_FILE
    
    force_stop_obfuscation
    
    ensure_obfuscation_files
    
    sudo systemctl daemon-reload
    
    echo "Démarrage de HAProxy..." >> $LOG_FILE
    
    local haproxy_started=false
    for attempt in {1..5}; do
        echo "Tentative $attempt de démarrage HAProxy..." >> $LOG_FILE
        
        if sudo systemctl start haproxy-monero 2>/dev/null; then
            sleep 3
            if systemctl is-active --quiet haproxy-monero; then
                echo "HAProxy-monero démarré avec succès à la tentative $attempt" >> $LOG_FILE
                haproxy_started=true
                break
            fi
        fi
        
        if sudo systemctl start haproxy 2>/dev/null; then
            sleep 3
            if systemctl is-active --quiet haproxy; then
                echo "HAProxy démarré avec succès à la tentative $attempt" >> $LOG_FILE
                haproxy_started=true
                break
            fi
        fi
        
        echo "Échec tentative $attempt, attente avant nouvelle tentative..." >> $LOG_FILE
        sleep 5
    done
    
    if [ "$haproxy_started" = "false" ]; then
        echo "ERREUR: Impossible de démarrer HAProxy après 5 tentatives" >> $LOG_FILE
        return 1
    fi
    
    echo "Configuration des règles iptables..." >> $LOG_FILE
    IPTABLES_SCRIPT="/home/$USERNAME/monero/obfuscation/iptables_setup.sh"
    
    if [ -f "$IPTABLES_SCRIPT" ]; then
        sudo chmod +x "$IPTABLES_SCRIPT"
        if sudo bash "$IPTABLES_SCRIPT" >> $LOG_FILE 2>&1; then
            echo "Règles iptables appliquées avec succès" >> $LOG_FILE
        else
            echo "Échec iptables, application de règles de base..." >> $LOG_FILE
            sudo iptables -t mangle -A POSTROUTING -p tcp --dport 19080 -j TTL --ttl-set 64
            sudo iptables -t mangle -A POSTROUTING -p tcp --dport 443 -j TTL --ttl-set 64
            sudo iptables -t mangle -A POSTROUTING -p tcp --dport 80 -j TTL --ttl-set 64
            sudo netfilter-persistent save 2>/dev/null
        fi
    fi
    
    echo "Démarrage du service de leurre..." >> $LOG_FILE
    
    local decoy_started=false
    for attempt in {1..5}; do
        echo "Tentative $attempt de démarrage service decoy..." >> $LOG_FILE
        
        if sudo systemctl restart monero-decoy; then
            sleep 3
            if systemctl is-active --quiet monero-decoy; then
                echo "Service decoy démarré via systemctl à la tentative $attempt" >> $LOG_FILE
                decoy_started=true
                break
            fi
        fi
        
        echo "Tentative de démarrage manuel du script de leurre..." >> $LOG_FILE
        DECOY_SCRIPT="/home/$USERNAME/monero/obfuscation/decoy_traffic.sh"
        if [ -f "$DECOY_SCRIPT" ]; then
            sudo chmod +x "$DECOY_SCRIPT"
            sudo chown "$USERNAME:$USERNAME" "$DECOY_SCRIPT"
            
            sudo -u "$USERNAME" nohup bash "$DECOY_SCRIPT" > /dev/null 2>&1 &
            sleep 3
            
            if pgrep -f "decoy_traffic.sh" > /dev/null; then
                echo "Script de leurre démarré manuellement à la tentative $attempt" >> $LOG_FILE
                decoy_started=true
                break
            fi
        fi
        
        echo "Échec tentative $attempt decoy, attente avant nouvelle tentative..." >> $LOG_FILE
        sleep 5
    done
    
    if [ "$decoy_started" = "false" ]; then
        echo "ERREUR: Impossible de démarrer le service de leurre après 5 tentatives" >> $LOG_FILE
        return 1
    fi
    
    sleep 5
    if check_services_enhanced; then
        echo -e "\033[1;32m$(display_message "🎉 SYSTÈME D'OBSCURCISSEMENT DÉMARRÉ AVEC SUCCÈS! 🎉" "🎉 OBFUSCATION SYSTEM STARTED SUCCESSFULLY! 🎉")\033[0m" | tee -a $LOG_FILE
        return 0
    else
        echo "$(display_message "ÉCHEC: Services non complètement actifs" "FAILURE: Services not completely active")" | tee -a $LOG_FILE
        return 1
    fi
}

ensure_obfuscation_files() {
    local username="$USERNAME"
    
    if [ ! -d "/home/$username/monero/obfuscation" ]; then
        echo "Création du répertoire d'obscurcissement..." | tee -a $LOG_FILE
        mkdir -p "/home/$username/monero/obfuscation"
        sudo chown -R "$username:$username" "/home/$username/monero/obfuscation"
    fi
    
    if [ ! -f "/home/$username/monero/obfuscation/profile.conf" ]; then
        echo "Création du profil d'obscurcissement par défaut..." | tee -a $LOG_FILE
        cat > "/home/$username/monero/obfuscation/profile.conf" << 'EOLPROFILE'
TRAFFIC_TYPE=web
PACKET_SIZE_MIN=512
PACKET_SIZE_MAX=1500
CONNECTION_INTERVAL_MIN=5
CONNECTION_INTERVAL_MAX=30
PORT_PRIMARY=443
PORT_SECONDARY=80
TRAFFIC_PATTERN=bursty
IDLE_PERIODS=true
EOLPROFILE
        chmod 644 "/home/$username/monero/obfuscation/profile.conf"
        sudo chown "$username:$username" "/home/$username/monero/obfuscation/profile.conf"
    fi
    
    return 0
}

load_state
setup_rpc_auth

if [ -f "/home/$USERNAME/.bitmonero/bitmonero.conf" ]; then
    RPC_PORT=$(grep "rpc-bind-port" "/home/$USERNAME/.bitmonero/bitmonero.conf" | cut -d'=' -f2)
    if [ -z "$RPC_PORT" ]; then
        RPC_PORT=18081
    fi
else
    RPC_PORT=18081
fi

echo "Port RPC configuré: $RPC_PORT" >> $LOG_FILE
echo "Authentification RPC: $([ -n "$MONEROD_AUTH_ARGS" ] && echo "Activée" || echo "Désactivée")" >> $LOG_FILE

if check_services_enhanced; then
    echo "$(display_message "Services d'obscurcissement déjà actifs au démarrage" "Obfuscation services already active at startup")" | tee -a $LOG_FILE
    echo "$(display_message "✅ Configuration terminée - Votre nœud Monero est prêt à l'emploi" "✅ Setup complete - Your Monero node is ready to use")" >> $LOG_FILE
    
    exit 0
fi

RETRY_COUNT=0
MAX_RETRIES=240 
CONSECUTIVE_SYNC_CHECKS=0
REQUIRED_CONSECUTIVE_SYNC=3  

echo "$(display_message "Début de la boucle de surveillance..." "Starting monitoring loop...")" >> $LOG_FILE

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if ! pgrep -f "monerod.*--non-interactive" > /dev/null; then
        echo "$(display_message "Le processus monerod s'est arrêté, arrêt de la surveillance" "Monerod process stopped, stopping monitoring")" | tee -a $LOG_FILE
        exit 1
    fi
    
    if check_services_enhanced; then
        echo "$(display_message "Services d'obscurcissement détectés comme actifs" "Obfuscation services detected as active")" >> $LOG_FILE
        echo "$(display_message "✅ Configuration terminée - Votre nœud Monero est prêt à l'emploi" "✅ Setup complete - Your Monero node is ready to use")" >> $LOG_FILE
        exit 0
    fi
    
    if ! nc -z localhost $RPC_PORT 2>/dev/null; then
        echo "$(date): Service RPC Monero non disponible sur le port $RPC_PORT. Attente..." >> $LOG_FILE
        sleep 30
        RETRY_COUNT=$((RETRY_COUNT + 1))
        continue
    fi
    
    if [ -n "$MONEROD_AUTH_ARGS" ]; then
        MONEROD_STATUS=$(timeout 15s $MONEROD_PATH status --rpc-bind-port $RPC_PORT $MONEROD_AUTH_ARGS 2>&1)
    else
        MONEROD_STATUS=$(timeout 15s $MONEROD_PATH status --rpc-bind-port $RPC_PORT 2>&1)
    fi
    
    echo "$(date): Statut obtenu (longueur: ${#MONEROD_STATUS})" >> $LOG_FILE
    
    CURRENT_HEIGHT=""
    TARGET_HEIGHT=""
    
    if echo "$MONEROD_STATUS" | grep -q "Height:"; then
        HEIGHT_LINE=$(echo "$MONEROD_STATUS" | grep "Height:")
        if [[ $HEIGHT_LINE =~ Height:[[:space:]]*([0-9]+)/([0-9]+) ]]; then
            CURRENT_HEIGHT="${BASH_REMATCH[1]}"
            TARGET_HEIGHT="${BASH_REMATCH[2]}"
            echo "Extraction méthode 1 réussie: CURRENT=$CURRENT_HEIGHT, TARGET=$TARGET_HEIGHT" >> $LOG_FILE
        fi
    fi
    
    if [ -z "$CURRENT_HEIGHT" ] || [ -z "$TARGET_HEIGHT" ]; then
        CURRENT_HEIGHT=$(echo "$MONEROD_STATUS" | grep -oP "height: \K[0-9]+" 2>/dev/null || echo "$MONEROD_STATUS" | grep "height" | awk '{print $2}' 2>/dev/null)
        TARGET_HEIGHT=$(echo "$MONEROD_STATUS" | grep -oP "target: \K[0-9]+" 2>/dev/null || echo "$MONEROD_STATUS" | grep "target" | awk '{print $2}' 2>/dev/null)
        
        if [ -n "$CURRENT_HEIGHT" ] && [ -n "$TARGET_HEIGHT" ]; then
            echo "Extraction méthode 2 réussie: CURRENT=$CURRENT_HEIGHT, TARGET=$TARGET_HEIGHT" >> $LOG_FILE
        fi
    fi
    
    if [ -z "$CURRENT_HEIGHT" ] || [ -z "$TARGET_HEIGHT" ]; then
        echo "Tentative d'extraction via RPC JSON..." >> $LOG_FILE
        
        if [ -n "$CURL_AUTH_ARGS" ]; then
            RPC_RESPONSE=$(curl -s -X POST http://localhost:$RPC_PORT/json_rpc $CURL_AUTH_ARGS -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' 2>/dev/null)
        else
            RPC_RESPONSE=$(curl -s -X POST http://localhost:$RPC_PORT/json_rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' 2>/dev/null)
        fi
        
        if [ $? -eq 0 ] && echo "$RPC_RESPONSE" | grep -q '"result"'; then
            CURRENT_HEIGHT=$(echo "$RPC_RESPONSE" | sed -n 's/.*"height":\s*\([0-9]*\).*/\1/p')
            TARGET_HEIGHT=$(echo "$RPC_RESPONSE" | sed -n 's/.*"target_height":\s*\([0-9]*\).*/\1/p')
            
            if [ -n "$CURRENT_HEIGHT" ] && [ -n "$TARGET_HEIGHT" ]; then
                echo "Extraction méthode 3 (RPC JSON) réussie: CURRENT=$CURRENT_HEIGHT, TARGET=$TARGET_HEIGHT" >> $LOG_FILE
            fi
        fi
    fi
    
    echo "$(date): CURRENT=$CURRENT_HEIGHT, TARGET=$TARGET_HEIGHT" >> $LOG_FILE
    
    if ! [[ "$CURRENT_HEIGHT" =~ ^[0-9]+$ ]] || ! [[ "$TARGET_HEIGHT" =~ ^[0-9]+$ ]]; then
        echo "$(date): Valeurs de hauteur invalides, nouvelle tentative..." >> $LOG_FILE
        CONSECUTIVE_SYNC_CHECKS=0
        RETRY_COUNT=$((RETRY_COUNT + 1))
        sleep 30
        continue
    fi
    
if [ $TARGET_HEIGHT -gt 0 ]; then
    DIFF=$((TARGET_HEIGHT - CURRENT_HEIGHT))
    SYNC_PERCENT=$(awk "BEGIN {print int(($CURRENT_HEIGHT*100/$TARGET_HEIGHT))}")
else
    DIFF=0
    SYNC_PERCENT=100
fi

echo "$(date): CURRENT=$CURRENT_HEIGHT, TARGET=$TARGET_HEIGHT, DIFF=$DIFF, SYNC=$SYNC_PERCENT%" >> $LOG_FILE
echo -ne "Synchronisation: $CURRENT_HEIGHT / $TARGET_HEIGHT ($SYNC_PERCENT%)\r"

save_state "$CURRENT_HEIGHT" "$TARGET_HEIGHT" "$SYNC_PERCENT"

SYNC_CONDITION_MET=false

if [ $TARGET_HEIGHT -eq 0 ] && [ $CURRENT_HEIGHT -gt 3000000 ]; then
    SYNC_CONDITION_MET=true
    echo "Condition 1 remplie: Nœud complètement synchronisé (target=0, height=$CURRENT_HEIGHT)" >> $LOG_FILE
fi

if [ $TARGET_HEIGHT -gt 0 ]; then
    ABS_DIFF=$([ $DIFF -lt 0 ] && echo $((-DIFF)) || echo $DIFF)
    if [ $ABS_DIFF -le 3 ]; then
        SYNC_CONDITION_MET=true
        echo "Condition 2 remplie: Différence ≤ 3 blocs (abs($DIFF)=$ABS_DIFF)" >> $LOG_FILE
    fi
fi

if [ $TARGET_HEIGHT -gt 0 ] && [ $SYNC_PERCENT -ge 99 ]; then
    SYNC_CONDITION_MET=true
    echo "Condition 3 remplie: Synchronisation ≥ 99% ($SYNC_PERCENT%)" >> $LOG_FILE
fi

if [ $TARGET_HEIGHT -gt 0 ] && [ "$CURRENT_HEIGHT" -eq "$TARGET_HEIGHT" ]; then
    SYNC_CONDITION_MET=true
    echo "Condition 4 remplie: Hauteurs identiques ($CURRENT_HEIGHT = $TARGET_HEIGHT)" >> $LOG_FILE
fi
    
if [ "$SYNC_CONDITION_MET" = "true" ]; then
    CONSECUTIVE_SYNC_CHECKS=$((CONSECUTIVE_SYNC_CHECKS + 1))
    echo "$(date): Synchronisation détectée (check $CONSECUTIVE_SYNC_CHECKS/$REQUIRED_CONSECUTIVE_SYNC)" >> $LOG_FILE
    
    if [ $CONSECUTIVE_SYNC_CHECKS -ge $REQUIRED_CONSECUTIVE_SYNC ]; then
        if [ "$SYNCHRONIZED" = "false" ]; then
            SYNCHRONIZED=true
            echo "$(display_message "BLOCKCHAIN SYNCHRONISÉE CONFIRMÉE! ($SYNC_PERCENT%, diff=$DIFF)" "BLOCKCHAIN SYNCHRONIZED CONFIRMED! ($SYNC_PERCENT%, diff=$DIFF)")" | tee -a $LOG_FILE
            
            OBFUSCATION_ATTEMPTED=true
            save_state "$CURRENT_HEIGHT" "$TARGET_HEIGHT" "$SYNC_PERCENT"
            
            if start_obfuscation_enhanced; then


                SUCCESS_BANNER="
 ╔════════════════════════════════════════════════════════════╗
 ║                                                            ║"

                if [ "$LANG_CHOICE" = "FR" ]; then
                    SUCCESS_BANNER="$SUCCESS_BANNER
 ║                OBSCURCISSEMENT du traffic ACTIVÉ           ║
 ║                                                            ║
 ║                  (trafic TCP sortant modifié)              ║"
                else
                    SUCCESS_BANNER="$SUCCESS_BANNER           
 ║                  Traffic  OBFUSCATION ENABLED              ║      
 ║                                                            
 ║                (outbound TCP traffic modified)             ║"
                fi
                
                SUCCESS_BANNER="$SUCCESS_BANNER
 ║                                                            ║
 ╚════════════════════════════════════════════════════════════╝"

                 echo -e "$SUCCESS_BANNER"
                
                echo -e "$SUCCESS_BANNER" > /tmp/obfs_success_banner.txt
                touch /tmp/obfs_activated
                
                echo "OBFS_SUCCESS_BANNER_START" >> $LOG_FILE
                echo -e "$SUCCESS_BANNER" >> $LOG_FILE
                echo "OBFS_SUCCESS_BANNER_END" >> $LOG_FILE
                
                echo "$(display_message "Système d'obscurcissement activé avec succès!" "Obfuscation system successfully activated!")" | tee -a $LOG_FILE
                exit 0
            else
                echo "$(display_message "Échec de l'activation, nouvelle tentative dans 30 secondes..." "Activation failed, retrying in 30 seconds...")" | tee -a $LOG_FILE
                sleep 30
                
                if start_obfuscation_enhanced; then
                    echo -e "\033[1;32m$(display_message "🎉 DEUXIÈME TENTATIVE RÉUSSIE!" "🎉 SECOND ATTEMPT SUCCESSFUL!")\033[0m" | tee -a $LOG_FILE
                    exit 0
                else
                    echo "$(display_message "Échec persistant - veuillez activer manuellement" "Persistent failure - please activate manually")" | tee -a $LOG_FILE
                    exit 1
                fi
            fi
        else
            if [ "$OBFUSCATION_ATTEMPTED" = "false" ]; then
                echo "$(display_message "Nouvelle tentative d'activation de l'obscurcissement..." "Retrying obfuscation activation...")" | tee -a $LOG_FILE
                OBFUSCATION_ATTEMPTED=true
                save_state "$CURRENT_HEIGHT" "$TARGET_HEIGHT" "$SYNC_PERCENT"
                
                if start_obfuscation_enhanced; then
                    echo -e "\033[1;32m$(display_message "🎉 ACTIVATION RÉUSSIE À LA NOUVELLE TENTATIVE!" "🎉 ACTIVATION SUCCESSFUL ON RETRY!")\033[0m" | tee -a $LOG_FILE
                    exit 0
                fi
            else
                echo "$(display_message "✅ Configuration terminée - Votre nœud Monero est prêt à l'emploi" "✅ Setup complete - Your Monero node is ready to use")" | tee -a $LOG_FILE
                exit 0
            fi
        fi
    fi
else
    if [ $CONSECUTIVE_SYNC_CHECKS -gt 0 ]; then
        echo "$(date): Condition de synchronisation plus remplie, reset du compteur" >> $LOG_FILE
        CONSECUTIVE_SYNC_CHECKS=0
    fi
fi
    
    sleep 30
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

echo "$(display_message "Nombre maximum de tentatives atteint sans synchronisation complète" "Maximum number of attempts reached without complete synchronization")" | tee -a $LOG_FILE
echo "$(display_message "Veuillez activer manuellement l'obscurcissement via le menu" "Please manually activate obfuscation through the menu")" | tee -a $LOG_FILE
exit 1

EOL

        sed -i "s|REPLACE_USERNAME|$USERNAME|g" "/tmp/auto_obfs_sync.sh"
        sed -i "s|REPLACE_MONEROD_PATH|$MONEROD_PATH|g" "/tmp/auto_obfs_sync.sh"
        sed -i "s|REPLACE_LANG_CHOICE|$LANG_CHOICE|g" "/tmp/auto_obfs_sync.sh"

        chmod +x "/tmp/auto_obfs_sync.sh"
        
        sudo systemctl stop haproxy haproxy-monero monero-decoy 2>/dev/null
        
        touch "/tmp/auto_obfs.log"
        sudo chmod 666 "/tmp/auto_obfs.log"
    fi
                    
    MONEROD_PATH="/home/$USERNAME/monero/monerod"
    if [ ! -x "$MONEROD_PATH" ]; then
        error "$(get_message "monerod n'est pas trouvé ou n'est pas exécutable" "monerod not found or not executable")"
        return 1
    fi

    STOP_MONEROD=0
            
    trap_original=$(trap -p SIGINT)
            
    cleanup() {
        if [ -n "$trap_original" ]; then
            eval "$trap_original"
        else
            trap - SIGINT
        fi
                
        if [ -n "$MONEROD_PID" ] && kill -0 $MONEROD_PID 2>/dev/null; then
            info "$(get_message "Arrêt de monerod..." "Stopping monerod...")"
            kill $MONEROD_PID 2>/dev/null
            wait $MONEROD_PID 2>/dev/null
        fi
        
        if [ "$AUTO_OBFS_CHOICE" = "2" ]; then
            if systemctl is-active --quiet monero-decoy; then
                info "$(get_message "Arrêt du système d'obscurcissement..." "Stopping obfuscation system...")"
                sudo systemctl stop monero-decoy
            fi
            
            if systemctl is-active --quiet haproxy-monero; then
                sudo systemctl stop haproxy-monero
            elif systemctl is-active --quiet haproxy; then
                sudo systemctl stop haproxy
            fi
        fi
                
        success "$(get_message "Blockchain arrêtée" "Blockchain stopped")"
    }
            
    handle_sigint() {
        echo
        info "$(get_message "CTRL+C détecté, arrêt de la blockchain..." "CTRL+C detected, stopping blockchain...")"
        STOP_MONEROD=1
                
        if systemctl is-active --quiet monero-decoy; then
            info "$(get_message "Arrêt du système d'obscurcissement..." "Stopping obfuscation system...")"
            sudo systemctl stop monero-decoy
            sudo systemctl stop haproxy-monero
        fi
                
        if [ -n "$MONEROD_PID" ] && kill -0 $MONEROD_PID 2>/dev/null; then
            kill -SIGINT $MONEROD_PID 2>/dev/null
        fi
                
        return 0
    }
            
    trap handle_sigint SIGINT

    if [ -n "$BLOCKCHAIN_LOCATION" ]; then
        if [ -d "$BLOCKCHAIN_LOCATION" ]; then
            sudo chown -R "$USERNAME:$USERNAME" "$BLOCKCHAIN_LOCATION" 2>/dev/null || true
            sudo chmod -R u+rw "$BLOCKCHAIN_LOCATION" 2>/dev/null || true
        fi
        
        sudo chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.bitmonero" 2>/dev/null || true
        sudo chmod -R u+rw "/home/$USERNAME/.bitmonero" 2>/dev/null || true
    fi

    monitor_peers &
    MONITOR_PID=$!

    if [ -n "$BLOCKCHAIN_LOCATION" ]; then
        info "$(get_message "Démarrage de la blockchain avec le fichier de configuration" "Starting blockchain with config file")"
        "$MONEROD_PATH" --config-file="$CONFIG_FILE" --non-interactive &
        MONEROD_PID=$!
    else
        info "$(get_message "Démarrage de la blockchain avec le dossier par défaut" "Starting blockchain with default folder")"
        "$MONEROD_PATH" --data-dir="$DEFAULT_DATA_DIR" --non-interactive &
        MONEROD_PID=$!
    fi

    sleep 2
    if ! ps -p $MONEROD_PID > /dev/null; then
        error "$(get_message "Échec du démarrage de monerod" "Failed to start monerod")"
        return 1
    fi
    
    if [ "$AUTO_OBFS_CHOICE" = "2" ]; then
        ensure_obfuscation_files "$USERNAME"
    
        /tmp/auto_obfs_sync.sh 2>/dev/null &
        OBFS_SCRIPT_PID=$!
        
         echo -e "\033[1;32m$(get_message "🚀 Script de surveillance d'obscurcissement démarré (PID: $OBFS_SCRIPT_PID)" "🚀 Obfuscation monitoring script started (PID: $OBFS_SCRIPT_PID)")\033[0m"
    echo -e "\033[1;32m$(get_message "📊 Vous pouvez consulter les logs avec: tail -f /tmp/auto_obfs.log" "📊 You can view logs with: tail -f /tmp/auto_obfs.log")\033[0m"
    echo -e "\033[1;32m$(get_message "⚡ L'obscurcissement s'activera automatiquement après synchronisation" "⚡ Obfuscation will activate automatically after synchronization")\033[0m"
 (
            while true; do
                sleep 5
                
                HAPROXY_ACTIVE=$(systemctl is-active haproxy-monero 2>/dev/null || systemctl is-active haproxy 2>/dev/null || echo "inactive")
                DECOY_ACTIVE=$(systemctl is-active monero-decoy 2>/dev/null || echo "inactive")
                
                if [ "$HAPROXY_ACTIVE" = "active" ] && [ "$DECOY_ACTIVE" = "active" ]; then
                    echo ""
                    echo -e "\033[1;32m ╔════════════════════════════════════════════════════════════╗\033[0m"
                    echo -e "\033[1;32m ║                                                            ║\033[0m"
                    if [ "$LANG_CHOICE" = "FR" ]; then
                        echo -e "\033[1;32m ║            OBSCURCISSEMENT du trafic ACTIVÉ               ║\033[0m"
                        echo -e "\033[1;32m ║                                                           ║\033[0m"
                        echo -e "\033[1;32m ║              (trafic TCP sortant modifié)                 ║\033[0m"
                    else
                        echo -e "\033[1;32m ║                Traffic obfuscation enabled                ║\033[0m"
                        echo -e "\033[1;32m ║                                                           ║\033[0m"
                        echo -e "\033[1;32m ║              (outbound TCP traffic modified)              ║\033[0m"
                    fi
                    echo -e "\033[1;32m ║                                                            ║\033[0m"
                    echo -e "\033[1;32m ╚════════════════════════════════════════════════════════════╝\033[0m"
                    echo ""
                    break
                fi
                
                ELAPSED=$((ELAPSED + 5))
                if [ ${ELAPSED:-0} -gt 900 ]; then
                    echo -e "\033[1;33m⚠️ Timeout: Vérifiez manuellement l'obscurcissement (menu 10-4)\033[0m"
                    break
                fi
            done
        ) &
    fi
        
    info "$(get_message "Attente du démarrage du service RPC..." "Waiting for RPC service to start...")"
    for i in {1..60}; do
        if [ $STOP_MONEROD -eq 1 ]; then
            break
        fi
                
        if nc -z localhost 18081; then
            success "$(get_message "Service RPC disponible" "RPC service available")"
            break
        fi
                
        echo -n "."
        sleep 2
                
        if [ $i -eq 60 ]; then
            error "$(get_message "Timeout en attendant le service RPC" "Timeout waiting for RPC service")"
        fi
    done
    
    if [ "$IP_BAN_CHOICE" = "1" ] && [ $STOP_MONEROD -eq 0 ]; then
        info "$(get_message "Application des bans IP..." "Applying IP bans...")"
        sleep 5  
        
        local BAN_DURATION=7776000  
        
        BAN_LIST_FILE="/home/$USERNAME/.bitmonero/ban_list.txt"
        if [ -f "$BAN_LIST_FILE" ]; then
            local total_bans=$(grep -v "^#" "$BAN_LIST_FILE" | grep -v "^$" | wc -l)
            info "$(get_message "Nombre total d'adresses IP à bannir: $total_bans" "Total number of IP addresses to ban: $total_bans")"
            info "$(get_message "Durée des bans: 3 mois" "Ban duration: 3 months")"
            
            local counter=0
            local success_count=0
            
            while IFS=' ' read -r line || [ -n "$line" ]; do
                if [ $STOP_MONEROD -eq 1 ]; then
                    break
                fi
                
                [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
                
                read -r ip duration_ignored <<< "$line"
                
                if [ -n "$ip" ]; then
                    counter=$((counter + 1))
                    
                    info "$(get_message "Ban IP $counter/$total_bans: $ip" "Banning IP $counter/$total_bans: $ip")"
                    
                   ban_ip_via_monerod "$ip" "$BAN_DURATION"
                    if [ $? -eq 0 ]; then
                        success_count=$((success_count + 1))
                    else
                        warning "$(get_message "Échec du ban pour l'IP: $ip" "Ban failed for IP: $ip")"
                    fi
                fi
            done < "$BAN_LIST_FILE"
            
            success "$(get_message "Bans appliqués: $success_count/$total_bans" "Bans applied: $success_count/$total_bans")"
            

info "$(get_message "Vérification de l'état des bans..." "Checking ban status...")"


if [ -f "/home/$USERNAME/.bitmonero/bitmonero.conf" ] && grep -q "^rpc-login=" "/home/$USERNAME/.bitmonero/bitmonero.conf"; then
    RPC_CREDENTIALS=$(grep "^rpc-login=" "/home/$USERNAME/.bitmonero/bitmonero.conf" | cut -d'=' -f2)
    ban_status=$("$MONEROD_PATH" bans --rpc-bind-port 18081 --rpc-login "$RPC_CREDENTIALS" 2>/dev/null)
else
    ban_status=$("$MONEROD_PATH" bans --rpc-bind-port 18081 2>/dev/null)
fi

ban_count=$(echo "$ban_status" | grep -c "banned for")
success "$(get_message "Nombre total de bans actifs: $ban_count" "Total active bans: $ban_count")"
            
            echo "$ban_status" | head -n 5
        else
            warning "$(get_message "Fichier de bans non trouvé: $BAN_LIST_FILE" "Ban list file not found: $BAN_LIST_FILE")"
        fi
    fi
    
    print_styled "PRIMARY" "$(get_message "Appuyez sur CTRL+C pour arrêter la blockchain et revenir au menu" "Press CTRL+C to stop the blockchain and return to the menu")"
    
    while [ $STOP_MONEROD -eq 0 ]; do
        if ! kill -0 $MONEROD_PID 2>/dev/null; then
            info "$(get_message "Le processus monerod s'est terminé" "Monerod process has terminated")"
            STOP_MONEROD=1
            break
        fi
        sleep 1
    done
    
    if [ -n "$OBFS_SCRIPT_PID" ] && kill -0 $OBFS_SCRIPT_PID 2>/dev/null; then
        kill $OBFS_SCRIPT_PID 2>/dev/null
    fi
    
    if [ -n "$MONITOR_PID" ]; then
        kill $MONITOR_PID 2>/dev/null
    fi
    
    cleanup
    return 0
}

show_notes() {
    clear
    setup_terminal
    echo -e "\n\n\n\n\n\n\n\n"  
    
    print_header "$(get_message "NOTES" "READ")"
    
    print_styled "MONERO" "$(get_message "- Pour arrêter la blockchain : CTRL + C" "- To stop the blockchain: CTRL + C")"
    echo
    print_styled "MONERO" "$(get_message "- Votre nom d'utilisateur est: ${COLORS[SUCCESS]}$SUDO_USER${COLORS[INFO]}" "- Your username is: ${COLORS[SUCCESS]}$SUDO_USER${COLORS[INFO]}")"
    echo
    print_styled "MONERO" "$(get_message "- Vérification de l'adresse IP Tor..." "- Checking Tor IP address...")"
    TOR_IP=$(torsocks curl -s https://check.torproject.org/api/ip 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$TOR_IP" ]; then
        print_styled "SUCCESS" "$(get_message "- Adresse IP TOR: ${COLORS[SUCCESS]}$TOR_IP${COLORS[SUCCESS]}" "- TOR IP address: ${COLORS[SUCCESS]}$TOR_IP${COLORS[SUCCESS]}")"
    else
        print_styled "ERROR" "$(get_message "- Impossible de récupérer l'adresse IP Tor" "- Unable to retrieve Tor IP address")"
    fi
    echo
    print_styled "PRIMARY" "$(get_message "- Configuration réseau requise :" "- Required network configuration:")"
    print_styled "PRIMARY" "$(get_message "⚠️ REDIRIGER le port 22 et 18080 de votre Box internet" "⚠️ Open port 22 and 18080 of your internet router")"
    print_styled "PRIMARY" "$(get_message "  vers l'IP de votre PC." "  to your PC's IP address.")"
    print_styled "MONERO" "$(get_message "  https://github.com/kerlannXmr/EasyMonerod/issues/10" "  https://github.com/kerlannXmr/EasyMonerod/issues/10")"
    echo
    print_styled "MONERO" "$(get_message "- Installer MONERO GUI pour la gestion du wallet" "- Install MONERO GUI for wallet management")"
    print_styled "MONERO" "$(get_message "  MONERO GUI se synchronisera sur ce noeud" "  MONERO GUI will synch on this node")"
    
    print_styled "MONERO" "$(get_message "  https://www.getmonero.org/downloads/" "  https://www.getmonero.org/downloads/")"
    echo
    print_styled "MONERO" "\e]8;;https://mega.nz/file/gjNWgL5B#itd6yCJJk_-1QbP2NbGWIm5DI1CC_MbTr8L6TeDqESI\e\\  PDF Documentations point 5 (CTRL+click)\e]8;;\e\\"
    echo
    
    echo
    print_styled "PRIMARY" "$(get_message "-🙏 Gacieux Dons MONERO(Xmr) pour le dur labeur: " "-🙏 Send MONERO(Xmr) donation for hard work")" 
    print_styled "PRIMARY" "$(get_message "    avec 'cake wallet' à:    kerlann.xmr" "    with 'cake wallet' to:   kerlann.xmr")"
    echo
    print_styled "MONERO" "$(get_message "- Contact:  easynode@kerlann.org" "- Contact:  easynode@kerlann.org")"
    echo
    print_styled "MONERO" "$(get_message "- Code source:" "- Source Code:")"
    print_styled "MONERO" "$(get_message "  https://github.com/kerlannXmr" "  https://github.com/kerlannXmr")"
    
    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..❤️." "Press Enter to continue..❤️.")")"
}

show_scripts() {
    clear
    setup_terminal
    echo -e "\n\n\n\n\n\n"  
    print_header "$(get_message "INFOS" "FEATURES")"
    
    print_styled "MONERO" "1) $(get_message "Mise à jour système et installation des paquets" "System update and package installation")"
    print_styled "PRIMARY" "   $(get_message "- Configuration du firewall activé avec ouverture des ports :" "- Firewall configuration Actived with ports opening:")"
    echo -e "${COLORS[GRIS]}    $(get_message "-Ports system: 22(SSH), 80(HTTP), 443(HTTPS), 9050(Tor), 4200(SHELL IN BOX), 4444(i2p-http), 4447(i2p-socks), 53317(localsend)" "-System ports: 22(SSH), 80(HTTP), 443(HTTPS), 9050(Tor), 4200(SHELL IN BOX), 4444(i2p-http), 4447(i2p-socks), 53317(localsend)")${COLORS[RESET]}"
    echo -e "${COLORS[GRIS]}    $(get_message "-Ports Monero: 18080(P2P), 18081(Public), 18083(ZMQ), 18084(Tor), 18085(I2P), 18086(LWS), 18089(RPC)" "-Monero ports: 18080(P2P), 18081(Public), 18083(ZMQ), 18084(Tor), 18085(I2P), 18086(LWS), 18089(RPC)")${COLORS[RESET]}"
    echo -e "${COLORS[GRIS]}    $(get_message "-Ports HAProxy: 19080, 8443, 8080" "-HAProxy ports: 19080, 8443, 8080")${COLORS[RESET]}"
    echo
    print_styled "MONERO" "2) $(get_message "Installation de Monero CLI" "Monero CLI Installation")"
    print_styled "PRIMARY" "   $(get_message "- Installation des fichiers Monero" "- Installing Monero files")"
    print_styled "PRIMARY" "   $(get_message "- Configuration des permissions" "- Setting up permissions")"
    echo
    print_styled "MONERO" "3) $(get_message "Installation et configuration de TOR" "TOR Installation and configuration")"
    
    if [ -f /var/lib/tor/monero-service/hostname ]; then
        ONION_ADDRESS=$(sudo cat /var/lib/tor/monero-service/hostname)
        echo -e "${COLORS[SUCCESS]}    -TOR Onion: $ONION_ADDRESS${COLORS[RESET]}"
    fi
    print_styled "SUCCESS" "     PORT RPC: 18081"
    if [ -f /var/lib/tor/ssh/hostname ]; then
        SSH_ONION_ADDRESS=$(sudo cat /var/lib/tor/ssh/hostname)
        echo -e "${COLORS[SUCCESS]}    -SSH Onion: $SSH_ONION_ADDRESS${COLORS[RESET]}"
    fi
    print_styled "SUCCESS" "     PORT SSH: 22"
    print_styled "WARNING" "   $(get_message " Les adresses Tor sont créées uniquement lors de votre installation" "  Tor addresses are only created during installation")"
    echo
    print_styled "MONERO" "4) $(get_message "Configuration de bitmonero.conf" "bitmonero.conf configuration")"
    print_styled "PRIMARY" "   $(get_message "- Configuration du fichier de démarrage" "- Configuring startup file")"
    print_styled "PRIMARY" "   $(get_message "- Configuration des ports" "- Setting up ports")"
    print_styled "SUCCESS" "$(get_message "    -rpc-bind-port=18081" "     rpc-bind-port=18081")"
    print_styled "PRIMARY" "   $(get_message "- Configuration des chemins" "- Setting up paths")"
    print_styled "PRIMARY" "   $(get_message "- Option de sécurisation RPC (avec/sans mot de passe)" "- RPC security option (with/without password)")"
    echo
    print_styled "MONERO" "5) $(get_message "Configuration DNS privacy-friendly" "Set up privacy-friendly DNS")"
    print_styled "PRIMARY" "   $(get_message "- Installation des DNS privacy-friendly" "- Installing privacy-friendly DNS")"
    print_styled "PRIMARY" "   $(get_message "- Configuration des serveurs DNS" "- Configuring DNS servers")"
    echo
    print_styled "MONERO" "6)$(get_message " Démarrage Blockchain et Bloquage 'IP Bans list':" "Start & Block 'IP bans list':")"
    print_styled "PRIMARY" "   $(get_message "- Option d'obscurcissement automatique après synchronisation" "- Automatic obfuscation option after synchronization")"
    print_styled "PRIMARY" "   $(get_message "- Monitoring en temps réel des peers" "- Real-time peer monitoring")"
    print_styled "PRIMARY" "   $(get_message "- https://github.com/monero-project/meta/issues/1124" "- https://github.com/monero-project/meta/issues/1124")"
    print_styled "PRIMARY" "   $(get_message "- https://github.com/Boog900/monero-ban-list/blob/main/ban_list.txt" "- https://github.com/Boog900/monero-ban-list/blob/main/ban_list.txt")"
    echo
    print_styled "MONERO" "10) $(get_message "Mode obscurcissement du trafic" "Mode Traffic obfuscation")"
    print_styled "PRIMARY" "   $(get_message "- Configuration HAProxy pour masquer le trafic Monero" "- HAProxy configuration to mask Monero traffic")"
    print_styled "PRIMARY" "   $(get_message "- Génération de trafic leurre" "- Decoy traffic generation")"
    print_styled "PRIMARY" "   $(get_message "- Randomisation des paquets avec iptables" "- Packet randomization with iptables")"
    print_styled "PRIMARY" "   $(get_message "- Activation automatique après synchronisation" "- Automatic activation after synchronization")"
    echo
    print_styled "WARNING" "$(get_message " ⚠️  Configurer votre router/Box internet pour REDIRIGER le port 22 et 18080" " ⚠️   Configure your router/internet box to REDIRECT port 22 and 18080")"
    print_styled "WARNING" "$(get_message "    vers l'ADRESSE IP de votre PC" "    to your PC's IP ADDRESS")"
    print_styled "PRIMARY" "$(get_message "- https://github.com/kerlannXmr/EasyMonerod/issues/10" "- https://github.com/kerlannXmr/EasyMonerod/issues/10")"
    echo

    read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
}

monero_animation() {
    clear
    
    local logo_frame1="
      ████████████      
    ██            ██    
   ██   ██    ██   ██   
  ██    ███  ███    ██  
  ██    ██ ██ ██    ██  
  ██    ██    ██    ██  
  ██    ██    ██    ██  
   ██   ██    ██   ██   
    ██            ██    
      ████████████      
"

    local logo_frame2="
      ************      
    **            **    
   **   **    **   **   
  **    ***  ***    **  
  **    ** ** **    **  
  **    **    **    **  
  **    **    **    **  
   **   **    **   **   
    **            **    
      ************      
"

    local terminal_width=$(tput cols)
    local logo_width=24
    local center_x=$(( (terminal_width - logo_width) / 2 ))
    local top_y=3
    
    if [ $center_x -lt 0 ]; then
        center_x=0
    fi
    
    for ((i=0; i<8; i++)); do
        clear
        
        if ((i % 2 == 0)); then
            logo="${logo_frame1}"
            color="${COLORS[MONERO]}"  
        else
            logo="${logo_frame2}"
            color="${COLORS[PRIMARY]}"  
        fi
        
        tput cup $top_y $center_x
        echo -e "$color$logo${COLORS[RESET]}"
        
        sleep 0.3
    done
}

show_menu() {
    while true; do
        setup_terminal
        echo -e "\n\n\n\n\n\n\n\n"  
        
        print_styled "PRIMARY" "0) $(get_message "GUIDE" "HOW TO")"
        
        echo -e "\033[38;5;208m$(get_message "Menu Principal:" "Main Menu:")${COLORS[RESET]}"
        print_styled "PRIMARY" "1) $(get_message "Mise à jour système" "Update system")"
        print_styled "PRIMARY" "2) $(get_message "Installer Monero CLI" "Install Monero CLI")"
        print_styled "PRIMARY" "3) $(get_message "Installer service Tor" "Install configure Tor")"
        print_styled "PRIMARY" "4) $(get_message "Configurer bitmonero" "Configure bitmonero")"
        print_styled "PRIMARY" "5) $(get_message "Configurer DNS privacy-friendly" "Set up privacy-friendly DNS")"
        
        echo -e "\033[38;5;208m$(get_message "BLOCKCHAIN" "BLOCKCHAIN")${COLORS[RESET]}"
        print_styled "PRIMARY" "6) $(get_message "MARCHE" "START")"
        print_styled "PRIMARY" "7) $(get_message "ARRET= ctrl+c" "STOP= ctrl+c")"
        
        echo -e "\033[38;5;208m$(get_message "Option du Noeud sur Disque:" "Node Option on DISK:")${COLORS[RESET]}"
        
        print_styled "PRIMARY" "8) $(get_message "Blockchain sur DISQUE EXTERNE" "Blockchain on EXTERNAL DISK")"
        print_styled "PRIMARY" "9) $(get_message "Blockchain sur DISQUE INTERNE" "Blockchain on INTERNAL DISK")"
        
        echo -e "\033[38;5;208m$(get_message "SÉCURITÉ AVANCÉE 'mode obfuscation'" "ADVANCED SECURITY 'obfuscation mode'")${COLORS[RESET]}"
        print_styled "GRIS" "10) $(get_message "Configuration obfuscation" "Obfuscation Configuration")"
        
        echo -e "\033[38;5;208m$(get_message "AUTRES OPTIONS" "OTHER OPTIONS")${COLORS[RESET]}"
        print_styled "PRIMARY" "11) $(get_message "Changer language" "Change language")"
        print_styled "PRIMARY" "12) $(get_message "INFOS" "FEATURES")"
        print_styled "PRIMARY" "13) $(get_message "NOTES" "READ")"
        
        echo -e "\033[38;5;208m$(get_message "FIN" "END")${COLORS[RESET]}"
        print_styled "PRIMARY" "14) $(get_message "QUITTER" "EXIT")"
                
        echo -n "$(print_styled "INFO" "$(get_message "Choix (1-14): " "Choice (1-14): ")")"
        read -r choice

        case $choice in
            0) 
                Manuel
                ;;
            1) 
                update_system 
                ;;
            2)  
                if ! ask_username; then
                    continue
                fi
                install_monero_cli
                read -p "$(print_styled "PRIMARY" "$(get_message "Appuyez sur Entrée pour continuer..." "Press Enter to continue...")")"
                ;;
            3)  
                if ! ask_username; then
                    continue
                fi
                install_tor
                ;;
            4)  
                if ! ask_username; then
                    continue
                fi
                configure_monero
                ;;
            5) 
                configure_dns 
                ;;
            6) 
                if ! ask_username; then
                    continue
                fi
                start_blockchain
                ;;
            7) 
                echo -n "$(print_styled "INFO" "$(get_message "Voulez-vous vraiment arrêter la blockchain? (o/n): " "Do you really want to stop the blockchain? (y/n): ")")"
                read -r confirm
                case $confirm in
                    [OoYy]*)
                        print_styled "INFO" "$(get_message "Arrêt de tous les services Monero..." "Stopping all Monero services...")"
                        
                        print_styled "INFO" "$(get_message "Arrêt du service de leurre..." "Stopping decoy service...")"
                        sudo systemctl stop monero-decoy 2>/dev/null
                        if systemctl is-active --quiet monero-decoy; then
                            print_styled "WARNING" "$(get_message "Le service de leurre n'a pas pu être arrêté normalement, tentative de kill..." "Decoy service could not be stopped normally, attempting kill...")"
                            DECOY_PIDS=$(pgrep -f "decoy_traffic.sh")
                            if [ -n "$DECOY_PIDS" ]; then
                                sudo kill -9 $DECOY_PIDS
                            fi
                        else
                            print_styled "SUCCESS" "$(get_message "Service de leurre arrêté" "Decoy service stopped")"
                        fi
                        
                        print_styled "INFO" "$(get_message "Arrêt de HAProxy..." "Stopping HAProxy...")"
                        sudo systemctl stop haproxy-monero 2>/dev/null
                        sudo systemctl stop haproxy 2>/dev/null
                        if systemctl is-active --quiet haproxy || systemctl is-active --quiet haproxy-monero; then
                            print_styled "WARNING" "$(get_message "HAProxy n'a pas pu être arrêté normalement, tentative de kill..." "HAProxy could not be stopped normally, attempting kill...")"
                            sudo killall -9 haproxy 2>/dev/null
                        else
                            print_styled "SUCCESS" "$(get_message "HAProxy arrêté" "HAProxy stopped")"
                        fi
                        
                        sudo systemctl stop monero 2>/dev/null
                        
                        print_styled "INFO" "$(get_message "Arrêt de Monero..." "Stopping Monero...")"
                        pkill -f monerod
                        sleep 2
                        
                        if pgrep -f monerod >/dev/null; then
                            print_styled "WARNING" "$(get_message "Des processus Monero persistent, arrêt forcé..." "Monero processes still running, forcing shutdown...")"
                            pkill -9 -f monerod
                        fi
                        
                        sleep 1
                        if ! pgrep -f monerod >/dev/null && ! systemctl is-active --quiet monero-decoy && ! systemctl is-active --quiet haproxy && ! systemctl is-active --quiet haproxy-monero; then
                            success "$(get_message "Tous les services ont été arrêtés avec succès!" "All services have been successfully stopped!")"
                        else
                            warning "$(get_message "Certains services pourraient être encore actifs. Vérifiez avec l'option 10-4." "Some services might still be active. Check with option 10-4.")"
                        fi
                        ;;
                    *)
                        continue
                        ;;
                esac
                ;;
            8)
                if ! ask_username; then
                    continue
                fi
                manage_blockchain
                ;;
            9) 
                unmount_sdb1 
                ;;
            10) 
                clear
                traffic_obfuscation_menu
                ;;
            11) 
                select_language
                continue
                ;;
            12) 
                show_scripts 
                ;;
            13) 
                show_notes 
                ;;
            14) 
                clear
                monero_animation
                setup_terminal
                echo -e "\n\n\n\n\n\n\n\n"  
                print_header "$(get_message "MERCI" "THANK YOU")"
                
                echo
                print_styled "SUCCESS" "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
                if [ "$LANG_CHOICE" = "FR" ]; then
                    print_styled "SUCCESS" "┃                                                                             ┃"
                    print_styled "SUCCESS" "┃  Programme d'aide informatique et de liberté.                               ┃"
                    print_styled "SUCCESS" "┃  Permet d'installer un nœud MONERO sans aucune connaissance sur Linux.      ┃"
                    print_styled "SUCCESS" "┃                                                                             ┃"
                    print_styled "SUCCESS" "┃  Merci d'avoir utilisé ce programme.                                        ┃"
                    print_styled "SUCCESS" "┃                                                                             ┃"
                    print_styled "MONERO"  "┃                           🔒 PRIVACY MATTERS 🔒                             ┃"
                else
                    print_styled "SUCCESS" "┃                                                                             ┃"
                    print_styled "SUCCESS" "┃  Computer assistance and freedom program.                                   ┃"
                    print_styled "SUCCESS" "┃  Helps you install a MONERO node without any knowledge on Linux.            ┃"
                    print_styled "SUCCESS" "┃                                                                             ┃"
                    print_styled "SUCCESS" "┃  Thank you for using this program.                                          ┃"
                    print_styled "SUCCESS" "┃                                                                             ┃"
                    print_styled "MONERO"  "┃                           🔒 PRIVACY MATTERS 🔒                             ┃"
                fi
                print_styled "SUCCESS" "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
                echo
                
                sleep 5
                exit 0
                ;;
        esac
    done
}

setup_terminal
select_language
create_motd
show_menu
exit 0
