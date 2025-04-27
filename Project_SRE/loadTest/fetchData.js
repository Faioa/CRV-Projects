import http from 'http'
import crypto from 'crypto'

http.globalAgent.maxSockets = Infinity;

const URL = process.env.URL || 'localhost:8080'

const random = (max) => Math.floor(Math.random() * max)

const sleep = (ms) => new Promise((res, rej) => setTimeout(res, ms))

const getItem = (id) => {
  console.log('fetch')
  fetch(URL + '/item?id=' + id).catch((err) => {
    console.error(err)
  })
}

const unsafe = (t) => {
  console.log('fetch')
  fetch(URL + '/unsafe?time=' + t).catch((err) => {
    console.error(err)
  })
}

const setItem = ({ id, val }) => {
  console.log('fetch')
  fetch(URL + '/item', {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
    },
    body: JSON.stringify({ id, val }),
  }).catch((err) => {
    console.error(err)
  })
}

const fetchAll = () => {
  console.log('fetch')
  fetch(URL + '/items').catch((err) => {
    console.error(err)
  })
}

const cannotFetch = () => {
  console.log('fetch')
  fetch(URL + '/nothing').catch((err) => {
    console.error(err)
  })
}

const ping = () => {
  console.log('fetch')
  fetch(URL, {
    headers: { 'Connection': 'close' }
  }).catch((err) => {
    console.error(err)
  })
}

const onlyServerTest = async (max = 10000, iter = 100) => {
  let call = 0
  while (call < max) {
    const res = await Promise.all(new Array(iter).fill(1).map((_) => ping()))
    call += res.length
    console.log('wait')
    sleep(200)
    console.log(call)
  }
}

const writeAndRead = async (max = 10000, iter = 10) => {
  let call = 0
  while (call < max) {
    // Create a large sentence (1KB - 50KB)
    const minKB = 1
    const maxKB = 50
    const targetedSize = random(maxKB * 1024 - minKB * 1024 + 1) + minKB * 1024
    const sentence = crypto.randomBytes(targetedSize).toString('utf-8')

    // Create random keys for write and read (2^6 different keys)
    const random_writeKey = random(2**6)
    const writeKey = random_writeKey.toString(2)

    const random_readKey = random(2**6)
    const readKey = random_readKey.toString(2)

    // Random number of write iteration
    const write_iter = random(iter - 1) + 1

    const writeRes = Promise.all(
      new Array(write_iter).fill(1).map((_) => {
        return setItem({ id: writeKey, val: sentence })
      })
    )

    const readRes = Promise.all(
      new Array(iter-write_iter).fill(1).map((_) => getItem(readKey))
    )

    const res = await Promise.all([writeRes, readRes])

    call += res.flatMap((_) => _).length
    console.log('wait')
    sleep(200)
    console.log(call)
  }
}

const openPendingConnections = async (max = 200, time = 10000) => {
  const requests = [];
  for (let i = 0; i < max; i++) {
    requests.push(unsafe(time));
  }
  await Promise.all(requests);
}

const main = async () => {
  const [n, script, funct, arg1, arg2] = process.argv
  switch (funct) {
    case 'server':
      await onlyServerTest(arg1, arg2)
      break
    case 'writeRead':
      await writeAndRead(arg1, arg2)
      break
    case 'pending':
      await openPendingConnections(arg1, arg2)
      break
    default:
      console.log('connecting to ' + URL)
      await fetch(URL)
      console.log('connection ok')
      console.log(`try with arguments :
        - node fetchData.js server 10000
        - node fetchData.js writeRead 10000
        - node fetchData.js pending 200 10000
        `)
      break
  }
  console.log('execution finished successfully')
}

main()
