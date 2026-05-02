import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const sourcePath = path.resolve(process.cwd(), "../ios/HealthDietCoach/HealthDietCoach/Services/NutritionServices.swift");
const source = fs.readFileSync(sourcePath, "utf-8");

function extractQuotedMatches(pattern: RegExp): string[] {
  return [...source.matchAll(pattern)].map((match) => match[1] ?? "");
}

test("supplement reminders avoid dosage and interaction language", () => {
  const reminderStrings = extractQuotedMatches(/return "([^"]*You usually take[^"]*)"/g);
  const forbidden = ["dosage", "should take", "start taking", "stop taking", "interaction", "increase", "decrease"];

  assert.ok(reminderStrings.length > 0);
  for (const reminder of reminderStrings) {
    const lowered = reminder.toLowerCase();
    for (const term of forbidden) {
      assert.equal(lowered.includes(term), false, `Unexpected term "${term}" in reminder: ${reminder}`);
    }
  }
});

test("health context and safety strings avoid diagnosis and treatment language", () => {
  const contextStrings = [
    ...extractQuotedMatches(/healthContextNotes\.append\("([^"]+)"\)/g),
    ...extractQuotedMatches(/safetyNote = "([^"]+)"/g)
  ];
  const forbidden = ["diagnose", "treat", "prescribe", "dosage", "start taking", "stop taking", "interaction", "insulin"];

  assert.ok(contextStrings.length > 0);
  for (const value of contextStrings) {
    const lowered = value.toLowerCase();
    for (const term of forbidden) {
      assert.equal(lowered.includes(term), false, `Unexpected term "${term}" in context string: ${value}`);
    }
  }
});
