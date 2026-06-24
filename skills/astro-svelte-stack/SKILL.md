---
name: astro-svelte-stack
description: Usa quando scrivi o modifichi file .astro o .svelte (o astro.config). Impone di rilevare la versione di Astro (4–7) e Svelte (3–5) dal package.json PRIMA di scrivere codice, applicare il paradigma giusto (Content Layer, Runes, import.meta.glob, ClientRouter), l'architettura zero-overkill (BFF/service layer, niente fetch nei componenti, componenti "dumb", stato cross-page) e cercare sul web con la versione nella query. Dettaglio breaking change in references/version-matrix.md.
paths: ["**/*.astro", "**/*.svelte", "**/astro.config.*"]
---

# Stack Astro (SSR) + Svelte — regole operative

## 0. Rileva la versione PRIMA di scrivere (obbligatorio)
Leggi `package.json` (o usa l'output di `repo-onboarding` / `new-repo-context.sh`).
Dichiara in chiaro: `[ARCH CHECK] Astro vX + Svelte vY`, poi applica il paradigma corretto.
In dubbio su una sintassi → **ricerca web con la versione nella query** (vedi §4).
Per i breaking change consulta `references/version-matrix.md` **solo se serve**.

## 1. Architettura (zero overkill)
- **Astro = guscio Server/Routing**: layout, SEO, sicurezza (middleware), fetch pesante in SSR.
- **Svelte = isola Client/UI**: interattività dentro la singola pagina.
- **Service layer (BFF)**: niente `fetch` sparse nei componenti. Centralizza le chiamate ai
  microservizi in `src/services/` (o `src/shared/api/`), funzioni TS pure (`getX`, `createY`).
  Se il microservizio cambia il JSON, aggiorni **solo** qui.
- **Componenti "dumb"**: il `.svelte` finale è quasi solo HTML + binding; fetch/stato/errori stanno
  in store o servizi. Il componente chiama `authStore.login(...)`, non fa fetch.
- **No prop drilling**: stato condiviso tra isole → store Svelte in un `.ts` condiviso (leggero),
  non Redux.

## 2. Stato (dipende dal ciclo di vita)
- Se ogni pagina è un'isola a sé (routing gestito da Astro), **ogni cambio pagina azzera lo stato
  Svelte in memoria**.
- Stato solo-client (preferenze UI, dati temporanei) → store sincronizzato con
  `localStorage` / `sessionStorage`.
- Stato che influisce sull'SSR iniziale → **URL (query params) o cookie** gestiti dal middleware.

## 3. Idratazione
- `client:visible` / `client:load` per le isole interattive.
- `client:only="svelte"` se il componente dipende da `window`/`location` o per una SPA Svelte
  interna (niente prerender SSR di quei componenti).

## 4. Protocollo di ricerca web
- Includi SEMPRE la versione: non "fetch data in Astro" ma `Astro v6 content layer fetch` /
  `Svelte 5 runes shared store`.
- Privilegia le guide ufficiali di migrazione: `site:docs.astro.build "Upgrade to Astro vX"`,
  `site:svelte.dev v5 migration`.
- Scarta esempi "ibridi" (es. Svelte 5 che usa ancora `export let` invece di `$props()`).

## 5. Zero overkill (Clean Code > Clean Architecture)
Niente interfacce/adapter in stile esagonale solo per mappare un JSON: usa la tipizzazione
strutturale di TS. **Eccezione**: core di business pesante e framework-agnostic (editor, calcoli,
tool complessi) → isolalo in TS puro che non sa cosa siano Astro/Svelte (testabile, portabile).
