# phiOS — Runbook operativo (Fla)

**Destinatario:** solo tu. Nessuna di queste operazioni può essere eseguita dall'agent.
**Riferimento:** `phios-master-plan.md`. Sequenza degli step: `phios-agent-brief.md`.
**Regola:** l'agent produce file nei repository. Tu cambi lo stato delle macchine. Nessuna eccezione.

---

## 1. Il ciclo di lavoro

Uno step alla volta sulla linea principale. Le tracce parallele non toccano le macchine e girano in sottofondo.

1. L'agent fa commit e push su **GitHub** e ti consegna tre blocchi: cosa è cambiato, cosa fare, cosa verificare.
2. Tu esegui il blocco **USER**.
3. Tu esegui il blocco **VERIFY** e incolli l'output.
4. L'agent marca lo step `verified` in `PROGRESS.md` e passa al successivo. Se qualcosa non torna, corregge nello **stesso** step.

**Non saltare la verifica.** È l'unico canale con cui l'agent sa cosa è successo davvero: non ha accesso a nessuna delle tue macchine.

### 1.1 Sincronizzazione dei remote

L'agent scrive solo su GitHub. `mini` resta la tua sorgente di verità e riceve push solo da te.

```bash
git pull github master        # prendi il lavoro dell'agent
# ... verifica ...
git push origin master        # allinea mini dopo la verifica
```

Se una verifica fallisce e l'agent corregge, ripeti il `pull` prima di riprovare. Non fare push su `origin` prima di aver verificato: `mini` deve contenere solo stati confermati.

### 1.2 Formato del feedback

Incolla l'output **grezzo**, non riassunto. Se un comando fallisce, incolla anche l'errore. Se una cosa funziona ma "non convince", dillo con parole tue: è informazione utile quanto un errore.

Se un comando ti sembra rischioso, **non eseguirlo e chiedi**. L'agent non ha modo di sapere cosa c'è di aperto sul tuo schermo.

---

## 2. Cosa fai tu, per categoria

| Categoria | Esempi |
|---|---|
| Pacchetti | `pacman -S`, `-R`, `-Si` per verificare tier e disponibilità |
| Sistema | Qualunque cosa sotto `/etc`, `/usr`, `/var` |
| Servizi | `systemctl enable`, `start`, `daemon-reload` — utente e sistema |
| Boot | `mkinitcpio`, voci `systemd-boot`, parametri kernel |
| Cifratura | Sblocco LUKS, keyfile, chiave di firma dei pacchetti |
| Diagnostica hardware | `evtest`, `python-openrazer`, `/sys/bus/iio/`, `lsusb`, `dkms status` |
| Misura risorse | `free -h`, `systemd-cgtop`, `df -h`, `btrfs filesystem usage` |
| Account nei servizi | Syncthing, Prowlarr, Jellyfin, indexer |
| Verifica visiva | Screenshot della shell, uso reale per un giorno o una settimana |

---

## 3. Prerequisiti — prima di iniziare M0

### 3.1 Verifica di compatibilità Hyprland `[rischio C-06]`

Le procedure di `zotac` e `razer` sono state scritte contro Hyprland 0.55 con la nuova configurazione Lua. In `extra` è già uscita la 0.56. L'API Lua è recente e in movimento.

```bash
hyprctl version
pacman -Qi hyprland | head -3
```

Poi apri la sessione e controlla che non compaiano avvisi di deprecazione nel log di Hyprland. Incolla entrambi all'agent: se qualcosa è deprecato va sistemato **prima** di costruire nove superfici sopra.

### 3.2 Stato di partenza dei repository

```bash
cd ~/phios-dotfiles
git remote -v          # deve mostrare origin (mini) e github
git log --oneline -3
git status
```

Se hai modifiche locali non committate su una delle due macchine, sistemale ora: la ristrutturazione di M0 le perderebbe.

---

## 4. M0 — Fondazione dei dotfiles

### 4.1 Ordine delle macchine

**`razer` per prima, poi `zotac`.** Motivo: `razer` è la macchina primaria per lo studio e ha più profili attivi (laptop, hardware Razer, gaming, Intel), quindi scopre più problemi; `zotac` è più semplice ed è la macchina di build, che ti serve funzionante per M1.

### 4.2 Sequenza per ogni macchina

```bash
cd ~/phios-dotfiles
git pull github master
bin/phios-install --dry-run          # NON applica nulla
```

Leggi l'output per intero. Deve proporre **solo file sostituiti con contenuto identico** e **nessun pacchetto da installare**. Se propone di installare o rimuovere qualcosa, fermati e segnalalo: M0 non deve cambiare nulla di funzionale.

```bash
bin/phios-install                    # applica
bin/phios-install --dry-run          # deve ora essere pulito (idempotenza)
bin/phios-install --system-diff      # sola lettura, nessun privilegio
```

Poi verifica a mano: terminale, browser, file manager, audio, rete, Steam, e su `razer` anche batteria e ibernazione.

### 4.3 Diagnostica `razer` — tasti volume e luminosità `[S-06]`

I tasti non funzionano. La retroilluminazione tastiera sì, perché passa da un percorso driver diverso. La causa probabile sono codici HID "Consumer Control" assenti dalla tabella hwdb.

```bash
sudo pacman -S evtest
sudo evtest
```

Seleziona la tastiera interna. Premi, uno alla volta, annotando il codice emesso:
volume su · volume giù · mute · luminosità su · luminosità giù — **prima da soli, poi con Fn**.

Poi identifica il dispositivo:

```bash
cat /proc/bus/input/devices | grep -A5 -i 'razer\|keyboard'
lsusb
```

E chiudi `Q-F01` (sensore di luce ambientale, serve per True Tone):

```bash
ls /sys/bus/iio/devices/
```

Se la directory è vuota o non esiste, True Tone è abbandonata definitivamente. Non è un problema: è una risposta.

Incolla tutto. Con i codici in mano l'agent scrive la regola hwdb, che applicherai in M4.

### 4.4 Capability detection

```bash
bin/phios-capabilities        # su entrambe le macchine
```

Atteso su `razer`: batteria, retroilluminazione, touchscreen, wifi, chroma presenti.
Atteso su `zotac`: gli stessi assenti, GPU NVIDIA presente.

Incolla entrambi.

---

## 5. M1 — `phi` e repository dei pacchetti propri

È la parte con più lavoro manuale del piano intero. Una volta fatta, non si ripete.

### 5.1 Toolchain sulla macchina di build (`zotac`)

```bash
sudo pacman -S base-devel devtools go pacman-contrib
```

`zotac` è la macchina di build perché ha 32 GB. `mini` **non** compila nulla.

### 5.2 Chiave di firma

Genera una chiave GPG dedicata alla firma dei pacchetti — **non** riusare una chiave esistente, e non metterla in nessun repository.

Cose da fare in questo ordine:
1. Genera la chiave su `zotac`.
2. Esporta la **pubblica** e importala nel keyring di `pacman` su `zotac`, `razer` e `mini`, firmandola localmente come attendibile.
3. Trascrivi su carta la passphrase della chiave, insieme alle due passphrase già esistenti (LUKS e repository di backup). ADR 050: le passphrase non passano dal password manager.
4. La chiave **privata** resta solo su `zotac`.

### 5.3 Repository pacman su `mini`

`/srv` è su volume cifrato, quindi va sbloccato prima.

```bash
# su mini
sudo cryptsetup open /dev/sda3 data
sudo mount /srv
sudo btrfs subvolume create /srv/pkg
sudo mkdir -p /srv/pkg/phi
sudo chown flavio:flavio /srv/pkg/phi
```

Poi serve un HTTP minimale che esponga `/srv/pkg/phi` **solo sull'indirizzo della rete overlay**, mai su ogni interfaccia. `pacman` consuma HTTP, non un mount.

**Attenzione al vincolo di disponibilità:** se `/srv` non è montato, `pacman` non trova il repository `[phi]`. Non è un guasto, ma va saputo. Aggiungi `RequiresMountsFor=` alla unit del server HTTP.

**Nota sullo spazio:** `data` è attualmente quasi pieno per via della copia temporanea da `TrekStor` (~360 GB). Va risolto prima, o il repository non ha spazio. È una decisione ancora sospesa e indipendente da questo piano.

### 5.4 Registrazione su ogni macchina

Frammento `pacman.conf` fornito dall'agent in `profiles/*/system/pacman/`. Leggilo con `--system-diff`, poi applicalo a mano.

```bash
sudo pacman -Sy
pacman -Si phi                 # deve mostrare Repository : phi
sudo pacman -S phi
phi --version
```

Se `pacman -Si phi` non lo trova: il repository non è raggiungibile, oppure la firma non è considerata attendibile. Sono due errori diversi con messaggi diversi — incolla quello che vedi.

---

## 6. M2–M5 — Shell e stilizzazione

Il lavoro è quasi tutto dell'agent. Il tuo contributo è di tre tipi.

### 6.1 Installazione

```bash
sudo pacman -S quickshell
sudo pacman -S phi-shell       # dopo che l'agent lo ha pacchettizzato
```

### 6.2 Verifica visiva

Screenshot. È l'unico modo in cui l'agent può vedere il risultato: non ha accesso a nessuno schermo.

Per iterare velocemente senza riavviare la sessione, usa l'hot reload di quickshell: salvi il file QML e la shell si ricarica. Per far ripartire la shell da zero:

```bash
qs -p ~/.config/quickshell/phi     # avvio manuale, mostra gli errori QML
```

Gli errori QML vanno incollati **integralmente**: il messaggio contiene file e riga.

### 6.3 Decisioni che tocca a te

| Quando | Domanda |
|---|---|
| S-22 | `Q-N02` — l'elenco workspace in barra è per-monitor o condiviso? Guarda il compositore e decidi |
| S-22 | `Q-N03` — btop su workspace normale a ID alto, oppure special workspace a comparsa? Sono due modelli di interazione diversi |
| S-33 | `Q-N09` — le voci del password manager entrano fra i risultati del launcher? **È una decisione di sicurezza**, non di comodità |
| S-38 | `Q-N07` — lo schema di keybinding: quale tasto fa cosa. L'agent propone, tu decidi. È la parte che memorizzerai col corpo |
| S-41 | `Q-N05` — decorazioni CSD attivate o soppresse |
| S-51 | `Q-N01` — `font-mono`: Iosevka (stretto, più colonne sul 13") o Source Code Pro (stessa superfamiglia di reading e ui). Nota: il font attuale esiste **solo** per le icone di `yazi`, quindi la sostituzione va verificata lì prima di rimuoverlo — `yazi` e `btop` con tutti i glifi al posto giusto |
| S-54 | `Q-N04` — tematizzare `systemd-boot` o lasciarlo |

### 6.4 Plymouth — step a rischio `[S-53]`

**Una macchina alla volta.** Non fare `zotac` e `razer` nella stessa sessione.

Sequenza:
1. `sudo pacman -S plymouth`
2. Aggiungi l'hook `plymouth` in `/etc/mkinitcpio.conf`, **subito dopo `systemd`** e comunque **prima** di `sd-encrypt`. Su `razer` l'hook `resume` resta dov'è, fra `sd-encrypt` e `filesystems`.
3. `sudo plymouth-set-default-theme phi`
4. `sudo mkinitcpio -P`
5. Aggiungi `quiet splash` alle voci in `/boot/loader/entries/`.
6. Riavvia.

**Cosa deve succedere:** l'animazione parte, la richiesta della passphrase LUKS è grafica, il boot completa, e su `razer` il resume da ibernazione continua a funzionare.

**Se non parte o sfarfalla:** togli l'hook, `mkinitcpio -P`, riavvia. Se non arrivi nemmeno a una shell, avvia dal **secondo kernel** dal menu, oppure fai rollback allo snapshot pre-aggiornamento. Su `zotac` c'è in più l'interazione con NVIDIA: `nvidia_drm.modeset=1` è già impostato, ma il passaggio Plymouth→sessione può comunque produrre sfarfallio.

**Lezione già appresa su `razer`, vale qui:** dopo aver installato un pacchetto che tocca un driver, fai un **riavvio reale** prima di testare sospensione o ibernazione. Altrimenti un probe fallito si congela nell'immagine di ibernazione e sopravvive a ogni resume, mascherandosi da bug persistente.

---

## 7. M6 — Servizi

### 7.1 Regola di misura, obbligatoria

`mini` ha 4 GB saldati. **Dopo ogni servizio aggiunto**, prima di aggiungere il successivo:

```bash
free -h
systemd-cgtop -n 1 --order=memory
df -h /srv /
```

Incolla i tre output. Se restano meno di **1,5 GB** liberi per page cache e picchi, ci si ferma: lo stadio 2 dello stack \*arr non si fa, e il piano registra perché.

**Non far mai sovrapporre due scansioni di libreria.** Navidrome, Jellyfin e l'hashing di Syncthing sono il picco, non il funzionamento normale. I timer vanno scaglionati.

### 7.2 Ordine di installazione su `mini`

1. **Syncthing** — misura
2. **Jellyfin** — misura
3. **qBittorrent-nox** — misura
4. **podman** e **Prowlarr** in container — misura
5. *(cancello)* Radarr e Sonarr solo se la misura lo consente

`lidarr` **non si installa**: duplica la pipeline musicale già decisa. La ricerca su indexer arriva da Prowlarr, l'ingestione resta `phi music add`.

### 7.3 Decisioni che tocca a te

| Quando | Domanda |
|---|---|
| S-65 | ClamAV su `mini`: streaming verso il `clamd` di `zotac` (semplice, trasferisce i byte) o job accodato con nodo di esecuzione (più efficiente, richiede che `zotac` raggiunga la libreria)? Si decide dopo aver misurato il volume reale |
| S-60 | `Q-N08` — come si chiama il vault universitario dentro `~/cloud`. **Non può chiamarsi `documents`**: genererebbe alberi paralleli con le directory XDG locali |
| S-61 | `Q-N06` — le foto restano sull'esterno da 1 TB o passano sull'interno? Sono classe irrecuperabile, e i dischi USB sono il rischio noto del progetto |
| S-62 | `Q-69` — convenzione di nome file per proiezione e stereoscopia dei video VR. **È lo schema di metadati**: va deciso prima di ingerire, non dopo |
| S-67 | Password manager: KeePassXC (offline, nessun servizio su `mini`) o Vaultwarden (sync automatico, ma un servizio in più su 4 GB). **Ha una conseguenza diretta**: determina se l'esclusione delle password dallo storico clipboard funziona via `x-kde-passwordManagerHint`. KeePassXC lo imposta già |

### 7.4 ClamAV — servizio residente su `zotac` e `razer`

Antivirus attivo, non solo scansione on demand. Su `mini` **non si installa**: il database firme residente sta sull'ordine di 1,2–1,5 GB, incompatibile con 4 GB condivisi.

```bash
sudo pacman -S clamav
sudo freshclam                       # primo aggiornamento firme, a mano
sudo systemctl enable --now clamav-freshclam.service
sudo systemctl enable --now clamav-daemon.service
sudo systemctl enable --now clamav-clamonacc.service
```

`clamav-daemon` va avviato **dopo** che `freshclam` ha scaricato le firme almeno una volta: senza database il daemon non parte e l'errore non è ovvio.

Verifica che la protezione in tempo reale funzioni davvero, con il file di test standard EICAR — non è malware, è una stringa concordata che ogni antivirus riconosce:

```bash
curl -s https://secure.eicar.org/eicar.com -o ~/downloads/eicar.com
journalctl -u clamav-clamonacc -n 20 --no-pager
```

Deve comparire il rilevamento. Se non compare, `clamonacc` non sta sorvegliando quel percorso.

**Su `razer`, misura il costo.** La scansione on-access consuma CPU, e su portatile questo è batteria. Usala a batteria per un giorno e riporta se è percepibile: se lo è, si condiziona all'alimentazione di rete.

**Cosa aspettarti, detto ora:** il tasso di rilevamento di ClamAV su malware nativo Linux è modesto. Il valore reale è intercettare malware Windows e macOS di passaggio e file noti nei download. È una misura utile, non una garanzia.

### 7.5 Feature indipendenti dalla shell

Queste puoi installarle in qualunque momento dopo M0, senza aspettare M6: `libreoffice-fresh` con i dizionari, `languagetool`, `anki`, `zotero`.

Su ognuna, prima di installare:

```bash
pacman -Si <pacchetto>        # conferma repository e versione reali
```

La colonna "tier" nei documenti è **indicativa**: la collocazione dei pacchetti cambia nel tempo. Se un pacchetto non è in `core`/`extra`, **fermati e segnalalo**: `Q-01` è rimandata e l'AUR non è ammesso.

---

## 8. M7 — Agente AI

### 8.1 Le prove bloccanti

`V-01`…`V-04` di `phios-agente.md` §15 sono **bloccanti**: nessuna capacità di scrittura si abilita prima del loro esito positivo.

| Prova | Cosa verifichi | Esito atteso |
|---|---|---|
| `V-01` | Leggere una chiave SSH, il portachiavi GPG, l'archivio del password manager e l'archivio posta **da dentro il contenimento** | File non trovato in ogni caso |
| `V-02` | Ambiente del processo contenuto | Nessun segreto, **e nessun socket dell'agente SSH** |
| `V-03` | Uscita di rete di A2 verso un dominio fuori lista bianca, **e con le variabili di proxy cancellate** | Negata in entrambi i casi |
| `V-04` | Avvio del servizio con il contenimento reso indisponibile | Avvio fallito, nessun processo attivo |

Se una fallisce, si corregge prima di qualunque altra cosa. Il degrado non è ammesso.

### 8.2 Prima di attivare qualunque agente

1. **Imposta un tetto di spesa presso il provider.** È l'unica misura che limita il **danno** invece della probabilità.
2. **Scrivi la procedura di revoca in anticipo**, non quando serve.
3. Una chiave per strumento, in alberi XDG distinti. Ogni chiave in più è un tetto in più da impostare e una revoca in più da ricordare.

### 8.3 Cosa cambia per te alla transizione

Passando ad A2 contenuto **perdi** l'accesso alle chiavi SSH dall'agente e la possibilità che pubblichi su remoto. A2 modifica e committa in locale; la pubblicazione è tua. È intenzionale.

---

## 9. Comandi di verifica ricorrenti

```bash
# Dotfiles
bin/phios-install --dry-run
bin/phios-install --check
bin/phios-install --system-diff

# phi
phi doctor
phi theme check
phi theme set dark --dry-run

# Sistema
systemctl --failed
systemctl --user --failed
journalctl -p err -b --no-pager | tail -30
findmnt -t btrfs,vfat -o TARGET,SOURCE,OPTIONS
snapper -c root list | tail -5

# Risorse (soprattutto mini)
free -h
systemd-cgtop -n 1 --order=memory
df -h
btrfs filesystem usage /

# Shell
qs -p <percorso>        # avvio manuale, mostra errori QML
hyprctl version
hyprctl clients -j      # per le regole finestra
hyprctl binds -j        # per il cheat sheet
```

---

## 10. Cosa fare quando qualcosa si rompe

| Sintomo | Prima mossa |
|---|---|
| Il sistema non avvia dopo un aggiornamento | Secondo kernel dal menu di boot. Da lì reinstalla il pacchetto del kernel primario, che rigenera immagine e moduli coerenti |
| Il sistema non avvia dopo un rollback | Stesso caso: un rollback riporta indietro i moduli ma **non** l'immagine del kernel, che sta sulla ESP fuori dagli snapshot |
| Sessione grafica assente su `zotac` | Aggiornamento kernel senza modulo NVIDIA. `dkms status` per confermare. Copertura tripla già in essere: DKMS, secondo kernel, snapshot pre-aggiornamento |
| La shell non parte | Avviala a mano con `qs -p` e leggi gli errori QML |
| Il tema è tornato indietro dopo un aggiornamento | L'hook pacman di rigenerazione non è attivo. `phi theme set` per rimediare subito |
| Boot bloccato dopo Plymouth | Togli l'hook, `mkinitcpio -P`, riavvia. Il secondo kernel è la rete |
| `pacman -Si phi` non trova il pacchetto | Repository irraggiungibile (`/srv` non montato su `mini`?) oppure firma non attendibile. Sono errori distinti |
| `mini` lento o servizi che muoiono | `systemd-cgtop`. Quasi sempre due scansioni sovrapposte |
| Disco pieno con spazio "libero" | Trappola Btrfs: gli snapshot trattengono i dati cancellati. `btrfs filesystem usage`, non `df`. Poi retention aggressiva |

---

## 11. Regole che non cambiano

1. **Ogni pacchetto installato entra nella lista nel momento in cui lo installi**, non dopo. Ricostruire la lista a memoria non riesce (ADR 067).
2. **Nessun indirizzo IP in nessuna configurazione.** Solo i nomi della rete overlay. Il server cambierà rete al trasloco.
3. **Nessun segreto in nessun repository**, nemmeno cifrato. Il remote GitHub è pubblico.
4. **Nessun colore o font scritto a mano** in nessun file di configurazione. Tutto generato dai token.
5. **Snapshot attivi sempre.** È durante la configurazione che è più probabile rompere qualcosa.
6. **Verifica prima di `push origin`.** `mini` contiene solo stati confermati.
7. **Se un pacchetto non è in `core`/`extra`, fermati.** `Q-01` è rimandata.
