"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildDay, canonicalDate, createStore, main, migrate,
} = require("../scripts/spark_capacity_migration");

const DATE = "11/5/2026";
const DAY_PATH = "capacity_days/11-5-2026";
const CONFIG_PATH = "system_config/queue_capacity";
const frozenConfig = () => ({
  exists: true, updateTime: "config-v1",
  data: {schemaVersion: 2, dailyLimit: 80, migrationComplete: false},
});
const appointment = (id, queue, status = "Pending", extra = {}) => ({
  id, path: `appointments/${id}`, date: DATE, queue, status, ...extra,
});
const queue = (id, extra = {}) => ({
  id, path: `queues/11-5-2026/items/${id}`, date: DATE, queue: id,
  status: "Waiting", source: "Walk-in", ...extra,
});

class FakeMigrationStore {
  constructor({appointments = [], items = []} = {}) {
    this.sources = structuredClone({appointments, items});
    this.metadata = new Map([[CONFIG_PATH, frozenConfig()]]);
    this.putCalls = [];
    this.finishCalls = 0;
    this.queryCalls = 0;
  }

  async get(documentPath) {
    return structuredClone(this.metadata.get(documentPath) || {exists: false, data: null});
  }

  async query(collectionId) {
    this.queryCalls++;
    this.beforeQuery?.(this.queryCalls);
    assert.ok(collectionId === "appointments" || collectionId === "items");
    return structuredClone(this.sources[collectionId]);
  }

  async putLedger(documentPath, data, previous) {
    assert.match(documentPath, /^capacity_days\/[^/]+$/);
    if (!previous) assert.equal(this.metadata.has(documentPath), false);
    this.putCalls.push({documentPath, previous});
    this.metadata.set(documentPath, {
      exists: true, updateTime: "ledger-v1", data: structuredClone(data),
    });
  }

  async finish(config) {
    // Activation is permitted only after both inventory projections ran.
    assert.ok(this.queryCalls >= 4);
    assert.equal(config.updateTime, this.metadata.get(CONFIG_PATH).updateTime);
    this.finishCalls++;
    this.metadata.get(CONFIG_PATH).data.migrationComplete = true;
  }
}

test("mixed Gas and Diesel reservations share source claim maps without double-counting a mirror", () => {
  const day = buildDay(DATE, [
    appointment("gas-appointment", "G001", "Approved"),
    appointment("diesel-appointment", "D001"),
  ], [
    queue("G001", {source: "Appointment", appointmentId: "gas-appointment"}),
    queue("G002"), queue("D002", {capacityRequestId: "diesel-request"}),
  ]);
  assert.deepEqual(day.appointmentClaims, {"diesel-appointment": "D001", "gas-appointment": "G001"});
  assert.deepEqual(day.walkInClaims, {"diesel-request": "D002", legacy_G002: "G002"});
  assert.deepEqual(day.legacyQueueClaims.G001, {source: "appointment", claimId: "gas-appointment"});
});

test("distinct appointment IDs sharing one code are retained and legacy path identities are preserved", () => {
  const day = buildDay(DATE, [
    appointment("actual-a", "G001", "Approved", {appointmentId: "obsolete-embedded-id"}),
    appointment("actual-b", "G001"),
  ], [
    queue("G001", {source: "Appointment"}),
    queue("D001", {source: "Appointment", _appointmentDocumentPath: "appointments/path-id"}),
    queue("D002", {source: "Appointment"}),
  ]);
  assert.deepEqual(day.appointmentClaims, {
    "actual-a": "G001", "actual-b": "G001", "path-id": "D001", legacy_appointment_D002: "D002",
  });
  assert.equal(day.appointmentClaims["obsolete-embedded-id"], undefined);
  assert.equal(day.legacyQueueClaims.D002.claimId, "legacy_appointment_D002");
});

test("completed legacy services retain original source while rejected and inactive records release places", () => {
  const day = buildDay(DATE, [appointment("rejected", "G003", "Rejected")], [
    queue("G001", {source: "Appointment", appointmentId: "completed-appointment", status: "Passed"}),
    queue("D001", {status: "Failed"}),
    ...["Cancelled", "Reset", "Rejected", "Expired"].map((status, i) => queue(`D01${i}`, {status})),
  ]);
  assert.deepEqual(day.appointmentClaims, {"completed-appointment": "G001"});
  assert.deepEqual(day.walkInClaims, {legacy_D001: "D001"});
  assert.deepEqual(day.completedClaims, {
    "appointment:completed-appointment": {source: "appointment", queue: "G001", appointmentId: "completed-appointment"},
    "walkin:legacy_D001": {source: "walkin", queue: "D001"},
  });
  assert.equal(Object.keys(day.legacyQueueClaims).length, 2);
});

test("migration guards reject invalid dates, another project, and apply without an explicit project", async () => {
  assert.throws(() => canonicalDate("2/30/2026"), /invalid date/);
  await assert.rejects(createStore({projectId: "another-project", emulator: false}), /authorized NPJN project/);
  await assert.rejects(main(["--apply"]), /explicit --project/);
  const store = new FakeMigrationStore();
  store.metadata.get(CONFIG_PATH).data.migrationComplete = true;
  await assert.rejects(migrate(store, {apply: true}), /freeze rules/);
  assert.equal(store.putCalls.length, 0);
  assert.equal(store.finishCalls, 0);
});

test("default dry run performs no writes and successful apply writes only verified metadata", async () => {
  const store = new FakeMigrationStore({
    appointments: [appointment("a", "G001")],
    items: [queue("D001", {status: "Passed"})],
  });
  const originalSources = structuredClone(store.sources);
  const dryRun = await migrate(store);
  assert.equal(dryRun.mode, "dry-run");
  assert.equal(dryRun.dates[0].appointmentUsed, 1);
  assert.equal(dryRun.dates[0].walkInUsed, 1);
  assert.equal(store.putCalls.length, 0);
  assert.equal(store.finishCalls, 0);
  const applied = await migrate(store, {apply: true});
  assert.equal(applied.createdDays, 1);
  assert.equal(applied.verified, true);
  assert.equal(applied.migrationComplete, true);
  assert.deepEqual(store.putCalls.map((call) => call.documentPath), [DAY_PATH]);
  assert.equal(store.putCalls[0].previous, undefined);
  assert.deepEqual(store.sources, originalSources);
});

test("rerunning a frozen migration skips initialized ledgers and never resets their contents", async () => {
  const store = new FakeMigrationStore({items: [queue("G001", {status: "Passed"})]});
  await migrate(store, {apply: true});
  const originalLedger = structuredClone(store.metadata.get(DAY_PATH));
  store.metadata.set(CONFIG_PATH, frozenConfig());
  const result = await migrate(store, {apply: true});
  assert.equal(result.createdDays, 0);
  assert.equal(result.skippedInitializedDays, 1);
  assert.equal(store.putCalls.length, 1);
  assert.deepEqual(store.metadata.get(DAY_PATH), originalLedger);
});

test("a changed source hash during the second inventory leaves migration frozen", async () => {
  const store = new FakeMigrationStore({items: [queue("G001")]});
  store.beforeQuery = (count) => {
    if (count === 3) store.sources.items.push(queue("D001"));
  };
  await assert.rejects(migrate(store, {apply: true}), /Source reservations changed/);
  assert.equal(store.finishCalls, 0);
  assert.equal(store.metadata.get(CONFIG_PATH).data.migrationComplete, false);
  assert.deepEqual(store.metadata.get(DAY_PATH).data.walkInClaims, {legacy_G001: "G001"});
});

test("an initialized ledger mismatch is preserved and blocks activation rather than overwriting claims", async () => {
  const store = new FakeMigrationStore({items: [queue("G001")]});
  const ledger = buildDay(DATE, [], store.sources.items);
  ledger.walkInClaims.existing = "D001";
  const existing = {exists: true, updateTime: "protected", data: ledger};
  store.metadata.set(DAY_PATH, structuredClone(existing));
  await assert.rejects(migrate(store, {apply: true}), /Ledger verification failed/);
  assert.equal(store.putCalls.length, 0);
  assert.equal(store.finishCalls, 0);
  assert.deepEqual(store.metadata.get(DAY_PATH), existing);
  assert.equal(store.metadata.get(CONFIG_PATH).data.migrationComplete, false);
});

test("a production legacy ledger is never replaced", async () => {
  const store = new FakeMigrationStore({items: [queue("G001")]});
  store.metadata.set(DAY_PATH, {exists: true, updateTime: "old", data: {schemaVersion: 1}});
  await assert.rejects(migrate(store, {apply: true}), /no production ledger was overwritten/);
  assert.equal(store.putCalls.length, 0);
  assert.equal(store.metadata.get(DAY_PATH).data.schemaVersion, 1);
  assert.equal(store.metadata.get(CONFIG_PATH).data.migrationComplete, false);
});
