# phiOS — Piano di stile dell'interfaccia (stato finale di sessione, v2)

Sostituisce le versioni precedenti. Da confrontare e innestare in `phios-architettura.md` (integra §7.2, compila §7.5, note per §7.4/§8.2/§8.2.1). Tag: `[OK]` deciso · `[PLACEHOLDER]` valore di partenza scelto per coerenza e funzione, sostituibile senza cambiare la regola · `[NOTA]` promemoria tecnico · `[FUORI SCOPE]` volutamente non trattato qui.

---

## 1. Principio di coerenza
La coerenza tra superfici eterogenee è di **grammatica** (ruoli colore, motion, affordance), non di resa visiva identica. `[OK]`

---

## 2. Sistema colore

Palette a livelli:
- **Tier 0** — struttura (chrome, bordi, sfondo): mono stretto, 2–3 valori.
- **Tier 1** — accento primario: stato attivo/focus/interattività primaria, un solo ruolo.
- **Tier 2** — semantico riservato (error/warn/success/info): solo su soglia/stato.
- **Tier 3** — sintattico (2–3 tonalità extra): per disambiguare più categorie/stati simultanei (codice, log, diff).

Varianti: **dark + light, entrambe permanenti**. `[OK]`

Contrasto: target 4.5:1 (WCAG AA). Accento attuale (`#d3a0ac`): ~9.4:1 su nero (ok), ~2.2:1 su bianco (sotto minimo). `[AZIONE]` derivare in OKLCH una seconda lightness per la variante chiara.

Colore per host (SSH): il segment del prompt zsh legge `accent` da `design/tokens`, valore diverso per file-host — nessuna meccanica nuova. `[OK]`

**Colori Tier-2, direzione di partenza** (non ancora derivati in OKLCH, non ancora verificati a 4.5:1 su entrambe le varianti): errore su tonalità ossido/rosso desaturato, warning su ocra/ambra desaturato, successo su verde muschio/teal desaturato, info su blu ardesia desaturato — coerenti con il riferimento retrò/CAD già fissato. `[PLACEHOLDER]`, valori esatti da derivare quando si genera la palette definitiva.

**Token**: `bg-0..bg-3` · `fg-0..fg-3` · `accent` · `accent-fg` · `border` · `border-strong` · `overlay-scrim` · `error`/`warn`/`success`/`info` · `syntax-1..n` · `selection-bg`/`selection-fg`.

---

## 3. Tipografia

Due contesti d'uso guida: **studio universitario/ricerca** (lettura prolungata) e **programmazione** (codice, terminale).

- **`font-mono`** — **Source Code Pro**, pacchetto `adobe-source-code-pro-fonts` (Arch extra, T0), licenza SIL OFL. Terzo membro della superfamiglia Adobe già scelta per `font-reading`/`font-ui`, descritto a monte come adatto sia a "interfacce utente" sia a "ambienti di codifica" — copre letteralmente il doppio ruolo di questo token (codice/IDE/documenti + chrome di sistema custom, coerente con l'unità di spaziatura `1ch` di §4). Italico reale, gamma pesi ampia (ExtraLight→Black). Copertura greca da verificare visivamente una volta installato. Configurabile. `[PLACEHOLDER]`
- **`font-reading`** — **Source Serif 4**, pacchetto `adobe-source-serif-fonts` (Arch extra, T0), licenza OFL. Sei pesi × cinque taglie ottiche: la resa resta leggibile sia a corpo piccolo (nota a piè pagina) sia a corpo largo (titolo di un documento), senza cambiare famiglia. Configurabile. `[PLACEHOLDER]`
- **`font-ui`** — **Source Sans 3**, pacchetto `adobe-source-sans-fonts` (Arch extra, T0), licenza OFL. Stessa superfamiglia di Source Serif, disegnata esplicitamente per l'uso complementare — non un abbinamento arbitrario. Descritto a monte come font per ambienti di interfaccia utente: copre menu, dialoghi, label delle app native (Classe 2). Configurabile. `[PLACEHOLDER]`
- **`font-symbol`** — già deciso in architettura (§7.3): Nerd Font solo glifi, separato dai font principali.

Nessun font "titolo/display" separato: la gerarchia si ottiene con dimensione/colore/opacità (§6), non con una famiglia dedicata. `[OK]`

Nota: se in futuro si vuole lo stesso principio di superfamiglia anche su `font-mono`, Source Code Pro è il terzo membro della stessa famiglia Adobe, pacchettizzato separatamente nei repo ufficiali. Non deciso qui. `[NOTA]`

---

## 4. Spaziatura, forma, superficie

- Unità di spaziatura: multiplo di `1ch` di `font-mono`, per agganciare il ritmo della GUI alla griglia a caratteri del terminale. `[OK]`
- **`radius-base`**: **2px**, configurabile. Non zero puro: a un pixel di raggio nullo, su fattori di scala non interi (HiDPI frazionario), l'angolo può mostrare artefatti di aliasing nel compositing; 2px resta percettivamente "spigolo vivo" evitandolo. Da verificare a schermo sull'hardware reale (`zotac`/`razer`) e correggere se non necessario. `[PLACEHOLDER]`
- `radius-pill`: fisso, pieno, riservato a toggle e badge di stato. `[OK]`
- `z-layer`: base, barra, popover, modale, tooltip, notifica. `[OK]`

---

## 5. Motion

Tassonomia a 4 categorie, criterio: peso inverso alla frequenza d'uso.

- **A — feedback di tracciamento** (es. `cursor_trail` kitty): continuo, leggero.
- **B — transizione di stato** (finestre, pannelli, tendine, workspace): alta frequenza → quasi-istantaneo, nessun easing organico.
- **C — enfasi/evento raro**: peso ammesso solo se legato a un evento reale. Due effetti formalizzati:
  - **Battitura carattere-per-carattere** — boot, testo di conferma raro, prima esecuzione.
  - **Random-letters** (scramble che si risolve nella parola finale) — riservato a pochi punti deliberati: schermata di sblocco, indicatori di caricamento dove la risoluzione coincide col completamento reale di un processo.
  - **Rimosso**: letter-roll generico sui titoli — non deve ricomparire come default.
- **D — indicatori ambientali**: animazione vietata per default, eccezioni giustificate esplicitamente.

**Notifiche/toast**: categoria **B**, come placeholder — una notifica può presentarsi più volte per sessione di lavoro, quindi va trattata come evento frequente finché l'uso reale non dimostra il contrario. `[PLACEHOLDER]`

---

## 6. Ruoli tipografici / affordance
Nessun simbolo di affordance diffuso. Stato comunicato da peso/colore/opacità:
- label di sistema → basso contrasto, sempre monocromo
- valore/dato → colore Tier-2 su soglia
- interattivo inattivo → stesso peso del label, opacità ridotta
- interattivo attivo/selezionato → inversione piena
- glifo `>` → riservato al solo punto di input attivo
`[OK]`

---

## 7. Modello di disclosure a tre livelli
Istanzia §8.2.1 dell'architettura.
1. **Segmento in barra** — muto per default, cambia stato solo su soglia/evento discreto.
2. **Tendina** — placeholder di capienza: **max 5 righe informative + 2 azioni rapide**. Da rivedere componente per componente una volta costruito il contenuto reale — è un tetto di partenza, non una misura derivata da dati. `[PLACEHOLDER]`
3. **Vista estesa** — dove esiste già uno strumento maturo (btop, nmtui, bluetuith, pulsemixer), il deep-link lancia quello. Non richiede hot-reload classe A.

---

## 8. Barra di stato

**Layout**: sinistra = workspace (numerico, corrente invertito) · centro = titolo finestra attiva · destra = cluster di stato che termina con l'orologio.

**Troncamento titolo finestra**: fine stringa con ellissi, nessuna logica aggiuntiva. Semplice di proposito — si rivede solo se in uso risulta insufficiente. `[PLACEHOLDER]`

**Criterio icona vs testo**: icona solo per stato discreto/binario; testo + colore-su-soglia per ogni valore continuo. `[OK]`

**Soglie anomaly-carrier**, placeholder da tarare sui dati reali di ciascuna macchina:
- `razer` batteria: velocità di scarica anomala oltre il 15%/ora, o carica residua sotto il 20%.
- `zotac` GPU: utilizzo sostenuto oltre il 70% per più di 60 secondi, o temperatura oltre 75°C.

Numeri di partenza generici, non calibrati sul comportamento reale delle due macchine — da correggere dopo osservazione. `[PLACEHOLDER]`

**Inventario per host:**
- `zotac`: workspace · titolo finestra · volume (icona solo su mute) · rete (icona solo su stato tailscale) · GPU anomaly-carrier · Φ agente (§17) · orologio
- `razer`: come sopra meno GPU, più batteria anomaly-carrier · wifi (icona stato, SSID a richiesta) · bluetooth (icona solo se connesso) · night mode (icona stato) · Φ agente (§17)
- `mini`: nessuna barra — hostname colorato nel prompt zsh via SSH

CPU/RAM/aggiornamenti pendenti: esclusi come segmenti permanenti. `[OK]`

---

## 9. Componente toggle standard
Pillola arrotondata (`radius-pill`), segmento attivo pieno in accento. `[OK]`

---

## 10. Vincolo sfondo
Wireframe/griglia tecnica o gradiente piatto, non fotografico/illustrativo. `[NOTA]`

---

## 11. Inventario per classe di superficie

Nota tecnica quickshell (0.3.1): QML/QtQuick, hot-reload al salvataggio. Pattern reale osservato: singleton `Appearance.qml` + libreria `common/widgets/Styled*.qml` — duplicazione zero dentro questa classe.

- **Classe 1 — custom (quickshell)**: barra · popover/tendina · notifica/toast · launcher · pannello impostazioni (anteprima doppia dark/light) · lock screen · boot splash · pannello laterale a schede · overlay Alt+Tab · tooltip (con ritardo di comparsa) · menu contestuale.
- **Classe 2 — app native GTK/Qt**: bottoni, checkbox, radio, scrollbar, menu, tab, righe lista — via tema GTK/Kvantum. Window decoration (CSD): **soppressa** come placeholder — il titolo finestra è già mostrato al centro della barra (§8), una title bar per-finestra duplicherebbe l'informazione oltre a consumare spazio verticale in un WM a tiling dove il drag-to-move non è il metodo di interazione primario. Da verificare che le app GTK4/libadwaita in uso permettano davvero la soppressione completa — alcune la impongono. `[PLACEHOLDER]`
- **Classe 3 — terminale/TUI**: mappa 16 colori ANSI · cursore terminale (token separato dal cursore GUI) · selezione · modeline/statusline (parentesi da modeline restano convenzione legittima, non affordance) · box-drawing · palette Tier-3.
- **Classe 4 — app chiuse** (Firefox-fork ecc.): solo iniezione accento + toggle chiaro/scuro.
- **Classe 5 — chrome di sistema**: XCursor theme (già in architettura) · schermata login/banner TTY · prompt passphrase LUKS · systemd-boot: **lasciare default**, come placeholder — theming limitato per natura (ambiente UEFI, nessuno stack di font/colore token disponibile prima del caricamento OS), schermata visibile solo se si interrompe il boot, e l'identità visiva dell'avvio è già portata dal boot splash grafico separato che segue. Costo di lavoro non giustificato dalla visibilità. `[PLACEHOLDER]`

---

## 12. Stati trasversali
`default` · `hover` · `active/pressed` · `focus` (tastiera) · `disabled` · `loading` · `invalid/errore`. `[OK]`

---

## 13. Note per l'architettura
- **§7.4**: le app on-demand da deep-link di Tier 3 non richiedono hot-reload classe A.
- **§8.2**: il modello di disclosure richiede popover con contenuto arbitrario — `waybar` copre male il caso, `quickshell` è la direzione già scelta per il progetto.

---

## 14. Fuori perimetro `[FUORI SCOPE]`
- Meccanismo/strumento per i menu contestuali — non trattato in questa sede.
- Scelta concreta dei pacchetti (bar/launcher/notifiche) — resta §8.2.

---

## 15. Pannello calendario/eventi
Placeholder: **tab nel pannello laterale unico** (notifiche/clipboard/chat), non superficie separata — coerente col principio già in architettura (§8.2.1) di evitare sei superfici indipendenti da tematizzare separatamente. Rivedibile se in uso il pannello unico risulta sovraccarico. `[PLACEHOLDER]`

---

## 16. Riepilogo placeholder da verificare in corso d'opera
Tutti i punti seguenti hanno un valore di partenza funzionale assegnato in questo documento, non sono più blocchi aperti — vanno solo confermati o corretti quando la decisione concreta a monte (strumento scelto, hardware osservato, contenuto reale del componente) sarà disponibile:
- `font-reading` / `font-ui` (§3) — famiglie scelte, pesi/taglie da rifinire in uso
- `radius-base` (§4) — 2px
- categoria motion notifiche/toast (§5) — B
- capienza tendina (§7) — 5 righe + 2 azioni
- troncamento titolo finestra (§8) — fine stringa, ellissi
- soglie anomaly-carrier batteria/GPU (§8)
- colori Tier-2 (§2) — direzione di tonalità, non hex definitivi
- pannello calendario (§15) — tab nel pannello unico
- `font-mono` (§3) — Source Code Pro
- window decoration CSD (§11) — soppressa
- systemd-boot (§11) — lasciato default

Nessun punto risulta più senza un valore di partenza. Restano fuori dal perimetro di questo documento solo le due voci dichiarate esplicitamente tali in §14 (strumento per i menu contestuali, scelta concreta dei pacchetti bar/launcher/notifiche) — non sono punti da chiudere qui, appartengono a §8.2 dell'architettura.

---

## 17. Identità — il marchio Φ

Φ ha due ruoli distinti, non uno: marchio statico del sistema e indicatore di presenza dell'agente AI ("copilot"), col richiamo dichiarato alla Φ dell'integrated information theory come misura di informazione integrata. Simbolo unico ovunque = rischio di dissolvenza del significato, stesso problema già affrontato con le parentesi diffuse.

**Un solo glifo, due trattamenti — nessuna meccanica nuova:**
- **Ruolo A — marchio statico**: Tier-0, monocromo, immobile. Contesti: boot splash · banner login/TTY · eventuale pannello "about phiOS". Mai altrove.
- **Ruolo B — presenza dell'agente**: Tier-1 (accento) solo mentre l'agente elabora, altrimenti neutro — regola "icona solo su stato discreto" già fissata in §8. Motion categoria A durante l'elaborazione (leggero, continuo, come `cursor_trail`) — non categoria C: un indicatore che compare a ogni interazione è per definizione frequente, la categoria C violerebbe §5.

Spiega, non introduce, la nota già in architettura (§7.7): "vettoriale, variante monocroma + variante accento" — sono Ruolo A e Ruolo B.

**Codepoint**: **Φ maiuscola, U+03A6**. Non la minuscola: Unicode ha due minuscole distinte (φ U+03C6, ϕ U+03D5 — forma chiusa/aperta) e i font non sono coerenti tra loro su quale renderizzi come cosa; la maiuscola ha un solo codepoint, nessuna ambiguità. Coincide inoltre con la notazione di Tononi per l'informazione integrata — coerenza col riferimento dichiarato.

**Copertura font**: verificato — Source Serif (writing system greco AG-1) e Source Sans (correzioni greche documentate) coprono lo script greco, Φ nativo in entrambi i font di sistema (§3), soddisfa I-11 senza fallback al solo vettore per usi testuali. Il marchio/logo resta comunque un asset vettoriale a parte (icona, non testo). `[OK]`

**Uso ammesso** (lista chiusa):
- Boot splash (Ruolo A)
- Banner TTY/login (Ruolo A)
- Pannello "about"/info di sistema, se costruito (Ruolo A)
- Segmento dedicato in barra di stato, `zotac`/`razer` (Ruolo B) — vedi correzione §8

**Uso escluso**: sfondo, watermark ripetuto, icona di ogni finestra, decorazione nel launcher — nessuna funzione aggiunta, solo inflazione del simbolo. `[OK]`

**Segmento agente (correzione a §8)**: mancava nell'inventario. Modello a tre livelli già esistente (§7): Tier1 = Φ neutro a riposo, Φ in accento con motion A durante l'elaborazione; Tier2 = tendina con l'ultima risposta/interazione; Tier3 = interfaccia estesa dell'agente. Trigger binario (elaborazione sì/no) — nessuna soglia da tarare, a differenza degli anomaly-carrier di batteria/GPU. `[OK]`

**Nota tematica, non vincolante**: l'effetto random-letters già ammesso in categoria C (§5) per sblocco/caricamento avrebbe una coerenza diretta se usato per la comparsa del marchio in boot — non è una regola imposta, solo un'opzione che si allinea al resto senza aggiungere eccezioni.
