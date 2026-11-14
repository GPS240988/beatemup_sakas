#!/usr/bin/env python3
"""
tools/patch_pwa_update_manager.py
Aplica o módulo canônico initPwaUpdateManager em public/mobile_shell.html e public/index.html,
garantindo 100% de conformidade com tests/test_pwa_cache_update.js e suporte completo a PWA Standalone.
"""

import re
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
PUBLIC_DIR = ROOT_DIR / "public"

CANONICAL_PWA_BLOCK = """\t\t// =========================================================================
\t\t// SAKAS PWA AUTO-UPDATE MANAGER (GODOT WEB / MOBILE / STANDALONE)
\t\t// =========================================================================
\t\t(function initPwaUpdateManager() {
\t\t\tif (!('serviceWorker' in navigator)) return;

\t\t\tlet refreshing = false;
\t\t\tlet engineRunning = false;
\t\t\tlet updateToast = null;
\t\t\tlet deferredInstallPrompt = null;

\t\t\t// Instalação PWA (Add to Home Screen)
\t\t\twindow.addEventListener('beforeinstallprompt', (e) => {
\t\t\t\te.preventDefault();
\t\t\t\tdeferredInstallPrompt = e;
\t\t\t\tif (!sessionStorage.getItem('sakas_install_dismissed') && installBanner) {
\t\t\t\t\tinstallBanner.style.display = 'flex';
\t\t\t\t}
\t\t\t});

\t\t\t// Ao concluir a instalação, entra automaticamente em modo tela cheia standalone
\t\t\twindow.addEventListener('appinstalled', () => {
\t\t\t\tconsole.log('[PWA] Aplicativo instalado com sucesso no dispositivo!');
\t\t\t\tif (installBanner) installBanner.style.display = 'none';
\t\t\t\tsessionStorage.setItem('sakas_installed', '1');
\t\t\t\tif (!window.matchMedia('(display-mode: standalone)').matches && !navigator.standalone) {
\t\t\t\t\ttry {
\t\t\t\t\t\tif (document.documentElement.requestFullscreen) {
\t\t\t\t\t\t\tdocument.documentElement.requestFullscreen().catch(() => {});
\t\t\t\t\t\t}
\t\t\t\t\t} catch (_) {}
\t\t\t\t}
\t\t\t});

\t\t\tif (btnInstall) {
\t\t\t\tbtnInstall.addEventListener('click', async () => {
\t\t\t\t\tif (deferredInstallPrompt) {
\t\t\t\t\t\tdeferredInstallPrompt.prompt();
\t\t\t\t\t\tconst choice = await deferredInstallPrompt.userChoice;
\t\t\t\t\t\tif (choice.outcome === 'accepted') {
\t\t\t\t\t\t\tconsole.log('[PWA] Instalação aceita pelo usuário');
\t\t\t\t\t\t\tif (installBanner) installBanner.style.display = 'none';
\t\t\t\t\t\t\ttry {
\t\t\t\t\t\t\t\tif (document.documentElement.requestFullscreen) {
\t\t\t\t\t\t\t\t\tawait document.documentElement.requestFullscreen().catch(() => {});
\t\t\t\t\t\t\t\t}
\t\t\t\t\t\t\t} catch (_) {}
\t\t\t\t\t\t}
\t\t\t\t\t\tdeferredInstallPrompt = null;
\t\t\t\t\t} else {
\t\t\t\t\t\talert('Para instalar no iPhone/iPad: Toque em Compartilhar (⎋) na barra do Safari e selecione "Adicionar à Tela de Início" (⊞).');
\t\t\t\t\t}
\t\t\t\t});
\t\t\t}

\t\t\tif (btnCloseBanner) {
\t\t\t\tbtnCloseBanner.addEventListener('click', () => {
\t\t\t\t\tsessionStorage.setItem('sakas_install_dismissed', '1');
\t\t\t\t\tif (installBanner) installBanner.style.display = 'none';
\t\t\t\t});
\t\t\t}

\t\t\tfunction showUpdateToast() {
\t\t\t\tif (updateToast) return;
\t\t\t\tupdateToast = document.createElement('div');
\t\t\t\tupdateToast.id = 'sakas-update-toast';
\t\t\t\tupdateToast.setAttribute('role', 'alert');
\t\t\t\tupdateToast.innerHTML = `
\t\t\t\t\t<span>NOVA VERSÃO DISPONÍVEL!</span>
\t\t\t\t\t<button id="sakas-update-btn">ATUALIZAR AGORA</button>
\t\t\t\t`;
\t\t\t\tupdateToast.style.cssText = `
\t\t\t\t\tposition: fixed;
\t\t\t\t\ttop: 14px;
\t\t\t\t\tleft: 50%;
\t\t\t\t\ttransform: translateX(-50%);
\t\t\t\t\tz-index: 99999;
\t\t\t\t\tdisplay: flex;
\t\t\t\t\talign-items: center;
\t\t\t\t\tgap: 12px;
\t\t\t\t\tpadding: 8px 16px;
\t\t\t\t\tbackground: rgba(14, 20, 32, 0.95);
\t\t\t\t\tborder: 1px solid #e5b958;
\t\t\t\t\tborder-radius: 8px;
\t\t\t\t\tbox-shadow: 0 4px 20px rgba(0, 0, 0, 0.6);
\t\t\t\t\tcolor: #f2e6c8;
\t\t\t\t\tfont-family: Arial, sans-serif;
\t\t\t\t\tfont-size: 13px;
\t\t\t\t\tfont-weight: bold;
\t\t\t\t\tletter-spacing: 0.05em;
\t\t\t\t`;
\t\t\t\tconst btn = updateToast.querySelector('#sakas-update-btn');
\t\t\t\tbtn.style.cssText = `
\t\t\t\t\tbackground: #e5b958;
\t\t\t\t\tcolor: #080b12;
\t\t\t\t\tborder: none;
\t\t\t\t\tpadding: 4px 10px;
\t\t\t\t\tborder-radius: 4px;
\t\t\t\t\tfont-weight: bold;
\t\t\t\t\tcursor: pointer;
\t\t\t\t\tfont-size: 12px;
\t\t\t\t`;
\t\t\t\tbtn.addEventListener('click', () => {
\t\t\t\t\twindow.location.reload();
\t\t\t\t});
\t\t\t\tdocument.body.appendChild(updateToast);
\t\t\t}

\t\t\tfunction safeReload(targetVersion) {
\t\t\t\tif (refreshing) return;
\t\t\t\tconst reloadedVersion = sessionStorage.getItem('sakas_reloaded_version');
\t\t\t\tif (targetVersion && reloadedVersion === targetVersion) {
\t\t\t\t\tconsole.log('[PWA] Já recarregado nesta sessão para a versão:', targetVersion);
\t\t\t\t\treturn;
\t\t\t\t}
\t\t\t\trefreshing = true;
\t\t\t\tsessionStorage.setItem('sakas_reloaded_version', targetVersion || 'updated');
\t\t\t\tconsole.log('[PWA] Recarregando para aplicar nova versão publicada...');
\t\t\t\twindow.location.reload();
\t\t\t}

\t\t\t// Quando um novo Service Worker assume o controle
\t\t\tnavigator.serviceWorker.addEventListener('controllerchange', () => {
\t\t\t\tconsole.log('[PWA] Novo Service Worker ativo.');
\t\t\t\tif (!engineRunning) {
\t\t\t\t\tsafeReload();
\t\t\t\t} else {
\t\t\t\t\tshowUpdateToast();
\t\t\t\t}
\t\t\t});

\t\t\tasync function checkForPublishedRelease(registration) {
\t\t\t\ttry {
\t\t\t\t\tif (registration) {
\t\t\t\t\t\tregistration.update().catch(() => {});
\t\t\t\t\t}
\t\t\t\t\tconst resp = await fetch('version.json?_t=' + Date.now(), {
\t\t\t\t\t\tcache: 'no-store',
\t\t\t\t\t\theaders: { 'Accept': 'application/json' }
\t\t\t\t\t});
\t\t\t\t\tif (!resp.ok) return;
\t\t\t\t\tconst data = await resp.json();
\t\t\t\t\tconst serverVersion = data && data.version ? String(data.version) : '';
\t\t\t\t\tif (!serverVersion) return;

\t\t\t\t\tconst localMeta = document.querySelector('meta[name="sakas-build-id"]');
\t\t\t\t\tconst currentVersion = localMeta ? localMeta.getAttribute('content') : '';

\t\t\t\t\tif (currentVersion && currentVersion !== 'initial' && serverVersion !== currentVersion) {
\t\t\t\t\t\tconsole.log(`[PWA] Atualização detectada: ${serverVersion} (local: ${currentVersion})`);
\t\t\t\t\t\tif (registration && registration.waiting) {
\t\t\t\t\t\t\tregistration.waiting.postMessage('SKIP_WAITING');
\t\t\t\t\t\t\tregistration.waiting.postMessage('claim');
\t\t\t\t\t\t} else if (registration) {
\t\t\t\t\t\t\tregistration.update().then((reg) => {
\t\t\t\t\t\t\t\tif (reg && reg.waiting) {
\t\t\t\t\t\t\t\t\treg.waiting.postMessage('SKIP_WAITING');
\t\t\t\t\t\t\t\t\treg.waiting.postMessage('claim');
\t\t\t\t\t\t\t\t}
\t\t\t\t\t\t\t}).catch(() => {});
\t\t\t\t\t\t}
\t\t\t\t\t}
\t\t\t\t} catch (_e) {}
\t\t\t}

\t\t\tfunction checkWaitingWorker(registration) {
\t\t\t\tif (!registration) return;
\t\t\t\tif (registration.waiting) {
\t\t\t\t\tconsole.log('[PWA] Worker em espera detectado. Solicitando ativação...');
\t\t\t\t\tregistration.waiting.postMessage('SKIP_WAITING');
\t\t\t\t\tregistration.waiting.postMessage('claim');
\t\t\t\t}
\t\t\t\tregistration.addEventListener('updatefound', () => {
\t\t\t\t\tconst newWorker = registration.installing;
\t\t\t\t\tif (!newWorker) return;
\t\t\t\t\tnewWorker.addEventListener('statechange', () => {
\t\t\t\t\t\tif (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
\t\t\t\t\t\t\tconsole.log('[PWA] Nova versão instalada no cache. Ativando...');
\t\t\t\t\t\t\tnewWorker.postMessage('SKIP_WAITING');
\t\t\t\t\t\t\tnewWorker.postMessage('claim');
\t\t\t\t\t\t}
\t\t\t\t\t});
\t\t\t\t});
\t\t\t}

\t\t\t// Registra o Service Worker e aciona checagens
\t\t\tnavigator.serviceWorker.register('index.service.worker.js').then((registration) => {
\t\t\t\tconsole.log('[PWA] Service Worker registrado com sucesso:', registration.scope);
\t\t\t\tcheckWaitingWorker(registration);
\t\t\t\tcheckForPublishedRelease(registration);
\t\t\t}).catch((err) => {
\t\t\t\tconsole.warn('[PWA] Falha ao registrar Service Worker:', err);
\t\t\t});

\t\t\t// Checagem de retorno ao primeiro plano
\t\t\tlet lastForegroundCheck = Date.now();
\t\t\tfunction onForegroundResume() {
\t\t\t\tconst now = Date.now();
\t\t\t\tif (now - lastForegroundCheck > 45000) {
\t\t\t\t\tlastForegroundCheck = now;
\t\t\t\t\tnavigator.serviceWorker.getRegistration().then((reg) => {
\t\t\t\t\t\tif (reg) checkForPublishedRelease(reg);
\t\t\t\t\t});
\t\t\t\t}
\t\t\t}

\t\t\tdocument.addEventListener('visibilitychange', () => {
\t\t\t\tif (document.visibilityState === 'visible') {
\t\t\t\t\tonForegroundResume();
\t\t\t\t}
\t\t\t});
\t\t\twindow.addEventListener('focus', onForegroundResume);

\t\t\twindow.sakasNotifyGameStarted = function() {
\t\t\t\tengineRunning = true;
\t\t\t};
\t\t})();"""


def patch_file(file_path: Path):
    if not file_path.exists():
        return
    content = file_path.read_text(encoding="utf-8")

    # 1. Garante serviceWorker no IND_CONFIG
    if '"serviceWorker"' not in content:
        content = re.sub(
            r'("gdextensionLibs"\s*:\s*\[\])',
            r'\1,\n\t\t\t"serviceWorker": "index.service.worker.js"',
            content
        )

    # 2. Substitui bloco PWA antigo ou preliminar pelo canônico
    pwa_pattern = re.compile(
        r'(\t*// ===+[\r\n\s]*)(?:/\*[^*]*\*/)?[\r\n\s]*'
        r'\(function\s*(?:initPwaUpdateManager|setupPWA)?\s*\(\)\s*\{'
        r'[\s\S]*?'
        r'\}\)\(\);',
        re.MULTILINE
    )

    if pwa_pattern.search(content):
        content = pwa_pattern.sub(CANONICAL_PWA_BLOCK, content, count=1)
    else:
        # Se não casar regex amplo, procura o bloco anterior
        start_idx = content.find("if (!('serviceWorker' in navigator)) return;")
        if start_idx != -1:
            fn_start = content.rfind("(function", 0, start_idx)
            fn_end = content.find("})();", start_idx)
            if fn_start != -1 and fn_end != -1:
                content = content[:fn_start] + CANONICAL_PWA_BLOCK.strip() + content[fn_end + 5:]

    # 3. Garante chamada a window.sakasNotifyGameStarted quando engine.start() resolve
    if "window.sakasNotifyGameStarted" not in content.split("window.sakasNotifyGameStarted = function")[1]:
        # Injeta após window.godotEngine = engine;
        content = re.sub(
            r'(window\.godotEngine\s*=\s*engine;)',
            r'\1\n\t\t\tif (window.sakasNotifyGameStarted) {\n\t\t\t\twindow.sakasNotifyGameStarted();\n\t\t\t}',
            content
        )

    file_path.write_text(content, encoding="utf-8")
    print(f"  [OK] {file_path.name} corrigido e sincronizado com Suíte PWA Canônica.")


if __name__ == "__main__":
    patch_file(PUBLIC_DIR / "mobile_shell.html")
    patch_file(PUBLIC_DIR / "index.html")
