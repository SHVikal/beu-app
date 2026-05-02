const ISO_DAY_REGEX = /^\d{4}-\d{2}-\d{2}$/;

export function isIsoDay(value: string): boolean {
  return ISO_DAY_REGEX.test(value);
}

export function currentIsoDay(): string {
  return new Date().toISOString().slice(0, 10);
}

export function shiftIsoDay(day: string, delta: number): string {
  const date = new Date(`${day}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + delta);
  return date.toISOString().slice(0, 10);
}

export function lastNDaysInclusive(endDay: string, days: number): string[] {
  const results: string[] = [];
  for (let offset = days - 1; offset >= 0; offset -= 1) {
    results.push(shiftIsoDay(endDay, -offset));
  }
  return results;
}
