/**
 * tests/test_pwa_cache_update.js
 * Suíte de testes automatizados para validação do sistema de atualização automática de cache PWA
 * no Beat 'em Up Sakas (Godot Web / Mobile / Vercel).
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assertTest(condition, message) {
	totalTests++;
	if (condition) {
		passedTests++;
		console.log(`  [OK] ${message}`);
	} else {
		failedTests++;
		console.error(`  [FALHA] ${message}`);
	}
}

console.log('\n===========================================================================');
console.log('SUÍTE DE TESTES: ATUALIZAÇÃO AUTOMÁTICA DE CACHE PWA (GODOT WEB / MOBILE)');
console.log('===========================================================================');

const ROOT = path.resolve(__dirname, '..');
const PUBLIC = path.join(ROOT, 'public');

// --- 1. Auditoria de Configuração da Vercel (vercel.json) ---
console.log('\n--- 1. Auditoria da Vercel (vercel.json) ---');
const vercelPath = path.join(ROOT, 'vercel.json');
assertTest(fs.existsSync(vercelPath), 'vercel.json existe na raiz do repositório');

if (fs.existsSync(vercelPath)) {
	const vercelConfig = JSON.parse(fs.readFileSync(vercelPath, 'utf8'));
	assertTest(vercelConfig.buildCommand === 'node scripts/pwa_post_export.js', "buildCommand aponta para 'node scripts/pwa_post_export.js'");
	assertTest(vercelConfig.outputDirectory === 'public', "outputDirectory é 'public'");

	const headers = vercelConfig.headers || [];
	const hasCoop = headers.some((h) =>
		h.headers && h.headers.some((kv) => kv.key === 'Cross-Origin-Opener-Policy' && kv.value === 'same-origin')
	);
	const hasCoep = headers.some((h) =>
		h.headers && h.headers.some((kv) => kv.key === 'Cross-Origin-Embedder-Policy' && kv.value === 'require-corp')
	);
	assertTest(hasCoop && hasCoep, 'Cabeçalhos COOP (same-origin) e COEP (require-corp) configurados para SharedArrayBuffer');

	const swHeaderRule = headers.find((h) =>
		h.source && (h.source.includes('service') || h.source.includes('version'))
	);
	assertTest(
		swHeaderRule != null &&
		swHeaderRule.headers.some((kv) => kv.key === 'Cache-Control' && kv.value.includes('must-revalidate')),
		'index.service.worker.js e version.json possuem política de revalidação imediata (must-revalidate)'
	);

	const wasmHeaderRule = headers.find((h) => h.source && h.source.includes('wasm'));
	assertTest(wasmHeaderRule != null, 'Binários WASM e PCK possuem regra explícita de controle de cache');
}

// --- 2. Execução e Saída do Script scripts/pwa_post_export.js ---
console.log('\n--- 2. Script de Automação Pós-Exportação / Deploy (pwa_post_export.js) ---');
const scriptPath = path.join(ROOT, 'scripts', 'pwa_post_export.js');
assertTest(fs.existsSync(scriptPath), 'scripts/pwa_post_export.js existe');

try {
	const out = execSync('node scripts/pwa_post_export.js', { cwd: ROOT, encoding: 'utf8' });
	assertTest(out.includes('Automação concluída com sucesso'), 'scripts/pwa_post_export.js executa sem erros');
} catch (e) {
	assertTest(false, `Falha ao executar scripts/pwa_post_export.js: ${e.message}`);
}

const versionJsonPath = path.join(PUBLIC, 'version.json');
assertTest(fs.existsSync(versionJsonPath), 'public/version.json foi gerado com sucesso');
if (fs.existsSync(versionJsonPath)) {
	const verData = JSON.parse(fs.readFileSync(versionJsonPath, 'utf8'));
	assertTest(verData.version && typeof verData.version === 'string' && verData.version.length > 0, `Identificador de versão gerado: '${verData.version}'`);
	assertTest(verData.builtAt && !isNaN(Date.parse(verData.builtAt)), 'Data ISO de build registrada com sucesso');
}

// --- 3. Auditoria do Service Worker (index.service.worker.js) ---
console.log('\n--- 3. Auditoria do Service Worker (index.service.worker.js) ---');
const swPath = path.join(PUBLIC, 'index.service.worker.js');
assertTest(fs.existsSync(swPath), 'public/index.service.worker.js existe');

if (fs.existsSync(swPath)) {
	const swCode = fs.readFileSync(swPath, 'utf8');

	assertTest(swCode.includes('// SAKAS_INSTALL_SKIP_WAITING') && swCode.includes('self.skipWaiting()'), 'Evento install executa self.skipWaiting() para não travar em waiting');
	assertTest(swCode.includes('// SAKAS_ACTIVATE_CLAIM') && swCode.includes('self.clients.claim()'), 'Evento activate assume clientes com self.clients.claim()');
	assertTest(swCode.includes('// SAKAS_NETWORK_FIRST_NAV'), 'Evento fetch implementa Network-First para navegação (index.html)');
	assertTest(swCode.includes("msg === 'SKIP_WAITING'"), 'EventListener message trata solicitação de SKIP_WAITING');
	assertTest(swCode.includes('key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME'), 'Limpeza de cache isolada estritamente aos caches com CACHE_PREFIX do jogo');

	// Proteção de dados do usuário
	assertTest(!swCode.includes('localStorage.clear()'), 'Proteção: Service worker NUNCA chama localStorage.clear()');
	assertTest(!swCode.includes('indexedDB.deleteDatabase'), 'Proteção: Service worker NUNCA apaga IndexedDB');
}

// --- 4. Auditoria do Cliente PWA (mobile_shell.html e index.html) ---
console.log('\n--- 4. Auditoria do PWA Update Manager (mobile_shell.html / index.html) ---');
const shellPath = path.join(PUBLIC, 'mobile_shell.html');
const indexPath = path.join(PUBLIC, 'index.html');
assertTest(fs.existsSync(shellPath), 'public/mobile_shell.html (fonte persistente do Godot) existe');
assertTest(fs.existsSync(indexPath), 'public/index.html (saída web ativa) existe');

for (const [name, filePath] of [['mobile_shell.html', shellPath], ['index.html', indexPath]]) {
	const html = fs.readFileSync(filePath, 'utf8');
	assertTest(html.includes('meta name="sakas-build-id"'), `${name}: contém meta tag sakas-build-id`);
	assertTest(html.includes('initPwaUpdateManager'), `${name}: contém módulo initPwaUpdateManager`);
	assertTest(html.includes('checkForPublishedRelease'), `${name}: verifica versão contra version.json`);
	assertTest(html.includes('visibilitychange'), `${name}: verifica nova versão ao retornar ao primeiro plano (visibilitychange)`);
	assertTest(html.includes('focus'), `${name}: verifica nova versão no evento focus`);
	assertTest(html.includes('sakas_reloaded_version'), `${name}: possui proteção contra reload loop (sessionStorage)`);
	assertTest(html.includes('sakasNotifyGameStarted'), `${name}: possui proteção para não interromper partida em andamento`);
	assertTest(html.includes('sakas-update-toast'), `${name}: exibe aviso discreto caso atualização chegue durante o jogo`);
}

// --- 5. Integridade Binária dos Assets Pesados (PCK e WASM) ---
console.log('\n--- 5. Integridade Binária dos Arquivos Exportados (Anti-LFS Pointer) ---');
const pckPath = path.join(PUBLIC, 'index.pck');
const wasmPath = path.join(PUBLIC, 'index.wasm');
assertTest(fs.existsSync(pckPath), 'public/index.pck existe no diretório de exportação');
assertTest(fs.existsSync(wasmPath), 'public/index.wasm existe no diretório de exportação');

if (fs.existsSync(pckPath)) {
	const pckStat = fs.statSync(pckPath);
	assertTest(pckStat.size > 10 * 1024 * 1024, `index.pck é binário real do jogo (${(pckStat.size / (1024 * 1024)).toFixed(1)} MB, não ponteiro LFS)`);
}

if (fs.existsSync(wasmPath)) {
	const wasmStat = fs.statSync(wasmPath);
	assertTest(wasmStat.size > 5 * 1024 * 1024, `index.wasm é binário WebAssembly real (${(wasmStat.size / (1024 * 1024)).toFixed(1)} MB, não ponteiro LFS)`);
}

console.log('\n===========================================================================');
console.log(`RESULTADO DOS TESTES PWA: ${passedTests}/${totalTests} PASSARAM (${failedTests} FALHAS)`);
console.log('===========================================================================');

process.exit(failedTests === 0 ? 0 : 1);
