const URL = process.env.URL || "http://192.168.58.200";

const words = [
  "drive",
  "driver",
  "capacitor",
  "card",
  "port",
  "interface",
  "bandwidth",
  "alarm",
  "port",
  "card",
];

const sentences = [
  "I'll copy the open-source PNG program, that should hard drive the IP driver!",
  "Use the digital API port, then you can connect the online interface!",
  "Try to synthesize the ASCII transmitter, maybe it will connect the bluetooth panel!",
  "The XSS application is down, program the optical protocol so we can index the SSL monitor!",
  "If we generate the circuit, we can get to the SDD driver through the cross-platform CSS monitor!",
  "We need to calculate the wireless GB bus!",
  "I'll synthesize the digital IB panel, that should hard drive the HTTP matrix!",
  "If we bypass the program, we can get to the SAS port through the primary IP system!",
  "Use the haptic OCR hard drive, then you can synthesize the multi-byte system!",
  "Try to quantify the XML application, maybe it will compress the wireless bandwidth!",
];

const random = (max) => Math.floor(Math.random() * max);

const sleep = (ms) => new Promise((res, rej) => setTimeout(res, ms));

const getItem = (id) => fetch(URL + "/item?id=" + id).catch(console.error);

const unsafe = (t) => fetch(URL + "/unsafe?t=" + t).catch(console.error);

const setItem = ({ id, val }) =>
  fetch(URL + "/item", {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ id, val }),
  }).catch(console.error);

const fetchAll = () => fetch(URL + "/items").catch(console.error);

const cannotFetch = () => fetch(URL + "/nothing").catch(console.error);

const ping = () => fetch(URL).catch(console.error);

const onlyServerTest = async (max = 10000, iter = 100) => {
  let call = 0;
  while (call < max) {
    console.log("fetch");
    const res = await Promise.all(new Array(iter).fill(1).map((_) => ping()));
    call += res.length;
    console.log("wait");
    await sleep(200);
    console.log(call);
  }
};

const writeAndRead = async (max = 10000, iter = 10) => {
  let call = 0;
  while (call < max) {
    console.log("fetch");
    const writeRes = Promise.all(
      new Array(Math.floor(iter / 10)).fill(1).map((_) => {
        const id = words[random(words.length)];
        const val = sentences[random(sentences.length)];
        return setItem({ id, val });
      })
    );
    const readRes = Promise.all(
      new Array(iter).fill(1).map((_) => getItem(words[random(words.length)]))
    );

    const res = await Promise.all([writeRes, readRes]);

    call += res.flatMap((_) => _).length;
    console.log("wait");
    await sleep(200);
    console.log(call);
  }
};

const openPendingConnections = async (max = 200, time = 10000) =>
  Promise.all(new Array(max).fill(1).map((_) => unsafe(time)));

const main = async () => {
  const [node, script, command] = process.argv;

  const nbTotal = [1000, 10000, 50000, 100000, 200000, 500000, 1000000];
  const nbConcurrent = [500, 1000, 5000, 10000, 20000, 50000, 100000];

  if (command === "all") {
    console.log("Connecting to " + URL);
    await fetch(URL);
    console.log("Connection established");

    for (const total of nbTotal) {
      for (const concurrent of nbConcurrent) {
        console.log(`nbTotal=${total}, nbConcurrent=${concurrent}`);

        console.log("--> Server test...");
        await onlyServerTest(total, concurrent);
        console.log("Server test completed");

        console.log("--> Write and read test...");
        await writeAndRead(total, concurrent);
        console.log("Write and read test completed");

        console.log("--> Pending connections test...");
        await openPendingConnections(concurrent, 10000);
        console.log("Pending connections test completed");
      }
    }
  } else {
    console.log("Connecting to " + URL);
    await fetch(URL);
    console.log("Connection ok");
    console.log(`Try with argument:
      - node fetchData.js all
    `);
  }

  console.log("Execution finished successfully");
};

main();