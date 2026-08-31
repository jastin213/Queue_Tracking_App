"use strict";

const {
  applicationDefault,
  initializeApp,
} = require("firebase-admin/app");
const {
  Timestamp,
  getFirestore,
} = require("firebase-admin/firestore");

const DEFAULT_PROJECT_ID = "npjn-queue-system-jkr";
const DEFAULT_BATCH_ID = "final-defense-2026";
const MANILA_TIME_ZONE = "Asia/Manila";
const MAX_BATCH_WRITES = 400;

function argumentValue(name, fallback) {
  const prefix = `--${name}=`;
  const argument = process.argv.find((value) => value.startsWith(prefix));
  return argument ? argument.slice(prefix.length) : fallback;
}

function hasFlag(name) {
  return process.argv.includes(`--${name}`);
}

function safeBatchId(value) {
  const normalized = value.toLowerCase().replace(/[^a-z0-9_-]/g, "-");
  if (!normalized || normalized.length > 60) {
    throw new Error("The demo batch ID must contain 1-60 safe characters.");
  }
  return normalized;
}

function todayInManila() {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: MANILA_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function parseIsoDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new Error("Use --date=YYYY-MM-DD for the demo anchor date.");
  }
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    throw new Error(`Invalid demo date: ${value}`);
  }
  return date;
}

function dateParts(date) {
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth() + 1,
    day: date.getUTCDate(),
  };
}

function mdy(date) {
  const {year, month, day} = dateParts(date);
  return `${month}/${day}/${year}`;
}

function ymd(date) {
  const {year, month, day} = dateParts(date);
  return `${year}${String(month).padStart(2, "0")}${String(day).padStart(2, "0")}`;
}

function queueDateId(date) {
  return mdy(date).replaceAll("/", "-");
}

function monthSample(anchorDate, monthOffset) {
  return new Date(Date.UTC(
      anchorDate.getUTCFullYear(),
      anchorDate.getUTCMonth() + monthOffset,
      15,
  ));
}

function timestampAt(date, hour, minute = 0) {
  return Timestamp.fromDate(new Date(Date.UTC(
      date.getUTCFullYear(),
      date.getUTCMonth(),
      date.getUTCDate(),
      hour,
      minute,
  )));
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

function normalizedName(value) {
  return value.trim().toUpperCase().replace(/\s+/g, " ");
}

function normalizedPlate(value) {
  return value.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
}

function searchFields(date, plate, name) {
  return {
    dateTimestamp: timestampAt(date, 0),
    plateNormalized: normalizedPlate(plate),
    nameNormalized: normalizedName(name),
  };
}

function demoIdentity(serial) {
  const suffix = String(serial).padStart(3, "0");
  return {
    name: `Demo Customer ${suffix}`,
    plate: `DMO${suffix}`,
    email: `demo.customer.${suffix}@example.invalid`,
    municipality: ["Ligao City", "Oas", "Polangui", "Guinobatan"][serial % 4],
  };
}

function queueCode(serial) {
  const type = serial % 2 === 0 ? "Gas" : "Diesel";
  const prefix = type === "Gas" ? "G" : "D";
  return {code: `${prefix}${String(serial).padStart(3, "0")}`, type};
}

function terminalQueueRecord({date, serial, status, batchId, createdHour = 8}) {
  const identity = demoIdentity(serial);
  const {code, type} = queueCode(serial);
  const createdAt = timestampAt(date, createdHour, serial % 50);
  const completedAt = Timestamp.fromMillis(createdAt.toMillis() + 20 * 60 * 1000);
  return {
    path: `queues/${queueDateId(date)}/items/${code}`,
    data: {
      queueId: code,
      queue: code,
      name: identity.name,
      plate: identity.plate,
      type,
      date: mdy(date),
      ...searchFields(date, identity.plate, identity.name),
      source: "Walk-in",
      status,
      result: status,
      time: `${createdHour}:${String(serial % 50).padStart(2, "0")} AM`,
      createdAt,
      updatedAt: completedAt,
      completedAt,
      isDemo: true,
      demoLabel: "FINAL DEFENSE SAMPLE DATA",
      seedBatchId: batchId,
    },
  };
}

function appointmentRecord({
  date,
  serial,
  status,
  batchId,
  appointmentId,
  hasDocuments = false,
  documentBytes = 0,
}) {
  const identity = demoIdentity(serial);
  const {code, type} = queueCode(serial);
  const createdAt = timestampAt(date, 7, serial % 50);
  const statusField = status === "Approved" ? "approvedAt" :
    status === "Rejected" ? "rejectedAt" : null;
  return {
    path: `appointments/${appointmentId}`,
    data: {
      appointmentId,
      customerId: `demo-customer-${String(serial).padStart(3, "0")}`,
      customerEmail: identity.email,
      fullName: identity.name,
      municipality: identity.municipality,
      plate: identity.plate,
      vehicle: type,
      queue: code,
      date: mdy(date),
      ...searchFields(date, identity.plate, identity.name),
      status,
      source: "Appointment",
      idFile: hasDocuments ? "DEMO_ID.pdf" : null,
      orFile: hasDocuments ? "DEMO_OR.pdf" : null,
      crFile: hasDocuments ? "DEMO_CR.pdf" : null,
      idFileUrl: null,
      orFileUrl: null,
      crFileUrl: null,
      idStoragePath: null,
      orStoragePath: null,
      crStoragePath: null,
      idFileUploaded: hasDocuments,
      orFileUploaded: hasDocuments,
      crFileUploaded: hasDocuments,
      documentBackend: hasDocuments ? "firestore" : "demo-no-files",
      archiveState: "active",
      documentsPurged: false,
      retentionDeleteAfter: Timestamp.fromDate(addDays(createdAt.toDate(), 365)),
      totalDocumentBytes: documentBytes,
      createdAt,
      updatedAt: createdAt,
      ...(statusField ? {[statusField]: createdAt} : {}),
      isDemo: true,
      demoLabel: "FINAL DEFENSE SAMPLE DATA",
      seedBatchId: batchId,
    },
  };
}

function escapePdfText(value) {
  return value.replace(/([\\()])/g, "\\$1");
}

function createDemoPdf(documentType, batchId) {
  const lines = [
    "DEMO DOCUMENT - NOT A REAL CUSTOMER FILE",
    `Document type: ${documentType}`,
    `Seed batch: ${batchId}`,
    "Created only for the final system demonstration.",
  ];
  const commands = ["BT", "/F1 17 Tf", "42 235 Td"];
  for (let index = 0; index < lines.length; index += 1) {
    if (index > 0) commands.push("0 -32 Td");
    commands.push(`(${escapePdfText(lines[index])}) Tj`);
  }
  commands.push("ET");
  const stream = `${commands.join("\n")}\n`;
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 300] " +
      "/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    `<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}endstream`,
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>",
  ];
  let content = "%PDF-1.4\n";
  const offsets = [0];
  for (let index = 0; index < objects.length; index += 1) {
    offsets.push(Buffer.byteLength(content));
    content += `${index + 1} 0 obj\n${objects[index]}\nendobj\n`;
  }
  const xrefOffset = Buffer.byteLength(content);
  content += `xref\n0 ${objects.length + 1}\n`;
  content += "0000000000 65535 f \n";
  for (const offset of offsets.slice(1)) {
    content += `${String(offset).padStart(10, "0")} 00000 n \n`;
  }
  content += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n`;
  content += `startxref\n${xrefOffset}\n%%EOF\n`;
  return Buffer.from(content);
}

function documentRecords(appointmentId, customerId, batchId) {
  const records = [];
  let totalBytes = 0;
  for (const type of ["ID", "OR", "CR"]) {
    const bytes = createDemoPdf(type, batchId);
    totalBytes += bytes.length;
    const documentPath = `appointments/${appointmentId}/documents/${type.toLowerCase()}`;
    records.push({
      path: documentPath,
      data: {
        customerId,
        documentType: type,
        fileName: `DEMO_${type}.pdf`,
        contentType: "application/pdf",
        size: bytes.length,
        chunkCount: 1,
        createdAt: Timestamp.now(),
        isDemo: true,
        seedBatchId: batchId,
      },
    });
    records.push({
      path: `${documentPath}/chunks/000000`,
      data: {
        customerId,
        index: 0,
        data: bytes,
        isDemo: true,
        seedBatchId: batchId,
      },
    });
  }
  return {records, totalBytes};
}

function createPlan(anchorDate, batchId) {
  const records = [];
  const passedByMonth = [5, 7, 6, 9, 8, 10];
  const failedByMonth = [1, 2, 1, 2, 3, 2];
  const approvedByMonth = [2, 3, 3, 4, 4, 5];
  const rejectedByMonth = [1, 1, 0, 1, 1, 1];

  for (let monthIndex = 0; monthIndex < 6; monthIndex += 1) {
    const date = monthSample(anchorDate, monthIndex - 5);
    let serial = 51;
    for (let index = 0; index < passedByMonth[monthIndex]; index += 1) {
      records.push(terminalQueueRecord({
        date,
        serial: serial++,
        status: "Passed",
        batchId,
      }));
    }
    for (let index = 0; index < failedByMonth[monthIndex]; index += 1) {
      records.push(terminalQueueRecord({
        date,
        serial: serial++,
        status: "Failed",
        batchId,
      }));
    }

    let appointmentSerial = 31;
    const monthKey = ymd(date).slice(0, 6);
    for (let index = 0; index < approvedByMonth[monthIndex]; index += 1) {
      const appointmentId = `demo_${batchId}_${monthKey}_approved_${index + 1}`;
      records.push(appointmentRecord({
        date,
        serial: appointmentSerial++,
        status: "Approved",
        batchId,
        appointmentId,
      }));
    }
    for (let index = 0; index < rejectedByMonth[monthIndex]; index += 1) {
      const appointmentId = `demo_${batchId}_${monthKey}_rejected_${index + 1}`;
      records.push(appointmentRecord({
        date,
        serial: appointmentSerial++,
        status: "Rejected",
        batchId,
        appointmentId,
      }));
    }
  }

  for (let index = 0; index < 8; index += 1) {
    records.push(terminalQueueRecord({
      date: anchorDate,
      serial: 71 + index,
      status: index < 6 ? "Passed" : "Failed",
      batchId,
      createdHour: 9,
    }));
  }

  let dailyAppointmentSerial = 71;
  for (let index = 0; index < 3; index += 1) {
    const appointmentId = `demo_${batchId}_${ymd(anchorDate)}_approved_${index + 1}`;
    records.push(appointmentRecord({
      date: anchorDate,
      serial: dailyAppointmentSerial++,
      status: "Approved",
      batchId,
      appointmentId,
    }));
  }
  const rejectedId = `demo_${batchId}_${ymd(anchorDate)}_rejected_1`;
  records.push(appointmentRecord({
    date: anchorDate,
    serial: dailyAppointmentSerial++,
    status: "Rejected",
    batchId,
    appointmentId: rejectedId,
  }));

  const pendingId = `demo_${batchId}_${ymd(anchorDate)}_pending_1`;
  const customerId = `demo-customer-${String(dailyAppointmentSerial).padStart(3, "0")}`;
  const demoDocuments = documentRecords(pendingId, customerId, batchId);
  records.push(appointmentRecord({
    date: anchorDate,
    serial: dailyAppointmentSerial,
    status: "Pending",
    batchId,
    appointmentId: pendingId,
    hasDocuments: true,
    documentBytes: demoDocuments.totalBytes,
  }));
  records.push(...demoDocuments.records);

  const uniqueRecords = new Map();
  for (const record of records) {
    if (uniqueRecords.has(record.path)) {
      throw new Error(`Seeder generated a duplicate path: ${record.path}`);
    }
    uniqueRecords.set(record.path, record);
  }

  return [...uniqueRecords.values()];
}

function manifestPath(batchId) {
  return `system_config/demo_seed_${batchId}`;
}

class AdminStore {
  constructor(projectId) {
    initializeApp({projectId, credential: applicationDefault()});
    this.db = getFirestore();
  }

  async get(path) {
    const snapshot = await this.db.doc(path).get();
    return {
      path,
      exists: snapshot.exists,
      data: snapshot.exists ? snapshot.data() : null,
    };
  }

  async getAll(paths) {
    const snapshots = await this.db.getAll(...paths.map((path) => this.db.doc(path)));
    return snapshots.map((snapshot, index) => ({
      path: paths[index],
      exists: snapshot.exists,
      data: snapshot.exists ? snapshot.data() : null,
    }));
  }

  async setMany(records) {
    for (let offset = 0; offset < records.length; offset += MAX_BATCH_WRITES) {
      const batch = this.db.batch();
      for (const record of records.slice(offset, offset + MAX_BATCH_WRITES)) {
        batch.set(this.db.doc(record.path), record.data, {merge: false});
      }
      await batch.commit();
    }
  }

  async set(path, data) {
    await this.db.doc(path).set(data, {merge: false});
  }

  async deleteMany(paths) {
    for (let offset = 0; offset < paths.length; offset += MAX_BATCH_WRITES) {
      const batch = this.db.batch();
      for (const path of paths.slice(offset, offset + MAX_BATCH_WRITES)) {
        batch.delete(this.db.doc(path));
      }
      await batch.commit();
    }
  }

  async delete(path) {
    await this.db.doc(path).delete();
  }
}

function encodeFirestoreValue(value) {
  if (value === null) return {nullValue: null};
  if (value instanceof Timestamp) {
    return {timestampValue: value.toDate().toISOString()};
  }
  if (Buffer.isBuffer(value)) {
    return {bytesValue: value.toString("base64")};
  }
  if (Array.isArray(value)) {
    return {arrayValue: {values: value.map(encodeFirestoreValue)}};
  }
  if (typeof value === "boolean") return {booleanValue: value};
  if (typeof value === "string") return {stringValue: value};
  if (typeof value === "number") {
    return Number.isInteger(value) ?
      {integerValue: String(value)} : {doubleValue: value};
  }
  if (typeof value === "object") {
    const fields = {};
    for (const [key, childValue] of Object.entries(value)) {
      if (childValue !== undefined) fields[key] = encodeFirestoreValue(childValue);
    }
    return {mapValue: {fields}};
  }
  throw new Error(`Unsupported Firestore demo value: ${typeof value}`);
}

function encodeFirestoreFields(data) {
  const fields = {};
  for (const [key, value] of Object.entries(data)) {
    if (value !== undefined) fields[key] = encodeFirestoreValue(value);
  }
  return fields;
}

function decodeFirestoreValue(value) {
  if ("nullValue" in value) return null;
  if ("booleanValue" in value) return value.booleanValue;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("bytesValue" in value) return Buffer.from(value.bytesValue, "base64");
  if ("arrayValue" in value) {
    return (value.arrayValue.values || []).map(decodeFirestoreValue);
  }
  if ("mapValue" in value) return decodeFirestoreFields(value.mapValue.fields || {});
  return undefined;
}

function decodeFirestoreFields(fields) {
  return Object.fromEntries(
      Object.entries(fields || {}).map(([key, value]) => [key, decodeFirestoreValue(value)]),
  );
}

class RestStore {
  constructor(projectId, accessToken) {
    this.projectId = projectId;
    this.accessToken = accessToken;
    this.baseUrl = "https://firestore.googleapis.com/v1/projects/" +
      `${encodeURIComponent(projectId)}/databases/(default)/documents`;
  }

  encodedPath(path) {
    return path.split("/").map(encodeURIComponent).join("/");
  }

  documentName(path) {
    return `projects/${this.projectId}/databases/(default)/documents/${path}`;
  }

  async request(url, options = {}) {
    const response = await fetch(url, {
      ...options,
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        "Content-Type": "application/json",
        ...(options.headers || {}),
      },
    });
    if (!response.ok) {
      const body = await response.text();
      const error = new Error(`Firestore REST ${response.status}: ${body}`);
      error.status = response.status;
      throw error;
    }
    if (response.status === 204) return null;
    return response.json();
  }

  async get(path) {
    try {
      const document = await this.request(`${this.baseUrl}/${this.encodedPath(path)}`);
      return {path, exists: true, data: decodeFirestoreFields(document.fields)};
    } catch (error) {
      if (error.status === 404) return {path, exists: false, data: null};
      throw error;
    }
  }

  async getAll(paths) {
    const snapshots = [];
    for (let offset = 0; offset < paths.length; offset += 20) {
      const group = paths.slice(offset, offset + 20);
      snapshots.push(...await Promise.all(group.map((path) => this.get(path))));
    }
    return snapshots;
  }

  async commit(writes) {
    if (writes.length === 0) return;
    await this.request(`${this.baseUrl}:commit`, {
      method: "POST",
      body: JSON.stringify({writes}),
    });
  }

  async setMany(records) {
    for (let offset = 0; offset < records.length; offset += MAX_BATCH_WRITES) {
      const writes = records.slice(offset, offset + MAX_BATCH_WRITES).map((record) => ({
        update: {
          name: this.documentName(record.path),
          fields: encodeFirestoreFields(record.data),
        },
      }));
      await this.commit(writes);
    }
  }

  async set(path, data) {
    await this.setMany([{path, data}]);
  }

  async deleteMany(paths) {
    for (let offset = 0; offset < paths.length; offset += MAX_BATCH_WRITES) {
      await this.commit(paths.slice(offset, offset + MAX_BATCH_WRITES).map((path) => ({
        delete: this.documentName(path),
      })));
    }
  }

  async delete(path) {
    await this.deleteMany([path]);
  }
}

function initializeStore(projectId) {
  const accessToken = process.env.FIREBASE_ACCESS_TOKEN;
  return accessToken ? new RestStore(projectId, accessToken) : new AdminStore(projectId);
}

async function ensureSafeTargets(store, records, batchId) {
  const snapshots = await store.getAll(records.map((record) => record.path));
  const conflicts = snapshots.filter((snapshot) => {
    if (!snapshot.exists) return false;
    const data = snapshot.data;
    return data?.isDemo !== true || data?.seedBatchId !== batchId;
  });
  if (conflicts.length > 0) {
    const paths = conflicts.slice(0, 8).map((snapshot) => snapshot.path);
    throw new Error(
        "Demo seeding stopped because real or unrelated records already use " +
        `these paths: ${paths.join(", ")}`,
    );
  }
}

async function seed({projectId, batchId, anchorDate, apply}) {
  const records = createPlan(anchorDate, batchId);
  const queueCount = records.filter((record) => record.path.startsWith("queues/")).length;
  const appointmentCount = records.filter((record) =>
    /^appointments\/[^/]+$/.test(record.path)).length;
  const documentCount = records.length - queueCount - appointmentCount;

  console.log("Demo seed preview");
  console.log(`  Project: ${projectId}`);
  console.log(`  Batch: ${batchId}`);
  console.log(`  Report date: ${mdy(anchorDate)}`);
  console.log(`  Queue records: ${queueCount}`);
  console.log(`  Appointment records: ${appointmentCount}`);
  console.log(`  Demo document records: ${documentCount}`);

  if (!apply) {
    console.log("Preview only. Add --apply to write these demo records.");
    return;
  }

  const store = initializeStore(projectId);
  const demoManifestPath = manifestPath(batchId);
  const existingManifest = await store.get(demoManifestPath);
  if (existingManifest.exists) {
    const existingDate = existingManifest.data?.anchorDate;
    if (existingDate !== mdy(anchorDate)) {
      throw new Error(
          `Batch ${batchId} already exists for ${existingDate}. ` +
          "Run demo:cleanup before seeding it for another date.",
      );
    }
  }

  await ensureSafeTargets(store, records, batchId);
  await store.setMany(records);
  await store.set(demoManifestPath, {
    isDemo: true,
    seedBatchId: batchId,
    anchorDate: mdy(anchorDate),
    projectId,
    recordPaths: records.map((record) => record.path),
    queueCount,
    appointmentCount,
    documentCount,
    seededAt: Timestamp.now(),
  });

  const verification = await store.getAll(records.map((record) => record.path));
  const verifiedCount = verification.filter((snapshot) => snapshot.exists).length;
  if (verifiedCount !== records.length) {
    throw new Error(`Only ${verifiedCount}/${records.length} demo records were verified.`);
  }

  console.log(`Seed complete and verified: ${verifiedCount} demo records.`);
  console.log("Run demo:cleanup with the same batch ID after the defense.");
}

async function cleanup({projectId, batchId, apply}) {
  console.log("Demo cleanup");
  console.log(`  Project: ${projectId}`);
  console.log(`  Batch: ${batchId}`);
  if (!apply) {
    console.log("Preview only. Add --apply to remove this demo batch.");
    return;
  }

  const store = initializeStore(projectId);
  const demoManifestPath = manifestPath(batchId);
  const manifest = await store.get(demoManifestPath);
  if (!manifest.exists || manifest.data?.isDemo !== true) {
    throw new Error(`No verified demo manifest exists for batch ${batchId}.`);
  }
  const recordPaths = manifest.data?.recordPaths;
  if (!Array.isArray(recordPaths) || recordPaths.length === 0) {
    throw new Error("The demo manifest has no safe cleanup paths.");
  }

  const snapshots = await store.getAll(recordPaths);
  const unsafe = snapshots.filter((snapshot) => {
    if (!snapshot.exists) return false;
    const data = snapshot.data;
    return data?.isDemo !== true || data?.seedBatchId !== batchId;
  });
  if (unsafe.length > 0) {
    throw new Error(
        "Cleanup stopped because a target is no longer verified demo data: " +
        unsafe.map((snapshot) => snapshot.path).join(", "),
    );
  }

  const existing = snapshots.filter((snapshot) => snapshot.exists).reverse();
  await store.deleteMany(existing.map((snapshot) => snapshot.path));
  await store.delete(demoManifestPath);
  console.log(`Cleanup complete: removed ${existing.length} verified demo records.`);
}

async function main() {
  const command = process.argv[2] || "preview";
  const projectId = argumentValue("project", DEFAULT_PROJECT_ID);
  const batchId = safeBatchId(argumentValue("batch", DEFAULT_BATCH_ID));
  const anchorDate = parseIsoDate(argumentValue("date", todayInManila()));
  const apply = hasFlag("apply");

  if (["preview", "seed"].includes(command)) {
    await seed({projectId, batchId, anchorDate, apply: command === "seed" && apply});
    return;
  }
  if (command === "cleanup") {
    await cleanup({projectId, batchId, apply});
    return;
  }
  throw new Error("Use preview, seed, or cleanup as the command.");
}

main().catch((error) => {
  console.error(`Demo data operation failed: ${error.message}`);
  process.exitCode = 1;
});
