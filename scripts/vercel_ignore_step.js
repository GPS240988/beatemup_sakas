/**
 * scripts/vercel_ignore_step.js
 *
 * Vercel Ignored Build Step:
 * - Exit code 0: CANCELA / IGNORA o build automático do GitHub na Vercel.
 * - Exit code 1: PERMITE que o build prossiga.
 *
 * Motivo:
 * Os binários pesados exportados do Godot (index.pck, index.wasm, packs/*.pck)
 * NÃO são versionados no Git para não consumir cota do Git LFS e respeitar
 * o teto de 100 MB por arquivo.
 *
 * Quando um push é feito no GitHub, a Vercel tenta construir o repositório,
 * mas como o Git não tem o index.pck nem o Godot instalado na nuvem, o deploy
 * ficaria quebrado (404 no index.pck).
 *
 * Este script detecta a ausência dos binários e cancela o build do Git,
 * garantindo que o deploy ativo em produção (feito via deploy_web.bat)
 * JAMAIS seja sobrescrito por um build vazio.
 */

const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '..');
const pckPath = path.join(ROOT_DIR, 'public', 'index.pck');
const wasmPath = path.join(ROOT_DIR, 'public', 'index.wasm');

const hasPck = fs.existsSync(pckPath);
const hasWasm = fs.existsSync(wasmPath);

if (!hasPck || !hasWasm) {
	console.log('[Vercel Ignored Build Step] 🛑 Git push detectado SEM binários do Godot (index.pck / index.wasm).');
	console.log('[Vercel Ignored Build Step] 🛡️ CANCELANDO build (Exit 0) para PRESERVAR a produção funcional.');
	console.log('[Vercel Ignored Build Step] 💡 Para publicar uma nova versão com binários, execute: tools\\deploy_web.bat');
	process.exit(0); // Exit 0 = Cancela o build na Vercel
}

console.log('[Vercel Ignored Build Step] ✅ Binários Godot detectados. Prosseguindo com o build...');
process.exit(1); // Exit 1 = Prossegue com o build na Vercel

