# Claude Context Kit

Kit locale per configurare **Claude Code** con un contesto globale persistente, policy operative e contesto specifico per repository, mantenendo tutto fuori dai repository applicativi.

L’obiettivo è usare Claude Code in modo più governato durante attività di sviluppo, refactoring e supporto tecnico, senza creare file `.claude/` o `CLAUDE.md` dentro i progetti su cui si lavora.

## Cosa risolve

Quando si lavora su più repository, Claude Code ha bisogno di conoscere ogni volta stack, comandi, vincoli e struttura del progetto. Questo kit centralizza queste informazioni in `~/.claude/` e le inietta automaticamente a ogni avvio di sessione.

In particolare:

- installa un `CLAUDE.md` globale con identità, policy e formato output;
- configura i permessi di Claude Code tramite `settings.json`;
- blocca comandi Git potenzialmente distruttivi o non desiderati;
- inietta automaticamente il contesto del repository corrente tramite hook `SessionStart`;
- mantiene un file `tech-stack.md` curato per ogni repository;
- genera una bozza iniziale del contesto repo quando manca;
- genera al volo una vista sintetica della struttura cartelle, evitando contesto stantio.

## A chi serve

Questo kit è pensato per chi usa Claude Code come assistente operativo su repository reali e vuole:

- evitare che Claude modifichi Git state senza controllo;
- mantenere il knowledge base fuori dai repository di progetto;
- ridurre ripetizioni e prompt manuali a ogni sessione;
- avere contesto specifico per repo senza sporcare il workspace;
- standardizzare il comportamento finale di Claude dopo ogni task.

## Claude Code vs Claude Desktop

Questo progetto è pensato per **Claude Code**, cioè la superficie agentica/terminale/IDE che legge:

- `~/.claude/CLAUDE.md`
- `~/.claude/settings.json`
- gli hook configurati in `settings.json`

Non è pensato per la chat generica di **Claude Desktop**, che usa configurazioni diverse, come `claude_desktop_config.json`, principalmente per MCP server e preferenze dell’app.

## Struttura del progetto

**Modello clone-in-place:** la root di questo repo **è** `~/.claude`. Non si copia nulla:
si clona/estrae direttamente in `~/.claude` e si versiona quella cartella.

```text
~/.claude/                 ← la root del repo È questa cartella
├── .gitignore             # protegge segreti, transcript e contesti di progetto
├── CLAUDE.md              # memoria globale (policy, governance contesto)
├── settings.json          # permessi (deny git) + hook + statusLine
├── statusline.sh          # display ctx% + logging token reali
├── bootstrap.sh           # wiring in-place (no copia)
├── README.md / INSTALL.md
├── hooks/
│   ├── repo-context.sh        # SessionStart: contesto repo + ripresa post-compact
│   ├── context-budget.sh      # UserPromptSubmit: segnale pressione contesto
│   ├── pre-compact.sh         # PreCompact: checkpoint + log
│   └── ctx-stats.sh           # consiglia le soglie dai log
├── skills/
│   ├── astro-svelte-stack/                   # regole stack Astro/Svelte + matrice versioni (paths-scoped)
│   ├── context-governance/SKILL.md          # procedura compattazione/cambio task (on-demand)
│   └── repo-onboarding/
│       ├── SKILL.md                          # flusso bozza tech-stack.md
│       └── scripts/new-repo-context.sh       # deduce lo stack (bundle della skill)
├── repos/
│   └── _TEMPLATE/tech-stack.md   # (i contesti repo reali sono git-ignored)
└── state/                 # runtime: checkpoint, campioni, soglie (git-ignored)
```

> **Dove vive cosa.** Il *grilletto* della governance e dell'onboarding sta in `CLAUDE.md`
> (residente, sopravvive alla compattazione, attivo ogni turno). La *procedura* dettagliata sta
> nelle **skill** (caricate on-demand → CLAUDE.md resta snello). Gli **hook** danno il trigger
> deterministico che nomina la skill giusta. Le skill non vanno registrate: Claude Code le
> scopre da `~/.claude/skills/` all'avvio.

### File principali

| File | Scopo |
| --- | --- |
| `.gitignore` | Versiona solo la config; esclude credenziali, `projects/`, `state/`, contesti repo reali. |
| `bootstrap.sh` | Wiring **in-place** (chmod, crea `state/`, `git init` se manca). Non copia. |
| `CLAUDE.md` | Memoria globale: identità, policy git, governance del contesto. |
| `settings.json` | Permessi (deny git), hook `SessionStart`/`UserPromptSubmit`/`PreCompact`, `statusLine`. |
| `statusline.sh` | Mostra `ctx %` e logga il `used_percentage` reale per tarare le soglie. |
| `hooks/repo-context.sh` | `SessionStart`: inietta contesto repo + folder graph; ripresa post-compact. |
| `skills/repo-onboarding/` | Skill: bozza di `tech-stack.md` per un nuovo repo (bundle `scripts/new-repo-context.sh`). |
| `skills/context-governance/` | Skill: procedura compattazione/cambio task (caricata on-demand). |
| `skills/astro-svelte-stack/` | Skill: regole stack Astro(4–7)/Svelte(3–5), zero-overkill e protocollo ricerca; matrice versioni in `references/` (attiva sui file `.astro`/`.svelte`). |
| `hooks/context-budget.sh` | `UserPromptSubmit`: segnale di pressione del contesto (token reali / byte). |
| `hooks/pre-compact.sh` | `PreCompact`: checkpoint + backup transcript + log. |
| `hooks/ctx-stats.sh` | Legge i log e **consiglia** `CTX_WARN_PCT`/`CTX_SOFT_PCT`. |
| `repos/_TEMPLATE/tech-stack.md` | Template per i contesti repo curati. |

## Installazione

Due scenari, a seconda che `~/.claude` esista già.

### A) Macchina nuova (nessun `~/.claude`)

Clona direttamente come `~/.claude`, poi esegui il bootstrap:

```bash
git clone <url-del-tuo-fork-privato> ~/.claude
cd ~/.claude
bash bootstrap.sh
```

Oppure, da uno zip/7z del kit: estrai il **contenuto** dentro `~/.claude/` e lancia
`bash ~/.claude/bootstrap.sh`.

### B) `~/.claude` esiste già (hai già usato Claude Code)

Non si può clonare in una cartella non vuota. Porta dentro i file del kit
**senza toccare** la tua config esistente, poi versiona in-place:

```bash
# 1) clona il kit altrove
git clone <url> /tmp/claude-kit

# 2) copia i file del kit in ~/.claude SENZA sovrascrivere CLAUDE.md/settings.json tuoi
cd /tmp/claude-kit
cp -n .gitignore bootstrap.sh README.md INSTALL.md statusline.sh ~/.claude/
cp -n CLAUDE.md settings.json ~/.claude/        # -n = no overwrite; fai il merge a mano
cp -rn hooks repos ~/.claude/

# 3) wiring + git init in-place
cd ~/.claude
bash bootstrap.sh
```

Se avevi già un `CLAUDE.md`/`settings.json`, uniscili a mano: aggiungi la sezione
**Governance del contesto** al tuo `CLAUDE.md` e gli hook `UserPromptSubmit`/`PreCompact`
+ `statusLine` al tuo `settings.json`.

### Cosa fa `bootstrap.sh`

Niente copia. Rende eseguibili hook/statusline, crea `state/` e `repos/` (git-ignored),
e se manca inizializza il repo git (senza commit automatici). È idempotente.

## Versionare `~/.claude` (in sicurezza)

L'obiettivo è avere **tutta la config versionata** senza esporre dati sensibili.
Il `.gitignore` esclude per default:

- **segreti**: `.credentials.json`, `.claude.json`, `*.pem`, …;
- **transcript e cronologia**: `projects/`, `history.jsonl`, `file-history/`, …;
- **stato runtime**: `todos/`, `shell-snapshots/`, `plugins/`, `statsig/`, …;
- **stato del kit**: `state/` (contiene copie di transcript → sensibile);
- **contesti repo reali**: `repos/*` tranne `_TEMPLATE` (descrivono sistemi di progetto).

Commit della sola configurazione:

```bash
cd ~/.claude
git add .gitignore CLAUDE.md settings.json statusline.sh hooks/ \
        skills/ repos/_TEMPLATE/ README.md INSTALL.md bootstrap.sh
git commit -m "feat: claude context kit"
# push SOLO su un remote PRIVATO tuo:
# git remote add origin <url-privato> && git push -u origin main
```

Per versionare **consapevolmente** un contesto repo (solo se non sensibile):

```bash
git add -f repos/<nome-repo>/
```

> ⚠️ Verifica sempre `git status` prima del primo push: non deve comparire nulla
> sotto `state/`, `projects/`, `repos/<repo-reali>` né alcun file di credenziali.

## Primo avvio dopo il bootstrap

1. riavvia Claude Code;
2. esegui `/hooks` e approva lo snapshot dell’hook `SessionStart`;
3. esegui `/memory` e verifica che `~/.claude/CLAUDE.md` sia caricato;
4. controlla che la statusLine in basso mostri `ctx %`.

## Come funziona il contesto per repository

Quando Claude Code parte dentro un repository, l’hook `repo-context.sh` determina il repository corrente e cerca il file:

```text
~/.claude/repos/{nome-repo}/tech-stack.md
```

Se il file esiste, viene iniettato nel contesto della sessione insieme a una vista aggiornata della struttura cartelle.

Se il file non esiste, Claude riceve un messaggio di contesto mancante e deve proporre la generazione della bozza tramite:

```bash
~/.claude/skills/repo-onboarding/scripts/new-repo-context.sh
```

La bozza non viene salvata automaticamente. Deve essere rivista e confermata prima di creare il file definitivo in:

```text
~/.claude/repos/{nome-repo}/tech-stack.md
```

## Generare una bozza per un nuovo repository

Da dentro il repository:

```bash
~/.claude/skills/repo-onboarding/scripts/new-repo-context.sh
```

Oppure passando un path esplicito:

```bash
~/.claude/skills/repo-onboarding/scripts/new-repo-context.sh /path/del/repository
```

Lo script prova a dedurre:

- nome repo;
- package manager;
- presenza di TypeScript;
- monorepo/workspace;
- configurazione Astro;
- adapter SSR;
- server Node custom;
- modulo Go;
- dipendenze significative da `package.json`;
- script disponibili in `package.json`.

Il risultato è una bozza Markdown da completare manualmente nelle sezioni architetturali e nei vincoli specifici.

## Policy Git

Il kit configura Claude Code per negare comandi Git che modificano lo stato del repository, tra cui:

```text
git commit
git push
git add
git merge
git rebase
git reset
git restore
git clean
git stash drop
```

Questa scelta serve a mantenere il controllo umano sulle operazioni Git e a preservare un workspace pulito, tenendo la configurazione fuori dai repository di progetto.

## Policy operative globali

Il file `CLAUDE.md` definisce alcune regole globali per Claude Code:

- agire come Senior Software Engineer;
- fare modifiche minime e manutenibili;
- non creare `.claude/` o `CLAUDE.md` dentro i repository;
- non modificare file critici senza approvazione esplicita;
- non scrivere segreti nei file di contesto;
- chiudere ogni task con summary, commit suggerito e branch corrente.

## Formato consigliato per `tech-stack.md`

Ogni repository dovrebbe avere un file dedicato:

```text
~/.claude/repos/{nome-repo}/tech-stack.md
```

Il template consigliato contiene:

- comandi esatti di install, dev, test, lint e build;
- stack tecnologico;
- architettura in breve;
- gotcha, vincoli e file da non toccare.

Il file dovrebbe restare breve e operativo. L’obiettivo non è documentare tutto il progetto, ma dare a Claude Code il contesto minimo ad alto valore.

## Personalizzazione

Puoi adattare il kit modificando:

| Area | Dove intervenire |
| --- | --- |
| Policy globali | `~/.claude/CLAUDE.md` |
| Permessi e blocchi | `~/.claude/settings.json` |
| Hook di avvio | `~/.claude/hooks/repo-context.sh` |
| Procedura governance/onboarding | `~/.claude/skills/*/SKILL.md` |
| Rilevamento stack | `~/.claude/skills/repo-onboarding/scripts/new-repo-context.sh` |
| Template repo | `~/.claude/repos/_TEMPLATE/tech-stack.md` |

## Disinstallazione

Nel modello clone-in-place `~/.claude` è il repo stesso. Per disattivare il kit:

1. **Sospendi gli hook**: in `~/.claude/settings.json` rimuovi i blocchi
   `SessionStart`/`UserPromptSubmit`/`PreCompact` e `statusLine` (o spostali altrove).
2. **Rimuovi gli script** che non vuoi più: `~/.claude/hooks/*.sh`, `~/.claude/statusline.sh`.
3. **Pulisci lo stato** (facoltativo): `rm -rf ~/.claude/state`.

Per smettere solo di **versionare** senza disinstallare, rimuovi il repo git mantenendo i file:

```bash
rm -rf ~/.claude/.git
```

Prima di rimuovere `CLAUDE.md` o `settings.json`, verifica che non contengano
configurazioni personali non legate al kit.

## Stato del progetto

Il progetto è uno scaffold leggero e locale. Non richiede dipendenze runtime particolari oltre a Bash, Git e, opzionalmente, Node.js per una lettura più robusta di `package.json` durante la generazione della bozza `tech-stack.md`.

## Licenza

Il progetto è pensato per essere rilasciato come **open source**.

Prima della pubblicazione ufficiale è consigliato aggiungere un file `LICENSE` alla root del repository con la licenza scelta, ad esempio MIT o Apache-2.0. Fino a quando il file `LICENSE` non è presente, il README dichiara l’intenzione open source ma non sostituisce una licenza formale.

## Governance del contesto (compattazione & cambio task)

Aggiunta pensata per le **sessioni lunghe di coding**: mantenere il contesto snello in modo
*semi-automatico*, senza che Claude agisca da solo. Due livelli che lavorano insieme.

**1. Livello comportamentale (policy in `CLAUDE.md`).** È la parte "semantica": un hook
deterministico non può capire che stai cambiando task. La policy istruisce Claude a fermarsi
quando rileva un **cambio di task** o un **segnale di budget alto** e a *proporre* `/compact`
(task correlato → tiene un riassunto) o `/clear` (task scollegato → il contesto repo viene
re-iniettato dall'hook), con **motivazione** e manifesto **MANTIENI / SCARTA**, attendendo
**conferma o modifica**. Claude non lancia mai da sé quei comandi: li esegue l'utente.

**2. Livello deterministico (hook).**

| Hook | Evento | Cosa fa |
| --- | --- | --- |
| `context-budget.sh` | `UserPromptSubmit` | Stima la pressione del contesto dalla dimensione del transcript e, **solo oltre soglia**, inietta un segnale `CONTEXT BUDGET` (banda `soft`/`warn`). Throttle per banda: niente spam a ogni turno. Esce **sempre** 0. |
| `pre-compact.sh` | `PreCompact` | Rete di sicurezza **prima** della compattazione (lossy): salva backup del transcript + un checkpoint Markdown in `~/.claude/state/{repo}/`, aggiorna `LAST_CHECKPOINT`, logga. Async. |
| `repo-context.sh` | `SessionStart` (`source=compact`) | Dopo una compattazione re-inietta il tech-stack curato e **segnala l'ultimo checkpoint**, così le decisioni non vanno perse. |

**Timing — importante.** La compattazione **automatica** non è negoziabile: quando scatta,
`PreCompact` può solo salvare un checkpoint, non chiedere conferma. Per questo la governance
agisce **prima** della soglia, guidata dal segnale di budget + dalla policy. Il `/compact`
manuale resta sempre nelle mani dell'utente.

**Soglie configurabili** (variabili d'ambiente, default tarati su un proxy euristico a byte):

```text
CTX_SOFT_MB=1.5   # banda "soft": contesto in crescita
CTX_WARN_MB=3.0   # banda "warn": agisci ora, prima dell'auto-compact
```

Tara le soglie sul tuo flusso reale dopo qualche sessione (regola *osserva-poi-astrai*).

**Stato fuori dai repo.** Checkpoint, log e file di banda vivono in `~/.claude/state/{repo}/`,
coerente col vincolo di tenere tutto **fuori** dai repository di progetto.

### Tracking & taratura delle soglie

Le soglie non si indovinano: si **misurano**. Il kit registra il dato autorevole della
finestra di contesto e ti propone i valori.

| Componente | Ruolo |
| --- | --- |
| `statusline.sh` (`statusLine`) | A ogni turno mostra `modello · dir · branch · ctx %` e **logga** il `used_percentage` reale (token, non stima) in `~/.claude/state/{repo}/ctx-samples.tsv`. Scrive anche `last-ctx-pct` usato dal budget hook. |
| `context-budget.sh` | Ora preferisce il **% token reale** scritto dalla statusLine (soglie `CTX_WARN_PCT`/`CTX_SOFT_PCT`); usa i byte del transcript solo come fallback se quel dato manca o è più vecchio di `CTX_PCT_MAX_AGE` s. |
| `pre-compact.sh` | Registra in `compaction-log.tsv` **trigger** (`auto`/`manual`), **% al compattamento** e **MB transcript**: così sai *a che livello* è scattato davvero l'auto-compact. |
| `ctx-stats.sh` | Legge i log e **consiglia** le soglie: `~/.claude/hooks/ctx-stats.sh [repo|all]`. |

**Flusso di taratura.** Lavora 2–3 sessioni lunghe con la statusLine attiva, poi:

```bash
~/.claude/hooks/ctx-stats.sh
```

Ti stampa picco raggiunto, a che % è scattato l'auto-compact e gli `export` consigliati,
es.:

```text
→ auto-compact osservato a partire da ~83%
  export CTX_WARN_PCT=75
  export CTX_SOFT_PCT=60
```

Metti gli `export` nel tuo `~/.bashrc`/`~/.zshrc` e il segnale di budget scatterà al livello
giusto **prima** dell'auto-compact. (Regola osserva-poi-astrai: parti dai default, misura, affina.)

**Soglie disponibili.**

```text
# preferite (token reali, servono statusLine)
CTX_WARN_PCT=78   CTX_SOFT_PCT=60   CTX_PCT_MAX_AGE=300
# fallback euristico (byte transcript, senza statusLine)
CTX_WARN_MB=3.0   CTX_SOFT_MB=1.5
```

**Fonti autorevoli a runtime.** Per un controllo manuale, in sessione hai i comandi
`/context` (ripartizione dei token: system prompt, tool, memory, history) e `/status`
(snapshot modello + % finestra). La statusLine è la stessa fonte, ma persistente e loggata.

**Hai già una tua statusLine?** L'installer non la sovrascrive (la salva come `.new`).
In quel caso tieni la tua e incolla dentro solo il blocco `TRACKING` di `statusline.sh`
(scrive `last-ctx-pct` e appende `ctx-samples.tsv`).
