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
 * 5. Garantir "serviceWorker": "index.service.worker.js" no IND_CONFIG de ambos os HTMLs.
 * 6. Garantir ciclo de auto-update PWA e transição fullscreen standalone.
 * 7. Enriquecer public/index.manifest.json com display_override fullscreen e metadados oficiais.
 * 8. Preservar 100% dos dados do usuário (IndexedDB, user://, LocalStorage).
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
		let gitSha = execSync('git rev-parse --short HEAD', {
			cwd: ROOT_DIR,
			encoding: 'utf8',
			stdio: ['ignore', 'pipe', 'ignore'],
		}).trim();
		if (gitSha) {
			try {
				const dirtyFiles = execSync('git status --porcelain -uno', {
					cwd: ROOT_DIR,
					encoding: 'utf8',
					stdio: ['ignore', 'pipe', 'ignore'],
				}).trim().split('\n').filter(Boolean);
				const codeChanges = dirtyFiles.filter(line => {
					const f = line.slice(3).trim();
					return !f.startsWith('public/version.json')
						&& !f.startsWith('public/index.service.worker.js')
						&& !f.startsWith('public/index.html')
						&& !f.startsWith('public/mobile_shell.html')
						&& !f.startsWith('public/packs/manifest.json');
				});
				if (codeChanges.length > 0) {
					gitSha += '-d' + Math.floor(Date.now() / 1000).toString(36);
				}
			} catch (_) {}
			return gitSha;
		}
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
					let cachedNav = await cache.match(event.request);
					if (cachedNav == null) {
						cachedNav = await cache.match('index.html');
					}
					if (cachedNav == null) {
						cachedNav = await cache.match('/');
					}
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

function ensureServiceWorkerInConfig(filePath) {
	if (!fs.existsSync(filePath)) return;
	let content = fs.readFileSync(filePath, 'utf8');

	if (!content.includes('"serviceWorker"')) {
		content = content.replace(
			/"gdextensionLibs"\s*:\s*\[\]/,
			'"gdextensionLibs": [],\n\t\t\t"serviceWorker": "index.service.worker.js"'
		);
		fs.writeFileSync(filePath, content, 'utf8');
		console.log(`[PWA Build] ${path.basename(filePath)} atualizado com "serviceWorker" em IND_CONFIG.`);
	}
}

function ensurePwaLifecycle(filePath) {
	if (!fs.existsSync(filePath)) return;
	let content = fs.readFileSync(filePath, 'utf8');

	if (!content.includes('// SAKAS AUTO-UPDATE')) {
		const oldBlockRegex = /\(function\(\)\s*\{[\r\n\s]*if\s*\(!\('serviceWorker'\s*in\s*navigator\)\)\s*return;[\s\S]*?navigator\.serviceWorker\.getRegistration\(\)\.then\(\(reg\)\s*=>\s*\{[\s\S]*?\}\);\s*\}\)\(\);/;

		const modernBlock = `(function() {
			if (!('serviceWorker' in navigator)) return;

			let deferredInstallPrompt = null;
			window.addEventListener('beforeinstallprompt', (e) => {
				e.preventDefault();
				deferredInstallPrompt = e;
				if (!sessionStorage.getItem('sakas_install_dismissed') && installBanner) {
					installBanner.style.display = 'flex';
				}
			});

			// Ao instalar o app, fecha banner e entra automaticamente em tela cheia/standalone
			window.addEventListener('appinstalled', () => {
				console.log('[PWA] Aplicativo instalado com sucesso no dispositivo!');
				if (installBanner) installBanner.style.display = 'none';
				sessionStorage.setItem('sakas_installed', '1');
				if (!window.matchMedia('(display-mode: standalone)').matches && !navigator.standalone) {
					try {
						if (document.documentElement.requestFullscreen) {
							document.documentElement.requestFullscreen().catch(() => {});
						}
					} catch (_) {}
				}
			});

			if (btnInstall) {
				btnInstall.addEventListener('click', async () => {
					if (deferredInstallPrompt) {
						deferredInstallPrompt.prompt();
						const choice = await deferredInstallPrompt.userChoice;
						if (choice.outcome === 'accepted') {
							console.log('[PWA] Instalação aceita pelo usuário');
							if (installBanner) installBanner.style.display = 'none';
							try {
								if (document.documentElement.requestFullscreen) {
									await document.documentElement.requestFullscreen().catch(() => {});
								}
							} catch (_) {}
						}
						deferredInstallPrompt = null;
					} else {
						// Instrução iOS Safari
						alert('Para instalar no iPhone/iPad: Toque em Compartilhar (⎋) na barra do Safari e selecione "Adicionar à Tela de Início" (⊞).');
					}
				});
			}

			if (btnCloseBanner) {
				btnCloseBanner.addEventListener('click', () => {
					sessionStorage.setItem('sakas_install_dismissed', '1');
					if (installBanner) installBanner.style.display = 'none';
				});
			}

			// SAKAS AUTO-UPDATE: Recarrega automaticamente quando um novo SW é ativado
			let hadControllerOnLoad = !!navigator.serviceWorker.controller;
			let refreshing = false;
			navigator.serviceWorker.addEventListener('controllerchange', () => {
				if (!hadControllerOnLoad) {
					hadControllerOnLoad = true;
					console.log('[PWA] Primeiro Service Worker ativo. Nenhuma recarga necessária.');
					return;
				}
				if (refreshing) return;
				refreshing = true;
				console.log('[PWA] Novo Service Worker ativo. Recarregando página para aplicar nova versão...');
				window.location.reload();
			});

			async function checkForPublishedRelease(registration) {
				try {
					if (registration) {
						registration.update().catch(() => {});
					}
					const resp = await fetch('version.json?_t=' + Date.now(), {
						cache: 'no-store',
						headers: { 'Accept': 'application/json' }
					});
					if (!resp.ok) return;
					const data = await resp.json();
					const serverVersion = data && data.version ? String(data.version) : '';
					if (!serverVersion) return;

					const localMeta = document.querySelector('meta[name="sakas-build-id"]');
					const currentVersion = localMeta ? localMeta.getAttribute('content') : '';

					if (currentVersion && currentVersion !== 'initial' && serverVersion !== currentVersion) {
						console.log(\`[PWA] Nova versão detectada: \${serverVersion} (local: \${currentVersion})\`);
						if (registration) {
							if (registration.waiting) {
								registration.waiting.postMessage('SKIP_WAITING');
								registration.waiting.postMessage('claim');
							} else {
								registration.update().then(() => {
									if (registration.waiting) {
										registration.waiting.postMessage('SKIP_WAITING');
									}
								}).catch(() => {});
							}
						}
					}
				} catch (_e) {}
			}

			// Registra ativamente o Service Worker e monitora ciclo de atualização
			navigator.serviceWorker.register('index.service.worker.js').then((registration) => {
				console.log('[PWA] Service Worker registrado com sucesso:', registration.scope);
				registration.addEventListener('updatefound', () => {
					const newWorker = registration.installing;
					if (newWorker) {
						newWorker.addEventListener('statechange', () => {
							if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
								console.log('[PWA] Nova versão pronta no cache. Ativando imediatamente...');
								newWorker.postMessage('SKIP_WAITING');
							}
						});
					}
				});
				checkForPublishedRelease(registration);
			}).catch((err) => {
				console.warn('[PWA] Falha ao registrar Service Worker:', err);
			});
		})();`;

		if (oldBlockRegex.test(content)) {
			content = content.replace(oldBlockRegex, modernBlock);
			fs.writeFileSync(filePath, content, 'utf8');
			console.log(`[PWA Build] ${path.basename(filePath)} atualizado com ciclo PWA modernizado.`);
		}
	}
}

function updateHtmlFileSizes(filePath) {
	if (!fs.existsSync(filePath)) return;
	let content = fs.readFileSync(filePath, 'utf8');

	const sizes = {};
	const wasmPath = path.join(PUBLIC_DIR, 'index.wasm');
	const pckPath = path.join(PUBLIC_DIR, 'index.pck');
	if (fs.existsSync(wasmPath)) sizes['index.wasm'] = fs.statSync(wasmPath).size;
	if (fs.existsSync(pckPath)) sizes['index.pck'] = fs.statSync(pckPath).size;

	const packsDir = path.join(PUBLIC_DIR, 'packs');
	if (fs.existsSync(packsDir)) {
		const files = fs.readdirSync(packsDir);
		for (const file of files) {
			if (file.endsWith('.pck')) {
				const full = path.join(packsDir, file);
				sizes[`packs/${file}`] = fs.statSync(full).size;
			}
		}
	}

	const fileSizesJson = JSON.stringify(sizes);
	const fileSizesRegex = /"fileSizes"\s*:\s*\{[^}]*\}/g;
	if (fileSizesRegex.test(content)) {
		content = content.replace(fileSizesRegex, `"fileSizes":${fileSizesJson}`);
		fs.writeFileSync(filePath, content, 'utf8');
		console.log(`[PWA Build] ${path.basename(filePath)} atualizado com fileSizes completos (${Object.keys(sizes).length} arquivos).`);
	}
}

function enrichManifest() {
	const manifestPath = path.join(PUBLIC_DIR, 'index.manifest.json');
	if (!fs.existsSync(manifestPath)) return;
	try {
		const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
		manifest.id = "/";
		manifest.name = "Beat 'em Up Sakas - A Ultima Ficha";
		manifest.short_name = "Sakas";
		manifest.description = "Beat 'em Up retro Neo-16-bit ambientado na Sao Paulo dos anos 90.";
		manifest.theme_color = "#060814";
		manifest.background_color = "#060814";
		manifest.display = "standalone";
		manifest.display_override = ["standalone", "minimal-ui"];
		delete manifest.orientation;
		manifest.start_url = "/";
		manifest.scope = "/";
		manifest.prefer_related_applications = false;
		manifest.launch_handler = { client_mode: "focus-existing" };
		manifest.icons = [
			{
				"sizes": "144x144",
				"src": "index.144x144.png",
				"type": "image/png",
				"purpose": "any"
			},
			{
				"sizes": "144x144",
				"src": "index.144x144.png",
				"type": "image/png",
				"purpose": "maskable"
			},
			{
				"sizes": "180x180",
				"src": "index.180x180.png",
				"type": "image/png",
				"purpose": "any"
			},
			{
				"sizes": "180x180",
				"src": "index.180x180.png",
				"type": "image/png",
				"purpose": "maskable"
			},
			{
				"sizes": "192x192",
				"src": "index.192x192.png",
				"type": "image/png",
				"purpose": "any"
			},
			{
				"sizes": "192x192",
				"src": "index.192x192.png",
				"type": "image/png",
				"purpose": "maskable"
			},
			{
				"sizes": "512x512",
				"src": "index.512x512.png",
				"type": "image/png",
				"purpose": "any"
			},
			{
				"sizes": "512x512",
				"src": "index.512x512.png",
				"type": "image/png",
				"purpose": "maskable"
			}
		];
		fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n', 'utf8');
		console.log('[PWA Build] index.manifest.json enriquecido com metadados premium.');
	} catch (e) {
		console.warn('[PWA Build] Aviso ao enriquecer manifest:', e.message);
	}
}

function main() {
	console.log('[PWA Build] Iniciando automação pós-exportação / deploy...');

	// Trava de segurança para Vercel Cloud Build (evita publicar site quebrado se acionado via Git)
	if (process.env.VERCEL) {
		const pckPath = path.join(PUBLIC_DIR, 'index.pck');
		const wasmPath = path.join(PUBLIC_DIR, 'index.wasm');
		if (!fs.existsSync(pckPath) || !fs.existsSync(wasmPath)) {
			console.error('\n======================================================================');
			console.error('[ERRO DEVOPS CRÍTICO] Build Vercel cancelado por ausência de binários!');
			console.error('O repositório Git não armazena index.pck nem index.wasm (economia de LFS).');
			console.error('Para publicar o jogo com todos os arquivos, execute no computador:');
			console.error('  tools\\deploy_web.bat');
			console.error('======================================================================\n');
			process.exit(1);
		}
	}

	const version = resolveBuildVersion();
	console.log(`[PWA Build] Versão canônica detectada: ${version}`);

	updateVersionJson(version);
	updateServiceWorker(version);
	
	const shellPath = path.join(PUBLIC_DIR, 'mobile_shell.html');
	const indexPath = path.join(PUBLIC_DIR, 'index.html');

	updateHtmlMetaTag(shellPath, version);
	updateHtmlMetaTag(indexPath, version);
	
	ensureServiceWorkerInConfig(shellPath);
	ensureServiceWorkerInConfig(indexPath);
	
	ensurePwaLifecycle(shellPath);
	ensurePwaLifecycle(indexPath);
	
	updateHtmlFileSizes(indexPath);
	enrichManifest();

	console.log('[PWA Build] Automação concluída com sucesso!');
}

main();
