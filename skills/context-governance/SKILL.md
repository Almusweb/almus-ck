---
name: context-governance
description: Procedura per governare la compattazione del contesto. Usala quando arriva un segnale CONTEXT BUDGET (hook context-budget.sh) o quando l'utente cambia task, per proporre /compact o /clear con motivazione e manifesto MANTIENI/SCARTA prima dell'auto-compact. Invocabile anche a mano con /context-governance.
---

# Governance del contesto — procedura

> Il grilletto vive in `CLAUDE.md` (residente, sopravvive alla compattazione). Qui c'è la
> procedura dettagliata, caricata on-demand quando serve davvero agire.

Obiettivo: tenere il contesto snello nelle sessioni lunghe **senza mai agire da solo**.
Compattare/ripulire è una scelta dell'utente: tu **proponi con motivazione**, lui conferma o modifica.
Stesso patto proponi→conferma del `tech-stack.md`.

## Quando attivarsi
- **Cambio task**: il lavoro cambia unità — altro repo/pod, altra feature, altro layer
  (es. da debug auth → UI Design System), oppure l'utente dice "ok, altra cosa".
- **Pressione contesto**: segnale `CONTEXT BUDGET` (soft/warn), o hai accumulato materiale
  ormai inutile (dump di file letti, output di test già verdi).

## Protocollo (NON eseguire, proponi)
1. `/compact` e `/clear` li lancia **l'utente**: tu non puoi e non devi forzarli.
2. Allo scatto di un trigger, **fermati prima** di proseguire e proponi:
   - **`/compact`** se il nuovo task è correlato (vuoi tenere un riassunto), **oppure**
   - **`/clear`** se è del tutto scollegato (il contesto repo viene re-iniettato in automatico
     dall'hook `SessionStart`, quindi non perdi lo stack);
   - una **motivazione** breve e un **manifesto MANTIENI / SCARTA** esplicito;
   - per `/compact`, anche la **stringa pronta**: `/compact mantieni: …; scarta: …`.
3. **Attendi conferma o modifica.** Se l'utente cambia il manifesto, applica le sue scelte.
   Non iniziare il nuovo task finché non ha deciso.

## Timing critico
Agisci **prima** che scatti l'auto-compact: una volta partita la compattazione automatica non è
più negoziabile (l'hook `PreCompact` salva solo un checkpoint, non può chiederti conferma).
Budget alto + cambio task imminente → proponi subito.

## Dopo la compattazione
All'avvio con `source=compact` l'hook re-inietta il tech-stack curato e indica l'ultimo checkpoint
in `~/.claude/state/{repo}/`. Riparti da lì: le decisioni architetturali non sono perse; se ti
manca qualcosa, apri il checkpoint indicato.

## Template motivazione (esempio)
> Stiamo passando da *[task A]* a *[task B]*. Il contesto contiene molto materiale legato ad A
> (dump di file, log di test verdi) inutile per B. Propongo
> `/compact mantieni: decisioni su A ancora rilevanti, bug aperti; scarta: dump file, output test verdi`.
> Confermi, o vuoi cambiare cosa tenere?

## Esempi di stringa /compact
- Refactor → nuova feature correlata:
  `/compact mantieni: contratto API e decisioni di design; scarta: diff intermedi, log build`
- Debug chiuso → altro modulo:
  `/compact mantieni: causa radice e fix applicato; scarta: tentativi falliti, stack trace`
