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
    const licenses = path.join(__dirname, '../dist/licenses');
    await fs.mkdir(licenses, { recursive: true });
    for (const name of ['hyparquet', 'hyparquet-compressors', 'hysnappy', 'fzstd']) {
        const directory = path.resolve(path.dirname(require.resolve(name)), '..');
        const license = (await fs.readdir(directory)).find(file => /^LICENSE(?:\.md|\.txt)?$/i.test(file));
        if (!license) throw new Error(`Missing license for ${name}`);
        await fs.copyFile(path.join(directory, license), path.join(licenses, `${name}-LICENSE.txt`));
    }
    const workerOptions = {
        entryPoints: [path.join(__dirname, '../src/index-worker.ts')],
        outfile: path.join(__dirname, '../dist/file-worker.cjs'),
        bundle: true, format: 'cjs', platform: 'node', target: 'node20', minify: true, legalComments: 'linked', logLevel: 'info',
    };
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
        const workerContext = await esbuild.context(workerOptions);
        await workerContext.watch();
        const typescript = require('typescript/package.json');
        const compilerPath = path.resolve(path.dirname(require.resolve('typescript/package.json')), typescript.bin.tsc);
        const compiler = spawn(process.execPath, [compilerPath, '-w', '-p', '.'], { stdio: 'inherit' });
        const dispose = () => Promise.all([context.dispose(), workerContext.dispose()]);
        const stop = async () => { compiler.kill(); await dispose(); };
        process.once('SIGINT', stop);
        process.once('SIGTERM', stop);
        compiler.once('exit', async code => { await dispose(); process.exitCode = code || 0; });
    } else {
        await esbuild.build(options);
        await esbuild.build(workerOptions);
    }
}

build().catch(error => { console.error(error); process.exitCode = 1; });
