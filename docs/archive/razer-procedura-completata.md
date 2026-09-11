# razer — Procedura di installazione (compilata)
 
Documento compilato a partire dai comandi realmente eseguiti, non dal piano. Aggiornato solo dopo step confermati riusciti (principio del progetto). Sostituisce la versione "piano" caricata a inizio sessione.
 
Hardware confermato in Fase 1: Razer Book 13 (2020), RZ09-0357, i7-1165G7 (Tiger Lake), Iris Xe, 16GB RAM, NVMe Micron 2400 512GB (`Micron_2400_MTFDKBA512QFM`, 476.9G reali), AX201 Wi-Fi, audio SOF (`sof-audio-pci-intel-tgl`), webcam USB/UVC (IMC Networks / Azurewave a seconda del tool), nessuna soglia di carica batteria disponibile.
 
**Stato: installazione core completa (Fasi 1-19).** Restano solo Fase 20 (backlog non bloccante) e Fase 21 (rimandato esplicitamente) — entrambe fuori perimetro per questa sessione.
 
---
 
## Prerequisiti (prima della Fase 1)
 
- Secure Boot disattivato, CSM già disattivato di fabbrica.
- Firmware aggiornato da Windows prima del wipe: Windows Update, poi Razer Updater in ordine — Intel firmware, Thunderbolt L, Thunderbolt R, BIOS, keyboard firmware.
---
 
## 1. Live ISO — identificazione hardware
 
```bash
ls /sys/firmware/efi/efivars
lsblk -d -o NAME,MODEL,SIZE
timedatectl
passwd
systemctl start sshd
```
 
Rilevato: `nvme0n1` (Micron 2400, 476.9G) come unico disco. CPU i7 confermato (poi esattamente i7-1165G7 via `powertop` in Fase 14).
 
```bash
dmidecode -t processor | grep -i version
lspci -nnk | grep -iA3 -E 'network|audio|multimedia|camera'
lsusb
ls /sys/class/power_supply/
cat /sys/class/power_supply/BAT*/charge_control_start_threshold 2>&1
cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>&1
```
 
Risultati:
- Network: Intel AX201 `[8086:a0f0]`, driver `iwlwifi`.
- Audio: Intel 500 Series HD Audio `[8086:a0c0]`, driver `sof-audio-pci-intel-tgl` → richiede `sof-firmware` (non nei `packages.txt` esistenti, aggiunto in Fase 12).
- Webcam: presente solo in `lsusb`, assente in `lspci` → USB/UVC standard, `uvcvideo` in-kernel, nessun driver fuori albero necessario.
- Soglie di carica batteria: entrambi i file assenti → nessuna gestione soglie possibile su questo hardware (confermato, non un'ipotesi).
**Deviazione — Wi-Fi non rilevato:** `iwctl device list` restituiva lista vuota. Diagnosi (`ip link show`, `lspci -k`, `dmesg`): `iwlwifi 0000:00:14.3: probe with driver iwlwifi failed with error -110` (ETIMEDOUT), causa più probabile mai un vero power-cycle a freddo del controller radio dopo Windows Fast Startup/Modern Standby. Fix:
```bash
poweroff
```
seguito da riaccensione completa da spento (non riavvio). Risolto: interfaccia `wlo1` comparsa, Wi-Fi connesso e verificato via `ping`.
 
---
 
## 2. Partizionamento
 
Disco singolo `/dev/nvme0n1`. Distruttivo, eseguito dopo conferma firmware.
 
```bash
wipefs -a /dev/nvme0n1
blkdiscard /dev/nvme0n1
sgdisk --zap-all /dev/nvme0n1
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI"        /dev/nvme0n1
sgdisk -n 2:0:0   -t 2:8309 -c 2:"phios-root" /dev/nvme0n1
partprobe /dev/nvme0n1
```
 
Risultato: `nvme0n1p1` (1G, EFI, vfat), `nvme0n1p2` (475.9G, `phios-root`, crypto_LUKS).
 
---
 
## 3. Cifratura
 
Un solo contenitore, nessuna cascata (a differenza di `zotac`, disco singolo).
 
```bash
cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 system
```
 
UUID LUKS: `e672e3de-cf67-4ada-bce4-eec7e288c73d` (confermato da `/proc/cmdline` in Fase 14, dopo il fix di Fase 8).
 
---
 
## 4. Filesystem e subvolumi
 
```bash
mkfs.fat -F32 -n EFI /dev/nvme0n1p1
mkfs.btrfs -f -L phios-root /dev/mapper/system
```
 
**Deviazione — due tentativi falliti prima del terzo riuscito:**
1. Primo tentativo senza `-f`: fallito, probe ambiguo su un device che in precedenza ospitava NTFS (Windows) — probabile superblock secondario non ripulito da un `wipefs` sul disco intero eseguito prima del partizionamento. Non un problema di dati: il device era comunque destinato a essere formattato.
2. Nel mezzo, un riavvio (test Wi-Fi) ha chiuso il mapping LUKS (runtime, non sopravvive al reboot). Il secondo tentativo falliva su un device ormai inesistente.
3. Riaperto `cryptsetup open` e rilanciato con `-f`: riuscito.
UUID filesystem Btrfs: `0ba1df41-7099-4aa8-b06e-ff48764b8f41`.
 
```bash
mount /dev/mapper/system /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@usercache
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@games
umount /mnt
 
O="noatime,compress=zstd:1,ssd"
mount -o $O,subvol=@ /dev/mapper/system /mnt
mkdir -p /mnt/{home,.snapshots,boot,var/log,var/cache,swap}
mount -o $O,subvol=@home      /dev/mapper/system /mnt/home
mount -o $O,subvol=@snapshots /dev/mapper/system /mnt/.snapshots
mount -o $O,subvol=@log       /dev/mapper/system /mnt/var/log
mount -o $O,subvol=@cache     /dev/mapper/system /mnt/var/cache
mount -o $O,subvol=@swap      /dev/mapper/system /mnt/swap
mount /dev/nvme0n1p1 /mnt/boot
```
 
`@usercache` e `@games` creati ma non montati qui: dipendono da `/home/flavio`, utente non ancora esistente in questa fase (stesso motivo di `zotac`).
 
Swapfile per l'ibernazione — dimensione 20GB (formula RAM + √RAM, standard Red Hat/Fedora, 16+4):
 
```bash
btrfs filesystem mkswapfile --size 20G /mnt/swap/swapfile
btrfs inspect-internal map-swapfile -r /mnt/swap/swapfile
swapon /mnt/swap/swapfile && swapoff /mnt/swap/swapfile && echo OK
```
 
Resume offset: `533760`. Nessun `chattr +C` manuale necessario: `mkswapfile` (btrfs-progs ≥6.1) imposta No_COW e crea il file di swap in un solo passaggio.
 
**Verificato:** `findmnt -R /mnt` pulito, ID subvolume in sequenza attesa (256→262), test `swapon`/`swapoff` senza errori.
 
---
 
## 5. Sistema base
 
```bash
pacstrap -K /mnt \
  base linux linux-lts linux-firmware intel-ucode \
  btrfs-progs cryptsetup dosfstools efibootmgr \
  networkmanager openssh sudo \
  zsh git vim nano fwupd
```
 
Nessun `base-devel`, niente `zram-generator` (a differenza di `zotac`/`mini`: lo swapfile serve solo all'ibernazione, 16GB RAM bastano senza zram per l'uso quotidiano).
 
```bash
ROOT=$(blkid -s UUID -o value /dev/mapper/system)
EFI=$(blkid -s UUID -o value /dev/nvme0n1p1)
O="rw,noatime,compress=zstd:1,ssd,space_cache=v2"
 
cat > /mnt/etc/fstab <<EOF
UUID=$ROOT   /                     btrfs  $O,subvol=/@            0 0
UUID=$ROOT   /home                 btrfs  $O,subvol=/@home        0 0
UUID=$ROOT   /.snapshots           btrfs  $O,subvol=/@snapshots   0 0
UUID=$ROOT   /var/log              btrfs  $O,subvol=/@log         0 0
UUID=$ROOT   /var/cache            btrfs  $O,subvol=/@cache       0 0
UUID=$ROOT   /home/flavio/.cache   btrfs  $O,subvol=/@usercache   0 0
UUID=$ROOT   /home/flavio/games    btrfs  $O,subvol=/@games       0 0
UUID=$ROOT   /swap                 btrfs  $O,subvol=/@swap        0 0
UUID=$EFI    /boot                 vfat   rw,relatime,fmask=0137,dmask=0027,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro 0 2
/swap/swapfile none swap defaults 0 0
EOF
```
 
---
 
## 6. Configurazione di sistema
 
```bash
arch-chroot /mnt
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
hwclock --systohc
 
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
printf 'LANG=en_US.UTF-8\nLC_PAPER=it_IT.UTF-8\n' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf
 
echo 'razer' > /etc/hostname
cat > /etc/hosts <<'EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   razer.localdomain razer
EOF
 
passwd
useradd -m -G wheel -s /usr/bin/zsh flavio
passwd flavio
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
visudo -c
 
mkdir -p /home/flavio/.cache /home/flavio/games
systemctl enable NetworkManager sshd fstrim.timer
```
 
Locale: inglese pieno + `LC_PAPER=it_IT.UTF-8`, tastiera US con compose key, timezone Europe/Rome (come da ADR069). Nessun `chown` qui su `.cache`/`games`: i mount reali arrivano solo da fstab al boot (Fase 9).
 
---
 
## 7. Initramfs
 
```bash
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt resume filesystems fsck)/' /etc/mkinitcpio.conf
sed -i "s/^PRESETS=.*/PRESETS=('default' 'fallback')/" /etc/mkinitcpio.d/linux.preset
sed -i 's|^#fallback_image=|fallback_image=|'     /etc/mkinitcpio.d/linux.preset
sed -i 's|^#fallback_options=|fallback_options=|' /etc/mkinitcpio.d/linux.preset
mkinitcpio -P
```
 
`resume` tra `sd-encrypt` e `filesystems`: deve leggere un device già decifrato, e deve intervenire prima del mount normale.
 
---
 
## 8. Bootloader
 
**Deviazione — due errori distinti, entrambi corretti:**
 
1. `bootctl install` eseguito **dentro** `arch-chroot`: le voci NVRAM venivano scritte ma con device path azzerato (`HD(0,GPT,00000000-...,0x0,0x0)`) — stesso meccanismo-causa del bug già visto su `mini` (chroot confonde la risoluzione del device reale), sintomo diverso (lì niente veniva scritto, qui veniva scritto ma vuoto). Fix, da **fuori** chroot:
```bash
efibootmgr -b 0003 -B
efibootmgr -b 0004 -B
bootctl --esp-path=/mnt/boot --variables=yes install
```
Risultato corretto verificato: `HD(1,GPT,f68fb3d1-2491-45e1-b70b-69788cc7946e,0x800,0x200000)` — GUID reale, offset 1MiB, size 1GiB (la partizione EFI).
 
2. Le entry generate con `root=UUID=<uuid-btrfs>` **mancavano** il parametro che dice all'initramfs quale LUKS sbloccare (`rd.luks.name=`). Conseguenza: al primo riavvio reale, boot bloccato a tempo indeterminato su "A start job is running for /dev/disk/by-uuid/...", nessun prompt passphrase mai mostrato. Fix (dalla live, montando solo l'ESP, senza riaprire LUKS/Btrfs):
```bash
mount /dev/nvme0n1p1 /mnt/boot
sed -i "s|root=UUID=0ba1df41-7099-4aa8-b06e-ff48764b8f41|rd.luks.name=e672e3de-cf67-4ada-bce4-eec7e288c73d=system root=/dev/mapper/system|" /mnt/boot/loader/entries/phios*.conf
```
 
Entry finale (le tre varianti — default, LTS, fallback — identiche a parte kernel/initrd):
```
title   phiOS
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options rd.luks.name=e672e3de-cf67-4ada-bce4-eec7e288c73d=system root=/dev/mapper/system rootflags=subvol=@ rw resume=UUID=0ba1df41-7099-4aa8-b06e-ff48764b8f41 resume_offset=533760
```
 
`loader.conf`:
```
default  phios.conf
timeout  3
console-mode keep
editor   no
```
 
Boot0000 (Windows Boot Manager) rimosso in seguito (`efibootmgr -b 0000 -B`). Effetto collaterale scoperto alla rimozione: lo slot NVRAM liberato è stato riassegnato dal firmware alla voce "Fallback Linux Boot Manager", che ha ereditato il vecchio device path `VenHw(...)` di Windows invece del proprio — corretto con `bootctl install` rieseguito sul sistema reale (non in chroot), che ha ricreato la entry con path corretto.
 
---
 
## 9. Primo riavvio
 
```bash
umount -R /mnt
cryptsetup close system
reboot
```
 
**Verificato:** richiesta passphrase LUKS, boot completato, login `flavio` su TTY, `wlo1` UP dopo configurazione NetworkManager (vedi Fase 11).
 
```bash
sudo chown flavio:flavio /home/flavio/.cache /home/flavio/games
```
 
Bug noto (già visto su `zotac`, qui su due directory invece di una): fstab monta le subvolume `@usercache`/`@games` come `root:root` al boot, va corretto manualmente una volta.
 
---
 
## 10. Snapshot (`snapper`)
 
```bash
sudo pacman -S snapper snap-pac
 
sudo umount /.snapshots
sudo rmdir /.snapshots
sudo snapper -c root create-config /
sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo mount -a
sudo chmod 750 /.snapshots
 
sudo snapper -c home create-config /home
sudo sed -i \
  -e 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="0"/' \
  -e 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' \
  -e 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="0"/' \
  -e 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' \
  -e 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' \
  /etc/snapper/configs/home
 
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
sudo systemctl enable --now btrfs-scrub@-.timer
```
 
Stesso workaround di `zotac` per il conflitto tra `@snapshots` (nostro, da fstab) e quello che `snapper create-config` genererebbe da sé. Nessun `btrfs-scrub@mnt-bulk.timer`: era per il secondo disco di `zotac`, qui non esiste.
 
---
 
## 11. Rete (Tailscale)
 
```bash
sudo pacman -S tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up
```
 
**Verificato:** `tailscale status` mostra `razer` nel tailnet insieme a `mini`, `flavios-macbook-pro`, `iphone-12-pro`. `ping mini` risponde via MagicDNS (`mini.taild3c272.ts.net`).
 
---
 
## 12. Chiave SSH e dotfiles
 
```bash
ssh-keygen -t ed25519 -C "flavio@razer" -f ~/.ssh/id_ed25519
ssh-copy-id -i ~/.ssh/id_ed25519.pub flavio@mini
ssh flavio@mini echo ok
```
 
Riuscito al primo tentativo (password auth ancora attiva su `mini`).
 
```bash
sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
sudo pacman -Sy
 
git clone flavio@mini:/srv/git/phios-dotfiles.git ~/phios-dotfiles
cd ~/phios-dotfiles
git remote add github https://github.com/phiOS-git/phios-dotfiles.git
```
 
Branch di default: `master` (non `main`). Verificato `git log --oneline -1` = `02987b8`, combaciante con lo stato atteso.
 
**Fix dotfiles — `sof-firmware` mancante** (trovato in Fase 1):
```bash
echo "sof-firmware" >> ~/phios-dotfiles/modules/desktop-environment/packages.txt
git add modules/desktop-environment/packages.txt
git commit -m "desktop-environment: aggiungi sof-firmware (audio SOF confermato su razer, Tiger Lake)"
git push origin master
git push github master
```
 
```bash
~/phios-dotfiles/install.sh
```
 
**Deviazione — prompt interattivo non previsto:** `pacman` ha chiesto di scegliere un provider per `vulkan-driver` (13 opzioni) durante l'installazione del modulo `gaming`, perché nell'ordine di `hosts/razer.txt` `gaming` precede `razer` (che fornisce `vulkan-intel`). Risolto scegliendo `vulkan-intel` (opzione 7) manualmente. **Fix di ordinamento eseguito successivamente** (`gaming` spostato dopo `razer` in `hosts/razer.txt`, commit e push su `origin`/`github`): elimina il prompt in reinstallazioni future.
 
```bash
sudo usermod -aG plugdev,openrazer flavio
```
 
Necessario per `openrazer-daemon` (pacchetto `extra`, non AUR — verificato — tira `openrazer-driver-dkms` e `python-openrazer` come dipendenze dirette).
 
**Verificato**: `dkms status` mostra `openrazer-driver/3.12.4` installato su entrambi i kernel. `pacman -Qi sof-firmware` conferma `2025.12.2-1` installato.
 
**Nota — sequenza rischiosa individuata a posteriori**: `sof-firmware` installato qui mentre il sistema era già acceso, senza un riavvio reale subito dopo. I test di ibernazione sono iniziati prima di quel riavvio (vedi Fase 13) — questo ha prodotto ore di diagnosi audio su un sintomo che era in realtà solo una conseguenza dell'ordine delle operazioni, non un problema del pacchetto. **Lezione per `mini` e future macchine**: dopo aver installato qualunque pacchetto che tocca un driver hardware (audio, grafica, rete), fare un riavvio reale *prima* di iniziare a testare suspend/hibernate — altrimenti un eventuale probe fallito si congela nell'immagine di ibernazione e sopravvive identico a ogni resume successivo, mascherandosi da bug persistente.
 
---
 
## 13. Sospensione (suspend-then-hibernate) — verificata e chiusa
 
```bash
sudo mkdir -p /etc/systemd/sleep.conf.d /etc/systemd/logind.conf.d
 
sudo tee /etc/systemd/sleep.conf.d/10-hibernate-delay.conf <<'EOF'
[Sleep]
AllowSuspendThenHibernate=yes
HibernateDelaySec=30min
EOF
 
sudo tee /etc/systemd/logind.conf.d/10-lid.conf <<'EOF'
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleSuspendKey=suspend-then-hibernate
EOF
 
sudo systemctl restart systemd-logind
```
 
**Causa reale del problema audio apparso qui** (non un difetto di questo meccanismo): `sof-firmware` era stato installato in Fase 12 senza un riavvio reale successivo. I cicli di ibernazione di questa fase hanno congelato ed eternamente ripristinato lo stato di probe *fallito* del driver audio (un resume da ibernazione richiama `.resume()`/`.thaw()`, mai un nuovo `.probe()` — per questo il sintomo sembrava un bug persistente di sistema quando era solo l'ordine delle operazioni). Anche l'avviso ACPI "Hardware changed while hibernated" osservato durante i primi test rientra nella stessa catena di resume-su-resume senza mai un boot a freddo nel mezzo.
 
**Verificato, chiuso**: dopo un riavvio reale, audio funzionante; verificato stabile sia su ciclo di solo suspend (rientro entro il minuto) sia su ciclo completo di ibernazione → riavvio, partendo da uno stato sano. `HibernateDelaySec` fissato a 30 minuti dopo conferma.
 
`IdleAction` deliberatamente non configurato in `logind.conf`: la gestione dell'inattività è rimandata a `hypridle` quando arriverà la sessione Hyprland (Fase 15), per evitare due gestori di idle in conflitto.
 
---
 
## 14. Gestione energia (TLP)
 
```bash
systemctl status power-profiles-daemon --no-pager
sudo systemctl enable --now tlp.service
sudo tlp-stat -s
sudo powertop --html=/tmp/powertop-razer.html
```
 
`power-profiles-daemon` non installato, nessun conflitto. `tlp-stat -s` conferma rilevamento corretto di AC/batteria (`Mode = battery` / `AC`). `powertop` eseguito come diagnostica una tantum (non `--auto-tune`, per non sovrapporsi a TLP): nessun problema critico segnalato, la maggior parte dei suggerimenti di runtime-PM rientra in ciò che TLP gestisce di default. Nessuna soglia di carica configurabile (confermato assente in Fase 1).
 
---
 
## 15. Sessione grafica — verificata
 
```bash
systemctl --user enable --now pipewire pipewire-pulse wireplumber
start-hyprland
```
 
I tre servizi PipeWire non erano attivi di default (Arch non auto-abilita servizi utente all'installazione del pacchetto) — abilitati una volta con `enable --now`, persistente da qui in avanti, nessuna ripetizione necessaria ai prossimi login.
 
**Verificato dall'utente**: bind `SUPER+Return`/`B`/`E`, touchscreen, sessione Wayland attiva, audio (dopo la correzione di Fase 13 — vedi causa reale lì).
 
## 16. Gaming — verificato
 
```bash
vulkaninfo --summary
```
**Verificato**: `Intel(R) Iris(R) Xe Graphics (TGL GT2)`, driver Mesa open source, nessun errore ICD. Libreria Steam configurata su `~/games`, gioco installato e giocato con successo.
 
Nota: Steam ha creato `~/games/SteamLibrary/steamapps/` (con sottocartella `SteamLibrary`), diverso dalla struttura piatta di `zotac` (`steamapps` diretto in `/mnt/bulk/games`). Causa probabile: la struttura piatta su `zotac` implica che `steamapps/` esistesse già in quel path prima di aggiungerlo come libreria (Steam usa una cartella preesistente così com'è); qui invece Steam ha creato la libreria da zero via GUI, e in quel caso nidifica sempre sotto `SteamLibrary` — comportamento standard, non un difetto di questa installazione. Omologazione rimandata (non urgente, richiede "Sposta contenuto" dalla GUI Steam per non rompere i manifest).
 
## 17. Bluetooth — verificato
 
```bash
sudo systemctl enable --now bluetooth
bluetoothctl show
```
**Verificato**: `Powered: yes`, mouse accoppiato e connesso con successo.
 
## 18. Webcam — verificata e chiusa
 
```bash
ls /dev/video*
mpv av://v4l2:/dev/video0
```
 
**Verificato**: `/dev/video0` è il sensore RGB reale, 1280x720, colore — cattura confermata funzionante, sufficiente per videolezioni/screen sharing (lo scopo dichiarato di questa fase). `/dev/video1` e `/dev/video3` falliscono all'apertura (`VIDIOC_G_INPUT` non supportato): nodi metadata attesi, non stream video reali, nessuna azione.
 
**Scoperta utile per il backlog (Fase 20, face unlock)**: `/dev/video2` è un sensore separato, monocromatico (`gray`, 640x360) — quasi certamente la camera IR per Windows Hello già annotata come presente. Immagine scura senza un driver che sincronizzi l'illuminatore IR, comportamento atteso per un sensore non pilotato. Conferma comunque che il sensore IR è raggiungibile via V4L2 standard (non IPU6/MIPI proprietario) — utile per quando si affronterà `howdy`/`howdy-next`, non ora.
 
## 19. Touchscreen — **fase nuova, non presente nel piano originale**
 
Hardware confermato presente (`powertop`: `Touchscreen (ELAN)`, `I2C Device i2c-ELAN0406:00`). Aggiunta in seguito a segnalazione esplicita.
 
```bash
cat /proc/bus/input/devices | grep -B2 -A8 -i elan
```
 
**Verificato:** due dispositivi ELAN distinti, non uno solo — il touchpad (`Bus=0018`, I2C, `ELAN0406:00`, handler `Mouse`/`Touchpad`) e il touchscreen vero (`Bus=0003`, USB, `04f3:2cc0`, handler con assi `ABS` multi-touch reali). Entrambi riconosciuti dal kernel senza driver fuori albero. **Verificato in sessione Hyprland (Fase 15):** tocco riconosciuto correttamente da libinput, nessuna configurazione necessaria.
 
## 20. Backlog avanzato — non bloccante
 
Face unlock (IR confermato per Windows Hello, rischio driver se webcam fosse IPU6 — non è il caso qui, è USB/UVC, ma `howdy`/`howdy-next` restano AUR-only, tensione con Q-01). Chroma lighting "smart" (base tecnica pronta: `openrazer-daemon` installato, trigger/effetti tutti da progettare).
 
## 21. Rimandato esplicitamente
 
VR (nessuna feature per `razer`), backup (ADR058, attivare al primo dato reale), sync `~/cloud` universitario (non chiuso a livello di ecosistema), shell desktop completa (§8.2 architettura, ancora TBD).
 
---
 
## Punti aperti — da chiudere prima di considerare l'installazione completa
 
Nessuno — tutti i punti aperti sono stati chiusi: `hosts/razer.txt` riordinato (gaming dopo razer), `Boot0000` (Windows Boot Manager) rimosso e la voce "Fallback Linux Boot Manager" ricreata con path reale dopo che il primo `-B` aveva lasciato un residuo del vecchio device path Windows in un altro slot NVRAM riciclato.