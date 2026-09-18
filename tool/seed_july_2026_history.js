"use strict";

// One-time, idempotent historical analytics seed for the NPJN defense demo.
// Uses the Firebase CLI's existing authenticated account and never prints tokens.

const firebaseToolsRoot =
  "C:/Users/Jastin/AppData/Roaming/npm/node_modules/firebase-tools/lib";
const { requireAuth } = require(`${firebaseToolsRoot}/requireAuth`);
const auth = require(`${firebaseToolsRoot}/auth`);
const { Client } = require(`${firebaseToolsRoot}/apiv2`);

const project = "npjn-queue-system-jkr";
const database = "(default)";
const batchId = "july-2026-analytics-v1";
const apiPrefix = "https://firestore.googleapis.com/v1";
const documentRoot = `projects/${project}/databases/${database}/documents`;

const names = [
  "Arielle Navarro",
  "Tomas Villareal",
  "Bianca Mercado",
  "Rafael Sarmiento",
  "Liana Cortez",
  "Miguel Alonzo",
  "Kira Manansala",
  "Enzo Dela Cruz",
  "Camille Soriano",
  "Noel Barrameda",
  "Patricia Fajardo",
  "Lucas Evangelista",
  "Janelle Panganiban",
  "Marco San Jose",
  "Nina Salcedo",
  "Paolo Legaspi",
  "Reina Monteverde",
  "Carlo Ibarra",
  "Sofia Arcilla",
  "Adrian Casimiro",
  "Bea Roldan",
  "Nico Estrella",
  "Mara Valdez",
  "Julian Ferrer",
  "Celina Ramos",
  "Darren Javier",
];

const days = [3, 3, 6, 6, 9, 9, 12, 12, 15, 15, 18, 18, 21, 21, 23, 23, 25, 25, 27, 27, 29, 29, 31, 31];
const appointmentIndexes = new Set([2, 5, 8, 11, 14, 17, 20, 23]);
const failedIndexes = new Set([6, 14, 22]);

function stringValue(value) {
  return { stringValue: String(value) };
}

function boolValue(value) {
  return { booleanValue: Boolean(value) };
}

function integerValue(value) {
  return { integerValue: String(value) };
}

function timestampValue(value) {
  return { timestampValue: value };
}

function julyTimestamp(day, hour = 1) {
  return new Date(Date.UTC(2026, 6, day, hour)).toISOString();
}

function normalizedName(name) {
  return name.trim().toUpperCase().replace(/\s+/g, " ");
}

function documentWrite(path, fields) {
  return {
    update: {
      name: `${documentRoot}/${path}`,
      fields,
    },
    currentDocument: { exists: false },
  };
}

function queueRecords() {
  return names.slice(0, 24).map((name, index) => {
    const sequence = index + 1;
    const day = days[index];
    const type = index % 4 === 3 ? "Diesel" : "Gas";
    const prefix = type === "Diesel" ? "D" : "G";
    const queue = `${prefix}${String(sequence).padStart(3, "0")}`;
    const plate = `FJ${String.fromCharCode(65 + (index % 26))}${String(1100 + index)}`;
    const date = `7/${day}/2026`;
    const source = appointmentIndexes.has(index) ? "Appointment" : "Walk-in";
    const status = failedIndexes.has(index) ? "Failed" : "Passed";
    const id = `synthetic-jul26-${String(sequence).padStart(3, "0")}`;
    const appointmentId = source === "Appointment" ? `synthetic-jul26-appt-${String(sequence).padStart(3, "0")}` : "";
    const createdAt = julyTimestamp(day, 1 + (index % 8));

    return {
      id,
      day,
      appointmentId,
      path: `queues/7-${day}-2026/items/${id}`,
      fields: {
        queueId: stringValue(queue),
        queue: stringValue(queue),
        name: stringValue(name),
        nameNormalized: stringValue(normalizedName(name)),
        plate: stringValue(plate),
        plateNormalized: stringValue(plate),
        type: stringValue(type),
        vehicle: stringValue(type),
        date: stringValue(date),
        dateTimestamp: timestampValue(julyTimestamp(day, 0)),
        source: stringValue(source),
        status: stringValue(status),
        ...(appointmentId ? { appointmentId: stringValue(appointmentId) } : {}),
        isDemo: boolValue(true),
        syntheticBatch: stringValue(batchId),
        createdAt: timestampValue(createdAt),
        updatedAt: timestampValue(createdAt),
      },
    };
  });
}

function appointmentRecords(queues) {
  const approved = queues
    .filter((record) => record.appointmentId)
    .map((record) => {
      const queueFields = record.fields;
      const name = queueFields.name.stringValue;
      const plate = queueFields.plate.stringValue;
      const date = queueFields.date.stringValue;
      const type = queueFields.type.stringValue;
      const queue = queueFields.queue.stringValue;
      const createdAt = queueFields.createdAt.timestampValue;

      return {
        path: `appointments/${record.appointmentId}`,
        fields: {
          appointmentId: stringValue(record.appointmentId),
          customerId: stringValue(`synthetic-customer-${record.id}`),
          fullName: stringValue(name),
          nameNormalized: stringValue(normalizedName(name)),
          municipality: stringValue("Polangui"),
          barangay: stringValue("Matacon"),
          plate: stringValue(plate),
          plateNormalized: stringValue(plate),
          vehicle: stringValue(type),
          queue: stringValue(queue),
          date: stringValue(date),
          dateTimestamp: queueFields.dateTimestamp,
          status: stringValue("Approved"),
          source: stringValue("Appointment"),
          idFile: stringValue("Historical record - document not retained"),
          orFile: stringValue("Historical record - document not retained"),
          crFile: stringValue("Historical record - document not retained"),
          idFileUrl: stringValue(""),
          orFileUrl: stringValue(""),
          crFileUrl: stringValue(""),
          idFileUploaded: boolValue(false),
          orFileUploaded: boolValue(false),
          crFileUploaded: boolValue(false),
          documentsPurged: boolValue(true),
          archiveState: stringValue("historical-synthetic"),
          totalDocumentBytes: integerValue(0),
          isDemo: boolValue(true),
          syntheticBatch: stringValue(batchId),
          createdAt: timestampValue(createdAt),
          updatedAt: timestampValue(createdAt),
          approvedAt: timestampValue(createdAt),
        },
      };
    });

  const rejectedSpecs = [
    {
      id: "synthetic-jul26-rejected-001",
      name: names[24],
      date: "7/11/2026",
      day: 11,
      plate: "FJY1198",
      vehicle: "Gas",
      queue: "G025",
      reason: "The submitted registration image was unreadable.",
    },
    {
      id: "synthetic-jul26-rejected-002",
      name: names[25],
      date: "7/26/2026",
      day: 26,
      plate: "FJZ1199",
      vehicle: "Diesel",
      queue: "D026",
      reason: "The submitted details did not match the registration record.",
    },
  ];

  const rejected = rejectedSpecs.map((record) => {
    const createdAt = julyTimestamp(record.day, 4);
    return {
      path: `appointments/${record.id}`,
      fields: {
        appointmentId: stringValue(record.id),
        customerId: stringValue(`synthetic-customer-${record.id}`),
        fullName: stringValue(record.name),
        nameNormalized: stringValue(normalizedName(record.name)),
        municipality: stringValue("Ligao City"),
        barangay: stringValue("Guilid"),
        plate: stringValue(record.plate),
        plateNormalized: stringValue(record.plate),
        vehicle: stringValue(record.vehicle),
        queue: stringValue(record.queue),
        date: stringValue(record.date),
        dateTimestamp: timestampValue(julyTimestamp(record.day, 0)),
        status: stringValue("Rejected"),
        rejectionReason: stringValue(record.reason),
        source: stringValue("Appointment"),
        idFile: stringValue("Historical record - document not retained"),
        orFile: stringValue("Historical record - document not retained"),
        crFile: stringValue("Historical record - document not retained"),
        idFileUploaded: boolValue(false),
        orFileUploaded: boolValue(false),
        crFileUploaded: boolValue(false),
        documentsPurged: boolValue(true),
        archiveState: stringValue("historical-synthetic"),
        totalDocumentBytes: integerValue(0),
        isDemo: boolValue(true),
        syntheticBatch: stringValue(batchId),
        createdAt: timestampValue(createdAt),
        updatedAt: timestampValue(createdAt),
        rejectedAt: timestampValue(createdAt),
      },
    };
  });

  return [...approved, ...rejected];
}

async function authenticatedClient() {
  const account =
    auth.getProjectDefaultAccount(process.cwd()) || auth.getGlobalDefaultAccount();
  if (!account) {
    throw new Error("Firebase CLI is not signed in.");
  }

  const options = {
    project,
    projectRoot: process.cwd(),
    user: account.user,
    tokens: account.tokens,
    nonInteractive: true,
  };
  await requireAuth(options);
  return new Client({ urlPrefix: apiPrefix });
}

async function listDocuments(client, collectionPath) {
  const documents = [];
  let pageToken;
  do {
    const response = await client.get(`/${documentRoot}/${collectionPath}`, {
      queryParams: {
        pageSize: 1000,
        ...(pageToken ? { pageToken } : {}),
      },
    });
    documents.push(...(response.body?.documents || []));
    pageToken = response.body?.nextPageToken;
  } while (pageToken);
  return documents;
}

async function julySummary(client) {
  const dates = Array.from({ length: 31 }, (_, index) => `7/${index + 1}/2026`);
  const julyDates = new Set(dates);
  const queueDocs = [];

  for (let day = 1; day <= 31; day += 1) {
    queueDocs.push(...(await listDocuments(client, `queues/7-${day}-2026/items`)));
  }
  const allAppointmentDocs = await listDocuments(client, "appointments");
  const appointmentDocs = allAppointmentDocs.filter((doc) =>
    julyDates.has(doc.fields?.date?.stringValue),
  );

  const queueDemo = queueDocs.filter(
    (doc) => doc.fields?.syntheticBatch?.stringValue === batchId,
  );
  const appointmentDemo = appointmentDocs.filter(
    (doc) => doc.fields?.syntheticBatch?.stringValue === batchId,
  );
  const passed = queueDemo.filter((doc) => doc.fields?.status?.stringValue === "Passed").length;
  const failed = queueDemo.filter((doc) => doc.fields?.status?.stringValue === "Failed").length;
  const walkIns = queueDemo.filter((doc) => doc.fields?.source?.stringValue === "Walk-in").length;
  const approved = appointmentDemo.filter((doc) => doc.fields?.status?.stringValue === "Approved").length;
  const rejected = appointmentDemo.filter((doc) => doc.fields?.status?.stringValue === "Rejected").length;

  return {
    julyQueueRecords: queueDocs.length,
    julyAppointmentRecords: appointmentDocs.length,
    batchQueueRecords: queueDemo.length,
    batchAppointmentRecords: appointmentDemo.length,
    batchPassed: passed,
    batchFailed: failed,
    batchWalkIns: walkIns,
    batchApprovedAppointments: approved,
    batchRejectedAppointments: rejected,
  };
}

async function main() {
  const mode = process.argv[2] || "inspect";
  if (!["inspect", "seed"].includes(mode)) {
    throw new Error("Use 'inspect' or 'seed'.");
  }

  const client = await authenticatedClient();
  const before = await julySummary(client);
  console.log(`BEFORE ${JSON.stringify(before)}`);

  if (mode === "inspect") return;

  if (before.batchQueueRecords > 0 || before.batchAppointmentRecords > 0) {
    console.log("SKIPPED: this synthetic July batch already exists.");
    return;
  }

  const queues = queueRecords();
  const appointments = appointmentRecords(queues);
  const writes = [
    ...queues.map((record) => documentWrite(record.path, record.fields)),
    ...appointments.map((record) => documentWrite(record.path, record.fields)),
  ];

  const response = await client.post(`/${documentRoot}:batchWrite`, { writes });
  const statuses = response.body?.status || [];
  const failures = statuses.filter((status) => Number(status.code || 0) !== 0);
  if (failures.length > 0) {
    throw new Error(`Firestore reported ${failures.length} failed writes.`);
  }

  const after = await julySummary(client);
  console.log(`AFTER ${JSON.stringify(after)}`);
  if (after.batchQueueRecords !== queues.length || after.batchAppointmentRecords !== appointments.length) {
    throw new Error("Post-write verification count did not match the planned batch.");
  }
}

main().catch((error) => {
  console.error(`ERROR: ${error.message}`);
  process.exitCode = 1;
});
