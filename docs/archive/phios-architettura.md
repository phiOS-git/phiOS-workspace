# phiOS — Documento di architettura
 
**Versione:** 2.1 • **Stato:** documento vivo, compilato incrementalmente
**Ultimo aggiornamento:** 2026-08-29
 
---
 
## 0. Come si legge e si compila questo documento
 
### 0.1 Legenda stati
 
| Marker | Significato |
|---|---|
| `[OK]` | Deciso e approvato. Vincolante. |
| `[TBD]` | Da decidere. Contiene *opzioni candidate*, non approvate. |
| `[?]` | Richiede input. Rimanda a `Q-nn` (§21). |
| `[BLOCK]` | Decisione bloccante: altre sezioni non si chiudono prima. |
| `[VUOTO]` | Da compilare in sessione futura. |
 
### 0.2 Regole di compilazione
 
1. Nessun pacchetto entra in §20 senza approvazione esplicita.
2. Ogni `[TBD]` si chiude producendo una voce in §19 (ADR): opzione scelta, alternative scartate, motivazione, reversibilità.
3. Le colonne "Origine" nelle tabelle candidati sono **indicative e da verificare** al momento dell'installazione (`pacman -Si`, stato AUR): la collocazione dei pacchetti nei repo cambia nel tempo.
4. Una sezione è "chiusa" solo con: (a) ADR, (b) config versionata, (c) procedura di ripristino documentata.
---
 
## 1. Invarianti di progetto
 
| ID | Invariante | Implicazione operativa |
|---|---|---|
| `I-01` | Nessun pacchetto AIO / distro-config / stack pre-assemblato | Escluse distribuzioni Neovim, dotfile-bundle Hyprland, stack self-host chiavi in mano |
| `I-02` | Provenienza software governata da policy di sicurezza, non da preferenza estetica | §2: tiering con requisiti crescenti |
| `I-03` | Nessun software proprietario o a pagamento salvo deroga motivata | Deroghe registrate in §2.3 |
| `I-04` | Ogni feature deve essere dimostrabilmente necessaria | Ogni sezione dichiara il *job to be done* |
| `I-05` | Coerenza stilistica totale, con aggiornamento live del tema | I colori non si configurano per-app: si **generano** e si **ricaricano** (§7) |
| `I-06` | Preferenza TUI; GUI solo se completamente tematizzabile | Filtro di ammissibilità per ogni candidato GUI |
| `I-07` | Il server non ha WM/DE né sessione grafica | Nessuna dipendenza Wayland/X11 sul server |
| `I-08` | Dati sensibili (ambito clinico/universitario) | Cifratura at-rest obbligatoria; superficie di rete minima |
| `I-09` | Configurazione riproducibile da zero | Reinstallare una macchina è una procedura, non una ricostruzione a memoria |
| `I-10` | Il costo di manutenzione è un costo reale | Ogni app custom è debito permanente (§10.1) |
| `I-11` | Identità unificata `phi` | Un solo punto di ingresso CLI, una sola identità visiva (§7.7, §10.2) |
 
---
 
## 2. Policy di provenienza del software — **decisa in linea di principio**
 
### 2.1 Principio approvato
 
AUR e software proprietario sono ammessi **solo dove necessari**, e la scelta del metodo di installazione è governata dalla sicurezza, non dalla comodità. Dove esiste un pacchetto già mantenuto e installabile in modo sicuro, si preferisce quello allo sviluppo proprio; dove la catena di distribuzione è opaca o non verificabile, si preferisce lo sviluppo proprio o la build controllata.
 
### 2.2 Tiering operativo
 
| Tier | Origine | Requisiti obbligatori | Uso previsto |
|---|---|---|---|
| T0 | `core` / `extra` | Nessuno | Default assoluto |
| T1 | AUR, build da sorgente upstream | Revisione del PKGBUILD ad ogni aggiornamento; upstream con tag/release firmate; build in chroot pulito; pin di versione | Componenti mancanti nei repo |
| T2 | AUR `-bin` | Solo se il binario è pubblicato **dall'upstream stesso**; checksum verificato | Eccezione, non regola |
| T3 | Container OCI | Solo lato server; immagine ufficiale upstream; rootless; isolamento e limiti espliciti | Servizi con dipendenze invasive |
| T4 | Build manuale in `/usr/local` o `~/.local` | Unità di aggiornamento propria; verifica firma upstream | Ultima risorsa |
| — | **Escluso** | curl-pipe-sh, repo di terzi non ufficiali, binari ripacchettizzati da ignoti | — |
 
### 2.3 Igiene AUR `[TBD]` `[?]`
 
L'esposizione principale non è "usare l'AUR", è **come** lo si usa. Da decidere:
 
| Approccio | Meccanismo | Vantaggio di sicurezza | Costo |
|---|---|---|---|
| `makepkg` manuale + repo locale firmato | Build in chroot pulito, pacchetti firmati e serviti da un repo locale | Massimo controllo; revisione forzata; build isolata | Manuale, più passaggi |
| Helper con revisione obbligatoria | Helper AUR con flag di revisione diff attivo di default | Buon compromesso, revisione dei diff ad ogni update | Dipende dalla disciplina personale |
| Helper senza revisione | Installazione automatica | Nessuno | Inaccettabile sotto `I-08` |
 
Candidati (non approvati): `devtools` + `makechrootpkg` + repo locale; `aurutils` (workflow orientato al repo locale, molto vicino a pacman); `paru` (revisione diff integrata); `yay`.
 
`Q-01`: quale approccio AUR? La build in chroot pulito è raccomandata in ogni caso, perché isola lo script di build dal sistema reale.
 
### 2.4 Deroghe proprietarie accettate
 
| Caso | Motivazione | Contenimento |
|---|---|---|
| Driver NVIDIA (RTX 3060 Ti) | Nessuna alternativa prestazionalmente adeguata per Unreal e VR | Solo su `desktop` |
| Unreal Engine | Requisito di dominio non sostituibile | Solo su `desktop`; account Epic necessario per l'accesso al sorgente |
| Steam / Proton | Necessario per la libreria giochi esistente | Solo su `desktop`; valutare isolamento (§11.3) |
| Firmware CPU/Wi-Fi/SSD | Hardware non funzionante senza | Inevitabile |
| Firma app iOS | Vedi §12.2 | Aggirabile via AltStore o abbandonando iOS |
 
---
 
## 3. Inventario, ruoli e vincoli hardware
 
| Host | Hardware | RAM | Storage | Stato attuale | Ruolo |
|---|---|---|---|---|---|
| `mini` | Mac mini **Macmini7,1** (Late 2014), i5-4260U Haswell dual-core | **4 GB, saldata** | 512 GB interno + SSD esterni USB 512 GB e 1 TB | Arch installato, Tailscale e Navidrome attivi, **nessun dato da preservare** | Sorgente di verità, servizi, sempre acceso. Nessuna sessione grafica (`I-07`) |
| `zotac` | Ryzen 5 5600X, ROG STRIX B550-I, RTX 3060 Ti 8 GB | 32 GB 3600 | NVMe **500 GB Gen4 con DRAM** → sistema; NVMe **2 TB Gen3** → massa: giochi, Unreal, modelli, file locali. Nessun file di sistema, quindi riallocabile | Dischi pronti a essere svuotati | Gaming, VR, game dev, **nodo di calcolo AI** (§11.7) |
| `razer` | Razer Book | 16 GB | 512 GB | Windows, **vuoto, nulla da preservare** | Studio universitario, uso quotidiano |
| `mobile` | Android o iOS via AltStore (`Q-03`) | — | — | — | Client di consumo |
 
**Conseguenza operativa importante:** né il server né il laptop contengono dati da preservare. Le reinstallazioni sono a rischio zero e possono avvenire nell'ordine che preferiamo. L'unico dato esistente da non toccare è la partizione Windows del desktop, che sta su un disco fisicamente separato da quello destinato a phiOS.
 
### 3.1 Vincoli del server — **caratterizzato** `[OK]`
 
`Macmini7,1`, Late 2014, i5-4260U (Haswell, 2 core / 4 thread, 15 W), 4 GB di RAM, SSD interno da ~500 GB, USB 3.0 e due porte Thunderbolt 2.
 
| Fattore | Esito | Conseguenza |
|---|---|---|
| Nessun chip T2 | Favorevole | Nessuna complicazione kernel: Arch gira già |
| Nessun TPM | Confermato | Sblocco automatico del disco non disponibile → §4.4 già decisa di conseguenza |
| USB 3.0 | Favorevole | ~400 MB/s sugli SSD esterni: sufficiente per streaming VR ad alto bitrate e per i backup. **Thunderbolt 2 non serve inseguirlo** |
| Quick Sync Haswell | Limitato | Decodifica hardware H.264 sì, **HEVC no**. Irrilevante in direct play, dirimente se si tentasse la transcodifica |
| **4 GB di RAM, saldata** | **Vincolo dominante** | Non aggiornabile su questo modello: il quantitativo è definitivo. Da verificare con `dmidecode -t memory` |
 
#### 3.1.1 La RAM è il vincolo che pota l'albero delle scelte
 
4 GB per un server che deve ospitare media, git, sync e backup è poco, e questo **chiude o restringe diverse sezioni ancora aperte**:
 
| Sezione | Effetto |
|---|---|
| §9.4 Foto | Le soluzioni con indicizzazione ML sono **fuori portata**: richiedono un database più servizi di inferenza, diversi GB solo per stare accese. Resta praticabile l'approccio minimo: struttura di cartelle, upload automatico, visualizzatore locale. Risponde di fatto a `Q-36` |
| §9 Modello di deployment | Ogni container aggiunge overhead di runtime. Su 4 GB le **unit systemd native** sono la scelta materialmente migliore, non una preferenza estetica. Orienta `Q-33` |
| §9.6 Media | Conferma definitiva del **direct play**: nessuna transcodifica, in nessun caso |
| §9.7 AI | Nessun modello locale sul server. Solo API esterne, come già previsto |
| §9.1 Git | Un forge completo è sostenibile ma pesa. Un server git leggero libera memoria per il resto |
 
Buona notizia sotto il criterio di semplicità: il vincolo **elimina opzioni pesanti** che avrebbero complicato il sistema. Meno scelte da fare, e quelle rimaste sono le più semplici.
 
#### 3.1.1 Riavvio automatico e funzionamento headless `[TBD]`
 
Due particolarità del Mac mini che vanno risolte in fase di installazione, entrambe non ovvie:
 
**Riavvio dopo blackout.** L'opzione esiste a livello hardware, ma il bit corrispondente nel controller di power management non è persistente fra un riavvio e l'altro: macOS lo riscrive a ogni avvio. Su Linux quindi non si eredita nulla dalla configurazione precedente: serve uno script eseguito a ogni boot che imposti il bit `AFTERG3_EN` nel registro del bridge LPC via `setpci`. L'indirizzo del registro dipende dal southbridge specifico del modello, quindi la procedura va derivata dopo aver chiuso `Q-02`.
 
Conseguenza pratica: **il server può ripartire da solo, ma solo se questo script esiste.** Va incluso nel provisioning (§5.3) e verificato con un test reale staccando l'alimentazione, non dato per funzionante.
 
**Avvio senza monitor.** Il funzionamento headless può richiedere un adattatore fittizio sulla porta video per consentire l'avvio senza display collegato. Da verificare empiricamente sul modello specifico; è una spesa trascurabile ma se manca il sintomo è un server che non completa l'avvio senza motivo apparente.
 
### 3.2 Vincoli storage per host `[?]`
 
- **`desktop` (512 GB + 1 TB):** Unreal Engine compilato da sorgente più cache derivate occupa un ordine di grandezza di centinaia di GB, a cui si sommano i progetti e la libreria giochi. Il budget è stretto. `Q-04`: quale dei due dischi è NVMe e quale SATA? La cache di build e la DDC di Unreal vanno sul più veloce.
- **`laptop` (512 GB):** non può ospitare copie complete delle librerie media. Questo **impone la sincronizzazione selettiva** (§9.3) e rende obbligatorio il meccanismo di pinning offline (§10.5).
- **`server` (512 GB interno + 512 GB + 1 TB esterni):** vedi §9.2.
---
 
## 4. Fondamenta di sistema `[BLOCK]`
 
### 4.1 Procedura di installazione base `[VUOTO]`
Da definire come procedura scritta e ripetibile: layout partizioni, locale, timezone, utenti, `mkinitcpio`, bootloader, primo avvio.
 
### 4.2 Filesystem — orientamento **Btrfs** `[BLOCK]` `[?]`
 
| Opzione | Snapshot | Integrità | Attrito |
|---|---|---|---|
| **Btrfs** | Nativi CoW, istantanei, `send/receive` incrementale | Checksum dati e metadati | In-tree nel kernel → tier T0 puro. Evitare RAID5/6 |
| **ZFS** | Nativi, maturi, cifratura nativa per dataset | Checksum + scrub | Modulo out-of-tree: un aggiornamento kernel può precedere il modulo compatibile e impedire il boot. Attrito diretto con `I-02` |
| **ext4 + LVM** | Snapshot thin | Nessuna | Nessun `send/receive`; snapshot costosi e scomodi |
| **bcachefs** | Nativi | Sì | Maturità upstream non allineata a `I-08` |
 
**Nota sugli SSD esterni USB:** un filesystem CoW su USB è vulnerabile ai reset del controller. **Nessun RAID né pool attraverso USB**: ogni SSD esterno è un filesystem indipendente e la ridondanza si ottiene per replica esplicita (§13), non per mirroring. I checksum Btrfs sono comunque un vantaggio netto qui: un enclosure che perde scritture corrompe silenziosamente su ext4, mentre su Btrfs l'errore emerge.
 
`Q-05`: conferma Btrfs su tutte e tre le macchine.
 
#### 4.2.1 Cosa va deciso all'installazione e cosa si può rimandare
 
Distinzione operativa fondamentale. La scelta del filesystem è economica; **è il layout che è costoso da sbagliare**, e il layout si decide una volta, in trenta minuti, il giorno dell'installazione.
 
| Elemento | Quando | Perché |
|---|---|---|
| Filesystem | **Installazione** | Cambiarlo dopo significa reinstallare o fare backup e restore completo |
| LUKS sotto il filesystem | **Installazione** | Non si aggiunge la cifratura a un sistema esistente senza svuotarlo e ricrearlo |
| **Layout dei subvolumi** | **Installazione** | Creare un subvolume dopo è possibile, ma spostarci dentro dati già esistenti è una migrazione, non una modifica di config |
| Opzioni di mount (compressione, `noatime`) | **Installazione** | La compressione si applica solo ai dati scritti dopo: attivarla in seguito lascia compresso solo il nuovo |
| `nodatacow` sulle directory di database | **Installazione** | L'attributo vale solo per i file creati dopo averlo impostato: va messo sulla directory **vuota**, prima che il servizio scriva |
| Collocazione dello swap | **Installazione** | Uno swapfile su CoW richiede trattamento speciale; l'ibernazione richiede parametri di boot coerenti |
| Dimensione ESP e partizioni | **Installazione** | Ridimensionare dopo è possibile ma fastidioso |
| — | — | — |
| Strumento di snapshot e pianificazione | **Quando vuoi** | Si installa e configura in qualsiasi momento su un layout corretto |
| Hook per snapshot pre-aggiornamento | **Quando vuoi** | Configurazione, non struttura |
| Retention e pruning | **Quando vuoi** | |
| Replica verso SSD esterno | **Quando vuoi** | |
| Backup cifrato offsite | **Quando vuoi**, ma **prima di mettere dati reali** | Vedi §17 P1 |
 
Risposta diretta alla domanda: **sì, puoi rimandare tutto il sistema di backup.** Non puoi rimandare il layout che lo rende possibile. Un sistema installato con un layout sbagliato non è irrecuperabile, ma correggerlo costa una migrazione di dati; installato con il layout giusto, aggiungere snapper o btrbk sei mesi dopo è un pomeriggio di lavoro.
 
#### 4.2.2 Cosa è concretamente uno snapshot
 
Serve l'intuizione giusta, perché determina cosa ha senso fare.
 
Uno snapshot Btrfs è **un secondo riferimento agli stessi blocchi su disco**. Alla creazione occupa circa zero byte ed è istantaneo, indipendentemente da quanti dati ci sono dentro. Cresce solo man mano che l'originale diverge: se modifichi un file da 1 GB, i blocchi vecchi restano vivi perché lo snapshot li referenzia, e lo snapshot "pesa" quel delta. Per questo puoi permetterti snapshot orari senza pensarci.
 
Il rollback consiste nel cambiare quale subvolume viene montato all'avvio. Non c'è una copia da ripristinare.
 
Le due conseguenze che contano:
 
1. **Uno snapshot vive sullo stesso disco dell'originale e muore con lui.** Non è un backup. Protegge da errore umano e aggiornamento fallito, non da guasto, furto o incendio.
2. **Cancellare file su un filesystem pieno non libera spazio** finché gli snapshot che li referenziano esistono. È la trappola classica di Btrfs: si arriva al disco pieno, si cancella, non cambia niente, e il sistema diventa difficile da salvare. Mitigazioni: retention aggressiva, monitoraggio dello spazio con soglia di allarme (§9.10), e quote per subvolume se serve.
#### 4.2.3 Layout subvolumi proposto `[TBD]` `[?]`
 
Il principio: **separare ciò che si vuole poter annullare da ciò che non si vuole mai annullare, e da ciò che non ha senso conservare.**
 
Base comune alle tre macchine:
 
| Subvolume | Punto di mount | Nello snapshot di sistema? | Razionale |
|---|---|---|---|
| `@` | `/` | Sì | È l'oggetto del rollback |
| `@home` | `/home` | No, snapshot proprio | Annullare un aggiornamento non deve annullare il documento scritto stamattina |
| `@snapshots` | `/.snapshots` | No | Contenitore degli snapshot |
| `@log` | `/var/log` | **No** | Dopo un rollback vuoi ancora i log che spiegano cosa è andato storto |
| `@cache` | `/var/cache` | No | Ricostruibile, e la cache dei pacchetti è voluminosa |
| `@swap` | `/swap` | No, `nodatacow` | Swapfile su CoW richiede attributi espliciti |
 
Aggiunte per host:
 
| Host | Subvolume | Razionale |
|---|---|---|
| `desktop` | `@games`, `@unreal` | Centinaia di GB ricostruibili: fuori da snapshot e backup, altrimenti saturano tutto |
| `server` | Un subvolume per servizio sotto `/srv`, con `nodatacow` sulle directory dei database | Snapshot e retention differenziati per servizio; evita la frammentazione dei DB |
| `laptop` | — | Layout base sufficiente |
 
**Stato: provvisorio, da riconfermare prima dell'installazione reale.** Il layout base è adottato come ipotesi di lavoro perché nessuna delle sue voci è controversa e ognuna previene un guasto concreto. Tre elementi restano però subordinati a decisioni aperte:
 
| Elemento | Dipende da | Effetto |
|---|---|---|
| Dimensione e presenza di `@swap` | `Q-07` (ibernazione sul laptop) | L'ibernazione richiede swap dimensionata rispetto alla RAM e parametri di resume |
| `@games` / `@unreal` | `Q-04` (quale disco è NVMe) | Se finiscono su un disco fisicamente diverso sono un filesystem separato, e la questione subvolumi non si pone: semplicemente non se ne fanno snapshot |
| Subvolumi per servizio sul server | `Q-33` (unit native o container) | I container spostano il punto in cui i dati risiedono e quindi dove vanno i confini |
 
`Q-67` resta aperta ma non blocca: si riconferma alla checklist di §4.2.4.
 
**Trappola da tenere presente:** gli **hardlink non attraversano i confini di subvolume**, e spostare un file da un subvolume all'altro è una copia, non una rinomina. Se prevedi un flusso in cui i file scaricati vengono collegati con hardlink dentro la libreria media invece di essere duplicati, sorgente e destinazione devono stare nello stesso subvolume. Va deciso insieme al layout dati di §9.2.
 
#### 4.2.3.1 Perimetro degli snapshot — **deciso (ADR 070)**
 
Obiettivo dichiarato: snapshot delle **sole configurazioni**, per poter tornare indietro dopo un errore introducendo una feature. Niente archivi, niente librerie, niente giochi.
 
**Come funziona il meccanismo, perché determina il layout.** Uno snapshot cattura **esattamente un subvolume e non scende nei subvolumi annidati**. Non "li include a poco prezzo": non li include affatto. Quindi la regola è secca:
 
> Tutto ciò che non deve mai finire in uno snapshot deve essere un subvolume a sé, o un filesystem a sé.
 
Perimetro risultante:
 
| Host | Nello snapshot | Fuori |
|---|---|---|
| `mini` | `@` (sistema e configurazioni), `/var/lib/*` (stato e database dei servizi) | **Tutto `/srv`**: musica, video, foto, cloud, git |
| `zotac` | `@` e `@home` sul NVMe 512 | `@cache`, `@log`, e **l'intero NVMe 1 TB**, che essendo un filesystem separato è escluso per costruzione |
 
Il gioco da 140 GB spostato sul NVMe 1 TB **non può** finire in uno snapshot: non è una configurazione da ricordarsi, è una impossibilità strutturale.
 
**Perché `/var/lib` sì e `/srv` no.** Rollback coerente: se torni indietro su una configurazione, vuoi che anche il database del servizio torni allo stato corrispondente, altrimenti il servizio riparte con uno schema che la config non si aspetta. Sono piccoli, dell'ordine dei megabyte.
 
**La tua intuizione su "cartelle e utenti" è corretta, e funziona da sola.** La directory che fa da punto di mount vive sul subvolume genitore, quindi nome, proprietario e permessi *sono* nello snapshot, mentre i dati sottostanti no. Un rollback ripristina il punto di mount corretto e vuoto, con i dati intatti sotto. Utenti e gruppi vivono in `/etc`, quindi anch'essi rientrano.
 
**Nota `~/.cache` su `zotac`:** le cache degli shader dei giochi possono raggiungere decine di GB e risiedono nella home. Va reso subvolume separato ed escluso, altrimenti rientra dalla finestra ciò che si è cacciato dalla porta.
 
#### 4.2.3.2 Svantaggi reali di Btrfs
 
Per completezza, dato che li hai chiesti:
 
| Svantaggio | Ti riguarda? |
|---|---|
| Prestazioni su scritture random piccole (database) | Sì, ma mitigato da `nodatacow` già previsto |
| Contabilità dello spazio libero poco intuitiva: `df` non dice il vero, serve lo strumento nativo | Sì, è una cosa da imparare |
| Disco pieno con snapshot che trattengono i dati cancellati | Sì, mitigato da retention e allarme spazio |
| RAID5/6 inaffidabile | No, non lo userai |
| Recupero da corruzione grave più difficile che su ext4 | Marginale, mitigato dai backup |
| Richiede manutenzione periodica (scrub, e occasionalmente balance) | Sì: due timer systemd, si configurano una volta |
 
Nessuno è bloccante, e i primi tre sono quelli con cui convivrai davvero.
 
#### 4.2.4 Checklist minima del giorno dell'installazione
 
1. LUKS sotto tutto (o sotto i volumi dati, secondo §4.4).
2. Btrfs con i subvolumi di §4.2.3 già creati.
3. Opzioni di mount fissate: compressione zstd a livello basso, `noatime`.
4. `nodatacow` impostato sulle directory dei database **vuote**, prima di avviare i servizi.
5. Swap collocato e, se serve l'ibernazione, parametri di resume coerenti.
6. Secondo kernel di fallback installato (§4.6).
Tutto il resto — snapper, btrbk, restic, hook, retention — può aspettare senza costi.
 
### 4.3 Layout partizioni `[VUOTO]`
Da definire per host dopo §4.2, §4.4 e §9.2.
 
### 4.4 Cifratura at-rest — **decisa (ADR 013)** `[?]`
 
Standard di riferimento: LUKS2 con dm-crypt. Su `laptop` e `desktop`: passphrase all'avvio, con valutazione TPM sul laptop.
 
#### 4.4.1 Server: schema differenziato
 
**Decisione: root non cifrata, tutti i volumi dati cifrati, sblocco via SSH sulla rete overlay dopo l'avvio.**
 
Razionale. L'inventario dei dati sensibili del server è: repository git, foto (se implementate), file del cloud manager, vault delle password. Nessuno di questi ha bisogno di essere disponibile prima che tu sia raggiungibile. Il sistema operativo invece deve avviarsi da solo, perché è ciò che rende il server raggiungibile: dopo un blackout riparte, monta la rete, si connette al tailnet, e tu sblocchi i dati quando vuoi, da dove vuoi.
 
L'alternativa con passphrase manuale richiederebbe presenza fisica con monitor e tastiera a ogni riavvio: incompatibile con un uso reale del server durante periodi di assenza. L'alternativa con SSH nell'initramfs romperebbe il perimetro di §6.3, perché in initramfs il tailnet non è disponibile.
 
#### 4.4.2 Principio: dati contro credenziali
 
La domanda "le chiavi SSH contano come dati sensibili?" ha una risposta precisa, ed è il criterio che governa cosa può stare sulla root in chiaro:
 
| Categoria | Esempio | Danno se esposto | Collocazione |
|---|---|---|---|
| **Dati** | Foto, documenti, repository, database | Permanente e irreversibile | **Volume cifrato** |
| **Credenziale revocabile** | Chiave host SSH, stato del nodo Tailscale | Limitato al tempo che passa prima della revoca | Root in chiaro, **con procedura di revoca documentata** |
| **Segreto non revocabile** | Chiave del repository di backup, chiave privata `age`/`sops` | Permanente: la chiave del repo backup decifra ogni backup mai fatto | **Volume cifrato, senza eccezioni** |
 
Il vault delle password è un caso a parte: è cifrato per costruzione dal suo stesso formato, quindi risulta protetto due volte. È l'elemento meno dipendente dalla cifratura del disco.
 
#### 4.4.3 Sblocco a cascata
 
Una sola passphrase apre il volume dati interno; i keyfile dei due SSD esterni risiedono su quel volume, quindi lo sblocco si propaga. Una passphrase da ricordare, tre volumi protetti. Esposto come `phi server unlock`.
 
Il disco di backup è comunque cifrato lato client da restic o borg: LUKS lì è ridondanza a costo quasi nullo, che nasconde anche la struttura del repository.
 
#### 4.4.4 Vincoli implementativi obbligatori
 
**Dipendenze di mount.** Ogni servizio che usa dati cifrati deve dichiarare una dipendenza systemd dal mount corrispondente. Non è pedanteria: un servizio che parte con la propria directory dati assente può ricrearla vuota, e un client di sincronizzazione bidirezionale che vede una libreria vuota può interpretarlo come "tutti i file sono stati cancellati" e propagare le cancellazioni. È una vera via di perdita dati, e va chiusa in fase di scrittura delle unit (§4.7).
 
**Finestra di backup.** Finché i volumi sono bloccati, i backup non possono girare. Se il server riavvia alle 3 di notte e sblocchi la sera, quella finestra è saltata. Mitigazione già prevista: allarme se il backup non viene eseguito da N giorni (§13.6).
 
**Rischio accettato.** Un attaccante con accesso fisico può manomettere la root in chiaro e catturare la passphrase al successivo sblocco. Richiede accesso non rilevato all'abitazione; non è la minaccia dominante per questo profilo. Mitigazione parziale a costo zero: gli snapshot Btrfs permettono di confrontare la root con uno stato noto buono, quindi una manomissione sarebbe rilevabile.
 
**Trigger di revisione.** Se `Q-55` (materiale clinico o dati identificabili) dovesse risultare affermativa, quei dati vanno su un volume **fuori dalla cascata**, con passphrase distinta, montato solo durante l'uso.
 
#### 4.4.4.1 `zotac` — **deciso (ADR 071)**
 
La domanda era solo: quanti contenitori cifrati separati. Risposta: **uno per disco, con sblocco a cascata.**
 
| Disco | Contenitore | Sblocco |
|---|---|---|
| NVMe 512 (sistema) | LUKS2 | Passphrase all'avvio |
| NVMe 1 TB (archivio, giochi, file locali) | LUKS2 | Keyfile residente sul 512: si apre da solo dopo il primo sblocco |
 
Digiti una passphrase sola. Cifrare anche i giochi non ha costo apprezzabile — la decifratura è accelerata in hardware dalla CPU — ed evita di dover valutare ogni volta se un file è sensibile.
 
#### 4.4.5 Laptop `[?]`
 
Il rischio dominante è il furto con macchina accesa o sospesa, non il furto a macchina spenta. `Q-07`: sospensione su RAM (comoda, ma la chiave resta in memoria), ibernazione su swap cifrata (più sicura, richiede swap dimensionata e parametri di resume), o spegnimento?
 
### 4.5 Boot `[TBD]`
 
| Candidato | Note |
|---|---|
| `systemd-boot` | Minimale, nessuna configurazione superflua, integrato con systemd. Richiede ESP montata |
| GRUB | Più flessibile, supporta il boot da snapshot Btrfs con strumenti dedicati |
| `rEFInd` | Storicamente il più tollerante alle particolarità dell'EFI Apple: candidato specifico per il server |
| UKI (Unified Kernel Image) | Kernel+initramfs+cmdline in un unico binario firmabile. Rilevante solo dove Secure Boot è applicabile (quindi non sul Mac mini) |
 
Il boot da snapshot in caso di aggiornamento fallito è una funzionalità di sicurezza operativa, non un vezzo: influisce sulla scelta. `Q-08`.
 
### 4.6 Kernel — **deciso (ADR 068)**
 
| Host | Primario | Fallback | Motivo |
|---|---|---|---|
| `mini` | `linux-lts` | `linux` | Server sempre acceso, hardware del 2014 già supportato da anni: le novità del kernel non portano nulla, la stabilità sì |
| `zotac` | `linux` | `linux-lts` | Serve supporto recente per GPU e Wayland |
| `razer` | `linux` | `linux-lts` | Hardware portatile recente: gestione energetica e Wi-Fi beneficiano di kernel aggiornati |
 
`linux-zen` scartato: introduce una variante in più da coordinare con il modulo NVIDIA, in cambio di ottimizzazioni di latenza che su un desktop con 32 GB non si notano.
 
**Vincolo NVIDIA su `zotac`:** il modulo va installato in versione **DKMS**, così si ricompila per entrambi i kernel. Senza, l'aggiornamento del kernel senza il modulo corrispondente lascia la macchina senza sessione grafica — il guasto più comune su Arch con NVIDIA. Con DKMS più kernel di fallback più snapshot pre-aggiornamento (§5.2.3) il rischio è coperto tre volte.
 
### 4.6.1 Locale, fuso orario e tastiera — **deciso (ADR 069)** `[?]`
 
| Voce | Scelta |
|---|---|
| Fuso orario | `Europe/Rome`, sincronizzazione oraria di rete attiva |
| Locale di sistema | **Inglese integrale** (`en_US.UTF-8`). Nessun formato italiano |
| Unica eccezione consigliata | `LC_PAPER=it_IT.UTF-8`, altrimenti la stampa predefinita è su formato Letter invece che A4 |
| Layout tastiera | ANSI fisico, layout logico `us` più **compose key** per le accentate |
| Italiano | Solo come dizionario del correttore ortografico, che è un pacchetto e non un locale |
 
**Perché il sistema in inglese.** I messaggi d'errore tradotti sono incomparabilmente meno ricercabili: un errore in italiano restituisce quasi sempre zero risultati utili.
 
### 4.7 Init e hardening dei servizi `[VUOTO]`
systemd è dato. Da definire: template di unit riusabile con direttive di hardening applicate di default a ogni servizio scritto in proprio, uso di timer al posto di cron, convenzione di naming `phi-*` per le unit del sistema.
 
---
 
## 5. Gestione della configurazione `[BLOCK]`
 
### 5.1 Struttura del repository `[TBD]` `[?]`
 
```
phios/
├── docs/                 # questo documento, ADR
├── bootstrap/            # installazione da zero, per host
├── hosts/{server,desktop,laptop}/
├── common/               # config condivise
├── design/               # token: sorgente unica di colori e tipografia (§7)
│   ├── tokens.<fmt>      # sorgente
│   └── templates/        # un template per ogni app tematizzabile
├── packages/             # software sviluppato in proprio
│   ├── phi/              # CLI unificata (§10.2)
│   └── ...
└── services/             # unit systemd e config dei servizi server
```
 
`Q-09`: monorepo unico o repo separati per config, software e infrastruttura? Il monorepo semplifica la coerenza dei token (§7) e il versionamento atomico di "tema + template + app".
 
### 5.2 Meccanismo di deployment `[TBD]` `[?]`
 
Requisito derivato da `I-05` e dal nuovo requisito di **tema live**: serve templating, non solo symlink; e serve un percorso di rigenerazione + ricarica invocabile a runtime (§7.6).
 
| Candidato | Templating | Segreti | Provisioning sistema | Attrito |
|---|---|---|---|---|
| GNU Stow | No | No | No | Non soddisfa `I-05` |
| `chezmoi` | Sì | Integrata | No | Una dipendenza, ma copre templating e segreti |
| `yadm` | Sì | Sì (via gpg/transcrypt) | No | Più semplice, meno potente |
| Ansible | Sì (Jinja) | Sì (vault) | **Sì**, idempotente, agentless | Sovradimensionato per 3 host? Ma copre anche i servizi server |
| Generatore proprio (`make` + templating) | Sì | Da costruire | Parziale | Zero dipendenze, ma è software da mantenere (`I-10`) |
| Nix / home-manager | Sì | Sì | Sì | Cambia radicalmente il modello di Arch: probabile conflitto con l'intento del progetto |
 
Configurazione plausibile: **Ansible per il provisioning di sistema e servizi + generatore proprio per i token di design**, dove il secondo è invocato anche da `phi theme` a runtime. `Q-10`.
 
### 5.2.1 Utenti e gerarchia del filesystem `[TBD]`
 
Requisito espresso: nessuna cartella in posizioni non ovvie, naming conforme alle convenzioni.
 
**Account di servizio sul server.** La pratica moderna non è creare utenti a mano: systemd offre `DynamicUser=yes`, che genera l'utente all'avvio del servizio e lo elimina all'arresto. Nessun `useradd`, nessun UID da gestire, nessun account su cui si possa fare login. È **insieme più semplice e più sicuro** della gestione manuale, quindi passa il test di §0.
 
Limiti da conoscere: lo stato deve risiedere in `/var/lib/<servizio>` tramite `StateDirectory=`, e il meccanismo non funziona quando più servizi devono condividere file con proprietà stabile — che è esattamente il caso della libreria media letta da più servizi. Regola conseguente: **`DynamicUser` per i servizi con stato privato, utente statico più gruppo condiviso per quelli che toccano la libreria comune.**
 
**Collocazione dei dati sul server (FHS).** La convenzione corretta e poco usata:
 
| Percorso | Contenuto | Disco |
|---|---|---|
| `/srv/` | Dati che il sistema **serve verso l'esterno**: libreria media, repository git. È letteralmente lo scopo di `/srv` | Esterno 1 TB, montato qui |
| `/var/lib/<servizio>/` | Stato **interno** del servizio: database, indici, cache persistenti | Interno 512 GB |
| `/etc/<servizio>/` | Configurazione | Interno |
 
Questa separazione coincide con l'allocazione dei dischi già decisa in §9.2: dati voluminosi e serviti sull'esterno, stato piccolo e critico sull'interno. Niente in `/opt`, niente nella home dell'utente personale.
 
**Home sui client (XDG Base Directory).** Lo standard prevede `~/.config`, `~/.local/share`, `~/.local/state`, `~/.cache`. Molti strumenti lo ignorano e scaricano dotfile direttamente in `~`. Due leve: impostare esplicitamente le variabili XDG, e forzare per-strumento i casi non conformi. Risultato: in `~` compaiono **solo** le directory che hai scelto tu.
 
#### 5.2.2 Struttura della home e modello di sincronizzazione `[TBD]`
 
**Il nodo: due assi che vengono confusi in uno.**
 
| Asse | Domanda | Dove esiste |
|---|---|---|
| **Sincronizzazione** | Questo file esiste anche altrove? | Ovunque |
| **Materializzazione** | Il contenuto è su questo disco, o è solo un segnaposto? | Solo dove i file sono troppi per starci tutti |
 
Il paradigma macOS li mescola, ed è da lì che nasce la cartella con dentro file scaricati, file non scaricati e file solo locali. **Ma il secondo asse esiste solo quando il volume dei dati eccede il disco.** Un vault di note e PDF accumulato in nove anni si misura in pochi GB: sta interamente su 512 GB senza alcuno sfratto. Quindi per documenti e note **i segnaposto non esistono**, e il problema che temi non può presentarsi.
 
L'asse della materializzazione esiste davvero solo per i media, che infatti hanno un top-level dedicato e un sottosistema dedicato (§10.5).
 
**Conseguenza: la separazione cloud/locale serve, ma solo sull'asse della sincronizzazione.** E il modo pulito di esprimerla non è per meccanismo — `~/cloud` contro `~/local` genera esattamente gli alberi paralleli che vuoi evitare — ma **per ragione**, perché la ragione è unica e non collide.
 
Struttura **decisa (ADR 045)**, modello spaziale con radice sincronizzata:
 
| Directory | Contenuto | Sync |
|---|---|---|
| `~/desktop`, `~/documents`, `~/downloads`, `~/music`, `~/pictures`, `~/videos` | Directory standard XDG user-dirs | **No**, locali alla macchina |
| `~/cloud/` | Radice sincronizzata. Sottocartelle nominate nel tempo secondo necessità | **Sì** |
| `~/dev` | Progetti di programmazione | No: git verso `mini` è già il sync (ADR 036) |
 
Vantaggio di aderire alle XDG user-dirs: le applicazioni trovano da sole le destinazioni corrette senza configurazione. `~/music`, `~/pictures` e `~/videos` diventano anche la destinazione locale del pinning (§10.5), quindi non serve un `~/media` separato.
 
**Il rischio da presidiare, e si presidia solo con disciplina di naming:** il modello spaziale genera alberi paralleli se una sottocartella di `~/cloud` prende lo stesso nome di una directory locale. Regola: **mai `~/cloud/documents`.** Le sottocartelle di `~/cloud` si nominano per scopo, non per tipo.
 
**Dove vive il vault universitario:** dentro `~/cloud`, perché deve sincronizzare ed essere sottoposto a backup. `Q-76`: come nominarlo, dato che non può chiamarsi `documents`.
 
**Granularità della sincronizzazione.** L'unità di sync deve coincidere con l'unità che vuoi su alcune macchine e non su altre. Poiché il vault universitario serve su `razer` ma non su `zotac`, **ogni vault è una unità di sync indipendente**, e `~/doc` sciolto è un'altra. Così `razer` prende entrambe, `zotac` solo la seconda.
 
**Vincolo di progetto per l'app note (§8.13):** contenuto e stato vanno separati fisicamente fin dall'inizio. Il vault contiene **solo** i file dell'utente; indice, cache di ricerca, stato dell'interfaccia e finestre aperte vivono in `~/.local/state/<app>/`, per XDG. È la causa più comune di conflitti negli strumenti di note sincronizzati: lo stato di workspace, che è per definizione locale alla macchina, viene sincronizzato e collide. Progettarlo correttamente ora costa zero.
 
### 5.2.3 Convenzioni da fissare prima della prima installazione `[OK]`
 
Cinque scelte che oggi costano nulla e a posteriori costano una migrazione. Non sono feature: sono vincoli che tengono aperte le porte.
 
| Convenzione | Decisione | Cosa protegge |
|---|---|---|
| **Gruppo condiviso per le librerie** | Le directory sotto `/srv/media` appartengono a un gruppo dedicato, con bit setgid sulle directory. I servizi che vi accedono entrano nel gruppo | Con `DynamicUser` puro, aggiungere un secondo servizio che legge la stessa libreria produce un problema di permessi difficile da sanare dopo. Il gruppo va creato prima che i file esistano |
| **Indirizzamento solo per nome** | Nessun indirizzo IP in nessuna configurazione: solo i nomi della rete overlay | Il server cambierà rete al trasloco. Un IP scritto in un file di configurazione è un guasto differito |
| **Disciplina della lista pacchetti** | Ogni pacchetto installato entra nella lista **nel momento in cui lo si installa**, non a posteriori | È l'unica cosa che determina se §5.3 funziona davvero. Ricostruire la lista dopo, a memoria, non riesce |
| **Config a colori sempre generate** | I file che contengono colori o font sono generati da template fin dal primo giorno, anche con una palette provvisoria | Il tema si decide più avanti (ADR 060). Se le config nascono scritte a mano, aggiungere il tema dopo è una riscrittura invece che un cambio di valori |
| **Snapshot attivi da subito** | `snapper` con hook pre-aggiornamento installato all'inizio, pur rimandando i backup | Gli snapshot **non sono backup** (ADR 058 riguarda i secondi). Proteggono da un aggiornamento o una configurazione che rompe il sistema, ed è proprio durante la configurazione che questo è più probabile |
 
### 5.2.4 Feature specifiche per categoria di macchina — **deciso (ADR 074)**
 
Problema: alcune funzioni esistono solo su certe macchine — retroilluminazione tastiera e batteria sul portatile, driver NVIDIA sul desktop — e devono essere recuperabili automaticamente su una macchina nuova della stessa categoria.
 
La soluzione pulita usa **due meccanismi distinti**, e il criterio per scegliere quale è il **peso**.
 
| Meccanismo | Cosa governa | Criterio |
|---|---|---|
| **Profili** | Quali pacchetti si installano e quali config si compongono | Tutto ciò che occupa disco o introduce stato di sistema |
| **Rilevamento di capacità** | Quali moduli si attivano a runtime | Tutto ciò che è solo un modulo di interfaccia o un demone leggero |
 
**Profili.** Un host è definito come composizione di profili più eventuali override propri:
 
```
zotac = base + desktop + gaming + nvidia
razer = base + desktop + laptop
mini  = base + server
```
 
Una macchina nuova coerente si configura assegnandole i profili giusti, senza copiare nulla a mano. È anche il motivo per cui i profili sono la sede giusta per il driver NVIDIA: installarlo dove non c'è la GPU è spreco e rischio, e va deciso all'installazione, non a runtime.
 
**Rilevamento di capacità.** La shell non chiede "sono un portatile": chiede se esiste un dispositivo batteria, se esiste un dispositivo di retroilluminazione, se esiste un sensore di luce ambientale. Se sì mostra il modulo, altrimenti no. Così **una sola configurazione della shell funziona su tutte le macchine** e i moduli compaiono solo dove hanno senso, senza biforcazioni che poi divergono.
 
Regola riassuntiva: **i profili decidono cosa si installa, le capacità decidono cosa si mostra.**
 
### 5.3 Provisioning — **deciso (ADR 049)**
 
Ansible e i dotfile manager sono progettati per gestire la deriva su molte macchine. Qui le macchine sono tre e le installazioni sono rare: la loro utilità non si applica, e il costo di apprendimento e di manutenzione sì.
 
Forma adottata, minima:
 
```
bootstrap/
├── packages/{base,desktop,server}.txt   # una riga per pacchetto, commentabile
├── setup.sh                             # installa, crea directory, collega config
└── README.md                            # passi manuali (segreti, LUKS, rete)
```
 
Aggiornare i requisiti è editare un file di testo. La sola parte che richiede vera meccanica è la generazione dei config dai token di design, ed è `phi theme` (§7.6), che va scritto comunque.
 
Costo accettato: nessuna idempotenza garantita, nessun rilevamento di deriva. Su tre macchine con installazioni rare è irrilevante.
 
### 5.4 Segreti — **minimo (ADR 050)**
 
Nessun segreto entra nel repo, nemmeno cifrato: si collocano a mano durante l'installazione e il `README.md` di bootstrap elenca quali sono.
 
Le passphrase di cifratura sono **memorizzate e trascritte su carta**, in un luogo fisicamente sicuro. Non passano dal password manager: una passphrase che digiti all'avvio della macchina o per aprire un backup non ha bisogno di un gestore, e farcela passare introdurrebbe una dipendenza circolare senza guadagno.
 
Due passphrase in tutto: quella LUKS e quella del repository di backup. È l'intero sistema.
 
Il password manager (§9.8) risolve un problema disgiunto: le credenziali dei servizi web, che sono molte, cambiano spesso e vanno digitate nel browser.
 
## 6. Rete, identità e accesso
 
### 6.1 Overlay network — `[OK] Tailscale`
Da definire: ACL fra nodi con default deny, MagicDNS, exit node, scadenza chiavi, comportamento in caso di indisponibilità del control plane. `Q-12`: accetti la dipendenza da un control plane gestito da terzi (coordinamento, non traffico), o valutiamo un control plane self-hosted?
 
### 6.2 WireGuard — `[OK]`, ruolo da chiarire
Tailscale usa già WireGuard come trasporto. Un secondo overlay ha senso solo con un job distinto: fallback indipendente dal control plane, o accesso da reti che bloccano Tailscale. `Q-13`.
 
### 6.3 Perimetro di esposizione `[BLOCK]` `[TBD]` `[?]`
 
Decisione strutturante. Mantenere tutto interno alla rete overlay elimina reverse proxy pubblico, certificati pubblici, hardening anti-scansione e gran parte della superficie d'attacco — coerente con `I-08`.
 
Casi che potrebbero richiedere un ingresso: il bridge chat dell'assistente AI (§9.7), le notifiche push mobile (§12.4). Entrambi possono essere risolti **senza esporre nulla** se il dispositivo mobile è a sua volta nodo della rete overlay: è la soluzione raccomandata perché conserva il perimetro. `Q-14`.
 
### 6.4 TLS e nomi `[TBD]`
Se il perimetro resta interno, esiste un'opzione elegante: Tailscale può emettere certificati validi per i nomi del tailnet, evitando sia una CA privata da distribuire sia l'esposizione pubblica. Alternative: CA interna (`step-ca`), nessun TLS su rete già cifrata, reverse proxy (`caddy`, `nginx`). `Q-15`.
 
### 6.5 SSH `[VUOTO]`
Baseline da definire: sole chiavi, algoritmi moderni, `AllowUsers`, ascolto limitato all'interfaccia overlay, policy sull'agent forwarding, valutazione dei certificati SSH al posto di `authorized_keys`.
 
### 6.6 Firewall `[TBD]`
Candidati: `nftables` diretto (già nel sistema base, massimo controllo, nessuna astrazione), `ufw`, `firewalld`. Se nulla ascolta su interfacce pubbliche il firewall è ridondanza difensiva — accettabile, non sostitutiva.
 
---
 
## 7. Design system e identità phiOS `[BLOCK]` per §8, §10, §12
 
### 7.1 Principio architetturale
 
Palette e tipografia esistono in **un unico file sorgente** in `design/tokens`. Ogni file di configurazione che contiene colori o font è **generato**. Nessun colore hardcoded in nessuna config, incluse quelle di Neovim (§16.10) e del terminale.
 
### 7.2 Specifica cromatica `[TBD]` `[?]`
 
Definito: base BW, un accento, palette derivata.
 
Da decidere:
- **Colore d'accento: rosa pastello** `[OK]`, configurabile dalle impostazioni con rigenerazione di tutti i temi (§7.6).
- **Scala di grigi:** proposta 10–12 step con progressione uniforme in luminanza percettiva, non in RGB.
- **Spazio di lavoro:** OKLCH permette di derivare algoritmicamente la palette mantenendo la luminanza costante — è la scelta corretta se la palette va *generata* e non scelta a mano, ed è ciò che rende praticabile il cambio di accento live.
- **Colori semantici: obbligatori** `[OK]`. Non è una scelta stilistica: praticamente ogni strumento a terminale assume una palette ANSI a 16 colori e la usa per errori, warning, diff e tipi di file. Non si può rinunciare, si può solo scegliere *quali* rossi e verdi.
- **Formato del file token: schema in stile base16** (8 toni di grigio più 8 accenti). Motivo pratico decisivo: è il formato di interscambio de facto, e quasi ogni strumento ha già un template base16 — quindi il file sorgente genera i config per l'intero sistema quasi gratis. **Questo rende la palette decidibile ora, prima di aver scelto le applicazioni.**
- Coerenza stilistica: con accento rosa pastello e cifra minimal/terminale/wave anni 80, i colori semantici vanno desaturati verso il pastello, non lasciati agli ANSI di default.
- **Contrasto minimo:** proposta WCAG AA 4.5:1 per testo normale, rilevante per l'uso prolungato in studio.
- **Varianti:** una sola (dark) o dark + light? Il requisito "read mode" (§8.2) spinge verso almeno due varianti, il che raddoppia il lavoro sui template ma è gestibile se i token sono astratti (`bg-0`, `fg-1`, `accent`) e non letterali.
### 7.3 Tipografia `[TBD]` `[?]`
 
**Non serve un font che contenga tutti i glifi.** `fontconfig` gestisce una catena di fallback: se un carattere manca nel font primario, passa al successivo. Quindi il set minimo è di quattro elementi, non di uno:
 
| Ruolo | Nota |
|---|---|
| Monospace primario | Terminale, TUI, editor. Copre latino esteso |
| Sans per interfaccia e testo | Documenti, browser, GUI |
| Font di **soli simboli** in fallback | Le TUI usano glifi tipo Nerd Font. Un font di soli simboli nella catena è più pulito di una copia "patchata" di ogni font: meno peso, aggiornabile separatamente |
| Fallback Noto per gli altri alfabeti | Si installano **solo i sottoinsiemi necessari**. Quello CJK è molto grande: solo se serve davvero |
 
`Q-18`: quali alfabeti oltre al latino servono davvero? Determina quali sottoinsiemi Noto installare.
 
Nota `I-11`: il glyph **φ** deve esistere in entrambi i font scelti, o va trattato come vettore (§7.7).
 
### 7.4 Propagazione del tema `[VUOTO]`
Per ogni componente scelto va mappato il meccanismo di tematizzazione. Le GUI non tematizzabili si respingono per `I-06`.
 
### 7.5 Linee guida di interfaccia `[VUOTO]`
Per le app custom: densità, spaziatura, bordi, convenzioni di keybinding, navigazione. Necessario perché §10 produrrà più app che devono sembrare la stessa app.
 
### 7.6 Motore di tema e aggiornamento live `[TBD]` — **nuovo requisito**
 
Job to be done: `phi theme set <accento>` cambia il tema di tutte le app stilizzate **senza riavviare la sessione**.
 
Il problema tecnico è che le applicazioni si dividono in tre classi, e la soluzione deve gestirle tutte e tre esplicitamente:
 
| Classe | Meccanismo di ricarica | Esempi tipici |
|---|---|---|
| **A — ricarica a caldo** | Segnale, comando di controllo, o file watch | Compositor, barre di stato, demoni di notifica, app custom progettate per farlo |
| **B — riconfigurabile a runtime via protocollo** | Sequenze di controllo o socket di controllo | Terminali che accettano l'aggiornamento colori delle sessioni attive; editor con istanza remota pilotabile |
| **C — richiede riavvio dell'applicazione** | Nessuno | Browser con CSS utente, GUI toolkit-based |
 
Architettura proposta:
 
1. `design/tokens` è la sorgente.
2. Ogni app ha un **adapter** dichiarativo: `{ template, destinazione, comando_di_ricarica, classe }`.
3. `phi theme set` esegue: rigenerazione di tutti i target → ricarica delle classi A e B → elenco esplicito delle app di classe C che richiedono riavvio.
4. Il comando è idempotente e ha un `--dry-run` che mostra i file che cambierebbero.
**Conseguenza di progetto rilevante:** questo è il primo argomento *tecnico* forte a favore dello sviluppo di app proprie. Un'app custom è di classe A per costruzione. Ogni GUI di terze parti tende alla classe C. `Q-19`: quante app di classe C sei disposto a tollerare?
 
### 7.7 Identità visiva phiOS `[TBD]` — **nuovo requisito**
 
Punti in cui l'identità è visibile, dal più profondo al più superficiale:
 
| Livello | Meccanismo | Note tecniche |
|---|---|---|
| Firmware / bootloader | Dipende da §4.5 | Spazio molto limitato; sul Mac mini vincolato dall'EFI Apple |
| Splash di boot | Servizio di splash grafico con tema custom | È l'unico modo pratico per avere un'animazione durante il boot **e** un prompt grafico per la passphrase LUKS. Costo: un componente nell'initramfs e qualche frazione di secondo di boot |
| Logo del kernel in console | Richiede ricompilazione del kernel | Sconsigliato: costo sproporzionato, e confligge con il tier T0 |
| TTY / login | Banner di sistema, prompt di login | Costo zero, resa alta |
| Sessione | Wallpaper, lock screen, barra di stato | Da §8.2 |
| Terminale | Banner all'avvio della shell, prompt | Attenzione: un banner ad ogni shell diventa rumore. Meglio solo su login shell |
| SSH nel server | Banner di accesso | Costo zero |
| `phi` | Intestazione dell'help, spinner, marchio ASCII | §10.2 |
 
`Q-20`: vuoi un'animazione vera durante il boot (richiede il componente di splash), o è sufficiente un logo statico più un boot silenzioso e rapido? Il boot silenzioso è tecnicamente più pulito; l'animazione è il requisito che hai espresso. Sono compatibili ma vanno bilanciati.
 
Da produrre in ogni caso: il marchio φ in formato vettoriale, in versione monocroma e con accento, più una variante ASCII/Unicode per TUI e banner.
 
---
 
## 8. Ambiente desktop (`desktop` + `laptop`)
 
### 8.1 Compositor — `[OK] Hyprland`
Da definire: workspace, regole finestre, gesture, multi-monitor, gestione sessione, comportamento alla chiusura del coperchio, scaling.
 
### 8.2 Componenti di sessione `[TBD]`
 
Hyprland è solo il compositor. Ogni riga è un componente separato. Colonna "Classe tema" riferita a §7.6.
 
| Ruolo | Candidati (non approvati) | Classe tema | Nota decisionale |
|---|---|---|---|
| Barra di stato | `waybar` (JSON+CSS, maturo); `eww` (widget interamente custom); `ags`/`astal` (JS+GTK, scriptabile); `quickshell` (QML) | A | "Barra custom" può significare *configurare* waybar o *costruire* la barra. Vedi §10.1 |
| Launcher | `fuzzel` (nativo Wayland, minimale); `rofi-wayland`; `wofi`; `walker`, `anyrun` (estendibili a plugin) | A/B | Vedi §10.3: il launcher come front-end di `phi` |
| Notifiche | `mako` (minimale, ini); `dunst` (maturo); `swaync` (con centro notifiche) | A | Serve supporto azioni per §15 |
| Lock screen | `hyprlock` (stesso ecosistema); `gtklock`; `waylock` | A | È un componente di **sicurezza**: deve fallire in modo chiuso |
| Idle | `hypridle`; `swayidle` | — | Prerequisito del lock |
| Portal | `xdg-desktop-portal-hyprland` + un portal GTK per il file picker | — | Necessario per screen sharing e videoconferenze universitarie |
| Polkit agent | `hyprpolkitagent`; `lxqt-policykit` | C | Valutare se evitabile lavorando da terminale |
| Clipboard + storico | `wl-clipboard` + `cliphist`; `clipse` (TUI) | A | **Rischio `I-08`:** lo storico cattura password. Serve TTL, esclusione per finestra sensibile, e cifratura o esclusione dai backup |
| Screenshot | `grim` + `slurp`; annotazione con `satty` o `swappy` | A | |
| Temperatura colore ("night mode") | `hyprsunset`; `gammastep`; `wlsunset` | A | |
| Read mode | Nessun componente dedicato: è una variante di tema (§7.2) più eventuale modalità lettura del browser | A | Da chiarire cosa intendi esattamente: `Q-21` |
| Audio | `pipewire` + `wireplumber`; controllo TUI: `pulsemixer`, `wiremix`, `ncpamixer`; CLI: `wpctl` | — | Non era in elenco ma è necessario. `Q-22` |
| Wallpaper | `hyprpaper`; `swaybg`; `swww` | A | |
| Rete | `NetworkManager` + `nmtui`; oppure `iwd` + `systemd-networkd` (più minimale, meno comodo in mobilità) | A | Il laptop cambia rete spesso: peso a favore di NetworkManager |
| Bluetooth | `bluez` + `bluetuith` (TUI) | A | Necessario per audio e periferiche |
| Luminosità | `brightnessctl` | — | Solo laptop |
| Login | `greetd` + `tuigreet` (TUI, molto allineato); `ly`; oppure nessun display manager con autologin su TTY | A | Nessun DM è l'opzione più minimale e riduce un componente |
 
### 8.2.1 La sessione desktop è **una shell**, non un insieme di componenti `[BLOCK]` `[TBD]`
 
Dai requisiti espressi emerge una conclusione che cambia l'impostazione di tutto §8.
 
Barra a tre isole con pannelli che si aprono dalle icone • pannello laterale a schede con notifiche, clipboard e chat • lock screen con controlli musicali, statistiche e sfocatura • impostazioni che ricompilano il tema • overlay Alt+Tab che resta aperto al rilascio parziale • modalità a schermo intero con barra a scomparsa e rivelazione sul bordo.
 
Queste superfici **condividono stato, stile e transizioni**. Costruirle come sei programmi indipendenti con sei toolkit diversi garantisce incoerenza e sei volte il lavoro di tematizzazione. Sono una **shell desktop**, e vanno ospitate da un unico framework.
 
**Questa è la decisione da prendere prima di iniziare a configurare `zotac`**, perché determina linguaggio e toolkit di tutto il livello visivo. Per ADR 018 la shell è un programma separato da `phi`: la scelta non tocca §10.1.
 
Candidati (non approvati): framework di widget su `layer-shell` con toolkit di alto livello. Le due famiglie mature sono quella basata su GTK4 con scripting, e quella basata su QML. Entrambe coprono barre, pannelli, OSD, launcher e lock screen. Un terzo percorso è scrivere direttamente su un toolkit con binding `layer-shell`, che dà più controllo e più lavoro.
 
**Guadagno non ovvio:** se la shell implementa essa stessa il demone di notifiche, lo **storico delle notifiche nel pannello laterale viene gratis**. Con un demone esterno serve un secondo componente e un modo per leggerne lo storico, e la maggior parte non lo espone. Lo stesso vale per il clipboard manager. Due voci di §8.2 si dissolvono nella shell.
 
**Avvertenza di sicurezza sul lock screen:** una lock screen custom che va in crash non deve lasciare la sessione esposta. Il protocollo di blocco sessione di Wayland lo garantisce — il compositore mantiene lo schermo bloccato se il client muore — ma va usato quel protocollo, non una finestra a schermo intero.
 
### 8.2.2 Requisiti della sessione — **specificati** `[TBD]`
 
| # | Requisito | Note e criticità |
|---|---|---|
| S1 | Runner con Super+Spazio: file, software, comando CLI, web, funzioni custom | §10.3, già specificato |
| S2 | Workspace multipli | Nativo nel compositore |
| S3 | Workspace dedicato alle statistiche | Un workspace con TUI di monitoraggio avviate automaticamente. Costo quasi nullo |
| S4 | Barra a tre isole, con pannelli evocati dalle icone e disposizione facilmente riordinabile | La riordinabilità va progettata come **dato di configurazione**, non come codice: stessa logica di ADR 019 |
| S5 | Notifiche laterali, o alternativa meno invasiva con icona animata | Entrambe realizzabili se la shell è il demone di notifiche. Decidibile dopo |
| S6 | Pannello laterale a schede: notifiche, clipboard, **più schede custom aggiungibili nel tempo** | Chat AI **rimandata** (`Q-83` chiusa): §9.7 è ancora interamente aperto. Il requisito che resta è più importante della chat stessa — le schede devono essere **definizioni dichiarative legate a verbi `phi` o a servizi interni**, non componenti scritti a mano. Stessa forma delle modalità del launcher (ADR 019). Vedi ADR 078 |
| S7 | Lock screen con password, sfocatura, transizioni, ed elementi opzionali | Controlli musicali via MPRIS. Vale l'avvertenza di sicurezza sopra |
| S8 | Impostazioni a pannelli, con sezione tema che ricompila | §8.16 e §7.6 |
| S9 | Animazioni con funzione di usabilità | Nativo nel compositore per le finestre; per le superfici della shell dipende dal toolkit |
| S10 | Alt+Tab con overlay che persiste al rilascio del solo Tab | **La voce più costosa dell'elenco.** Vedi sotto |
| S11 | Schermo intero con barra a scomparsa e rivelazione sul bordo | Richiede che la shell osservi lo stato della finestra attiva |
 
**Su S10 — rettifica.** Avevo segnalato questa voce come sproporzionatamente costosa. Riesaminandola, **non lo è, e soprattutto non introduce alcun componente separato.**
 
Il compositore espone associazioni sia sulla pressione sia sul **rilascio** dei tasti, e supporta modalità di input temporanee. Con questi due elementi il comportamento si costruisce così: Alt+Tab entra nella modalità, mostra l'overlay e cicla; il rilascio di Alt esce dalla modalità, conferma e nasconde l'overlay. Se rilasci solo Tab la modalità resta attiva, e l'overlay — essendo una superficie della shell — può accettare il puntatore.
 
Quindi non c'è nessun "ciclatore" da adottare e poi sostituire: **è una superficie della shell più logica di binding**, dentro lo stesso framework che stai costruendo comunque. Il costo reale è la sincronizzazione fra lo stato del ciclo nel compositore e l'evidenziazione nell'overlay, che è lavoro di integrazione, non una scelta di componente. `Q-81` chiusa.
 
### 8.2.3 Cosa non era nell'elenco e serve comunque `[TBD]`
 
| Voce | Perché è necessaria |
|---|---|
| **Modello di tiling e regole per il floating** | "Evitare le finestre fluttuanti" implica tiling, ma dialoghi, selettori file, Steam e i giochi hanno bisogno di fluttuare. Servono regole per finestra, non l'assenza del floating |
| **Schema di keybinding coerente** | Un desktop da tastiera richiede di assegnare i modificatori una volta sola — per convenzione Super al gestore finestre e Alt alle applicazioni — e di usare modalità per le azioni rare. Rimapparlo dopo distrugge la memoria muscolare |
| **XWayland** | Obbligatorio: Steam, i giochi, Unreal. Il purismo Wayland qui romperebbe il gaming |
| **Portal desktop** | Condivisione schermo per le videolezioni e selettore file per le GUI |
| **Configurazione monitor come stato runtime** | Il parco monitor cambierà e sarà multiplo: la configurazione **non va in un file statico** ma gestita dal pannello impostazioni e applicata via IPC del compositore. Conseguenza di progetto: la barra va pensata **per N monitor dal primo giorno**, perché aggiungere il supporto multi-monitor dopo è una ristrutturazione |
| **Inibizione del sospendimento** | L'equivalente di Amphetamine: per durata o per processo. È il protocollo di idle inhibit più un verbo `phi` |
| **Tema del cursore** | Il cursore descritto — sottile, nero bordato di bianco — è un tema XCursor: o se ne trova uno conforme o va prodotto |
| **Temperatura colore** | "Night shift" realizzabile ovunque. **"True Tone" resta in programma** ma richiede un sensore di luce ambientale: nativo su alcuni portatili, sul fisso serve un sensore USB esposto al sottosistema IIO, oppure il ripiego di usare una webcam misurando la luminosità media dei fotogrammi. Attivazione per rilevamento di capacità (§5.2.4) |
| **Gestione sessione** | Cosa accade al logout, se le applicazioni si ripristinano |
 
### 8.2.4 Strumenti aggiuntivi richiesti `[TBD]`
 
| Strumento | Fattibilità |
|---|---|
| Screenshot: schermo, finestra, ritardato, sfondo decorativo | Diretta. Composizione di cattura più editor |
| Cattura testo (OCR) | Fattibile con un motore OCR locale |
| Lettura QR | Fattibile, libreria standard |
| ~~Cattura a scorrimento~~ | **Esclusa deliberatamente (ADR 075). Non va rivalutata.** Su Wayland non esiste modo di far scorrere programmaticamente un'altra applicazione: è isolamento del protocollo, non una lacuna implementativa. Resterebbe solo lo scorrimento manuale con ricucitura, complesso e di scarsa utilità |
| Timer nella barra | Banale una volta esistente la shell |
| Color picker | Cattura più lettura del pixel |
| Localizzatore del mouse con effetto riflettore | Realizzabile come shader del compositore |
| Lente d'ingrandimento | Il compositore ha uno zoom nativo; l'effetto lente è uno shader |
 
Le prime otto voci sono **superfici o verbi della shell**, non applicazioni separate: rientrano nello stesso framework di §8.2.1 e nello stesso namespace `phi`.
 
### 8.3 Terminal emulator `[TBD]`
 
| Candidato | Punti di forza | Limiti |
|---|---|---|
| `foot` | Nativo Wayland, estremamente leggero, config ini semplice da generare, supporto immagini via sixel | Nessuna tab o split integrati (delegati al multiplexer) |
| `kitty` | Protocollo grafico proprio (anteprime immagini eccellenti in `yazi`), tab e split integrati, ricarica config a caldo | Più pesante, molte funzionalità potenzialmente non necessarie |
| `alacritty` | GPU, config TOML, molto stabile | Nessuna immagine, nessuna tab |
| `ghostty` | Moderno, veloce, buone impostazioni di default | Ecosistema più giovane |
 
Criterio dirimente: **quanto conta l'anteprima immagini in `yazi` e nella galleria (§8.12)**. Se conta molto, il protocollo grafico di kitty è superiore al sixel. `Q-23`. Sul laptop pesa anche il consumo.
 
### 8.4 Shell — `[OK] zsh`
- Prompt `[TBD]`: `starship` (binario unico, TOML generabile dai token, cross-shell); prompt scritto a mano in zsh puro (zero dipendenze, massima coerenza); framework AIO **esclusi** da `I-01`.
- Plugin: caricamento manuale dei singoli plugin (autosuggestions, syntax highlighting, completions, integrazione fzf), senza framework.
- `Q-24`: history condivisa fra macchine? Contiene dati sensibili (`I-08`) — se sì, va cifrata e trattata come dato di classe riservata.
### 8.5 Multiplexer `[TBD]` `[?]`
Non richiesto esplicitamente ma implicito nell'uso intensivo di TUI e SSH (una sessione TUI sul server che sopravvive alla disconnessione). Candidati: `tmux` (ubiquo, configurabile, tematizzabile da template), `zellij` (default migliori, più scopribile, Rust). `Q-25`: serve? Interagisce con §8.3.
 
### 8.6 Browser `[TBD]` — candidato indicato: Zen
 
Da verificare prima dell'approvazione, con criterio esplicito `I-08`: **il ritardo con cui una fork applica le patch di sicurezza upstream di Firefox**. Su una macchina che gestisce dati sensibili questo è il criterio dominante, sopra l'estetica.
 
| Candidato | Provenienza | Tematizzabilità | Nota |
|---|---|---|---|
| Firefox | T0 | userChrome.css: molto alta, e generabile dai token | Patch di sicurezza immediate. È la scelta conservativa |
| Zen | AUR / build upstream | Alta, più curata di default | Fork: valutare la latenza di rebase sulle release di sicurezza |
| LibreWolf | AUR / repo upstream | Alta | Fork orientata alla privacy, latenza di rebase generalmente contenuta |
| Chromium / ungoogled | T0 / AUR | Bassa | Attrito con `I-05` |
 
Tutte le opzioni Firefox-based sono di **classe C** per il tema (§7.6): il cambio di accento richiederà un riavvio del browser. `Q-26`.
 
### 8.7 Mail `[TBD]`
 
Architettura da decidere prima del client: sincronizzazione locale (abilita ricerca offline e backup del contenuto — coerente con §13) oppure client che parla direttamente con IMAP.
 
Stack candidato in caso di sincronizzazione locale: `isync`/`mbsync` per il fetch, `msmtp` per l'invio, `notmuch` o `mu` per l'indicizzazione, e un client TUI fra `aerc` (moderno, tematizzabile, buona integrazione con notmuch), `neomutt` (massima configurabilità, curva ripida), `himalaya`, `meli`.
 
**Punto di attrito noto:** l'autenticazione OAuth2 richiesta da Gmail e Outlook non è supportata nativamente da tutti questi strumenti e richiede un helper dedicato. Da verificare prima di impegnarsi. `Q-27`: quali account e provider?
 
### 8.8 Calendario, eventi e reminder `[TBD]`
 
Vincolo: la sorgente deve essere condivisa con §9.9 e con il mobile. CalDAV è l'unico protocollo che i client nativi iOS e Android parlano senza app custom — sceglierlo elimina lavoro in §12.
 
Stack candidato: server `Radicale` (Python, molto leggero — adatto al Mac mini) o `Baikal`; sincronizzazione client con `vdirsyncer`; TUI `khal` per gli eventi e `todoman` per i reminder (che in CalDAV sono entità distinte, VTODO); `khard` per i contatti se servono. Su Android, sincronizzazione CalDAV con un client dedicato disponibile su F-Droid.
 
### 8.9 File manager — `[OK] yazi`
Da configurare: anteprime (dipende da §8.3), integrazione `fzf`/`zoxide`/`fd`, apertura per tipo MIME, integrazione con il pinning offline (§10.5).
 
### 8.10 Media player — `[OK] VLC` `[?]`
Nota `I-05`/`I-06`: VLC è una GUI Qt poco tematizzabile, quindi classe C. L'alternativa naturale è `mpv`: minimale, config testuale generabile dai token, OSD personalizzabile, scriptabile in Lua, e usabile come backend da altre app. `Q-28`: confermi VLC, o valutiamo mpv come player primario mantenendo VLC solo come fallback per formati esotici?
 
### 8.11 Traduttore e dizionario offline `[TBD]` `[?]`
 
Due esigenze diverse che richiedono soluzioni diverse:
 
| Esigenza | Approccio | Candidati |
|---|---|---|
| Parola singola durante lo studio | Dizionari statici offline | `sdcv` (CLI, formato StarDict), `GoldenDict` (GUI Qt, classe C), dizionari da dump Wiktionary |
| Paragrafo di paper | Traduzione automatica neurale locale | `argos-translate` (modelli offline, Python); traduzione integrata nel browser (offline, già disponibile in Firefox); `LibreTranslate` self-hosted sul server |
 
Nota hardware: un modello di traduzione sul Mac mini Intel è CPU-bound e lento; su laptop e desktop è più sensato eseguirlo localmente. `Q-29`: quali lingue e quale dei due casi d'uso prevale?
 
### 8.12 Galleria fotografica `[TBD]`
Candidati visualizzatori Wayland: `imv`, `swayimg` (entrambi minimali, tematizzabili, classe A/B). Rendering in terminale per un flusso interamente TUI: `chafa`, `timg`, o il protocollo grafico del terminale scelto in §8.3. La gestione (tag, ricerca, deduplica) è un problema distinto e appartiene a §9.4.
 
### 8.13 Note `[TBD]` — sviluppo proprio previsto
Decisioni preliminari indipendenti dall'app: formato dei file (**vincolo: testo semplice**, per essere versionabile, sincronizzabile e ricercabile con `fd`/ripgrep), schema dei link, gestione degli allegati, e se la sincronizzazione passa da §9.3 o da un servizio dedicato. Vedi §10.6.
 
### 8.14 Scrittura accademica e alternativa office `[TBD]` `[?]`
 
`Q-30`: quali formati devi **produrre** e quali **consumare**?
 
| Scenario | Stack candidato |
|---|---|
| Devi consegnare `.docx` con fedeltà di impaginazione | `LibreOffice` (FOSS, pesante, classe C) — poco evitabile |
| Devi produrre solo PDF | `Typst` (moderno, veloce, sintassi accessibile) o LaTeX (`texlive`), entrambi con sorgente in testo semplice e quindi coerenti con tutto il resto |
| Conversione fra formati | `pandoc` |
| Lettura e annotazione di paper | `zathura` (minimale, tematizzabile, vim-like) o `sioyek` (pensato per la lettura di ricerca) |
| Gestione bibliografica e citazioni APA | Necessaria per psicologia. `Zotero` (GUI pesante ma standard di fatto, classe C) oppure `papis` (CLI, allineato a `I-06`, ecosistema più piccolo) |
| Statistica | `Q-31`: il corso richiederà analisi statistica? In tal caso serve decidere fra R, Python con stack scientifico, o strumenti didattici come JASP/jamovi — che sono GUI ma spesso richiesti dai corsi |
 
### 8.15 Meteo `[TBD]`
Sorgenti candidate senza registrazione né chiave API: `wttr.in` (interrogabile con un semplice comando), Open-Meteo (API JSON su dati aperti). Visualizzazione come modulo della barra di stato più `phi weather`.
 
### 8.16 Pannello impostazioni `[TBD]` — job ora definito
 
Il nuovo requisito di tema live gli dà una ragione d'essere concreta. Perimetro proposto, limitato allo **stato realmente runtime**:
 
- Tema: accento, variante chiara/scura, anteprima, applicazione live (§7.6)
- Audio: dispositivo di uscita e ingresso, volume
- Rete: Wi-Fi
- Bluetooth: dispositivi accoppiati
- Display: monitor, risoluzione, scaling
- Energia: profilo, comportamento del coperchio
Tutto il resto resta nel repo versionato: un pannello che scrive stato persistente fuori dal repo crea un secondo punto di verità che diverge. `Q-32`: confermi questo perimetro?
 
### 8.17 Gestione pacchetti `[VUOTO]`
`pacman` è dato. Da definire: helper AUR (§2.3), policy di aggiornamento manuale con snapshot preventivo (§4.2), hook pacman per rigenerare le config del design system dopo un aggiornamento, gestione degli orfani, `phi update` come wrapper unico dell'intero flusso.
 
---
 
## 9. Servizi server
 
**Precondizione trasversale `[BLOCK]` `[TBD]` `[?]`:** ogni servizio gira come unit systemd nativa o in container? Scelta da fare **una volta**. Candidati: unit native (massima leggerezza, ma dipendenze invasive nel sistema), `podman` rootless con unit systemd generate (isolamento buono, gestione uniforme, senza demone privilegiato), Docker (scartabile: demone privilegiato, attrito con `I-08`). Su un Mac mini Intel con RAM limitata l'overhead dei container è modesto ma non nullo. `Q-33`.
 
### 9.1 Git remote `[TBD]`
 
`Q-34`: ti serve solo un remote, o servono issue, pull request e CI?
 
| Candidato | Peso | Cosa offre |
|---|---|---|
| Bare repo su SSH | Nullo | Solo push/pull. Nessun servizio da mantenere, nessuna superficie d'attacco |
| `Soft Serve` | Molto basso (binario singolo) | Server git su SSH con interfaccia **TUI** — molto allineato a `I-06` |
| `cgit` | Basso | Sola consultazione web |
| `Forgejo` | Medio (binario singolo Go) | Forge completa: issue, PR, CI, web |
 
Su un Mac mini Intel, Forgejo è sostenibile; il salto di complessità va però giustificato da `I-04`.
 
### 9.2 Layout dati e budget di capacità `[TBD]` — **aggiornato con i dischi reali**
 
Proposta di allocazione, da confermare:
 
| Volume | Contenuto | Razionale |
|---|---|---|
| **Interno 512 GB** | Sistema, stato dei servizi e database, repository git, note, documenti, vault | Dati piccoli, ad alta frequenza di scrittura e **irrecuperabili**. Sul disco più affidabile e non rimovibile |
| **Esterno 1 TB** | Libreria media primaria: video, musica, foto | Dati voluminosi, in gran parte ricostruibili. Su USB il throughput basta per lo streaming |
| **Esterno 512 GB** | Destinazione di backup locale: replica snapshot dell'interno + copia della classe irrecuperabile dalla libreria media (foto in primis) | Separazione fisica dal dato primario |
 
**Nota critica:** un backup su disco collegato alla stessa macchina non protegge da furto, incendio, sovratensione o ransomware che monta i volumi. È il secondo livello, non l'ultimo. La copia offsite resta necessaria (§13.4).
 
Classificazione dei dati media, come richiesto ("solo in misura ragionevole"):
 
| Dato | Classe | Backup offsite |
|---|---|---|
| Foto personali | Irrecuperabile | **Sempre** |
| Note, documenti, tesi | Irrecuperabile | **Sempre** |
| Repository git | Irrecuperabile se non hanno altro remote | Sì (sono piccoli) |
| Database dei servizi | Irrecuperabile | Sì |
| Musica acquistata o rippata da supporto proprio | Irrecuperabile | Sì |
| Musica scaricabile di nuovo | Ricostruibile | No, o solo la lista |
| Film e serie | Ricostruibile | No — solo la watchlist e i metadati |
| Giochi, cache, DDC Unreal | Effimero | No |
 
Questa classificazione fa sì che il volume offsite reale sia nell'ordine di decine di GB, non di terabyte: economicamente e operativamente sostenibile.
 
#### 9.2.0 Dischi esterni: rinviati `[OK]`
 
Principio adottato: **la configurazione dei servizi non assume nulla sui dischi.** Percorsi logici sotto `/srv/media/*` (ADR 033), assegnazione fisica decisa in seguito e modificabile con una riga di fstab. I servizi si configurano e si collaudano subito, gli archivi si popolano dopo.
 
Sequenza dei dischi esterni, senza transito dal desktop:
 
1. L'esterno 1 TB si svuota sul NVMe 1 TB di `zotac`.
2. I ~300 GB di video VR passano direttamente dall'esterno 512 all'esterno 1 TB.
3. Assegnazione definitiva decisa quando serve.
**L'esterno 512 va riformattato?** Solo se il filesystem attuale non è POSIX. Criterio unico:
 
| Filesystem attuale | Riformattare? |
|---|---|
| ext4, Btrfs, XFS | **No.** Si monta e si usa. Il guadagno di Btrfs qui è checksum e snapshot, ma la libreria video è ricostruibile: non li richiede |
| exFAT, NTFS | **Sì, obbligatorio.** Nessuna proprietà POSIX: tutti i file appartengono all'utente che monta, con permessi fissi. Incompatibile con gli account di servizio di §5.2.1 |
 
`Q-77`: output di `lsblk -f` sul server per chiudere il punto.
 
#### 9.2.0.1 Modello dei dischi — **rivisto (ADR 057)**
 
| Disco | Natura | Ruolo |
|---|---|---|
| Interno 512 GB | Fisso | Sistema, servizi, e archivio per la parte che ci sta |
| Esterno 512 GB | Fisso | Archivio file |
| Esterno 1 TB | **Portatile** | Trasferimento file fra macchine **più** partizione di backup per tutte le macchine, in stile disco Time Machine |
 
Il disco portatile assolve anche il livello 3 di §13.4, purché non viva stabilmente accanto al server.
 
#### 9.2.0.2 Due alberi distinti sul server `[OK]`
 
Chiarimento che semplifica il layout: **il "cloud" non contiene i media.**
 
| Albero | Contenuto | Chi lo gestisce |
|---|---|---|
| `/srv/cloud/` | Documenti, vault delle note, e ciò che aggiungerai. Controparte server di `~/cloud` | Servizio di sincronizzazione |
| `/srv/media/{music,video,video-vr,photos}/` | Librerie | I rispettivi servizi |
| `/srv/git/` | Repository bare | SSH e `phi repo` |
 
Conseguenza: la sincronizzazione file opera **solo** su `/srv/cloud`. Le librerie non sono sincronizzate, sono **servite**, e raggiungono i client via streaming o pinning (§10.5). Due meccanismi distinti per due problemi distinti: tenerli separati evita che una libreria video finisca dentro un sync bidirezionale.
 
#### 9.2.1 `/srv` è un namespace, non un disco `[TBD]`
 
Il malinteso da sciogliere: FHS definisce il **significato** del percorso, non dove risiedono i byte. La collocazione fisica si esprime con i punti di mount, quindi si possono avere librerie su dischi diversi sotto lo stesso albero logico.
 
Poiché entrambi i dischi sono Btrfs, la forma pulita è **un subvolume per libreria, montato al proprio percorso logico**:
 
| Percorso logico | Disco fisico | Contenuto |
|---|---|---|
| `/srv/media/music` | Interno | Libreria musicale: piccola, e nella classe irrecuperabile |
| `/srv/media/video` | Esterno 512 | Film e serie: voluminosi, ricostruibili |
| `/srv/media/video-vr` | Esterno 512, poi 1 TB quando serve | ~300 GB. Libreria separata (§9.6.1) |
| `/srv/media/photos` | **Interno 512** | ~72 GB. Irrecuperabili, quindi sul disco più affidabile e sempre presente |
| `/srv/git` | Interno | Repository |
| `/var/lib/navidrome`, `/var/lib/<servizio>` | Interno | Stato e database dei servizi |
 
**Il vantaggio decisivo di questa forma:** i percorsi logici non cambiano mai. Se un domani la libreria musicale non entra più sull'interno, si crea un subvolume sull'esterno, si spostano i dati e si aggiunge una riga a fstab. `/srv/media/music` resta identico, quindi **nessuna configurazione di servizio, nessuna playlist e nessuno script va toccato.** È esattamente ciò che rende reversibile una scelta di allocazione altrimenti definitiva.
 
Nell'esempio Navidrome: i file stanno in `/srv/media/music`, il database in `/var/lib/navidrome`. Il servizio conosce solo i due percorsi e ignora completamente su quale disco si trovino.
 
**Regole operative obbligatorie:**
 
1. **Mount per UUID, mai per percorso di device.** `/dev/sdb1` cambia fra un riavvio e l'altro se scolleghi qualcosa.
2. **Punto di mount protetto quando il disco è assente.** Se l'esterno non è montato, `/srv/media/video` è una directory vuota sul disco di root: un servizio la vede vuota e può marcare l'intera libreria come cancellata, oppure un download può riempire silenziosamente il disco di sistema. Contromisure: `RequiresMountsFor=` nelle unit (§4.4.4) e directory sottostante resa non scrivibile quando vuota.
3. **Chiave di passphrase sul disco esterno, oltre al keyfile.** Il requisito di portabilità lo impone: LUKS supporta più slot, quindi il keyfile serve allo sblocco a cascata automatico e la passphrase permette di aprire il disco su un'altra macchina. Costa nulla e senza di essa il disco è illeggibile fuori da `mini`.
4. **Etichetta di filesystem parlante**, per riconoscere il disco quando lo colleghi altrove.
#### 9.2.2 Budget di memoria `[TBD]`
 
Stima indicativa dell'insieme sempre attivo, da validare misurando:
 
| Servizio | Residente stimato |
|---|---|
| Sistema base, senza sessione grafica | 200–300 MB |
| Streaming musicale | 150–300 MB, cresce con l'indice |
| Sincronizzazione file | 100–500 MB, cresce con il **numero** di file più che con il volume |
| Server git leggero su SSH | ~50 MB a riposo. Un forge completo: 200–500 MB |
| Media server | 300–600 MB a riposo |
| Bridge dell'assistente AI | 50–100 MB se si limita a inoltrare chiamate |
 
L'insieme sempre attivo si colloca intorno a 1,0–1,8 GB, lasciando circa 2 GB per page cache e picchi. **Ci sta, con tre avvertenze.**
 
1. **Le scansioni di libreria sono il picco**, non il funzionamento normale. Scansioni del media server, dello streaming musicale e hashing del sincronizzatore non devono mai sovrapporsi. Vanno pianificate, non lasciate in modalità automatica aggressiva.
2. **Lo swap diventa portante.** `zram` è particolarmente adatto qui: swap compressa in RAM, evita di scrivere sull'SSD ed è efficace proprio sulle macchine a memoria scarsa. È già presente sull'installazione attuale.
3. **La page cache non è spazio sprecato.** Servire file beneficia enormemente della cache: riempire la RAM di servizi la sottrae al lavoro che conta.
#### 9.2.3 Il media server è necessario? `[?]`
 
Osservazione dall'uso dichiarato: catalogo con watchlist, visti e valutazioni; streaming o download verso il client; richiesta di acquisizione e catalogazione. **Quasi nulla di questo richiede un media server.** Serve un database con stato, un'API, e la capacità di servire un file via HTTP — che è §10.7 più un file server.
 
| Cosa aggiunge un media server completo | Serve? |
|---|---|
| Transcodifica | **No**, esclusa per vincolo hardware |
| Interfaccia web | No, il client è custom |
| Gestione utenti multipli | No, utente singolo |
| Scraping metadati già pronto | Sì, risparmia lavoro |
| **App mobile con download offline già esistenti** | **Forse decisivo**: è il requisito che da soli costerebbe di più |
| Eventuale integrazione col player VR | Da verificare (`Q-70`) |
| Costo | 300–600 MB su 4 GB, e un database che duplica il catalogo `phi` |
 
`Q-33b`: la decisione dipende quasi interamente dal piano mobile. Se sul telefono userai un client esistente per i film, il media server si giustifica da solo; se il client sarà custom o non guarderai film da telefono, è 600 MB per funzioni che non usi.
 
### 9.3 Sincronizzazione file `[BLOCK]` `[TBD]` `[?]`
 
Decisione strutturante, resa più stringente dal laptop da 512 GB.
 
| Modello | Candidati | Comportamento | Adatto se |
|---|---|---|---|
| **P2P, ogni dispositivo ha una copia** | `Syncthing` | Nessuna autorità centrale; selezione per cartella; niente sync parziale nativo dentro una cartella | Cartelle di lavoro, note, documenti, upload foto dal telefono |
| **Client-server, il server è autoritativo** | `Nextcloud` (pesante, PHP; ma ha selective sync, web e app mobile), `Seafile` (efficiente, block-level) | Il client sceglie cosa tenere in locale | Librerie grandi con laptop piccolo |
| **Pull esplicito** | `rclone`, `rsync` su SSH | Nessun sync automatico; controllo totale | Media, dove il "sync continuo" non serve |
 
Raccomandazione strutturale: **non usare un solo meccanismo per tutto.** Documenti e note hanno bisogno di sync bidirezionale continuo; le librerie media hanno bisogno di *pinning* esplicito (§10.5), che è un problema diverso e si risolve meglio con un pull controllato. Forzare i media dentro un sync bidirezionale su un laptop da 512 GB è la ricetta per riempirlo.
 
`Q-35`: confermi la separazione fra "sync continuo per i documenti" e "pinning esplicito per i media"?
 
### 9.4 Foto `[TBD]` `[?]`
 
| Candidato | Peso su Mac mini Intel | Cosa offre |
|---|---|---|
| Directory strutturata + `exiftool` + sync + visualizzatore locale | Nullo | Archiviazione, backup, nessuna ricerca semantica |
| `PhotoPrism` | Medio-alto | Indicizzazione, ricerca, riconoscimento; scritto in Go |
| `Immich` | **Alto** | Molto completo, app mobile eccellente con upload automatico; richiede Postgres più servizi ML |
 
Avvertenza: su un Mac mini Intel di generazione datata, l'indicizzazione ML di Immich è realisticamente fuori portata o richiederà giorni di elaborazione iniziale e degraderà gli altri servizi. `Q-36`: ti serve davvero ricerca e riconoscimento, o basta archiviazione affidabile con upload automatico dal telefono più visualizzazione?
 
### 9.5 Musica — `[OK] Navidrome`
 
Da definire: layout della libreria su disco, convenzione di naming, formato e qualità target, gestione copertine.
 
**Podcast `[TBD]`:** Navidrome non è progettato per il modello dati dei podcast (feed, episodi, stato di ascolto, retention). Opzioni: servizio dedicato separato, oppure un'app Android dedicata con sincronizzazione dello stato verso il server. `Q-37`: i podcast entrano nell'ecosistema come servizio a sé o restano fuori?
 
**Modello client — deciso (ADR 007).** Il server è **l'unica sorgente di verità** della libreria. I client sono client di streaming con capacità di download locale. Nessun client aggiunge musica alla libreria in condizioni normali: se hai tracce su un client, le sposti sul server via SSH e la libreria si aggiorna lì.
 
Restano tre sotto-decisioni:
 
**(a) Cosa significa "scaricare localmente" `[TBD]`.** Due forme:
 
| Forma | Descrizione | Conseguenze |
|---|---|---|
| Cache opaca del client | File nominati per identificatore, gestiti solo dal client | Nessun altro programma può leggerli; si perde tutto alla reinstallazione del client; ma nessuna ambiguità su cosa è locale |
| Mirror di file reali | Sottoinsieme della libreria replicato con la stessa struttura di cartelle | Leggibile da qualsiasi player, sopravvive al client, riusa il pinning di §10.5 — che serve comunque per i video |
 
Raccomandazione: mirror di file reali. Il costo aggiuntivo è nullo e il beneficio è che il meccanismo è uno solo per musica e video (`Q-68`).
 
**(b) Riconciliazione dopo un'ingestione offline `[TBD]`.** Il client offline ha i byte; il server no. Quando il server torna raggiungibile:
 
| Strategia | Pro | Contro |
|---|---|---|
| Il client rimanda solo l'URL, il server riscarica | Nessun endpoint di upload da scrivere | Doppio download; l'URL può nel frattempo essere morto; i byte possono differire |
| Il client carica il file già scaricato | Byte identici garantiti, nessun secondo download, funziona anche se la fonte sparisce | Serve un endpoint di upload e la deduplica per hash |
 
Raccomandazione: caricare il file. Vedi però il punto (c), che rende questa scelta quasi gratuita.
 
**(c) Separazione fra *fetch* e *catalogazione* — semplificazione architetturale.** La pipeline di §10.6 va spezzata in due fasi indipendenti:
 
- **fetch**: dato un URL, ottenere i byte. Richiede un solo strumento di download.
- **catalogazione**: riconoscere la traccia, arricchire i metadati, normalizzare, collocare nella struttura di cartelle, aggiornare l'indice. Richiede l'accesso alle fonti di metadati, quindi **richiede la rete comunque**.
Conseguenza: **la catalogazione avviene sempre e solo sul server.** Il client offline esegue solo il fetch e mette il file in una coda locale. Questo elimina quasi del tutto la duplicazione di logica fra client e server che sembrava necessaria: il client non ha bisogno dell'intero stack di tagging, solo del downloader.
 
Corollario di design: l'input della pipeline non è un URL, è una **sorgente**, che può essere un URL o un file locale. Con una sola implementazione copri tre casi: `phi music add <url>` sul server, `phi music add <file>` per le tracce che sposti a mano via SSH, e la riconciliazione della coda offline.
 
### 9.6 Film e serie `[TBD]`
 
Componenti concettualmente distinti: (a) server e libreria, (b) metadati, (c) watchlist condivisa, (d) acquisizione.
 
Per (a): `Jellyfin` è il candidato allineato (FOSS integrale, nessun livello a pagamento, client Android con **download offline** disponibili anche in versioni FOSS su F-Droid). Alternative come Plex ed Emby hanno componenti proprietarie e livelli a pagamento, in conflitto con `I-03`.
 
**Vincolo hardware determinante:** la transcodifica su Mac mini Intel è limitata (§3.1). Conseguenza architetturale: **la libreria va conservata in formati direct-play** per i dispositivi target, evitando la transcodifica. Questo va deciso ora perché determina il formato in cui i file vengono archiviati, non solo come vengono letti.
 
Per (c) e (d): vedi §10.4. Per l'acquisizione, va ribadito che deve limitarsi a fonti legittime — contenuti di pubblico dominio, acquistati, con licenza libera, o propri; l'architettura è agnostica rispetto alla fonte, la conformità resta a tuo carico.
 
#### 9.6.1 Libreria video VR `[TBD]` — **requisito, indipendente dal gaming VR**
 
Requisito distinto e più prioritario di §11.4: i video VR devono essere **archiviati e gestiti sul server** e riproducibili da un player VR, indipendentemente dal fatto che il gaming VR su Linux funzioni o meno. Vale anche se il visore viene usato da Windows.
 
**Il video VR non è video normale.** Porta due attributi che i media server standard non modellano: il tipo di proiezione (equirettangolare 180 o 360, fisheye) e la disposizione stereoscopica (affiancata o sovrapposta). Senza questi attributi il player non sa come deformare l'immagine.
 
Lo standard di fatto per trasmetterli è **la convenzione di nome file**: i player VR diffusi leggono suffissi nel nome per dedurre proiezione e layout. Conseguenza di progetto: **la convenzione di naming è lo schema di metadati**, e va decisa insieme al layout della libreria (§9.2) e imposta dalla pipeline di ingestione, non lasciata all'improvvisazione. `Q-69`: convenzione da adottare.
 
**Il percorso dei dati, e la differenza strutturale rispetto ai film.** Il player VR gira **sul visore**, non sul PC: sono applicazioni Android installate sull'XR Elite che leggono i file da una posizione di rete. Il percorso è quindi `mini` → Wi-Fi → visore, e **il desktop non è coinvolto**. Guardare video VR non richiede che `zotac` sia acceso né che il VR gaming funzioni.
 
Banda: un file VR ad alto bitrate richiede nell'ordine di 100–150 Mbps. L'SSD esterno su USB 3.0 ne offre molte volte tanto, quindi il collo di bottiglia è il Wi-Fi verso il visore, dove il 5 GHz lascia margine. Il vincolo pratico è che avviene in LAN: fuori casa servirebbe il visore sulla rete overlay, complessità che non vale il beneficio.
 
**Il protocollo dipende dal player `[TBD]` `[?]`:**
 
| Via | Cosa richiede sul server | Note |
|---|---|---|
| Condivisione di rete SMB | Un servizio di condivisione file | La più semplice e la più supportata dai player VR; nessun transcoding, nessun database |
| DLNA / UPnP | Un server DLNA | Ampiamente supportato ma con metadati poveri |
| Integrazione con il media server (§9.6) | Nessun componente aggiuntivo | Il supporto varia per player e versione: **da verificare prima di impegnarsi**, non da assumere |
 
`Q-70`: il player gira sul visore in modalità standalone, o sul desktop? Cambia il percorso dei dati: nel primo caso il file va server → visore via Wi-Fi; nel secondo server → desktop → visore, con due tratte di rete.
 
**Vincoli tecnici non negoziabili:**
 
- **Nessun transcoding, mai.** Un file VR ad alta risoluzione in H.265 non è transcodificabile dal Mac mini. I file vanno archiviati nel formato che il visore decodifica nativamente. Il tuo visore non decodifica AV1: il target è H.265.
- **Banda.** Un file VR ad alta risoluzione può richiedere nell'ordine di 100–150 Mbps, cioè circa 12–19 MB/s sostenuti. Se l'SSD esterno è su USB 2.0 (§3.1) il tetto reale è intorno ai 35 MB/s: un singolo flusso passa, ma con poco margine e con stuttering garantito se contemporaneamente gira un job di backup. È un'altra ragione per cui `Q-02` va chiusa presto, ed eventualmente per pianificare i backup in finestre in cui non guardi video.
- **Libreria separata.** I video VR vanno tenuti in una radice distinta dalla libreria film: i metadati sono diversi, gli scraper standard si confondono, e il player VR vuole una sua directory dedicata.
#### 9.6.2 Requisiti di riproduzione — **specificati** `[TBD]`
 
| # | Caso | Percorso |
|---|---|---|
| R1 | In LAN, film già in libreria | Client → media server, direct play HTTP |
| R2 | In LAN, film non in libreria | Client → `phi` → risoluzione fonte → fetch sequenziale → riproduzione appena il buffer lo consente |
| R3 | Da internet, film in libreria | Client → server via rete overlay. **Limitato dall'upload domestico** |
| R4 | Da internet, film non in libreria | Risoluzione sul server; se la fonte è HTTP, **reindirizzare il client alla fonte** anziché fare da proxy |
| R5 | Sottotitoli in qualunque lingua, in tutti i casi | Job `phi` all'acquisizione |
 
**Precisazioni (2026-08-30):**
- Il catalogo di scoperta serve **anche** ai file già in libreria, per associare i metadati automaticamente.
- Il modulo di risoluzione e fetch deve supportare fonti peer-to-peer, appoggiandosi a un motore esistente open source anziché riscriverlo.
- **Il modulo vive sia sul server sia sul laptop** (ADR 065): il laptop deve poter risolvere e riprodurre da fonte anche a server irraggiungibile. Stesso schema della pipeline musicale: una libreria, due consumatori.
- La libreria deve accettare **media personali con metadati inseriti a mano**, non reperibili in nessun catalogo. Criterio di selezione del media server.
- Lo streaming remoto va **contemplato in architettura** anche se non realizzabile subito, perché riguarda proprio i media personali che non hanno una fonte alternativa.
**Conseguenza architetturale di R2: "streaming da fonte" e "download" non sono due funzioni.** Sono una pipeline sola in cui la riproduzione comincia prima che il fetch finisca. Elimina un'intera classe di duplicazione.
 
##### Tre vincoli da risolvere prima di progettare il modulo
 
**V1 — Servono due cataloghi.** Quello della libreria indicizza ciò che è su disco; per cercare un film che non possiedi serve un **catalogo di scoperta** alimentato da una fonte di metadati esterna. È un componente non previsto finora.
 
**V2 — La difficoltà del fetch dipende dal protocollo della fonte.** Con URL HTTP diretti il server apre lo stream, lo scrive su disco e lo serve contemporaneamente: poche decine di righe. Con fonti peer-to-peer serve un motore che scarichi i pezzi in ordine sequenziale ed esponga il file parziale via HTTP bloccando sulle porzioni mancanti: dipendenza pesante. `Q-78`: quale protocollo produrrà il modulo di risoluzione?
 
**V3 — R3 è limitato dall'upload domestico e il server non può transcodificare.** È esattamente il caso in cui la transcodifica esisterebbe. Tre vie: tenere in libreria versioni a bitrate contenuto; pre-transcodificare su `zotac` con NVENC una versione secondaria, al costo di spazio doppio; oppure accettare 1080p o meno da remoto. `Q-79`: banda in upload della connessione domestica?
 
##### Sottotitoli
 
File affiancati al video con convenzione di lingua nel nome (`Film.it.srt`), che è ciò che sia i media server sia `mpv` si aspettano. Sono minuscoli, quindi arrivano subito anche a video incompleto.
 
Dettaglio non ovvio: l'accoppiamento affidabile si fa per hash calcolato su dimensione totale più primi e ultimi 64 KB. In un download sequenziale gli ultimi 64 KB arrivano per ultimi, quindi durante lo streaming progressivo l'accoppiamento è possibile solo per titolo e nome del rilascio, meno affidabile. Rimedio: chiedere al fetcher di prelevare l'ultimo pezzo per primo.
 
#### 9.6.2.1 Criteri di selezione del media server `[OK]`
 
Non si sceglie ora, ma i criteri sì, perché servono a **non scegliere qualcosa che chiuda porte**:
 
| Criterio | Perché |
|---|---|
| **Capace di transcodificare**, anche se disabilitata | Il Mac mini non può, ma una macchina futura sì. Scegliere qualcosa che non sappia farlo renderebbe irreversibile un limite hardware temporaneo |
| Accetta **metadati inseriti a mano** | I media personali non esistono in nessun catalogo esterno |
| Espone **API e client esistenti** per TV e mobile | È l'unico motivo per cui non si costruisce il catalogo in `phi` |
| Tollera librerie su percorsi arbitrari | Coerenza con ADR 033 |
| Nessun livello a pagamento | `I-03` |
 
#### 9.6.3 Player VR standalone — candidati `[TBD]` `[?]`
 
Il visore è Snapdragon XR2 con 12 GB di RAM e decodifica hardware H.264 e HEVC: la riproduzione standalone di file ad alto bitrate è alla sua portata. **Nessun AV1**, il che conferma H.265 come formato di libreria anche per questo percorso.
 
| Candidato | Distribuzione | Fonti di rete | Nota |
|---|---|---|---|
| MermaidVR | **Viveport**, gratuito | Da verificare | Nativo per il visore, attrito zero: primo da provare |
| SKYBOX | Sideload APK | SMB 1.0/2.0, WebDAV, DLNA, **e Plex/Emby/Jellyfin** | Il più capace. Build pensate per lo store Meta: possibili dipendenze dal runtime Meta |
| DeoVR | Sideload APK | Sì | Già in uso via SteamVR, gratuito |
| Viveport Video | Preinstallato | Limitate | Riproduce 3D/180/360 locali; funzionalità scarse secondo i forum HTC |
 
**Diagnostico a costo quasi nullo, da fare prima di scegliere:** installare da Viveport un file manager che supporti le condivisioni di rete e verificare che veda una share SMB in LAN. Se la vede, il percorso di rete funziona e resta solo da scegliere il player; se non la vede, il problema è a monte. Conferma anche che il sideload di APK è una procedura supportata sul visore.
 
**Convergenza da notare:** SKYBOX supporta Jellyfin come sorgente. Con SKYBOX sul visore, l'SMB diventa superfluo — il visore parla direttamente al media server. È un ulteriore argomento nella colonna del media server.
 
### 9.7 Assistente AI `[TBD]` `[?]`
 
Sottoproblemi indipendenti:
 
1. **Provider e modello** — API esterna. Implica invio di dati a terzi: sotto `I-08` va definito per iscritto **cosa non può mai uscire**. È il punto più delicato dell'intero progetto se l'assistente ha accesso a note di studio o materiale clinico. `Q-39`.
2. **Runtime e skill** — come sono definite, versionate, e con quali privilegi. Ogni strumento concesso è una superficie.
3. **Canale esterno** — candidati: `signal-cli` (allineato alla privacy, richiede un numero dedicato), Matrix con server self-hosted leggero, bot Telegram (semplice ma server proprietario). Se il telefono è nodo della rete overlay (§6.3), l'opzione più pulita è **nessun bridge esterno**: si parla con l'assistente attraverso l'app dell'ecosistema.
4. **Persistenza** — memoria conversazionale: dove risiede, se è cifrata, se è nel perimetro di backup.
5. **CLI agent** — `opencode` indicato come provvisorio. `Q-40`: confermi, o valutiamo alternative open source per l'uso da terminale?
### 9.8 Password manager `[TBD]`
Vedi §5.4 per la distinzione fra segreti di automazione e password interattive. Candidati per le seconde: `KeePassXC` più file sincronizzato (nessun servizio, ottimo desktop, mobile decente, rischio conflitti); `Vaultwarden` più client Bitwarden (server leggero in Rust, client ufficiali browser e mobile gratuiti, ottimo per il mobile); `pass` (Unix-native, mobile scomodo). Requisiti da verificare: TOTP, supporto chiave hardware, integrazione CLI per gli script, procedura di revoca in caso di dispositivo perso.
 
### 9.9 Sincronizzazione calendario `[TBD]`
Vedi §8.8. Il server deve esporre CalDAV, altrimenti §12 cresce di un'app.
 
### 9.10 Osservabilità e manutenzione `[TBD]`
Livello minimo necessario per `I-09`: notifica su fallimento di qualsiasi unit systemd (`OnFailure=`), monitoraggio SMART dei dischi (`smartmontools`), esito dei backup (§13.6), spazio disco. Candidato per la consegna delle notifiche: un servizio di push self-hosted leggero, che risolverebbe **anche** §12.4. Stack completi tipo Prometheus più Grafana sono sovradimensionati per tre host e pesanti per il Mac mini. `Q-41`: livello richiesto?
 
---
 
## 10. Software sviluppato in proprio
 
### 10.1 Governance `[BLOCK]` `[?]`
 
I requisiti attuali implicano potenzialmente 8–10 applicazioni proprie. `I-10` impone disciplina.
 
Criterio proposto: si sviluppa in proprio **solo se** (a) nessuna opzione esistente soddisfa `I-06`, oppure (b) l'opzione esistente porta dipendenze irriducibili indesiderate, oppure (c) il componente è la colla fra due sistemi propri e quindi non esiste per definizione, oppure (d) l'aggiornamento live del tema (§7.6) è un requisito e nessun candidato è di classe A.
 
Decisioni da prendere **una volta sola**, prima di scrivere codice:
 
| Decisione | Perché è vincolante |
|---|---|
| Linguaggio per CLI e TUI | Determina distribuzione (binario statico contro runtime) e avvio a freddo. **Nota: non c'è cross-compilazione.** Il Mac mini è Intel, quindi tutte e tre le macchine sono x86_64 Linux e compilano lo stesso binario. Il criterio decade |
| Libreria TUI unica | Prerequisito di `I-05`: due librerie producono due estetiche |
| Linguaggio per i componenti desktop | Vincolato dalle API Wayland e dall'ecosistema Hyprland |
| Contratto di configurazione e token | Tutte le app leggono i token di §7 e ricaricano allo stesso modo (classe A per costruzione) |
 
**Decisione provvisoria (ADR 016): Go.**
 
Criterio che ha escluso le alternative: `phi` viene invocato dal launcher, quindi l'**avvio a freddo è un requisito funzionale**. Un launcher che impiega centinaia di millisecondi a elencare i comandi è percepito come rotto. Questo esclude i linguaggi con runtime da caricare, lasciando Go e Rust, entrambi nell'ordine dei millisecondi.
 
#### 10.1.1 Reversibilità della scelta: cosa cambia davvero passando a Rust
 
La scelta è provvisoria. Il costo di cambiare però non è uniforme: **il linguaggio non è la parte cara, lo è il livello di presentazione.**
 
| Ambito | Cambia? | Costo del cambio |
|---|---|---|
| Logica di dominio: client API, parsing config, token di design, coda job, modello dati | Sì, ma è codice meccanico | Basso. È l'80% delle righe e il 20% della fatica |
| **Libreria TUI e livello di vista** | Sì, radicalmente | **Alto.** I due ecosistemi hanno modelli di rendering incompatibili: uno a messaggi con stato esplicito, l'altro a ridisegno immediato. Widget, layout e API di stile non si mappano. Ogni app TUI va riscritta nella vista |
| Invocazione di strumenti esterni (downloader, ffmpeg, tagger) | No | Nullo: sono sottoprocessi, indifferenti al linguaggio |
| Distribuzione a binario singolo | No | Nullo |
| Compilazione per il server | No | Nullo: tutte le macchine sono x86_64 Linux |
| Binding a librerie C (audio, metadati, Wayland) | Sì | Medio. È il punto in cui Go diventa scomodo e Rust no |
| **Componenti Wayland nativi** (barra §10.8, launcher §10.3) | Sì | **Alto.** L'ecosistema Wayland e la tooling dell'ecosistema Hyprland sono in larga parte Rust; il supporto Go è sottile |
| Velocità di iterazione | Sì | A favore di Go: compilazioni in secondi contro decine di secondi su un progetto che cresce |
 
**La domanda che decide davvero non è "Go o Rust", è: `phi` resta CLI e TUI, o cresce in superfici Wayland native?**
 
- Se il launcher è un front-end sottile che invoca i verbi `phi` e la barra è una barra esistente configurata, **Go va bene per sempre**.
- Se invece launcher e barra sono componenti Wayland scritti da zero, **Rust è strutturalmente più adatto**, e conviene saperlo prima di aver scritto tre app TUI in Go.
**Correzione dopo la specifica di §10.3.1:** questo gate è più debole di quanto sembrasse. La specifica del launcher è pesante di logica e leggera di superficie, e la logica vive comunque in `phi`. La superficie può essere un launcher esistente, oppure un guscio scritto con un toolkit di alto livello in un linguaggio diverso da quello di `phi`: in nessuno dei due casi Go è messo in discussione. Rust torna in gioco solo nello scenario in cui si scriva la superficie con binding Wayland di basso livello, che questa specifica **non richiede**.
 
**Come tenere l'opzione aperta a costo quasi nullo:**
1. Separare fin dall'inizio la logica di dominio dal livello di vista. Il porting della prima è meccanico, quello della seconda no.
2. Trattare l'API di §10.4 come confine: se i client parlano al server via protocollo documentato anziché condividere una libreria, un componente Rust si aggiunge domani senza toccare il codice Go.
3. **La forma scelta in §10.2 è già la copertura**: con il fallback su PATH, un singolo sottocomando può essere un binario Rust chiamato `phi-bar` senza riscrivere niente.
**Scadenza pratica:** ogni app TUI scritta in Go aumenta il costo del porting. La prima è economica da rifare, la terza no. Riconsiderare Rust **prima della seconda app TUI**, oppure mai.
 
### 10.2 `phi` — CLI unificata `[BLOCK]` per §10.3, §10.4, §12 — **nuovo requisito**
 
Job to be done: un solo punto di ingresso per tutte le funzioni custom del sistema.
 
**Contratto da definire:**
 
| Aspetto | Decisione richiesta |
|---|---|
| Grammatica | Proposta: `phi <dominio> <verbo> [argomenti]` — es. `phi music add <url>`, `phi media watch <titolo>`, `phi theme set <accento>`, `phi backup run`, `phi doctor` |
| Architettura | **Decisa (ADR 017): monolite con fallback su PATH.** Il binario gestisce i verbi noti con help, completamenti e gestione errori uniformi; se il verbo non è riconosciuto cerca `phi-<nome>` nel PATH ed esegue quello. Coerenza sul nucleo, estensibilità ai bordi, e possibilità di scrivere singoli sottocomandi in un altro linguaggio |
| Output | Doppio: leggibile e stilizzato su TTY, strutturato quando l'output è ridiretto. Regola: mai colori o spinner quando non si scrive su un terminale |
| Configurazione | File unico, con override per host |
| Completamenti | Generati per zsh dal comando stesso |
| Rapporto con l'API | `phi` è il **client di riferimento** dell'API di §10.4: ogni verbo esiste sia come comando che come endpoint. Il launcher (§10.3) e l'app mobile (§12) sono altre facce degli stessi verbi |
| Comportamento offline | Ogni verbo dichiara se richiede il server; in assenza, fallisce in modo esplicito o accoda |
 
#### 10.2.1 Ambito: cosa entra in `phi` e cosa no `[OK]`
 
Il rischio da evitare è la ridondanza: un verbo `phi` che è un alias sottile su un comando già esistente non aggiunge niente e aggiunge manutenzione.
 
**Due test da applicare a ogni verbo candidato:**
 
1. **Test di composizione.** L'operazione attraversa più di uno strumento, oppure codifica una convenzione che esiste solo nel tuo sistema? Se sì, `phi`. Se è un alias su un solo comando di un solo strumento, no.
2. **Test di proprietà dello stato.** Chi possiede i dati su cui l'operazione agisce? Se li possiede un'applicazione, il comando appartiene a quell'applicazione, non a `phi`.
**La risoluzione del dubbio "comandi di app specifiche dentro `phi` o fuori": entrambe le cose, senza duplicazione.** Grazie ad ADR 017, un'app custom mantiene il proprio binario e la propria CLI, chiamato `phi-<dominio>`; `phi` lo raggiunge via fallback su PATH. L'implementazione resta una sola, ma è esposta sotto un namespace uniforme con help e completamenti coerenti, ed è scopribile dal launcher. **`phi` è un namespace e un dispatcher, non un proprietario.**
 
#### 10.2.2 Le tre categorie e la loro collocazione
 
| Categoria | Esempio | Dove vive | Perché |
|---|---|---|---|
| **1. Sequenze ripetitive** | `phi repo add <nome>`: crea il bare repo nella directory adibita, imposta i permessi, restituisce l'URL SSH pronto da incollare | **Nucleo `phi`** | Compone git, filesystem e configurazione SSH. Nessuno strumento la possiede |
| **2. Script di dominio riutilizzabili** | `phi music add <sorgente>` | **Binario `phi-music`**, che consuma una **libreria condivisa** | Passa il test 1 ma anche il 2: la logica di fetch e catalogazione serve pure al client musicale, quindi va estratta in libreria con due consumatori, non duplicata |
| **3. Comandi di sistema phiOS** | Vedi §10.2.3 | **Nucleo `phi`** solo se supera il test 1 | La maggior parte dei candidati intuitivi lo fallisce |
 
La distinzione fra 1 e 2 non è concettuale, è di **struttura del codice**: la categoria 2 identifica esattamente ciò che va estratto in libreria perché ha più di un consumatore.
 
#### 10.2.3 Comandi di sistema che superano il test
 
Nessuno di questi è un alias: tutti compongono tre o più strumenti e codificano una convenzione del sistema.
 
| Verbo | Cosa compone |
|---|---|
| `phi theme set/preview` | Rigenerazione da token, scrittura di N file, ricarica differenziata per classe (§7.6) |
| `phi server unlock` | SSH, sblocco LUKS a cascata, attesa dei mount, avvio dei servizi dipendenti (§4.4.3) |
| `phi update` | Snapshot preventivo, aggiornamento pacman, revisione AUR, rigenerazione config, esito (§8.17) |
| `phi doctor` | Età dell'ultimo backup, spazio disco, numero di snapshot, stato dei servizi, SMART (§9.10) |
| `phi backup run/verify/status` | Snapshot, replica, repository cifrato, verifica, notifica (§13.6) |
| `phi pin` | Sottosistema di disponibilità offline, trasversale a musica, media e file (§10.5) |
| `phi query` | Backend logico del launcher (§10.3.2) |
 
**Controesempi espliciti — non entrano in `phi`:** riavvio, spegnimento, volume, luminosità, screenshot. Sono operazioni a strumento singolo già coperte. Se servono nel launcher, ci arrivano come *azioni di sistema* fra i risultati, non come verbi `phi`.
 
Questa sezione è bloccante perché definisce l'interfaccia che tutto il resto del software custom implementa.
 
### 10.3 Launcher `[TBD]` — specifica e valutazione
 
#### 10.3.1 Requisiti dichiarati
 
Barra tipo Spotlight, invocata da scorciatoia globale.
 
1. Ricerca di applicazioni, file e web.
2. Esecuzione di comandi.
3. Funzioni integrate: calcolatrice, conversione valuta, traduzione, e altre da selezionare.
4. **Modalità con Tab**: parola chiave più Tab entra in una ricerca specifica preimpostata (`file`, `web`, `yt`, ...). Le modalità vanno valutate una per una.
5. **Senza Tab**: una logica di ranking decide il tipo di risultato, alla Spotlight (prima l'app se il nome corrisponde, poi i file, ecc.).
6. **Comando diretto**: se la prima parola è un comando di shell, Invio apre una nuova finestra di terminale e lo esegue. Il risultato non deve comparire nella barra.
#### 10.3.2 Decomposizione: superficie contro logica
 
La specifica si divide in due strati con costi molto diversi:
 
| Strato | Contenuto | Peso nella specifica |
|---|---|---|
| **Superficie** | Finestra fluttuante con layer-shell, campo di testo, lista risultati, eventuale anteprima | Modesto: nessun requisito grafico esotico |
| **Logica** | Ranking, modalità, provider di risultati, calcolatrice, rilevamento comandi, azioni | **Quasi tutto** |
 
Conseguenza architetturale vincolante: **la logica vive in `phi`, il launcher è un renderer.** Il launcher chiede a `phi` i risultati per una stringa e li disegna. Questo produce tre effetti: cambiare launcher in futuro costa quasi nulla; gli stessi verbi funzionano da CLI, da launcher e da mobile; e la scelta del linguaggio della superficie si scollega da `Q-42`.
 
#### 10.3.3 Criterio che discrimina i launcher esistenti
 
La domanda non è "quanto è bello", è: **la lista dei risultati può essere ricalcolata da codice esterno a ogni battuta?**
 
| Famiglia | Modello | Regge la specifica? |
|---|---|---|
| Stile dmenu (`fuzzel`, `wofi`, `bemenu`) | Legge una lista statica da stdin, restituisce la riga scelta | **No.** La lista è fissata prima che la finestra si apra: incompatibile con `web`+Tab, ricerca file, e ranking dinamico |
| `rofi` con modalità script | Reinvoca lo script a ogni cambio di input | **In gran parte sì.** Modalità e risultati dinamici funzionano; il rendering resta una lista testuale e il tema ha un formato proprio (generabile) |
| Launcher a provider/estensioni | Provider dinamici, prefissi, moduli integrati | **Sì**, è il modello nativo per questa specifica |
| Framework di widget (`ags`/`astal`, `quickshell`) | Costruisci la superficie con un toolkit di alto livello su layer-shell | Percorso "costruisci", ma senza scrivere Wayland grezzo |
 
**Nota importante:** "superficie Wayland nativa" non significa protocollo Wayland grezzo. Significa layer-shell attraverso un toolkit. Solo il primo livello richiede binding di basso livello, e questa specifica non lo richiede.
 
#### 10.3.4 Candidato principale da valutare `[?]`
 
Un launcher C++/Qt nativo Wayland, con daemon in background, ha oggi la copertura più vicina alla specifica: calcolatrice, conversione valuta, ricerca file, storico clipboard e selettore emoji già integrati, sistema di temi con file TOML in una directory dedicata, modalità dmenu, comandi-script, IPC e CLI.
 
Punti a favore rispetto agli invarianti:
- I temi sono file TOML: **generabili dai token di §7.1**, quindi soddisfa `I-05` e si colloca in classe A/B per §7.6.
- La modalità comandi-script permette di esporre i verbi `phi` senza toccare il runtime delle estensioni.
- Storico clipboard ed emoji integrati **eliminano due componenti separati** da §8.2, a beneficio di `I-10`.
Attriti da verificare prima di adottarlo:
- Le estensioni ricche girano su un runtime TypeScript/React, quindi Node sul desktop. Attrito con `I-01` e `I-04`. Mitigabile restando ai comandi-script.
- La compatibilità con l'ecosistema di estensioni Raycast è pubblicizzata ma riportata come inconsistente nella pratica: **non va conteggiata come beneficio** nella decisione.
- Distribuzione via AUR o AppImage: tier T1/T2 o T4 secondo §2.2. Progetto giovane e in movimento rapido.
- Gira come daemon persistente.
**La domanda che decide, ed è verificabile in una serata `[?]`:** *i provider integrati si possono disattivare?*
 
La tua obiezione è fondata: adottare un launcher che porta già storico clipboard, emoji e calcolatrice significa o usarli, o averne due. La seconda è una violazione diretta di `I-04`.
 
- Se i moduli integrati si disattivano e si può alimentare il launcher con i soli provider `phi`, adottarlo è economico e reversibile: si sfrutta la superficie e si scarta la logica.
- Se non si disattivano, si eredita ridondanza strutturale e la costruzione diventa giustificata dal criterio (b) di §10.1.
Secondo criterio, da verificare insieme al primo: lo **stack di navigazione** di §10.3.6.1, cioè la possibilità di aprire sotto-viste con campi di input.
 
`Q-44`: esito della prova.
 
#### 10.3.5 Cosa nessun launcher esistente farà
 
Le modalità legate al tuo ecosistema, che sono precisamente ciò che giustifica il lavoro custom secondo il criterio (c) di §10.1:
 
`music`+Tab che cerca nella libreria (§9.5) • `media`+Tab che aggiunge alla watchlist (§10.7) • `note`+Tab per la cattura rapida (§8.13) • `phi`+Tab per i verbi di sistema • `ssh`+Tab sugli host noti
 
Sono **provider custom**, non un launcher custom. È una distinzione che cambia l'ordine di grandezza del lavoro.
 
#### 10.3.6 Tipi di risultato e ranking `[TBD]`
 
Il cuore della specifica è il punto 5: senza Tab, una logica decide cosa mostrare. I tipi di risultato dichiarati:
 
applicazione • comando di terminale (con completamento o suggerimento in tono attenuato) • calcolo • file • ricerca web • brano nella libreria musicale • voce nello storico clipboard
 
**Tipi mancanti che valgono la pena, in ordine di frequenza d'uso attesa:**
 
| Tipo | Perché | Costo |
|---|---|---|
| **Passaggio a finestra già aperta** | Su un compositore a tiling è plausibilmente l'azione più frequente dopo il lancio di app: evita di riaprire ciò che è già aperto. Assente dalla lista | Basso: il compositore espone l'elenco finestre |
| **Salto a progetto o directory** | `zoxide` è già approvato e mantiene le directory per frecency: il provider è quasi gratuito. Apre in terminale o editor | Molto basso |
| **Azioni di sistema** (blocca, sospendi, esci) | Copre il caso che *non* deve diventare un verbo `phi` (§10.2.3) | Basso |
| Host SSH | Tre macchine, letti dalla config SSH | Molto basso |
| Segnalibri del browser | Sovrapposto alla ricerca web, ma più preciso | Basso |
| Voci del vault password | **Decisione di sicurezza, non di comodità.** Indicizzare titoli di credenziali in un launcher amplia la superficie sotto `I-08`. Da decidere consapevolmente (`Q-73`), non da assumere | — |
 
#### 10.3.6.1 Modalità Tab: la domanda si dissolve `[TBD]`
 
Il dubbio "modalità con Tab oppure termini esatti che appaiono come risultato" presuppone che siano due meccanismi alternativi. Non lo sono: **sono lo stesso oggetto a due livelli di impegno.**
 
Si implementa un tipo di risultato "comando" che, quando attivato, **spinge una sotto-vista** invece di eseguire e chiudere. Digitando `translate` compare il risultato "Translate"; premendo Invio si entra nella sua interfaccia. Il Tab su una parola chiave diventa allora **un acceleratore sullo stesso oggetto**, non una funzionalità separata da progettare.
 
Conseguenza pratica: rimandare le modalità Tab **non costa niente**, perché non è una feature da aggiungere dopo ma una scorciatoia su un meccanismo già presente. Va invece deciso subito il meccanismo sottostante.
 
**Requisito che ne deriva, ed è il vero discriminante `[BLOCK]` per §10.3.4:** il launcher deve supportare uno **stack di navigazione** con sotto-viste che non siano semplici liste — la vista di traduzione ha campi di input e un riquadro di output. È esattamente la capacità che separa un launcher stile dmenu da un command palette. Va verificata nel candidato prima di adottarlo, o costruita.
 
#### 10.3.6.2 Cosa costa costruirlo, se si costruisce
 
| Elemento | Note |
|---|---|
| Finestra layer-shell con cattura tastiera | Fornita dal toolkit |
| Campo di testo, lista virtualizzata, icone freedesktop | Forniti dal toolkit |
| **Stack di navigazione e viste con form** | Forniti dal toolkit, ma vanno progettati |
| Orchestrazione asincrona dei provider | **Da scrivere.** I risultati arrivano con latenze diverse e non devono mai bloccare la digitazione |
| Ranking e frecency | Da scrivere. È la parte che determina se sembra intelligente |
| Tema dai token | Da scrivere, ma banale se il toolkit usa CSS o QML |
 
**Implicazione sul linguaggio:** i primi elementi vengono dal toolkit, quindi **è il toolkit a determinare il linguaggio della superficie, non il contrario**. È il punto in cui i binding GTK4 o Qt contano più della preferenza personale, ed è anche il punto debole di Go. Ma per ADR 018 la superficie è un programma **separato** da `phi`: può essere scritta in un altro linguaggio senza intaccare la scelta di §10.1.
 
**Raccomandazione di sequenza:** la logica di ranking è la parte rischiosa e iterativa, la superficie è quella meccanica. Conviene validare `phi query` con un prototipo in terminale su `fzf` — già approvato — prima di impegnarsi su qualunque GUI. Si sbaglia il ranking molte volte, e sbagliarlo in terminale costa niente.
 
#### 10.3.7 Punti tecnici da risolvere
 
**Ambiguità app contro comando.** `firefox` è sia un'applicazione sia un eseguibile. Euristica pulita: token singolo → applicazione; token seguito da argomenti → comando. Da confermare (`Q-74`).
 
**Terminale che resta aperto.** `nano` trattiene la finestra perché è interattivo, ma `ls` lampeggerebbe e sparirebbe. Serve una politica di hold, per comando o come default.
 
**Ricerca file — la parte difficile.** Tre approcci: invocazione live limitata a una directory (semplice, non scala alla home); indice aggiornato periodicamente (query veloci, risultati non freschi); indice con watch del filesystem (fresco, complesso). Proposta: indice per la home più ricerca live nella directory di progetto corrente. La ricerca *dentro* i file è un problema separato e più pesante: da rimandare.
 
**Vincolo `I-08` sull'indice file:** l'indice contiene i nomi di tutto, incluso il materiale sensibile. Deve risiedere sul volume cifrato ed essere escluso da qualunque sincronizzazione.
 
**Frecency.** Ciò che fa sembrare intelligente un launcher è il ranking pesato sull'uso: frequenza più recenza, per elemento. Richiede un piccolo store persistente. È poco codice ed è la differenza fra "funziona" e "è piacevole".
 
**Calcolatrice, valuta, traduzione.** La prima è un valutatore di espressioni con conversione di unità, interamente locale. Le altre due richiedono rete: per la valuta serve una fonte di tassi senza chiave con cache e ricaduta sull'ultimo valore noto; la traduzione riusa il backend di §8.11 anziché introdurne un secondo.
 
### 10.4 API interna `[BLOCK]` per §10.5, §10.6, §12 `[TBD]`
Con più client (CLI, TUI, launcher, mobile) sugli stessi dati serve **un solo contratto**. Da decidere: protocollo, formato, autenticazione con token per dispositivo revocabili, versionamento, gestione dei job asincroni (i download sono lunghi e falliscono), comportamento offline dei client. `Q-45`.
 
### 10.5 Sottosistema di pinning e disponibilità offline `[TBD]` — **nuovo requisito, trasversale**
 
Requisito emerso per musica e media, ma che risolve anche note, documenti e foto: **un solo meccanismo** con cui un dispositivo dichiara "voglio questo contenuto disponibile localmente".
 
Elementi da definire:
- Modello: un *pin* è una dichiarazione per (dispositivo, contenuto). Il server conosce i pin di ogni dispositivo.
- Budget per dispositivo: il laptop da 512 GB ha bisogno di un limite e di una politica di sfratto (es. il meno usato di recente).
- Trasporto: riuso del meccanismo scelto in §9.3.
- Verifica di integrità dopo il download.
- Comportamento del player quando il contenuto pinnato non è ancora disponibile.
- Esposizione: `phi music pin`, `phi media pin`, e i corrispondenti nell'app mobile.
Questa astrazione evita di implementare tre volte la stessa cosa in tre client diversi.
 
### 10.6 Pipeline musicale `[TBD]`
 
Requisito: dato un URL, scaricare, compilare i metadati mancanti, collocare il file nella libreria organizzata, aggiornare l'indice — con la stessa funzione disponibile lato client e sincronizzata.
 
Componenti candidati: `yt-dlp` per il download, `ffmpeg` per la conversione, `beets` per tagging, arricchimento dei metadati e organizzazione automatica nella struttura di cartelle — `beets` copre quasi esattamente il job descritto ed è estendibile a plugin, quindi merita valutazione prima di scrivere codice proprio.
 
Punti architetturali da decidere:
- **Dove viene eseguito il lavoro.** Se il client scarica e poi sincronizza, esistono due percorsi di ingestione e due possibilità di divergenza. Se il client accoda un job sul server, il percorso è uno solo — più semplice e coerente con §9.2, ma richiede il server raggiungibile. Raccomandata la seconda con accodamento locale in caso di server irraggiungibile.
- Deduplica per hash di contenuto, non per nome file.
- Comportamento in caso di metadati ambigui: fallire e chiedere, non indovinare.
- Idempotenza e ripetibilità dei job falliti.
- Formato e qualità target, coerenti con la scelta direct-play di §9.6.
### 10.7 Watchlist e pipeline media `[TBD]`
Stesso schema di §10.6: azione avviata da qualunque dispositivo, esecuzione sul server, stato visibile ovunque. Da definire: schema dati, stati (da vedere / in corso / visto), risoluzione del titolo a un identificatore stabile, coda di acquisizione, notifica a completamento, e integrazione con il pinning (§10.5) per il download offline.
 
### 10.8 Componenti desktop custom `[VUOTO]`
Barra di stato, pannello impostazioni, app note, TUI giochi (§11.5). Da specificare individualmente solo dopo §10.1, §10.2 e §7.
 
---
 
## 11. Gaming, game dev e VR (`desktop`)
 
### 11.1 Windows — **rimosso dal piano (ADR 044)**
 
Verifica conclusa il 2026-08-30. Le ragioni che avevano motivato la cautela iniziale si sono rivelate infondate o mal attribuite:
 
| Preoccupazione iniziale | Esito della verifica |
|---|---|
| Codec AV1 non supportato dal visore | **Irrilevante.** La serie RTX 30 ha decodifica AV1 ma **non encoding**: quello arriva con Ada. H.265 è il codec in entrambi i sistemi operativi |
| Latenza NVIDIA in VR | **Mal attribuita.** Il problema di latenza di presentazione DRM lease riguarda i visori **cablati**. I visori standalone in streaming sono generalmente valutati Platinum |
| Scelta fra ALVR e WiVRn | **Non esiste una scelta.** ALVR è deprecato per Linux e incompatibile con SteamVR 2.16.7+. WiVRn è l'unico percorso |
| Unreal Engine su Linux | Epic pubblica **build binarie ufficiali precompilate**, ~25 GB compressi. La specifica raccomandata è 32 GB di RAM, esattamente la dotazione di `zotac` |
| Anti-cheat | Irrilevante: nessun interesse per il multiplayer online |
| Flag "Laggy" sul visore | **Vedi sotto: è una caratteristica del visore, non di Linux** |
 
**Il flag "Laggy" non è un problema di Linux.** Sui forum ufficiali HTC è documentato che l'XR Elite presenta stuttering marcato in streaming wireless a parità di impostazioni e di rete dove il Vive Focus 3 non ne ha — **sul software di streaming di HTC stesso**. Il difetto esiste indipendentemente dal sistema operativo, quindi Windows non lo risolverebbe.
 
**Due avvertenze reali e specifiche di Linux, da registrare onestamente:**
 
1. **WiVRn dichiara di non essere ben ottimizzato per le GPU NVIDIA**, per assenza di sviluppatori con quell'hardware, e avverte che la latenza di movimento può peggiorare sensibilmente a risoluzioni di rendering superiori a quella predefinita. Mitigazione: restare alla risoluzione predefinita, non spingere il supersampling.
2. **Il requisito di rete è stringente e non negoziabile**: collegamento gigabit cablato fra PC e router, e access point dedicato in modalità AP. Qualunque forma di collegamento wireless fra computer e router compromette latenza e qualità.
**Ripiego disponibile:** WiVRn supporta anche una modalità cablata via USB, che aggira interamente lo stack wireless. È la contromisura se lo stuttering del visore si rivelasse invalidante.
 
**Il valore di opzione di tenere Windows è nullo**, perché è installabile in seguito su una partizione (§11.1.1). Quindi non c'è ragione di conservarlo ora.
 
#### 11.1.1 Reinstallare Windows in futuro, se servisse
 
Windows **non richiede un disco intero**: si installa su una partizione di un disco GPT condiviso. Gli serve una ESP (può usare quella esistente o averne una propria) più una piccola partizione riservata Microsoft.
 
Due accortezze:
- L'installer Windows è aggressivo sulla ESP e sull'ordine di avvio: tipicamente si impone come predefinito. Si previene facendo una copia della ESP prima, e ripristinando la voce di Arch dopo.
- **Non serve riservare spazio ora.** Btrfs si riduce a caldo con `btrfs filesystem resize`; con LUKS sotto servono due passaggi in più e una parte offline, ma è un'operazione documentata. Quindi si usa tutto l'1 TB adesso e si ritaglia solo se il bisogno arriva davvero.
### 11.2 Driver GPU `[TBD]`
Deroga già accettata (§2.4). Da decidere: quale variante del driver proprietario, quale kernel abbinato (§4.6), e la gestione degli aggiornamenti — un aggiornamento kernel senza il corrispondente driver rompe la sessione grafica, quindi va coperto dalla policy di snapshot preventivo (§4.2).
 
### 11.3 Piattaforme e giochi `[TBD]`
`steamcmd` è approvato. Da chiarire il perimetro: client Steam grafico oltre a steamcmd (`Q-48`), livello di compatibilità Proton, valutazione di `gamemode` e overlay di monitoraggio, gestione dei prefissi Wine per i giochi non-Steam, emulatori.
 
Nota `I-08`: Steam e i giochi sono la categoria di software meno affidabile del sistema. Vale la pena valutare l'isolamento (utente dedicato o sandbox) per tenerli lontani dai dati sensibili. `Q-49`.
 
### 11.4 VR — HTC XR Elite `[TBD]` — **nuovo requisito, area ad alto rischio**
 
L'XR Elite è un visore standalone su base Android: il PC gli invia video via rete, e sul visore gira un'app ricevente da installare tramite sideload.
 
Componenti da decidere, in tre strati indipendenti:
 
| Strato | Candidati | Note |
|---|---|---|
| **Runtime OpenXR** | `Monado` (open source, allineato a `I-03`); SteamVR (proprietario, più compatibile con i titoli esistenti) | La scelta condiziona lo strato successivo |
| **Streaming wireless** | `WiVRn` (basato su Monado, progettato per visori standalone Android). ALVR **escluso**: attualmente sconsigliato dalla documentazione di riferimento | Richiede l'installazione dell'app client sul visore |
| **Traduzione API** | Livello di compatibilità OpenVR→OpenXR, necessario per far girare titoli OpenVR senza SteamVR | Rilevante solo nel percorso Monado |
 
Fatti verificati che caratterizzano il rischio:
 
- Il visore **è supportato** da WiVRn, ma nella tabella di compatibilità upstream è fra i pochi annotati come lento, a differenza dei Quest e dei Pico che non hanno annotazioni. È un segnale specifico di questo hardware.
- Il visore **non decodifica AV1** anche se la GPU lo codifica: il codec di trasporto obbligato è H.265.
- Su NVIDIA servono workaround documentati (variabili d'ambiente per il pacing del compositor e un parametro kernel dedicato) e restano comunque problemi di frametime nel driver che possono produrre stutter.
- I titoli OpenVR richiedono un livello di traduzione verso OpenXR se non si usa SteamVR; SteamVR su Linux ha a sua volta la reproiezione asincrona problematica da anni.
- **Rete:** collegamento gigabit cablato fra PC e router, e access point dedicato in modalità AP collegato via ethernet. Se il desktop è su Wi-Fi la VR wireless è compromessa a prescindere.
Percorso scelto: **Monado più WiVRn**, con livello di traduzione OpenVR per i titoli che lo richiedono. Il percorso SteamVR resta disponibile su Windows senza costi aggiuntivi, data la decisione di §11.1. `Q-50` chiusa.
 
### 11.7 Desktop come nodo di calcolo AI `[TBD]` — requisito emerso
 
Il desktop deve eseguire pipeline AI locali, con lavori dispatchati da laptop e telefono.
 
Vincoli da registrare ora, approfondimento rimandato:
 
- **VRAM.** 8 GB sulla 3060 Ti. Delimita il campo: generazione di immagini e modelli linguistici piccoli quantizzati sono praticabili, modelli grandi no. Va verificato caso per caso prima di progettare pipeline.
- **Il desktop non è sempre acceso, e può essere avviato in Windows.** Entrambe le cose lo rendono un nodo *intermittente*. Conseguenze: serve Wake-on-LAN, e phiOS conviene come sistema di avvio predefinito, altrimenti la macchina è indisponibile ogni volta che hai giocato in VR.
- **Riuso della coda job.** Dispatch da laptop o telefono verso il desktop è lo stesso problema di §10.6 e §10.7: un lavoro accodato, eseguito altrove, con stato osservabile. **Va servito dalla stessa coda di §10.4 con un campo "nodo di esecuzione"**, non da un secondo meccanismo.
- **Spazio.** I modelli occupano decine di GB e competono con Unreal e i giochi sull'1 TB.
### 11.5 Game dev — Unreal Engine `[TBD]`
Da definire: modalità di installazione (il sorgente richiede un account Epic collegato), versione, spazio richiesto e collocazione su disco (§3.2), toolchain di build, dove risiede la cache derivata, integrazione con Neovim (§16.9). Vincolo di capacità: engine più cache più progetti più libreria giochi su 1,5 TB totali richiede una pianificazione esplicita, non improvvisata.
 
### 11.6 TUI unificata giochi ed emulatori `[TBD]`
Requisito espresso: interfaccia unica TUI su Steam, giochi vecchi ed emulatori. Nessuna soluzione esistente è TUI (i frontend consolidati sono GUI). È quindi un candidato legittimo allo sviluppo proprio secondo il criterio (a) di §10.1: un `phi games` che legge un manifesto di titoli e sa lanciare Steam, prefissi Wine ed emulatori con un'interfaccia sola. Da decidere dopo §10.2.
 
---
 
## 12. Mobile
 
### 12.1 Perimetro `[?]`
`Q-03`: Android, oppure iOS con sideload via AltStore? La risposta cambia costo e vincoli in modo sostanziale. Se non c'è già un dispositivo vincolante, **Android è nettamente più economico** per questo progetto: distribuzione libera degli APK, ecosistema F-Droid con client FOSS già esistenti per calendario, file, musica e media, nessun problema di firma.
 
### 12.2 Distribuzione iOS `[TBD]`
Con AltStore il sideload è possibile senza programma sviluppatori a pagamento, ma comporta: rifirma periodica dell'app, limite al numero di app sideloadate, e un dispositivo che esegua il servizio di rifirma. È sostenibile ma è manutenzione ricorrente. Da valutare anche l'opzione PWA, che elimina interamente il problema della firma su entrambe le piattaforme in cambio di limiti su notifiche push, esecuzione in background e riproduzione audio in background — limiti che per un'app musicale offline sono probabilmente **decisivi**. `Q-51`.
 
### 12.3 Superficie funzionale `[?]`
 
`Q-52`: quali funzioni servono davvero da telefono, in ordine?
 
Osservazione architetturale importante: **calendario, contatti e file possono essere coperti da protocolli standard con client già esistenti**, senza scrivere alcuna app. Musica e media hanno client FOSS esistenti con download offline. Restano scoperte solo le funzioni che non hanno un protocollo standard: watchlist, ingestione musicale via URL, verbi `phi`, assistente AI. Sotto `I-04`, **solo queste giustificano un'app propria**, che diventa quindi molto più piccola di quanto sembrasse.
 
### 12.4 Notifiche push `[TBD]`
Su iOS le push passano necessariamente dall'infrastruttura Apple. Su Android esistono soluzioni self-hosted che evitano i servizi Google mantenendo una connessione propria — a costo di un po' di batteria. Se il telefono è nodo della rete overlay (§6.3), un servizio di push self-hosted leggero copre **sia** le notifiche dell'ecosistema **sia** gli avvisi di §9.10 e §13.6. `Q-53`.
 
---
 
## 13. Backup, snapshot e ripristino `[BLOCK]` — priorità massima
 
**Snapshot ≠ backup.** Lo snapshot locale protegge da errore umano e aggiornamento fallito; non protegge da guasto disco, furto, incendio o ransomware. Servono entrambi.
 
### 13.1 Classificazione dei dati
Vedi §9.2, già impostata. Da completare con RPO e RTO per classe: quanti dati posso perdere, in quanto tempo devo tornare operativo.
 
### 13.2 Snapshot locali `[TBD]`
Dipende da §4.2. Candidati nell'ipotesi Btrfs: `snapper` con hook pacman per snapshot automatici prima e dopo ogni aggiornamento; `btrbk` per la replica incrementale verso l'SSD esterno; `timeshift`. Da definire: frequenza, retention, e capacità di avviare il sistema da uno snapshot precedente dopo un aggiornamento fallito.
 
### 13.3 Backup cifrati `[TBD]`
Requisiti da soddisfare: deduplica, incrementale, **cifratura lato client** obbligatoria, verifica di integrità, ripristino del singolo file, pruning automatico, funzionamento non presidiato. Candidati: `restic` (binario unico, molti backend, semplice da automatizzare), `borg` (maturo, dedup eccellente, richiede repo con locking), `kopia`. Wrapper per profili e pianificazione: `resticprofile`, `borgmatic`.
 
### 13.4 Topologia `[TBD]` `[?]`
 
Regola 3-2-1 come baseline. Stato attuale e proposta:
 
| Livello | Contenuto | Destinazione |
|---|---|---|
| 1 — snapshot locali | Tutte le macchine | Stesso disco (protegge da errore umano) |
| 2 — replica locale | Server: interno → SSD esterno 512 GB. Client: → server quando in rete | Disco separato, stessa sede |
| 3 — offsite | Solo classe irrecuperabile (§9.2): decine di GB | `Q-54` |
 
Opzioni per il livello 3: provider di storage economico con cifratura lato client (costo ricorrente contenuto, ma è una spesa e va contro `I-03` in senso lato); disco esterno cifrato conservato fisicamente altrove e ruotato periodicamente (costo zero ricorrente, richiede disciplina); macchina di un familiare raggiungibile via rete overlay (costo zero, richiede fiducia e disponibilità).
 
Dato che il volume offsite è nell'ordine delle decine di GB, tutte e tre le opzioni sono praticabili.
 
### 13.4.1 Momento di attivazione — **deciso (ADR 058)**
 
I backup non si predispongono durante la configurazione iniziale: finché il sistema non contiene dati, non c'è nulla da salvare.
 
**Il grilletto non è "il sistema è configurato", è "il primo dato reale atterra sul server".** Concretamente: il primo travaso di foto, i primi file musicali, i primi video. Da quel momento i backup devono già esistere, perché la finestra fra "ho i dati" e "ho i backup" è esattamente quella in cui li si perde.
 
Ciò che **non** si poteva rimandare era il layout che li rende possibili — filesystem, subvolumi, cifratura — ed è già deciso (§4.2, §4.4).
 
### 13.5 Pianificazione `[VUOTO]`
Server: snapshot giornaliero come richiesto. Client: opportunistico alla connessione a rete o disco noti. Da definire: finestre orarie, comportamento sotto batteria — il laptop non deve avviare backup completi a batteria — e gestione della sovrapposizione dei job. Su USB 2.0 (§3.1) le finestre vanno dimensionate di conseguenza.
 
### 13.6 Verifica e prove di ripristino `[VUOTO]` — non opzionale
Un backup mai ripristinato non è un backup. Da definire: verifica automatica dell'integrità, **notifica in caso di fallimento o di backup non eseguito da N giorni** (§9.10), e prova di ripristino calendarizzata con esito registrato. `phi backup verify` come comando esplicito.
 
### 13.7 Chiavi di backup `[BLOCK]`
Le chiavi di cifratura non possono stare solo nel vault che sta nel backup. Serve un percorso di recupero indipendente, offline e fisicamente sicuro. Da definire in §5.4.
 
---
 
## 14. Sicurezza
 
### 14.1 Modello di minaccia `[VUOTO]` — da scrivere prima delle contromisure
Da definire esplicitamente: furto o smarrimento del laptop (scenario più probabile), compromissione di un servizio, supply chain via AUR (§2.3), esposizione accidentale di dati sensibili verso l'API del modello AI (§9.7), errore umano, ransomware che monta i volumi di backup.
 
### 14.2 Baseline per host `[VUOTO]`
Cifratura disco, blocco automatico, policy sudo, superficie di ascolto di rete, isolamento dei servizi, aggiornamenti di sicurezza, isolamento della categoria giochi (§11.3).
 
### 14.3 Dati ad alta sensibilità `[TBD]` `[?]`
`Q-55`: gestirai materiale clinico o dati di persone identificabili? In caso affermativo servono misure aggiuntive: volume cifrato separato, esclusione esplicita da qualsiasi sync e da qualsiasi flusso verso l'AI, retention definita, e verifica degli obblighi normativi applicabili — punto su cui va consultata una fonte competente, non questo documento.
 
### 14.4 Igiene delle credenziali `[VUOTO]`
Rotazione, valutazione di una chiave hardware, MFA, revoca di dispositivo perso, separazione delle chiavi per host, procedura di emergenza.
 
---
 
## 15. Handoff fra dispositivi `[TBD]` `[?]`
 
Scomposizione per verificare cosa è già coperto dal resto del progetto:
 
| Sotto-funzione | Già coperta da | Serve davvero? |
|---|---|---|
| Controllo musica da un altro dispositivo | Se la sorgente è condivisa (§9.5), il "controllo remoto" diventa un caso d'uso dell'API (§10.4): `phi music pause` su qualsiasi nodo | Probabilmente sì, ma via `phi`, non via handoff |
| Trasferimento file computer↔computer | SSH e rsync su rete overlay | No |
| Trasferimento file computer↔telefono | §9.3 se il mobile ne è client | Dipende da `Q-35` |
| Clipboard condivisa | Non coperta. **Rischio `I-08` significativo**: una clipboard che attraversa la rete contiene password e dati sensibili | `Q-56` |
| Far suonare il telefono | Non coperta | `Q-57`: frequenza d'uso reale? |
| Notifiche unificate | Non coperta. Rapporto valore/complessità peggiore: richiede un bridge permanente e permessi ampi sul telefono | `Q-58` |
 
Conclusione provvisoria: fra computer, quasi tutto è già risolto da SSH e dalla sincronizzazione. Il valore residuo riguarda l'asse computer↔telefono. Valutare uno strumento dedicato **solo dopo** aver chiuso §9.3 e §12, perché potrebbero ridurre il residuo a poco o nulla.
 
---
 
## 16. Neovim — sezione dedicata
 
### 16.1 Obiettivo e anti-obiettivi
 
**Obiettivo:** rendere sostenibile la transizione da VS Code aggiungendo il minimo insieme di plugin necessari, non il massimo disponibile.
 
**Anti-obiettivi:**
- Nessuna distribuzione preconfigurata (`I-01`).
- Nessun plugin il cui job sia già coperto da una funzionalità nativa di Neovim recente. È il filtro più importante e il più ignorato: molte configurazioni diffuse installano plugin per cose che Neovim ormai fa da solo.
- Nessun plugin adottato per consuetudine. Ogni plugin ha una riga di giustificazione in §16.7.
- Nessuna dashboard, nessuna animazione, nessun greeter.
### 16.2 Baseline nativa `[VUOTO]` — da verificare prima di installare qualsiasi cosa
 
Ordine di lavoro obbligatorio: configurare Neovim nudo, usarlo per un periodo definito, e **solo allora** aggiungere un plugin per ogni attrito effettivamente riscontrato. Aggiungere plugin in anticipo rende impossibile capire quali servano davvero.
 
Da valutare in versione nativa: client LSP e sua configurazione, completamento automatico, parsing sintattico, ricerca fuzzy su file e buffer, esplorazione file, terminale integrato, diagnostica, quickfix, gestore di plugin integrato.
 
`Q-59`: quale versione di Neovim è nei repo al momento dell'installazione? Determina quanto della lista è già nativo.
 
### 16.3 Mappa di transizione VS Code → Neovim `[VUOTO]`
 
Da compilare voce per voce. `Q-60`: quali di queste usi realmente ogni giorno? Le voci a bassa frequenza non giustificano un plugin.
 
| Funzione VS Code | Frequenza | Copertura nativa? | Decisione |
|---|---|---|---|
| Command palette | | | |
| Quick open per nome file | | | |
| Ricerca testo nel progetto | | | |
| Explorer ad albero | | | |
| Go to definition / references | | | |
| Rename symbol | | | |
| Hover documentazione | | | |
| Autocompletamento | | | |
| Diagnostica inline | | | |
| Formattazione al salvataggio | | | |
| Multi-cursore | | | |
| Terminale integrato | | | |
| Git: gutter, blame, diff, stage per riga | | | |
| Debugger | | | |
| Task e build | | | |
| Tab dei file aperti | | | |
| Split e layout | | | |
| Snippet | | | |
 
### 16.4 Architettura della configurazione `[VUOTO]`
Da definire: punto di ingresso e moduli Lua (opzioni, keymap, LSP, plugin, aspetto), namespace del modulo, separazione fra config comune e per-host (il desktop ha bisogno di C++ e Unreal, il laptop no), integrazione con il deployment di §5.2, e **versionamento obbligatorio del lockfile dei plugin** — senza, la configurazione non è riproducibile e `I-09` è violato.
 
### 16.5 Gestore di plugin `[TBD]` `[?]`
 
| Candidato | Natura | Trade-off |
|---|---|---|
| Gestore integrato in Neovim | Nessuna dipendenza esterna, tier massimo | Recente, meno funzionalità, ecosistema di ricette meno maturo |
| `lazy.nvim` | Consolidato, lazy loading sofisticato, lockfile | Un DSL proprio in più, e molte funzionalità potenzialmente non necessarie |
| `mini.deps` | Minimale, coerente con una filosofia di piccole parti | Meno diffuso |
| `paq-nvim` | Estremamente semplice | Nessun lazy loading |
 
`Q-61`. Se la versione di Neovim disponibile include un gestore nativo funzionante, è la scelta più allineata a `I-01` e `I-02`.
 
### 16.6 Linguaggi da supportare `[?]`
`Q-62`: elenca i linguaggi effettivamente usati. LSP, parser, formattatori e linter si decidono **solo** in base a questa lista: installare supporto per linguaggi non usati è bloat per definizione. Da chiarire almeno: C++ per Unreal, Lua per la config, il linguaggio scelto in `Q-42`, quelli dello sviluppo web, e la scelta di §8.14 per la scrittura accademica.
 
### 16.7 Budget plugin `[VUOTO]`
 
- **L0 — nessun plugin.** Stato iniziale obbligatorio.
- **L1 — attrito dimostrato.** Un plugin per ogni attrito registrato per iscritto durante L0. Ogni voce richiede: problema riscontrato, alternativa nativa valutata, motivo dell'insufficienza.
- **L2 — qualità della vita.** Solo dopo che L1 è stabile da un periodo definito.
- **Rifiutati.** Elenco esplicito dei plugin valutati e scartati con motivazione, per non rivalutarli ciclicamente.
Nota di allineamento: quando si arriverà a L1, va preferito ciò che riusa strumenti **già approvati** in §20. La ricerca fuzzy costruita su `fzf` e la navigazione file delegata a `yazi` evitano di introdurre motori di ricerca e file manager duplicati dentro l'editor — un guadagno sia di coerenza (`I-05`) sia di superficie (`I-04`).
 
### 16.8 Keymap `[VUOTO]`
Da definire: leader key, organizzazione per prefissi mnemonici anziché mappature sparse, regola su cosa non rimappare mai (i comandi Vim nativi, che sono la competenza trasferibile), e se mantenere una modalità di compatibilità con le abitudini VS Code — sconsigliata, perché rimanda l'apprendimento invece di eliminarlo.
 
### 16.9 C++ e Unreal `[TBD]` — solo su `desktop`
Punto tecnico non banale: un progetto Unreal non produce per default il database di compilazione di cui il server LSP C++ ha bisogno per funzionare su una codebase di quelle dimensioni. Va definito come generarlo dal sistema di build di Unreal e come rigenerarlo quando cambiano i moduli. Da decidere separatamente se il debug interattivo avviene in Neovim (richiede un adapter di debug, non banale con Unreal) o resta affidato a strumenti esterni. `Q-63`.
 
### 16.10 Integrazione con il design system `[VUOTO]`
Vincolo `I-05`: il tema di Neovim non si sceglie da una libreria di temi — **si genera** dai token di §7.1. Da definire: formato del colorscheme generato, mappatura dei gruppi di evidenziazione ai token, gestione dei colori semantici coerente con `Q-17`, e coerenza con il tema del terminale per evitare doppia definizione.
 
Requisito aggiuntivo da §7.6: Neovim deve essere di **classe B**, cioè ricaricare il colorscheme a caldo su comando esterno, senza riavvio. Da verificare come pilotare le istanze in esecuzione.
 
### 16.11 Piano di transizione `[VUOTO]`
Processo temporale, non configurazione: periodo di uso parallelo con VS Code, criterio di abbandono, esercizio dei movimenti fondamentali, e regola per non configurare durante il lavoro — la configurazione è un'attività separata e calendarizzata, altrimenti diventa procrastinazione strutturale.
 
---
 
## 17. Roadmap per priorità
 
Ordinamento per **dipendenza**, non per interesse.
 
### P0 — Fondamenta (bloccanti)
1. §2.3 Igiene AUR e metodo di build
2. §4.2 Filesystem e strategia snapshot
3. §3.1 Caratterizzazione del Mac mini (determina §4.4, §9.4, §9.6)
4. §4.4 Cifratura e strategia di sblocco del server
5. §9.2 Layout dati e budget di capacità
6. §5.4 Segreti + §13.7 chiavi di backup
7. §5.1–5.2 Repo e meccanismo di deployment
8. §7.2–7.3 Token di design — sblocca ogni configurazione visiva
9. §9 Modello di deployment dei servizi
10. §10.1–10.2 Governance custom e contratto `phi`
### P1 — Sistema utilizzabile quotidianamente
11. §4.1, §4.3, §4.5–4.7 Installazione base sulle tre macchine
12. §6 Rete: ACL, SSH, perimetro
13. §13.2–13.6 Backup operativi **e verificati** — prima di mettere dati reali sul sistema
14. §8.1–8.5 Sessione desktop minima funzionante
15. §16 Neovim L0 e periodo di uso nativo
16. §7.6 Motore di tema (anche in versione minima: rigenerazione senza live reload)
### P2 — Servizi e produttività
17. §9.1 Git remote
18. §9.3 Sync file
19. §8.7–8.8 Mail e calendario, §9.9
20. §9.8 Password manager
21. §8.6 Browser
22. §16 Neovim L1
23. §8.13 + §10.6 Note
### P3 — Media, contenuti e mobile
24. §10.4 API interna e §10.5 pinning offline — prerequisiti dei successivi
25. §9.5 + §10.6 Musica e ingestione
26. §9.6 + §10.7 Film, serie e watchlist
27. §9.4 Foto e §8.12 galleria
28. §12 Mobile
### P4 — Gaming, VR ed estensioni
29. §11.1–11.3 Validazione giochi su Arch (prima di formattare Windows)
30. §11.4 VR
31. §11.5 Unreal Engine
32. §8.11, §8.14–8.16 Traduttore, office, impostazioni, meteo
33. §9.7 Assistente AI
### P5 — Rifinitura e identità
34. §7.7 Splash di boot e identità visiva
35. §10.3 Launcher, §10.8 barra e pannello impostazioni, §11.6 TUI giochi
36. §9.10 Osservabilità
37. §15 Handoff, se ancora necessario
Nota: l'identità visiva (§7.7) è deliberatamente in coda. È il requisito più visibile e il più tentante da fare per primo, ed è anche quello che, fatto per primo, garantisce di non completare mai le fondamenta.
 
---
 
## 18. Rischi di progetto
 
| Rischio | Impatto | Mitigazione |
|---|---|---|
| Superficie custom eccessiva (`I-10`) | Sistema immanutenibile, progetto bloccato | Criterio §10.1 applicato rigidamente; `phi` come punto unico riduce la duplicazione |
| Yak shaving sulla configurazione | Il tempo va nella config anziché in studio e sviluppo | Configurare è un'attività calendarizzata, non un'interruzione |
| Backup non verificati | Perdita di dati irrecuperabili | §13.6 obbligatoria prima di P2 |
| Windows formattato prima di validare VR | Perdita di funzionalità senza percorso di ritorno | §11.1: sequenza di validazione |
| Mac mini Intel sottodimensionato per i servizi previsti | Servizi lenti o inutilizzabili | §3.1 da chiudere presto; scelte di §9.4 e §9.6 subordinate |
| SSD esterni su USB inaffidabili | Corruzione dati, filesystem CoW danneggiati | §4.2: nessun pool su USB, replica esplicita, verifica dell'enclosure |
| Divergenza stilistica progressiva | `I-05` decade silenziosamente | §7.1 e §7.6: generazione dalla sorgente unica, mai config a mano |
| Perdita della root of trust | Sistema irrecuperabile | §13.7, percorso di recupero offline |
| Dipendenza da un singolo server | Un guasto blocca musica, file, note, AI | Il pinning offline (§10.5) è anche una strategia di degrado; `Q-64`: quali funzioni devono restare utilizzabili a server spento? |
 
---
 
## 19. Registro delle decisioni (ADR)
 
| # | Data | Ambito | Decisione | Alternative scartate | Reversibile? |
|---|---|---|---|---|---|
| 001 | 2026-08-29 | §2 | AUR e software proprietario ammessi solo dove necessari, con tiering e requisiti di sicurezza crescenti | Esclusione totale del non-ufficiale | Sì |
| 002 | 2026-08-29 | §2.4 | Deroghe accettate: driver NVIDIA, Unreal, Steam/Proton, firmware, firma iOS | Rifiuto totale del proprietario | Sì |
| 003 | 2026-08-29 | §11.1 | Obiettivo: Arch come sistema unico su `desktop`, Windows abbandonato | Dual boot permanente | Da confermare la sequenza (`Q-46`) |
| 004 | 2026-08-29 | §12.1 | iOS ammesso solo via sideload AltStore; altrimenti Android | Programma sviluppatori a pagamento | Sì |
| 005 | 2026-08-29 | §9.5, §9.6 | Download offline è requisito per i client musicali; desiderabile per i media | Solo streaming | No, è un requisito |
| 006 | 2026-08-29 | §10.2 | `phi` è il punto di ingresso unico di tutte le funzioni custom | Comandi separati per dominio | Costoso da invertire |
| 007 | 2026-08-29 | §9.5 | Musica: il server è l'unica sorgente di verità. I client ricevono in streaming e possono scaricare localmente. L'ingestione avviene sul server; sul client solo come ripiego offline | Sync-first con filesystem autoritativo | Sì |
| 008 | 2026-08-29 | §11.1 | Due dischi di avvio separati: Arch primario, Windows conservato per VR e software specifici. Selezione dal firmware, nessun bootloader condiviso | Formattazione immediata di Windows | Sì |
| 009 | 2026-08-29 | §11.4 | Percorso VR gaming: Monado più WiVRn. ALVR escluso | ALVR; SteamVR su Linux | Sì |
| 010 | 2026-08-29 | §9.6.1 | La libreria video VR è un requisito server autonomo, indipendente dal gaming VR e dal sistema operativo del desktop | Gestione dei file VR sul solo desktop | No, è un requisito |
| 011 | 2026-08-29 | §4.2 | Orientamento Btrfs su tutte le macchine, in attesa di conferma formale | ZFS; ext4 più LVM | Costoso da invertire |
| 012 | 2026-08-29 | §10.6 | La pipeline è spezzata in *fetch* e *catalogazione*; la catalogazione avviene sempre sul server. L'input è una "sorgente" che può essere URL o file | Pipeline monolitica duplicata su client e server | Sì |
| 013 | 2026-08-29 | §4.4 | Server: root non cifrata, tutti i volumi dati cifrati con sblocco via SSH sulla rete overlay. Sblocco a cascata da una sola passphrase | Passphrase manuale; SSH nell'initramfs; keyfile su USB | Sì |
| 014 | 2026-08-29 | §4.4.2 | Criterio di collocazione dei segreti: dati e segreti non revocabili sul volume cifrato; credenziali revocabili tollerate sulla root in chiaro con procedura di revoca | Cifrare tutto indistintamente | Sì |
| 015 | 2026-08-29 | §4.2.3 | Layout subvolumi base adottato in via provvisoria, da riconfermare prima dell'installazione | — | Sì |
| 016 | 2026-08-29 | §10.1 | Linguaggio del software custom: **Go**, in via provvisoria. Criterio decisivo: avvio a freddo come requisito del launcher | Rust, da riconsiderare in funzione di `Q-44`; Python e Node esclusi per il costo di avvio | Sì, ma il costo cresce con ogni app TUI scritta |
| 017 | 2026-08-29 | §10.2 | `phi` è un monolite con fallback su `phi-<nome>` nel PATH | Monolite puro; dispatcher puro | Sì |
| 018 | 2026-08-29 | §10.3.2 | Il launcher è un **renderer**: tutta la logica di ricerca, ranking e azioni vive in `phi`. Il launcher interroga `phi` e disegna | Logica dentro il launcher | Costoso da invertire, ma è la scelta che rende reversibile tutto il resto |
| 019 | 2026-08-29 | §10.3.6 | Le modalità Tab sono **dati** (nome, icona, modello di comando o URL), non codice. Solo le modalità che interrogano l'ecosistema richiedono codice | Una modalità = un plugin | Sì |
| 020 | 2026-08-29 | §10.3.3 | I launcher a lista statica in stile dmenu sono **esclusi**: non permettono di ricalcolare i risultati a ogni battuta | fuzzel, wofi, bemenu | Sì |
| 021 | 2026-08-29 | §10.2.1 | `phi` è un namespace e un dispatcher, non un proprietario. Due test di ammissione: composizione fra strumenti, e proprietà dello stato. Le app custom mantengono la propria CLI come `phi-<dominio>` | Verbi `phi` per ogni funzione; CLI separate senza namespace comune | Sì |
| 022 | 2026-08-29 | §10.3.6.1 | Le modalità Tab non sono una feature separata: si implementa il tipo di risultato "comando" che apre una sotto-vista, e Tab è un acceleratore sullo stesso oggetto | Modalità Tab come meccanismo distinto | Sì |
| 023 | 2026-08-29 | §10.2.2 | La logica di fetch e catalogazione musicale è una **libreria** con due consumatori (`phi-music` e il client), non codice duplicato | Duplicazione fra CLI e client | Sì |
| 024 | 2026-08-30 | §4.5 | Bootloader: `systemd-boot` su `zotac` e `razer`. **Niente boot da snapshot**: recupero con chiavetta di installazione e chroot | GRUB con voci di menu per snapshot | Sì |
| 025 | 2026-08-30 | §4.4 | Niente sblocco TPM sul laptop: riduce la sicurezza reale (la macchina rubata si avvia da sola) e va rifatto a ogni aggiornamento di kernel o bootloader | Enrollment TPM2 | Sì |
| 026 | 2026-08-30 | §11.3 | **Nessuna libreria Steam condivisa** fra Windows e phiOS: file diversi per lo stesso titolo, librerie su NTFS non supportate, Fast Startup che sporca il filesystem | Libreria condivisa sul disco Windows | Sì |
| 027 | 2026-08-30 | §3 | Allocazione dischi `zotac`: SSD 512 GB resta a Windows con i giochi VR già installati, SSD 1 TB a phiOS. Nessuno spostamento | Spostare Windows; partizionare un disco solo | Sì |
| 028 | 2026-08-30 | §4.6 | Swap: `zotac` piccola o zram (32 GB di RAM, macchina fissa, nessuna ibernazione). `razer` dimensionata per l'ibernazione | Swap uniforme | Sì |
| 029 | 2026-08-30 | §5.2.1 | Account di servizio via `DynamicUser` di systemd dove possibile; utente statico con gruppo condiviso solo per i servizi che accedono alla libreria comune | Utenti di servizio creati manualmente per ognuno | Sì |
| 030 | 2026-08-30 | §5.2.1 | Gerarchia server: `/srv` per i dati serviti, `/var/lib/<servizio>` per lo stato interno. Home client conforme a XDG | Dati sotto la home dell'utente; `/opt` | Sì |
| 031 | 2026-08-30 | §11.7 | Il dispatch di lavori AI verso il desktop riusa la coda job di §10.4 con un campo "nodo di esecuzione" | Meccanismo separato per il calcolo | Sì |
| 032 | 2026-08-30 | §3.1 | Server caratterizzato: Macmini7,1, 4 GB saldati. La RAM è il vincolo dominante e pota le opzioni pesanti di §9 | — | No, è un fatto |
| 033 | 2026-08-30 | §9.2.1 | `/srv` è un namespace: un subvolume per libreria montato al proprio percorso logico, indipendentemente dal disco fisico | Un disco = un albero; symlink fra alberi | Sì, ed è la scelta che rende reversibile l'allocazione |
| 034 | 2026-08-30 | §9.2.1 | Il disco esterno ha uno slot LUKS a passphrase oltre al keyfile, per essere apribile su un'altra macchina | Solo keyfile | Sì |
| 035 | 2026-08-30 | §5.2.2 | Modello di sincronizzazione **dichiarativo**: gerarchia per contenuto, sync come proprietà della cartella | Modello spaziale stile macOS con radice `~/cloud` | Sì |
| 036 | 2026-08-30 | §5.2.2 | `~/dev` è escluso dalla sincronizzazione file: git verso `mini` è già il meccanismo di sync del codice | Sync bidirezionale anche del codice | Sì |
| 037 | 2026-08-30 | §3 | Nomi host: `mini`, `razer`, `zotac`, minuscoli, senza prefisso | Prefisso `phi-`; nomi di ruolo | Sì, fino al Cancello B |
| 038 | 2026-08-30 | §4.4 | Anche `zotac` è cifrato: contiene code base di progetti privati e si riavvia di rado, quindi il costo è basso | Desktop non cifrato | Sì |
| 039 | 2026-08-30 | §5.2.2 | Struttura home: `doc` (sync, con `doc/vaults/<nome>`), `private` (mai sync, garanzia strutturale), `dev`, `media`, `tmp`. Nomi inglesi minuscoli | `~/cloud` contro `~/local`; `vault` come top-level | Sì, fino al primo sync configurato |
| 040 | 2026-08-30 | §5.2.2 | Ogni vault è un'unità di sincronizzazione indipendente, così `razer` e `zotac` possono averne insiemi diversi | Un'unica unità `doc` | Sì |
| 041 | 2026-08-30 | §5.2.2 | Nell'app note, contenuto e stato sono separati: il vault contiene solo file dell'utente, indice e stato di workspace stanno in `~/.local/state` | Stato dentro il vault | Costoso da invertire dopo |
| 042 | 2026-08-30 | §9.2.1 | Foto sull'SSD esterno da 1 TB, con backup offsite obbligatorio essendo su disco USB singolo | Foto sull'interno | Sì |
| 043 | 2026-08-30 | §5.2.2 | Utente personale: `flavio`, identico su tutte le macchine | Utenti diversi per host | Sì |
| 044 | 2026-08-30 | §11.1 | **Windows rimosso dal piano.** Verifica conclusa: le preoccupazioni erano infondate o mal attribuite, e il flag "Laggy" è una caratteristica del visore documentata anche su Windows | Dual boot; mantenimento temporaneo per test | Sì: reinstallabile su partizione (§11.1.1) |
| 045 | 2026-08-30 | §5.2.2 | Home a **modello spaziale**: directory XDG standard locali più `~/cloud` come unica radice sincronizzata | Modello dichiarativo; coppia `doc`/`private` | Sì, fino al primo sync configurato |
| 046 | 2026-08-30 | §9.2.0 | **Si parte da `zotac`**, non da `mini`: gli SSD esterni contengono dati che devono transitare dal desktop prima di essere riformattati | Partire dal server | No, è una dipendenza fisica |
| 047 | 2026-08-30 | §9.2.0.1 | Piano server immediato limitato a interno 512 più esterno 512. L'esterno 1 TB resta non assegnato | Assegnare tutti i dischi subito | Sì |
| 048 | 2026-08-30 | §3 | `zotac`: NVMe 512 per il sistema, NVMe 1 TB per la massa senza file di sistema, quindi riallocabile | Sistema sull'1 TB | Sì |
| 049 | 2026-08-30 | §5.3 | Provisioning con **script minimo più liste di pacchetti in testo semplice**. Niente Ansible, niente dotfile manager | Ansible; chezmoi; Nix | Sì |
| 050 | 2026-08-30 | §5.4 | **Nessun segreto nel repo.** Collocazione manuale documentata. L'unico requisito di recupero è la copia cartacea di passphrase LUKS e password del repository di backup | `age`/`sops` nel repo | Sì |
| 051 | 2026-08-30 | §4.3 | `zotac`: **partizione unica** con subvolumi Btrfs separati per root e home. Nessuna partizione fissa oltre ESP e root | Partizioni separate per root e home | Costoso da invertire |
| 052 | 2026-08-30 | §4.6 | `zotac`: **solo zram**, nessuna swap su disco. 32 GB di RAM, nessuna ibernazione. Un swapfile si aggiunge dopo se emerge un OOM | Swap su disco preventiva | Sì |
| 053 | 2026-08-30 | §7.2 | Accento **rosa pastello**; colori semantici **obbligatori** e desaturati; file token in stile **base16** per generare i config dell'intero sistema | Solo BW più accento; palette proprietaria | Sì |
| 054 | 2026-08-30 | §7.3 | Font: monospace più sans più font di soli simboli più fallback Noto mirato. Niente font patchati | Font patchato con Nerd Font | Sì |
| 055 | 2026-08-30 | §9.1 | Git: **bare repo su SSH**, nessun forge. `phi repo add` li crea | Forgejo; Soft Serve | Sì |
| 056 | 2026-08-30 | §9.2.0 | Configurazione dei servizi indipendente dall'assegnazione fisica dei dischi; archivi popolati in un secondo momento | Decidere ora tutta l'allocazione | Sì |
| 057 | 2026-08-30 | §9.2.0.1 | Server con due dischi fissi. L'esterno 1 TB è **portatile**: trasferimento più partizione di backup per tutte le macchine | Tre dischi fissi | Sì |
| 058 | 2026-08-30 | §13.4.1 | Backup attivati al primo dato reale, non durante la configurazione | Backup prima della configurazione | Sì |
| 059 | 2026-08-30 | §9.2.0.2 | Due alberi: `/srv/cloud` sincronizzato, `/srv/media` e `/srv/git` serviti. Le librerie non entrano mai nel sync file | Un unico albero sincronizzato | Sì |
| 060 | 2026-08-30 | §7 | Palette esatta, font e cifra stilistica rimandati a una **fase dedicata di design UI**. Restano fissati accento rosa pastello e struttura base16 | Deciderli ora | Sì |
| 061 | 2026-08-30 | §9.6.1 | Video VR serviti **direttamente al visore** via condivisione di rete, senza media server e senza coinvolgere il desktop | Video VR dentro il media server | Sì |
| 062 | 2026-08-30 | §9.6.2 | R2 unifica streaming da fonte e download in **una sola pipeline**: la riproduzione comincia prima che il fetch finisca | Due funzioni separate | Sì |
| 063 | 2026-08-30 | §9.6.2 | Il server **non transcodifica mai**. La compatibilità di formato si risolve all'ingestione; le ricodifiche avvengono su `zotac` con NVENC, una volta per file | Transcodifica al volo sul server | No, è un vincolo hardware |
| 064 | 2026-08-30 | §9.6 | Un media server esistente è preferibile a un catalogo costruito in `phi`, perché fornisce i client per TV e mobile che altrimenti andrebbero scritti | Catalogo interamente in `phi` | Sì |
| 065 | 2026-08-30 | §9.6.2 | Il modulo di risoluzione e fetch è una **libreria con due consumatori**, server e laptop, così il laptop funziona a server irraggiungibile | Modulo solo lato server | Sì |
| 066 | 2026-08-30 | §9.6.2.1 | Criteri di selezione del media server fissati ora, scelta rimandata. Il criterio dirimente è che sia **capace di transcodificare** anche se disattivata | Scegliere subito; scegliere qualcosa senza transcodifica | Sì |
| 067 | 2026-08-30 | §5.2.3 | Cinque convenzioni fissate prima della prima installazione: gruppo condiviso librerie, indirizzamento per nome, disciplina lista pacchetti, config a colori generate, snapshot attivi da subito | Deciderle in corsa | No: sono proprio quelle costose da retrofittare |
| 068 | 2026-08-30 | §4.6 | Kernel: `linux-lts` su `mini`, `linux` su `zotac` e `razer`, con l'altro come fallback. Modulo NVIDIA in DKMS | `linux-zen` | Sì |
| 069 | 2026-08-30 | §4.6.1 | Sistema in inglese con formati italiani; fuso `Europe/Rome`; tastiera ANSI | Sistema in italiano | Sì |
| 070 | 2026-08-30 | §4.2.3.1 | Snapshot limitati a configurazioni e stato dei servizi. Archivi esclusi **per struttura**, non per configurazione | Esclusioni tramite regole | Costoso da invertire |
| 071 | 2026-08-30 | §4.4.4.1 | `zotac`: un contenitore LUKS per disco, sblocco a cascata da una sola passphrase | Solo il disco di sistema cifrato | Sì |
| 072 | 2026-08-30 | §8.2.1 | La sessione desktop è **una shell unica**, non componenti indipendenti: barra, pannelli, lock screen, impostazioni e overlay condividono un solo framework | Sei programmi separati con toolkit diversi | Costoso da invertire |
| 073 | 2026-08-30 | §8.2.1 | La shell implementa essa stessa demone di notifiche e clipboard, ottenendo lo storico nel pannello senza componenti aggiuntivi | Demoni esterni più lettura dello storico | Sì |
| 074 | 2026-08-30 | §5.2.4 | Feature per categoria di macchina governate da **profili** (cosa si installa) più **rilevamento di capacità** (cosa si mostra). Criterio di smistamento: il peso | Config separate per host; tutto a runtime | Sì |
| 075 | 2026-08-30 | §8.2.4 | **Cattura a scorrimento esclusa deliberatamente e definitivamente.** Non va rivalutata | Implementazione con ricucitura manuale | Chiusa |
| 076 | 2026-08-30 | §4.6.1 | Sistema interamente in inglese, layout `us` con compose key. Italiano solo come dizionario ortografico | Formati italiani | Sì |
| 077 | 2026-08-30 | §8.2.3 | La configurazione monitor è **stato runtime** gestito dal pannello impostazioni, non un file statico. La barra è progettata per N monitor dal primo giorno | Monitor nel file di configurazione | Costoso da invertire per la barra |
| 078 | 2026-08-30 | §8.2.2 | Schede del pannello laterale e moduli della barra sono **definizioni dichiarative legate a verbi `phi`**, non componenti codificati. Aggiungere un pannello è un dato, non codice | Ogni pannello scritto a mano | Costoso da invertire |
| 079 | 2026-08-30 | §8.2.2 | Chat AI nel pannello rimandata; resta il requisito di estensibilità che la rende poi banale da aggiungere | Includerla nella prima versione | Sì |
| 080 | 2026-08-31 | Procedura | `zotac`: disco di massa su `/mnt/bulk`, con **bind mount** (non symlink) verso `~/videos`, `~/pictures`, `~/music` | Symlink; mount dentro la home | Sì |
| 081 | 2026-08-31 | Procedura | Moduli kernel NVIDIA **aperti** in DKMS: Ampere è supportata, i moduli diventano open source, si torna indietro con un comando | Moduli proprietari; varianti precompilate | Sì |
| 082 | 2026-08-31 | Procedura | Snapshot anche della home, cadenza giornaliera e retention breve, senza aggancio agli aggiornamenti pacchetti | Solo root; home con retention piena | Sì |
| 083 | 2026-08-31 | §3 | Correzione: il disco di massa di `zotac` è da **2 TB**, non 1 TB. CPU AMD, quindi microcodice `amd-ucode` e nessuna grafica integrata | — | No, è un fatto |
 
---
 
## 20. Registro pacchetti approvati
 
Tier da assegnare dopo verifica in fase di installazione.
 
| Pacchetto | Ambito | Host | Tier | Job |
|---|---|---|---|---|
| tailscale | Rete overlay | tutti | — | Accesso remoto (in uso) |
| wireguard | VPN | tutti | — | Ruolo da chiarire (`Q-13`) |
| hyprland | Compositor Wayland | desktop, laptop | — | Sessione grafica |
| neovim | Editor / IDE | tutti | — | Sostituisce VS Code |
| git | VCS | tutti | — | — |
| zsh | Shell | tutti | — | — |
| fzf | Fuzzy finder | tutti | — | — |
| fd | Ricerca file | tutti | — | — |
| bat | Visualizzatore file | tutti | — | — |
| zoxide | Navigazione directory | tutti | — | — |
| yazi | File manager TUI | tutti | — | — |
| navidrome | Streaming musicale | server | — | In uso |
| vlc | Media player | desktop, laptop | — | Vedi `Q-28` |
| steamcmd | Giochi | desktop | — | — |
| opencode | Agent AI da CLI | tutti | — | Provvisorio: `Q-40` |
| Unreal Engine | Game dev | desktop | Deroga | Requisito di dominio |
 
### 20.1 Strumenti base proposti per approvazione `[?]`
 
Probabilmente necessari, **non ancora approvati** (`Q-65`, da confermare singolarmente):
 
- Ricerca full-text nei file (complemento a `fd`; necessaria a Neovim e alla ricerca nelle note)
- Processore JSON da riga di comando (necessario agli script di §10)
- Sincronizzazione file incrementale (necessaria in §13)
- Server e client SSH (implicito, da dichiarare)
- Toolchain di compilazione (necessaria per i tier T1 e T4)
- Strumenti di build in chroot pulito (necessari per §2.3)
- Pagine di manuale e indice
- Sincronizzazione oraria di rete
- Diagnostica SMART (necessaria a §9.10 e §13)
- Utility di archivio e compressione
- Statistiche di sistema TUI (`Q-66`: quale? Erano in elenco senza software scelto)
---
 
## 21. Registro domande aperte
 
Ordinate per sezione. Le sette a maggiore impatto sono ripetute in §22.
 
| ID | Sez. | Domanda |
|---|---|---|
| Q-01 | §2.3 | Quale approccio AUR: build manuale in chroot con repo locale, o helper con revisione obbligatoria? |
| Q-02 | §3.1 | Modello, anno, CPU, RAM, disco interno e porte del Mac mini? |
| Q-03 | §12.1 | Android o iOS via AltStore? Il dispositivo è già vincolato? |
| Q-04 | §3.2 | Quale disco del desktop è NVMe e quale SATA? |
| Q-05 | §4.2 | **Conferma Btrfs** su tutte le macchine (orientamento in ADR 011) |
| Q-06 | §4.4 | ~~Sblocco del disco cifrato sul server~~ — **chiusa**, ADR 013 |
| Q-07 | §4.4 | Comportamento del laptop in sospensione? |
| Q-08 | §4.5 | Bootloader, e serve il boot da snapshot? |
| Q-09 | §5.1 | Monorepo o repo separati? |
| Q-10 | §5.2 | Meccanismo di deployment e templating? |
| Q-11 | §5.4 | Root of trust dei segreti e percorso di recupero? |
| Q-12 | §6.1 | Control plane Tailscale gestito da terzi: accettabile? |
| Q-13 | §6.2 | Job specifico di WireGuard distinto da Tailscale? |
| Q-14 | §6.3 | Tutto interno alla rete overlay, o qualcosa esposto? |
| Q-15 | §6.4 | Strategia TLS e nomi? |
| Q-16 | §7.2 | Colore d'accento? |
| Q-17 | §7.2 | Colori semantici: ammessi o distinzione per luminanza? |
| Q-18 | §7.3 | Requisiti tipografici e lingue da coprire? |
| Q-19 | §7.6 | Quante app di classe C (riavvio richiesto per il tema) sei disposto a tollerare? |
| Q-20 | §7.7 | Animazione di boot vera o logo statico con boot rapido? |
| Q-21 | §8.2 | Cosa intendi esattamente per "read mode"? |
| Q-22 | §8.2 | Confermi lo stack audio come necessario? |
| Q-23 | §8.3 | Quanto conta l'anteprima immagini nel terminale? |
| Q-24 | §8.4 | History shell condivisa fra macchine? |
| Q-25 | §8.5 | Serve un multiplexer? |
| Q-26 | §8.6 | Zen confermato nonostante la latenza sulle patch di sicurezza upstream? |
| Q-27 | §8.7 | Quali account mail e provider? |
| Q-28 | §8.10 | VLC confermato, o mpv come player primario? |
| Q-29 | §8.11 | Lingue e caso d'uso prevalente per traduzione e dizionario? |
| Q-30 | §8.14 | Quali formati office produrre e consumare? |
| Q-31 | §8.14 | Il corso richiederà analisi statistica? |
| Q-32 | §8.16 | Confermi il perimetro del pannello impostazioni? |
| Q-33 | §9 | Servizi come unit native o container rootless? |
| Q-34 | §9.1 | Solo remote git, o forge completa? |
| Q-35 | §9.3 | Confermi la separazione fra sync continuo e pinning esplicito? |
| Q-36 | §9.4 | Ti serve ricerca e riconoscimento foto, o basta archiviazione? |
| Q-37 | §9.5 | I podcast entrano nell'ecosistema come servizio a sé? |
| Q-38 | §9.5 | ~~Architettura musicale~~ — **chiusa**, ADR 007 |
| Q-39 | §9.7 | Cosa non deve **mai** raggiungere l'API del modello AI? |
| Q-40 | §9.7 | Confermi opencode o valutiamo alternative? |
| Q-41 | §9.10 | Livello di osservabilità richiesto? |
| Q-42 | §10.1 | Go provvisorio (ADR 016). Riconsiderare Rust **prima della seconda app TUI**, in funzione di `Q-44` |
| Q-43 | §10.2 | ~~Architettura di `phi`~~ — **chiusa**, ADR 017 |
| Q-44 | §10.3.4 | Esito della prova: i provider integrati del candidato si disattivano, e supporta sotto-viste con form? |
| Q-45 | §10.4 | Design dell'API interna? |
| Q-46 | §11.1 | ~~Sequenza abbandono Windows~~ — **chiusa**, ADR 008 |
| Q-47 | §11.1 | Quali giochi multiplayer con anti-cheat usi davvero? |
| Q-48 | §11.3 | Serve il client Steam grafico oltre a steamcmd? |
| Q-49 | §11.3 | Isolare i giochi dai dati sensibili? |
| Q-50 | §11.4 | ~~Percorso VR~~ — **chiusa**, ADR 009 |
| Q-51 | §12.2 | I limiti di una PWA sono accettabili, o serve app nativa? |
| Q-52 | §12.3 | Quali funzioni servono davvero da telefono, in ordine? |
| Q-53 | §12.4 | Push self-hosted per notifiche ecosistema e avvisi? |
| Q-54 | §13.4 | Destinazione offsite? |
| Q-55 | §14.3 | Gestirai materiale clinico o dati identificabili? |
| Q-56 | §15 | Clipboard condivisa: serve, dato il rischio? |
| Q-57 | §15 | Far suonare il telefono: frequenza d'uso reale? |
| Q-58 | §15 | Notifiche unificate: valore reale? |
| Q-59 | §16.2 | Versione di Neovim disponibile? |
| Q-60 | §16.3 | Quali funzioni VS Code usi ogni giorno? |
| Q-61 | §16.5 | Quale gestore di plugin? |
| Q-62 | §16.6 | Quali linguaggi effettivamente usati? |
| Q-63 | §16.9 | Debug C++/Unreal dentro Neovim o esterno? |
| Q-64 | §18 | Quali funzioni devono restare utilizzabili a server spento? |
| Q-65 | §20.1 | Approvi gli strumenti base proposti? |
| Q-66 | §20.1 | Quale strumento di statistiche di sistema TUI? |
| Q-67 | §4.2.3 | Riconferma del layout subvolumi prima dell'installazione (provvisorio, ADR 015) |
| Q-68 | §9.5 | Download locale: cache opaca del client o mirror di file reali? |
| Q-69 | §9.6.1 | Convenzione di naming per proiezione e stereoscopia dei video VR? |
| Q-70 | §9.6.1 | Il player VR gira sul visore in standalone o sul desktop? |
| Q-71 | §11.1 | Quanto spazio riservi alla partizione Windows? |
| Q-72 | §3.1.1 | Verificare che il riavvio automatico dopo blackout funzioni sul modello specifico, e se serve un adattatore video fittizio |
| Q-73 | §10.3.6 | Le voci del vault password entrano fra i risultati del launcher? È una decisione di sicurezza |
| Q-74 | §10.3.7 | Confermi l'euristica app contro comando (token singolo = app, token con argomenti = comando)? |
| Q-75 | §10.3.6 | Confermi i tipi di risultato mancanti proposti (finestre aperte, salto a progetto, azioni di sistema)? |
 
---
 
## 21bis. Stato di avanzamento
 
**Metrica grezza:** 23 decisioni chiuse (§19), 70 domande aperte (§21), 21 sezioni ancora interamente da scrivere.
 
Il numero di domande aperte non è allarmante di per sé: la maggior parte sono scelte di componente a basso rischio e reversibili. **Il rischio è concentrato in una decina.** Quello che conta è la distinzione fra ciò che blocca e ciò che no.
 
### 21bis.1 Cosa è deciso
 
L'**architettura** è in buona parte chiusa: policy di provenienza software, modello dei dati musicali, ruolo del server come sorgente di verità, forma e ambito di `phi`, ruolo del launcher come renderer, strategia di cifratura, separazione fetch/catalogazione, sequenza su Windows e VR, percorso VR gaming, criteri di ammissione dei verbi.
 
I **componenti** sono in gran parte aperti. È l'ordine giusto — decidere i componenti prima dell'architettura produce sistemi incoerenti — ma significa che il lavoro residuo è ampio nel conteggio e contenuto nel rischio.
 
### 21bis.2 Blocca l'installazione — da chiudere per primo
 
Nulla può iniziare finché questi non sono risolti, perché sono scelte del giorno zero.
 
| Cosa | Domanda | Stato |
|---|---|---|
| Caratterizzazione del Mac mini | `Q-02` | Aperta, richiede solo che tu guardi l'hardware |
| Quale disco desktop è NVMe | `Q-04` | Aperta |
| Ibernazione sul laptop → dimensione swap | `Q-07` | Aperta |
| Spazio riservato a Windows | `Q-71` | Aperta |
| Conferma Btrfs | `Q-05` | Provvisoria (ADR 011) |
| Conferma layout subvolumi | `Q-67` | Provvisoria (ADR 015) |
| Bootloader | `Q-08` | Aperta |
| Metodo AUR e build in chroot | `Q-01` | Aperta |
| Root of trust dei segreti | `Q-11` | Aperta |
| Meccanismo di deployment e templating | `Q-10` | Aperta |
| **Procedura di installazione** | §4.1 | **Da scrivere** |
| **Layout partizioni** | §4.3 | **Da scrivere** |
| **Provisioning da zero** | §5.3 | **Da scrivere** |
 
### 21bis.3 Blocca i servizi server
 
| Cosa | Domanda |
|---|---|
| Unit native o container — sblocca tutto §9 | `Q-33` |
| Perimetro di esposizione e TLS | `Q-14`, `Q-15` |
| Modello di sincronizzazione file | `Q-29`, `Q-35` |
| Forma del git remote | `Q-34` |
| Foto: archiviazione o indicizzazione | `Q-36` |
| Player VR e protocollo di accesso | `Q-70`, `Q-69` |
 
### 21bis.4 Blocca l'ambiente desktop
 
| Cosa | Domanda |
|---|---|
| Colore d'accento e colori semantici | `Q-16`, `Q-17` |
| Tipografia | `Q-18` |
| Terminale, in funzione delle anteprime immagini | `Q-23` |
| I ~14 componenti di sessione di §8.2 | — |
| **Propagazione del tema per componente** | §7.4 **da scrivere** |
| **Linee guida di interfaccia** | §7.5 **da scrivere** |
 
### 21bis.5 Capitoli mai affrontati
 
Sezioni interamente vuote, elencate perché il vuoto è esso stesso un rischio:
 
| Sezione | Perché conta |
|---|---|
| **§14 Sicurezza** — modello di minaccia, baseline per host, igiene credenziali | Quattro sottosezioni su quattro vuote, su un progetto il cui invariante `I-08` è la sensibilità dei dati. Il modello di minaccia va scritto **prima** delle contromisure, e diverse decisioni già prese lo assumono implicitamente |
| **§16 Neovim** — 7 sottosezioni su 11 vuote | È un deliverable richiesto esplicitamente, ed è attualmente un guscio. Dipende però da `Q-59` e `Q-62`, quindi il vuoto è in parte legittimo |
| **§13.5–13.6 Pianificazione e verifica backup** | La roadmap li colloca prima dei dati reali. Un backup mai ripristinato non è un backup |
| §4.7 Hardening delle unit | Assunto da ADR 013 (dipendenze di mount): non è opzionale |
| §6.5 Baseline SSH | Unica via di accesso al server dopo ADR 013 |
| §8.17 Flusso di aggiornamento | Presupposto da `phi update` |
| §10.8 Componenti desktop custom | Subordinato a §10.1 e §7 |
 
### 21bis.6 Aperto ma non blocca
 
Mail, calendario, scrittura accademica e bibliografia, assistente AI (cinque sotto-problemi, nessuno deciso), mobile (a partire da `Q-03`), handoff, traduttore, meteo, pannello impostazioni, destinazione offsite dei backup, osservabilità.
 
Sono tutte scelte rimandabili senza costo, purché le fondamenta siano corrette.
 
---
 
## 22. Prossime decisioni, in ordine di rilevanza
 
**Chiuse finora:** `Q-38` (ADR 007), `Q-46` (ADR 008), `Q-50` (ADR 009), `Q-06` (ADR 013), `Q-43` (ADR 017). Provvisorie: `Q-05` (ADR 011), `Q-42` (ADR 016), `Q-67` (ADR 015).
 
1. **`Q-02` — caratterizzazione del Mac mini.** Sblocca §4.4, §9.4, §9.6 e §9.6.1. È l'unica domanda a cui non posso rispondere per te, e da cui ora dipendono anche i vincoli di banda della libreria VR.
2. **`Q-33` — servizi nativi o container.** Sblocca l'intero §9 e chiude la parte server di `Q-67`.
3. **`Q-16` — colore d'accento.** Sblocca ogni configurazione visiva.
5. **`Q-04` — quale disco del desktop è NVMe.** Chiude la parte desktop di `Q-67`.
6. **`Q-70` — dove gira il player VR.** Determina il percorso dei dati e il protocollo di accesso alla libreria VR.
7. **`Q-07` — comportamento del laptop in sospensione.** Determina il dimensionamento dello swap, che è una scelta da installazione.
---
 
## 23. Cancelli di avanzamento
 
Non un elenco di cose da fare — quello è §17 — ma i tre punti in cui il progetto **non può proseguire** finché non si chiude un insieme preciso.
 
### Cancello A — prima di installare la prima macchina
 
| Voce | Stato |
|---|---|
| `Q-02` Caratterizzazione Mac mini | Aperta, dipende da te |
| `Q-04` Quale disco desktop è NVMe | Aperta |
| `Q-05` Conferma Btrfs | Provvisoria |
| `Q-67` Layout subvolumi | Provvisoria |
| `Q-07` Ibernazione laptop → dimensiona lo swap | Aperta |
| `Q-08` Bootloader e boot da snapshot | Aperta |
| `Q-71` Dimensione partizione Windows | Aperta |
| §4.1 Procedura di installazione | Da scrivere |
| §4.3 Layout partizioni | Da scrivere |
 
### Cancello B — prima di mettere dati reali sul sistema
 
| Voce | Stato |
|---|---|
| `Q-11` Root of trust dei segreti | Aperta |
| §13.7 Chiavi di backup e recupero offline | Da scrivere |
| `Q-10` Meccanismo di deployment | Aperta |
| §13.2–13.4 Strumenti di snapshot, backup, replica | Aperte |
| `Q-54` Destinazione offsite | Aperta |
| §13.6 Verifica e prova di ripristino | Da scrivere |
| §14.1 Modello di minaccia | Da scrivere |
| `Q-55` Materiale clinico sì/no → riapre §4.4 | Aperta |
 
### Cancello C — prima di scrivere la configurazione finale di qualsiasi app
 
| Voce | Stato |
|---|---|
| `Q-16` Colore d'accento | Aperta |
| `Q-17` Colori semantici | Aperta |
| `Q-18` Tipografia | Aperta |
| §7.4 Propagazione del tema per componente | Da scrivere |
| §7.5 Linee guida di interfaccia | Da scrivere |
 
Finché il Cancello C è chiuso, ogni config scritta va riscritta. È il motivo per cui §7 è marcato bloccante per §8, §10 e §12.
 
### Domini mai aperti
 
| Dominio | Note |
|---|---|
| §16 Neovim | 7 sottosezioni su 11 vuote. È la sezione richiesta esplicitamente come dedicata ed è la meno sviluppata |
| §14 Sicurezza | 3 su 4 vuote, incluso il modello di minaccia che dovrebbe precedere le contromisure |
| §10.4 API interna | Mai progettata. Blocca pinning, musica, media e mobile |
| §12 Mobile | Interamente aperto, bloccato su `Q-03` |
| §8 Applicazioni | Mail, calendario, browser, note, office, galleria, traduttore, terminale, prompt, multiplexer: tutte TBD |
| §9 Servizi | Git, sync file, foto, media, AI, password manager, osservabilità: tutte TBD |