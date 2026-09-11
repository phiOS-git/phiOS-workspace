# phiOS — Agente AI

**Versione:** 1.1 • **Stato:** specifica
**Ultimo aggiornamento:** 2026-09-06
**Estende:** `phios-architettura.md` §9.7 • **Vincolato da:** `I-01`–`I-11`, §2.2, §10.2, §8.2
**Macchine:** `zotac`, `razer`

---

## 1. Scopo e perimetro

### 1.1 Oggetto

Un assistente di sistema conversazionale (**A1**) e un agente di lavoro autonomo sul codice (**A2**), separati per capacità e per contenimento, accessibili da tre superfici: pannello della shell, riga di comando inline, superficie remota.

### 1.2 Fuori perimetro

Il pannello grafico è un client esterno. Questo documento ne definisce il contratto (§9) e il perimetro funzionale (§10.1); la realizzazione appartiene alla shell desktop.

Fuori perimetro anche: collocazione nel repository dotfiles, perimetro di backup, framework grafico, e la configurazione di `mini`, che riceverà il pacchetto del runtime per uso inline su macchina headless senza partecipare a questa architettura.

### 1.3 Job to be done

| # | Job | Agente |
|---|---|---|
| J1 | Conversazione: domande, ricerche, ragionamento su un contesto di studio | A1 |
| J2 | Produzione di file di output di cui l'utente dispone liberamente | A1 |
| J3 | Consultazione di un archivio di appunti personali | A1, sola lettura |
| J4 | Esecuzione di verbi `phi` | A1 |
| J5 | Lavoro autonomo su progetti di codice | A2 |
| J6 | Contatto remoto con sessioni di lavoro attive | A2 |
| J7 | Domanda rapida inline nel terminale | A1 |
| J8 | Progetti: raggruppamento conversazioni, materiali, istruzioni proprie | A1 |

Esclusi: completamento inline nell'editor · osservazione della sessione terminale · osservazione e controllo della sessione grafica · contatto remoto con A1 · lavoro simultaneo di due macchine sullo stesso progetto · attività pianificate non presidiate · contenuti non testuali · sintesi vocale · nodo di calcolo locale.

### 1.4 Principio ordinatore

Default-deny su filesystem, rete, strumenti e scrittura della memoria.

**Corollario:** dove un vincolo può essere imposto dal filesystem invece che dall'interfaccia, si impone dal filesystem.

### 1.5 Anti-obiettivi

Nessun controllo del desktop · nessuna shell per A1 · nessuna attività non presidiata · nessuna installazione autonoma di skill o strumenti · nessuna scrittura fuori dai percorsi concessi · nessun accesso a socket di sessione · nessun accesso diretto alle directory di origine dei materiali · nessun ascolto fuori dalla rete overlay.

---

## 2. Aspettative

### 2.1 Cosa determina la qualità

La qualità del ragionamento, della ricerca e del supporto allo studio viene **dal modello**, non dal motore. Il motore è provider-agnostico: sulla dimensione che conta di più è neutro. Il comportamento viene dal prompt di sistema, che per le personalità è interamente sostituibile.

### 2.2 Attriti previsti

| Attrito | Natura |
|---|---|
| Disposizione all'azione | Il ciclo del motore è costruito per *fare*: leggere, agire, riferire. Il supporto allo studio richiede spesso di ragionare insieme. Il prompt della personalità sposta la disposizione, non la elimina |
| Residuo del prompt di base | Il motore inietta una propria intelaiatura oltre al prompt della personalità |
| Documenti | Il supporto nativo alla lettura dei PDF è da accertare; in mancanza diventa un verbo di §7.1 |
| Affordance conversazionali | Ramificare, rigenerare, modificare un messaggio precedente sono funzioni da client di chat; il pannello espone ciò che il motore offre |
| Costo in contesto | Ogni turno porta con sé gli schemi degli strumenti |

### 2.3 Asimmetria di sostituibilità

Il motore di A2 non è sostituibile: un agente di coding non si riscrive.

Il motore di A1 lo è: un assistente senza shell e con cinque strumenti è un ciclo di poche centinaia di righe contro le API dei provider. Ciò che si evita di riscrivere è il livello provider, l'archiviazione delle sessioni, lo streaming e il protocollo di chiamata agli strumenti — cose mutevoli, non difficili.

Questa asimmetria è la ragione sostanziale della separazione di §9: **se il motore di A1 si rivelasse inadatto, si sostituisce senza toccare il pannello.**

---

## 3. Architettura

### 3.1 Due agenti

| | **A1 — assistente** | **A2 — operaio** |
|---|---|---|
| Scopo | conversazione, ricerca, studio, output testuali | lavoro autonomo sul codice |
| Shell | **no** | **sì** |
| Scrittura | aree designate del progetto attivo | radice dei progetti di codice |
| Rete | libera, con approvazione | lista bianca |
| Memoria | propone, non scrive | nessuna |
| Attivazione | servizio, ricostruito al cambio progetto | su richiesta |
| Recupero da errore | cancellare un file | `git` |

Il confine fra A1 e A2 **è** il confine di sicurezza. Nessun percorso, strumento o credenziale è condiviso.

### 3.2 Un binario, due istanze

I due agenti differiscono per configurazione, non per capacità. Runtime: linea stabile del repository ufficiale (T0). La linea successiva è in beta e dichiara che le interfacce di server e plugin possono cambiare; il pannello è un client proprio di quelle interfacce.

Misure di compatibilità in avanti: permessi raccolti in pochi file identificati · livello client sottile ed esplicito · nessuna dipendenza da comportamenti non documentati.

### 3.3 Separazione delle istanze

Alberi XDG distinti (`XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`), da cui discendono credenziali, cronologia e configurazione separate.

---

## 4. Contenimento

### 4.1 Meccanismo

`bubblewrap` (T0), namespace di mount costruito **partendo dal vuoto**. Un percorso non montato non esiste per il processo, qualunque comando si usi.

Alternativa scartata: montare tutto in sola lettura aprendo buchi in scrittura. È il predefinito degli strumenti commerciali, è più comoda, e non protegge i segreti.

Costo operativo previsto: assestamento della lista dei mount nelle prime sessioni.

### 4.2 Base comune, sola lettura

`/usr` · symlink `/bin` `/lib` `/lib64` `/sbin` · `/etc/resolv.conf` `/etc/hosts` `/etc/nsswitch.conf` · `/etc/ssl/certs` `/etc/ca-certificates` · `/etc/passwd` `/etc/group` · `/etc/localtime`

Pseudo-filesystem creati e non ereditati: `--proc /proc` · `--dev /dev` minimale · `--tmpfs /tmp` · `--tmpfs /run`

### 4.3 Perimetro di A1

Ricalcolato per progetto attivo. Nessun altro progetto è visibile.

| Percorso | Modo |
|---|---|
| `output/` e `proposte/` del progetto attivo | scrittura |
| resto del progetto attivo | sola lettura |
| `personalita/` | sola lettura |
| albero XDG di A1 | scrittura |
| archivio appunti | sola lettura |

Il cambio di progetto ricostruisce il contenimento e riavvia il servizio; il client copre l'attesa con uno stato di caricamento.

### 4.4 Perimetro di A2

Radice dei progetti di codice in scrittura · albero XDG di A2 in scrittura · cache delle toolchain dedicate ad A2 in scrittura.

Identità git fornita via variabili d'ambiente, non montando la configurazione git dell'utente, che può contenere gestori di credenziali e riscritture di URL.

**A2 non pubblica né preleva da remoti.** Modifica e committa in locale; la pubblicazione è dell'utente.

### 4.5 Mai montati

Resto di `$HOME` e `/home` · `/var` `/srv` `/opt` `/mnt` `/boot` `/efi` · `/etc` fuori dalla lista bianca · chiavi SSH, portachiavi GPG, archivio del gestore password, profili del browser, archivio locale della posta · **socket di sessione**: `$XDG_RUNTIME_DIR`, Wayland, D-Bus, PipeWire, agente SSH.

L'agente SSH permette di **usare** una chiave senza leggerla: escludere il file e lasciare il socket non protegge nulla.

### 4.6 Namespace e ambiente

`--unshare-pid --unshare-ipc --unshare-uts --unshare-cgroup` · `--die-with-parent` · `--new-session` (mitiga l'iniezione via `TIOCSTI`) · `--clearenv` seguito da `--setenv` esplicito.

L'ambiente ripulito è parte del confine: senza, entrano nel contenimento il socket dell'agente SSH e ogni credenziale presente nell'ambiente della shell.

### 4.7 Indisponibilità

Se il contenimento non parte, l'avvio fallisce. Il client segnala il servizio non disponibile. Nessuna esecuzione fuori dal contenimento in nessuna circostanza.

---

## 5. Rete

### 5.1 A2 — lista bianca

`--unshare-net` rimuove la rete dal contenimento; un ponte su socket Unix realizzato con `socat` porta il traffico a un proxy esterno; le variabili di proxy puntano lì.

Il confine è il namespace, non la variabile: un processo che ignora o cancella le variabili resta **senza rete**, non con rete libera.

Composizione della lista bianca: l'indirizzo del servizio di §6.2 e i registri dei pacchetti effettivamente usati dai progetti presenti. Nessun altro dominio. La lista si estende per aggiunta esplicita, mai per comodità.

### 5.2 A1 — approvazione a livello di agente

Per A1 non esiste una lista statica: il suo compito è recuperare pagine trovate dalla ricerca, e l'URL di un attaccante è indistinguibile da qualunque altro. Il controllo necessario è interattivo e progressivo, e un proxy non sa chiedere: sa solo consentire o negare secondo una regola fissa.

Il recupero pagina è quindi impostato su richiesta di approvazione. Vedi §12.1 per il limite noto.

### 5.3 Superficie remota

L'ascolto avviene esclusivamente sull'indirizzo della rete overlay, mai su ogni interfaccia.

La raggiungibilità dentro la rete overlay è governata dalla politica di accesso della rete stessa, che segue lo stesso principio di §1.4: **negazione predefinita, con permesso esplicito ai soli dispositivi personali dell'utente verso quella porta.** Un dispositivo aggiunto in seguito non ottiene accesso per il fatto di essere entrato nella rete. Non sono ammessi nodi condivisi da terzi né instradamenti di sottorete o uscita verso quella porta.

Non si aggiunge un secondo strato di cifratura: la rete overlay cifra già il traffico.

---

## 6. Credenziali

### 6.1 Natura del problema

L'agente ha bisogno della chiave per funzionare, quindi dev'essere raggiungibile, quindi un agente manipolato può farla uscire. Il problema non appartiene al motore scelto: vale per qualunque agente.

Ma "raggiungibile" non implica "presente nel processo dell'agente".

| Livello | Collocazione | Esito in caso di compromissione |
|---|---|---|
| 1 | file leggibile dall'agente | chiave sottratta, utilizzabile altrove e in seguito |
| 2 | variabile d'ambiente | via banale chiusa, altre residue |
| 3 | **mai nel processo dell'agente** | non sottraibile; resta l'abuso in loco |

### 6.2 Intermediazione della chiamata al provider

Si adotta il livello 3. L'agente non parla al provider: parla in chiaro sul loopback a un servizio locale, fuori dal contenimento, che detiene la chiave e la aggiunge alla richiesta in uscita. Dentro il contenimento non esiste nessuna credenziale.

Praticabile perché il motore consente provider con indirizzo di base personalizzato. Collocazione: verbo di `phi`, non binario separato.

| | |
|---|---|
| Ricaduta positiva | è il punto naturale dove misurare il consumo e applicare un limite locale di frequenza |
| Vincolo realizzativo | deve trasferire lo streaming senza bufferizzare, altrimenti la risposta incrementale si perde |
| Modo di fallire | se il servizio è fermo, nessun agente funziona. Coerente con §4.7 |

### 6.3 Misure complementari

Una chiave per strumento, in alberi XDG distinti · tetto di spesa impostato presso il provider, che è l'unica misura a limitare il **danno** invece della probabilità · procedura di revoca scritta in anticipo · numero di provider attivi ridotto al minimo, poiché ogni chiave in più è un tetto in più da impostare e una revoca in più da ricordare.

### 6.4 Rischio residuo

Un agente compromesso può usare la via verso il provider finché è compromesso, consumando budget. Non può sottrarre la chiave, quindi non può usarla altrove né in seguito. Il tetto limita la finestra.

---

## 7. Strumenti

### 7.1 Insieme di A1

| # | Strumento | Origine | Cresce |
|---|---|---|---|
| 1 | ricerca web | nativo | no |
| 2 | recupero pagina | nativo, con approvazione | no |
| 3 | lettura file | nativo, confinato dai mount | no |
| 4 | scrittura file | nativo, confinato ai mount di scrittura | no |
| 5 | server MCP `phi` | proprio | **sì — unico punto di crescita** |

Ogni capacità futura entra come verbo nello strumento 5, senza modificare l'architettura. Alla prima versione il server espone un solo verbo di sola lettura e senza argomenti, sufficiente a dimostrare il collegamento.

### 7.2 Insieme di A2

Configurazione predefinita del motore. Il contenimento di §4.4 e §5.1 è il confine; ridurre anche gli strumenti aggiungerebbe attrito senza aggiungere garanzie.

---

## 8. Modello dei dati

### 8.1 Due assi ortogonali

| Asse | Cos'è | Stato |
|---|---|---|
| **Personalità** | un agente del motore: prompt di sistema, modello, permessi | no |
| **Progetto** | una directory: istruzioni, materiali, memoria, archivio, output | sì |

Una conversazione è la coppia *(personalità, progetto)*. La stessa personalità serve più progetti; lo stesso progetto si affronta con personalità diverse.

Il prompt di sistema della personalità sostituisce quello predefinito del motore. È lì che si definisce la disposizione conversazionale discussa in §2.2.

### 8.2 Struttura su disco

Radice sotto la directory dati XDG dell'utente.

```
<radice>/
  personalita/
    <nome>.md            prompt di sistema — scrive solo l'utente
  progetti/
    <nome>/
      progetto.md        istruzioni e personalità predefinita
      materiali/         file copiati e statici          [agente: sola lettura]
      archivio/          riassunti delle conversazioni   [agente: sola lettura]
      memoria.md         fatti durevoli                  [agente: sola lettura]
      proposte/          proposte di memoria             [agente: scrittura]
      output/            file prodotti                   [agente: scrittura]
```

I materiali sono copie statiche: l'agente non riceve mai accesso alla directory di origine.

### 8.3 Stato iniziale

Minimo, per consentire un'installazione pulita su una macchina nuova: due personalità, una generale e una tecnica, che dimostrano i due assi. Nessun progetto precaricato: si creano all'uso.

### 8.4 Conferma della memoria imposta dai mount

`memoria.md` è montato in sola lettura dentro il contenimento; `proposte/` in scrittura. Il client, che gira fuori dal contenimento, è l'unico che può trasferire una proposta approvata.

La conferma non è quindi una convenzione dell'interfaccia ma una proprietà del filesystem: **l'agente non può scrivere la propria memoria, nemmeno se manipolato.**

### 8.5 Memoria e archivio

| | `memoria.md` | `archivio/` |
|---|---|---|
| Contenuto | pochi fatti durevoli | riassunti delle conversazioni chiuse |
| Come entra nel contesto | **sempre**, come istruzione | **su richiesta**, come risultato di lettura |
| Chi scrive | il client, su conferma | il client, alla chiusura |
| Richiede conferma | **sì** | no |

Un riassunto arriva come dato dentro un risultato di strumento, non come istruzione di sistema: non è un canale di persistenza e non richiede approvazione. Ne consegue anche che le conferme restano poche.

L'archivio è composto da file markdown ordinari, trovabili con gli strumenti di lettura nativi. Nessuna dipendenza dallo schema interno del database delle sessioni, che è privato.

### 8.6 Innesco e conferma della memoria

Notifica non bloccante in tempo reale, cumulabile. Le proposte in attesa si revisionano in un resoconto di fine giornata.

La conferma mostra il **testo letterale** che verrà scritto, come differenza rispetto al file esistente. Mai un riassunto: sarebbe prodotto dallo stesso modello che potrebbe essere stato manipolato.

Solo A1. Escluso da A2, dove ciò che l'agente apprende ha collocazione migliore nei file del repository — che git rende già approvabili, versionati e reversibili — e dove un'istruzione persistita sarebbe molto più pericolosa, perché A2 ha una shell.

---

## 9. Contratto motore ↔ client

### 9.1 Cosa fornisce il motore

Elenco e creazione di conversazioni · invio di un messaggio · flusso di eventi in tempo reale con testo incrementale, chiamate a strumento ed esiti · richieste di approvazione e relativa risposta · selezione di agente e directory di lavoro per conversazione · interruzione di una conversazione in corso.

### 9.2 Cosa fornisce il client

Rendering · gestione dei file di progetto e di personalità sul filesystem · trasferimento delle proposte di memoria approvate · produzione e scrittura dei riassunti di chiusura · notifiche · commutazione del progetto attivo e attesa della ricostruzione del contenimento.

### 9.3 Regole del collegamento

Il livello client è sottile ed esplicito, concentrato in un punto identificabile, e non contiene logica di prodotto.

Il client non assume nulla sul formato interno di archiviazione del motore. Ogni dato che deve sopravvivere a un cambio di motore vive nei file di §8.2.

Da queste due regole discende §2.3.

---

## 10. Superfici

### 10.1 Pannello

Conversazione testuale in streaming · elenco conversazioni raggruppate per progetto · creazione e modifica di personalità e progetti · copia di file nei materiali · allegato di un file a una singola conversazione · elenco e apertura degli output · approvazione degli strumenti · notifica non bloccante di proposta di memoria · resoconto di fine giornata · riassunto e archiviazione alla chiusura · stato di caricamento al cambio progetto · segnalazione di servizio non disponibile.

Evocazione da scorciatoia globale, superficie residente, connessione persistente al flusso di eventi.

**La ricerca nella cronologia non fa parte della prima versione.** L'archivio di §8.5 è già la superficie di ricerca: sono file markdown dentro il progetto, trovabili dagli strumenti dell'agente e dagli strumenti di sistema. Una ricerca dedicata nel pannello sarebbe un secondo meccanismo per un problema già coperto, e dovrebbe interrogare il database privato del motore, cosa che §9.3 vieta. Se all'uso l'archivio si rivelasse insufficiente, la ricerca entra come verbo `phi` sui file dell'archivio, non come funzione del pannello sul motore.

**Rapporto con ADR 078.** Nessuna deroga è necessaria. Il *tipo* di scheda conversazionale è codice scritto una volta, come ogni altro tipo di scheda; l'*istanza* resta una definizione dichiarative che indica il tipo e l'endpoint. La regola di ADR 078 riguarda le istanze e resta soddisfatta.

### 10.2 Riga di comando inline

Wrapper sottile collegato al servizio di A1 già attivo, senza costo di avvio a freddo. La sessione è effimera: esclusa dall'elenco del pannello e dalla memoria.

### 10.3 Superficie remota

Solo A2. Il server è il modo normale di eseguire A2, ma **l'ascolto sull'indirizzo della rete overlay si attiva solo all'avvio di una sessione dichiarata remota**; le sessioni locali restano su loopback. La superficie esiste quindi solo nei momenti in cui serve.

Autenticazione attiva. La password è caricata dal gestore di servizi come credenziale, da un file fuori dal repository con permessi ristretti, e trasferita dentro il contenimento con l'impostazione esplicita richiesta da §4.6. Mai in chiaro nei dotfiles.

---

## 11. Indurimento

| # | Misura | Dove |
|---|---|---|
| 1 | Limiti di memoria, processi e quota di CPU | unità del gestore di servizi |
| 2 | Nessuna elevazione di privilegi, temporanei privati, protezione dei parametri del kernel | unità del gestore di servizi |
| 3 | Guardia contro la ripetizione della stessa chiamata a strumento | configurazione del motore |
| 4 | Divieto di lettura sull'albero XDG dell'agente stesso | configurazione del motore |
| 5 | Modalità ad approvazione sospesa disponibile ma disattivata di default | configurazione del motore |
| 6 | Registro delle azioni scritto fuori dal contenimento | client |

---

## 12. Limiti noti

### 12.1 Controllo sul recupero pagina

Il permesso sul recupero pagina accetta solo un valore globale; la sintassi per pattern, disponibile per gli altri strumenti, non è supportata sugli URL. Il controllo per dominio descritto in §5.2 non è ottenibile in configurazione.

Scelta della prima versione: permesso a richiesta, nessun codice proprio.

Rischio residuo accettato: dal perimetro di A1 potrebbero uscire appunti di studio, che per loro natura non contengono materiale problematico, e i materiali di un solo progetto. La credenziale non è esposta grazie a §6.2.

Vie d'uscita, entrambe successive alla prima versione:

| Via | Costo | Dipendenza |
|---|---|---|
| Modello di permessi della linea successiva del motore, dove l'URL è la risorsa della regola | nullo in codice | attende la stabilizzazione a monte |
| Recupero pagina come verbo del server MCP `phi`, con lista dei domini e approvazione in codice proprio | recupero e conversione della pagina | nessuna |

La seconda è coerente con la preferenza per il codice proprio rispetto alla dipendenza esterna, e con §7.1 dove il server `phi` è già il punto di crescita previsto.

### 12.2 Esclusione di singoli file dall'archivio appunti

Non prevista nella prima versione. L'archivio è montato per intero in sola lettura. Diventa necessaria solo se vi entrasse materiale che non deve raggiungere un provider esterno.

### 12.3 Cronologia non condivisa fra macchine

Ogni macchina ha la propria. Il contatto remoto individuale con ciascuna macchina è sufficiente ai job di §1.3.

---

## 13. Dipendenze da `phi`

Nessuna richiede l'API interna né una grammatica matura: richiedono che `phi` esista come binario con sottocomandi.

| Verbo | Perché è necessario | Milestone |
|---|---|---|
| server MCP | è lo strumento 5 di §7.1; senza, J4 non esiste | 0 |
| domanda inline | è J7 | 0 |
| commutazione del progetto attivo | il contenimento è per progetto: serve un comando che riscriva il perimetro e riavvii il servizio | 0 |
| intermediazione del provider | §6.2 | 0 |
| creazione di personalità e progetti da modello | manuale in milestone 0, dal pannello in milestone 1 | 1 |

Ogni altro verbo cresce con `phi` e non condiziona questo progetto.

---

## 14. Realizzazione

### 14.1 Milestone 0 — senza pannello

Agenti configurati · contenimento e sua prova · intermediazione della credenziale · riga di comando inline · superficie remota.

Tutto verificabile da terminale. Contenimento e configurazione sono così validati prima che inizi il lavoro grande, e il sistema è già utile. Conferma della memoria, archiviazione a chiusura e gestione di personalità e progetti restano manuali in questa fase.

### 14.2 Milestone 1 — pannello

Il resto di §10.1.

### 14.3 Transizione dall'uso attuale

L'uso corrente del motore avviene senza contenimento e con configurazione propria. Il passaggio ad A2 contenuto toglie l'accesso alle chiavi SSH e la pubblicazione su remoto. Il passaggio avviene alla fine della milestone 0, quando la prova di §15 è superata, e non prima.

### 14.4 Componenti

| # | Componente | Milestone | Dimensione |
|---|---|---|---|
| 1 | Script di avvio contenuto, uno per agente, più le liste di percorsi | 0 | piccola |
| 2 | Unità di servizio: A1 con ricostruzione al cambio progetto, A2 remoto | 0 | piccola-media |
| 3 | Intermediazione della chiamata al provider | 0 | piccola-media |
| 4 | Configurazione del proxy d'uscita di A2 | 0 | minima |
| 5 | Domanda inline | 0 | minima |
| 6 | Server MCP `phi` | 0, poi cresce | media |
| 7 | Creazione di personalità e progetti da modello | 0 manuale, 1 dal pannello | piccola |
| 8 | Livello client verso il motore | 1 | piccola-media |
| 9 | Riassunto e archiviazione a chiusura | 1 | piccola |
| 10 | Trasferimento delle proposte approvate | 1 | minima |

Il pannello non compare: appartiene alla shell desktop (§1.2).

---

## 15. Piano di verifica

Nessuna sezione è considerata chiusa senza la prova corrispondente eseguita e registrata. Le prove da V-01 a V-04 sono bloccanti: nessuna capacità di scrittura si abilita prima del loro esito positivo.

| # | Prova | Esito atteso | Se fallisce |
|---|---|---|---|
| V-01 | Lettura di una chiave SSH, del portachiavi, dell'archivio del gestore password e dell'archivio posta da dentro il contenimento | file non trovato in ogni caso | il mount è errato: correggere prima di proseguire |
| V-02 | Presenza di credenziali nell'ambiente del processo contenuto | ambiente privo di segreti e del socket dell'agente SSH | l'ambiente non è stato ripulito |
| V-03 | Uscita di rete da A2 verso un dominio fuori dalla lista bianca, e con variabili di proxy cancellate | negata in entrambi i casi | il namespace di rete non è stato rimosso |
| V-04 | Avvio del servizio con il meccanismo di contenimento reso indisponibile | avvio fallito, nessun processo attivo | correggere: il degrado non è ammesso |
| V-05 | Scrittura diretta su `memoria.md` da dentro il contenimento | negata | `memoria.md` è montato in scrittura per errore |
| V-06 | Scrittura fuori da `output/` e `proposte/` | negata | i mount di A1 sono troppo larghi |
| V-07 | Lettura dell'albero XDG dell'agente da parte dell'agente stesso | negata | rivedere la regola di §11 punto 4 |
| V-08 | Presenza della chiave del provider dentro il contenimento | assente | §6.2 non è attiva |
| V-09 | Streaming attraverso il servizio di intermediazione | risposta incrementale, senza attesa della fine | il servizio bufferizza |
| V-10 | Composizione del prompt: personalità più istruzioni di progetto | entrambe presenti nel contesto | rivedere la collocazione delle istruzioni |
| V-11 | Residuo del prompt di base del motore | disposizione conversazionale coerente con la personalità | rafforzare il prompt della personalità; se insufficiente, valutare §2.3 |
| V-12 | Lettura di un PDF dall'archivio appunti | contenuto leggibile | aggiungere un verbo di conversione al server di §7.1 |
| V-13 | Approvazione del recupero pagina: presenza di un'opzione persistente per dominio nella sessione | attrito accettabile all'uso quotidiano | misurare l'attrito per una settimana, poi valutare le vie di §12.1 |
| V-14 | Riassunto alla chiusura di una conversazione tramite l'aggancio a sessione inattiva | riassunto prodotto e scritto in `archivio/` | il client produce il riassunto su richiesta esplicita |
| V-15 | Esclusione della sessione inline dall'elenco del pannello | assente dall'elenco | filtro applicato lato client |
| V-16 | Tempo di ricostruzione del contenimento al cambio progetto | compatibile con l'uso interattivo | rivedere il perimetro per progetto attivo di §4.3 |
| V-17 | Ascolto della superficie remota su interfacce diverse da quella overlay | assente | correggere l'indirizzo di ascolto |
| V-18 | Accesso alla superficie remota senza credenziale | negato | attivare l'autenticazione |

---

## 16. Registro delle decisioni

Continuazione di `phios-architettura.md` §19.

| # | Data | Ambito | Decisione | Alternative scartate | Reversibile? |
|---|---|---|---|---|---|
| 084 | 2026-09-06 | §3.1 | Due agenti separati per classe di rischio: A1 conversazionale senza shell, A2 di lavoro con shell | Agente unico con permessi variabili | Sì |
| 085 | 2026-09-06 | §3.2 | Motore unico, linea stabile del repository ufficiale, due istanze configurate diversamente | Due motori distinti; linea beta; harness a librerie; agente generale in Rust | Sì |
| 086 | 2026-09-06 | §3.3 | Separazione delle istanze tramite alberi XDG distinti | Istanza unica con profili | Sì |
| 087 | 2026-09-06 | §4.1 | Contenimento con `bubblewrap` costruito partendo dal vuoto | Filesystem intero in sola lettura con buchi in scrittura; motore di contenimento di terze parti; contenitori | Sì |
| 088 | 2026-09-06 | §4.3 | Perimetro di A1 ricalcolato per progetto attivo | Radice dei progetti montata per intero | Sì |
| 089 | 2026-09-06 | §4.4 | A2 non pubblica né preleva da remoti; nessuna chiave montata | Chiave dedicata montata in sola lettura | Sì |
| 090 | 2026-09-06 | §4.7 | Se il contenimento non parte, l'avvio fallisce | Degrado con avviso | Sì |
| 091 | 2026-09-06 | §5 | Politica di rete asimmetrica: lista bianca per A2, approvazione a livello di agente per A1 | Lista bianca per entrambi; nessun filtro per entrambi | Sì |
| 092 | 2026-09-06 | §6.2 | La credenziale del provider non entra mai nel processo dell'agente: intermediazione locale fuori dal contenimento | Chiave in file; chiave in variabile d'ambiente; mascheramento con valore fittizio | Sì |
| 093 | 2026-09-06 | §8.1 | Personalità e progetto come assi ortogonali: agente del motore e directory | Contesto unico che unisce prompt e dati | Sì |
| 094 | 2026-09-06 | §8.4 | La memoria è scrivibile solo tramite il client; il vincolo è imposto dai mount, non dall'interfaccia | Scrittura diretta dell'agente con conferma nell'interfaccia | No, senza ridisegnare §8.2 |
| 095 | 2026-09-06 | §8.5 | Memoria e archivio come strati distinti: la prima sempre in contesto e con conferma, il secondo su richiesta e senza | Strato unico | Sì |
| 096 | 2026-09-06 | §8.6 | Memoria scrivibile esclusa da A2 | Memoria su entrambi gli agenti | Sì |
| 097 | 2026-09-06 | §10.3 | Superficie remota solo per A2, in ascolto sull'indirizzo overlay e solo per sessioni dichiarate remote | Ascolto permanente; ascolto su ogni interfaccia; superficie remota anche per A1 | Sì |
| 098 | 2026-09-06 | §9 | Contratto esplicito motore/client, con livello client sottile e dati durevoli su file | Client accoppiato all'archiviazione interna del motore | No, senza riscrivere il client |
| 099 | 2026-09-06 | §10.1 | Ricerca nella cronologia esclusa dalla prima versione; l'archivio è la superficie di ricerca | Ricerca nel pannello sul database del motore | Sì |
| 100 | 2026-09-06 | §10.1 | Nessuna deroga ad ADR 078: il tipo di scheda è codice, l'istanza resta dichiarativa | Deroga esplicita per la scheda conversazionale | Sì |
| 126 | 2026-09-09 | §8.2, §8.5 (delta D-01) | Memoria a tre livelli — sistema, personalità, progetto — ognuno montato in sola lettura con una `proposte/` scrivibile; il client resta l'unico scrittore, imposto dai mount | Strato unico di memoria; scrittura diretta dell'agente con conferma nell'interfaccia | No: ridisegna §8.2 (deroga voluta ad ADR 094) |
| 127 | 2026-09-09 | §4.3, nuova §4.3.1 (delta D-02) | Cartelle di interesse del progetto: `project.json` elenca directory reali dell'host, montate in sola lettura nel perimetro per-progetto di A1; distinte da `materiali/` (copie statiche) | Solo copie statiche; radice dei progetti montata per intero | Sì |
| 128 | 2026-09-09 | §4.3, §4.4, §8.3 (delta D-03) | Niente cartelle note/codice a livello di sistema: rimossi `PHI_AGENT_NOTES_DIR` e `PHI_AGENT_CODE_ROOT`; `~/Notes` è un progetto ordinario; A2 apre una directory scelta per sessione, protetta da una lista di blocco configurabile (mai il confine) | Cartelle fisse di sistema (in contraddizione con ADR 045) | Sì |
| 129 | 2026-09-09 | §8.2 (delta D-04) | Metadati di progetto strutturati in `project.json` (titolo, descrizione, istruzioni, personalità predefinita, cartelle di interesse, chat fissate); `progetto.md` rigenerato dal client dai campi | `progetto.md` come unica fonte scritta a mano | Sì |
| 130 | 2026-09-09 | §8.5, §10.1 (delta D-05) | Specchio delle conversazioni lato client in `progetti/<nome>/conversazioni/<id>.md`, scritto dalle risposte HTTP già ricevute; sorgente della cronologia e corpus della ricerca | Nessuno specchio; lettura dal database interno del motore | Sì |
| 131 | 2026-09-09 | §10.1 (delta D-06) | Pannello a quattro sezioni — dashboard, chat, sessioni di codice, proposte di memoria; la ricerca nella cronologia rientra via D-05 + `phi agent search` (via d'uscita già prevista da ADR 099) | Singola conversazione a scorrimento; ricerca nel pannello sul database del motore | Sì |
| 132 | 2026-09-09 | nuova §10.4 (delta D-07) | Superficie di A2 nel pannello via metadati per-sessione posseduti da `phi`, registrati fuori dal contenimento; nessun canale di rete in ingresso verso il namespace di A2 | Ponte o strumento condiviso verso il server di A2 | Sì |
| 133 | 2026-09-09 | §10.1, §13 (delta D-08) | Personalità come entità di prima classe modificabile dal pannello (crea/modifica/rinomina/elimina) via `phi agent personality`; `personalita/` resta in sola lettura dentro il mount | Modifica solo da file a mano | Sì |

I numeri 101–125 sono nel registro globale di `phios-master-plan.md` §19. Le righe
126–133 recepiscono il registro delta di `phios-agente-delta.md` §2 (id provvisori
D-01…D-08), track `Out-of-plan: agent-panel-rework`.

---

## 17. Registro pacchetti

| Pacchetto | Ruolo | Macchine | Tier |
|---|---|---|---|
| *(runtime, linea stabile)* | A1, A2 | `zotac`, `razer` | T0 |
| `bubblewrap` | contenimento | `zotac`, `razer` | T0 |
| `socat` | ponte di rete di A2 | `zotac`, `razer` | T0 |
| `tinyproxy` | lista bianca d'uscita di A2 | `zotac`, `razer` | T0 |

Il runtime su `mini` è fuori dal perimetro di questo progetto (§1.2).
