"use strict";

// Trusted, one-time metadata migration. This script never writes appointments,
// queue items, profiles, reports, uploads, or billing configuration.
const {createHash} = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");

const PROJECT_ID = "npjn-queue-system-jkr";
const CONFIG_PATH = "system_config/queue_capacity";
const IGNORED_STATUSES = new Set(["cancelled", "reset", "rejected", "expired"]);
const TERMINAL_STATUSES = new Set(["passed", "failed"]);
const SOURCE_FIELDS = [
  "date", "status", "queue", "queueId", "source", "originalSource", "quotaSource",
  "appointmentId", "_appointmentDocumentPath", "capacityRequestId",
];

function string(value) {
  return value == null ? "" : String(value).trim();
}

function canonicalDate(value) {
  if (typeof value !== "string" || !/^\d{1,2}\/\d{1,2}\/\d{4}$/.test(value)) {
    throw new Error("A source record has an invalid date; migration refused.");
  }
  const [month, day, year] = value.split("/").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (year < 2020 || year > 2100 || date.getUTCFullYear() !== year ||
      date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    throw new Error("A source record has an invalid date; migration refused.");
  }
  return `${month}/${day}/${year}`;
}

function dateKey(date) {
  return canonicalDate(date).replaceAll("/", "-");
}

function isAppointment(record) {
  const quotaSource = string(record.quotaSource).toLowerCase();
  if (quotaSource === "appointment") return true;
  if (quotaSource === "walkin") return false;
  return Boolean(string(record.appointmentId) || string(record._appointmentDocumentPath) ||
    [record.originalSource, record.source].some((value) =>
      string(value).toLowerCase().includes("appointment")));
}

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
  }
  return value;
}

function digest(value) {
  return createHash("sha256").update(JSON.stringify(canonical(value))).digest("hex");
}

function addClaim(claims, id, queue, date) {
  if (!id || !queue) throw new Error(`An incomplete reservation identity exists on ${date}; migration refused.`);
  if (Object.hasOwn(claims, id) && claims[id] !== queue) {
    throw new Error(`A reservation identity points to different queue codes on ${date}; migration refused.`);
  }
  claims[id] = queue;
}

function buildDay(date, appointmentRecords, queueRecords) {
  const appointmentClaims = Object.create(null);
  const walkInClaims = Object.create(null);
  const completedClaims = Object.create(null);
  const legacyQueueClaims = Object.create(null);
  const byCode = new Map();
  const appointments = [...appointmentRecords].sort((a, b) => a.id.localeCompare(b.id));
  const queues = [...queueRecords].sort((a, b) => a.id.localeCompare(b.id));

  for (const record of appointments) {
    const code = string(record.queue);
    const status = string(record.status).toLowerCase();
    if (!code) throw new Error(`An appointment has no queue code on ${date}; migration refused.`);
    const candidate = byCode.get(code);
    const priority = status === "approved" ? 2 : status === "pending" ? 1 : 0;
    if (!candidate || priority > candidate.priority) byCode.set(code, {id: record.id, priority});
    if (status === "pending" || status === "approved") {
      // Document identity wins over any obsolete embedded appointmentId value.
      addClaim(appointmentClaims, record.id, code, date);
    }
  }

  for (const record of queues) {
    const status = string(record.status).toLowerCase();
    if (IGNORED_STATUSES.has(status)) continue;
    const code = string(record.queue) || string(record.queueId) || record.id;
    const source = isAppointment(record) ? "appointment" : "walkin";
    let claimId;
    if (source === "appointment") {
      const pathId = string(record._appointmentDocumentPath).split("/").filter(Boolean).at(-1);
      claimId = string(record.appointmentId) || pathId || byCode.get(code)?.id ||
        `legacy_appointment_${record.id}`;
      addClaim(appointmentClaims, claimId, code, date);
    } else {
      claimId = string(record.capacityRequestId) || `legacy_${record.id}`;
      addClaim(walkInClaims, claimId, code, date);
    }
    legacyQueueClaims[record.id] = {source, claimId};
    if (TERMINAL_STATUSES.has(status)) {
      completedClaims[`${source}:${claimId}`] = {
        source, queue: code, ...(source === "appointment" ? {appointmentId: claimId} : {}),
      };
    }
  }

  return {
    schemaVersion: 2,
    date,
    appointmentClaims: {...appointmentClaims},
    walkInClaims: {...walkInClaims},
    completedClaims: {...completedClaims},
    legacyQueueClaims: {...legacyQueueClaims},
    lastMutation: {action: "migration", source: "system", claimId: "", queue: ""},
  };
}

function decodeValue(value) {
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("mapValue" in value) return decodeFields(value.mapValue.fields || {});
  if ("arrayValue" in value) return (value.arrayValue.values || []).map(decodeValue);
  return null;
}

function decodeFields(fields = {}) {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]));
}

function encodeValue(value) {
  if (typeof value === "string") return {stringValue: value};
  if (typeof value === "boolean") return {booleanValue: value};
  if (Number.isInteger(value)) return {integerValue: String(value)};
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return {mapValue: {fields: encodeFields(value)}};
  }
  throw new Error("Unsupported migration metadata value.");
}

function encodeFields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key, encodeValue(value)]));
}

class MigrationStore {
  constructor({projectId, endpoint, accessToken}) {
    this.projectId = projectId;
    this.base = `${endpoint}/v1/projects/${projectId}/databases/(default)/documents`;
    this.accessToken = accessToken;
  }

  name(documentPath) {
    if (documentPath !== CONFIG_PATH && !/^capacity_days\/[^/]+$/.test(documentPath)) {
      throw new Error("Migration may write only capacity metadata.");
    }
    return `projects/${this.projectId}/databases/(default)/documents/${documentPath}`;
  }

  async request(url, options = {}) {
    const response = await fetch(url, {
      ...options,
      headers: {"Content-Type": "application/json", Authorization: `Bearer ${this.accessToken}`},
    });
    if (!response.ok) {
      const error = new Error(`Capacity metadata operation failed: HTTP ${response.status}.`);
      error.status = response.status;
      throw error;
    }
    return response.status === 204 ? null : response.json();
  }

  async get(documentPath) {
    try {
      const document = await this.request(`${this.base}/${documentPath.split("/").map(encodeURIComponent).join("/")}`);
      return {exists: true, data: decodeFields(document.fields), updateTime: document.updateTime};
    } catch (error) {
      if (error.status === 404) return {exists: false, data: null};
      throw error;
    }
  }

  async query(collectionId, {descendants = false, projection = SOURCE_FIELDS} = {}) {
    const rows = await this.request(`${this.base}:runQuery`, {
      method: "POST",
      body: JSON.stringify({structuredQuery: {
        from: [{collectionId, allDescendants: descendants}],
        select: {fields: projection.map((fieldPath) => ({fieldPath}))},
      }}),
    });
    return rows.filter((row) => row.document).map(({document}) => ({
      ...decodeFields(document.fields), id: document.name.split("/").at(-1),
      path: document.name.split("/documents/")[1],
    }));
  }

  async putLedger(documentPath, data, previous) {
    await this.request(`${this.base}:commit`, {
      method: "POST",
      body: JSON.stringify({writes: [{
        update: {name: this.name(documentPath), fields: encodeFields(data)},
        currentDocument: previous?.exists ? {updateTime: previous.updateTime} : {exists: false},
        updateTransforms: [{fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME"}],
      }]}),
    });
  }

  async finish(config) {
    await this.request(`${this.base}:commit`, {
      method: "POST",
      body: JSON.stringify({writes: [{
        update: {name: this.name(CONFIG_PATH), fields: encodeFields({schemaVersion: 2, migrationComplete: true})},
        updateMask: {fieldPaths: ["schemaVersion", "migrationComplete"]},
        currentDocument: {updateTime: config.updateTime},
        updateTransforms: [{fieldPath: "migrationVerifiedAt", setToServerValue: "REQUEST_TIME"}],
      }]}),
    });
  }
}

async function readPlan(store) {
  const [appointments, items] = await Promise.all([
    store.query("appointments"), store.query("items", {descendants: true}),
  ]);
  const queueItems = items.filter((record) => /^queues\/[^/]+\/items\/[^/]+$/.test(record.path));
  const dates = new Map();
  for (const record of appointments) {
    const date = canonicalDate(record.date);
    if (!dates.has(date)) dates.set(date, {appointments: [], queueItems: []});
    dates.get(date).appointments.push(record);
  }
  for (const record of queueItems) {
    const parentDate = canonicalDate(record.path.split("/")[1].replaceAll("-", "/"));
    const date = record.date ? canonicalDate(record.date) : parentDate;
    if (date !== parentDate) throw new Error("A queue record date differs from its containing day; migration refused.");
    if (!dates.has(date)) dates.set(date, {appointments: [], queueItems: []});
    dates.get(date).queueItems.push(record);
  }
  const days = [...dates.entries()].map(([date, records]) => {
    const ledger = buildDay(date, records.appointments, records.queueItems);
    const projection = [...records.appointments, ...records.queueItems]
        .sort((a, b) => a.path.localeCompare(b.path));
    return {date, records, ledger, sourceHash: digest(projection)};
  }).sort((a, b) => {
    const dateNumber = (value) => { const [m, d, y] = value.split("/").map(Number); return Date.UTC(y, m - 1, d); };
    return dateNumber(a.date) - dateNumber(b.date);
  });
  return {days, sourceHash: digest(days.map((day) => [day.date, day.sourceHash])),
    appointmentDocuments: appointments.length, queueDocuments: queueItems.length};
}

function ledgerState(data) {
  return {
    date: data.date,
    appointmentClaims: data.appointmentClaims || {},
    walkInClaims: data.walkInClaims || {},
    completedClaims: data.completedClaims || {},
    legacyQueueClaims: data.legacyQueueClaims || {},
  };
}

function summary(plan) {
  return {
    appointmentDocuments: plan.appointmentDocuments,
    queueDocuments: plan.queueDocuments,
    sourceHash: plan.sourceHash,
    dates: plan.days.map(({date, ledger, sourceHash}) => ({
      date, appointmentDocuments: plan.days.find((day) => day.date === date).records.appointments.length,
      queueDocuments: plan.days.find((day) => day.date === date).records.queueItems.length,
      appointmentUsed: Object.keys(ledger.appointmentClaims).length,
      walkInUsed: Object.keys(ledger.walkInClaims).length,
      completedReservations: Object.keys(ledger.completedClaims).length,
      sourceHash,
    })),
  };
}

function requireFrozenConfig(snapshot) {
  if (!snapshot.exists || snapshot.data.schemaVersion !== 2 ||
      snapshot.data.dailyLimit !== 80 || snapshot.data.migrationComplete !== false) {
    throw new Error("Apply requires the reviewed schemaVersion 2 / dailyLimit 80 / migrationComplete false configuration and deployed freeze rules.");
  }
}

async function migrate(store, {apply = false, emulator = false} = {}) {
  const config = await store.get(CONFIG_PATH);
  if (apply) requireFrozenConfig(config);
  const plan = await readPlan(store);
  const result = {projectId: PROJECT_ID, mode: apply ? "apply" : "dry-run", emulator,
    ...summary(plan), createdDays: 0, skippedInitializedDays: 0, replacedEmulatorDays: 0,
    verified: false, migrationComplete: config.data?.migrationComplete === true};
  if (!apply) return result;

  for (const day of plan.days) {
    const ledgerPath = `capacity_days/${dateKey(day.date)}`;
    const existing = await store.get(ledgerPath);
    if (existing.exists && existing.data.schemaVersion === 2) {
      result.skippedInitializedDays++;
      continue;
    }
    if (existing.exists && !emulator) {
      throw new Error(`An existing non-v2 ledger requires review on ${day.date}; no production ledger was overwritten.`);
    }
    try {
      await store.putLedger(ledgerPath, day.ledger, existing.exists ? existing : undefined);
      if (existing.exists) result.replacedEmulatorDays++;
      else result.createdDays++;
    } catch (error) {
      if (error.status !== 409) throw error;
      const concurrent = await store.get(ledgerPath);
      if (!concurrent.exists || concurrent.data.schemaVersion !== 2) throw error;
      result.skippedInitializedDays++;
    }
  }

  // A second full projection proves quota-affecting source fields stayed frozen.
  const fresh = await readPlan(store);
  if (fresh.sourceHash !== plan.sourceHash) {
    throw new Error("Source reservations changed during migration. The freeze remains active; rerun after reviewing the rules.");
  }
  for (const day of fresh.days) {
    const saved = await store.get(`capacity_days/${dateKey(day.date)}`);
    if (!saved.exists || saved.data.schemaVersion !== 2 ||
        digest(ledgerState(saved.data)) !== digest(ledgerState(day.ledger))) {
      throw new Error(`Ledger verification failed on ${day.date}. Existing claims were left untouched and the freeze remains active.`);
    }
  }
  const currentConfig = await store.get(CONFIG_PATH);
  requireFrozenConfig(currentConfig);
  if (currentConfig.updateTime !== config.updateTime) {
    throw new Error("Capacity configuration changed during migration; activation refused.");
  }
  await store.finish(currentConfig);
  const activated = await store.get(CONFIG_PATH);
  if (activated.data?.migrationComplete !== true) throw new Error("Capacity activation could not be confirmed.");
  result.verified = true;
  result.migrationComplete = true;
  return result;
}

async function createStore({projectId, emulator}) {
  if (projectId !== PROJECT_ID) throw new Error("Only the explicitly authorized NPJN project is supported.");
  if (emulator) {
    const host = process.env.FIRESTORE_EMULATOR_HOST;
    if (!host || !/^(localhost|127\.0\.0\.1|\[::1\]):\d+$/.test(host)) {
      throw new Error("Emulator mode requires a loopback FIRESTORE_EMULATOR_HOST.");
    }
    return new MigrationStore({projectId, endpoint: `http://${host}`, accessToken: "owner"});
  }
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Production mode refuses an emulator environment. Use --emulator or unset the emulator variables.");
  }
  const cliRoot = process.env.FIREBASE_TOOLS_LIB || path.join(
      process.env.APPDATA || "", "npm", "node_modules", "firebase-tools", "lib");
  const auth = require(path.join(cliRoot, "auth"));
  const account = auth.getProjectDefaultAccount(process.cwd()) || auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) throw new Error("Sign in to the Firebase CLI before running the migration.");
  const credential = await auth.getAccessToken(account.tokens.refresh_token, ["https://www.googleapis.com/auth/cloud-platform"]);
  if (!credential.access_token) throw new Error("Firebase CLI authorization is unavailable.");
  return new MigrationStore({projectId, endpoint: "https://firestore.googleapis.com", accessToken: credential.access_token});
}

async function main(argv = process.argv.slice(2)) {
  const apply = argv.includes("--apply");
  const emulator = argv.includes("--emulator");
  const projectArgument = argv.find((argument) => argument.startsWith("--project="));
  const projectId = projectArgument?.slice("--project=".length) || PROJECT_ID;
  if (apply && !projectArgument) throw new Error("Apply requires an explicit --project=npjn-queue-system-jkr argument.");
  if (argv.some((argument) => argument !== "--apply" && argument !== "--emulator" &&
      !argument.startsWith("--project="))) throw new Error("Unsupported migration argument.");
  const store = await createStore({projectId, emulator});
  const result = await migrate(store, {apply, emulator});
  if (apply) {
    const outputDir = path.resolve(process.cwd(), "output", "deployment");
    await fs.mkdir(outputDir, {recursive: true});
    const suffix = new Date().toISOString().replace(/[:.]/g, "-");
    const summaryPath = path.join(outputDir, `spark-capacity-migration-${suffix}.json`);
    await fs.writeFile(summaryPath, JSON.stringify(result, null, 2) + "\n", {flag: "wx"});
    result.summaryPath = summaryPath;
  }
  console.log(JSON.stringify(result, null, 2));
  return result;
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {buildDay, canonicalDate, createStore, ledgerState, main, migrate, readPlan};
