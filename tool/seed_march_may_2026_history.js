"use strict";

// One-time, idempotent historical analytics seed for March and May 2026.
// Uses the Firebase CLI's existing authenticated account and never prints tokens.

const firebaseToolsRoot =
  "C:/Users/Jastin/AppData/Roaming/npm/node_modules/firebase-tools/lib";
const { requireAuth } = require(`${firebaseToolsRoot}/requireAuth`);
const auth = require(`${firebaseToolsRoot}/auth`);
const { Client } = require(`${firebaseToolsRoot}/apiv2`);

const project = "npjn-queue-system-jkr";
const database = "(default)";
const apiPrefix = "https://firestore.googleapis.com/v1";
const documentRoot = `projects/${project}/databases/${database}/documents`;

const monthPlans = [
  {
    key: "march",
    month: 3,
    label: "March",
    count: 35,
    batchId: "march-2026-analytics-v1",
    idPrefix: "synthetic-mar26",
    failedIndexes: new Set([10, 21, 32]),
    isAppointment: (index) => index % 3 === 2,
  },
  {
    key: "may",
    month: 5,
    label: "May",
    count: 30,
    batchId: "may-2026-analytics-v1",
    idPrefix: "synthetic-may26",
    failedIndexes: new Set([8, 18, 28]),
    isAppointment: (index) => index % 3 === 1,
  },
];

const firstNames = [
  "Althea",
  "Benicio",
  "Clarisse",
  "Danilo",
  "Elise",
  "Francis",
  "Giselle",
  "Harvey",
  "Isabel",
  "Jericho",
  "Katrina",
  "Leandro",
  "Marielle",
];

const lastNames = [
  "Abad",
  "Belmonte",
  "Castillo",
  "Domingo",
  "Escobar",
];

const fictionalNames = lastNames.flatMap((lastName) =>
  firstNames.map((firstName) => `${firstName} ${lastName}`),
);

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

function historicalTimestamp(month, day, hour = 1) {
  return new Date(Date.UTC(2026, month - 1, day, hour)).toISOString();
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

function queueRecords(plan, nameOffset) {
  return Array.from({ length: plan.count }, (_, index) => {
    const sequence = index + 1;
    const day = 1 + ((index * 3) % 28);
    const name = fictionalNames[nameOffset + index];
    const type = index % 4 === 3 ? "Diesel" : "Gas";
    const prefix = type === "Diesel" ? "D" : "G";
    const queue = `${prefix}${String(sequence).padStart(3, "0")}`;
    const platePrefix = plan.month === 3 ? "KM" : "LP";
    const plate = `${platePrefix}${String.fromCharCode(65 + (index % 26))}${String(2100 + plan.month * 100 + index)}`;
    const date = `${plan.month}/${day}/2026`;
    const source = plan.isAppointment(index) ? "Appointment" : "Walk-in";
    const status = plan.failedIndexes.has(index) ? "Failed" : "Passed";
    const id = `${plan.idPrefix}-${String(sequence).padStart(3, "0")}`;
    const appointmentId = source === "Appointment" ? `${plan.idPrefix}-appt-${String(sequence).padStart(3, "0")}` : "";
    const createdAt = historicalTimestamp(plan.month, day, 1 + (index % 8));

    return {
      id,
      appointmentId,
      path: `queues/${plan.month}-${day}-2026/items/${id}`,
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
        dateTimestamp: timestampValue(historicalTimestamp(plan.month, day, 0)),
        source: stringValue(source),
        status: stringValue(status),
        ...(appointmentId ? { appointmentId: stringValue(appointmentId) } : {}),
        isDemo: boolValue(true),
        syntheticBatch: stringValue(plan.batchId),
        createdAt: timestampValue(createdAt),
        updatedAt: timestampValue(createdAt),
      },
    };
  });
}

function appointmentRecords(plan, queues) {
  return queues
    .filter((record) => record.appointmentId)
    .map((record) => {
      const queueFields = record.fields;
      const createdAt = queueFields.createdAt.timestampValue;
      return {
        path: `appointments/${record.appointmentId}`,
        fields: {
          appointmentId: stringValue(record.appointmentId),
          customerId: stringValue(`synthetic-customer-${record.id}`),
          fullName: queueFields.name,
          nameNormalized: stringValue(
            normalizedName(queueFields.name.stringValue),
          ),
          municipality: stringValue(plan.month === 3 ? "Polangui" : "Ligao City"),
          barangay: stringValue(plan.month === 3 ? "Matacon" : "Guilid"),
          plate: queueFields.plate,
          plateNormalized: queueFields.plate,
          vehicle: queueFields.vehicle,
          queue: queueFields.queue,
          date: queueFields.date,
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
          syntheticBatch: stringValue(plan.batchId),
          createdAt: timestampValue(createdAt),
          updatedAt: timestampValue(createdAt),
          approvedAt: timestampValue(createdAt),
        },
      };
    });
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

async function summaries(client) {
  const queueDocsByMonth = new Map();
  for (const plan of monthPlans) {
    const documents = [];
    for (let day = 1; day <= 31; day += 1) {
      documents.push(
        ...(await listDocuments(
          client,
          `queues/${plan.month}-${day}-2026/items`,
        )),
      );
    }
    queueDocsByMonth.set(plan.month, documents);
  }

  const allAppointmentDocs = await listDocuments(client, "appointments");
  return monthPlans.map((plan) => {
    const monthPrefix = `${plan.month}/`;
    const queueDocs = queueDocsByMonth.get(plan.month) || [];
    const appointmentDocs = allAppointmentDocs.filter((doc) =>
      doc.fields?.date?.stringValue?.startsWith(monthPrefix),
    );
    const batchQueueDocs = queueDocs.filter(
      (doc) => doc.fields?.syntheticBatch?.stringValue === plan.batchId,
    );
    const batchAppointmentDocs = appointmentDocs.filter(
      (doc) => doc.fields?.syntheticBatch?.stringValue === plan.batchId,
    );

    return {
      month: plan.label,
      existingQueueRecords: queueDocs.length,
      existingAppointmentRecords: appointmentDocs.length,
      batchQueueRecords: batchQueueDocs.length,
      batchAppointmentRecords: batchAppointmentDocs.length,
      batchPassed: batchQueueDocs.filter(
        (doc) => doc.fields?.status?.stringValue === "Passed",
      ).length,
      batchFailed: batchQueueDocs.filter(
        (doc) => doc.fields?.status?.stringValue === "Failed",
      ).length,
      batchWalkIns: batchQueueDocs.filter(
        (doc) => doc.fields?.source?.stringValue === "Walk-in",
      ).length,
    };
  });
}

async function main() {
  const mode = process.argv[2] || "inspect";
  if (!["inspect", "seed"].includes(mode)) {
    throw new Error("Use 'inspect' or 'seed'.");
  }

  const client = await authenticatedClient();
  const before = await summaries(client);
  console.log(`BEFORE ${JSON.stringify(before)}`);
  if (mode === "inspect") return;

  const existingBatch = before.find(
    (summary) =>
      summary.batchQueueRecords > 0 || summary.batchAppointmentRecords > 0,
  );
  if (existingBatch) {
    throw new Error(
      `${existingBatch.month} synthetic batch already exists; nothing was written.`,
    );
  }

  let nameOffset = 0;
  const plannedRecords = monthPlans.map((plan) => {
    const queues = queueRecords(plan, nameOffset);
    nameOffset += plan.count;
    return { plan, queues, appointments: appointmentRecords(plan, queues) };
  });
  const writes = plannedRecords.flatMap(({ queues, appointments }) => [
    ...queues.map((record) => documentWrite(record.path, record.fields)),
    ...appointments.map((record) =>
      documentWrite(record.path, record.fields),
    ),
  ]);

  const response = await client.post(`/${documentRoot}:batchWrite`, { writes });
  const statuses = response.body?.status || [];
  const failures = statuses.filter((status) => Number(status.code || 0) !== 0);
  if (failures.length > 0) {
    throw new Error(`Firestore reported ${failures.length} failed writes.`);
  }

  const after = await summaries(client);
  console.log(`AFTER ${JSON.stringify(after)}`);
  for (let index = 0; index < plannedRecords.length; index += 1) {
    const expected = plannedRecords[index];
    const actual = after[index];
    if (
      actual.batchQueueRecords !== expected.queues.length ||
      actual.batchAppointmentRecords !== expected.appointments.length
    ) {
      throw new Error(
        `${expected.plan.label} post-write verification did not match the plan.`,
      );
    }
  }
}

main().catch((error) => {
  console.error(`ERROR: ${error.message}`);
  process.exitCode = 1;
});
