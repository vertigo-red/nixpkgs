import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir, open } from 'node:fs/promises'
import { createServer } from 'node:net'
import { join } from 'node:path'
import { setTimeout as delay } from 'node:timers/promises'

const [executable, directory] = process.argv.slice(2)
assert(executable && directory)
await mkdir(directory, { recursive: true })
await mkdir(join(directory, 'runtime'), { recursive: true, mode: 0o700 })
const log = await open(join(directory, 'electron.log'), 'w')
const reservation = createServer()
await new Promise(resolve => reservation.listen(0, '127.0.0.1', resolve))
const port = reservation.address().port
await new Promise(resolve => reservation.close(resolve))

const app = spawn('xvfb-run', ['-a', 'dbus-run-session', '--', executable,
  '--disable-gpu', `--remote-debugging-port=${port}`], {
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
      page = (await response.json()).find(item => item.type === 'page' && item.url.startsWith('http://127.0.0.1:'))
      if (page) break
    } catch {}
    await delay(500)
  }
  assert(page, 'Desktop window did not load its local dashboard')
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
  let state
  for (let attempt = 0; attempt < 60; attempt++) {
    const result = await cdp('Runtime.evaluate', {
      expression: `(async () => {
        const bridge = window.metacubexd
        if (!bridge?.isDesktop) return null
        const headers = { Authorization: 'Bearer ' + bridge.control.token }
        const info = await fetch(bridge.control.base + '/info', { headers })
        const backend = await fetch(bridge.endpoint.url + '/version', {
          headers: { Authorization: 'Bearer ' + bridge.endpoint.secret }
        })
        return {
          desktop: bridge.isDesktop,
          textLength: document.body.innerText.trim().length,
          infoStatus: info.status,
          backendStatus: backend.status,
          version: (await backend.json()).version
        }
      })()`,
      awaitPromise: true,
      returnByValue: true,
    })
    state = result.result?.value
    if (state?.textLength > 100 && state.backendStatus === 200) break
    await delay(500)
  }
  assert(state?.desktop, 'Electron preload bridge is unavailable')
  assert(state.textLength > 100, 'Dashboard did not render')
  assert.equal(state.infoStatus, 200)
  assert.equal(state.backendStatus, 200)
  assert.match(state.version, /^v?1\./)
  console.log('Electron dashboard, preload bridge, agent API and Mihomo backend passed:', state)
} finally {
  ws?.close()
  try { process.kill(-app.pid, 'SIGTERM') } catch {}
  await log.close()
}
