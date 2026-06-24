# Claude Context Kit — Installazione

Contesto persistente e governato per **Claude Code**, tenuto **fuori dai repo**
(la configurazione resta fuori dai repository di progetto).

## Cosa fa
- **`CLAUDE.md` globale** (sempre caricato): identità Senior Engineer, policy, formato output.
- **`settings.json`**: blocca via *permessi* i comandi git che modificano lo stato
  (`commit/push/add/merge/rebase/reset/...`) e registra l'hook di avvio.
- **`hooks/repo-context.sh`** (SessionStart): a ogni avvio inietta il `tech-stack.md` curato
  del repo + un albero cartelle **generato al volo** (mai stantio). Se il contesto manca, lo segnala.
- **`skills/repo-onboarding/`** (skill): deduce lo stack di un repo (package manager, framework,
  integration/island Astro, adapter SSR, server Node, comandi da `package.json`) e stampa una
  **bozza** di `tech-stack.md` da rivedere.
- **`repos/_TEMPLATE/tech-stack.md`**: template di riferimento.

## ⚠️ Claude Code vs Claude Desktop
Questo kit è per **Claude Code** (terminale / IDE / superficie agentica desktop), che legge
`~/.claude/settings.json` e `~/.claude/CLAUDE.md` — **identico** comunque lo lanci.
La **app Claude Desktop "chat"** è un prodotto separato: usa `claude_desktop_config.json`
(solo MCP server + preferenze) e **non** esegue questi hook. Non c'è nessun `settings_desktop`
da configurare. Per le sessioni di architettura su Desktop chat non serve fare nulla.

## Installazione (modello clone-in-place)
La root del repo **è** `~/.claude`: non si copia, si clona/estrae lì e si versiona.

**Macchina nuova (nessun `~/.claude`):**
```bash
git clone <url-del-tuo-fork-privato> ~/.claude
cd ~/.claude && bash bootstrap.sh
```

**`~/.claude` già esistente:** non puoi clonare in una cartella non vuota. Porta dentro i
file del kit senza sovrascrivere i tuoi (`cp -n`/`cp -rn`), poi `bash ~/.claude/bootstrap.sh`.
Vedi il README per i comandi completi e il merge di `CLAUDE.md`/`settings.json`.

`bootstrap.sh` non copia nulla: rende eseguibili gli hook, crea `state/` e `repos/`
(git-ignored) e inizializza il repo git se manca (nessun commit automatico).

## Versionare in sicurezza
Il `.gitignore` esclude segreti (`.credentials.json`, `.claude.json`), transcript
(`projects/`, `history.jsonl`), stato runtime (`todos/`, `plugins/`, …), lo `state/`
del kit e i **contesti repo reali** (`repos/*` tranne `_TEMPLATE`). Commit della sola config:
```bash
cd ~/.claude
git add .gitignore CLAUDE.md settings.json statusline.sh hooks/ repos/_TEMPLATE/ \
        README.md INSTALL.md bootstrap.sh
git commit -m "feat: claude context kit"   # push solo su remote PRIVATO
```
Per versionare un contesto repo consapevolmente: `git add -f repos/<repo>/`.
Controlla sempre `git status` prima del primo push.

## Dopo il bootstrap
1. **Riavvia Claude Code**.
2. `/hooks` → approva lo snapshot degli hook.
3. `/memory` → conferma che `~/.claude/CLAUDE.md` è caricato.
4. Verifica che la statusLine mostri `ctx %`.

## Primo uso in un nuovo repo
Apri Claude Code nel repo. L'hook segnala "CONTESTO MANCANTE" e Claude:
1. esegue `~/.claude/skills/repo-onboarding/scripts/new-repo-context.sh` e ti mostra la **bozza** dedotta;
2. **dopo la tua conferma** la salva in `~/.claude/repos/{nome-repo}/tech-stack.md`
   (completando "Architettura" e "Gotcha").

Da quel momento, a ogni avvio in quel repo il contesto viene iniettato in automatico.

## Personalizzazione
- **Blocco git**: aggiungi/togli pattern in `permissions.deny` (`settings.json`).
- **Cartelle ignorate** nell'albero: variabile `ignore` in `repo-context.sh`.
- **Segnali di stack** riconosciuti: array `signals` in `skills/repo-onboarding/scripts/new-repo-context.sh`.

## Governance del contesto (nuovo)
Per le sessioni lunghe di coding il kit aggiunge due hook + una policy che **propone**
(mai esegue da sé) la compattazione al cambio di task o sotto pressione di contesto:

- **`hooks/context-budget.sh`** (`UserPromptSubmit`): oltre soglia inietta un segnale
  `CONTEXT BUDGET` (`soft`/`warn`), con throttle per banda. Esce sempre 0.
- **`hooks/pre-compact.sh`** (`PreCompact`): prima della compattazione salva transcript +
  checkpoint in `~/.claude/state/{repo}/` e aggiorna `LAST_CHECKPOINT`.
- **`repo-context.sh`** ora è *source-aware*: con `source=compact` re-inietta il contesto
  e segnala l'ultimo checkpoint.
- **`CLAUDE.md`** contiene la policy "Governance del contesto": proponi `/compact` o `/clear`
  con motivazione e manifesto MANTIENI/SCARTA, poi attendi conferma.

Dopo l'install, in `/hooks` troverai registrati anche `UserPromptSubmit` e `PreCompact`.

Soglie regolabili: `CTX_SOFT_MB` (default 1.5), `CTX_WARN_MB` (default 3.0).

### Tracking delle soglie (nuovo)
- **`statusline.sh`** (`statusLine`): mostra `ctx %` e logga il `used_percentage` reale
  in `~/.claude/state/{repo}/ctx-samples.tsv`. L'installer non sovrascrive una statusLine
  esistente (salva `.new`): in tal caso incolla solo il blocco `TRACKING`.
- **`hooks/ctx-stats.sh [repo|all]`**: legge i log e consiglia `CTX_WARN_PCT`/`CTX_SOFT_PCT`.
- `context-budget.sh` ora usa il **% token reale** (fallback byte) e `pre-compact.sh` logga
  trigger + % + MB a ogni compattazione.

Dopo qualche sessione lunga: `~/.claude/hooks/ctx-stats.sh` → applica gli `export` suggeriti.

## Skill (governance & onboarding)
La procedura di **governance del contesto** e l'**onboarding repo** sono skill in
`~/.claude/skills/`. Claude Code le scopre all'avvio (nessuna registrazione in `settings.json`).
Dopo l'aggiunta: riavvia o esegui `/reload-skills`. Il grilletto resta in `CLAUDE.md` (residente,
sopravvive alla compattazione); le skill portano la procedura, caricata solo quando serve.
