# phiOS — Procedura base: `mini`
 
Solo passi eseguiti e verificati. Riferimento: `mini`, 2026-09-02/03.
 
---
 
## 1. Live ISO — hardware reale
 
```bash
ls /sys/firmware/efi/efivars
lsblk -d -o NAME,MODEL,SIZE
dmidecode -t memory | grep -i size
lspci -nn | grep -iE "isa bridge|lpc"
```
 
Riscontrato: `sda` è un **HDD meccanico** (`APPLE HDD HTS545050A7E362`, 465.8G), non un SSD come assunto in `phios-architettura.md`/`mini-installazione.md` — nessun flag `ssd`, nessun `fstrim.timer`/`blkdiscard` in tutta l'installazione. RAM: 2×2GiB confermati (warning DMI benigno, comune su firmware Apple). LPC: `8086:9c43`, Intel 8 Series (Lynx Point), usato in Fase 9 per `AFTERG3_EN`.
 
Accesso SSH dalla live:
```bash
passwd
systemctl start sshd
ip -brief address
```
 
## 2. Partizionamento (`/dev/sda`)
 
```bash
wipefs -a /dev/sda
sgdisk --zap-all /dev/sda
sgdisk -n 1:0:+1G   -t 1:ef00 -c 1:"EFI"        /dev/sda
sgdisk -n 2:0:+100G -t 2:8300 -c 2:"phios-root" /dev/sda
sgdisk -n 3:0:0     -t 3:8309 -c 3:"phios-data" /dev/sda
partprobe /dev/sda
```
 
`sda1` ESP 1G, `sda2` root **non cifrata** 100G, `sda3` `data` cifrata resto disco (~364.8G). Root non cifrata per costruzione (§4.4.1): deve avviarsi da sola per il riavvio autonomo dopo blackout.
 
## 3. Cifratura (solo `sda3`)
 
```bash
cryptsetup luksFormat --type luks2 /dev/sda3
cryptsetup open /dev/sda3 data
```
 
## 4. Filesystem e subvolumi
 
```bash
mkfs.fat -F32 -n EFI /dev/sda1
mkfs.btrfs -L phios-root /dev/sda2
mkfs.btrfs -L phios-data /dev/mapper/data
 
mount /dev/sda2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@usercache
umount /mnt
 
O="noatime,compress=zstd:1"
mount -o $O,subvol=@ /dev/sda2 /mnt
mkdir -p /mnt/{home,.snapshots,boot,var/log,var/cache}
mount -o $O,subvol=@home      /dev/sda2 /mnt/home
mount -o $O,subvol=@snapshots /dev/sda2 /mnt/.snapshots
mount -o $O,subvol=@log       /dev/sda2 /mnt/var/log
mount -o $O,subvol=@cache     /dev/sda2 /mnt/var/cache
mount /dev/sda1 /mnt/boot
cryptsetup close data
```
 
`data` non ha subvolumi propri né fstab a questo punto: struttura interna creata solo quando serve (§13).
 
## 5. Sistema base
 
```bash
pacstrap -K /mnt \
  base linux linux-lts linux-firmware intel-ucode \
  btrfs-progs cryptsetup dosfstools efibootmgr \
  openssh sudo \
  zsh git vim nano \
  man-db man-pages texinfo \
  zram-generator
```
 
`intel-ucode` (CPU Intel, non AMD). Niente `networkmanager` (→ `systemd-networkd`), niente `base-devel` (rimandato a quando serve una build reale).
 
fstab scritto a mano (non `genfstab`):
```bash
ROOT=$(blkid -s UUID -o value /dev/sda2)
EFI=$(blkid -s UUID -o value /dev/sda1)
O="rw,noatime,compress=zstd:1,space_cache=v2"
cat > /mnt/etc/fstab <<EOF
UUID=$ROOT   /                     btrfs  $O,subvol=/@            0 0
UUID=$ROOT   /home                 btrfs  $O,subvol=/@home        0 0
UUID=$ROOT   /.snapshots           btrfs  $O,subvol=/@snapshots   0 0
UUID=$ROOT   /var/log              btrfs  $O,subvol=/@log         0 0
UUID=$ROOT   /var/cache            btrfs  $O,subvol=/@cache       0 0
UUID=$ROOT   /home/flavio/.cache   btrfs  $O,subvol=/@usercache   0 0
UUID=$EFI    /boot                 vfat   rw,relatime,fmask=0137,dmask=0027,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro 0 2
EOF
```
 
## 6. Configurazione di sistema (in `arch-chroot /mnt`)
 
```bash
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf
 
echo 'mini' > /etc/hostname
cat > /etc/hosts <<'EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   mini.localdomain mini
EOF
 
passwd
useradd -m -G wheel -s /usr/bin/zsh flavio
passwd flavio
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
 
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF
cat > /etc/sysctl.d/99-zram.conf <<'EOF'
vm.swappiness = 150
vm.page-cluster = 0
EOF
 
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/20-wired.network <<'EOF'
[Match]
Name=en*
[Network]
DHCP=yes
EOF
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
systemctl enable systemd-networkd systemd-resolved sshd
```
 
`NetworkManager` scartato per `mini`: la motivazione in architettura (§6, riga 665) è la mobilità di `razer`, non applicabile a un server cablato fisso. Fix esterno al chroot: `resolv.conf` reale va corretto da `/mnt/etc` (bind mount del chroot mostra quello della live).
 
## 7. Initramfs
 
```bash
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)/' /etc/mkinitcpio.conf
```
 
Niente `sd-encrypt` (root non cifrata). Fallback solo su `linux-lts` (primario):
```bash
sed -i "s/^PRESETS=.*/PRESETS=('default' 'fallback')/" /etc/mkinitcpio.d/linux-lts.preset
sed -i 's|^#fallback_image=|fallback_image=|'     /etc/mkinitcpio.d/linux-lts.preset
sed -i 's|^#fallback_options=|fallback_options=|' /etc/mkinitcpio.d/linux-lts.preset
mkinitcpio -P
```
 
## 8. Bootloader
 
Kernel: **`linux-lts` primario, `linux` fallback** (invertito rispetto a `zotac`, per ADR068).
 
```bash
bootctl --variables=yes install
systemctl enable systemd-boot-update.service
 
cat > /boot/loader/loader.conf <<'EOF'
default  phios-linux-lts.conf
timeout  0
console-mode keep
editor   no
EOF
 
FS=$(blkid -s UUID -o value /dev/sda2)
for k in linux-lts linux; do
  cat > /boot/loader/entries/phios-$k.conf <<EOF
title   phiOS ($k)
linux   /vmlinuz-$k
initrd  /intel-ucode.img
initrd  /initramfs-$k.img
options root=UUID=$FS rootflags=subvol=@ rw
EOF
done
cat > /boot/loader/entries/phios-fallback.conf <<EOF
title   phiOS (fallback)
linux   /vmlinuz-linux-lts
initrd  /intel-ucode.img
initrd  /initramfs-linux-lts-fallback.img
options root=UUID=$FS rootflags=subvol=@ rw
EOF
 
echo "blacklist efi_pstore" > /etc/modprobe.d/blacklist-efi-pstore.conf
bootctl random-seed
```
 
**`--variables=yes` obbligatorio**: bug noto di `systemd` ≥257 (`systemd/systemd#36174`), `bootctl` scambia `arch-chroot` per un container e salta la scrittura NVRAM in silenzio senza quel flag. Verificato con `efibootmgr -v`: device path con GUID/size reali (non `00000000...`), altrimenti la voce è scritta ma punta a nulla.
 
`timeout 0` (non `3` come `zotac`): nessuno è fisicamente presente a leggere un menu su un headless.
 
## 9. Riavvio e verifica quirk Mac mini
 
Boot reale confermato: `linux-lts` (`uname -r` → `6.18.48-...`), rete via DHCP, `zram0` attivo.
 
**Blackout — `AFTERG3_EN`** (offset `0xA4`, bit 0, bridge LPC `00:1f.0`; bit=0 → riaccensione automatica, bit=1 → resta spento — semantica invertita rispetto al nome):
```bash
pacman -S pciutils
sudo tee /usr/local/bin/afterg3-set.sh > /dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
val=$(setpci -s 00:1f.0 0xa4.w)
new=$(printf '%04x' $(( 0x$val & 0xfffe )))
setpci -s 00:1f.0 0xa4.w="$new"
EOF
sudo chmod 755 /usr/local/bin/afterg3-set.sh
 
sudo tee /etc/systemd/system/afterg3-poweron.service > /dev/null <<'EOF'
[Unit]
Description=Azzera AFTERG3_EN (riaccensione automatica dopo blackout)
DefaultDependencies=no
After=sysinit.target
Before=basic.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/afterg3-set.sh
[Install]
WantedBy=sysinit.target
EOF
sudo systemctl enable --now afterg3-poweron.service
 
echo "blacklist b43" | sudo tee /etc/modprobe.d/blacklist-b43.conf
```
 
**Verificato empiricamente**, non solo configurato: spina staccata fisicamente e ricollegata → riavvio automatico senza intervento. Boot headless (monitor scollegato) → SSH raggiungibile, confermato.
 
`blacklist b43`: chip Wi-Fi interno 802.11ac che il driver `b43` (solo fino a `n`) non supporta — irrilevante per costruzione (`mini` solo cablato), tolto di mezzo il tentativo fallito nel log.
 
## 10. Snapshot (`snapper`)
 
Solo `root`, niente config `home` separata (a differenza di `zotac`): `/home/flavio` su `mini` non contiene dati di lavoro, solo config già in git.
 
```bash
sudo pacman -S snapper snap-pac
sudo umount /.snapshots
sudo rmdir /.snapshots
sudo snapper -c root create-config /
sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo mount -a
sudo chmod 750 /.snapshots
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
sudo systemctl enable --now btrfs-scrub@-.timer
```
 
## 11. Rete (Tailscale)
 
```bash
sudo pacman -S tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up
```
 
Nessun tag/subnet-router/ACL: non decisi, non necessari ora.
 
## 12. Chiave SSH
 
Chiavi di `zotac` e MacBook autorizzate in `~/.ssh/authorized_keys` di `flavio`. Password disattivata:
```bash
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl reload sshd
```
 
## 13. Servizio git leggero
 
Deployment: **unit systemd native**, non container — `Q-33` chiusa per `mini`. I servizi pianificati (git, Navidrome) non hanno dipendenze invasive (tabella T3 dell'architettura riserva i container a quel caso specifico).
 
`/srv` vive su `data` (sda3), montata manualmente (nessun crypttab automatico — coerente con lo sblocco via SSH, non a cascata come su `zotac`):
```bash
sudo cryptsetup open /dev/sda3 data
sudo mkdir -p /srv
echo '/dev/mapper/data  /srv  btrfs  noauto,noatime,compress=zstd:1,space_cache=v2  0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount /srv
```
 
Repository bare per `phios-dotfiles`, path canonico da architettura (§9.2.1, riga 921):
```bash
sudo mkdir -p /srv/git
sudo chown flavio:flavio /srv/git
chmod 750 /srv/git
git init --bare /srv/git/phios-dotfiles.git
```
 
`zotac`, `razer` (futuro) e MacBook puntano `origin` a `flavio@<ip>:/srv/git/phios-dotfiles.git` via SSH; `mini` stesso punta `origin` a `/srv/git/phios-dotfiles.git` come **path locale** (nessuna chiave SSH verso se stesso). GitHub resta come specchio secondario (`remote: github`).
 
## 14. Dotfiles
 
```bash
git clone https://github.com/phiOS-git/phios-dotfiles.git ~/phios-dotfiles
~/phios-dotfiles/install.sh
```
 
`hosts/mini.txt`: `base` + `server` (nuovo modulo, per ora solo `README.md` come segnaposto). `bluez`/`bluez-utils` spostati da `base` a `desktop-environment` (non servono su un headless). Font nerd resta in `base` invariato: costo nullo in RAM, inerte su `mini` per costruzione (nessun rendering locale, nessuna console TTY che usi font TTF).
 
`ya pkg add yazi-rs/plugins:git` eseguito a mano (non tracciato nei dotfiles, gap noto).
 
---
 
## 15. `/srv/git` — correzione a subvolume
 
Creato inizialmente come directory semplice (§13), corretto a subvolume per poter dare in futuro retention indipendente (coerente con §9.2.1 architettura: un subvolume per libreria):
```bash
sudo mv /srv/git /srv/git.bak
sudo btrfs subvolume create /srv/git
sudo chown flavio:flavio /srv/git
sudo mv /srv/git.bak/phios-dotfiles.git /srv/git/
sudo rmdir /srv/git.bak
```
Path finale invariato, nessun impatto sui remote già configurati sulle altre macchine.
 
## 16. Musica — Navidrome
 
Pacchetto ufficiale (`extra`, non AUR — `Q-01` non si applica):
```bash
sudo mkdir -p /srv/media
sudo btrfs subvolume create /srv/media/music
sudo chown flavio:flavio /srv/media/music
sudo chmod 755 /srv/media/music
 
sudo pacman -S navidrome
echo 'MusicFolder = "/srv/media/music"' | sudo tee -a /etc/navidrome/navidrome.toml
sudo systemctl enable --now navidrome
```
Utente/gruppo dedicato creato dal pacchetto (`sysusers.d`), `755` sufficiente per la lettura. Accesso: `http://<tailscale-ip>:4533`. Ruolo: backend/API Subsonic per un client custom (streaming, sync playqueue, transcodifica), non l'interfaccia web bundle — quella resta inutilizzata ma non è un costo (stessa porta, stessa autenticazione, raggiungibile solo via Tailscale).
 
## 17. Monitoraggio
 
Livello minimo deciso in `mini-installazione.md` §6: unit fallite, SMART, spazio disco. Notifica via `ntfy.sh` (istanza pubblica, nessun account, topic privato generato e salvato in `/etc/ntfy-topic`).
 
```bash
TOPIC="mini-$(tr -dc 'a-z0-9' </dev/urandom | head -c16)"
echo "$TOPIC" | sudo tee /etc/ntfy-topic
sudo chmod 600 /etc/ntfy-topic
 
sudo tee /usr/local/bin/notify.sh > /dev/null <<EOF
#!/bin/bash
TOPIC="$TOPIC"
if [ "\$#" -gt 0 ]; then MSG="\$*"; else MSG=\$(cat); fi
curl -s -d "\$MSG" "https://ntfy.sh/\$TOPIC" > /dev/null
EOF
sudo chmod 755 /usr/local/bin/notify.sh
```
 
SMART (già installato §_hardware_, qui collegato alla notifica):
```bash
sudo pacman -S smartmontools
echo '/dev/sda -a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -m <nomailer> -M exec /usr/local/bin/notify.sh' | sudo tee /etc/smartd.conf
sudo systemctl enable --now smartd
```
 
Unit fallite — drop-in globale, non ripetuto per servizio:
```bash
sudo mkdir -p /etc/systemd/system/service.d
sudo tee /etc/systemd/system/service.d/notify-on-failure.conf > /dev/null <<'EOF'
[Unit]
OnFailure=unit-failure-notify@%n.service
EOF
sudo tee /etc/systemd/system/unit-failure-notify@.service > /dev/null <<'EOF'
[Unit]
Description=Notifica fallimento di %i
[Service]
Type=oneshot
ExecStart=/usr/local/bin/notify.sh "mini: unit fallita: %i"
EOF
sudo systemctl daemon-reload
```
 
Spazio disco (`/`, `/srv`, soglia 90%, timer giornaliero):
```bash
sudo tee /usr/local/bin/check-diskspace.sh > /dev/null <<'EOF'
#!/bin/bash
for mp in / /srv; do
  use=$(df --output=pcent "$mp" | tail -1 | tr -dc '0-9')
  [ "$use" -ge 90 ] && /usr/local/bin/notify.sh "mini: spazio disco basso su $mp ($use%)"
done
EOF
sudo chmod 755 /usr/local/bin/check-diskspace.sh
sudo tee /etc/systemd/system/check-diskspace.service > /dev/null <<'EOF'
[Unit]
Description=Controllo spazio disco
[Service]
Type=oneshot
ExecStart=/usr/local/bin/check-diskspace.sh
EOF
sudo tee /etc/systemd/system/check-diskspace.timer > /dev/null <<'EOF'
[Unit]
Description=Controllo spazio disco giornaliero
[Timer]
OnCalendar=daily
Persistent=true
[Install]
WantedBy=timers.target
EOF
sudo systemctl enable --now check-diskspace.timer
```
 
Canale pronto anche per l'esito backup (§20, non ancora costruito): stesso `notify.sh`, nessuna modifica prevista.
 
**Verificato**: notifica di prova ricevuta sul telefono.
 
---
 
## 18. `TrekStor` — cifratura (IN CORSO, non ancora completata)
 
Inventario reale (`/dev/sdb`, partizione unica `sdb1`, exFAT, etichetta `exStorage`, 465.8G), ispezionato in sola lettura:
- `Homeworks` (350G) — contenuto reale: esercizi video VR, da trattare come libreria video-VR.
- `$RECYCLE.BIN`, `System Volume Information`, `.fseventsd`, `.Spotlight-V100` — residui Windows/macOS, non dati dell'utente, eliminabili senza conseguenze.
### Decisione tecnica, dopo verifica approfondita (non presa a cuor leggero)
 
- `cryptsetup reencrypt --encrypt --reduce-device-size` (in-place, nessun dato spostato): richiede che gli ultimi 32+ MiB della partizione siano liberi da dati filesystem — precondizione esplicita della documentazione ufficiale. **Non verificabile su exFAT**: nessuno strumento maturo/ufficiale su Linux mappa l'occupazione dei cluster in coda (`exfatprogs` non offre resize; l'unico tool che si avvicina, `exfatDump`, è dichiarato sperimentale/forense dagli stessi autori). Scartato: rischio reale sull'intero archivio, non accettabile.
- Header LUKS separato (`--header`): evita la precondizione, ma il disco cifrato non è più utilizzabile su un'altra macchina con la sola passphrase — richiederebbe portare anche il file header ovunque. Scartato: contro il requisito esplicito di portabilità (l'utente deve poter usare il disco su `zotac`/`razer` collegandolo e basta).
- **Approccio scelto**: copia temporanea su `data` (363G liberi, sufficienti per i 350G) → wipe completo di `TrekStor` (sicuro, a quel punto senza dati da perdere) → `cryptsetup luksFormat` standard con header integrato → `mkfs.exfat` dentro il volume aperto → ricopia dei dati da `data` → verifica → rimozione della copia temporanea.
- exFAT confermato come filesystem anche dopo la cifratura, non da riconsiderare: unico formato leggibile nativamente su Windows/macOS/Linux con file di grandi dimensioni, richiesto esplicitamente per l'uso portabile del disco.
Nota tecnica: `tmux`/`screen` non sono installati su `mini` (non fanno parte di `base`) — per processi lunghi sopravvissuti a una disconnessione SSH si usa `nohup ... & disown`, senza installare nulla.
 
### Stato attuale
 
Copia in corso verso `/srv/trekstor-restore-tmp` (`nohup rsync -av`, log in `~/trekstor-copy.log`).
 
### Da fare al completamento della copia — non ancora eseguito, riferimento per la sessione successiva
 
1. Verifica leggera copia: confronto conteggio file e dimensione totale tra `/mnt/trekstor-check/Homeworks` e `/srv/trekstor-restore-tmp`.
2. Smontare `/mnt/trekstor-check`; wipe di `/dev/sdb` (`wipefs -a`, `sgdisk --zap-all`).
3. Nuova partizione singola su `sdb1`; `cryptsetup luksFormat --type luks2 /dev/sdb1` (header integrato, non separato — decisione sopra).
4. `cryptsetup open /dev/sdb1 trekstor`; `mkfs.exfat -n exStorage /dev/mapper/trekstor`.
5. Ricopiare i dati da `/srv/trekstor-restore-tmp` al `TrekStor` ora cifrato; riverificare.
6. Rimuovere `/srv/trekstor-restore-tmp`.
7. **Decisione aperta, mai posta all'utente**: "altre macchine" per l'uso portabile include Windows/macOS oltre a `zotac`/`razer`? LUKS non è nativamente leggibile su Windows/macOS senza software aggiuntivo (a differenza di exFAT) — se sì, va affrontato prima di considerare chiusa la portabilità.
8. Valutare se aggiungere anche una cascata a keyfile per sblocco automatico quando collegato a `mini` (comodità), mantenendo comunque la passphrase come metodo primario e universale per le altre macchine.
9. Aggiungere `/dev/sdb1` a `/etc/smartd.conf` (rimandato dalla fase Monitoraggio §17, disco non ancora pronto in quel momento).
### Aggiornamento — lavoro SOSPESO, disco fisico giudicato inadatto
 
Il disco fisico dietro `TrekStor` è un **Seagate ST500LM012 (HN-M500MBB), 500GB, 5400rpm**, in un box USB con bridge non riconosciuto da `smartctl` (`0x1e68:0x0059` — richiede `-d sat`).
 
**Copia eseguita, non completa al 100%**: 1138 file su 1142 trasferiti con successo su `/srv/trekstor-restore-tmp` (su `data`, interno), **375.351.153.833 byte all'origine contro 360.903.837.280 byte copiati** (~14.4G di differenza). **4 file persi in modo permanente**, non recuperabili: errore I/O identico e ripetibile su due tentativi `rsync` indipendenti (non un errore di rete o una lettura marginale — danno fisico confermato sui settori specifici di quei file).
 
**Diagnosi SMART, in ordine cronologico durante la copia**:
| Momento | `Current_Pending_Sector` |
|---|---|
| Metà copia (primo controllo) | 43 |
| Durante la copia | 79 |
| Dopo copia + un secondo passaggio completo | 163 |
 
Self-test esteso (`smartctl -t long -d sat`): **`Completed: read failure` al 90% di `Remaining`** — si è fermato dopo aver scansionato solo il 10% del disco, primo errore a `LBA 37899560` (~19GB dall'inizio), `LifeTime 105 hours`.
 
**Conclusione**: la crescita dei pending sector a ogni passaggio di lettura, insieme al self-test che fallisce quasi subito, indica **degrado attivo sotto carico**, non un difetto isolato e statico da un singolo urto. Sconsigliato come supporto per un archivio cifrato a lungo termine di dati non sostituibili. `TrekStor` non è mai stato wipeato né toccato in scrittura — resta exFAT, non cifrato, esattamente come trovato, ancora montato in sola lettura su `/mnt/trekstor-check`.
 
**Stato spazio disco**: `/srv/trekstor-restore-tmp` occupa ~360.9G su `data` (che aveva 363G liberi) — **`data` è ora quasi completamente pieno**, poco margine per altro (musica, git, cloud) finché questa situazione non si risolve.
 
**Decisione in sospeso, non presa** — tre opzioni poste, nessuna scelta ancora per indisponibilità di `Gtech` e mancanza di spazio alternativo su `mini` in questo momento:
1. Lasciare i 360G su `data` temporaneamente, accettando l'occupazione di spazio pensato per altro.
2. Usare `Gtech` (1TB, portatile, mai ispezionato in questa sessione) al posto di `TrekStor` per l'archivio.
3. Procedere comunque con `TrekStor`, accettando esplicitamente il rischio di degrado ulteriore.
**Lavoro sul server sospeso a questo punto**, in attesa di una decisione su queste tre opzioni prima di poter proseguire su `TrekStor` o su qualunque cosa richieda spazio su `data`.
