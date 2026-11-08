/**
 * scripts/pwa_post_export.js
 * Script de automação pós-exportação / deploy Vercel do Beat 'em Up Sakas.
 *
 * Responsabilidades:
 * 1. Identificar o identificador único de build (SHA do commit Vercel / Git local / Deploy ID).
 * 2. Gerar public/version.json sem cache para detecção automática de releases.
 * 3. Atualizar public/index.service.worker.js com a nova CACHE_VERSION, self.skipWaiting(),
 *    e estratégia Network-First para navegação (index.html) com fallback offline.
 * 4. Carimbar a meta tag sakas-build-id em public/mobile_shell.html e public/index.html.
 * 5. Preservar 100% dos dados do usuário (IndexedDB, user://, LocalStorage).
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT_DIR = path.resolve(__dirname, '..');
const PUBLIC_DIR = path.join(ROOT_DIR, 'public');

function resolveBuildVersion() {
	if (process.env.VERCEL_GIT_COMMIT_SHA) {
		return process.env.VERCEL_GIT_COMMIT_SHA.trim().slice(0, 12);
	}
	if (process.env.VERCEL_DEPLOYMENT_ID) {
		return String(process.env.VERCEL_DEPLOYMENT_ID).trim();
	}
	try {
		const gitSha = execSync('git rev-parse --short HEAD', {
			cwd: ROOT_DIR,
			encoding: 'utf8',
			stdio: ['ignore', 'pipe', 'ignore'],
		}).trim();
		if (gitSha) return gitSha;
	} catch (_e) {
		// Git não disponível ou erro de execução
	}
	return 'v' + Date.now().toString(36);
}

function updateVersionJson(version) {
	const versionFile = path.join(PUBLIC_DIR, 'version.json');
	const payload = {
		version: version,
		builtAt: new Date().toISOString(),
		app: 'Beat Em Up - Sakas'
	};
	fs.writeFileSync(versionFile, JSON.stringify(payload, null, 2) + '\n', 'utf8');
	console.log(`[PWA Build] public/version.json gerado com versão: ${version}`);
}

function updateServiceWorker(version) {
	const swFile = path.join(PUBLIC_DIR, 'index.service.worker.js');
	if (!fs.existsSync(swFile)) {
		console.warn(`[PWA Build] Aviso: ${swFile} não encontrado. Pulando.`);
		return;
	}

	let content = fs.readFileSync(swFile, 'utf8');

	// 1. Atualiza CACHE_VERSION
	const versionRegex = /const\s+CACHE_VERSION\s*=\s*['"][^'"]*['"];/;
	if (versionRegex.test(content)) {
		content = content.replace(versionRegex, `const CACHE_VERSION = '${version}';`);
	} else {
		content = `const CACHE_VERSION = '${version}';\n` + content;
	}

	// 1.1 Atualiza CACHEABLE_FILES com pacotes modulares de public/packs/
	const packsDir = path.join(PUBLIC_DIR, 'packs');
	let extraPacks = ['packs/manifest.json'];
	if (fs.existsSync(packsDir)) {
		const packFiles = fs.readdirSync(packsDir);
		for (const f of packFiles) {
			if (f.endsWith('.pck')) {
				extraPacks.push(`packs/${f}`);
			}
		}
	}
	const cacheableRegex = /const\s+CACHEABLE_FILES\s*=\s*\[[^\]]*\];/;
	const baseCacheable = ['index.wasm', 'index.pck'];
	const fullCacheable = Array.from(new Set([...baseCacheable, ...extraPacks]));
	const newCacheableStr = `const CACHEABLE_FILES = ${JSON.stringify(fullCacheable)};`;
	if (cacheableRegex.test(content)) {
		content = content.replace(cacheableRegex, newCacheableStr);
	}

	// 2. Garante self.skipWaiting() no evento install
	if (!content.includes('// SAKAS_INSTALL_SKIP_WAITING')) {
		content = content.replace(
			/self\.addEventListener\('install',\s*\(event\)\s*=>\s*\{/,
			"self.addEventListener('install', (event) => {\n\t// SAKAS_INSTALL_SKIP_WAITING\n\tself.skipWaiting();"
		);
	}

	// 3. Garante self.clients.claim() no evento activate
	if (!content.includes('// SAKAS_ACTIVATE_CLAIM')) {
		content = content.replace(
			/return\s*\('navigationPreload'\s*in\s*self\.registration\)/,
			"// SAKAS_ACTIVATE_CLAIM\n\t\treturn self.clients.claim().then(() => ('navigationPreload' in self.registration)"
		);
	}

	// 4. Garante tratamento de mensagem SKIP_WAITING
	if (!content.includes("msg === 'SKIP_WAITING'")) {
		content = content.replace(
			/if\s*\(msg\s*===\s*'claim'\)/,
			"if (msg === 'claim' || msg === 'SKIP_WAITING' || (typeof msg === 'object' && msg && msg.type === 'SKIP_WAITING'))"
		);
	}

	// 5. Garante estratégia Network-First para navegação (index.html) com fallback offline
	if (!content.includes('// SAKAS_NETWORK_FIRST_NAV')) {
		const navSearch = /if\s*\(isNavigate\)\s*\{[\s\S]*?const\s+missing\s*=\s*fullCache\.some[\s\S]*?\}\s*\}\s*let\s+cached\s*=\s*await\s+cache\.match\(event\.request\);/;
		const navReplacement = `if (isNavigate) {
					// SAKAS_NETWORK_FIRST_NAV: Busca index.html na rede para receber novo deploy imediatamente.
					// Se estiver offline ou a rede falhar, utiliza o cache local ou a página offline.
					try {
						const netResp = await fetch(event.request);
						if (netResp && netResp.ok) {
							cache.put(event.request, netResp.clone());
							return ensureCrossOriginIsolationHeaders(netResp);
						}
					} catch (_err) {
						// Offline: continua para o cache abaixo
					}
					const cachedNav = await cache.match(event.request);
					if (cachedNav != null) {
						return ensureCrossOriginIsolationHeaders(cachedNav);
					}
					return caches.match(OFFLINE_URL);
				}
				let cached = await cache.match(event.request);`;

		if (navSearch.test(content)) {
			content = content.replace(navSearch, navReplacement);
		}
	}

	fs.writeFileSync(swFile, content, 'utf8');
	console.log(`[PWA Build] public/index.service.worker.js atualizado com CACHE_VERSION = '${version}'`);
}

function updateHtmlMetaTag(filePath, version) {
	if (!fs.existsSync(filePath)) return;
	let content = fs.readFileSync(filePath, 'utf8');

	const metaTag = `<meta name="sakas-build-id" content="${version}">`;
	const metaRegex = /<meta\s+name=["']sakas-build-id["']\s+content=["'][^"']*["']\s*\/?>/i;

	if (metaRegex.test(content)) {
		content = content.replace(metaRegex, metaTag);
	} else if (content.includes('</head>')) {
		content = content.replace('</head>', `\t${metaTag}\n</head>`);
	}

	fs.writeFileSync(filePath, content, 'utf8');
	console.log(`[PWA Build] ${path.basename(filePath)} atualizado com meta sakas-build-id = '${version}'`);
}

function main() {
	console.log('[PWA Build] Iniciando automação pós-exportação / deploy...');
	const version = resolveBuildVersion();
	console.log(`[PWA Build] Versão canônica detectada: ${version}`);

	updateVersionJson(version);
	updateServiceWorker(version);
	updateHtmlMetaTag(path.join(PUBLIC_DIR, 'mobile_shell.html'), version);
	updateHtmlMetaTag(path.join(PUBLIC_DIR, 'index.html'), version);

	console.log('[PWA Build] Automação concluída com sucesso!');
}

main();
