"use strict";

const { initializeApp, getApps } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { createStore, migrate } = require("./spark_capacity_migration");

const localProjectId = "npjn-queue-system-jkr";
const localPassword = "LocalReview123!";

function requireLoopbackHost(name, value) {
  if (!value || !/^(localhost|127\.0\.0\.1|\[::1\]):\d+$/.test(value)) {
    throw new Error(`${name} must identify a loopback emulator; production access is refused.`);
  }
  const port = Number(value.slice(value.lastIndexOf(":") + 1));
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`${name} has an invalid emulator port.`);
  }
  return value;
}

function requireLocalEmulators(environment = process.env) {
  return {
    firestoreHost: requireLoopbackHost(
      "FIRESTORE_EMULATOR_HOST", environment.FIRESTORE_EMULATOR_HOST,
    ),
    authHost: requireLoopbackHost(
      "FIREBASE_AUTH_EMULATOR_HOST", environment.FIREBASE_AUTH_EMULATOR_HOST,
    ),
    storageHost: requireLoopbackHost(
      "FIREBASE_STORAGE_EMULATOR_HOST",
      environment.FIREBASE_STORAGE_EMULATOR_HOST || environment.STORAGE_EMULATOR_HOST,
    ),
  };
}

function localAdminApp() {
  // Validate every service before initializing an SDK or looking for credentials.
  requireLocalEmulators();
  return getApps().find((app) => app.name === "local-capacity-preview") || initializeApp({
    projectId: localProjectId,
    storageBucket: `${localProjectId}.firebasestorage.app`,
  }, "local-capacity-preview");
}

async function seedLocalCapacityPreview() {
  const app = localAdminApp();
  const auth = getAuth(app);
  const firestore = getFirestore(app);
  for (const account of [
    { uid: "local-preview-admin", email: "admin@npjn.test", role: "admin", fullName: "Local Review Admin" },
    { uid: "local-preview-customer", email: "customer@npjn.test", role: "customer", fullName: "Local Review Customer" },
  ]) {
    const authData = {
      email: account.email,
      password: localPassword,
      displayName: account.fullName,
      emailVerified: true,
      disabled: false,
    };
    try {
      await auth.getUser(account.uid);
      await auth.updateUser(account.uid, authData);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
      await auth.createUser({ uid: account.uid, ...authData });
    }
    await firestore.doc(`users/${account.uid}`).set({
      ...account,
      emailVerified: true,
      municipality: "Ligao",
      barangay: "",
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  const capacityRef = firestore.doc("system_config/queue_capacity");
  const capacity = (await capacityRef.get()).data();
  let dailyLimit = capacity?.dailyLimit ?? 80;
  if (capacity?.schemaVersion !== 2 || capacity?.migrationComplete !== true) {
    await capacityRef.set({
      schemaVersion: 2,
      dailyLimit: 80,
      migrationComplete: false,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: "local-preview-admin",
    }, { merge: true });
    // All emulator hosts were checked before initialization. Backfill any local
    // test records before opening reservations; ready v2 ledgers stay untouched.
    const store = await createStore({projectId: localProjectId, emulator: true});
    await migrate(store, {apply: true, emulator: true});
    dailyLimit = 80;
  }
  console.log(`Local emulators ready: daily limit ${dailyLimit}; ${dailyLimit / 2} appointments and ${dailyLimit / 2} walk-ins.`);
  console.log(`Local review accounts: admin@npjn.test / customer@npjn.test; password: ${localPassword}`);
}

if (require.main === module) {
  seedLocalCapacityPreview().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = { localAdminApp, localProjectId, requireLocalEmulators, seedLocalCapacityPreview };
