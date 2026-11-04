"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {randomBytes} = require("node:crypto");
const {readFileSync} = require("node:fs");
const path = require("node:path");

const enabled = process.env.RUN_SPARK_CAPACITY_RULES_TESTS === "1";
const project = "npjn-queue-system-jkr";

if (!enabled) {
  test("Spark capacity rules integration requires explicit local opt-in", {skip: true}, () => {});
} else {
  // Guard before importing/initializing any SDK; this suite must never reach a
  // real Firebase project, even when the developer has production credentials.
  for (const key of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"]) {
    if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(process.env[key] || "")) {
      throw new Error(`${key} must explicitly target a loopback emulator.`);
    }
  }

  const {initializeApp, deleteApp} = require("firebase-admin/app");
  const {getFirestore, FieldValue} = require("firebase-admin/firestore");
  const {getAuth} = require("firebase-admin/auth");
  const app = initializeApp({projectId: project}, `spark-capacity-rules-${process.pid}`);
  const db = getFirestore(app);
  const auth = getAuth(app);
  const run = `spark-${Date.now()}-${randomBytes(3).toString("hex")}`;
  const origin = `http://${process.env.FIRESTORE_EMULATOR_HOST}`;
  const documentRoot = `projects/${project}/databases/(default)/documents`;
  const documentUrl = `${origin}/v1/${documentRoot}`;
  const config = db.doc("system_config/queue_capacity");
  let initialConfig;
  let adminToken;
  let customerToken;
  let secondCustomerToken;
  let unverifiedToken;
  let customerId;
  let adminId;
  let dayNumber = 0;
  const fixtureBase = new Date(Date.UTC(2200 + randomBytes(2).readUInt16BE() % 1500,
    randomBytes(1)[0] % 12, 1 + randomBytes(1)[0] % 20));
  const authIds = [];

  function dateFixture() {
    const date = new Date(fixtureBase);
    date.setUTCDate(date.getUTCDate() + dayNumber++);
    const value = `${date.getUTCMonth() + 1}/${date.getUTCDate()}/${date.getUTCFullYear()}`;
    return {date: value, key: value.replaceAll("/", "-")};
  }

  function value(data) {
    if (data === null) return {nullValue: null};
    if (data instanceof Date) return {timestampValue: data.toISOString()};
    if (typeof data === "string") return {stringValue: data};
    if (typeof data === "boolean") return {booleanValue: data};
    if (typeof data === "number") return Number.isInteger(data)
      ? {integerValue: String(data)} : {doubleValue: data};
    if (Array.isArray(data)) return {arrayValue: {values: data.map(value)}};
    return {mapValue: {fields: fields(data)}};
  }

  function fields(data) {
    return Object.fromEntries(Object.entries(data).map(([key, data]) => [key, value(data)]));
  }

  function decode(data) {
    if (data.mapValue) return Object.fromEntries(Object.entries(data.mapValue.fields || {}).map(([key, nested]) => [key, decode(nested)]));
    if (data.arrayValue) return (data.arrayValue.values || []).map(decode);
    if (data.integerValue !== undefined) return Number(data.integerValue);
    if (data.doubleValue !== undefined) return Number(data.doubleValue);
    if (data.booleanValue !== undefined) return data.booleanValue;
    if (data.timestampValue !== undefined) return new Date(data.timestampValue);
    return data.stringValue ?? null;
  }

  function setWrite(relative, data, transforms = [], merge = false) {
    return {
      update: {name: `${documentRoot}/${relative}`, fields: fields(data)},
      ...(merge ? {updateMask: {fieldPaths: Object.keys(data)}} : {}),
      ...(transforms.length ? {updateTransforms: transforms.map((fieldPath) => ({fieldPath, setToServerValue: "REQUEST_TIME"}))} : {}),
    };
  }

  function deleteWrite(relative) {
    return {delete: `${documentRoot}/${relative}`};
  }

  async function rest(suffix, token, body, method = "POST") {
    const response = await fetch(`${documentUrl}${suffix}`, {
      method,
      signal: AbortSignal.timeout(25000),
      headers: {"Content-Type": "application/json", ...(token ? {Authorization: `Bearer ${token}`} : {})},
      ...(body === undefined ? {} : {body: JSON.stringify(body)}),
    });
    const result = await response.json();
    return {status: response.status, body: result};
  }

  function explain(result) {
    return JSON.stringify(result.body.error || result.body);
  }

  async function commit(writes, token = adminToken, transaction) {
    return rest(":commit", token, {writes, ...(transaction ? {transaction} : {})});
  }

  async function allowed(writes, token = adminToken) {
    const result = await commit(writes, token);
    assert.equal(result.status, 200, explain(result));
    return result;
  }

  async function denied(writes, token = adminToken) {
    const result = await commit(writes, token);
    assert.equal(result.status, 403, explain(result));
    return result;
  }

  async function tokenFor(label, role, verified = true) {
    const uid = `${run}-${label}`;
    const email = `${uid}@local.npjn.test`;
    const password = randomBytes(18).toString("hex");
    await auth.createUser({uid, email, password, emailVerified: verified});
    authIds.push(uid);
    await db.doc(`users/${uid}`).set({uid, email, role});
    const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-only`, {
      method: "POST", headers: {"Content-Type": "application/json"},
      body: JSON.stringify({email, password, returnSecureToken: true}),
    });
    assert.equal(response.status, 200, "Synthetic local sign-in should succeed");
    return {uid, token: (await response.json()).idToken};
  }

  function emptyDay(day) {
    return {schemaVersion: 2, date: day.date, appointmentClaims: {}, walkInClaims: {}, completedClaims: {}, legacyQueueClaims: {}};
  }

  function ledgerWrite(day, data, action, source, claimId, queue) {
    return setWrite(`capacity_days/${day.key}`, {
      ...data, lastMutation: {action, source, claimId, queue},
    }, ["updatedAt"]);
  }

  function appointment(day, id, queue, status = "Pending") {
    return {
      appointmentId: id, customerId, customerEmail: "synthetic@local.npjn.test",
      fullName: "Synthetic Rules Customer", plate: "TEST123", municipality: "Ligao",
      barangay: "Synthetic Barangay", vehicle: queue[0] === "G" ? "Gas" : "Diesel",
      vehicleCategory: "Car/Sedan", queue, date: day.date, status,
      source: "Appointment", quotaSource: "appointment",
    };
  }

  function walkIn(day, id, queue, status = "Waiting") {
    return {
      queue, queueId: queue, date: day.date, name: "Synthetic Rules Walk-in",
      plate: "TEST123", status, source: "Walk-in", quotaSource: "walkin",
      capacityRequestId: id, type: queue[0] === "G" ? "Gas" : "Diesel",
      vehicleCategory: "Car/Sedan",
    };
  }

  function reserveWrites(day, before, source, id, queue) {
    const next = structuredClone(before);
    delete next.updatedAt;
    next[source === "appointment" ? "appointmentClaims" : "walkInClaims"][id] = queue;
    const writes = [ledgerWrite(day, next, "reserve", source, id, queue)];
    if (source === "appointment") {
      writes.push(setWrite(`appointments/${id}`, appointment(day, id, queue), ["createdAt", "updatedAt"]));
    } else {
      writes.push(setWrite(`queues/${day.key}/items/${queue}`, walkIn(day, id, queue), ["createdAt", "updatedAt"]));
      writes.push(setWrite(`capacity_days/${day.key}/requests/${id}`, {
        adminId, payloadFingerprint: `${day.date}:${queue}:${id}`, queue, date: day.date,
      }, ["createdAt"]));
    }
    return writes;
  }

  async function reserve(day, source, id, queue, token = source === "appointment" ? customerToken : adminToken) {
    const snapshot = await db.doc(`capacity_days/${day.key}`).get();
    return commit(reserveWrites(day, snapshot.exists ? snapshot.data() : emptyDay(day), source, id, queue), token);
  }

  async function reserveTransaction(day, source, id, queue, token) {
    for (let attempt = 0; attempt < 4; attempt++) {
      // Flutter web/mobile transactions use optimistic document-version
      // preconditions. Explicit REST readWrite transactions instead take
      // pessimistic server locks and do not model the client being tested.
      const read = await rest(`/capacity_days/${day.key}`, token, undefined, "GET");
      assert.ok(read.status === 200 || read.status === 404, explain(read));
      const before = read.status === 200 ? decode({mapValue: {fields: read.body.fields}}) : emptyDay(day);
      const writes = reserveWrites(day, before, source, id, queue);
      writes[0].currentDocument = read.status === 200 ? {updateTime: read.body.updateTime} : {exists: false};
      const result = await commit(writes, token);
      if (!["ABORTED", "FAILED_PRECONDITION"].includes(result.body.error?.status) && result.status !== 409) return result;
    }
    throw new Error("Local contention did not settle after bounded transaction retries");
  }

  async function seed(day, appointmentCount = 0, walkInCount = 0) {
    const data = emptyDay(day);
    const batch = db.batch();
    for (const [source, count] of [["appointment", appointmentCount], ["walkin", walkInCount]]) {
      for (let index = 0; index < count; index++) {
        const id = `${run}-${day.key}-${source}-${index}`;
        const offset = source === "appointment" ? 0 : 75;
        const queue = `${index % 2 ? "D" : "G"}${String(offset + Math.floor(index / 2) + 1).padStart(3, "0")}`;
        data[source === "appointment" ? "appointmentClaims" : "walkInClaims"][id] = queue;
        batch.set(db.doc(source === "appointment" ? `appointments/${id}` : `queues/${day.key}/items/${queue}`),
          source === "appointment" ? appointment(day, id, queue) : walkIn(day, id, queue));
      }
    }
    batch.set(db.doc(`capacity_days/${day.key}`), {...data, lastMutation: {action: "migration", source: "appointment", claimId: "migration", queue: "G001"}, updatedAt: FieldValue.serverTimestamp()});
    await batch.commit();
    return data;
  }

  test("Spark capacity security rules use real Auth tokens and atomic REST commits", {timeout: 180000}, async (t) => {
    initialConfig = await config.get();
    try {
      const rulesResponse = await fetch(`${origin}/emulator/v1/projects/${project}:securityRules`, {
        method: "PUT", headers: {"Content-Type": "application/json"},
        body: JSON.stringify({rules: {files: [{name: "firestore.rules", content: readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8")}]}}),
      });
      assert.equal(rulesResponse.status, 200, await rulesResponse.text());
      ({uid: adminId, token: adminToken} = await tokenFor("admin", "admin"));
      ({uid: customerId, token: customerToken} = await tokenFor("customer", "customer"));
      ({token: secondCustomerToken} = await tokenFor("other", "customer"));
      ({token: unverifiedToken} = await tokenFor("unverified", "customer", false));
      await config.set({dailyLimit: 80, schemaVersion: 2, migrationComplete: true});

      await t.test("a new day needs exactly one paired verified-owner reservation", async () => {
        const day = dateFixture();
        const id = `${run}-new-day`;
        const record = appointment(day, id, "G001");
        await denied([setWrite(`appointments/${id}`, record)], customerToken);
        await denied(reserveWrites(day, emptyDay(day), "appointment", id, "G001"), secondCustomerToken);
        await denied(reserveWrites(day, emptyDay(day), "appointment", id, "G001"), unverifiedToken);
        const writes = reserveWrites(day, emptyDay(day), "appointment", id, "G001");
        await denied([writes[0]], customerToken);
        const poisoned = structuredClone(writes);
        poisoned[1].update.fields.autoApproved = {booleanValue: true};
        await denied(poisoned, customerToken);
        await allowed(writes, customerToken);
        assert.equal((await db.doc(`capacity_days/${day.key}`).get()).data().appointmentClaims[id], "G001");
      });

      await t.test("claims, legacy bindings, timestamps, gate, and source pools cannot be tampered with", async () => {
        const day = dateFixture();
        const before = await seed(day, 1, 0);
        const id = Object.keys(before.appointmentClaims)[0];
        const without = {...before, appointmentClaims: {}};
        await denied([ledgerWrite(day, without, "release", "appointment", id, "G001")]);
        await denied([ledgerWrite(day, {...before, legacyQueueClaims: {G001: {source: "walkin", claimId: "forged"}}}, "reserve", "walkin", "forged", "G002")]);
        await denied([setWrite(`capacity_days/${day.key}`, {...before, lastMutation: {action: "reserve", source: "appointment", claimId: "forged", queue: "G002"}, updatedAt: new Date()})]);
        await denied([setWrite("system_config/queue_capacity", {dailyLimit: 80, schemaVersion: 2, migrationComplete: false})]);
        await denied([setWrite("system_config/queue_capacity", {dailyLimit: 80, schemaVersion: 2, migrationComplete: true})], customerToken);
        await denied([setWrite(`queues/${day.key}/items/G002`, walkIn(day, "unreserved", "G002"))]);
        await denied([setWrite(`somewhere/test/items/G002`, walkIn(day, "unreserved", "G002"))]);
        await config.update({migrationComplete: false});
        await denied(reserveWrites(day, before, "appointment", `${run}-frozen`, "G002"), customerToken);
        await denied([setWrite("system_config/queue_capacity", {dailyLimit: 80, schemaVersion: 2, migrationComplete: true})]);
        await config.update({migrationComplete: true});
      });

      await t.test("new queue codes stay within the configured numeric range and match their fuel", async () => {
        const eighty = dateFixture();
        for (const source of ["appointment", "walkin"]) {
          for (const queue of ["G081", "D150"]) {
            const result = await reserve(eighty, source, `${run}-range80-${source}-${queue}`, queue);
            assert.equal(result.status, 403, explain(result));
          }
        }
        const validEighty = await reserve(eighty, "appointment", `${run}-range80-valid`, "G080");
        assert.equal(validEighty.status, 200, explain(validEighty));

        const wrongFuelDay = dateFixture();
        for (const source of ["appointment", "walkin"]) {
          const id = `${run}-wrong-fuel-${source}`;
          const writes = reserveWrites(wrongFuelDay, emptyDay(wrongFuelDay), source, id, "G001");
          writes[1].update.fields[source === "appointment" ? "vehicle" : "type"] = {stringValue: "Diesel"};
          await denied(writes, source === "appointment" ? customerToken : adminToken);
        }

        await allowed([setWrite("system_config/queue_capacity", {dailyLimit: 100}, ["updatedAt"], true)]);
        const hundred = dateFixture();
        const validHundred = await reserve(hundred, "appointment", `${run}-range100-valid`, "G100");
        assert.equal(validHundred.status, 200, explain(validHundred));
        const validWalkHundred = await reserve(hundred, "walkin", `${run}-range100-walk-valid`, "D100");
        assert.equal(validWalkHundred.status, 200, explain(validWalkHundred));
        for (const source of ["appointment", "walkin"]) {
          const result = await reserve(hundred, source, `${run}-range100-invalid-${source}`, "G101");
          assert.equal(result.status, 403, explain(result));
        }
        await config.update({dailyLimit: 80});
        const beforeLowered = (await db.doc(`capacity_days/${hundred.key}`).get()).data();
        const applicationId = `${run}-range100-valid`;
        const walkId = `${run}-range100-walk-valid`;
        const released = {...beforeLowered, appointmentClaims: {}};
        delete released.updatedAt;
        await allowed([
          ledgerWrite(hundred, released, "release", "appointment", applicationId, "G100"),
          setWrite(`appointments/${applicationId}`, {status: "Expired"}, [], true),
        ]);
        const completed = {...released, completedClaims: {[`walkin:${walkId}`]: {source: "walkin", queue: "D100"}}};
        await allowed([
          ledgerWrite(hundred, completed, "complete", "walkin", walkId, "D100"),
          setWrite(`queues/${hundred.key}/items/D100`, {status: "Passed"}, [], true),
        ]);
      });

      await t.test("39 mixed-fuel appointments racing for the last source slot admit exactly one", async () => {
        const day = dateFixture();
        await seed(day, 39, 0);
        const results = await Promise.all([
          reserveTransaction(day, "appointment", `${run}-last-gas`, "G070", customerToken),
          reserveTransaction(day, "appointment", `${run}-last-diesel`, "D070", customerToken),
        ]);
        assert.equal(results.filter((r) => r.status === 200).length, 1, results.map(explain).join("\n"));
        assert.equal(results.filter((r) => r.status === 403).length, 1, results.map(explain).join("\n"));
        assert.equal(Object.keys((await db.doc(`capacity_days/${day.key}`).get()).data().appointmentClaims).length, 40);
        const walkResult = await reserve(day, "walkin", `${run}-separate-pool`, "G071");
        assert.equal(walkResult.status, 200, explain(walkResult));
        const full = await reserve(day, "appointment", `${run}-cannot-borrow`, "D071");
        assert.equal(full.status, 403, explain(full));
      });

      await t.test("39 walk-ins racing for the last source slot admit exactly one", async () => {
        const day = dateFixture();
        await seed(day, 0, 39);
        const results = await Promise.all([
          reserveTransaction(day, "walkin", `${run}-last-walk-g`, "G070", adminToken),
          reserveTransaction(day, "walkin", `${run}-last-walk-d`, "D070", adminToken),
        ]);
        assert.equal(results.filter((r) => r.status === 200).length, 1, results.map(explain).join("\n"));
        assert.equal(results.filter((r) => r.status === 403).length, 1, results.map(explain).join("\n"));
        assert.equal(Object.keys((await db.doc(`capacity_days/${day.key}`).get()).data().walkInClaims).length, 40);
      });

      await t.test("appointment and walk-in cannot claim the same queue code concurrently", async () => {
        const day = dateFixture();
        await seed(day);
        const results = await Promise.all([
          reserveTransaction(day, "appointment", `${run}-collision-app`, "G001", customerToken),
          reserveTransaction(day, "walkin", `${run}-collision-walk`, "G001", adminToken),
        ]);
        assert.equal(results.filter((r) => r.status === 200).length, 1, results.map(explain).join("\n"));
        const saved = (await db.doc(`capacity_days/${day.key}`).get()).data();
        assert.equal(Object.keys(saved.appointmentClaims).length + Object.keys(saved.walkInClaims).length, 1);
      });

      await t.test("rejection must release atomically and the code is immediately reusable", async () => {
        const day = dateFixture();
        const before = await seed(day, 1, 0);
        const id = Object.keys(before.appointmentClaims)[0];
        await denied([setWrite(`appointments/${id}`, {status: "Rejected"}, [], true)]);
        const next = {...before, appointmentClaims: {}};
        await allowed([
          ledgerWrite(day, next, "release", "appointment", id, "G001"),
          setWrite(`appointments/${id}`, {status: "Rejected"}, [], true),
        ]);
        const result = await reserve(day, "appointment", `${run}-reused-code`, "G001");
        assert.equal(result.status, 200, explain(result));
      });

      await t.test("approval and OCR metadata preserve the original source claim without double counting", async () => {
        const day = dateFixture();
        const before = await seed(day, 1, 0);
        const id = Object.keys(before.appointmentClaims)[0];
        await allowed([setWrite(`appointments/${id}`, {documentReview: {status: "completed", score: 80}}, [], true)]);
        await denied([setWrite(`appointments/${id}`, {queue: "D010"}, [], true)]);
        const mirror = {...walkIn(day, "unused", "G001"), source: "Appointment", quotaSource: "appointment", appointmentId: id, customerId};
        delete mirror.capacityRequestId;
        await allowed([
          setWrite(`appointments/${id}`, {status: "Approved"}, [], true),
          setWrite(`queues/${day.key}/items/G001`, mirror),
        ]);
        assert.equal(Object.keys((await db.doc(`capacity_days/${day.key}`).get()).data().appointmentClaims).length, 1);
        await denied([
          ledgerWrite(day, {...before, appointmentClaims: {}}, "release", "appointment", id, "G001"),
          setWrite(`appointments/${id}`, {status: "Rejected"}, [], true),
        ]);
        await allowed([setWrite(`queues/${day.key}/items/G001`, {status: "Now Serving", source: "Appointment", originalSource: "Appointment"}, [], true)]);
      });

      await t.test("completed usage survives report deletion and cannot be released or replayed", async () => {
        const day = dateFixture();
        const before = await seed(day, 0, 1);
        const id = Object.keys(before.walkInClaims)[0];
        const queue = before.walkInClaims[id];
        await denied([setWrite(`queues/${day.key}/items/${queue}`, {status: "Passed"}, [], true)]);
        const completed = {...before, completedClaims: {[`walkin:${id}`]: {source: "walkin", queue}}};
        await allowed([
          ledgerWrite(day, completed, "complete", "walkin", id, queue),
          setWrite(`queues/${day.key}/items/${queue}`, {status: "Passed"}, [], true),
        ]);
        await denied([ledgerWrite(day, {...completed, walkInClaims: {}}, "release", "walkin", id, queue)]);
        await allowed([deleteWrite(`queues/${day.key}/items/${queue}`)]);
        assert.equal(Object.keys((await db.doc(`capacity_days/${day.key}`).get()).data().walkInClaims).length, 1);
        const result = await reserve(day, "walkin", `${run}-completed-replay`, queue);
        assert.equal(result.status, 403, explain(result));
      });

      await t.test("migrated legacy queue identities complete without rewriting legacy records", async () => {
        const day = dateFixture();
        const legacyId = `${run}-legacy-walkin`;
        const before = emptyDay(day);
        before.walkInClaims[legacyId] = "G001";
        before.legacyQueueClaims.G001 = {source: "walkin", claimId: legacyId};
        await db.doc(`capacity_days/${day.key}`).set({...before, updatedAt: FieldValue.serverTimestamp()});
        await db.doc(`queues/${day.key}/items/G001`).set({queue: "G001", queueId: "G001", date: day.date, source: "Skipped / No Show", status: "Skipped"});
        const next = {...before, completedClaims: {[`walkin:${legacyId}`]: {source: "walkin", queue: "G001"}}};
        await allowed([
          ledgerWrite(day, next, "complete", "walkin", legacyId, "G001"),
          setWrite(`queues/${day.key}/items/G001`, {status: "Failed", source: "Walk-in", originalSource: "Walk-in"}, [], true),
        ]);
      });

      await t.test("legacy queueId values remain unchanged during atomic status completion", async () => {
        const day = dateFixture();
        const id = `${run}-legacy-mismatched-queue-id`;
        const persistedQueueId = `${run}-historical-row-id`;
        const before = emptyDay(day);
        before.walkInClaims[id] = "G001";
        before.legacyQueueClaims.G001 = {source: "walkin", claimId: id};
        await db.doc(`capacity_days/${day.key}`).set({...before, updatedAt: FieldValue.serverTimestamp()});
        const queuePath = `queues/${day.key}/items/G001`;
        await db.doc(queuePath).set({queue: "G001", queueId: persistedQueueId,
          date: day.date, source: "Walk-in", status: "Now Serving"});
        const completed = {...before, completedClaims: {[`walkin:${id}`]: {source: "walkin", queue: "G001"}}};
        await denied([
          ledgerWrite(day, completed, "complete", "walkin", id, "G001"),
          setWrite(queuePath, {status: "Passed", queueId: "G001"}, [], true),
        ]);
        await allowed([
          ledgerWrite(day, completed, "complete", "walkin", id, "G001"),
          setWrite(queuePath, {status: "Passed"}, [], true),
        ]);
        const saved = (await db.doc(queuePath).get()).data();
        assert.equal(saved.status, "Passed");
        assert.equal(saved.queueId, persistedQueueId);
        assert.deepEqual((await db.doc(`capacity_days/${day.key}`).get()).data().completedClaims,
          completed.completedClaims);
      });

      await t.test("legacy appointment paths and nullable optional IDs resolve to their actual reservation", async () => {
        const day = dateFixture();
        const id = `${run}-legacy-path`;
        const before = emptyDay(day);
        before.appointmentClaims[id] = "D001";
        before.legacyQueueClaims.D001 = {source: "appointment", claimId: id};
        await db.doc(`capacity_days/${day.key}`).set({...before, updatedAt: FieldValue.serverTimestamp()});
        await db.doc(`queues/${day.key}/items/D001`).set({queue: "D001", queueId: "D001", date: day.date,
          source: "Appointment", status: "Waiting", appointmentId: null, capacityRequestId: null,
          _appointmentDocumentPath: ` appointments/${id} `});
        const next = {...before, completedClaims: {[`appointment:${id}`]: {source: "appointment", queue: "D001", appointmentId: id}}};
        await allowed([
          ledgerWrite(day, next, "complete", "appointment", id, "D001"),
          setWrite(`queues/${day.key}/items/D001`, {status: "Passed"}, [], true),
        ]);
      });

      await t.test("legacy appointment references win ambiguous IDs unless an explicit quota source overrides them", async () => {
        for (const explicitWalkIn of [false, true]) {
          const day = dateFixture();
          const appointmentId = `${run}-ambiguous-app-${explicitWalkIn}`;
          const walkId = `${run}-ambiguous-walk-${explicitWalkIn}`;
          const source = explicitWalkIn ? "walkin" : "appointment";
          const id = explicitWalkIn ? walkId : appointmentId;
          const before = emptyDay(day);
          before[explicitWalkIn ? "walkInClaims" : "appointmentClaims"][id] = "G001";
          before.legacyQueueClaims.G001 = {source, claimId: id};
          await db.doc(`capacity_days/${day.key}`).set({...before, updatedAt: FieldValue.serverTimestamp()});
          await db.doc(`queues/${day.key}/items/G001`).set({queue: "G001", queueId: "G001", date: day.date,
            status: "Waiting", source: "Appointment", appointmentId, capacityRequestId: walkId,
            quotaSource: explicitWalkIn ? " WALKIN " : null});
          const marker = {source, queue: "G001", ...(explicitWalkIn ? {} : {appointmentId})};
          const next = {...before, completedClaims: {[`${source}:${id}`]: marker}};
          await allowed([
            ledgerWrite(day, next, "complete", source, id, "G001"),
            setWrite(`queues/${day.key}/items/G001`, {status: "Passed"}, [], true),
          ]);
          const saved = (await db.doc(`capacity_days/${day.key}`).get()).data();
          assert.deepEqual(saved.appointmentClaims, before.appointmentClaims);
          assert.deepEqual(saved.walkInClaims, before.walkInClaims);
        }
      });

      await t.test("validated limit changes grandfather existing usage but do not admit more into an overfull source", async () => {
        const day = dateFixture();
        await config.update({dailyLimit: 120});
        const before = await seed(day, 50, 0);
        await allowed([setWrite("system_config/queue_capacity", {dailyLimit: 60}, ["updatedAt"], true)]);
        assert.equal(Object.keys((await db.doc(`capacity_days/${day.key}`).get()).data().appointmentClaims).length, 50);
        const result = await reserve(day, "appointment", `${run}-lowered-full`, "G070");
        assert.equal(result.status, 403, explain(result));
        const id = Object.keys(before.appointmentClaims)[0];
        const next = {...before, appointmentClaims: {...before.appointmentClaims}};
        delete next.appointmentClaims[id];
        await allowed([
          ledgerWrite(day, next, "release", "appointment", id, before.appointmentClaims[id]),
          setWrite(`appointments/${id}`, {status: "Expired"}, [], true),
        ]);
        await denied([setWrite("system_config/queue_capacity", {dailyLimit: 61}, [], true)]);
        await config.update({dailyLimit: 80});
      });

      await t.test("walk-in receipts are immutable and their reservation cannot be replayed", async () => {
        const day = dateFixture();
        const id = `${run}-receipt`;
        const result = await reserve(day, "walkin", id, "G001");
        assert.equal(result.status, 200, explain(result));
        const receipt = await rest(`/capacity_days/${day.key}/requests/${id}`, adminToken, undefined, "GET");
        assert.equal(receipt.status, 200, explain(receipt));
        await denied([setWrite(`capacity_days/${day.key}/requests/${id}`, {queue: "G002"}, [], true)]);
        await denied([setWrite(`queues/${day.key}/items/G002`, walkIn(day, id, "G002"))]);
        await denied([deleteWrite(`queues/${day.key}/items/G001`)]);
        const before = (await db.doc(`capacity_days/${day.key}`).get()).data();
        const next = {...before, walkInClaims: {}};
        delete next.updatedAt;
        await allowed([
          ledgerWrite(day, next, "release", "walkin", id, "G001"),
          setWrite(`queues/${day.key}/items/G001`, {status: "Cancelled"}, [], true),
        ]);
        const reused = await reserve(day, "walkin", `${run}-new-receipt`, "G001");
        assert.equal(reused.status, 200, explain(reused));
      });
    } finally {
      if (initialConfig?.exists) await config.set(initialConfig.data());
      else await config.delete();
      // Keep synthetic appointment fixtures until emulator shutdown: retention
      // triggers may still be processing their creation events asynchronously.
      await Promise.all(authIds.map((uid) => auth.deleteUser(uid)));
      await deleteApp(app);
    }
  });
}
