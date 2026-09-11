# phiOS — Procedura base
 
Solo passi eseguiti e verificati. Riferimento: `zotac`, 2026-08-31.
 
---
 
## 1. Live ISO
 
```bash
ls /sys/firmware/efi/efivars     # deve elencare file → boot UEFI
lsblk -d -o NAME,MODEL,SIZE      # identifica i dischi
ping -c 3 archlinux.org
timedatectl
```
 
Lavoro remoto via SSH:
 
```bash
passwd                           # password temporanea root, valida solo nella live
systemctl start sshd
ip -brief address
```
 
---
 
## 2. Partizionamento
 
Distruttivo.
 
```bash
wipefs -a /dev/nvme0n1
wipefs -a /dev/nvme1n1
blkdiscard /dev/nvme0n1          # opzionale, ignora errori
blkdiscard /dev/nvme1n1
sgdisk --zap-all /dev/nvme0n1
sgdisk --zap-all /dev/nvme1n1
 
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI"          /dev/nvme0n1
sgdisk -n 2:0:0   -t 2:8309 -c 2:"phios-system" /dev/nvme0n1
sgdisk -n 1:0:0   -t 1:8309 -c 1:"phios-bulk"   /dev/nvme1n1
partprobe /dev/nvme0n1 /dev/nvme1n1
 
lsblk -o NAME,SIZE,PARTLABEL,PARTTYPENAME
```
 
---
 
## 3. Cifratura
 
Stessa passphrase su entrambi. Trascriverla su carta ora.
 
```bash
cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
cryptsetup luksFormat --type luks2 /dev/nvme1n1p1
cryptsetup open /dev/nvme0n1p2 system
cryptsetup open /dev/nvme1n1p1 bulk
```
 
---
 
## 4. Filesystem e subvolumi
 
```bash
mkfs.fat -F32 -n EFI /dev/nvme0n1p1
mkfs.btrfs -L phios-system /dev/mapper/system
mkfs.btrfs -L phios-bulk   /dev/mapper/bulk
 
mount /dev/mapper/system /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@usercache
umount /mnt
 
O="noatime,compress=zstd:1,ssd"
mount -o $O,subvol=@ /dev/mapper/system /mnt
mkdir -p /mnt/{home,.snapshots,boot,var/log,var/cache}
mount -o $O,subvol=@home      /dev/mapper/system /mnt/home
mount -o $O,subvol=@snapshots /dev/mapper/system /mnt/.snapshots
mount -o $O,subvol=@log       /dev/mapper/system /mnt/var/log
mount -o $O,subvol=@cache     /dev/mapper/system /mnt/var/cache
mount /dev/nvme0n1p1 /mnt/boot
 
findmnt -R /mnt
```
 
`@usercache` non si monta qui: l'utente non esiste ancora.
 
---
 
## 5. Sistema base
 
```bash
pacstrap -K /mnt \
  base base-devel linux linux-lts linux-firmware amd-ucode \
  btrfs-progs cryptsetup dosfstools efibootmgr \
  networkmanager openssh sudo \
  zsh git vim nano \
  man-db man-pages texinfo \
  zram-generator
```
 
fstab scritto in modo deterministico. **Non usare `genfstab >>`**: accoda e duplica.
 
```bash
FS=$(blkid -s UUID -o value /dev/mapper/system)
EFI=$(blkid -s UUID -o value /dev/nvme0n1p1)
O="rw,noatime,compress=zstd:1,ssd,space_cache=v2"
 
cat > /mnt/etc/fstab <<EOF
UUID=$FS   /                     btrfs  $O,subvol=/@            0 0
UUID=$FS   /home                 btrfs  $O,subvol=/@home        0 0
UUID=$FS   /.snapshots           btrfs  $O,subvol=/@snapshots   0 0
UUID=$FS   /var/log              btrfs  $O,subvol=/@log         0 0
UUID=$FS   /var/cache            btrfs  $O,subvol=/@cache       0 0
UUID=$FS   /home/flavio/.cache   btrfs  $O,subvol=/@usercache   0 0
UUID=$EFI  /boot                 vfat   rw,relatime,fmask=0137,dmask=0027,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro 0 2
EOF
```
 
`fmask/dmask` ristretti: altrimenti `bootctl` segnala il seme casuale leggibile da chiunque.
 
---
 
## 6. Configurazione di sistema
 
```bash
arch-chroot /mnt
export TERM=xterm-256color       # se TERM del client non è nel database
```
 
```bash
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
hwclock --systohc
 
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/' /etc/locale.gen   # solo dizionario
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf
 
echo 'zotac' > /etc/hostname
cat > /etc/hosts <<'EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   zotac.localdomain zotac
EOF
 
passwd                           # root: serve per la shell di emergenza
useradd -m -G wheel -s /usr/bin/zsh flavio
passwd flavio
 
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
visudo -c
 
mkdir -p /home/flavio/.cache
# NON chown qui: @usercache non è ancora montato su questo path (si monta
# solo al boot, da fstab), quindi il chown si applicherebbe alla directory
# vuota su @home, coperta subito dopo dal subvolume reale — che resta
# root:root, la sua proprietà di creazione (Fase 4). Il chown va fatto
# dopo il primo riavvio, quando il mount è quello vero. Vedi Fase 9.
 
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = 8192
compression-algorithm = zstd
EOF
 
cat > /etc/sysctl.d/99-zram.conf <<'EOF'
vm.swappiness = 150
vm.page-cluster = 0
EOF
 
systemctl enable NetworkManager sshd fstrim.timer
```
 
Verifica nel chroot (`localectl` non è attendibile qui, systemd non gira):
 
```bash
cat /etc/locale.conf /etc/vconsole.conf
locale -a | grep -iE 'en_US|it_IT'
id flavio
passwd -S root; passwd -S flavio
```
 
---
 
## 7. Initramfs
 
```bash
BLK=$(blkid -s UUID -o value /dev/nvme0n1p2)   # UUID della PARTIZIONE, non del filesystem
echo "system  UUID=$BLK  none  password-echo=no,discard" > /etc/crypttab.initramfs
 
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
```
 
Fallback: servono **tre** modifiche al preset, non una.
 
```bash
sed -i "s/^PRESETS=.*/PRESETS=('default' 'fallback')/" /etc/mkinitcpio.d/linux.preset
sed -i 's|^#fallback_image=|fallback_image=|'          /etc/mkinitcpio.d/linux.preset
sed -i 's|^#fallback_options=|fallback_options=|'      /etc/mkinitcpio.d/linux.preset
 
mkinitcpio -P
ls -la /boot/initramfs-*.img
```
 
Il fallback deve risultare **più grande** dell'immagine normale. Se ha la stessa dimensione, `fallback_options` non è attivo.
 
---
 
## 8. Bootloader
 
```bash
bootctl install
systemctl enable systemd-boot-update.service
 
cat > /boot/loader/loader.conf <<'EOF'
default  phios.conf
timeout  3
console-mode keep
editor   no
EOF
 
FS=$(blkid -s UUID -o value /dev/mapper/system)
 
for k in linux linux-lts; do
  [ "$k" = "linux" ] && n="phios" || n="phios-lts"
  [ "$k" = "linux" ] && t="phiOS" || t="phiOS (LTS)"
  cat > /boot/loader/entries/$n.conf <<EOF
title   $t
linux   /vmlinuz-$k
initrd  /amd-ucode.img
initrd  /initramfs-$k.img
options root=UUID=$FS rootflags=subvol=@ rw
EOF
done
 
cat > /boot/loader/entries/phios-fallback.conf <<EOF
title   phiOS (fallback)
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux-fallback.img
options root=UUID=$FS rootflags=subvol=@ rw
EOF
 
bootctl random-seed
bootctl list
```
 
`bootctl list` non deve riportare "No such file or directory".
 
---
 
## 9. Riavvio
 
```bash
exit
umount -R /mnt
cryptsetup close bulk
reboot
```
 
Verifica dopo l'avvio:
 
```bash
findmnt -t btrfs,vfat -o TARGET,SOURCE,OPTIONS
zramctl; swapon --show
localectl status
systemctl --failed
ip -brief address
uname -r
```
 
**Fix necessario, una tantum:** solo ora `@usercache` è montato per davvero su `/home/flavio/.cache`. La sua radice ha ancora la proprietà di creazione (Fase 4, root:root):
 
```bash
sudo chown flavio:flavio /home/flavio/.cache
ls -ld /home/flavio/.cache
```
 
Senza questo, qualsiasi programma che scrive nella cache utente (es. `kitty`) fallisce con `PermissionError`. Da ripetere identico su `razer`.
 
---
 
## 10. Secondo disco (`bulk`)
 
Sblocco automatico dopo la passphrase di `system`, secondo il layout di §3.2 della pianificazione zotac.
 
```bash
# Keyfile e aggiunta slot LUKS su /dev/nvme1n1p1
# — comandi eseguiti in sessione precedente, non trascritti qui —
```
 
```bash
BULK_UUID=$(blkid -s UUID -o value /dev/nvme1n1p1)
echo "bulk  UUID=$BULK_UUID  /etc/cryptsetup-keys.d/bulk.key  discard" >> /etc/crypttab
 
BULK_FS=$(blkid -s UUID -o value /dev/mapper/bulk)
echo "UUID=$BULK_FS  /mnt/bulk  btrfs  rw,noatime,compress=zstd:1,ssd  0 0" >> /etc/fstab
 
mkdir -p /mnt/bulk
mount -a
```
 
```bash
mkdir -p /mnt/bulk/games
chown flavio:flavio /mnt/bulk /mnt/bulk/games
```
 
Correzione applicata dopo Fase 17: `/mnt/bulk` (radice del mount, non solo `games`) era rimasta root:root dalla creazione del filesystem. Qualunque programma che testa la scrivibilità del mount point stesso (Steam lo fa alla selezione del disco) falliva con permission denied — stesso bug di `.cache` sopra, stessa causa (chown fatto solo sulla sottocartella).
 
**Verificato:** al riavvio `/mnt/bulk` risulta montato senza richiesta di seconda passphrase (`findmnt /mnt/bulk` → `/dev/mapper/bulk`, `btrfs`).
 
**Rimandato:** `unreal`, `models`, `media/{videos,pictures,music}` e i relativi bind mount verso la home. Non necessari allo stato attuale (D1, zotac-installazione.md §1).
 
---
 
## 11. Snapshot (`snapper`)
 
```bash
sudo pacman -S snapper snap-pac
```
 
`@snapshots` (Fase 4) confligge con il subvolume che `snapper create-config` genera da sé. Sequenza per usare il nostro al posto di quello nuovo:
 
```bash
sudo umount /.snapshots
sudo rmdir /.snapshots
 
sudo snapper -c root create-config /
 
sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo mount -a
sudo chmod 750 /.snapshots
```
 
`home` non ha questo conflitto (`.snapshots` nasce annidato in `@home`, previsto):
 
```bash
sudo snapper -c home create-config /home
```
 
Retention `home` — D3: sola cadenza giornaliera, poche istantanee (valore scelto: 7):
 
```bash
sudo sed -i \
  -e 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="0"/' \
  -e 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' \
  -e 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="0"/' \
  -e 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' \
  -e 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' \
  /etc/snapper/configs/home
```
 
`root` ai default di snapper (timeline oltre al gancio pacman). `snap-pac` di suo snapshotta solo `root`: nessuna configurazione necessaria per escludere `home` dal gancio pacman (comportamento di default).
 
Timer:
 
```bash
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
sudo systemctl enable --now btrfs-scrub@-.timer
sudo systemctl enable --now btrfs-scrub@mnt-bulk.timer
```
 
**Verificato:** installazione/rimozione di prova (`tree`) genera coppia pre/post in `snapper -c root list`, correttamente numerata.
 
---
 
## 12. NVIDIA (moduli aperti, DKMS)
 
```bash
sudo pacman -S nvidia-open-dkms nvidia-utils dkms linux-headers linux-lts-headers
```
 
Verifica build per entrambi i kernel prima di proseguire:
 
```bash
dkms status
# nvidia/<versione>, <ver-lts>, x86_64: installed
# nvidia/<versione>, <ver-arch>, x86_64: installed
```
 
I pacchetti `*-dkms` rigenerano da soli l'initramfs a ogni build (loro `dkms.conf`): nessun pacman hook manuale necessario per tenere driver e initramfs allineati.
 
Moduli per l'early KMS (fuori albero, non coperti dall'hook `kms`) e parametro di modesetting per Wayland:
 
```bash
sudo sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
echo 'options nvidia_drm modeset=1' | sudo tee /etc/modprobe.d/nvidia.conf
sudo mkinitcpio -P
```
 
**Verificato dopo il riavvio:** `nvidia-smi` risponde (RTX 3060 Ti), `lsmod | grep nouveau` vuoto, moduli `nvidia*` caricati.
 
---
 
## 13. Sessione grafica minima
 
```bash
sudo pacman -S hyprland xorg-xwayland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk pipewire wireplumber pipewire-pulse pipewire-alsa kitty
```
 
**Hyprland 0.55+ usa Lua, non più il vecchio `hyprland.conf`.** Config in `~/.config/hypr/hyprland.lua`:
 
```lua
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
 
local terminal = "kitty"
local mainMod  = "SUPER"
 
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
```
 
`kb_layout` non impostato: resta il default della tastiera di sistema finché la scelta compose-key/`us-intl` non è chiusa.
 
Nessun display manager: login su TTY, poi avvio con il wrapper corretto (non il binario `Hyprland` nudo — serve per l'integrazione systemd, es. portali):
 
```bash
systemctl --user enable --now pipewire pipewire-pulse wireplumber
start-hyprland
```
 
**Verificato:** sessione avviata, `SUPER+Invio` apre `kitty`, `SUPER+M` chiude la sessione, audio (`wpctl status`) e rete attivi. XWayland non testato isolatamente: verifica rimandata a Steam (Fase successiva).
 
---
 
## 14. Strumenti di uso quotidiano (editor, file manager, browser)
 
**Convenzione — risoluzione dipendenze virtuali.** Alcuni pacchetti dipendono da un nome virtuale soddisfatto da più provider (pacman chiede quale scegliere). Scelte fissate qui per essere identiche su `razer`:
 
| Dipendenza virtuale | Richiesta da | Scelto | Motivo |
|---|---|---|---|
| `ttf-font-nerd` | `yazi` (icone) | `ttf-iosevkatermslab-nerd` | — |
| `jack` | `librewolf` | `pipewire-jack` (non `jack2`) | Lo stack audio è già `pipewire`+`wireplumber` (Fase 13): un secondo server audio indipendente (`jack2`) duplicherebbe quello che c'è già. `pipewire-jack` è un layer di compatibilità sullo stesso demone, non un secondo server. |
| `ttf-font` | `librewolf` | `ttf-dejavu` | — |
 
Elencando i pacchetti concreti nella stessa transazione, pacman non chiede nulla (la dipendenza virtuale risulta già soddisfatta):
 
```bash
sudo pacman -S neovim yazi fzf fd bat zoxide librewolf ttf-iosevkatermslab-nerd pipewire-jack ttf-dejavu
```
 
Bind aggiunti in `~/.config/hypr/hyprland.lua` (browser, file manager — pattern identico al template ufficiale):
 
```lua
local terminal     = "kitty"
local browser      = "librewolf"
local fileManager  = "kitty -e yazi"
local mainMod      = "SUPER"
 
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
```
 
**Browser:** `librewolf` (T0, `extra` dall'agosto 2026). Da annotare nel registro pacchetti dell'architettura — non è un file che aggiorno io.
 
---
 
**Shell.** `useradd -s /usr/bin/zsh` imposta solo la shell di login: nessun `.zshrc` viene generato (niente skeleton zsh in `/etc/skel`).
 
```bash
cat > ~/.zshrc <<'EOF'
# Cronologia
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS SHARE_HISTORY
 
# Completamento
autoload -Uz compinit
compinit
 
# Integrazioni
eval "$(zoxide init zsh)"
source <(fzf --zsh)
EOF
```
 
`source <(fzf --zsh)` (fzf ≥0.48, su Arch siamo ben oltre): un'unica riga per keybinding e completamento, niente percorsi `/usr/share` hardcoded.
 
---
 
## 15. Chiave SSH (locale, verso `mini`)
 
Generata su `zotac`, non ancora distribuita: `mini` va reinstallato, non ha senso autorizzare una chiave su un sistema in dismissione.
 
```bash
ssh-keygen -t ed25519 -C "flavio@zotac" -f ~/.ssh/id_ed25519
```
 
Passphrase impostata (stessa logica delle passphrase LUKS: la chiave apre l'accesso al server). Deploy della chiave pubblica in `~/.ssh/authorized_keys` su `mini`: rimandato a dopo la sua reinstallazione.
 
---
 
## 16. Repository dotfiles
 
Repository separato da questo documento: `~/phios-dotfiles`. `/etc` (NVIDIA, crypttab, fstab...) resta di competenza di questo documento; i dotfiles coprono solo spazio utente + liste pacchetti.
 
```
~/phios-dotfiles/
├── theme.sh
├── install.sh
├── hosts/
│   └── zotac.txt
└── modules/
    ├── base/
    │   ├── packages.txt
    │   └── .config/{zsh/.zshrc, zsh/theme.zsh.tmpl, yazi/theme.toml.tmpl, nvim/init.lua}
    │   └── .zshenv
    ├── desktop-environment/
    │   ├── packages.txt
    │   └── .config/{hypr/hyprland.lua, kitty/kitty.conf, kitty/theme.conf.tmpl}
    └── nvidia/
        └── packages.txt
```
 
`hosts/zotac.txt`:
```
base
desktop-environment
nvidia
```
 
Pacchetti:
```bash
# modules/base/packages.txt
zsh
zsh-history-substring-search
git
zoxide
fzf
fd
bat
yazi
ttf-iosevkatermslab-nerd
neovim
nnn
gettext
 
# modules/desktop-environment/packages.txt
hyprland
xorg-xwayland
xdg-desktop-portal-hyprland
xdg-desktop-portal-gtk
pipewire
wireplumber
pipewire-pulse
pipewire-alsa
pipewire-jack
kitty
librewolf
ttf-dejavu
 
# modules/nvidia/packages.txt
nvidia-open-dkms
nvidia-utils
dkms
linux-headers
linux-lts-headers
```
 
`install.sh`:
 
```bash
#!/usr/bin/env bash
set -euo pipefail
 
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="$(< /etc/hostname)"
MANIFEST="$REPO/hosts/$HOST.txt"
 
[[ -f "$MANIFEST" ]] || { echo "Manca hosts/$HOST.txt" >&2; exit 1; }
 
while read -r module; do
  [[ -z "$module" ]] && continue
  MOD="$REPO/modules/$module"
  [[ -d "$MOD" ]] || { echo "Modulo sconosciuto: $module" >&2; exit 1; }
 
  if [[ -f "$MOD/packages.txt" ]]; then
    sudo pacman -S --needed $(cat "$MOD/packages.txt")
  fi
 
  find "$MOD" -type f ! -name packages.txt ! -name '*.tmpl' | while read -r f; do
    rel="${f#$MOD/}"
    target="$HOME/$rel"
    mkdir -p "$(dirname "$target")"
    ln -sfr "$f" "$target"
  done
 
  find "$MOD" -type f -name '*.tmpl' | while read -r f; do
    rel="${f#$MOD/}"; rel="${rel%.tmpl}"
    target="$HOME/$rel"
    mkdir -p "$(dirname "$target")"
    ( set -a; source "$REPO/theme.sh"; set +a
      envsubst < "$f" > "$target" )
  done
done < "$MANIFEST"
```
 
Note strutturali:
- `.zshenv` non è templabile né spostabile sotto `ZDOTDIR`: deve restare in `$HOME` per vincolo di zsh stesso (è il primo file letto, prima che `ZDOTDIR` esista).
- File `.tmpl`: resi in un file reale (non symlink) a ogni esecuzione, sorgente `theme.sh` per le variabili. Non vanno editati sul target: sovrascritti al prossimo `install.sh`.
- Simlink relativi (`ln -sfr`): sopravvivono a spostamenti dell'intera cartella home (backup/restore, clone su altra macchina), non a un semplice `mv` della cartella `phios-dotfiles` isolata — in quel caso basta rilanciare `install.sh`, che li ricrea.
- Override per-host (personalizzazioni non da propagare): meccanismo non ancora costruito, rimandato a un caso reale.
`theme.sh` — palette applicata (monocromo, semantici denaturati, accento rosa pastello):
 
```bash
export PHI_BG="#1a1918"
export PHI_SURFACE="#242320"
export PHI_FG_DIM="#7d786f"
export PHI_FG="#d6d1c9"
export PHI_ACCENT="#d3a0ac"
export PHI_ERROR="#b57b73"
export PHI_WARN="#c0a874"
export PHI_SUCCESS="#8fa77e"
export PHI_INFO="#7f95ab"
```
 
**Stato:** commit locale fatto, push rimandato a quando `mini` avrà un servizio git (attualmente da reinstallare, vedi nota Fase 15).
 
---
 
## 17. Steam e libreria giochi
 
Multilib, di sistema (`/etc`), non nei dotfiles — stesso confine già tracciato per `nvidia`:
 
```bash
sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
sudo pacman -Sy
```
 
Modulo `gaming` nei dotfiles:
 
```bash
mkdir -p ~/phios-dotfiles/modules/gaming
cat > ~/phios-dotfiles/modules/gaming/packages.txt <<'EOF'
steam
lib32-nvidia-utils
lib32-vulkan-icd-loader
vulkan-tools
EOF
echo "gaming" >> ~/phios-dotfiles/hosts/zotac.txt
~/phios-dotfiles/install.sh
```
 
`lib32-nvidia-utils` esplicito: soddisfa la dipendenza virtuale `lib32-vulkan-driver` di `steam` senza il prompt interattivo (provider corretto per NVIDIA, non i default AMD/Intel).
 
**Libreria giochi su `/mnt/bulk/games`** (già pianificato, D1 zotac-installazione.md): Steam → Impostazioni → Storage → aggiungi drive → seleziona `/mnt/bulk/games` → imposta come predefinita. La libreria in `~/.local/share/Steam` resta (client + cache, non rimovibile, per design di Steam) ma non riceve più nuove installazioni.
 
**Avvio senza interfaccia:**
```bash
steam -silent &          # avvio in background, nessuna finestra libreria
steam -applaunch <appid>  # avvia un gioco già installato
```
`steamcmd` e i frontend TUI di terze parti (es. `steam-tui`) scartati: entrambi richiedono AUR (`Q-01` non risolta) e nessuno dei due elimina la necessità del client reale in background per giochi con DRM — verificato, non solo per principio.
 
**Recupero libreria da backup su SSD esterno** (metodo, non i singoli giochi):
```bash
sudo mount /dev/sdX1 /mnt/extssd     # ntfs3 nel kernel, nessun pacchetto aggiuntivo
```
Per ogni gioco: avviare l'installazione da Steam su `games`, mettere in pausa subito dopo la creazione di cartella e manifest, chiudere Steam, sostituire i file con `rsync` dalla copia esterna, riavviare Steam e usare "Verifica integrità dei file di gioco". Evita di riscrivere i manifest a mano (fragile, spesso ignorato da Steam se il formato non è esatto).
 
**Verifica:** un gioco si avvia — chiude Fase 13.
 
---
 
## 18. Bluetooth (MX Master 3)
 
In `base`, non `desktop-environment`: nessuna dipendenza da sessione grafica, utile anche su `mini` headless.
 
```bash
echo -e "bluez\nbluez-utils" >> ~/phios-dotfiles/modules/base/packages.txt
~/phios-dotfiles/install.sh
sudo systemctl enable --now bluetooth.service
```
 
Pairing via `bluetoothctl` (TUI nativo):
```
power on
agent on
default-agent
scan on
pair XX:XX:XX:XX:XX:XX
trust XX:XX:XX:XX:XX:XX
connect XX:XX:XX:XX:XX:XX
```
 
`trust` è la parte che conta per la persistenza: BlueZ ≥5.65 (qui 5.87-2) accende l'adattatore da solo all'avvio per default, nessuna modifica a `main.conf` necessaria.
 
`install.sh` non gestisce ancora l'abilitazione di servizi systemd — `systemctl enable --now` resta un passo manuale, da ripetere identico su `mini`/`razer`. Gap noto, non ancora risolto nello script.
 
**Verificato**: pairing riuscito, riconnessione confermata.
 
---
 
## 19. Strumenti aggiuntivi e temi
 
Pacchetti, per modulo:
 
```bash
# modules/base/packages.txt (aggiunte)
rsync
tesseract
tesseract-data-eng
7zip
unrar
poppler
imagemagick
ffmpeg
ripgrep
jq
resvg
btop
 
# modules/desktop-environment/packages.txt (aggiunte)
alsa-utils
zathura
zathura-pdf-mupdf
imv
cliphist
wl-clipboard
```
 
`tesseract-data-eng` richiede `tesseract` esplicito nella stessa transazione (dipendenza virtuale multi-provider, stesso schema di `ttf-font-nerd`/`jack`). `unrar` accanto a `7zip`: il codec RAR interno di `7z` è incompleto (fallisce su RAR5/metodi recenti con "Unsupported Method", limite noto del progetto, non del pacchetto scelto) — `unrar` copre la maggior parte dei casi, ma un residuo può restare non estraibile da `yazi` stesso (richiede `unrar` diretto da terminale in quel caso).
 
`mpv` **non installato**: personalizzazione rimandata a una fase di stilizzazione avanzata, per esplicita scelta.
 
### Yazi — plugin git e segni espliciti
 
```bash
cat > ~/phios-dotfiles/modules/base/.config/yazi/init.lua <<'EOF'
require("git"):setup {
    order = 1500,
}
EOF
```
 
In `yazi.toml`:
```toml
[[plugin.prepend_fetchers]]
url = "*"
run = "git"
group = "git"
 
[[plugin.prepend_fetchers]]
url = "*/"
run = "git"
group = "git"
```
 
In `theme.toml.tmpl`, segni ASCII espliciti (non i default del plugin, per evitare dipendenza da copertura glifi del font):
```toml
[git]
unknown_sign   = "?"
ignored_sign   = "I"
untracked_sign = "+"
unstaged_sign  = "M"
staged_sign    = "S"
added_sign     = "A"
deleted_sign   = "D"
updated_sign   = "U"
clean_sign     = "."
 
unstaged = { fg = "${PHI_WARN}" }
staged   = { fg = "${PHI_SUCCESS}" }
added    = { fg = "${PHI_SUCCESS}", bold = true }
deleted  = { fg = "${PHI_ERROR}" }
untracked = { fg = "${PHI_INFO}" }
```
 
**Verificato**: stati git distinti correttamente nella lista file.
 
### Neovim — tema, percorso corretto
 
```bash
mkdir -p ~/phios-dotfiles/modules/base/.config/nvim/lua
```
Il file va in `.config/nvim/lua/theme.lua`, non nella radice di `.config/nvim/` — `require("theme")` cerca solo sotto `lua/`.
```lua
-- modules/base/.config/nvim/lua/theme.lua.tmpl
vim.api.nvim_set_hl(0, "Normal", { bg = "${PHI_BG}", fg = "${PHI_FG}" })
vim.api.nvim_set_hl(0, "Comment", { fg = "${PHI_FG_DIM}", italic = true })
vim.api.nvim_set_hl(0, "CursorLine", { bg = "${PHI_SURFACE}" })
vim.api.nvim_set_hl(0, "Visual", { bg = "${PHI_SURFACE}" })
vim.api.nvim_set_hl(0, "Search", { bg = "${PHI_ACCENT}", fg = "${PHI_BG}" })
vim.api.nvim_set_hl(0, "ErrorMsg", { fg = "${PHI_ERROR}" })
vim.api.nvim_set_hl(0, "WarningMsg", { fg = "${PHI_WARN}" })
```
`init.lua` invariato: `require("theme")`. **Verificato**: nessun errore, colori applicati.
 
### Btop — tema attivato
 
```bash
mkdir -p ~/phios-dotfiles/modules/base/.config/btop/themes
# themes/phi.theme.tmpl — vedi Fase 14/16 per i token, invariato
 
cat > ~/phios-dotfiles/modules/base/.config/btop/btop.conf <<'EOF'
color_theme = "phi"
theme_background = False
EOF
```
Creare il file `.theme` non basta: `color_theme` in `btop.conf` deve referenziarlo esplicitamente. **Stato attuale**: configurazione ampliata a mano direttamente da Flavio oltre il minimo qui sopra (supporto GPU incluso, verificato presente in `btop` ufficiale senza bisogno di `nvtop`) — il file nel repository è quello reale in uso, non questa versione minima.
 
### Kitty — font non modificato
 
Un tentativo di impostare `font_family` è stato annullato (`sed -i '/^font_family/d' kitty.conf`): resta il font di default. Non era la causa dei segni mancanti in `yazi` (risolta sopra, a livello di segni espliciti).
 
### Rimandato, esplicitamente
 
- **Ventole case/CPU** (`lm_sensors`+`fancontrol`): non installato, in attesa — decisione rimandata da Flavio.
- **Curva ventole GPU** (`CoolerControl`, AUR): in attesa dell'esito di un test sotto carico reale.
- **VR** (`WiVRn`): non ancora implementato, sessione dedicata a parte.
---
 
## Note
 
- `discard=async` viene attivato da Btrfs sugli SSD anche se non specificato. Non confligge con `fstrim.timer`, che copre anche i filesystem non-Btrfs.
- Nel chroot `bootctl` non scrive le variabili EFI. La voce nella NVRAM va registrata dopo il primo avvio.
