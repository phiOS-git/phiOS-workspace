# phiOS — Piano di completamento del sistema (SSOT)
 
**Versione:** 1.0 • **Stato:** fonte unica di verità per il lavoro residuo
**Data:** 2026-09-06
**Perimetro:** completamento di `zotac` e `razer` (desktop environment), più le dipendenze server su `mini` necessarie a chiuderne le feature.
**Estende e non sostituisce:** `phios-architettura.md` (invarianti, tiering, ADR 001–083), `phios-agente.md` (ADR 084–100), `phios-piano-stilistico-finale.md`, `phios-shell-desktop.md`, `phios-funzionalita.md`.
 
---
 
## 0. Come si usa questo documento
 
### 0.1 Ruolo
 
Questo è il documento centrale. Descrive **cosa** va fatto, **in che ordine**, **con quali pacchetti e quali vincoli**, e **chi** lo fa. Non contiene procedure passo-passo né codice: quelli si studiano contestualmente allo step, come da disciplina già in uso nel progetto.
 
### 0.2 Documenti derivati
 
| File | Lingua | Destinatario | Contenuto |
|---|---|---|---|
| `phios-master-plan.md` | italiano | Fla + agent | **Questo file.** SSOT: regole, decisioni, milestone, registri |
| `phios-agent-brief.md` | inglese | Claude Code | Contratto operativo dell'agent + backlog sequenziale della linea principale (step card) |
| `phios-agent-parallel.md` | inglese | Claude Code | Tracce software indipendenti dalla configurazione macchina, sviluppabili in parallelo |
| `phios-user-runbook.md` | italiano | Fla | Operazioni riservate all'utente: pacchetti, `/etc`, systemd, diagnostica hardware, protocollo di feedback |
 
**Regola di precedenza:** in caso di conflitto vince questo file. I documenti derivati non introducono decisioni: le eseguono. Se l'agent trova un'ambiguità, si ferma e chiede — non la risolve.
 
### 0.3 Legenda
 
Stessi marker di `phios-architettura.md` §0.1: `[OK]` deciso e vincolante · `[TBD]` da decidere · `[?]` richiede input, rimanda a `Q-nn` · `[HOLD]` dipende da verifica in fase di configurazione · `[BLOCK]` bloccante · `[VUOTO]` da compilare.
 
Aggiunti in questo documento:
- `[AGENT]` — eseguibile interamente dall'agent sui repository
- `[USER]` — riservato all'utente sulla macchina reale
- `[MISTO]` — l'agent prepara, l'utente applica e verifica
### 0.4 Regole di compilazione ereditate
 
1. Nessun pacchetto entra nei registri senza approvazione esplicita.
2. Ogni `[TBD]` chiuso produce una voce ADR (§19).
3. La colonna "Tier"/"Repo" è **indicativa e da verificare** con `pacman -Si` al momento dell'installazione: la collocazione dei pacchetti cambia nel tempo.
4. Una sezione è chiusa solo con: (a) ADR, (b) config versionata, (c) verifica registrata.
---
 
## 1. Stato di partenza e perimetro
 
### 1.1 Cosa esiste già e funziona
 
| Macchina | Stato | Riferimento |
|---|---|---|
| `zotac` | Installazione completa. Btrfs+LUKS, systemd-boot, NVIDIA open DKMS, snapper, Hyprland minimale (Lua), kitty, librewolf, yazi, neovim, Steam su `/mnt/bulk/games`, Bluetooth, Tailscale | `phios-procedura-base-2.md` |
| `razer` | Installazione completa (Fasi 1–19). Ibernazione verificata, TLP, sessione Hyprland, gaming Intel, webcam, touchscreen, `openrazer-daemon` installato | `razer-procedura-completata.md` |
| `mini` | Base + Tailscale + git bare (`/srv/git`) + Navidrome + monitoraggio (`ntfy`, SMART, spazio disco, unit fallite). `/srv` su volume cifrato sbloccato a mano | `mini-procedura-base.md` |
| `phios-dotfiles` | Repo funzionante: `install.sh` bash, moduli `base`/`desktop-environment`/`laptop`/`razer`/`nvidia`/`gaming`/`server`, `theme.sh` con 9 token, template `envsubst` per kitty/yazi/btop/nvim/zsh/mpv | GitHub + `mini:/srv/git` |
 
### 1.2 Cosa manca — inventario ad alto livello
 
1. **Infrastruttura dotfiles** adeguata a un sistema completo (moduli, profili, capability detection, tema a due varianti, confine `/etc`, idempotenza, disinstallazione pulita).
2. **`phi`** — la CLI unificata non esiste.
3. **Shell desktop** — nessuna barra, nessun pannello, nessun launcher, nessun lock screen, nessuna impostazione. La sessione è un compositore nudo con quattro bind.
4. **Design system** — palette provvisoria a 9 token, una sola variante, tipografia non chiusa, nessun sistema di motion, nessuna identità Φ realizzata.
5. **Feature di sistema** — tutte quelle di `phios-funzionalita.md` §2, più le rimanenze indicate in questa sessione.
6. **Servizi server** — cloud sync, libreria foto, indicizzazione media, Jellyfin.
7. **Agente AI** — l'intero `phios-agente.md`.
8. **App client custom** — note, client Navidrome, client Jellyfin.
### 1.3 Fuori perimetro di questo piano
 
VR e Unreal Engine (`zotac`) · mobile (§12 architettura) · backup e offsite (ADR 058: si attivano al primo dato reale, con procedura propria) · `mini` come host di sessione grafica (`I-07`) · risoluzione del disco `TrekStor` degradato (decisione a sé, sospesa) · Neovim §16 architettura oltre l'integrazione col design system.
 
---
 
## 2. Regole fondanti — ciò che nessuno step può violare
 
Sintesi operativa degli invarianti e delle ADR che governano il lavoro residuo. **Ogni step va letto contro questa lista.**
 
### 2.1 Invarianti (`phios-architettura.md` §1)
 
| ID | Applicazione nel perimetro di questo piano |
|---|---|
| `I-01` | Vietato adottare configurazioni Hyprland preconfezionate, dotfile-bundle quickshell (Illogical-Impulse, Noctalia, yahr) come base. Si può **leggere** il codice altrui come riferimento; non si importa |
| `I-02` | La provenienza governa la scelta, non l'estetica. Con Q-01 rimandata (§3.3), la conseguenza è netta: **solo T0, più T3 container sul solo server dove giustificato** |
| `I-03` | Nessun software proprietario nuovo. Le deroghe restano quelle di §2.4 architettura |
| `I-04` | Ogni feature dichiara il problema risolto. Nessuna voce "per completezza". Un modulo di barra che duplica un altro modulo si toglie |
| `I-05` | **Nessun colore o font hardcoded in nessun file di configurazione, mai.** Tutto generato dai token. Vale anche per QML |
| `I-06` | TUI preferita; GUI solo se completamente tematizzabile. Le deroghe (Zotero, LibreOffice, Xournal++) restano esplicite e registrate |
| `I-07` | Nessuna dipendenza Wayland/X11 su `mini` |
| `I-08` | Cifratura at-rest già in essere. Nel perimetro: indice di ricerca file sul volume cifrato ed escluso dal sync; storico clipboard con esclusione password; nessun dato sensibile verso l'API del modello se non nel perimetro di `phios-agente.md` |
| `I-09` | Ogni configurazione applicata a mano su una macchina che non finisce nei repo è un guasto differito. Vale in particolare per `/etc` (§5.5) |
| `I-10` | Ogni app custom è debito permanente. Il criterio di §10.1 architettura si applica a ogni nuovo componente proposto |
| `I-11` | Un solo punto di ingresso CLI (`phi`), una sola identità visiva (Φ) |
 
### 2.2 ADR strutturanti già chiuse, da rispettare senza rinegoziare
 
| ADR | Vincolo |
|---|---|
| 016 | Linguaggio del software custom: **Go**. Riconsiderare Rust solo prima della seconda app TUI |
| 017 | `phi` è monolite con fallback su `phi-<nome>` nel `PATH` |
| 018 | Il launcher è un **renderer**: ranking, provider e azioni vivono in `phi` |
| 019 | Le modalità del launcher sono **dati**, non codice |
| 021 | `phi` è namespace e dispatcher, non proprietario. Due test di ammissione: composizione fra strumenti, proprietà dello stato |
| 022 | Le modalità Tab sono un acceleratore sul tipo di risultato "comando" con sotto-vista, non un meccanismo separato |
| 049 | Provisioning con script minimo più liste in testo semplice. **Niente Ansible, chezmoi, Nix** |
| 050 | Nessun segreto nel repo, nemmeno cifrato |
| 053 | Accento rosa pastello, semantici obbligatori e desaturati, token in stile base16 |
| 054 | Mono + sans + **font di soli simboli** + fallback Noto mirato. **Niente font patchati** |
| 067 | Cinque convenzioni: gruppo condiviso librerie, indirizzamento per nome (mai IP), disciplina lista pacchetti, config a colori sempre generate, snapshot attivi |
| 070 | Snapshot limitati a configurazioni e stato dei servizi; archivi esclusi per struttura |
| 072 | La sessione desktop è **una shell unica**, non componenti indipendenti |
| 073 | La shell implementa essa stessa demone di notifiche e storico clipboard |
| 074 | Profili decidono cosa si installa; **rilevamento di capacità** decide cosa si mostra |
| 075 | Cattura a scorrimento esclusa definitivamente. Non va rivalutata |
| 077 | Configurazione monitor = stato runtime, non file. Barra progettata per N monitor dal primo giorno |
| 078 | Schede del pannello laterale e moduli della barra sono **definizioni dichiarative**, non componenti codificati |
| 084–100 | Intero impianto dell'agente AI: due agenti, contenimento `bubblewrap` da vuoto, credenziale mai nel processo, memoria scrivibile solo dal client, contratto motore↔client |
 
### 2.3 Decisioni di superficie già chiuse in `phios-shell-desktop.md`
 
Non si riaprono: `quickshell` come framework unico (§0) · workspace dinamici, Steam su workspace dedicato, btop su workspace dedicato (§2) · launcher costruito dentro quickshell (§3) · notifica come icona animata con testo scorrevole, dettaglio nel pannello (§4) · lock screen quickshell nativo con PAM (§10) · screenshot costruito in casa, `wf-recorder` per il video (§11) · idle inhibit nativo per processo, `hyprsunset` per night mode (§12) · overview finestre quickshell nativa, gesture 3 dita su/giù, ambito tutte le finestre (§13) · cheat sheet keybinding in sola lettura da `hyprctl binds -j`, nessuna modifica da interfaccia (§14) · wallpaper nativo con copia in cartella dedicata (§9).
 
---
 
## 3. Decisioni prese in questa sessione
 
Tutte producono ADR in §19.
 
### 3.1 Topologia dei repository — repo separati più repo pacman proprio `[OK]`
 
| Repository | Contenuto | Distribuzione |
|---|---|---|
| `phios-dotfiles` | **Solo configurazione.** Moduli, profili, manifest host, token di design, template, materiale `/etc` non applicato, script di bootstrap | Clone diretto su ogni macchina |
| `phi` | CLI unificata in Go (nucleo + verbi) | Pacchetto `phi` nel repo `phi-packages` |
| `phi-shell` | Shell desktop quickshell (QML) | Pacchetto `phi-shell` |
| `phi-notes` | App note (M8) | Pacchetto `phi-notes` |
| `phi-music` | Client Navidrome (M8) | Pacchetto `phi-music` |
| `phi-media` | Client Jellyfin (M8) | Pacchetto `phi-media` |
| `phi-packages` | **PKGBUILD** di tutti i pacchetti propri + script di build e pubblicazione | Genera il repo pacman servito da `mini` |
 
**Meccanismo di consumo:** i pacchetti propri sono installati da `pacman` come qualunque altro, da un repository `[phi]` firmato servito da `mini` su `/srv/pkg/phi/`, registrato in `/etc/pacman.conf` di ogni macchina. I dotfiles li elencano nei `packages.txt` dei profili. Nessun submodule, nessuna build su macchina client.
 
**Conseguenze da accettare:**
- Serve una chiave di firma dei pacchetti, generata una volta e importata nel keyring di ogni macchina. È materiale `[USER]`.
- Serve `devtools` per la build in chroot pulito. La build avviene su `zotac` (32 GB, non su `mini`).
- Serve un servizio HTTP minimale su `mini` per servire `/srv/pkg/phi/` sulla rete overlay, oppure accesso `file://` via mount — **si adotta HTTP su loopback overlay**, perché è ciò che `pacman` consuma senza montaggi.
- **Ricaduta positiva:** questa è esattamente l'infrastruttura che chiuderebbe `Q-01` nella variante "repo locale firmato". Costruirla ora rende la decisione AUR futura quasi gratuita.
**Vincolo di bootstrap:** finché `phi` non è pacchettizzato, il renderer dei template resta lo script bash dei dotfiles. Il formato dei template non cambia nel passaggio: `phi theme` subentra sostituendo l'implementazione, non il contratto.
 
### 3.2 Remote di lavoro dell'agent `[OK]`
 
L'agent lavora su una macchina esterna senza accesso alla rete overlay, quindi **non può raggiungere `mini`**.
 
| Remote | Ruolo | Chi scrive |
|---|---|---|
| `github` (`github.com/phiOS-git/…`) | Remote di lavoro dell'agent, e specchio pubblico | Agent (push), Fla (pull) |
| `origin` (`flavio@mini:/srv/git/…`) | Sorgente di verità personale | Solo Fla |
 
Flusso: agent → push su GitHub → Fla `git pull github` sulla macchina → verifica → `git push origin`. Un solo verso, nessun conflitto.
 
**Conseguenza sulla sicurezza:** GitHub è pubblico. Nessun segreto, nessun IP, nessun nome di rete privata, nessun topic `ntfy`, nessuna chiave, in nessuno dei repo. Regola già in vigore (ADR 050), qui rafforzata perché l'agent scrive su un remote pubblico.
 
### 3.3 `Q-01` (policy AUR) — rimandata, con conseguenze esplicite `[OK]`
 
Decisione: **si resta a T0 finché una feature non è dimostrabilmente impossibile senza AUR.** T3 (container OCI rootless) resta ammesso sul solo server, come già previsto dal tiering (§2.2 architettura), e non è governato da `Q-01`.
 
Conseguenze immediate, da accettare:
 
| Feature | Effetto | Ripiego adottato |
|---|---|---|
| Overview finestre (`hyprexpo`, `hycov`, `hyprview`, `hymission`) | Tutti via `hyprpm` → esclusi | Nessun impatto: §13 shell-desktop aveva già deciso quickshell nativo |
| Gesture bottone MX Master su `zotac` (`logid`/`logiops`) | AUR → escluso | **`solaar` è già installato ed è T0.** Supporta la deviazione dei tasti e regole che emettono pressioni sintetiche: da verificare se copre il bottone gesture. Se non copre, restano solo i keybind |
| Face unlock IR (`howdy`, `howdy-next`) | AUR → esclusi | Feature **rimandata**. `authFace` è T4 (build manuale, aggiornamento non gestito): non si adotta ora. §2.2 `phios-funzionalita.md` resta `[HOLD]` |
| Stack \*arr (`prowlarr`, `radarr`, `sonarr`, `lidarr`) | **Tutti solo AUR** | Via T3, container rootless con immagini ufficiali upstream, su `mini`, con budget RAM misurato (§10.4) |
| `ltex-ls` per LanguageTool in Neovim | AUR/manuale | Integrazione via **API HTTP** dal plugin Neovim e da un verbo `phi`, nessun binario aggiuntivo |
 
`Q-01` resta aperta. Il trigger di riapertura è: una feature richiesta diventa impossibile senza AUR **e** non ha ripiego T0/T3. A quel punto l'infrastruttura di §3.1 (chroot pulito, repo firmato) è già in piedi e la decisione costa poco.
 
### 3.4 Sequenza: ristrutturazione dei dotfiles prima di tutto `[OK]`
 
M0 non produce feature visibili. Produce l'infrastruttura su cui tutto il resto poggia. Il criterio di uscita di M0 è che **entrambe le macchine, riapplicate dai dotfiles v2, siano funzionalmente identiche a oggi**, non migliori.
 
Motivazione: ogni step successivo aggiunge target di tema, moduli, servizi e pacchetti. Farlo sulla struttura attuale significa riscrivere tutto due volte, e la seconda volta con più codice da spostare.
 
### 3.5 Lingua `[OK]`
 
Sistema, identificatori, nomi di file, nomi di moduli, nomi di verbi, messaggi dell'interfaccia, commit: **inglese**. Documentazione di progetto per Fla: italiano. Documentazione operativa per l'agent: inglese.
 
---
 
## 4. Correzioni e incoerenze rilevate
 
Non sono opinioni: sono conflitti fra documenti o fra documenti e stato reale, e vanno chiusi.
 
| # | Rilievo | Effetto | Chiusura proposta |
|---|---|---|---|
| C-01 | `ttf-iosevkatermslab-nerd` è un **font patchato**, in conflitto con ADR 054 ("niente font patchati", font di soli simboli in fallback). **Non è una scelta stilistica**: è stato installato solo per soddisfare la richiesta di glifi icona di `yazi` | Una ADR chiusa viene violata per una ragione funzionale che si copre altrimenti | Sostituire con `ttf-nerd-fonts-symbols` (soli glifi) più il `font-mono` scelto, **coprendo esplicitamente il caso `yazi`** prima della rimozione (§6.4). Step S-51, anticipabile: non dipende dalla palette |
| C-02 | Lo stack \*arr richiesto è interamente AUR, mentre `Q-01` è rimandata | Blocco su una feature esplicitamente richiesta | T3 rootless su `mini`, staged e misurato (§10.4) |
| C-03 | `lidarr` duplica una pipeline già decisa (ADR 012, 023: fetch + catalogazione, `phi music add <sorgente>`, `beets`) | Due sorgenti di verità per la libreria musicale | **`lidarr` escluso.** La ricerca su indexer arriva da Prowlarr, l'ingestione resta `phi music add` |
| C-04 | `clamd` tiene l'intero database firme in memoria (ordine di 1,2–1,5 GB). Su `mini` (4 GB, con Navidrome, Jellyfin, Syncthing e container \*arr) è **infattibile** | Un antivirus residente non è realizzabile sul server, mentre lo è sulle altre due macchine | Servizio residente completo con scansione on-access su `zotac` (32 GB) e `razer` (16 GB). Su `mini`: nessun daemon, scansione delegata a `zotac` (§9.2) |
| C-05 | LanguageTool è un servizio JVM: heap significativo con due lingue caricate | Su `mini` compete con tutto il resto | **Servizio locale per client**, unit systemd utente **attivata su socket** su `zotac` e `razer`. Non su `mini` |
| C-06 | `hyprland` in `extra` è a **0.56.2**, mentre le procedure di `zotac`/`razer` sono state scritte contro 0.55 con la nuova configurazione Lua | L'API Lua è recente e in movimento: una config scritta ora può rompersi | Verifica di compatibilità come primo controllo `[USER]` di M0, e nota di rischio permanente (§18). Nessun pinning: Arch è rolling |
| C-07 | `cliphist` è nei pacchetti di `desktop-environment`, ma ADR 073 stabilisce che lo storico clipboard lo implementa la shell | Componente destinato a diventare ridondante | Rimozione allo step S-32, non prima. `wl-clipboard` resta (serve `wl-paste --watch`) |
| C-08 | `phios-funzionalita.md` §5.8 lascia in sospeso le sezioni **Sicurezza** e **Notifiche** del pannello impostazioni | Feature senza collocazione (face unlock, segreti, DND, blink Chroma) | **Confermate entrambe come sezioni.** Struttura finale a nove sezioni (§9.12) |
| C-09 | L'inventario barra di `razer` in `phios-piano-stilistico-finale.md` §8 non prevede la luminosità, mentre `phios-funzionalita.md` §2.15 documenta che i tasti luminosità **non funzionano** | Una feature rotta senza superficie di controllo | Diagnosi hwdb `[USER]` come prerequisito; controllo luminosità esposto nel pannello Devices e nel popover volume/luminosità, non come segmento permanente |
| C-10 | `install.sh` attuale non gestisce: abilitazione servizi systemd, plugin `yazi`, materiale `/etc`, rimozione di file non più previsti, esecuzione idempotente sicura | Deriva silenziosa fra repo e macchina, contro `I-09` | Riscrittura in M0 con manifest di stato (§5.4) |
| C-11 | Il supporto nativo alla luminosità in quickshell 0.3 è dichiarato ma il nome esatto del tipo QML non è verificato | Rischio di step bloccato | Verifica documentale `[AGENT]` prima di S-23; ripiego `brightnessctl` (già in `laptop`) via `Quickshell.Io` |
| C-12 | `phios-agente.md` non nomina il motore; `phios-architettura.md` §20 elenca `opencode` come approvato provvisorio (`Q-40`) | Ambiguità su quale binario si configura | `opencode` è in `extra` (linea stabile 1.18.x). Si adotta come motore, mantenendo il contratto di §9 dell'agente che ne consente la sostituzione. `Q-40` chiusa |
 
---
 
## 5. Dotfiles v2 — specifica strutturale
 
Obiettivo: un repository che l'agent possa modificare e l'utente possa applicare, aggiornare e verificare senza sorprese, su macchine già configurate.
 
### 5.1 Requisiti funzionali
 
| # | Requisito | Motivo |
|---|---|---|
| R1 | **Idempotenza**: eseguire l'installazione due volte non cambia nulla la seconda | Le macchine sono già configurate: la prima esecuzione della v2 è un aggiornamento, non un'installazione |
| R2 | **Anteprima**: `--dry-run` elenca ogni file che cambierebbe e ogni pacchetto che verrebbe installato, senza toccare nulla | È il modo con cui l'utente verifica il lavoro dell'agent prima di applicarlo |
| R3 | **Manifest di stato**: il repo sa quali file ha creato su questa macchina | Senza, un file rimosso dal repo resta orfano nella home per sempre |
| R4 | **Profili componibili** (ADR 074) | Una macchina nuova della stessa categoria si configura assegnando profili |
| R5 | **Rilevamento di capacità** (ADR 074) | Una sola configurazione della shell su tutte le macchine |
| R6 | **Due varianti di tema** generate insieme (chiara e scura) | `phios-piano-stilistico-finale.md` §2: entrambe permanenti |
| R7 | **Confine `/etc` esplicito**: il repo contiene il materiale di sistema ma non lo applica mai da solo | `I-09` senza violare la separazione di responsabilità agent/utente |
| R8 | **Servizi dichiarati**: ogni profilo elenca le unit systemd da abilitare, distinguendo utente e sistema | Colma il gap noto (`install.sh` non gestisce `systemctl enable`) |
| R9 | **Nessuna dipendenza oltre a coreutils, bash, git, gettext** nello stato di bootstrap | Deve funzionare su una macchina appena installata, prima che `phi` esista |
| R10 | **Verifica**: un comando che riporta la deriva fra repo e macchina | È l'input del ciclo di feedback verso l'agent |
 
### 5.2 Struttura del repository
 
```
phios-dotfiles/
├── README.md                  # cosa fa, come si esegue, cosa NON fa
├── PROGRESS.md                # stato del piano: step fatti, verificati, in attesa
├── bin/
│   ├── phios-install          # entry point unico
│   ├── phios-render           # token → config (pre-phi; sostituito da `phi theme`)
│   ├── phios-capabilities     # rilevamento capacità, output KEY=VALUE
│   └── lib/                   # funzioni bash condivise
├── design/
│   ├── tokens.common.sh       # tipografia, spaziatura, raggi, motion, z-layer
│   ├── tokens.dark.sh         # palette variante scura
│   ├── tokens.light.sh        # palette variante chiara
│   └── adapters.txt           # target: template, destinazione, comando di ricarica, classe A/B/C
├── hosts/
│   ├── zotac.txt              # elenco profili
│   ├── razer.txt
│   └── mini.txt
├── profiles/
│   └── <nome>/
│       ├── packages.txt       # pacchetti pacman
│       ├── services-user.txt  # unit systemd --user da abilitare
│       ├── services-system.txt# unit di sistema: elencate, MAI abilitate dallo script
│       ├── home/              # albero collegato in $HOME (symlink relativi)
│       ├── templates/         # sorgenti .tmpl rese in $HOME
│       └── system/            # materiale /etc: mostrato in diff, MAI applicato
└── docs/
    └── adr/                   # ADR locali ai dotfiles, se ne nascono
```
 
### 5.3 Profili
 
| Profilo | Applicato a | Contenuto |
|---|---|---|
| `base` | tutte | Shell, strumenti CLI, font, editor, utility. Nessuna dipendenza grafica |
| `desktop` | `zotac`, `razer` | Compositore, portali, audio, terminale, browser, shell phiOS |
| `laptop` | `razer` | Energia, luminosità, ibernazione, touchpad |
| `workstation` | `zotac` | Nessun risparmio energetico, monitor esterni |
| `nvidia` | `zotac` | Driver e librerie 32 bit |
| `intel-gpu` | `razer` | Mesa e librerie 32 bit |
| `razer-hw` | `razer` | `openrazer-daemon`, hwdb tastiera, sensore IR |
| `gaming` | `zotac`, `razer` | Steam e stack Vulkan a 32 bit |
| `study` | `razer` | Lettura PDF, bibliografia, ripetizione dilazionata, LibreOffice, LanguageTool |
| `server` | `mini` | Servizi, senza nulla di grafico |
 
**Ordine di applicazione:** significativo, per la risoluzione delle dipendenze virtuali (lezione già appresa su `razer`, dove `gaming` prima di `razer` produsse un prompt su `vulkan-driver`). L'ordine è quello scritto in `hosts/<host>.txt` e va mantenuto: profili che forniscono un provider concreto precedono quelli che lo richiedono.
 
### 5.4 Manifest di stato
 
File in `$XDG_STATE_HOME/phios/manifest`, non versionato. Elenca ogni percorso creato dall'installazione (symlink e file resi), con l'origine. Alla successiva esecuzione: i percorsi non più previsti vengono rimossi, gli altri riconciliati. Risolve R3.
 
### 5.5 Confine `/etc` — meccanismo `[OK]`
 
Il materiale di sistema **vive nel repo** ma non viene mai applicato dallo script.
 
| Comando | Effetto |
|---|---|
| `phios-install --system-diff` | Per ogni file in `profiles/*/system/`, mostra la differenza rispetto alla macchina. Sola lettura, nessun privilegio |
| Applicazione | Manuale, dall'utente, con `sudo`, file per file, dopo aver letto la differenza |
 
Contenuto tipico di `system/`: regole `udev`/`hwdb`, drop-in systemd di sistema, `modprobe.d`, tema Plymouth, `pacman.conf` frammenti, unit dei servizi propri, `sysctl.d`.
 
Questo chiude `I-09` (nulla vive solo nella memoria della macchina) senza violare la regola che l'agent non tocca il sistema.
 
### 5.6 Stato runtime
 
Distinto dalla configurazione versionata. Vive in `$XDG_STATE_HOME/phi/` e **non entra mai nel repo**:
 
| Voce | Scritto da |
|---|---|
| Variante di tema attiva (chiara/scura) | pannello impostazioni |
| Configurazione monitor (ADR 077) | pannello impostazioni |
| Percorso dello sfondo attivo | pannello impostazioni |
| Stato dei toggle runtime (night mode, DND, spotlight, chroma) | pannello impostazioni e barra |
| Frecency del launcher | `phi query` |
| Storico clipboard | shell |
| Storico notifiche | shell |
 
Le immagini di sfondo sono **copiate** in `$XDG_DATA_HOME/phi/wallpapers/` all'assegnazione, mai referenziate al percorso originale (requisito §9 `phios-shell-desktop.md`).
 
### 5.7 Criterio di uscita di M0
 
Su `zotac` e `razer`: `phios-install --dry-run` non riporta differenze dopo un'esecuzione completa; la sessione grafica, l'audio, la rete, il gaming e gli strumenti CLI funzionano esattamente come prima; `--system-diff` è pulito.
---
 
## 6. Design system — chiusura e contratto di generazione
 
Istanzia `phios-architettura.md` §7.1–7.7 e `phios-piano-stilistico-finale.md`.
 
### 6.1 Sorgente unica
 
`design/tokens.common.sh` + `design/tokens.dark.sh` + `design/tokens.light.sh`. Formato `KEY=VALUE`, sourceable da bash e parsabile da Go senza librerie. Nessun altro file contiene un colore o un nome di font.
 
### 6.2 Token colore — set completo
 
Estende gli attuali 9 token. Nomenclatura astratta, mai letterale (ADR 060, §7.2 architettura).
 
| Gruppo | Token | Note |
|---|---|---|
| Tier 0 — struttura | `bg-0` `bg-1` `bg-2` `bg-3` · `fg-0` `fg-1` `fg-2` `fg-3` · `border` `border-strong` · `overlay-scrim` | Progressione uniforme in **luminanza percettiva**, non in RGB |
| Tier 1 — accento | `accent` · `accent-fg` | Un solo ruolo: stato attivo/focus/interattività primaria |
| Tier 2 — semantico | `error` `warn` `success` `info` (+ varianti `-fg`) | Solo su soglia o stato. Direzione: ossido, ocra, muschio, ardesia — tutti desaturati |
| Tier 3 — sintattico | `syntax-1` … `syntax-n` | Per disambiguare categorie simultanee: codice, log, diff |
| Selezione | `selection-bg` `selection-fg` | |
| Terminale | `ansi-0` … `ansi-15` | Mappa ANSI a 16 colori derivata, non scelta a mano |
| Cursore | `cursor-term` (token separato dal cursore GUI) | §11 Classe 3 del piano stilistico |
 
**Vincoli di derivazione:**
- Spazio di lavoro **OKLCH**: la palette si deriva algoritmicamente mantenendo la luminanza costante fra le varianti.
- Contrasto minimo **4,5:1** (WCAG AA) per testo normale, **su entrambe le varianti**.
- `[AZIONE]` nota dal piano stilistico: l'accento attuale `#d3a0ac` è ~9,4:1 su nero e ~2,2:1 su bianco. **La variante chiara richiede una seconda lightness dell'accento.** Non è opzionale: senza, la variante chiara è inaccessibile.
- I colori Tier 2 attuali (`#b57b73`, `#c0a874`, `#8fa77e`, `#7f95ab`) sono una direzione di tonalità, non valori definitivi: vanno riderivati in OKLCH e verificati.
**Verifica del contrasto:** deve essere un controllo **eseguibile**, non un'ispezione visiva. Verbo `phi theme check` (o script equivalente in M0), che riporta ogni coppia sotto soglia. Vincolante prima di chiudere M5.
 
### 6.3 Token non-colore
 
| Gruppo | Token | Valore di partenza |
|---|---|---|
| Tipografia | `font-mono` `font-reading` `font-ui` `font-symbol` | Vedi §6.4 |
| Scala | `font-size-0` … `font-size-n` | Derivata, non arbitraria |
| Spaziatura | `space-1` … `space-n` | **Multiplo di `1ch` di `font-mono`** — aggancia il ritmo della GUI alla griglia a caratteri del terminale |
| Forma | `radius-base` = `2px` · `radius-pill` = pieno | `radius-base` `[PLACEHOLDER]`: verificare a schermo su HiDPI frazionario |
| Layering | `z-base` `z-bar` `z-popover` `z-modal` `z-tooltip` `z-notification` | |
| Motion | `motion-a-*` `motion-b-*` `motion-c-*` | Vedi §6.5 |
 
### 6.4 Tipografia — chiusura di `font-mono` `[TBD] → proposta`
 
Stato: `font-reading` = Source Serif 4 (`adobe-source-serif-fonts`), `font-ui` = Source Sans 3 (`adobe-source-sans-fonts`), `font-symbol` = Nerd Font di soli glifi. `font-mono` è l'unico ruolo non assegnato.
 
Correzione obbligatoria (C-01): il font attualmente installato è patchato, in conflitto con ADR 054.
 
| Candidato | A favore | Contro |
|---|---|---|
| **Iosevka** (`ttf-iosevka`) | Stretto: più colonne su schermo 13". Copertura latina estesa. Il ritmo `1ch` di §6.3 lavora meglio con una gabbia stretta | Estraneo alla superfamiglia Adobe |
| Source Code Pro (`adobe-source-code-pro-fonts`) | Terzo membro della stessa superfamiglia di `font-reading` e `font-ui`: coerenza tipografica dichiarata | Gabbia larga: meno colonne, penalizza il 13" |
 
**Proposta: Iosevka non patchato**, più `ttf-nerd-fonts-symbols` come font di soli simboli in fallback `fontconfig`. Motivo: il ruolo di `font-mono` è terminale e TUI, dove la densità è funzionale; la coerenza di superfamiglia conta sulle superfici di lettura, dove già c'è. `Q-N01`: conferma o ribaltamento.
 
**Fallback `fontconfig`** — da generare dai token, non scritto a mano:
1. `font-mono` primario
2. `font-symbol` (soli glifi)
3. Noto mirato: **solo greco** (per Φ, §6.6) e latino esteso. **Niente CJK** finché non serve davvero (`Q-18` architettura).
**Copertura del caso `yazi`** — è la ragione per cui il font patchato è stato installato, e va coperta **prima** di rimuoverlo, non dopo. Le icone di `yazi` sono glifi Nerd Font resi dal terminale. Con un font mono non patchato servono due cose, non una:
1. La catena di fallback `fontconfig` verso `font-symbol`.
2. In `kitty`, le direttive `symbol_map` che mappano gli intervalli di codepoint Nerd Font su `font-symbol`. **`kitty` non si affida solo a `fontconfig`** per i glifi mancanti: senza `symbol_map` le icone restano quadratini anche con il fallback configurato correttamente.
Verifica prima della rimozione: lista file di `yazi` con i segni git, più `btop`. Finché non passa, il font patchato resta installato. Lo stesso vale per qualunque altra TUI che usi glifi icona.
 
### 6.5 Motion — tassonomia vincolante
 
Da `phios-piano-stilistico-finale.md` §5. Criterio: **peso inverso alla frequenza d'uso.**
 
| Categoria | Uso | Regola |
|---|---|---|
| **A** — feedback di tracciamento | `cursor_trail` kitty, indicatore di elaborazione dell'agente | Continuo, leggero |
| **B** — transizione di stato | Finestre, pannelli, tendine, workspace, **notifiche e toast** | Alta frequenza → quasi istantaneo, nessun easing organico |
| **C** — enfasi / evento raro | Boot, sblocco, prima esecuzione, conferme rare | Due soli effetti ammessi: **battitura carattere-per-carattere** e **random-letters** (scramble che si risolve). Un caricamento in categoria C è ammesso solo se la risoluzione coincide col completamento reale del processo |
| **D** — indicatori ambientali | — | **Animazione vietata per default**, eccezioni giustificate esplicitamente |
 
**Rimosso e da non reintrodurre:** letter-roll generico sui titoli.
 
### 6.6 Identità Φ
 
| Ruolo | Trattamento | Contesti — lista chiusa |
|---|---|---|
| **A — marchio statico** | Tier 0, monocromo, immobile | Boot splash · banner TTY/login · banner SSH · pannello "about" |
| **B — presenza dell'agente** | Tier 1 (accento) **solo durante l'elaborazione**, altrimenti neutro. Motion categoria **A** | Segmento dedicato in barra su `zotac` e `razer` |
 
**Codepoint:** Φ maiuscola, `U+03A6`. Non le minuscole (`φ U+03C6`, `ϕ U+03D5`): i font non sono coerenti su quale forma renderizzino.
 
**Uso escluso:** sfondo, watermark ripetuto, icona di finestra, decorazione nel launcher.
 
**Asset da produrre `[AGENT]`:** vettore monocromo, vettore con accento, variante ASCII/Unicode per TUI e banner, tema Plymouth.
 
### 6.7 Contratto di generazione (§7.6 architettura)
 
`design/adapters.txt` dichiara, per ogni target: `template | destinazione | comando_di_ricarica | classe`.
 
| Classe | Ricarica | Target previsti |
|---|---|---|
| **A** — a caldo | Segnale, comando di controllo o file watch | `phi-shell` (hot reload QML nativo), Hyprland, `hyprsunset`, btop, yazi, zathura, imv, mpv |
| **B** — riconfigurabile a runtime | Sequenze o socket di controllo | kitty (sessioni attive), Neovim (istanza pilotabile) |
| **C** — richiede riavvio | Nessuno | LibreOffice, Librewolf, tema GTK/Qt per app native |
 
`phi theme set <variante>` esegue: rigenerazione di tutti i target → ricarica A e B → **elenco esplicito** delle app di classe C da riavviare. Idempotente, con `--dry-run`.
 
**Perimetro dei target di tema** (§7.4 architettura, `[VUOTO]` finora — qui compilato):
 
| Classe superficie | Target | Meccanismo |
|---|---|---|
| 1 — custom | `phi-shell` | Token QML generati, singleton `Appearance` |
| 2 — app native GTK/Qt | Tema GTK3/GTK4, Kvantum per Qt, `gsettings`/`xdg-desktop-portal` per la preferenza chiaro/scuro | Generati dai token |
| 3 — terminale/TUI | kitty, yazi, btop, neovim, zathura, imv, mpv, prompt zsh, `bat`, `fzf`, `delta` se adottato | Template `.tmpl` |
| 4 — app chiuse | Librewolf: `userChrome.css` + preferenza chiaro/scuro | Iniezione accento, classe C |
| 5 — chrome di sistema | Tema XCursor, banner TTY/login, prompt passphrase LUKS (via Plymouth), `systemd-boot` | `[TBD]` se tematizzare systemd-boot |
 
**Decorazione finestre CSD** (`[TBD]` §11 piano stilistico): decisione da prendere in S-41. Proposta: **sopprimere** le CSD dove il toolkit lo consente e lasciare che la gestione finestre sia interamente del compositore, coerentemente con un ambiente a tiling.
 
---
 
## 7. `phi` — CLI unificata
 
### 7.1 Contratto (§10.2 architettura)
 
| Aspetto | Decisione |
|---|---|
| Grammatica | `phi <dominio> <verbo> [argomenti]` |
| Architettura | Monolite con fallback su `phi-<nome>` nel `PATH` (ADR 017) |
| Linguaggio | Go (ADR 016) |
| Output | Doppio: stilizzato su TTY, strutturato quando rediretto. **Mai colori o spinner fuori dal terminale** |
| Configurazione | File unico con override per host |
| Completamenti | Generati per zsh dal comando stesso |
| Offline | Ogni verbo dichiara se richiede il server; in assenza fallisce esplicitamente o accoda |
| Avvio a freddo | **Requisito funzionale** (il launcher lo invoca a ogni battuta): ordine dei millisecondi |
 
### 7.2 Test di ammissione di un verbo (ADR 021)
 
1. **Composizione** — l'operazione attraversa più di uno strumento, o codifica una convenzione che esiste solo in questo sistema? Se è un alias su un solo comando, **non entra**.
2. **Proprietà dello stato** — se i dati appartengono a un'applicazione, il comando appartiene a quell'applicazione.
**Controesempi espliciti, da non implementare mai:** riavvio, spegnimento, volume, luminosità, screenshot. Nel launcher arrivano come *azioni di sistema*, non come verbi.
 
### 7.3 Roadmap dei verbi
 
| Milestone | Verbi | Note |
|---|---|---|
| M1 | `phi --version` · `phi help` · `phi completion zsh` | Il requisito minimo richiesto |
| M1 | `phi theme render \| set \| preview \| check \| list` | Sostituisce `phios-render`. `check` verifica il contrasto |
| M1 | `phi state get \| set \| list` | Bridge sullo stato runtime di §5.6 |
| M1 | `phi doctor` | Spazio disco, unit fallite, deriva dotfiles, SMART, età backup, stato servizi |
| M2 | `phi capabilities` | Espone il rilevamento di §5.3 a shell e script |
| M3 | `phi query <stringa>` | Backend del launcher: provider, ranking, frecency, azioni |
| M3 | `phi clip …` | Solo se la shell non basta a sé |
| M4 | `phi update` | Snapshot preventivo, aggiornamento, rigenerazione config, esito |
| M4 | `phi pkg list \| check` | Quattro categorie: T0, AUR, T4 manuale, `phi-packages` |
| M6 | `phi music …` · `phi media …` · `phi photos …` · `phi pin …` | Domini media; l'implementazione può essere in `phi-<dominio>` |
| M6 | `phi scan <percorso> \| status \| quarantine` | ClamAV; su `mini` delegato a `zotac` |
| M6 | `phi lint <file>` | LanguageTool via API HTTP locale |
| M7 | `phi agent broker \| mcp \| ask \| project` | §13 `phios-agente.md` |
| M7 | `phi server unlock` | Sblocco LUKS a cascata su `mini` via SSH |
 
**Regola di crescita:** il server MCP di `phi` è l'**unico punto di crescita** delle capacità dell'agente A1 (§7.1 `phios-agente.md`). Ogni capacità futura entra come verbo lì, non modificando l'architettura.
 
### 7.4 Struttura del repository `phi`
 
Vincolo di progetto (§10.1.1 architettura): **separare la logica di dominio dal livello di vista fin dall'inizio.** Il porting della prima è meccanico, quello della seconda no. È l'unica cosa che tiene aperta l'opzione Rust.
 
```
phi/
├── cmd/phi/            # entry point, dispatcher, fallback PATH
├── internal/
│   ├── cli/            # parsing, help, completamenti, rilevamento TTY
│   ├── tokens/         # lettura e derivazione OKLCH dei token
│   ├── theme/          # adapter, rendering, ricarica per classe
│   ├── state/          # stato runtime
│   ├── query/          # provider, ranking, frecency
│   ├── caps/           # capability detection
│   └── ...
├── pkg/                # librerie con più di un consumatore (ADR 023)
└── docs/
```
 
---
 
## 8. `phi-shell` — shell desktop
 
### 8.1 Base tecnica
 
`quickshell` 0.3.1 (`extra`, T0), QML/QtQuick, hot reload al salvataggio. Framework unico per tutte le superfici della sessione (ADR 072).
 
Copertura nativa verificata: `Quickshell.Hyprland` (workspace, finestra attiva) · `Quickshell.Services.UPower` (batteria) · `Quickshell.Services.Pipewire` (volume) · `Quickshell.Bluetooth` · `Quickshell.Networking` · `Quickshell.Services.SystemTray` · `Quickshell.Services.Mpris` · `Quickshell.Services.Pam` · `Quickshell.Services.Polkit` · `Quickshell.Wayland` (layer-shell, `WlSessionLock`, idle inhibitor) · `Quickshell.Io` (processi, socket, file).
 
Demoni di sistema richiesti, tutti già previsti: `upower`, `bluez`, `NetworkManager`, `pipewire`.
 
**Da verificare prima di S-23 (C-11):** nome esatto del tipo QML per la luminosità in 0.3.x. Ripiego: `brightnessctl` via `Quickshell.Io`.
 
**Ricaduta:** `Quickshell.Services.Polkit` permette alla shell di fare da agente Polkit, eliminando `hyprpolkitagent`/`lxqt-policykit` previsti in §8.2 architettura. Da confermare in implementazione.
 
### 8.2 Struttura del repository
 
```
phi-shell/
├── shell.qml                 # entry: istanziazione per schermo
├── Config/
│   ├── Tokens.qml            # GENERATO da `phi theme` — mai editato a mano
│   ├── Appearance.qml        # singleton: legge Tokens, espone ruoli semantici
│   ├── Settings.qml          # bridge sullo stato runtime ($XDG_STATE_HOME/phi)
│   └── Capabilities.qml      # singleton: batteria? backlight? ALS? GPU? chroma? touchscreen?
├── Widgets/                  # libreria Styled*: zero duplicazione dentro la classe 1
├── Services/                 # Phi (IPC verso phi), Notifications, Clipboard, Chroma, Idle, Agent
├── Bar/
│   ├── Bar.qml
│   ├── modules.json          # REGISTRO DICHIARATIVO (ADR 078)
│   └── modules/              # un tipo per modulo
├── Panels/
│   ├── Sidebar.qml
│   ├── tabs.json             # REGISTRO DICHIARATIVO (ADR 078)
│   └── tabs/
├── Launcher/  Lock/  Overview/  Screenshot/  Settings/  Osd/  Tooltip/  ContextMenu/  Cheatsheet/  Spotlight/
└── docs/
```
 
**Regola ADR 078, applicata:** il *tipo* di modulo o scheda è codice scritto una volta. L'*istanza* è una riga nel registro dichiarativo, che indica tipo, posizione, e sorgente dati (servizio interno o verbo `phi`). Aggiungere un modulo alla barra o una scheda al pannello è **modificare un file di dati**, non scrivere un componente.
 
### 8.3 Superfici — inventario completo e stato
 
| # | Superficie | Origine del requisito | Milestone |
|---|---|---|---|
| 1 | Barra di stato, a isole, per monitor | shell §1, stile §8 | M2 |
| 2 | Popover/tendina dai segmenti | stile §7 | M2 |
| 3 | Notifiche: toast + demone | shell §4, ADR 073 | M3 |
| 4 | Pannello laterale a schede | shell §6, ADR 078 | M3 |
| 5 | Storico clipboard con pin e TTL | shell §5, ADR 073 | M3 |
| 6 | Launcher | shell §3, ADR 018/019/022 | M3 |
| 7 | Lock screen (PAM, `ext-session-lock`) | shell §10 | M3 |
| 8 | Overview finestre | shell §13 | M3 |
| 9 | Screenshot / OCR / QR / registrazione | shell §11 | M3 |
| 10 | Overlay Alt+Tab | arch §8.2.2 S10 | M3 |
| 11 | Tooltip con ritardo di comparsa | stile §11 | M3 |
| 12 | Menu contestuale | stile §11 | M3 |
| 13 | Cheat sheet keybinding (sola lettura) | shell §14 | M3 |
| 14 | Pannello impostazioni | shell §8, funz §5 | M4 |
| 15 | OSD volume/luminosità | implicito | M4 |
| 16 | Sfondo (layer di background nativo) | shell §9 | M4 |
| 17 | Localizzazione cursore (spotlight) | funz §2.14 | M4 |
| 18 | Barra a scomparsa in schermo intero | arch §8.2.2 S11 | M4 |
| 19 | Timer in barra | arch §8.2.4 | M4 |
| 20 | Color picker | arch §8.2.4 | M4 |
| 21 | Lente d'ingrandimento | arch §8.2.4 | M5 |
| 22 | Pannello "about phiOS" (Ruolo A di Φ) | stile §17 | M5 |
| 23 | Scheda chat agente (placeholder in M3, funzionale in M7) | agente §10.1 | M3/M7 |
 
### 8.4 Barra — inventario per host (stile §8)
 
**Layout:** sinistra = workspace (numerico, corrente invertito) · centro = titolo finestra attiva, troncato a fine stringa con ellissi · destra = cluster di stato che **termina con l'orologio**.
 
| Host | Segmenti |
|---|---|
| `zotac` | workspace · titolo finestra · volume (icona solo su mute) · rete (icona solo su stato Tailscale) · GPU anomaly-carrier · **Φ agente** · orologio |
| `razer` | workspace · titolo finestra · volume · rete · **batteria anomaly-carrier** · wifi (icona stato, SSID a richiesta) · bluetooth (icona solo se connesso) · night mode (icona stato) · **Φ agente** · orologio |
| `mini` | Nessuna barra. Hostname colorato nel prompt zsh via SSH, accento diverso per host letto dai token |
 
**Esclusi come segmenti permanenti:** CPU, RAM, aggiornamenti pendenti.
 
**Criterio icona vs testo:** icona solo per stato discreto/binario; testo più colore-su-soglia per ogni valore continuo.
 
**Soglie anomaly-carrier** `[PLACEHOLDER]` da tarare su dati reali:
- `razer` batteria: scarica oltre 15%/ora, o carica residua sotto 20%
- `zotac` GPU: utilizzo sostenuto oltre 70% per più di 60 s, o temperatura oltre 75 °C
**Il segmento Φ agente non ha soglia:** trigger binario (elaborazione sì/no).
 
**Multi-monitor:** barra su tutti i monitor, "finestra attiva" per-monitor (focus locale). `[TBD]` residuo: l'elenco workspace mostrato è per-monitor o condiviso — si decide in S-22 con il compositore davanti.
 
**Tray di sistema:** non incluso finché non emerge un'app che lo richieda (`I-04`).
 
### 8.5 Modello di disclosure a tre livelli (stile §7)
 
Vincolante per ogni segmento della barra.
 
1. **Segmento** — muto per default, cambia stato solo su soglia o evento discreto.
2. **Tendina** — capienza `[PLACEHOLDER]`: massimo **5 righe informative + 2 azioni rapide**. Tetto di partenza, da rivedere componente per componente sul contenuto reale.
3. **Vista estesa** — dove esiste già uno strumento maturo, il deep-link lancia quello: `btop`, `nmtui`, `bluetuith`, `pulsemixer`/`wiremix`. Non richiede hot-reload classe A.
### 8.6 Ruoli tipografici e affordance (stile §6)
 
Nessun simbolo di affordance diffuso. Stato comunicato da peso, colore, opacità:
- label di sistema → basso contrasto, sempre monocromo
- valore/dato → colore Tier 2 solo su soglia
- interattivo inattivo → stesso peso del label, opacità ridotta
- interattivo attivo/selezionato → **inversione piena**
- glifo `>` → riservato al **solo** punto di input attivo
**Componente toggle standard:** pillola `radius-pill`, segmento attivo pieno in accento.
 
**Stati trasversali obbligatori per ogni componente:** `default` `hover` `active/pressed` `focus` (tastiera) `disabled` `loading` `invalid`.
 
**Vincolo sfondo:** wireframe / griglia tecnica o gradiente piatto. Mai fotografico o illustrativo.
 
---
 
## 9. Feature di sistema
 
Ogni voce dichiara: problema risolto (`I-04`), macchine, pacchetti, meccanismo, chi la esegue, milestone.
 
### 9.1 Animazione di boot `[NUOVO]`
 
| | |
|---|---|
| Problema | Identità di sistema durante il boot, e prompt grafico per la passphrase LUKS al posto della richiesta testuale |
| Macchine | `zotac`, `razer` (non `mini`: headless, root non cifrata, `timeout 0`) |
| Pacchetto | `plymouth` (T0, `extra`, 26.134.222) |
| Meccanismo | Hook `plymouth` in `mkinitcpio.conf`, prima di `sd-encrypt`. Con initramfs systemd la richiesta passphrase passa da `systemd-ask-password`, che Plymouth intercetta. Parametri kernel `quiet splash` nelle entry `systemd-boot`. Tema custom di tipo `script` che rende Φ in Ruolo A |
| Stile | Ruolo A: Tier 0, monocromo, immobile. **Opzione coerente**: effetto random-letters (categoria C) alla comparsa del marchio — ammesso, non imposto |
| Rischi | (a) Su `zotac` interazione con NVIDIA DRM: `nvidia_drm.modeset=1` è già impostato, ma il passaggio Plymouth→sessione può produrre sfarfallio. (b) Su `razer` interazione con il resume da ibernazione. (c) Costo: un componente nell'initramfs e frazioni di secondo di boot |
| Chi | `[AGENT]` tema e asset in `profiles/desktop/system/plymouth/phi/`. `[USER]` installazione pacchetto, modifica `mkinitcpio.conf`, `plymouth-set-default-theme`, `mkinitcpio -P`, aggiunta parametri kernel, riavvio e verifica |
| Milestone | M5 (indipendente: può anticiparsi se desiderato) |
 
### 9.2 ClamAV `[NUOVO]`
 
| | |
|---|---|
| Problema | **Antivirus attivo di sistema**: controllo dei download, degli script e di quanto è monitorabile in tempo reale, più i file che transitano da e verso macchine Windows e macOS e il disco esterno exFAT condiviso |
| Macchine | `zotac` e `razer`: servizio residente completo. `mini`: **nessun daemon** (C-04) |
| Pacchetto | `clamav` (T0, `extra`) |
| Perché la distinzione | `clamd` tiene l'intero database firme in memoria, dell'ordine di 1,2–1,5 GB. Su 32 GB e su 16 GB è irrilevante; su 4 GB condivisi con Navidrome, Jellyfin, Syncthing e i container è infattibile. Non è una scelta: è il vincolo dominante di `mini` |
| Componenti | `clamav-freshclam` (aggiornamento firme) · `clamav-daemon` (`clamd`, database residente) · `clamav-clamonacc` (scansione **on-access** via `fanotify`) |
| Scansione on-access | **Non sull'intero filesystem**: costerebbe prestazioni senza aggiungere copertura utile, e su Btrfs con snapshot produce rumore. Percorsi sorvegliati dichiarati: `~/downloads`, `~/cloud`, la directory di download del browser, `/tmp`, e le aree di ingestione media. La lista è **configurazione**, non codice: si estende senza toccare nulla |
| Costo su `razer` | La scansione on-access consuma CPU, e su un portatile questo è consumo di batteria. **Da misurare in uso reale.** Se il costo è percepibile, si condiziona all'alimentazione di rete con una regola su UPower — meccanismo già presente per Chroma |
| Scansione pianificata | Timer su `zotac` e `razer`, su percorsi dichiarati, scaglionato rispetto agli altri job. Copre ciò che l'on-access non vede (file già presenti, firme nuove su file vecchi) |
| `mini` | Nessun `clamd`, nessuna scansione locale. Due vie, entrambe senza database sul server: (a) `clamdscan --stream` verso il `clamd` di `zotac` sulla rete overlay — semplice, ma trasferisce i byte; (b) job accodato con nodo di esecuzione `zotac` (ADR 031) — più efficiente, ma richiede che `zotac` raggiunga la libreria. **Scelta in implementazione**, dopo aver misurato il volume reale |
| Quarantena | Directory dedicata, **fuori dal perimetro di sync e di backup**. Nessuna cancellazione automatica: i falsi positivi esistono e cancellare un file dell'utente è peggio del rischio che copre |
| Verbi | `phi scan <percorso>` · `phi scan status` · `phi scan quarantine list \| restore \| purge` |
| Superficie | Sezione **Security** del pannello: stato del servizio, freschezza delle firme, toggle della scansione on-access, elenco dei percorsi sorvegliati, ultimo esito, avvio scansione, contenuto della quarantena. Notifica alla scoperta di una minaccia, motion categoria B |
| Limite da conoscere | Il tasso di rilevamento di ClamAV su malware **nativo Linux** è modesto. Il valore reale è intercettare malware Windows e macOS di passaggio, e file noti nei download. È una misura utile, non una garanzia, e va saputo ora perché determina quanto affidamento farci |
| Chi | `[AGENT]` unit, timer, configurazione dei percorsi, verbi, superficie, notifica. `[USER]` installazione, abilitazione, prima scansione, misura del costo su `razer` |
| Milestone | Servizio: M6, indipendente dalla shell. Superficie: M4 se la sezione Security è pronta, altrimenti M6 |
 
### 9.3 LibreOffice `[NUOVO]`
 
| | |
|---|---|
| Problema | Consegna e consumo di documenti in formati Office con fedeltà di impaginazione (§8.14 architettura) |
| Macchine | Solo `zotac` e `razer` (profilo `study` per `razer`, `desktop` per entrambi — da assegnare a `study` e aggiungere `study` a `zotac` se serve) |
| Pacchetti | `libreoffice-fresh` (T0, `extra`) · `hunspell` · `hunspell-en_us` · `hunspell-it` · `hyphen-en` · `hyphen-it` · `mythes-en` · `mythes-it` |
| Tematizzazione | **Classe C** (§6.7): richiede riavvio. Segue il tema GTK/Qt generato; set di icone coerente da selezionare in S-41 |
| Nota `I-06` | Deroga esplicita, già ammessa in §8.14 architettura |
| Chi | `[AGENT]` voce nei `packages.txt`, configurazione tema e dizionari come template. `[USER]` installazione |
| Milestone | M6, ma applicabile in qualunque momento (indipendente) |
 
### 9.4 LanguageTool self-hosted `[NUOVO]`
 
| | |
|---|---|
| Problema | Correzione grammaticale e stilistica in inglese e italiano su testo accademico, senza inviare il testo a un servizio esterno (`I-08`) |
| Macchine | `zotac`, `razer` — **locale per client**, non su `mini` (C-05) |
| Pacchetto | `languagetool` (T0, `extra`, 6.6). Richiede un JRE, già dipendenza del pacchetto |
| Meccanismo | Server HTTP locale su loopback, **unit systemd utente attivata su socket**: parte alla prima richiesta, si ferma dopo inattività. Evita di tenere una JVM residente. Lingue: `en-US` e `it-IT`. Estendibile aggiungendo lingue nella configurazione |
| N-gram | I dati n-gram (che migliorano il rilevamento di parole confuse) sono un download separato di alcuni GB per lingua. **Rimandati**: si valutano dopo aver misurato la qualità senza |
| Integrazioni | (a) Neovim via plugin che parla l'API HTTP — **non** `ltex-ls` (AUR, C-03/§3.3). (b) LibreOffice via estensione ufficiale configurata sul server locale. (c) `phi lint <file>` per il flusso da terminale. (d) Librewolf: estensione ufficiale configurata sul server locale |
| Chi | `[AGENT]` unit socket-activated, configurazione, verbo, plugin Neovim, template. `[USER]` installazione, abilitazione, verifica |
| Milestone | M6, indipendente |
 
### 9.5 `phi` — strumento CLI `[NUOVO]`
 
Copre esplicitamente il requisito indicato: **creare `phi` con il solo comando `--version`**, e farlo crescere. Specifica completa in §7. Milestone M1.
 
### 9.6 Interactive Chroma (`razer`)
 
| | |
|---|---|
| Problema | Feedback visivo di stato di sistema e per-app sulla tastiera RGB per-tasto |
| Macchina | `razer` |
| Pacchetti | `openrazer-daemon` (T0, `extra`, tira `openrazer-driver-dkms` e `python-openrazer`) — **già installato e verificato** (`dkms status` → `openrazer-driver/3.12.4`) |
| Meccanismo | Scrittura diretta sul bus DBus `org.razer` esposto dal daemon. Nessun client di personalizzazione (`razer-cli`, `polychromatic`): sono interfacce, fuori scope |
| Scope deciso | **Nessuna interfaccia di personalizzazione.** Nel pannello: solo toggle on/off più eventuale color picker per un colore statico alternativo agli effetti |
| Comportamenti da programmare | Illuminazione statica in idle (`hypridle`) · colore tasto power in base a batteria (UPower) · blink riga funzione all'arrivo di notifiche (dal demone notifiche **della shell**, non da un bus esterno — ADR 073 chiude `Q-F05`) · rosso su finestra di errore bloccante (filtro per classe finestra) · Super premuto → illumina i tasti con shortcut disponibili (submap Hyprland con gestione di pressione **e** rilascio) · Neovim: colore contestuale a modalità (`ModeChanged`) · indicatore mic-mute (PipeWire/WirePlumber) · pulse rosso a batteria critica |
| Verifiche `[USER]` | `Q-F04` — device ID coperto dalla release stabile (enumerazione con `python-openrazer`). `Q-F06` — il tasto power è indirizzabile singolarmente nella matrice |
| Chi | `[AGENT]` servizio `Chroma` nella shell, mappatura evento→colore sui token, submap. `[USER]` enumerazione capacità del device |
| Milestone | M4 |
 
### 9.7 Tema chiaro/scuro live
 
Problema: cambio rapido per lettura prolungata o variazione ambientale. Macchine `zotac`, `razer`. Vincolo `I-05`: nessuna configurazione per-app, il tema si **genera** e si **ricarica**. Meccanismo: `phi theme set light|dark` più toggle in barra e nel pannello. Classi A/B/C di §6.7. Milestone M4 (S-41).
 
### 9.8 Night Shift
 
Strumento confermato: `hyprsunset` (T0, ufficiale hyprwm, richiede Hyprland ≥ 0.45 per il protocollo `hyprland-ctm-control-v1`; sostituisce `redshift`/`gammastep`, non funzionanti nativamente su Hyprland). Automazione oraria: pilotata dalla shell via `Quickshell.Io` invece di adottare un wrapper esterno — un timer e una chiamata `hyprctl` sono meno parti mobili di un secondo demone. Superficie: toggle e temperatura target nel pannello Theme, icona di stato in barra su `razer`. Milestone M4.
 
### 9.9 True Tone `[HOLD]`
 
Bilanciamento colore su luce ambientale, solo `razer` (unica con sensore). `[HOLD]` su `Q-F01`: esistenza di supporto ALS (`ls /sys/bus/iio/devices/`) — verifica `[USER]`, non risolvibile da ricerca. Se presente: `iio-sensor-proxy` e pilotaggio della temperatura da lux invece che da orario. Se assente: feature abbandonata, non sostituita. Milestone M4 se sbloccata.
 
### 9.10 Localizzazione cursore (spotlight)
 
Problema: perdere il cursore su schermo 13" HiDPI o in multitasking. Via nativa **verificata chiusa** (`decoration:screen_shader` non espone la posizione del cursore; issue upstream `hyprwm/Hyprland#1502` chiusa senza sviluppo). Realizzazione: **overlay layer-shell dentro `phi-shell`**, che disegna la vignetta e si aggiorna sul movimento del cursore. Nessun impegno permanente: se il costo di manutenzione diventa ingestibile, la feature si abbandona. Superficie: toggle e dimensione del cerchio nel pannello Theme. Milestone M4.
 
### 9.11 Volume e luminosità non funzionanti su `razer` `[HOLD]`
 
**Non è una preferenza fra modalità Fn.** I tasti volume e luminosità non hanno alcun effetto; la retroilluminazione tastiera funziona (percorso driver Razer/EC, diverso). Diagnosi probabile: codici HID della pagina "Consumer Control" non presenti nella tabella hwdb.
 
Percorso `[USER]`, non verificabile da remoto:
1. `sudo evtest` (o `sudo libinput debug-events`) premendo i tasti con e senza Fn, per leggere i codici emessi
2. Identificare vendor:product ID della tastiera interna (`/proc/bus/input/devices`, `lsusb`)
3. Regola `/etc/udev/hwdb.d/` che mappa i codici osservati su `KEYBOARD_KEY_<code>=volumeup|volumedown|mute|brightnessup|brightnessdown`
4. `sudo systemd-hwdb update && sudo udevadm trigger`
L'esito diventa un file in `profiles/razer-hw/system/` `[AGENT]` una volta noti i codici. Precedente noto con stesso meccanismo e codici diversi: la regola hwdb pubblica per la tastiera esterna Razer Pro Type Ultra.
 
Superficie: readout "risolto / non risolto" nella sezione Devices, non un controllo live. Milestone M0 (diagnosi) / M4 (superficie).
 
### 9.12 Pannello impostazioni — struttura finale
 
Chiude `C-08`. Nove sezioni. Perimetro: **solo stato realmente runtime**; il resto resta in configurazione versionata (ADR: un pannello che scrive stato persistente fuori dal repo crea un secondo punto di verità).
 
| Sezione | Contenuto |
|---|---|
| **General** | Hostname, modello hardware (CPU/GPU/RAM/storage), versione OS e kernel, uptime, spazio disco. Su `razer`: statistiche batteria (autonomia, cicli, salute) e profilo di risparmio energetico |
| **Theme** | Toggle chiaro/scuro live con anteprima doppia · night shift (toggle + temperatura) · True Tone se sbloccata · spotlight cursore (toggle + dimensione) · sfondo (selezione con copia in cartella dedicata). **L'accento è fisso da design system**: nessun controllo, salvo decisione contraria |
| **Connectivity** | Stato Tailscale (connesso/disconnesso, nome overlay — **mai IP**, ADR 067) · Wi-Fi (`razer`) · Bluetooth |
| **Devices** | Audio: mixer e selezione dispositivo (PipeWire) · monitor, risoluzione, scaling (stato runtime, ADR 077) · Chroma toggle e color picker (`razer`) · readout stato fix volume/luminosità · sensibilità mouse/trackpad |
| **Keybindings** | Vista di reference da `hyprctl binds -j`. **Sola lettura e ricerca**: nessuna modifica da interfaccia (shell §14, decisione chiusa) |
| **Notifications** | Modalità non disturbare (durata o a richiesta) · regole per applicazione · blink Chroma su notifica |
| **Security** | ClamAV: stato del servizio, freschezza firme, **toggle della scansione on-access**, percorsi sorvegliati, ultimo esito, avvio scansione, quarantena · face unlock: enroll e gestione, **disabilitato** finché `Q-01` resta rimandata · gestione segreti (punto di ingresso al password manager scelto) |
| **AI Agent** | Toggle di attivazione, stato connessione, stato dei servizi, readout broker/motore, contatore proposte di memoria in attesa, editor della lista di blocco per la directory di lavoro di A2. La gestione di progetti e personalità è passata al pannello (`phios-agente-delta.md` D-06). Contenuto dettagliato in `phios-agente.md` + `phios-agente-delta.md` |
| **Updates** | Vista a quattro categorie: T0 (`core`/`extra`), AUR (vuota finché `Q-01` è rimandata), T4 build manuale, **`phi-packages`**. Check aggiornamenti per categoria |
 
### 9.13 Altre feature confermate, senza modifiche rispetto ai documenti di origine
 
| Feature | Sede | Milestone |
|---|---|---|
| Lettura/annotazione PDF | `zathura` per lettura (già installato). Annotazione: Xournal++ come deroga `I-06`, **rimandata** finché non diventa bloccante. `Q-F03` risolta: Zathura non supporta annotazione persistente | M6 |
| Ripetizione dilazionata (Anki) | `anki` (verificare tier). Sync: `anki-sync-server` su `mini`, `[HOLD]` su `Q-F02` (budget RAM) | M6 |
| Bibliografia (Zotero) | Deroga `I-06` esplicita. Storage WebDAV self-hosted su `mini`, `[HOLD]` su `Q-F02` | M6 |
| Note collegate (zettelkasten) | Markdown puro più plugin Neovim, versionato via git. Nessun nuovo strumento di terze parti finché `phi-notes` non esiste | M6 → M8 |
| Gestione segreti | `KeePassXC` (offline, `keepassxc-cli`, nessuna dipendenza server) contro `Vaultwarden` su `mini` (`[HOLD]` `Q-F02`). **Vincolo collegato**: la scelta determina se lo storico clipboard può escludere le password via `x-kde-passwordManagerHint` — KeePassXC lo imposta già | M6 |
| Continuità clipboard `zotac`↔`razer` | Perimetro deliberatamente ridotto: solo clipboard, via rete overlay. Meccanismo dentro la shell, non un tool dedicato | M6 |
| Context switching automatico (P7) | Rivalutare quando almeno due fra Chroma, tema e note sono implementate | M8+ |
---
 
## 10. Servizi server (`mini`) necessari a chiudere le feature client
 
`mini` è nel perimetro solo per ciò che serve a completare `zotac` e `razer`.
 
### 10.1 Vincolo dominante: 4 GB saldati
 
Ogni servizio aggiunto va misurato, non stimato. Budget di riferimento, da validare con `systemd-cgtop` e `free -h` **dopo ogni aggiunta**:
 
| Componente | Residente atteso |
|---|---|
| Sistema base headless | 200–300 MB |
| Navidrome (attivo) | 150–300 MB, cresce con l'indice |
| Syncthing | 100–500 MB, cresce col **numero** di file più che col volume |
| Jellyfin server | 300–600 MB a riposo |
| Prowlarr (container) | 150–250 MB |
| qBittorrent-nox | 100–200 MB |
| Radarr + Sonarr (container, stage 2) | 300–600 MB complessivi |
| git su SSH | ~0 a riposo |
 
**Regole non negoziabili:**
1. **Le scansioni di libreria non si sovrappongono mai.** Sono il picco, non il funzionamento normale. Timer scaglionati, nessuna modalità automatica aggressiva.
2. **La page cache non è spazio sprecato**: servire file ne beneficia enormemente. Riempire la RAM di servizi la sottrae al lavoro che conta.
3. `zram` è già configurato (`min(ram/2, 4096)`, `zstd`, `swappiness=150`).
4. Ogni servizio che usa dati cifrati **dichiara `RequiresMountsFor=`** sul mount corrispondente (ADR 013 §4.4.4): un servizio che parte con la directory dati assente può ricrearla vuota, e un sincronizzatore che vede una libreria vuota può propagare cancellazioni. È una vera via di perdita dati.
5. Account di servizio: `DynamicUser=yes` dove lo stato è privato; utente statico più **gruppo condiviso con setgid** per chi accede alla libreria comune (ADR 029, 067).
### 10.2 Cloud sincronizzato — `/cloud` `[NUOVO]`
 
| | |
|---|---|
| Problema | La cartella `~/cloud` dei client (ADR 045) ha bisogno della sua controparte server (`/srv/cloud`, ADR 059) e di un meccanismo di sincronizzazione |
| Scelta | **Syncthing** (T0, `extra`, 2.1.x) |
| Motivazione | Go a binario singolo, granularità **per cartella** — che è esattamente ADR 040 ("ogni vault è un'unità di sync indipendente", così `razer` e `zotac` possono averne insiemi diversi") · nessun database, nessun PHP · client Android su F-Droid · P2P, quindi nessun punto singolo di guasto |
| Alternative scartate | **Nextcloud**: PHP più database, oltre 1 GB, escluso dal vincolo RAM. **Seafile**: efficiente ma con livello Pro proprietario (`I-03`) e dipendenze più invasive. **rclone/rsync**: nessun sync continuo, adatto ai media (dove serve pinning, non sync) ma non ai documenti |
| Limite accettato | Nessun sync selettivo **dentro** una cartella. Irrilevante: documenti e note si misurano in pochi GB e stanno interi su 512 GB (§5.2.2 architettura) |
| Layout | Un subvolume Btrfs per unità di sync sotto `/srv/cloud/`, così retention e snapshot sono differenziabili |
| Disciplina di naming | **Mai `~/cloud/documents`.** Le sottocartelle di `~/cloud` si nominano per **scopo**, non per tipo, altrimenti si generano alberi paralleli con le directory XDG locali (`Q-76` architettura resta aperta sul nome del vault universitario) |
| Confine | La sincronizzazione file opera **solo** su `/srv/cloud`. Le librerie media non sono sincronizzate: sono **servite** (ADR 059). Non mescolare mai i due meccanismi |
| Chi | `[AGENT]` unit, configurazione dichiarativa delle cartelle, voce nei profili. `[USER]` installazione, sblocco volume, accoppiamento dei dispositivi, subvolumi |
| Milestone | M6 |
 
### 10.3 Libreria foto `[NUOVO]`
 
| | |
|---|---|
| Problema | Archiviazione affidabile delle foto personali (classe **irrecuperabile**) con upload automatico dal telefono e visualizzazione dai client |
| Vincolo | L'indicizzazione ML è **fuori portata** su questo hardware: Immich richiede Postgres più servizi di inferenza, diversi GB solo per stare accesi, e l'indicizzazione iniziale su Haswell degraderebbe tutti gli altri servizi. PhotoPrism resta medio-alto. `Q-36` risolta di fatto dal vincolo RAM |
| Scelta | **Approccio minimo, senza servizio di indicizzazione.** Struttura di cartelle per data, pipeline di import, visualizzatore locale |
| Componenti | `perl-image-exiftool` (T0, `extra`, 13.55) per la lettura EXIF · Syncthing per l'upload dal telefono in una cartella `photos-inbox` in sola invio · `phi photos import` che sposta dall'inbox alla libreria ordinando per data di scatto, con **deduplica per hash di contenuto**, non per nome file |
| Collocazione | `/srv/media/photos`, subvolume proprio. ADR 042 la colloca sull'SSD esterno da 1 TB: **da riconfermare** alla luce della classificazione "irrecuperabile" e del fatto che i dischi esterni su USB sono il rischio noto (§18 architettura). Proposta: interno se ci sta, con backup offsite obbligatorio in ogni caso |
| Client | Visualizzatore: `imv` (già installato) e anteprime `yazi`. Superficie phiOS: scheda galleria nel pannello o `phi-photos` più avanti. Nessun client web |
| Ricerca | Per data e per cartella. **Nessuna ricerca semantica**, nessun riconoscimento: è una rinuncia esplicita, non un rimandare |
| Chi | `[AGENT]` pipeline di import, verbo, struttura. `[USER]` subvolume, permessi, configurazione Syncthing sul telefono |
| Milestone | M6 |
 
### 10.4 Indicizzazione e gestione contenuti — stack \*arr `[NUOVO]`
 
| | |
|---|---|
| Problema | Definire i comandi `phi` relativi alle librerie Jellyfin e Navidrome serve una fonte di ricerca su indexer. Oggi non esiste |
| Ostacolo | `prowlarr`, `radarr`, `sonarr`, `lidarr` sono **tutti solo AUR** (C-02). Con `Q-01` rimandata, la via T1 è chiusa |
| Via adottata | **T3 — container OCI rootless con `podman`**, immagini ufficiali upstream, unit systemd generate, senza demone privilegiato. È esattamente il caso previsto dal tiering (§2.2 architettura: "servizi con dipendenze invasive"): il runtime .NET è una dipendenza invasiva su un server a 4 GB |
| Alternativa scartata | Docker: demone privilegiato, attrito con `I-08` |
 
**Stadio 1 — il minimo che sblocca i verbi `phi`:**
 
| Componente | Ruolo | Tier |
|---|---|---|
| `prowlarr` | Aggregatore di indexer, espone un'API di ricerca unica | T3 |
| `qbittorrent-nox` | Client di download. **T0, `extra`, 5.2.3** | T0 |
 
**Perché `qbittorrent-nox` e non un altro client:** supporta il **download sequenziale** e la priorità al primo e ultimo pezzo. Sono i due requisiti esatti che il progetto ha già identificato — R2 di §9.6.2 architettura ("la riproduzione comincia prima che il fetch finisca") e la nota sui sottotitoli ("chiedere al fetcher di prelevare l'ultimo pezzo per primo", perché l'accoppiamento per hash usa i primi e ultimi 64 KB). Non è una preferenza: è la funzionalità che rende realizzabile una decisione già presa.
 
**Stadio 2 — subordinato a misura:**
 
| Componente | Condizione |
|---|---|
| `radarr` (film), `sonarr` (serie) | Solo se, misurato dopo lo stadio 1 con Jellyfin attivo, restano almeno **1,5 GB** liberi per page cache e picchi |
 
**`lidarr` — escluso (C-03).** Duplicherebbe una pipeline già decisa: ADR 012 spezza fetch e catalogazione, ADR 023 stabilisce che la logica è una libreria con due consumatori, e `beets` copre tagging, arricchimento e organizzazione. La ricerca su indexer arriva da Prowlarr; l'ingestione resta `phi music add <sorgente>`.
 
**Verbi `phi` sbloccati:** `phi media search|add|status` · `phi music search|add` · `phi media watchlist`.
 
**Conformità:** l'architettura è agnostica rispetto alla fonte; l'acquisizione deve limitarsi a contenuti di pubblico dominio, acquistati, con licenza libera o propri. La conformità resta a carico dell'utente.
 
Chi: `[AGENT]` unit quadlet, configurazione, verbi, integrazione. `[USER]` installazione `podman`, pull immagini, avvio, misura RAM, configurazione indexer.
Milestone: M6.
 
### 10.5 Jellyfin
 
| | |
|---|---|
| Pacchetto | `jellyfin-server` (T0, `extra`, 10.11.11) più `jellyfin-web` |
| Vincolo hardware | **Nessuna transcodifica, mai** (ADR 063). Quick Sync Haswell decodifica H.264 ma **non HEVC**. La libreria va conservata in formati **direct-play** per i dispositivi target: è una decisione sul formato di archiviazione, non sulla lettura |
| Criteri già fissati (ADR 066) | Capace di transcodificare anche se disattivata · accetta metadati inseriti a mano (media personali) · espone API e client esistenti per TV e mobile · tollera librerie su percorsi arbitrari (ADR 033) · nessun livello a pagamento |
| Libreria VR | **Radice separata** `/srv/media/video-vr`, servita direttamente al visore (ADR 061). Convenzione di nome file come schema di metadati per proiezione e stereoscopia (`Q-69` aperta). Target H.265: il visore non decodifica AV1 |
| Milestone | M6 |
 
### 10.6 Riepilogo `/srv`
 
| Percorso | Contenuto | Note |
|---|---|---|
| `/srv/cloud/<unità>` | Un subvolume per unità di sync | Syncthing |
| `/srv/media/music` | Libreria musicale | Navidrome, già attivo |
| `/srv/media/video` | Film e serie | Jellyfin |
| `/srv/media/video-vr` | Video VR | Servito al visore, fuori da Jellyfin |
| `/srv/media/photos` | Foto | Classe irrecuperabile |
| `/srv/git` | Repository bare | Già subvolume |
| `/srv/pkg/phi` | **Repo pacman dei pacchetti propri** | Nuovo, §3.1 |
| `/var/lib/<servizio>` | Stato e database dei servizi | `nodatacow` sulle directory di database, impostato **prima** che il servizio scriva |
 
### 10.7 Allocazione fisica per fasi — nessuna archiviazione esterna oggi
 
Situazione reale: `mini` ha il solo disco interno. L'archiviazione esterna arriverà dopo.
 
**Questo non richiede una pianificazione diversa**, ed è esattamente il caso per cui esiste ADR 033: `/srv` è un **namespace**, non un disco. Un subvolume per libreria, montato al proprio percorso logico, indipendentemente da dove risiedono i byte.
 
Conseguenza operativa: si creano ora i subvolumi ai percorsi logici definitivi sul volume interno, e quando arriva il disco esterno si crea il subvolume lì, si spostano i dati e si aggiunge una riga a `fstab`. `/srv/media/video` resta identico, quindi **nessuna configurazione di servizio, nessuna playlist e nessuno script va toccato**. È la scelta che rende reversibile un'allocazione altrimenti definitiva.
 
Capienza indicativa del volume interno (`data`, ~365 GB una volta liberato):
 
| Percorso | Ordine di grandezza | Sta sull'interno? |
|---|---|---|
| `/srv/pkg/phi` | decine di MB | Sì |
| `/srv/cloud/*` | pochi GB | Sì |
| `/srv/media/photos` | ~72 GB | Sì |
| `/srv/media/music` | già presente | Sì |
| `/srv/media/video` | **è la classe voluminosa** | Parzialmente: si parte piccoli e si cresce sull'esterno |
| `/srv/media/video-vr` | ~300 GB | **No.** Attende l'esterno |
 
Quindi cloud, foto, pacchetti e musica si possono impostare subito e restano dove sono. Jellyfin si può configurare e collaudare subito con una libreria contenuta; è il volume dei film e dei video VR ad attendere il disco.
 
**Quattro vincoli da imporre adesso, non dopo** — sono economici ora e costano una migrazione o una perdita di dati poi:
 
1. **Punto di mount protetto quando il disco è assente.** Se domani monti un esterno su `/srv/media/video` e il mount fallisce, la directory sottostante è sul disco interno: un servizio la vede **vuota** e può marcare l'intera libreria come cancellata; un download può riempire silenziosamente il disco di sistema. Contromisure obbligatorie: `RequiresMountsFor=` nelle unit, e directory sottostante resa non scrivibile quando vuota.
2. **Mount per UUID, mai per percorso di device.** `/dev/sdb1` cambia fra un riavvio e l'altro.
3. **`nodatacow` sulle directory di database prima che il servizio scriva.** L'attributo vale solo per i file creati dopo averlo impostato: va messo sulla directory **vuota**. Vale per `/var/lib/jellyfin` e per ogni servizio nuovo.
4. **Etichetta di filesystem parlante** su ogni volume, per riconoscerlo quando lo colleghi altrove.
**Nota sullo sblocco:** `/srv` vive sul volume cifrato che su `mini` si sblocca **a mano** (coerente con §4.4.1: root non cifrata, dati sbloccati via SSH dopo l'avvio). Dopo ogni riavvio i servizi che dipendono da `/srv` non partono finché non sblocchi. Con `RequiresMountsFor=` è il comportamento corretto — attendono invece di partire su una directory vuota — ma va saputo, perché il sintomo è "i servizi non ci sono" e la causa è "il volume non è aperto".
 
---
 
## 11. Agente AI — collocazione nel piano
 
`phios-agente.md` è già una specifica completa. Qui si registra solo come si innesta nella sequenza e cosa dipende da cosa. **Nessuna decisione dell'agente viene rinegoziata in questo documento.**
 
### 11.1 Motore
 
`opencode` (T0, `extra`, linea stabile 1.18.x). Chiude `Q-40` e `C-12`. Il contratto motore↔client di §9 dell'agente resta in vigore: se il motore di A1 si rivelasse inadatto, si sostituisce senza toccare il pannello.
 
### 11.2 Dipendenze verso il resto del piano
 
| Cosa serve prima | Perché |
|---|---|
| `phi` esiste come binario con sottocomandi (M1) | Tutti e cinque i verbi di §13 dell'agente ne dipendono |
| `phi-shell` ha il pannello laterale a schede dichiarativo (M3) | La scheda chat è un'istanza dichiarativa, non un componente scritto a mano (ADR 078, ADR 100) |
| Il segmento Φ in barra (M2) | Ruolo B dell'identità: presenza dell'agente |
| Rete overlay con politica di accesso a negazione predefinita (già in essere) | §5.3 dell'agente: superficie remota solo sull'indirizzo overlay |
 
### 11.3 Ciò che l'agente aggiunge al piano
 
| Componente | Milestone dell'agente | Milestone di questo piano |
|---|---|---|
| Script di avvio contenuto (`bubblewrap`), liste di percorsi | 0 | M7 |
| Unit di servizio A1 (ricostruzione al cambio progetto) e A2 remoto | 0 | M7 |
| Intermediazione della chiamata al provider (verbo `phi`) | 0 | M7 |
| Configurazione proxy d'uscita di A2 (`tinyproxy` + `socat`) | 0 | M7 |
| Domanda inline | 0 | M7 |
| Server MCP `phi` | 0, poi cresce | M7 |
| Livello client verso il motore, riassunto e archiviazione, trasferimento proposte | 1 | M7 |
| Pannello (appartiene alla shell) | — | M3 placeholder, M7 funzionale |
| Rilavorazione pannello (4 sezioni), memoria a 3 livelli, cartelle di interesse, specchio conversazioni, superficie A2 (`phios-agente-delta.md`) | 1 | Out-of-plan `agent-panel-rework` |
 
### 11.4 Prove bloccanti
 
Le prove `V-01`…`V-04` di `phios-agente.md` §15 sono **bloccanti**: nessuna capacità di scrittura si abilita prima del loro esito positivo. Sono operazioni `[USER]` sulla macchina reale. Il passaggio dall'uso attuale del motore (senza contenimento) ad A2 contenuto avviene **alla fine della milestone 0 dell'agente**, non prima.
 
### 11.5 Pacchetti
 
`opencode` · `bubblewrap` · `socat` · `tinyproxy` — tutti T0, `zotac` e `razer`.
 
---
 
## 12. App client custom — fase finale
 
Criterio di ammissione (§10.1 architettura): si sviluppa in proprio **solo se** (a) nessuna opzione esistente soddisfa `I-06`, (b) l'opzione esistente porta dipendenze irriducibili indesiderate, (c) il componente è colla fra due sistemi propri e quindi non esiste per definizione, (d) l'aggiornamento live del tema è un requisito e nessun candidato è di classe A.
 
| App | Criterio | Sostituto attuale | Priorità |
|---|---|---|---|
| **`phi-notes`** | (a) + (d). Obsidian è Electron, classe C, non tematizzabile dai token | Obsidian | **La prima delle app custom.** Vincolo ADR 041: contenuto e stato **separati fisicamente** dal primo giorno — il vault contiene solo file dell'utente, indice, cache di ricerca e stato di workspace vivono in `~/.local/state/<app>/`. È la causa più comune di conflitti negli strumenti di note sincronizzati |
| **`phi-music`** | (c). Deve poter chiedere al server di **aggiungere il download** di una traccia o di un album: è colla fra client e pipeline propria | `clamp` o interfaccia web Navidrome | Seconda |
| **`phi-media`** | (c). Deve poter chiedere al server di aggiungere un film, una serie o un video da URL, in conformità con le feature del server | Interfaccia web Jellyfin | Terza |
 
**Vincolo trasversale:** ogni app custom è di **classe A** per costruzione (§7.6 architettura) e legge i token di §6. Sono il motivo tecnico forte a favore dello sviluppo proprio.
 
**Scadenza sulla scelta del linguaggio (ADR 016):** ogni app TUI scritta in Go aumenta il costo di un eventuale porting a Rust. La prima è economica da rifare, la terza no. **Riconsiderare Rust prima della seconda app TUI, oppure mai.**
 
---
 
## 13. Roadmap
 
Ordinamento per **dipendenza**, non per interesse. Ogni milestone ha un cancello: non si prosegue senza.
 
### M0 — Fondazione dei dotfiles `[MISTO]`
 
Nuova struttura, profili, capability detection, token a due varianti, confine `/etc`, manifest di stato, idempotenza, `--dry-run`, `--system-diff`. Migrazione di tutti i target di tema esistenti senza cambiare l'output.
 
**Cancello G0:** su `zotac` e `razer`, `--dry-run` pulito dopo un'esecuzione completa; nessuna regressione funzionale; `--system-diff` pulito. Diagnosi hwdb su `razer` eseguita e codici registrati.
 
### M1 — `phi` e distribuzione dei pacchetti propri `[MISTO]`
 
Repo `phi`, dispatcher, `--version`, `theme`, `state`, `doctor`, completamenti. Repo `phi-packages`, PKGBUILD, chiave di firma, repo pacman su `mini`, registrazione in `pacman.conf`.
 
**Cancello G1:** `phi --version` installato **da `pacman`** su entrambe le macchine; `phi theme set` produce lo stesso risultato dello script bash; `phi theme check` riporta lo stato del contrasto.
 
### M2 — Shell: scheletro e barra `[MISTO]`
 
Repo `phi-shell`, struttura QML, `Appearance`/`Tokens`/`Capabilities`, libreria `Styled*`, barra a isole per monitor con registro dichiarativo, moduli di §8.4, avvio dalla sessione, hot reload.
 
**Cancello G2:** barra funzionante su entrambe le macchine, moduli corretti per capacità rilevate, nessun colore hardcoded, aggiunta di un modulo dimostrata come modifica di un solo file di dati.
 
### M3 — Superfici di sessione `[MISTO]`
 
Notifiche (demone + toast + DND) · pannello laterale a schede con registro dichiarativo (notifiche, clipboard, calendario, **chat agente come placeholder**) · storico clipboard con pin, TTL ed esclusione sensibile · launcher con stack di navigazione e provider via `phi query` · lock screen PAM · overview finestre · screenshot/OCR/QR/registrazione · Alt+Tab · tooltip · menu contestuale · cheat sheet.
 
Rimozione di `cliphist` (C-07).
 
**Cancello G3:** la sessione è usabile quotidianamente senza tornare al terminale per le operazioni comuni. Il lock screen non lascia mai la sessione esposta se il client muore (garanzia di `ext-session-lock`, da verificare uccidendo il processo).
 
### M4 — Impostazioni e feature di sistema `[MISTO]`
 
Pannello a nove sezioni · tema live chiaro/scuro · night shift · spotlight cursore · idle inhibit per processo · sfondo nativo con copia · Chroma (`razer`) · OSD · timer · color picker · barra a scomparsa in schermo intero · superficie pacchetti a quattro categorie · hook pacman di rigenerazione tema.
 
**Cancello G4:** ogni feature dichiarata in `phios-funzionalita.md` ha una superficie, funzionante o esplicitamente segnata come placeholder in attesa di backend. **Questo cancello chiude la priorità 2 dichiarata da Fla.**
 
### M5 — Identità e stilizzazione avanzata `[MISTO]`
 
Palette definitiva derivata in OKLCH con contrasto AA verificato su entrambe le varianti · Tier 2 e Tier 3 finali · chiusura di `font-mono` e correzione del font patchato (C-01) · fallback `fontconfig` · motion categorie A–D implementate · Plymouth con tema Φ · banner TTY, login e SSH · pannello about · tema XCursor · lente d'ingrandimento.
 
**Cancello G5:** `phi theme check` senza violazioni; entrambe le varianti usabili; nessun font patchato installato.
 
### M6 — Servizi e strumenti `[MISTO]`
 
Syncthing e `/srv/cloud` · libreria foto e import · Jellyfin · Prowlarr e qBittorrent · verbi `phi media`/`phi music`/`phi photos`/`phi pin` · ClamAV · LanguageTool · LibreOffice · Anki, Zotero, PDF, segreti, clipboard fra macchine.
 
**Cancello G6:** budget RAM di `mini` misurato e documentato dopo ogni aggiunta; nessuna sovrapposizione di scansioni; `phi doctor` verde.
 
### M7 — Agente AI `[MISTO]`
 
Milestone 0 e 1 di `phios-agente.md`. Le prove `V-01`…`V-04` sono bloccanti.
 
**Cancello G7:** tutte le prove `V-01`…`V-18` dell'agente eseguite e registrate.
 
### M8 — App custom `[MISTO]`
 
`phi-notes`, poi `phi-music`, poi `phi-media`. Decisione Go/Rust riaperta prima della seconda.
 
**Cancello G8:** ogni app è classe A, legge i token, è distribuita come pacchetto `phi-*`.
 
### 13.1 Lavoro parallelizzabile
 
Le tracce di `phios-agent-parallel.md` non dipendono dallo stato delle macchine e possono avanzare in qualunque momento dopo M0:
 
- Libreria di dominio di `phi` (token, OKLCH, ranking, provider) — testabile senza hardware
- Asset vettoriali Φ e tema Plymouth
- `phi-notes` (indipendente da tutto)
- `phi-music`, `phi-media` (dipendono solo dal contratto API, non dal server)
- Server MCP `phi` e intermediazione del provider (testabili in locale)
Le feature indipendenti dalla shell — LibreOffice, LanguageTool, ClamAV, Anki, Zotero — possono essere installate dall'utente in qualunque momento dopo M0 senza attendere M6.
 
---
 
## 14. Matrice di responsabilità
 
Regola generale: **l'agent produce file nei repository. L'utente cambia lo stato delle macchine.** Nessuna eccezione.
 
### 14.1 L'agent può
 
Scrivere, modificare e cancellare file nei repository · progettare la struttura di moduli, profili, registri dichiarativi · scrivere QML, Go, template, PKGBUILD, unit systemd (come **file**, non abilitandole) · scrivere materiale `/etc` sotto `profiles/*/system/` · derivare la palette e verificare il contrasto in modo programmatico · scrivere documentazione, ADR, `PROGRESS.md` · fare commit e push sul remote `github` · proporre pacchetti da aggiungere al registro, **chiedendo conferma** · fermarsi e chiedere quando incontra un `[TBD]`, `[HOLD]`, `[?]` o un'ambiguità.
 
### 14.2 L'agent non può, mai
 
Eseguire `pacman`, `paru`, `makepkg` o qualunque installazione · toccare `/etc`, `/usr`, `/var` su una macchina reale · eseguire `systemctl enable`, `start`, `daemon-reload` · connettersi a `zotac`, `razer` o `mini` · eseguire diagnostica hardware · sbloccare volumi, gestire chiavi, scrivere segreti in qualunque forma · introdurre dipendenze AUR o T4 finché `Q-01` è rimandata · aggiungere un pacchetto non presente nel registro di §15 senza chiedere · riaprire una ADR chiusa · procedere allo step successivo senza il feedback di verifica dell'utente · fare push su `origin` (`mini`).
 
### 14.3 L'utente esegue
 
Installazione e rimozione pacchetti · modifiche a `/etc` dopo aver letto il `--system-diff` · abilitazione e avvio servizi · riavvii e verifiche · diagnostica hardware (`evtest`, `python-openrazer`, `/sys/bus/iio/devices/`, `free -h`, `systemd-cgtop`) · sblocco LUKS · generazione e gestione della chiave di firma · configurazione degli account nei servizi (Syncthing, Prowlarr, Jellyfin) · **restituzione del feedback di verifica**.
 
---
 
## 15. Registro pacchetti consolidato
 
Tier indicativo, **da verificare con `pacman -Si` al momento dell'installazione** (regola §0.2.3 architettura).
 
### 15.1 Già installati e confermati
 
Elencati nei `packages.txt` attuali. Nessuna azione salvo le correzioni indicate.
 
### 15.2 Nuovi — profilo `base` (tutte le macchine)
 
| Pacchetto | Repo | Job | Milestone |
|---|---|---|---|
| `perl-image-exiftool` | extra | Lettura EXIF per la pipeline foto | M6 |
| `ttf-nerd-fonts-symbols` | extra | Font di soli simboli (ADR 054) | M5 |
| `adobe-source-code-pro-fonts` | extra | `font-mono` non patchato — `Q-N01` chiusa (ADR 123) | M5 |
| `adobe-source-serif-fonts` | extra | `font-reading` | M5 |
| `adobe-source-sans-fonts` | extra | `font-ui` | M5 |
| `noto-fonts` | extra | Fallback mirato (latino esteso, greco per Φ) | M5 |
| `phi` | **`[phi]`** | CLI unificata | M1 |
 
**Da rimuovere:** `ttf-iosevkatermslab-nerd` (font patchato, C-01), allo step S-51 e non prima.
 
### 15.3 Nuovi — profilo `desktop`
 
| Pacchetto | Repo | Job | Milestone |
|---|---|---|---|
| `quickshell` | extra | Framework della shell | M2 |
| `qt6-base` `qt6-declarative` `qt6-svg` `qt6-wayland` `qt6-shadertools` | extra | Dipendenze quickshell (verificare quali siano già tirate dal pacchetto) | M2 |
| `phi-shell` | **`[phi]`** | Shell desktop | M2 |
| `upower` | extra | Batteria, soglie, tasto power Chroma | M2 |
| `networkmanager` | extra | Modulo rete della barra e Wi-Fi (`razer` lo ha già) | M2 |
| `hyprsunset` | extra | Night shift | M4 |
| `hypridle` | extra | Idle, illuminazione statica Chroma | M4 |
| `wf-recorder` | extra | Registrazione schermo | M3 |
| `zbar` | extra | Lettura QR | M3 |
| `grim` `slurp` | extra | Cattura (la UI è custom) | M3 |
| `libnotify` | extra | `notify-send`, per testare il demone notifiche (S-30) senza `busctl` a mano; approvato dall'utente durante la verifica M3 | M3 |
| `plymouth` | extra | Animazione di boot | M5 |
| `clamav` | extra | Antivirus residente con scansione on-access. **Solo `zotac` e `razer`**, mai `mini` | M6 |
| `languagetool` | extra | Correzione grammaticale locale | M6 |
| `libreoffice-fresh` | extra | Formati Office | M6 |
| `hunspell` `hunspell-en_us` `hunspell-it` `hyphen-en` `hyphen-it` `mythes-en` `mythes-it` | extra | Dizionari e sillabazione | M6 |
| `opencode` | extra | Motore dell'agente AI | M7 |
| `bubblewrap` | extra | Contenimento dell'agente | M7 |
| `socat` | extra | Ponte di rete di A2 | M7 |
| `tinyproxy` | extra | Lista bianca d'uscita di A2 | M7 |
| `wiremix` *(o `pulsemixer`)* | extra | Vista estesa audio dal deep-link Tier 3 | M4 |
| `bluetuith` | extra/AUR — **verificare** | Vista estesa Bluetooth. Se AUR, il deep-link punta altrove | M4 |
 
**Da rimuovere:** `cliphist` allo step S-32 (C-07). `wl-clipboard` **resta**.
 
### 15.4 Nuovi — profilo `study` (`razer`)
 
| Pacchetto | Repo | Job | Milestone |
|---|---|---|---|
| `anki` | verificare | Ripetizione dilazionata | M6 |
| `zotero` *(deroga `I-06`)* | verificare | Bibliografia | M6 |
| `keepassxc` | extra | Gestione segreti (in alternativa a Vaultwarden) | M6 |
| `xournalpp` | extra | Annotazione PDF — **rimandato** finché non bloccante | — |
 
### 15.5 Nuovi — profilo `server` (`mini`)
 
| Pacchetto | Repo | Job | Milestone |
|---|---|---|---|
| `syncthing` | extra | Cloud sincronizzato | M6 |
| `jellyfin-server` `jellyfin-web` | extra | Libreria film e serie | M6 |
| `qbittorrent-nox` | extra | Client di download con sequenziale e priorità primo/ultimo pezzo | M6 |
| `podman` | extra | Runtime container rootless per lo stack \*arr | M6 |
| `perl-image-exiftool` | extra | Pipeline foto | M6 |
| `darkhttpd` *(o `nginx`)* | extra | Servire `/srv/pkg/phi` a `pacman` sulla rete overlay | M1 |
 
### 15.6 Container (T3, solo `mini`)
 
| Immagine | Ruolo | Stadio |
|---|---|---|
| Prowlarr, immagine ufficiale upstream | Aggregatore indexer | 1 |
| Radarr, Sonarr, immagini ufficiali upstream | Automazione film e serie | 2, subordinato a misura |
 
### 15.7 Pacchetti propri (`[phi]`)
 
| Pacchetto | Repo sorgente | Milestone |
|---|---|---|
| `phi` | `phi` | M1 |
| `phi-shell` | `phi-shell` | M2 |
| `phi-notes` | `phi-notes` | M8 |
| `phi-music` | `phi-music` | M8 |
| `phi-media` | `phi-media` | M8 |
 
### 15.8 Toolchain sulla sola macchina di build (`zotac`)
 
| Pacchetto | Job |
|---|---|
| `base-devel` | Build dei pacchetti propri |
| `devtools` | Build in chroot pulito |
| `go` | Compilazione di `phi` e app |
| `pacman-contrib` | Utilità di repository |
 
---
 
## 16. Protocollo di verifica e feedback
 
È il meccanismo che tiene insieme il ciclo agent↔utente. Senza, l'agent lavora alla cieca.
 
### 16.1 Ciclo di uno step
 
1. L'agent legge lo step nel backlog e la SSOT.
2. L'agent scrive i file, aggiorna `PROGRESS.md` marcando lo step `awaiting-verification`, fa **un commit per step** con il trailer `Step: S-NN`, e fa push su `github`.
3. L'agent produce un **blocco di consegna**: cosa è cambiato, cosa deve fare l'utente, quali comandi eseguire, quale output è atteso.
4. L'utente esegue, incolla l'output.
5. Se conforme: l'agent aggiorna `PROGRESS.md` a `verified` e passa allo step successivo. Se non conforme: l'agent corregge nello stesso step, non ne apre un altro.
**Regola:** mai due step in volo contemporaneamente sulla linea principale. Le tracce parallele sono l'eccezione, e non toccano lo stato delle macchine.
 
### 16.2 `PROGRESS.md`
 
Vive in `phios-dotfiles`. È la memoria durevole del ciclo, indipendente dal contesto di sessione dell'agent. Una riga per step: identificatore, titolo, stato (`todo` / `awaiting-verification` / `verified` / `blocked`), commit, data, nota.
 
### 16.3 Convenzione di commit
 
```
<scope>: <imperativo, inglese, minuscolo>
 
<corpo opzionale: cosa e perché, mai come>
 
Step: S-NN
```
 
Scope: nome del profilo, del modulo o del componente. Un commit per step. Mai squash di più step. Nessun commit tocca due step.
 
### 16.4 Forma della verifica
 
Ogni step dichiara comandi **non distruttivi e brevi**, e la **forma** dell'output atteso — non il valore esatto, che dipende dalla macchina. Se la verifica richiede un riavvio o un'operazione rischiosa, lo step lo dichiara in testa.
 
### 16.5 Registro delle verifiche
 
Le verifiche `V-01`…`V-18` di `phios-agente.md` restano vincolanti e non si duplicano qui. Le verifiche di questo piano si numerano `V-P01`… e vivono nelle step card.
 
---
 
## 17. Domande aperte
 
### 17.1 Nuove, da chiudere in corso d'opera
 
| ID | Domanda | Impatta | Quando |
|---|---|---|---|
| `Q-N01` | **Chiusa (ADR 123, S-50, 2026-09-09)**: ~~`font-mono`: Iosevka o Source Code Pro?~~ Source Code Pro, per scelta diretta dell'utente | §6.4, S-51 | M5 |
| `Q-N02` | **Chiusa (ADR 121, S-22, 2026-09-08)**: ~~Elenco workspace in barra: per-monitor o condiviso?~~ Per-monitor, confermato dall'utente col compositore davanti | §8.4, S-22 | M2 |
| `Q-N03` | **Chiusa (ADR 122, S-22, 2026-09-08)**: ~~btop: workspace normale a ID alto e persistente, o special workspace a comparsa?~~ Special workspace dedicato a btop, con un toggle visivo in barra trattato come i pulsanti workspace — non ancora costruito da nessuno step | shell §2 | M2 |
| `Q-N04` | **Chiusa (ADR 124, S-53, 2026-09-09)**: ~~Tematizzare `systemd-boot`?~~ No, lasciato al default, per scelta diretta dell'utente | §6.7 classe 5 | M5 |
| `Q-N05` | Decorazioni CSD: attivate o soppresse? | §6.7, S-41 | M4 |
| `Q-N06` | Le foto restano sull'esterno da 1 TB (ADR 042) o passano sull'interno, data la classe irrecuperabile e il rischio noto dei dischi USB? | §10.3 | M6 |
| `Q-N07` | Contenuto dello schema di keybinding: quale tasto fa cosa. È un lavoro a sé, non risolto da nessuna valutazione tecnica. **Nota da S-22 (2026-09-08):** a questa data nessuna keybinding Hyprland è ancora configurata sulle macchine reali — nessuna funzione della shell guidata da tastiera è verificabile prima che questo step la chiuda; ogni step precedente a `S-38` che vuole un test da tastiera deve prima chiedere se il bind esiste già | shell §14 | M3 |
| `Q-N08` | Nome del vault universitario dentro `~/cloud` (non può chiamarsi `documents`) | ADR 045, `Q-76` | M6 |
| `Q-N09` | Le voci del vault password entrano fra i risultati del launcher? **Decisione di sicurezza, non di comodità** | `Q-73`, S-33 | M3 |
| `Q-N10` | `phi-shell` fa da agente Polkit via `Quickshell.Services.Polkit`, eliminando un componente? | §8.1 | M3 |
 
### 17.2 Ereditate, rilevanti in questo perimetro
 
| ID | Stato |
|---|---|
| `Q-01` | **Rimandata** (§3.3). Trigger di riapertura definito |
| `Q-F01` | ALS su `razer`: `[HOLD]`, verifica `[USER]` in M0 |
| `Q-F02` | Budget RAM su `mini` per nuovi servizi: `[HOLD]`, si misura in M6 |
| `Q-F04` | Device ID Razer coperto da openrazer stabile: probabile sì, conferma in M4 |
| `Q-F06` | Tasto power indirizzabile nella matrice Chroma: `[HOLD]`, verifica in M4 |
| `Q-F05` | Notification daemon in uso: **chiusa da ADR 073** — è la shell |
| `Q-40` | **Chiusa**: `opencode` (§11.1) |
| `Q-73` | Riformulata come `Q-N09` |
| `Q-76` | Riformulata come `Q-N08` |
| `Q-69` | Convenzione di naming VR: aperta, M6 |
| `Q-19` | Quante app di classe C tollerare: risposta operativa in §6.7 — LibreOffice, Librewolf e le GUI native. Nessun'altra ammessa senza deroga |
 
---
 
## 18. Rischi
 
| Rischio | Impatto | Mitigazione |
|---|---|---|
| **API Lua di Hyprland in movimento** (0.55 → 0.56 in poche settimane) | Una configurazione scritta ora si rompe a un aggiornamento | Snapshot pre-aggiornamento già attivi; secondo kernel già installato; verifica di compatibilità come primo controllo di M0; la configurazione resta minima e concentrata in un file |
| **API di quickshell non stabile** (0.3.x) | Rottura della shell a un aggiornamento | Livello di astrazione sottile: `Appearance` e `Capabilities` come unici punti di contatto con i tipi del framework; nessuna dipendenza da comportamenti non documentati |
| **RAM di `mini`** | Servizi lenti o OOM | Misura obbligatoria dopo ogni aggiunta; stadio 2 dello stack \*arr subordinato a soglia; scansioni scaglionate; `zram` già attivo |
| **Superficie custom eccessiva** (`I-10`) | Sistema immanutenibile | Criterio §10.1 architettura applicato rigidamente; registri dichiarativi (ADR 078) al posto di componenti scritti a mano; ogni app custom dichiara il criterio che la giustifica |
| **Yak shaving sulla configurazione** | Il tempo va nella config invece che in studio e sviluppo | I cancelli G0–G8 sono criteri di uscita, non di perfezione. Configurare è un'attività calendarizzata |
| **Agent che procede senza verifica** | Deriva silenziosa fra repo e macchine | `PROGRESS.md`; un solo step in volo; nessun passaggio senza feedback; `--dry-run` come contratto |
| **Plymouth su NVIDIA e su resume da ibernazione** | Boot non completa o sfarfalla | Step isolato, riavvio di verifica, ripiego immediato: rimuovere l'hook e rigenerare l'initramfs. Il secondo kernel resta la rete di sicurezza |
| **Contrasto della variante chiara** | Variante inaccessibile e inutilizzabile | `phi theme check` come verifica eseguibile, bloccante per G5 |
| **Divergenza stilistica progressiva** | `I-05` decade silenziosamente | Nessun colore fuori dai token; l'hook pacman rigenera dopo ogni aggiornamento; `--dry-run` mostra ogni deriva |
| **Storico clipboard che cattura password** | Violazione `I-08` | Esclusione via MIME `x-kde-passwordManagerHint`, **subordinata alla scelta del password manager**: KeePassXC lo imposta già. Se si sceglie altro, l'esclusione va reimplementata |
| **Repo pubblico su GitHub scritto dall'agent** | Esposizione accidentale | Nessun segreto, nessun IP, nessun nome di rete privata, nessun topic di notifica in nessun repo. Regola verificata a ogni step |
 
---
 
## 19. Registro delle decisioni
 
Continuazione di `phios-architettura.md` §19 e `phios-agente.md` §16.
 
| # | Data | Ambito | Decisione | Alternative scartate | Reversibile? |
|---|---|---|---|---|---|
| 101 | 2026-09-06 | §3.1 | Topologia multi-repo: `phios-dotfiles` per la sola configurazione, un repo per ogni software proprio, distribuzione tramite repo pacman firmato `[phi]` servito da `mini` | Monorepo unico; submodule git; build su ogni client | Sì, ma costosa dopo M2 |
| 102 | 2026-09-06 | §3.2 | GitHub è il remote di lavoro dell'agent; `mini` resta sorgente di verità personale e riceve solo push dall'utente | Agent con accesso alla rete overlay | Sì |
| 103 | 2026-09-06 | §3.3 | `Q-01` rimandata: solo T0, più T3 container sul solo server. Conseguenze accettate esplicitamente per overview finestre, gesture mouse, face unlock e stack \*arr | Chiudere ora su `aurutils` o su `paru` | Sì, ed è previsto un trigger di riapertura |
| 104 | 2026-09-06 | §3.4 | Ristrutturazione dei dotfiles come milestone zero, senza feature nuove, con criterio di uscita "nessuna regressione" | Struttura attuale estesa in modo additivo | No, senza rifare il lavoro |
| 105 | 2026-09-06 | §5.5 | Il materiale `/etc` vive nel repo ma non viene mai applicato dallo script: `--system-diff` mostra la deriva, l'applicazione è manuale | `install.sh` con `sudo`; `/etc` fuori dal repo | Sì |
| 106 | 2026-09-06 | §5.4 | Manifest di stato per macchina, che permette la rimozione dei file non più previsti | Symlink senza tracciamento | Sì |
| 107 | 2026-09-06 | §5.6 | Lo stato runtime vive in `$XDG_STATE_HOME/phi` e non entra mai nel repo; gli sfondi sono copiati, mai referenziati | Stato dentro il repo; sfondi referenziati al percorso originale | Sì |
| 108 | 2026-09-06 | §6.4, C-01 | Nessun font patchato: `font-mono` non patchato più font di soli simboli in fallback `fontconfig`, con `symbol_map` in `kitty` a coprire il caso `yazi` che era l'unica ragione del font patchato | Mantenere il font patchato | Sì |
| 109 | 2026-09-06 | §9.2, C-04 | ClamAV come **servizio residente con scansione on-access** su `zotac` e `razer`, su percorsi dichiarati e non sull'intero filesystem. Su `mini` nessun daemon: scansione delegata a `zotac` | `clamd` anche sul server; sola scansione on demand ovunque; on-access su tutto il filesystem | Sì |
| 110 | 2026-09-06 | §9.4, C-05 | LanguageTool è un servizio **locale per client**, attivato su socket, non un servizio del server | LanguageTool su `mini`; servizio esterno | Sì |
| 111 | 2026-09-06 | §10.2 | Sincronizzazione file con **Syncthing**, granularità per cartella coerente con ADR 040; opera solo su `/srv/cloud` | Nextcloud; Seafile; rclone | Sì |
| 112 | 2026-09-06 | §10.3 | Libreria foto **senza indicizzazione ML**: struttura per data, import EXIF, deduplica per hash, visualizzatore locale. Rinuncia esplicita alla ricerca semantica | Immich; PhotoPrism | Sì, se cambia l'hardware |
| 113 | 2026-09-06 | §10.4, C-02 | Stack \*arr via **T3 container rootless**, in due stadi: Prowlarr più `qbittorrent-nox` subito, Radarr e Sonarr subordinati a misura di RAM | Attendere la chiusura di `Q-01`; installare tutto subito | Sì |
| 114 | 2026-09-06 | §10.4, C-03 | **`lidarr` escluso**: duplica la pipeline musicale già decisa (ADR 012, 023). La ricerca arriva da Prowlarr, l'ingestione resta `phi music add` | Adottare Lidarr come gestore della libreria musicale | Sì |
| 115 | 2026-09-06 | §10.4 | `qbittorrent-nox` come client di download, scelto per il download sequenziale e la priorità al primo e ultimo pezzo — requisiti già derivati da R2 e dall'accoppiamento dei sottotitoli | Transmission; altri client | Sì |
| 116 | 2026-09-06 | §9.1 | Animazione di boot con **Plymouth**, tema custom con Φ in Ruolo A, che fornisce anche il prompt grafico della passphrase LUKS | Logo statico con boot silenzioso; nessuna animazione | Sì |
| 117 | 2026-09-06 | §11.1, C-12 | Motore dell'agente AI: **`opencode`**, linea stabile dai repository ufficiali. `Q-40` chiusa. Il contratto motore↔client resta invariato | Altro motore; harness proprio | Sì per A1, no per A2 |
| 118 | 2026-09-06 | §9.12, C-08 | Il pannello impostazioni ha **nove** sezioni: aggiunte Security e Notifications | Sette sezioni | Sì |
| 119 | 2026-09-06 | §14 | Confine di responsabilità agent/utente: l'agent produce file nei repository, l'utente cambia lo stato delle macchine. Nessuna eccezione | Agent con accesso alle macchine | No |
| 120 | 2026-09-06 | §16 | Ciclo a uno step in volo, con `PROGRESS.md` come memoria durevole e un commit per step | Più step in parallelo; nessun tracciamento persistente | Sì |
| 121 | 2026-09-08 | §8.4, `Q-N02` | Elenco workspace in barra: **per-monitor**, non condiviso — ogni barra mostra solo i workspace del proprio monitor (`Bar/modules/Workspaces.qml`, S-22). Confermato dall'utente col compositore davanti, come richiesto dal `DONE WHEN` di S-22 | Elenco condiviso su ogni monitor, con indicazione di quale monitor possiede ciascun workspace | Sì, un solo filtro da rimuovere |
| 122 | 2026-09-08 | shell §2, `Q-N03` | btop vive su uno **special workspace dedicato**, con un **toggle visivo in barra** trattato come i pulsanti dei workspace — non un workspace normale a ID alto e persistente. Decisione presa, implementazione non ancora assegnata a nessuno step | Workspace normale a ID alto e persistente; toggle solo nelle impostazioni (il ripiego originale di `Q-N03`) | Sì |
| 123 | 2026-09-09 | §6.4, `Q-N01` | `font-mono`: **Source Code Pro**, terzo membro della stessa superfamiglia Adobe di `font-reading`/`font-ui` — coerenza tipografica sulle tre superfici di testo, sulla proposta del piano (Iosevka, gabbia più stretta) | Iosevka | Sì, un token e un pacchetto |
| 124 | 2026-09-09 | §6.7 classe 5, `Q-N04` | `systemd-boot` **non tematizzato**, lasciato al default: costo di lavoro non giustificato da uno schermo visibile solo se si interrompe il boot, con l'identità già portata dallo splash Plymouth (S-53) | Tematizzare la voce di menu `systemd-boot` | Sì |
| 125 | 2026-09-09 | §8.2.3 architettura, S-54 | Tema cursore **`whiteglass`** (pacchetto `xcursor-themes`) accettato **pur non conformando** alla descrizione "sottile, nero bordato di bianco" — `whiteglass` è bianco, non nero. Errore trovato e corretto prima dell'handoff (l'agent aveva inizialmente affermato erroneamente che conformasse); l'utente ha scelto di accettare la deviazione invece di far produrre un tema su misura | Tema su misura nero/bordo bianco (l'alternativa che il card dello step ammette esplicitamente) | Sì, un token e un pacchetto |
| 126–133 *(delta D-01…D-08)* | 2026-09-09 | `phios-agente-delta.md`, recepite in `phios-agente.md` §16 | Rilavorazione dell'agente e del pannello: memoria a 3 livelli (sistema/personalità/progetto), cartelle di interesse in sola lettura per progetto, niente cartelle note/codice di sistema, metadati di progetto strutturati, specchio delle conversazioni lato client, pannello a 4 sezioni, superficie A2 via metadati posseduti da `phi`, personalità modificabile dal pannello. Traccia `Out-of-plan: agent-panel-rework` (OOP-26/OOP-27), merge il 2026-09-09, `phi` a `v0.13.0` | vedi `phios-agente-delta.md` §2 e `phios-agente.md` §16 | in gran parte Sì; D-01 (ADR 126) tocca §8.2 come ADR 094 |
 
---
 
## 20. Indice degli step
 
La sequenza dettagliata vive in `phios-agent-brief.md`. Mappa sintetica:
 
| Milestone | Step | Titolo |
|---|---|---|
| M0 | S-00 … S-06 | Fondazione dotfiles |
| M1 | S-10 … S-15 | `phi` e distribuzione |
| M2 | S-20 … S-25 | Shell: scheletro e barra |
| M3 | S-30 … S-39 | Superfici di sessione |
| M4 | S-40 … S-46 | Impostazioni e feature |
| M5 | S-50 … S-54 | Identità e stilizzazione |
| M6 | S-60 … S-68 | Servizi e strumenti |
| M7 | S-70 … S-76 | Agente AI |
| M8 | S-80 … S-83 | App custom |
| Parallelo | P-01 … P-08 | Tracce indipendenti — `phios-agent-parallel.md` |
