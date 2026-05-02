import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "../ios/HealthDietCoach/HealthDietCoach");

function read(relativePath: string): string {
  return fs.readFileSync(path.join(root, relativePath), "utf-8");
}

test("hydration code paths no longer reference 250 ml or 0.25 litre increments", () => {
  const files = [
    "Views/Engine/EngineCoordinatorView.swift",
    "Views/DashboardView.swift",
    "Services/NudgeService.swift",
    "Services/GoalStore.swift"
  ];

  for (const file of files) {
    const source = read(file);
    assert.equal(source.includes("+250 ml"), false, `Unexpected +250 ml in ${file}`);
    assert.equal(source.includes("250 ml"), false, `Unexpected 250 ml in ${file}`);
    assert.equal(source.includes("addWater(0.25)"), false, `Unexpected 0.25L increment in ${file}`);
    assert.equal(source.includes("logWater(0.25)"), false, `Unexpected 0.25L write in ${file}`);
  }
});

test("active goal setup flow no longer uses week-based timeline options", () => {
  const files = [
    "Views/Onboarding/BeUOnboardingFlowView.swift",
    "Views/Engine/EngineCoordinatorView.swift",
    "Models/Goal.swift"
  ];

  for (const file of files) {
    const source = read(file);
    assert.equal(source.includes("4 weeks"), false, `Unexpected 4-week option in ${file}`);
    assert.equal(source.includes("8 weeks"), false, `Unexpected 8-week option in ${file}`);
    assert.equal(source.includes("12 weeks"), false, `Unexpected 12-week option in ${file}`);
    assert.equal(source.includes("timelineWeeks"), false, `Unexpected legacy timelineWeeks reference in ${file}`);
  }
});
