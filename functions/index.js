"use strict";

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {logger} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");

initializeApp();

const db = getFirestore();
const RETENTION_DAYS = 365;
const MAX_APPOINTMENTS_PER_RUN = 200;
const REGION = "asia-southeast1";
const TIME_ZONE = "Asia/Manila";

function retentionDateFromCreatedAt(createdAt) {
  const baseDate = createdAt instanceof Timestamp ? createdAt.toDate() : new Date();
  baseDate.setUTCDate(baseDate.getUTCDate() + RETENTION_DAYS);
  return Timestamp.fromDate(baseDate);
}

exports.setAppointmentRetention = onDocumentCreated(
    {document: "appointments/{appointmentId}", region: REGION},
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const data = snapshot.data();
      await snapshot.ref.set({
        archiveState: data.archiveState || "active",
        documentsPurged: data.documentsPurged === true,
        retentionDeleteAfter: retentionDateFromCreatedAt(data.createdAt),
        retentionConfiguredAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    },
);

function archiveSummary(appointmentId, data) {
  return {
    appointmentId,
    customerId: data.customerId || null,
    customerEmail: data.customerEmail || null,
    fullName: data.fullName || null,
    fullNameSearch: data.fullNameSearch || null,
    municipality: data.municipality || null,
    plate: data.plate || null,
    plateSearch: data.plateSearch || null,
    vehicle: data.vehicle || null,
    queue: data.queue || null,
    date: data.date || null,
    dateKey: data.dateKey || null,
    status: data.status || null,
    source: data.source || "Appointment",
    createdAt: data.createdAt || null,
    updatedAt: data.updatedAt || null,
    totalDocumentBytes: data.totalDocumentBytes || 0,
    documentsPurged: true,
    archivedAt: FieldValue.serverTimestamp(),
  };
}

async function deleteFirestoreDocumentFallback(appointmentRef) {
  const documentsSnapshot = await appointmentRef.collection("documents").get();

  for (const documentSnapshot of documentsSnapshot.docs) {
    const chunksSnapshot = await documentSnapshot.ref.collection("chunks").get();

    for (let offset = 0; offset < chunksSnapshot.docs.length; offset += 400) {
      const batch = db.batch();
      for (const chunk of chunksSnapshot.docs.slice(offset, offset + 400)) {
        batch.delete(chunk.ref);
      }
      await batch.commit();
    }

    await documentSnapshot.ref.delete();
  }
}

async function deleteStorageFiles(appointmentId, data) {
  const bucket = getStorage().bucket();
  const explicitPaths = [
    data.idStoragePath,
    data.orStoragePath,
    data.crStoragePath,
  ].filter((path) => typeof path === "string" && path.length > 0);

  for (const path of new Set(explicitPaths)) {
    try {
      await bucket.file(path).delete({ignoreNotFound: true});
    } catch (error) {
      logger.warn("Could not delete an explicitly stored document", {
        appointmentId,
        path,
        error: error.message,
      });
      throw error;
    }
  }

  if (typeof data.customerId === "string" && data.customerId.length > 0) {
    const [remainingFiles] = await bucket.getFiles({
      prefix: `appointment_documents/${data.customerId}/${appointmentId}/`,
    });
    await Promise.all(
        remainingFiles.map((file) => file.delete({ignoreNotFound: true})),
    );
  }
}

async function backfillRetentionMetadata() {
  const configRef = db.doc("system_config/storage_retention");
  const configSnapshot = await configRef.get();
  if (configSnapshot.data()?.legacyBackfillComplete === true) return;

  let lastDocument = null;
  let updatedCount = 0;

  while (true) {
    let query = db.collection("appointments")
        .orderBy("__name__")
        .limit(300);
    if (lastDocument) query = query.startAfter(lastDocument);

    const snapshot = await query.get();
    if (snapshot.empty) break;

    let batch = db.batch();
    let writes = 0;
    for (const documentSnapshot of snapshot.docs) {
      const data = documentSnapshot.data();
      if (!data.retentionDeleteAfter) {
        batch.set(documentSnapshot.ref, {
          archiveState: data.archiveState || "active",
          documentsPurged: data.documentsPurged === true,
          retentionDeleteAfter: retentionDateFromCreatedAt(data.createdAt),
          retentionConfiguredAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        writes += 1;
        updatedCount += 1;
      }
    }
    if (writes > 0) await batch.commit();

    lastDocument = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < 300) break;
  }

  await configRef.set({
    retentionDays: RETENTION_DAYS,
    legacyBackfillComplete: true,
    legacyBackfillCompletedAt: FieldValue.serverTimestamp(),
    legacyRecordsUpdated: updatedCount,
  }, {merge: true});
}

async function archiveAndPurge(appointmentSnapshot) {
  const appointmentId = appointmentSnapshot.id;
  const data = appointmentSnapshot.data();
  if (data.documentsPurged === true) return false;

  const archiveRef = db.collection("appointment_archives").doc(appointmentId);
  await archiveRef.set(archiveSummary(appointmentId, data), {merge: true});

  await deleteStorageFiles(appointmentId, data);
  await deleteFirestoreDocumentFallback(appointmentSnapshot.ref);

  await appointmentSnapshot.ref.set({
    archiveState: "archived",
    documentsPurged: true,
    documentsPurgedAt: FieldValue.serverTimestamp(),
    retentionDeleteAfter: FieldValue.delete(),
    idFile: FieldValue.delete(),
    orFile: FieldValue.delete(),
    crFile: FieldValue.delete(),
    idFileUrl: FieldValue.delete(),
    orFileUrl: FieldValue.delete(),
    crFileUrl: FieldValue.delete(),
    idStoragePath: FieldValue.delete(),
    orStoragePath: FieldValue.delete(),
    crStoragePath: FieldValue.delete(),
    idFileUploaded: false,
    orFileUploaded: false,
    crFileUploaded: false,
    documentBackend: "purged",
  }, {merge: true});

  return true;
}

exports.archiveExpiredAppointmentDocuments = onSchedule({
  schedule: "0 2 * * *",
  timeZone: TIME_ZONE,
  region: REGION,
  retryCount: 3,
  memory: "256MiB",
  timeoutSeconds: 540,
}, async () => {
  await backfillRetentionMetadata();

  const dueSnapshot = await db.collection("appointments")
      .where("retentionDeleteAfter", "<=", Timestamp.now())
      .orderBy("retentionDeleteAfter")
      .limit(MAX_APPOINTMENTS_PER_RUN)
      .get();

  let purgedCount = 0;
  let failedCount = 0;
  for (const appointmentSnapshot of dueSnapshot.docs) {
    try {
      if (await archiveAndPurge(appointmentSnapshot)) purgedCount += 1;
    } catch (error) {
      failedCount += 1;
      logger.error("Appointment retention failed", {
        appointmentId: appointmentSnapshot.id,
        error: error.message,
      });
    }
  }

  await db.doc("system_config/storage_retention").set({
    retentionDays: RETENTION_DAYS,
    lastRunAt: FieldValue.serverTimestamp(),
    lastRunScanned: dueSnapshot.size,
    lastRunPurged: purgedCount,
    lastRunFailed: failedCount,
  }, {merge: true});

  logger.info("Appointment retention completed", {
    scanned: dueSnapshot.size,
    purged: purgedCount,
    failed: failedCount,
  });
});
