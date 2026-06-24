# Matrice versioni — Astro 4→7 / Svelte 3→5

> **Indicativa, non legge.** Le versioni evolvono: questa è una bussola per orientarsi.
> In caso di dubbio verifica sempre la doc ufficiale: `site:docs.astro.build "Upgrade to Astro vX"`.

## Astro

**v4** — SSR classico; contesto via `context.locals`; `Astro.glob()` e `<ViewTransitions />`
disponibili; content collections tradizionali in `src/content/`.

**v5** — **Content Layer API**: loader tipati con Zod in `src/content/config.ts` (modo consigliato
per dati da microservizi). `Astro.glob()` **deprecato** (→ `getCollection()` o `import.meta.glob()`);
`<ViewTransitions />` → `<ClientRouter />`; le collezioni non dichiarate in config non sono più tollerate.

**v6** (stabile, 2026) — **breaking**:
- `Astro.glob()` **RIMOSSO** → `import.meta.glob()` (non restituisce più una Promise: adegua il codice).
- `emitESMImage()` rimosso → `emitImageMetadata()`.
- `<ViewTransitions />` rimosso → **`<ClientRouter />`** (cambia anche il timing degli eventi
  `astro:page-load` / `astro:after-swap`: testa).
- **Node 22+** (droppati Node 18/20); **Vite 7**; **Zod 4** (importa Zod da `astro/zod`).
- Cloudflare: `Astro.locals.runtime` rimosso (accesso diretto alle platform API; dev su `workerd`).
- Live content collections stabili; **CSP nativa** (`security.csp`); compilatore Rust sperimentale.

**v7** (giu 2026) — focus velocità:
- Compilatore `.astro` in **Rust** (default); Markdown/MDX via **Sätteri** (Rust).
- **Rendering a coda**; **Vite 8 + Rolldown**; route caching stabile; CDN cache providers sperimentali.
- **Advanced Routing**: entrypoint `src/fetch.ts` per il controllo della request pipeline
  → **nome riservato**: NON chiamare così i file del service layer.
- Supporto agli agenti AI: rilevamento agenti, dev server in background, log JSON strutturati.

## Svelte

**3 / 4** — store classici (`writable` / `readable` / `derived`); props con `export let`;
reattività con `$:`. La logica condivisa si estrae in Custom Store (funzione che torna uno store).

**5** — **Runes**: `$state`, `$derived`, `$effect`, `$props()` (al posto di `export let`).
La logica condivisa si fa con funzioni/classi che usano le runes (anche fuori dai componenti, in `.svelte.ts`).
**Non mescolare** sintassi 4 e 5.

---

**Regola d'innesco:** se Astro ≥ 5 **o** Svelte ≥ 5 → applica Content Layer / Runes e **vieta** le
API rimosse (`Astro.glob`, `<ViewTransitions />`, store-only dove servono runes). Se i framework sono
≤ 4 resta sulle API classiche: non introdurre sintassi nuove in un progetto non ancora migrato.
