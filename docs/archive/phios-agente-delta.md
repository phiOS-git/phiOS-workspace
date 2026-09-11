# phiOS — Agente AI, delta

**Versione:** 0.2 • **Stato:** recepito nel registro (ADR 126–133), in attesa di verifica hardware su `razer`
**Ultimo aggiornamento:** 2026-09-09
**Estende:** `phios-agente.md` v1.1 (ADR 084–100) • **Non sostituisce** il documento base
**Traccia:** `Out-of-plan: agent-panel-rework` — OOP-26/OOP-27, merge in `main`/`master` il 2026-09-09 (`phi` a `v0.13.0`)

---

## 0. Perché questo documento

`phios-agente.md` v1.1 è una specifica completa e la milestone M7 la realizza
(S-70…S-76, `awaiting-verification` su `razer`). L'uso reale del pannello ha fatto
emergere sei richieste che cambiano parti della specifica:

1. Pannello a **quattro sezioni** (dashboard, chat, sessioni di codice, proposte di
   memoria) invece della singola conversazione a scorrimento.
2. Progetti con una **cartella dedicata** che contiene istruzioni, metadati, config,
   conversazioni, materiali; con descrizione, elenco di istruzioni, personalità
   predefinita, e un **ambito di cartelle di interesse** (directory reali, in **sola
   lettura**, non copiate).
3. **Personalità** per singola conversazione, con una vista completa di creazione e
   modifica nel pannello.
4. **Memoria** su tre livelli: **sistema**, **personalità**, **progetto**.
5. Niente più **cartella note** né **cartella codice** a livello di sistema. L'agente
   di codice si apre in una cartella qualsiasi, esclusa una **lista di blocco**
   configurabile. "Note" diventa un progetto ordinario che punta a `~/Notes`.
6. Stati di caricamento reali su ogni superficie.

Le decisioni prese con Fla:

| Ambito | Decisione |
|---|---|
| Gestione della specifica | Documento delta separato (questo). Il base v1.1 non si tocca. |
| Cartelle di interesse | **Sola lettura.** Le modifiche restano in `output/` del progetto. |
| Accesso alle sessioni di codice | File di metadati posseduti da `phi`. Nessun canale di rete in ingresso verso il namespace di A2. |
| Sequenza | Tutto ora, su un ramo dedicato per repository. Merge solo su conferma di Fla. |

Le decisioni di questo documento sono state recepite nel registro il 2026-09-09:
**D-01…D-08 → ADR 126…133** in `phios-agente.md` §16, con la riga di rimando in
`phios-master-plan.md` §19. Gli id `D-0x` restano qui come chiave di lettura del
documento.

---

## 1. Conseguenze da mettere a verbale

### 1.1 L'isolamento fra progetti si allarga

`memoria.md` di **sistema** e di **personalità** è montata in A1 **indipendentemente
dal progetto attivo** (§4.3 rivista). Ne consegue che un fatto registrato a livello
di sistema mentre si lavora nel progetto A è leggibile dall'agente nel progetto B.

La regola §4.3 "Nessun altro progetto è visibile" **resta valida per i progetti**: un
progetto non vede gli altri progetti, i loro materiali, il loro archivio, la loro
`memoria.md` di progetto. La superficie condivisa è solo la memoria di sistema e
quella della personalità in uso — per costruzione poche righe, sotto conferma
esplicita dell'utente, mai scritte dall'agente.

### 1.2 Verifiche già superate da rieseguire

`V-05` (una sola `memoria.md`, sola lettura dentro il contenimento) e `V-06`
(insieme esatto dei percorsi scrivibili, con `notes/`) sono passate su `razer`
contro il layout v1. Il §7 di questo documento le riscrive: vanno rieseguite quando
il lavoro è recepito.

### 1.3 Falsi conflitti già chiariti

- **Ricerca cronologia vs ADR 099.** §10.1 nomina già la via d'uscita: *"la ricerca
  entra come verbo `phi` sui file dell'archivio, non come funzione del pannello sul
  motore."* La ricerca è il verbo `phi agent search` sui file markdown posseduti da
  `phi` (specchio delle conversazioni + `archivio/` + `memoria.md` + `progetto.md`),
  mai un'interrogazione del database di opencode. È l'attivazione di una via già
  prevista, non un ribaltamento.
- **Ambito cartella dell'agente di codice vs §1.4 / §4.1 / ADR 087.** Si sceglie
  **una** cartella per sessione di A2; solo quella viene montata; il contenimento
  resta costruito dal vuoto. La lista di blocco è un **guard-rail del selettore, mai
  il confine di sicurezza.**
- **Editor di personalità vs §8.2 "scrive solo l'utente".** Il pannello gira fuori
  dal contenimento ed **è** l'utente. `personalita/` resta in sola lettura dentro il
  mount.
- **Rimozione di `PHI_AGENT_NOTES_DIR` / `PHI_AGENT_CODE_ROOT`.** I default erano
  `~/notes` / `~/code`, già in contraddizione con ADR 045 (`~/dev` +
  `~/cloud/<vault>`, nessun `~/notes` di primo livello). Rimuoverli **risolve** quella
  contraddizione latente.

---

## 2. Registro delle decisioni delta

| # → ADR | Ambito | Decisione | Sostituisce / estende | Reversibile? |
|---|---|---|---|---|
| **D-01** → 126 | §8.2, §8.5 | **Memoria a tre livelli.** `sistema` (`<dati A1>/memoria.md`), `personalità` (`personalita/<nome>/memoria.md`), `progetto` (invariata). Ogni livello è montato in sola lettura; ogni livello ha una `proposte/` scrivibile; il client resta l'unico scrittore a ogni livello, imposto dai mount. | ADR 094 (il registro la marca "No, senza ridisegnare §8.2": questo *è* il ridisegno voluto), ADR 095 | No, senza ridisegnare §8.2 |
| **D-02** → 127 | §4.3, nuova §4.3.1 | **Cartelle di interesse del progetto.** Il `project.json` di un progetto elenca directory reali dell'host, montate in **sola lettura** nel perimetro per-progetto di A1 a un percorso stabile nel contenitore. Distinte da `materiali/` (copie statiche). L'anti-obiettivo §1.5 ("nessun accesso diretto alle directory di origine dei materiali") resta valido per i *materiali*; la cartella di interesse è un'adesione esplicita, per progetto, separata. | ADR 088 | Sì |
| **D-03** → 128 | §4.3, §4.4, §8.3, §14 | **Niente cartelle note/codice di sistema.** Si rimuove `PHI_AGENT_NOTES_DIR` e il mount dedicato all'archivio appunti; `~/Notes` è un progetto ordinario (cartella di interesse = `~/Notes`, personalità propria). Si rimuove `PHI_AGENT_CODE_ROOT`; A2 apre una **directory scelta per sessione**, montata in scrittura, protetta da una lista di blocco configurabile (mai il confine). | §4.3 mount archivio appunti, §4.4 radice codice fissa, J3, contraddizione con ADR 045 | Sì |
| **D-04** → 129 | §8.2 | **Metadati di progetto strutturati.** `project.json` (titolo, descrizione, elenco istruzioni, personalità predefinita, elenco cartelle di interesse, chat fissate). Lo possiede il client. `progetto.md` resta il file in chiaro che legge il motore, rigenerato dal client dai campi strutturati. | ADR 093 (aggiunge struttura, mantiene gli assi) | Sì |
| **D-05** → 130 | §8.5, §10.1 | **Specchio delle conversazioni lato client.** Il client scrive la trascrizione completa di ogni conversazione come markdown in `progetti/<nome>/conversazioni/<id>.md`, dalle risposte HTTP che già riceve. Indipendente dal motore; rafforza ADR 098. Complementare ad `archivio/` (che tiene i *riassunti* delle conversazioni chiuse). È la sorgente della cronologia in dashboard e il corpus della ricerca. | rafforza ADR 098; attiva la via d'uscita già prevista da ADR 099 | Sì |
| **D-06** → 131 | §10.1 | **Perimetro del pannello v2.** Quattro sezioni: Dashboard (progetti + cronologia + ricerca + elenco fissate + azioni), Chat (intestazione `progetto > titolo`, personalità per chat, scorrimento automatico, streaming), Sessioni di codice (gestione di A2 dai file di metadati), Proposte di memoria (sezione propria; il pannello si allarga fino a un limite per mostrare le differenze letterali). La ricerca cronologia **rientra** via D-05 + `phi agent search`. | ADR 099 (attiva la via prevista), ADR 100 (il pannello è una superficie dedicata, non un'istanza di `tabs.json` — già vero dopo OOP-06) | Sì |
| **D-07** → 132 | nuova §10.4 | **Superficie di A2 nel pannello via metadati posseduti da `phi`.** `phi` registra i metadati per-sessione (directory, stato, inizio/fine, indirizzo finestra Hyprland, percorso dello specchio) fuori dal contenimento; il pannello legge quei file; **nessun canale di rete in ingresso verso il namespace di A2**. "Apri conversazione" = specchio in sola lettura (può essere in ritardo). "Porta in primo piano il terminale" = corrispondenza con la finestra Hyprland. "Apri in un pannello" = nuovo terminale con sessione nuova o ripresa. | ADR 084 (aggiunge una vista di A2 in sola lettura senza condividere percorso, strumento o credenziale) | Sì |
| **D-08** → 133 | §10.1, §13 | **Personalità come entità di prima classe modificabile dal pannello.** Creazione / modifica / rinomina / eliminazione dal pannello (milestone 1 "dal pannello" di §13). `personalita/` in sola lettura dentro il mount; il pannello scrive via `phi agent personality` per la validazione. | ADR 093 | Sì |

---

## 3. Sezioni riviste di `phios-agente.md`

### 3.1 §4.3 rivista — Perimetro di A1

Ricalcolato per progetto attivo. **Nessun altro progetto è visibile** (§1.1 per il
limite di questa regola sui livelli di memoria superiori).

| Percorso | Modo |
|---|---|
| `output/` e `proposte/` del progetto attivo | scrittura |
| resto del progetto attivo (incl. `materiali/`, `archivio/`, `conversazioni/`, `memoria.md` di progetto) | sola lettura |
| `<dati A1>/memoria.md` (memoria di sistema) | sola lettura |
| `<dati A1>/proposte/` (proposte di sistema) | scrittura |
| `personalita/<nome>/memoria.md` per ogni personalità | sola lettura |
| `personalita/<nome>/proposte/` per ogni personalità | scrittura |
| `personalita/` (prompt) | sola lettura |
| cartelle di interesse del progetto attivo (§4.3.1) | sola lettura |
| albero XDG di A1 | scrittura |

**Rimosso:** "archivio appunti — sola lettura" (D-03: non esiste più un archivio
appunti di sistema; le note sono un progetto con una cartella di interesse).

Le `proposte/` di sistema e di personalità sono scrivibili perché una proposta di
memoria può riguardare qualunque livello; `memoria.md` di ogni livello resta in sola
lettura, quindi l'agente non può scrivere la propria memoria a nessun livello, nemmeno
se manipolato (ADR 094, invariato nel principio). Il client, fuori dal contenimento,
è l'unico che promuove una proposta a `memoria.md`, a qualunque livello.

Il cambio di progetto ricostruisce il contenimento e riavvia il servizio; il client
copre l'attesa con uno stato di caricamento.

### 3.2 §4.3.1 nuova — Cartelle di interesse

Un progetto può dichiarare, nel suo `project.json`, un elenco di directory reali
dell'host. All'avvio del contenimento per quel progetto, `phi-agent-contain` monta
ciascuna **in sola lettura** a un percorso stabile e deterministico dentro il
contenitore (`/home/agent/folders/<n>`, ordine dell'elenco).

- Le cartelle di interesse **non sono copiate**: sono la directory di origine, montata.
  Questo le distingue da `materiali/` (§8.2), che restano copie statiche. La scelta è
  esplicita e per progetto: l'utente decide quali directory un dato progetto può
  leggere.
- **Sola lettura, sempre.** L'agente non modifica una cartella di interesse. Ciò che
  produce lavorando su quei file va in `output/` del progetto, come ogni altro output
  (§4.3). Il recupero da errore resta "cancellare un file in `output/`".
- Ogni percorso è validato contro `mounts/never.paths` e contro la lista di blocco
  dell'utente (§3.4) prima di essere montato. Un percorso bloccato fa **fallire
  l'avvio** con una riga chiara — non viene ignorato silenziosamente (coerente con
  §4.7, ADR 090).

### 3.3 §4.4 rivista — Perimetro di A2

Albero XDG di A2 in scrittura · cache delle toolchain dedicate ad A2 in scrittura ·
**la singola directory di lavoro scelta per la sessione** in scrittura, montata a
`/home/agent/work`.

**Rimosso:** "radice dei progetti di codice in scrittura". Non esiste più una radice
fissa. Ogni sessione di A2 nasce con `phi agent code <DIR>`: `<DIR>` è l'unica
directory di lavoro montata, e nient'altro sotto `$HOME` è visibile. Il contenimento
resta costruito dal vuoto (ADR 087): montare una sola directory scelta è
default-deny per sessione, non un buco in scrittura in un filesystem montato per
intero.

Identità git via variabili d'ambiente, invariata. A2 non pubblica né preleva da
remoti, invariato (ADR 089).

### 3.4 §5 / §11 — Lista di blocco per la directory di lavoro di A2

`phi agent code <DIR>` rifiuta `<DIR>` se corrisponde a:

1. l'insieme non modificabile: `$HOME` stessa, `/`, `/etc`, `~/.ssh`, `~/.gnupg`,
   l'archivio del gestore password, `~/.config/phi-agent`, i repository di `phiOS`;
2. la lista dell'utente in `~/.config/phi-agent/code-blocklist` (un glob per riga),
   distribuita come `code-blocklist.example` con default sensati.

La lista è un guard-rail del selettore. Il confine reale resta il namespace di mount
costruito dal vuoto: anche se la lista fosse vuota o aggirata, A2 vedrebbe solo la
directory passata e i propri alberi XDG, mai il resto di `$HOME`.

### 3.5 §8.2 rivista — Struttura su disco

Radice sotto la directory dati XDG dell'utente (per A1).

```
<radice>/
  memoria.md                fatti durevoli di sistema        [agente: sola lettura]
  proposte/                 proposte di memoria di sistema    [agente: scrittura]
  personalita/
    <nome>/
      prompt.md             prompt di sistema — scrive solo l'utente
      memoria.md            fatti durevoli di quella personalità  [agente: sola lettura]
      proposte/             proposte di memoria di personalità    [agente: scrittura]
  progetti/                 (nome reale su disco: projects/ — vedi nota in fondo)
    <nome>/
      project.json          metadati strutturati — lo possiede il client
      progetto.md           istruzioni in chiaro — rigenerato da project.json
      materiali/            file copiati e statici           [agente: sola lettura]
      archivio/             riassunti delle conversazioni chiuse  [agente: sola lettura]
      conversazioni/        specchio markdown delle conversazioni [agente: sola lettura]
      memoria.md            fatti durevoli del progetto      [agente: sola lettura]
      proposte/             proposte di memoria del progetto [agente: scrittura]
      output/              file prodotti                    [agente: scrittura]
```

Note:
- **`personalita/<nome>.md` → `personalita/<nome>/prompt.md`**: la personalità diventa
  una directory, per ospitare la sua `memoria.md` e le sue `proposte/`. `phi agent
  init` migra i file piatti esistenti in modo idempotente.
- **`project.json`**: possesso del client (ADR 098 §9.2, "gestione dei file di
  progetto sul filesystem"). Campi: `title`, `description`, `instructions` (elenco),
  `default_personality`, `folders` (elenco di percorsi host), `pins` (id di
  conversazioni fissate). `progetto.md` è **derivato**: il client lo riscrive dai
  campi ogni volta che cambiano, così il motore continua a leggere un solo file in
  chiaro (§8.5).
- **`conversazioni/`**: specchio, non database. Il client scrive il markdown dalle
  risposte HTTP di opencode che già riceve (D-05). Nessuna dipendenza dallo schema
  interno del motore (ADR 098).
- I nomi italiani interni (`progetto.md`, `materiali/`, `archivio/`, `proposte/`,
  `memoria.md`) restano invariati: rinominarli rifà `V-05`/`V-06` senza motivo. La
  directory esterna resta `projects/` (inglese), come già nel codice — lo schema qui
  usa `progetti/` solo per continuità con `phios-agente.md` §8.2, ma
  l'implementazione e i mount usano `projects/`. Incoerenza IT/EN nota, non
  affrontata qui.

I materiali sono copie statiche: l'agente non riceve mai accesso alla directory di
origine. Le cartelle di interesse (§4.3.1) sono la directory di origine, in sola
lettura, per adesione esplicita del progetto — meccanismo diverso, scelta diversa.

### 3.6 §8.5 rivista — Memoria e archivio, con i livelli

| | `memoria.md` (3 livelli) | `archivio/` | `conversazioni/` |
|---|---|---|---|
| Contenuto | pochi fatti durevoli, per livello | riassunti delle conversazioni chiuse | trascrizione completa delle conversazioni |
| Come entra nel contesto | **sempre**, come istruzione (tutti e tre i livelli montati) | **su richiesta**, come risultato di lettura | **su richiesta**, come risultato di lettura o via `phi agent search` |
| Chi scrive | il client, su conferma | il client, alla chiusura | il client, a ogni turno / alla chiusura |
| Richiede conferma | **sì** | no | no |

I tre livelli di `memoria.md` entrano in contesto insieme, come istruzioni, nella
composizione del prompt (§8.2 opencode `instructions`): sistema, poi personalità in
uso, poi progetto attivo. La conferma di una proposta mostra sempre il **testo
letterale** come differenza rispetto al file del livello indicato — mai un riassunto
(§8.6, invariato).

`conversazioni/` è la superficie che rende possibile la ricerca (D-06) senza
interrogare il database del motore. È markdown ordinario, trovabile anche dagli
strumenti di lettura nativi dell'agente e dagli strumenti di sistema.

### 3.7 §10.1 rivista — Pannello, quattro sezioni

Evocazione da scorciatoia globale, superficie residente, connessione persistente al
flusso di eventi (invariato). Il pannello è una **superficie dedicata** (`Panels/
AgentPanel.qml`), non un'istanza di `tabs.json` — stato di fatto dopo OOP-06, qui
formalizzato; ADR 100 resta soddisfatto perché il *tipo* della superficie è codice
scritto una volta.

**Sezione 1 — Dashboard.** Elenco dei progetti e cronologia delle conversazioni.
Barra di ricerca su titolo e contenuto (`phi agent search`, gerarchia progetto →
conversazione, indica se il riscontro è nel titolo o nel corpo). Le conversazioni
fissate stanno in un elenco separato. Azioni: nuovo progetto, nuova conversazione,
fissa/sblocca, impostazioni (apre il pannello impostazioni alla sezione AI Agent).
Selezionando un progetto: nome, descrizione, elenco istruzioni, materiali (aggiunta
manuale di file, copiati come copie statiche nella cartella del progetto), cartelle
di interesse (aggiunta/rimozione di directory reali), personalità predefinita, elenco
delle conversazioni del progetto (fissabili nel progetto).

**Sezione 2 — Chat.** Una conversazione. Titolo `progetto > titolo` se fa parte di un
progetto, altrimenti solo il titolo. Il titolo nasce come id e viene cambiato in base
al contesto dopo il primo messaggio (lo fa opencode; il client legge `session.title`).
Personalità **per conversazione**, scelta da un controllo dedicato — non un campo di
testo — con accesso alla vista di modifica/creazione. Scorrimento automatico della
trascrizione. Indicatore di elaborazione (categoria A). Card di approvazione degli
strumenti. Avviso non bloccante e in tempo reale di proposta di memoria (§8.6), con
un contatore sulla barra delle sezioni; la revisione completa è nella sezione 4.

**Sezione 3 — Sessioni di codice.** Elenco di tutte le sessioni di A2, attive e
passate (recuperabili). Per ciascuna: aprire la vista conversazione nel pannello
(specchio in sola lettura), portare in primo piano il terminale attivo se esiste,
oppure aprire la sessione in un pannello a parte. Simile al pannello web di Claude
Code: una gestione centralizzata. **Le sessioni di codice non si mescolano con le
conversazioni dell'agente A1** — sezione separata, dati separati (D-07).

**Sezione 4 — Proposte di memoria.** Elenco delle proposte, raggruppate per livello
(sistema / personalità / progetto). Ogni proposta ha spazio per mostrare il suo
contenuto per intero (differenza letterale, mai un riassunto); il pannello si allarga
all'apertura della sezione se serve, fino a un limite.

Fuori dalla prima versione, invariato rispetto a v1.1: allegato di file per singola
conversazione; resoconto di fine giornata come superficie a sé (le proposte hanno la
loro sezione); riassunto verificato alla chiusura.

### 3.8 §10.4 nuova — Superficie di A2 nel pannello

Il pannello mostra e gestisce le sessioni di A2 **senza raggiungerne il server**. Il
server di A2 è dentro il suo namespace di rete (§5.1); aprirvi un canale in ingresso
sarebbe un cambio di postura di sicurezza (ADR 084: nessun percorso condiviso fra A1
e A2). Invece:

- `phi agent code <DIR>` registra un file di metadati per sessione in
  `~/.local/state/phi-agent/a2/sessions/<id>.json` (directory, stato, inizio, fine,
  indirizzo della finestra Hyprland se lanciata in un terminale, percorso dello
  specchio della trascrizione). Aggiorna lo stato all'uscita.
- Lo specchio della trascrizione è **best-effort**, dal contenuto che opencode
  espone; è la parte più debole di questa superficie e va marcata come tale, come già
  il salvataggio in `archivio/` alla chiusura in S-75.
- Il pannello legge solo quei file. "Apri conversazione" mostra lo specchio in sola
  lettura. "Porta in primo piano il terminale" fa corrispondere l'indirizzo di
  finestra registrato. "Apri in un pannello" lancia un terminale nuovo con la sessione
  ripresa o nuova.

---

## 4. Dipendenze da `phi` — verbi nuovi

Tutti sotto `phi agent`, coerenti con §13 (nessuno richiede l'API interna del motore;
richiedono che `phi` esista come binario con sottocomandi).

| Verbo | Perché | Livello |
|---|---|---|
| `project new\|set\|show` (con `--description`, `--personality`, `--folder`, `--instruction-*`) | metadati strutturati di progetto (D-04), cartelle di interesse (D-02) | 1 (dal pannello) |
| `personality list\|show\|new\|write\|rename\|delete` | personalità dal pannello (D-08) | 1 |
| `memory … --level system\|project [--personality NOME]` | memoria a tre livelli (D-01) | 0/1 |
| `chat list\|show\|sync\|pin\|unpin\|title` | specchio delle conversazioni (D-05) | 1 |
| `search QUERY [--project] [--scope]` | ricerca cronologia (D-06), via ADR 099 | 1 |
| `session list\|show` | superficie di A2 nel pannello (D-07) | 1 |
| `code DIR` | sessione di A2 con directory scelta + lista di blocco (D-03) | 0 |

`phi_context` (MCP, tool 5) estende il payload ai tre livelli di memoria e all'elenco
delle cartelle di interesse. Resta **un solo strumento**; `mcpTools` resta l'unico
punto di crescita (§7.1).

---

## 5. Realizzazione

Ordine (rami dedicati per repository, un commit per unità, trailer
`Out-of-plan: agent-panel-rework`):

1. **Documenti** — questo delta; rimandi in `phios-master-plan.md` §9.12/§11/§19;
   nota in `phios-agent-brief.md`; righe `OOP-NN` in `PROGRESS.md`.
2. **`phi`** — `internal/agent/model.go` (memoria a livelli, `project.json`,
   validazione cartelle, migrazione); verbi `chat`/`search`/`session`/`personality`/
   `code`; `mcp.go`. Test verdi.
3. **`phi-packages`** — bump `pkgver` (nessun tag, nessuna pubblicazione fino al
   merge; il `phi` pacchettizzato è congelato a 0.12.1 per le verifiche M7 in corso).
4. **`phios-dotfiles`** — `phi-agent-contain` + file di mount + `code-blocklist.example`
   + `agent.zsh` + `env.example` + README.
5. **`phi-shell`** — ricostruzione di `Panels/AgentPanel.qml` + `Panels/tabs/agent/*`
   + estensione di `Services/Agent.qml` + sfoltimento di `Settings/sections/AiAgent.qml`
   + correzioni di focus tastiera e scorrimento automatico.

**Non toccare** nessuna riga di step M7, il registro di verifica M7, né le righe OOP
dello shell-restyle: sono lavoro in corso.

---

## 6. Componenti (aggiunta a §14.4 di `phios-agente.md`)

| # | Componente | Milestone | Dimensione |
|---|---|---|---|
| 11 | Memoria a tre livelli: percorsi, mount, promozione per livello | 1 | piccola-media |
| 12 | Metadati di progetto strutturati + rigenerazione di `progetto.md` | 1 | piccola |
| 13 | Cartelle di interesse: lettura `project.json`, mount in sola lettura, validazione | 1 | piccola-media |
| 14 | Specchio delle conversazioni + `phi agent search` | 1 | media |
| 15 | Store dei metadati delle sessioni di A2 + `phi agent code` | 1 | piccola-media |
| 16 | Pannello a quattro sezioni | 1 | media-grande |
| 17 | Editor di personalità nel pannello | 1 | piccola |

---

## 7. Piano di verifica (aggiunta e modifica a `phios-agente.md` §15)

| # | Prova | Esito atteso | Se fallisce |
|---|---|---|---|
| V-05 *(riscritta)* | Scrittura diretta su `memoria.md` da dentro il contenimento, per **tutti e tre i livelli** (sistema, personalità in uso, progetto attivo) | negata in tutti e tre i casi | uno dei tre `memoria.md` è montato in scrittura per errore |
| V-06 *(riscritta)* | Scrittura fuori da `output/` e dalle `proposte/` di ciascun livello | negata; scrivibili solo `output/` del progetto e `proposte/` di sistema, personalità, progetto | i mount di A1 sono troppo larghi |
| V-19 | Lettura e scrittura di un file dentro una cartella di interesse del progetto | lettura riuscita, scrittura **negata** | il mount della cartella di interesse non è in sola lettura |
| V-20 | `phi agent code <percorso della lista di blocco>` e `phi agent code <dir valida>` | il primo rifiutato con una riga chiara e **nessun processo avviato**; il secondo monta solo quella dir in scrittura, nient'altro sotto `$HOME` | la lista di blocco non è applicata / il mount è troppo largo |
| V-21 | Da dentro il contenimento, `memoria.md` di sistema e di personalità presenti e in sola lettura; nessun'altra `memoria.md` di progetto oltre quella attiva | esatto | il perimetro per-progetto è sbagliato |
| V-22 | `phi agent search` su un progetto con più conversazioni nello specchio: riscontro solo nel corpo di una conversazione | restituisce quella conversazione; il database di opencode non viene mai aperto | la ricerca dipende dallo schema interno del motore |
| V-23 | Cambio di progetto: tempo di ricostruzione del contenimento con le cartelle di interesse montate | compatibile con l'uso interattivo (come V-16) | rivedere il numero/uso delle cartelle di interesse |

`V-01…V-04` restano bloccanti e invariate. `V-07…V-18` invariate.
