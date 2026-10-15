const esbuild = require('esbuild');
const fs = require('node:fs/promises');
const path = require('node:path');
const { spawn } = require('node:child_process');

async function build() {
    const output = path.join(__dirname, '../media/build');
    await fs.mkdir(output, { recursive: true });
    const monaco = path.resolve(path.dirname(require.resolve('monaco-editor/editor/editor.api.js')), '../../..');
    for (const name of ['LICENSE', 'ThirdPartyNotices.txt']) {
        await fs.copyFile(path.join(monaco, name), path.join(output, `monaco-${name}`));
    }
    const jsonParser = path.dirname(require.resolve('jsonc-parser/package.json'));
    await fs.copyFile(path.join(jsonParser, 'LICENSE.md'), path.join(output, 'jsonc-parser-LICENSE.md'));
    const options = {
        entryPoints: {
            viewer: path.join(__dirname, '../media/viewer.js'),
            'editor.worker': require.resolve('monaco-editor/editor/editor.worker.js'),
            'json.worker': require.resolve('monaco-editor/language/json/json.worker.js'),
        },
        outdir: output,
        bundle: true,
        alias: { 'monaco-editor': path.join(monaco, 'esm/vs') },
        format: 'iife',
        platform: 'browser',
        target: 'chrome128',
        minify: true,
        loader: { '.ttf': 'file' },
        assetNames: 'assets/[name]-[hash]',
        legalComments: 'linked',
        logLevel: 'info',
    };
    if (process.argv.includes('--watch')) {
        const context = await esbuild.context(options);
        await context.watch();
        const typescript = require('typescript/package.json');
        const compilerPath = path.resolve(path.dirname(require.resolve('typescript/package.json')), typescript.bin.tsc);
        const compiler = spawn(process.execPath, [compilerPath, '-w', '-p', '.'], { stdio: 'inherit' });
        const stop = async () => { compiler.kill(); await context.dispose(); };
        process.once('SIGINT', stop);
        process.once('SIGTERM', stop);
        compiler.once('exit', async code => { await context.dispose(); process.exitCode = code || 0; });
    } else await esbuild.build(options);
}

build().catch(error => { console.error(error); process.exitCode = 1; });
