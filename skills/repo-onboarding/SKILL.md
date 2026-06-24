---
name: repo-onboarding
description: Usa quando entri in un repo SENZA contesto curato e l'hook SessionStart segnala "CONTESTO MANCANTE". Deduce lo stack del repo (package manager, framework, Astro adapter/island, server Node, Go, comandi da package.json), propone una bozza di tech-stack.md e la salva solo dopo conferma in ~/.claude/repos/{repo}/. Invocabile anche con /repo-onboarding.
---

# Onboarding di un nuovo repo

Quando il contesto del repo è **MANCANTE**, crea il `tech-stack.md` curato con questo flusso
proponi→conferma (mai scrivere senza ok dell'utente).

## Passi
1. **Deduci lo stack** eseguendo lo script bundle:
   ```bash
   bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/repo-onboarding/scripts/new-repo-context.sh"
   ```
   (Opzionale: passa un percorso esplicito come primo argomento.)
   Lo script stampa una **BOZZA** Markdown con: package manager, TypeScript, monorepo,
   config Astro (output + adapter), server Node, modulo Go, dipendenze-segnale e comandi.

2. **Presenta la bozza** all'utente. Completa con giudizio umano le due sezioni che lo script
   lascia aperte:
   - **Architettura in breve**: dove vive la business logic, pattern (hexagonal / ports & adapters),
     confini tra pod.
   - **Gotcha / vincoli**: trappole note, file da non toccare, particolarità SSR/auth/flags.

3. **Attendi conferma o modifica.** Non scrivere nulla finché l'utente non approva.

4. **Solo dopo conferma**, salva in:
   ```text
   ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/repos/{nome-repo}/tech-stack.md
   ```
   Da quel momento l'hook `SessionStart` lo inietta in automatico a ogni avvio in quel repo.

## Vincoli 
- Tieni il file **breve e operativo** (< 60 righe): contesto minimo ad alto valore, non documentazione.
- **Mai** segreti nel file. **Mai** creare `.claude/` o `tech-stack.md` dentro un repository di progetto:
  il contesto vive solo sotto `~/.claude/repos/`.
