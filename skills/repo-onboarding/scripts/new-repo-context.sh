#!/usr/bin/env bash
# new-repo-context.sh — deduce lo stack di un repo e stampa una BOZZA di tech-stack.md.
# NON scrive nulla: la revisione e l'applicazione spettano a te (o all'agente dopo
# la tua conferma) in ~/.claude/repos/{nome-repo}/tech-stack.md.
#
# Uso:
#   ~/.claude/hooks/new-repo-context.sh [percorso-repo]   # default: cwd / git root
#
# Strategia: le dipendenze sono la fonte affidabile (framework, integration Astro,
# adapter SSR, server). Da astro.config.* si leggono solo `output` e adapter, che
# nelle deps non ci sono. Astro.config può essere .mjs/.ts/.js/.cjs.

set -uo pipefail

target="${1:-$PWD}"
repo_root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || echo "$target")"
repo_name="$(basename "$repo_root")"
cd "$repo_root" 2>/dev/null || { echo "Percorso non valido: $target" >&2; exit 1; }
today="$(date +%Y-%m-%d)"

# --- package manager (da lockfile) ---
pm="(non rilevato)"
[[ -f package-lock.json ]] && pm="npm"
[[ -f yarn.lock ]]         && pm="yarn"
[[ -f bun.lockb || -f bun.lock ]] && pm="bun"
[[ -f pnpm-lock.yaml ]]    && pm="pnpm"

# --- typescript / monorepo ---
ts="no"; [[ -f tsconfig.json ]] && ts="sì (tsconfig.json)"
mono="no"; [[ -f pnpm-workspace.yaml ]] && mono="sì (pnpm-workspace.yaml)"

# --- astro.config.* : output mode + adapter ---
astro_cfg="$(ls astro.config.* 2>/dev/null | head -n1 || true)"
astro_output=""; astro_adapter=""
if [[ -n "$astro_cfg" ]]; then
  astro_output="$(grep -oE "output:[[:space:]]*['\"](static|server|hybrid)['\"]" "$astro_cfg" \
                  | grep -oE "(static|server|hybrid)" | head -n1 || true)"
  astro_adapter="$(grep -oE "@astrojs/(node|vercel|netlify|cloudflare)" "$astro_cfg" | head -n1 || true)"
fi

# --- server Node che monta l'app Astro (SSR in server custom) ---
server_file="$(ls server.{js,ts,mjs,cjs} src/server.{js,ts,mjs} server/index.{js,ts,mjs} 2>/dev/null | head -n1 || true)"
[[ -z "$server_file" && -d server ]] && server_file="server/ (cartella presente)"

# --- Go ---
go_mod=""; go_ver=""
if [[ -f go.mod ]]; then
  go_mod="$(grep -m1 '^module ' go.mod | awk '{print $2}')"
  go_ver="$(grep -m1 '^go '     go.mod | awk '{print $2}')"
fi

# --- package.json: deps-segnale + scripts (parse robusto via node) ---
pkg_block=""
if [[ -f package.json ]] && command -v node >/dev/null 2>&1; then
  pkg_block="$(PKG="$repo_root/package.json" node <<'NODE'
const fs = require('fs');
const p = JSON.parse(fs.readFileSync(process.env.PKG, 'utf8'));
const deps = { ...(p.dependencies||{}), ...(p.devDependencies||{}) };
const names = Object.keys(deps);
const has = re => names.filter(n => re.test(n));
const signals = [
  ['Astro',                     /^astro$/],
  ['Astro adapter Node (SSR)',  /^@astrojs\/node$/],
  ['Astro adapter (altro)',     /^@astrojs\/(vercel|netlify|cloudflare)$/],
  ['Island Svelte',             /^@astrojs\/svelte$/],
  ['Island React',              /^@astrojs\/react$/],
  ['Island Vue',                /^@astrojs\/vue$/],
  ['MDX',                       /^@astrojs\/mdx$/],
  ['Tailwind',                  /tailwind/],
  ['Svelte',                    /^svelte$/],
  ['SvelteKit',                 /^@sveltejs\/kit$/],
  ['React',                     /^react$/],
  ['Next.js',                   /^next$/],
  ['Vue',                       /^vue$/],
  ['Express',                   /^express$/],
  ['Fastify',                   /^fastify$/],
  ['Vite',                      /^vite$/],
  ['TypeScript',                /^typescript$/],
  ['Auth (Keycloak/OIDC/JWT)',  /(keycloak|openid|oidc|^jose$|jsonwebtoken)/],
  ['Feature flags (Unleash)',   /unleash/],
  ['E2E (Playwright)',          /playwright/],
  ['Test (Vitest)',             /vitest/],
];
const found = signals
  .map(([label, re]) => { const m = has(re); return m.length ? [label, m.map(n => `${n}@${deps[n]}`)] : null; })
  .filter(Boolean);

const out = [];
out.push('### Dipendenze-segnale rilevate (da package.json)');
if (found.length) for (const [label, pkgs] of found) out.push(`- **${label}**: ${pkgs.join(', ')}`);
else out.push('- (nessun segnale noto)');

out.push('');
out.push('### Comandi (da `scripts`) — usali così come sono');
const s = p.scripts || {}, keys = Object.keys(s);
if (keys.length) for (const k of keys) out.push(`- \`${k}\`: \`${s[k]}\``);
else out.push('- (nessuno script definito)');
console.log(out.join('\n'));
NODE
)"
fi

# ====================== BOZZA tech-stack.md ======================
echo "# Tech Stack — $repo_name   (BOZZA — rivedi prima di salvare)"
echo "> Aggiornato: $today · generato da new-repo-context.sh"
echo "> Destinazione dopo conferma: ~/.claude/repos/$repo_name/tech-stack.md"
echo
echo "## Rilevato automaticamente"
echo "- Package manager: $pm"
echo "- TypeScript: $ts"
[[ "$mono" != "no" ]] && echo "- Monorepo/workspaces: $mono"
if [[ -n "$astro_cfg" ]]; then
  echo "- Astro config: \`$astro_cfg\` — output: \`${astro_output:-?}\` — adapter: \`${astro_adapter:-nessuno}\`"
  [[ "$astro_output" == "server" || -n "$astro_adapter" ]] && echo "  → **Astro in modalità SSR**"
fi
[[ -n "$server_file" ]] && echo "- Server Node: \`$server_file\` → probabile **app Astro montata in un server custom** (verifica)"
[[ -n "$go_mod" ]] && echo "- Go module: \`$go_mod\` (go ${go_ver:-?})"
echo
[[ -n "$pkg_block" ]] && { echo "$pkg_block"; echo; }
echo "## Architettura in breve   ← DA COMPLETARE (giudizio umano)"
echo "- Dove vive la business logic, pattern (hexagonal / ports & adapters), confini tra pod."
echo
echo "## Gotcha / vincoli        ← DA COMPLETARE"
echo "- Trappole note, file da non toccare, particolarità SSR/auth/flags."
