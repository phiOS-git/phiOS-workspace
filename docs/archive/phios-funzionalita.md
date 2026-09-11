# phiOS — Funzionalità utente (zotac / razer / mini)

**Versione:** 0.2 • **Stato:** documento vivo, in compilazione
**Ultimo aggiornamento:** 2026-09-06
**Riferimento:** `phios-architettura.md` (fonte di verità per policy, invarianti, tiering software)

---

## 0. Legenda

Stessi marker di `phios-architettura.md` §0.1: `[OK]` `[TBD]` `[?]` `[BLOCK]` `[VUOTO]`.

Per questo documento:
- `[TBD]` = proposta o alternativa non ancora decisa
- `[?]` = rimanda a domanda aperta in §4
- `[HOLD]` = dipende da una verifica o decisione che avverrà in fase di configurazione, non in questa sessione di pianificazione. Non blocca il documento: si procede lo stesso, il punto resta segnato per quando ci si arriva

Vincolo `I-04` (ogni feature deve essere dimostrabilmente necessaria): ogni voce dichiara il problema risolto. Nessuna voce è ammessa "per completezza".

---

## 1. Ambito

**Casi d'uso, in ordine di priorità:**
1. Studio — psicologia (razer)
2. Lavoro — sviluppo software (razer, zotac)
3. Gaming — marginale, Steam soddisfa il requisito, nessuna feature aggiuntiva pianificata

**Macchine:** `razer` (laptop, primario per tutti e tre i casi d'uso) · `zotac` (desktop, lavoro/gaming) · `mini` (server, solo come backend di supporto per feature §3)

---

## 2. Funzionalità confermate

### 2.1 AI agent

- **Problema:** interazione con sistema e app aperte oltre la chat testuale, tramite skill esposte via MCP server
- **Macchine:** tutte, in forma diversa
- **Nota:** non trattato in questo documento. Verrà pianificato in un documento dedicato separato, da creare quando si affronta l'argomento.

### 2.2 Face unlock IR [HOLD]

- **Problema:** sblocco senza digitare la password ad ogni accesso
- **Macchina:** razer (unica con sensore IR)
- **Hardware confermato:** Razer Book 13 (2020) monta sensore IR + webcam dedicati (specifica ufficiale Razer, compatibile Windows Hello)
- **Candidati software** (nessuna scelta fatta):

| Candidato | Tier | Note |
|---|---|---|
| howdy (boltgolt) | AUR (T1) | Stack pesante: opencv, dlib, python-face_recognition; issue ricorrenti su update kernel/PAM/KScreenLocker |
| howdy-next | AUR (T1) | Riscrittura C++/meson, dipendenza `nlohmann-json` (extra); più leggero, ma resta AUR |
| authFace (pfalkingham) | Nessun pacchetto — build manuale Rust/musl (T4) | Zero dipendenze runtime, binario statico, fallback password automatico via PAM. Non è su AUR: aggira il blocco di `Q-01`, ma introduce un tier T4 (build manuale, aggiornamento non gestito da pacman) |

- **HOLD:** `Q-01` (policy AUR, `phios-architettura.md` §2.3) si risolve in fase di configurazione, non in questa sessione di pianificazione. La scelta tra i tre candidati dipende da quella decisione — non viene presa qui.

### 2.3 Interactive Chroma

- **Problema:** feedback visivo di stato (sistema, notifiche) e per-app (es. profilo dedicato in neovim)
- **Macchina:** razer (unica con tastiera RGB per-key)
- **Pacchetti:** `openrazer-daemon` + `openrazer-driver-dkms` + `python-openrazer` — tutti pacchetto base `openrazer`, repo `extra`, **T0** (verificato in questa sessione). Nessun pacchetto AUR richiesto per la funzionalità di base.
- **Scelta di scope (Fla):** nessuna interfaccia di personalizzazione. Le feature si programmano e basta. In impostazioni: solo un toggle on/off, più eventualmente un color picker per un colore statico come alternativa agli effetti dinamici (collocazione da definire in §5).
- **Meccanismo:** si scrive direttamente contro il bus DBus (`org.razer`) esposto dal daemon — via `python-openrazer` (libreria T0, API tipizzata) o chiamate dirette (`busctl`/`gdbus`, zero dipendenze aggiuntive). Non serve un client come `razer-cli` o `polychromatic`: sono interfacce di personalizzazione, fuori scope.
- **Verifica pacchetto per questo modello:** la pagina ArchWiki dedicata indica `openrazer-meta-git` (AUR), ma è probabilmente informazione datata: i changelog di openrazer 3.9 (2024) e 3.12 (2026) — le release più recenti con liste di "nuovi dispositivi" — non elencano il Book 13, il che suggerisce un supporto già presente in `extra` da anni. Non è però una conferma diretta del device ID; verifica finale consigliata con enumerazione tramite `python-openrazer`.
- **Nota:** provvisoriamente non bloccata da `Q-01`, ma condizionata a `Q-F04` (supporto del device ID nella release stabile). Se il supporto manca, si ricade su AUR e `Q-01` torna applicabile.
- **Trigger per-app:** evento `activewindow` dal socket IPC di Hyprland (non esiste hook nativo di Hyprland per questo, va scriptato)
- **Da pianificare:** script/daemon custom evento→colore, mappatura sui token base16 (accento `#d3a0ac`)

**Comportamenti richiesti da programmare:**

| Comportamento | Meccanismo | Nota |
|---|---|---|
| Illuminazione statica in idle | `hypridle` (idle daemon Hyprland) → colore statico dopo N minuti di inattività | Verificare se `hypridle` è già in uso per il lock screen su razer |
| Colore tasto power in base a batteria | DBus UPower (livello batteria) → colore tasto | Il tasto power potrebbe non essere indirizzabile singolarmente nella matrice chroma di questo dispositivo — verificare (`Q-F06`) |
| Blink riga funzione all'arrivo di notifiche | Hook sul bus notifiche desktop (`org.freedesktop.Notifications`) → blink temporaneo | Dipende dal notification daemon in uso, non ancora specificato (`Q-F05`) |
| Rosso su finestra di errore bloccante | Stesso meccanismo del trigger per-app sopra, filtrato per classe finestra dei dialoghi di errore | Nessun meccanismo nuovo, riuso diretto |
| Super premuto → illumina tasti con shortcut disponibili | Submap Hyprland: bind su pressione entra in submap che illumina i tasti, rilascio esce e ripristina | Più complesso — serve gestire pressione **e** rilascio, non un bind singolo |
| Neovim: colore contestuale a modalità/azione | Autocmd `ModeChanged` → chiamata a script esterno (`python-openrazer`/DBus) | Meccanismo diretto, nessun blocco noto |
| Indicatore mic-mute su un tasto | Stato letto da PipeWire/WirePlumber → colore tasto dedicato | Evita di parlare col microfono silenziato in videochiamate (lezioni, riunioni) |
| Pulse rosso a batteria critica | DBus UPower, soglia critica → pulse su tutta la tastiera o una riga | Fallback all'idea "power = batteria" se `Q-F06` risulta negativo — non un singolo tasto |

### 2.4 Live dark theme (toggle)

- **Problema:** cambio rapido chiaro/scuro per lettura prolungata o variazione ambientale
- **Macchine:** razer, zotac
- **Vincolo:** `I-05` — nessuna configurazione per-app, il tema si genera e si ricarica live
- **Da pianificare:** meccanismo di toggle (waybar/rofi/script), hook nella pipeline base16 esistente

### 2.5 Night Shift (filtro luce blu)

- **Problema:** affaticamento visivo in uso serale/notturno
- **Macchine:** razer, zotac
- **Strumento confermato:** `hyprsunset` — ufficiale hyprwm, richiede Hyprland ≥0.45 (protocollo `hyprland-ctm-control-v1`), sostituisce redshift/gammastep che non funzionano nativamente su Hyprland/Wayland
- **Automazione oraria/geolocalizzata:** `sunsetr` — wrapper su hyprsunset con transizioni automatiche; da valutare rispetto al controllo manuale via `hyprctl`
- **Da pianificare:** temperatura target, automatico vs manuale, binding tasti

### 2.6 True Tone (bilanciamento colore ambientale) [HOLD]

- **Problema:** affaticamento visivo diurno, bilanciamento adattivo alla luce ambientale (non solo orario, a differenza di Night Shift)
- **Macchina:** razer (zotac non ha sensore ambientale — desktop, monitor esterno — feature non applicabile lì)
- **Hardware confermato:** Razer Book 13 (2020) ha sensore di luce ambientale integrato (specifica ufficiale Razer)
- **HOLD:** `Q-F01` (supporto driver ALS via `iio-sensor-proxy` o equivalente) si verifica in fase di configurazione, non qui — non è documentato pubblicamente per questo chip specifico.
- **Nota:** non esiste un equivalente diretto di True Tone Apple su Linux; l'approssimazione realistica è temperatura colore pilotata da lux ambientale invece che da orario fisso.

### 2.7 Lettura/annotazione PDF (ex P1) [TBD]

- **Problema:** ore di lettura di paper/dispense/slide con note collegate al testo
- **Macchina:** razer
- **Candidati:**

| Candidato | Tipo | Nota |
|---|---|---|
| Zathura | TUI, `I-06` | Lettura/ricerca/SyncTeX solidi; **annotazione verificata assente** — richiesta upstream aperta dal 2018 (`git.pwmt.org/pwmt/zathura#7`), branch `feature/annotations` mai completato. Non affidabile su nessuna distro |
| Xournal++ | GTK | Annotazione completa (penna/testo, salvataggio persistente); non TUI — deroga esplicita a `I-06` |

- **[TBD] non bloccante:** l'annotazione è probabilmente necessaria, ma non urgente. La deroga `I-06` per Xournal++ resta in sospeso finché non diventa bloccante — nel frattempo Zathura copre lettura/ricerca.

### 2.8 Ripetizione dilazionata — Anki (ex P2) [HOLD]

- **Problema:** memorizzazione a lungo termine per esami
- **Macchina:** razer (uso primario)
- **Candidato:** Anki, tier probabile T0 (`extra`) — da confermare con `pacman -Si` al momento dell'installazione
- **Sync:** `anki-sync-server` (componente Rust) self-hosted su `mini`, in alternativa ad AnkiWeb
- **HOLD:** `Q-F02` — budget RAM su `mini` per il servizio di sync, si misura in fase di configurazione

### 2.9 Gestione riferimenti bibliografici — Zotero (ex P3) [HOLD]

- **Problema:** organizzare bibliografia per tesi/paper universitari
- **Macchina:** razer
- **Candidato:** Zotero — Electron, non TUI, deroga esplicita a `I-06`
- **Storage:** WebDAV self-hosted su `mini`, evita il cloud Zotero
- **HOLD:** `Q-F02` — budget RAM su `mini` per il servizio WebDAV, si misura in fase di configurazione

### 2.10 Note collegate — zettelkasten (ex P4)

- **Problema:** collegare concetti tra materie e tesi
- **Macchine:** razer (studio), zotac (eventuale uso lavoro)
- **Approccio:** markdown puro + plugin neovim, versionato via git come i dotfiles — coerente `I-06`, nessun nuovo tool di terze parti
- **Da pianificare:** scelta plugin, struttura cartelle, convenzione link

### 2.11 Gestione segreti/credenziali dev (ex P5) [TBD]

- **Problema:** i dotfiles sono su git pubblico (mirror GitHub) — le credenziali non possono starci; serve un meccanismo separato coerente su zotac e razer
- **Macchine:** zotac, razer
- **Candidati:**

| Candidato | Tipo | Nota |
|---|---|---|
| KeePassXC | Offline, `keepassxc-cli` | Nessuna dipendenza server, sync manuale del file db — nessuna dipendenza da `Q-F02` |
| Vaultwarden | Self-hosted su `mini` (Rust), client `rbw` | Sync automatico multi-macchina, ma aggiunge un servizio su `mini` — **[HOLD]** `Q-F02`, si misura in fase di configurazione |

### 2.12 Continuità clipboard zotac↔razer (ex P6)

- **Problema:** copiare uno snippet/comando tra le due macchine senza passare per file o chat
- **Macchine:** zotac, razer
- **Vincolo di scope:** deliberatamente ridotto rispetto alla sync file/cloud già in `[BLOCK]` — solo clipboard, via Tailscale
- **Da pianificare:** meccanismo (`wl-clipboard` + script su Tailscale vs tool dedicato)

### 2.13 Interfaccia di gestione pacchetti per tier

- **Problema:** visibilità sulla provenienza dei pacchetti installati (T0 `core`/`extra`, T1/T2 AUR, T4 build manuale) senza dover decidere ora la policy AUR (`Q-01`)
- **Macchine:** zotac, razer; eventualmente `mini` in forma testuale/CLI (`I-07` — nessuna sessione grafica lì)
- **Contenuto minimo:** lista pacchetti raggruppata per tier, secondo la definizione di `phios-architettura.md` §2.2
- **Quarta categoria (Fla):** oltre a T0/T1-T2/T4 manuale, una sezione separata per **phi-packages** — pacchetti da repository private mantenute da Fla su tutti i dispositivi. Diversi dal T4 manuale puro: hanno un'infrastruttura di repo propria (probabile estensione di quanto già ospitato su `mini:/srv/`), non sono build una tantum. Dove ospitare il repo e come registrarlo in `pacman.conf` su ogni macchina resta da pianificare quando si arriva a questa voce nel dettaglio.
- **Collocazione:** pannello impostazioni vs interfaccia dedicata — da decidere in §5
- **Da pianificare:** fonte dati (query `pacman`, AUR helper, registro per T4, repo phi-packages), meccanismo di refresh, eventuale collegamento al futuro `copilot phi` (CLI unificata, `I-11`)

### 2.14 Localizzazione cursore (spotlight)

- **Problema:** perdere il cursore su schermo (multitasking, schermo 13" HiDPI)
- **Macchine:** razer, zotac
- **Non esiste un tool pronto** per l'effetto richiesto (schermo scurito con un foro/cerchio intorno al cursore). Due strade possibili:

| Approccio | Meccanismo | Stato |
|---|---|---|
| Shader globale Hyprland (`decoration:screen_shader`) | Shader GLSL post-render su tutto lo schermo; richiede la posizione del cursore come uniform | **Verificato: non disponibile.** L'issue upstream `hyprwm/Hyprland#1502` che la richiedeva è chiusa senza sviluppo collegato (nessuna PR, nessun commit di riferimento) — la via nativa resta chiusa |
| Overlay layer-shell dedicato | Programma proprio che disegna la vignetta e si aggiorna a ogni movimento del cursore (via socket eventi Hyprland) | **Confermato (Fla):** si sviluppa ad hoc |

- **Riferimento vicino, non equivalente:** il plugin `hypr-dynamic-cursors` fa "shake to find" (ingrandisce il cursore se scosso) — comportamento diverso, non scurisce lo schermo.
- **Nota:** nessun impegno permanente — se il costo di manutenzione dell'overlay diventa ingestibile, la feature si sostituisce o si abbandona.

### 2.15 Volume e luminosità non funzionanti (Fn row) [HOLD]

- **Problema (corretto — non è una preferenza tra modalità Fn):** i tasti volume e luminosità schermo non hanno alcun effetto sul sistema. Il controllo della retroilluminazione tastiera invece funziona. I tasti della riga funzione stampano caratteri diversi se premuti da soli o con Fn — sintomo di codici HID non riconosciuti, non di un default da invertire.
- **Macchina:** razer
- **Diagnosi più probabile:** questa tastiera invia per Fn+volume/Fn+luminosità dei codici HID (pagina "Consumer Control") non presenti nella tabella hwdb del sistema. La retroilluminazione funziona probabilmente perché passa da un percorso diverso (intercettato direttamente da driver Razer/EC), mentre volume e luminosità restano sulla via generica evdev, che non riconoscendo i codici li mappa su caratteri arbitrari.
- **Precedente noto (stesso meccanismo, hardware diverso):** per la tastiera esterna Razer Pro Type Ultra esiste una regola hwdb pubblica che rimappa i codici "Consumer Control" non riconosciuti (es. `c00e2`→F1, `70003b`→volumedown) in `/etc/udev/hwdb.d/`. Il Book 13 verosimilmente necessita di una regola equivalente, con codici e `vendor:product ID` propri (diversi da quelli della Pro Type Ultra).
- **Percorso di diagnosi (va fatto sull'hardware, non è verificabile da remoto):**
  1. `sudo evtest` (o `sudo libinput debug-events`) premendo i tasti volume/luminosità con e senza Fn, per leggere i codici raw effettivamente emessi
  2. Identificare vendor:product ID della tastiera interna (`cat /proc/bus/input/devices` o `lsusb`)
  3. Scrivere una regola `/etc/udev/hwdb.d/` che mappa i codici osservati su `KEYBOARD_KEY_<code>=volumeup|volumedown|mute|brightnessup|brightnessdown`
  4. `sudo systemd-hwdb update && sudo udevadm trigger`
- **Nota:** l'ipotesi della sessione precedente (toggle BIOS "Action Key"/Fn-lock) era una diagnosi sbagliata — non corrisponde al problema descritto ed è stata rimossa.

---

## 3. Proposte non ancora decise

### 3.1 Trasversale

| # | Proposta | Problema risolto | Stato |
|---|---|---|---|
| P7 | Context switching automatico (profili studio/lavoro) | ridurre l'attrito nel passare da sessione di studio a sessione di coding | In attesa — da valutare dopo che almeno due tra §2.3 (Chroma), §2.4 (tema), §2.10 (note) sono pianificate/implementate |

---

## 4. Domande aperte / blocchi

| ID | Domanda | Impatta | Stato |
|---|---|---|---|
| `Q-01` | Policy AUR (vedi `phios-architettura.md` §2.3) | §2.2 | **HOLD** — si decide in fase di configurazione, non qui |
| `Q-F01` | Esiste supporto ALS (`iio-sensor-proxy` o driver IIO equivalente) sul kernel/hardware razer? | §2.6 | **HOLD** — si verifica in fase di configurazione (`ls /sys/bus/iio/devices/`), non risolvibile da ricerca |
| `Q-F02` | Budget RAM su `mini` (4GB) per nuovi servizi self-hosted | §2.8, §2.9, §2.11 | **HOLD** — si misura in fase di configurazione (`free -h`), non risolvibile da ricerca |
| `Q-F03` | Zathura supporta annotazione persistente? | §2.7 | **Risolta:** no. Richiesta upstream aperta dal 2018, branch abbandonato |
| `Q-F04` | Il device ID della tastiera Razer Book 13 (2020) è coperto da `openrazer` stabile in `extra`? | §2.3 | **Probabile sì** — i changelog 3.9 (2024) e 3.12 (2026) non lo elencano tra i nuovi dispositivi, segno di supporto già presente da anni. Conferma finale in fase di configurazione (enumerazione `python-openrazer`) |
| `Q-F05` | Quale notification daemon è in uso su razer? | §2.3 | **HOLD** — specifico alla configurazione della macchina, si verifica lì |
| `Q-F06` | Il tasto power è indirizzabile singolarmente nella matrice chroma? | §2.3 | **HOLD** — si verifica in fase di configurazione con enumerazione capacità device |
| `Q-F07` | Lo screen shader di Hyprland espone la posizione del cursore? | §2.14 | **Risolta:** no. Issue upstream `#1502` chiusa senza sviluppo — serve overlay proprio |
| ~~`Q-F08`~~ | ~~BIOS Action Key~~ | §2.15 | **Invalidata** — diagnosi sbagliata, il problema reale (volume/luminosità non funzionanti) è ridefinito in §2.15 con percorso `evtest` |

---

## 5. Gestione impostazioni

**Meccanismo (Fla):** pannello impostazioni dedicato. Alcune opzioni compaiono anche nella barra come scorciatoia, ma il pannello resta il luogo canonico in cui ogni sezione e ogni opzione elencata qui si trova — la presenza nella barra è supplementare, non sostitutiva.

**Struttura confermata:** Generali, Tema, Connettività, Dispositivi, Keybindings, AI agent, Aggiornamenti (pacchetti).

### 5.1 Generali
Hostname, modello hardware (CPU/GPU/RAM/storage), versione OS/kernel, uptime, spazio disco — vista informativa. Batteria (razer): statistiche (autonomia, cicli, salute) + opzioni tipo risparmio energetico — meccanismo non definito qui, si implementa al momento o si salta, non bloccante.

### 5.2 Tema
Toggle dark/light live (§2.4). Toggle + temperatura target per Night Shift (§2.5). Toggle True Tone se sbloccata da `Q-F01` (§2.6, `[HOLD]`). Toggle localizzazione cursore + eventuale dimensione del cerchio (§2.14). L'accento colore è fisso da design system (`#d3a0ac`, base16) — nessun controllo se non si decide di renderlo personalizzabile, il che sarebbe in tensione con l'idea di un design system unico.

### 5.3 Connettività
Stato Tailscale (connesso/disconnesso, IP overlay), Wi-Fi (razer), Bluetooth (mouse MX Master 3 su zotac, altri dispositivi accoppiati).

### 5.4 Dispositivi
Toggle e color picker Chroma (§2.3). Stato del fix volume/luminosità (§2.15 — readout "risolto/non risolto", non un controllo live). Audio: mixer, selezione dispositivo di output (PipeWire). Eventuale sensibilità mouse/trackpad.

### 5.5 Keybindings
Vista di reference delle scorciatoie Hyprland attuali. Coerente con `I-06`/minimalismo: probabilmente solo consultazione, l'editing resta nel file Lua di configurazione, non in UI.

### 5.6 AI agent
Toggle di attivazione, stato connessione. Contenuto dettagliato nel documento dedicato (§2.1) — qui solo il punto di ingresso.

### 5.7 Aggiornamenti (pacchetti)
Vista a 4 categorie (§2.13): T0 (`core`/`extra`), T1/T2 (AUR), T4 (build manuale una tantum), **phi-packages** (repo private di Fla, mantenute su tutti i dispositivi). Check aggiornamenti disponibili per categoria.

### 5.8 Mancanze ovvie (da confermare)

| Sezione proposta | Perché manca |
|---|---|
| Sicurezza | Face unlock (enroll/gestione, §2.2) e gestione segreti (§2.11) non hanno una casa nell'elenco attuale |
| Notifiche | Il blink Chroma su notifica (§2.3) e qualunque futura gestione DND non hanno una casa attuale |

## 6. Prossimi passi

1. Verifiche/decisioni in fase di configurazione (`[HOLD]`, non bloccano questo documento): `evtest` per §2.15, enumerazione `python-openrazer` per `Q-F04`/`Q-F06`, notification daemon per `Q-F05`, `/sys/bus/iio/devices/` per `Q-F01`, `free -h` su `mini` per `Q-F02`, decisione `Q-01` per §2.2
2. Confermare o scartare Sicurezza/Notifiche come sezioni di §5 (§5.8)
3. Compilare §2 elemento per elemento con pianificazione dettagliata (pacchetti, tier, comandi) — solo dopo conferma esplicita di ogni scelta architetturale, come da disciplina decisionale già in uso
4. Rivalutare P7 (§3.1) quando almeno due delle feature indicate sono pianificate
