import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir, open, writeFile } from 'node:fs/promises'
import { createServer } from 'node:net'
import { join } from 'node:path'
import { setTimeout as delay } from 'node:timers/promises'

const [executable, directory] = process.argv.slice(2)
assert(executable && directory)
await mkdir(directory, { recursive: true })
await mkdir(join(directory, 'config', 'mihomo-party'), { recursive: true })
await writeFile(join(directory, 'config', 'mihomo-party', 'config.yaml'),
  'modeSelected: true\noperationMode: standard\nlanguage: en-US\nautoCheckUpdate: false\n')
await mkdir(join(directory, 'runtime'), { recursive: true, mode: 0o700 })
const log = await open(join(directory, 'electron.log'), 'w')
const reservation = createServer()
await new Promise(resolve => reservation.listen(0, '127.0.0.1', resolve))
const port = reservation.address().port
await new Promise(resolve => reservation.close(resolve))

const app = spawn('xvfb-run', ['-a', 'dbus-run-session', '--', executable,
  '--no-sandbox', '--disable-gpu', `--remote-debugging-port=${port}`], {
  detached: true,
  env: {
    ...process.env,
    XDG_CONFIG_HOME: join(directory, 'config'),
    XDG_CACHE_HOME: join(directory, 'cache'),
    XDG_RUNTIME_DIR: join(directory, 'runtime'),
  },
  stdio: ['ignore', log.fd, log.fd],
})

let ws
try {
  let page
  for (let attempt = 0; attempt < 120; attempt++) {
    assert(app.exitCode === null, `Electron exited with ${app.exitCode}`)
    try {
      const response = await fetch(`http://127.0.0.1:${port}/json/list`)
      page = (await response.json()).find(item => item.type === 'page' && item.url.startsWith('file:'))
      if (page) break
    } catch {}
    await delay(500)
  }
  assert(page, 'Clash Party window did not load its renderer')
  ws = new WebSocket(page.webSocketDebuggerUrl)
  await new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true })
    ws.addEventListener('error', reject, { once: true })
  })
  let id = 0
  const pending = new Map()
  ws.addEventListener('message', event => {
    const message = JSON.parse(event.data)
    if (message.id && pending.has(message.id)) {
      pending.get(message.id)(message)
      pending.delete(message.id)
    }
  })
  function cdp(method, params = {}) {
    const requestId = ++id
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`CDP timeout: ${method}`)), 15000)
      pending.set(requestId, result => {
        clearTimeout(timer)
        if (result.error) reject(new Error(JSON.stringify(result.error)))
        else resolve(result.result)
      })
      ws.send(JSON.stringify({ id: requestId, method, params }))
    })
  }
  async function evaluate(expression) {
    const result = await cdp('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true })
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails))
    return result.result?.value
  }
  const invoke = `(async (channel, ...args) => {
    const result = await window.electron.ipcRenderer.invoke(channel, ...args)
    if (result && typeof result === 'object' && 'invokeError' in result) throw new Error(result.invokeError)
    return result
  })`
  let state
  for (let attempt = 0; attempt < 120; attempt++) {
    state = await evaluate(`(async () => {
      if (!window.electron?.ipcRenderer) return null
      const call = ${invoke}
      let backend
      try { backend = await call('mihomoVersion') } catch {}
      return {
        textLength: document.body.innerText.trim().length,
        version: await call('getVersion'),
        backend: backend?.version,
        subStorePort: await call('subStorePort'),
        subStoreFrontendPort: await call('subStoreFrontendPort')
      }
    })()`)
    if (state?.textLength > 100 && state.backend && state.subStorePort && state.subStoreFrontendPort) break
    await delay(500)
  }
  assert(state?.textLength > 100, 'Clash Party UI did not render')
  assert.equal(state.version, '2.0.4')
  assert.match(state.backend, /^v?1\./)
  // The application assigns the port before the Sub-Store worker listens.
  // Wait for HTTP readiness as well as the GUI/core startup state.
  async function waitForHttp(url) {
    const deadline = Date.now() + 60000
    let failure
    while (Date.now() < deadline) {
      assert(app.exitCode === null, `Electron exited with ${app.exitCode}`)
      try {
        const response = await fetch(url, { signal: AbortSignal.timeout(2000) })
        if (response.ok) return response
        failure = new Error(`HTTP ${response.status}`)
        await response.body?.cancel()
      } catch (error) { failure = error }
      await delay(500)
    }
    throw new Error(`Sub-Store did not become ready: ${url}`, { cause: failure })
  }
  assert(state.subStorePort && state.subStoreFrontendPort, 'Sub-Store ports were not assigned')
  const response = await waitForHttp(`http://127.0.0.1:${state.subStorePort}/api/subs`)
  assert.equal(response.status, 200, 'Bundled Sub-Store backend did not start')
  assert.equal((await response.json()).status, 'success')
  const frontend = await waitForHttp(`http://127.0.0.1:${state.subStoreFrontendPort}/`)
  assert.equal(frontend.status, 200, 'Bundled Sub-Store frontend did not start')
  assert.match(await frontend.text(), /<html/)

  for (const [core, expected] of [
    ['mihomo-alpha', /alpha-b6a1518/],
    ['mihomo-smart', /alpha-smart-4624551/],
    ['mihomo', /^v?1\./],
  ]) {
    await evaluate(`(async () => {
      const call = ${invoke}
      await call('patchAppConfig', { core: ${JSON.stringify(core)}, enableSmartCore: ${core === 'mihomo-smart'} })
      await call('restartCore')
    })()`)
    let version
    for (let attempt = 0; attempt < 60; attempt++) {
      try { version = await evaluate(`(${invoke})('mihomoVersion')`) } catch {}
      if (expected.test(version?.version || '')) break
      await delay(500)
    }
    assert.match(version?.version || '', expected, `${core} did not start`)
    console.log('Verified core:', core, version.version)
  }
  console.log('Electron UI, preload, three cores and bundled Sub-Store passed:', state)

} finally {
  ws?.close()
  try { process.kill(-app.pid, 'SIGTERM') } catch {}
  await log.close()
}

