// Attacks against Gamy's database rules. Runs against the local Firebase emulator, never the real database.
// From C:\Gamy:  firebase emulators:exec --only firestore "node --test firestore/rules.test.mjs"
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'gamy-dev',
    firestore: { rules: readFileSync(new URL('./firestore.rules', import.meta.url), 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const ana = () => env.authenticatedContext('ana').firestore(); // a signed-in student
const ben = () => env.authenticatedContext('ben').firestore(); // another student (the "hacker")
const guest = () => env.unauthenticatedContext().firestore(); // not signed in

const subject = 'users/ana/subjects/s1';
const module = `${subject}/modules/m1`;

test('a student can save and read back their own lessons', async () => {
  const db = ana();
  await assertSucceeds(setDoc(doc(db, 'users/ana'), { created: serverTimestamp() }));
  await assertSucceeds(setDoc(doc(db, subject), { name: 'CSS', updated: serverTimestamp() }));
  await assertSucceeds(setDoc(doc(db, module), { name: 'Module 1', parts: 1, updated: serverTimestamp() }));
  await assertSucceeds(setDoc(doc(db, `${module}/parts/0`), { text: 'The motherboard is the main board.' }));
  await assertSucceeds(getDoc(doc(db, `${module}/parts/0`)));
});

test('another student cannot read or change my lessons', async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), `${module}/parts/0`), { text: 'secret notes' }));
  await assertFails(getDoc(doc(ben(), `${module}/parts/0`)));
  await assertFails(setDoc(doc(ben(), `${module}/parts/0`), { text: 'hacked' }));
  await assertFails(deleteDoc(doc(ben(), `${module}/parts/0`)));
});

test('someone not signed in gets nothing', async () => {
  await assertFails(getDoc(doc(guest(), 'users/ana')));
  await assertFails(setDoc(doc(guest(), subject), { name: 'x', updated: serverTimestamp() }));
});

test('nobody can give themselves Pro', async () => {
  await assertFails(setDoc(doc(ana(), 'users/ana'), { created: serverTimestamp(), pro: true }));
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'users/ana'), { created: new Date() }));
  await assertFails(updateDoc(doc(ana(), 'users/ana'), { pro: true }));
});

test('no extra fields, wrong types or huge text', async () => {
  const db = ana();
  await assertFails(setDoc(doc(db, subject), { name: 'CSS', updated: serverTimestamp(), pro: true }));
  await assertFails(setDoc(doc(db, subject), { name: 123, updated: serverTimestamp() }));
  await assertFails(setDoc(doc(db, subject), { name: 'x'.repeat(101), updated: serverTimestamp() }));
  await assertFails(setDoc(doc(db, module), { name: 'M', parts: 26, updated: serverTimestamp() }));
  await assertFails(setDoc(doc(db, `${module}/parts/0`), { text: 'x'.repeat(900001) }));
});

test('nothing outside the users folders can be read or written', async () => {
  await assertFails(getDoc(doc(ana(), 'admin/settings')));
  await assertFails(setDoc(doc(ana(), 'admin/settings'), { pro: true }));
});

test('a student can delete their account data (Delete account)', async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), subject), { name: 'CSS', updated: new Date() }));
  await assertSucceeds(deleteDoc(doc(ana(), subject)));
  await assertSucceeds(deleteDoc(doc(ana(), 'users/ana')));
});
