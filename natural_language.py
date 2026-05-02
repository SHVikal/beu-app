import json
import os
import re
from typing import Optional

import requests

from settings_store import AppSettings


PROMPT_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "assistant_reply": {"type": "string"},
        "target_protein": {"type": ["integer", "null"], "minimum": 80, "maximum": 180},
        "recipient": {"type": ["string", "null"]},
        "delivery_mode": {
            "type": ["string", "null"],
            "enum": ["full", "menu_only", "shopping_only", None],
        },
        "send_now": {"type": "boolean"},
        "schedule_day": {"type": ["string", "null"]},
        "schedule_hour": {"type": ["integer", "null"], "minimum": 0, "maximum": 23},
        "schedule_minute": {"type": ["integer", "null"], "minimum": 0, "maximum": 59},
        "customization_notes": {"type": ["string", "null"]},
        "unsupported_requests": {"type": "array", "items": {"type": "string"}},
    },
    "required": [
        "assistant_reply",
        "target_protein",
        "recipient",
        "delivery_mode",
        "send_now",
        "schedule_day",
        "schedule_hour",
        "schedule_minute",
        "customization_notes",
        "unsupported_requests",
    ],
}


class PromptInterpreter:
    def __init__(self):
        self.api_key = os.getenv("OPENAI_API_KEY", "")
        self.model = os.getenv("OPENAI_MODEL", "gpt-5")

    def interpret(self, prompt: str, settings: AppSettings) -> dict:
        if self.api_key:
            try:
                return self._interpret_with_openai(prompt, settings)
            except Exception:
                return self._fallback(prompt, settings)
        return self._fallback(prompt, settings)

    def _interpret_with_openai(self, prompt: str, settings: AppSettings) -> dict:
        response = requests.post(
            "https://api.openai.com/v1/responses",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": self.model,
                "reasoning": {"effort": "low"},
                "instructions": (
                    "You interpret user requests for an email weekly meal-planner app. "
                    "Only map requests into supported fields. Supported changes are: target protein, "
                    "recipient, delivery mode, send now, weekly day/hour/minute schedule, and short "
                    "customization notes. If the user asks for unsupported changes such as swapping "
                    "specific meals or auto-ordering groceries, keep the existing settings and list them "
                    "under unsupported_requests."
                ),
                "input": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "input_text",
                                "text": (
                                    f"Current settings: {json.dumps(settings.__dict__)}\n"
                                    f"User request: {prompt}"
                                ),
                            }
                        ],
                    }
                ],
                "text": {
                    "format": {
                        "type": "json_schema",
                        "name": "planner_prompt_result",
                        "strict": True,
                        "schema": PROMPT_SCHEMA,
                    }
                },
            },
            timeout=45,
        )
        response.raise_for_status()
        payload = response.json()
        return json.loads(payload["output"][0]["content"][0]["text"])

    def _fallback(self, prompt: str, settings: AppSettings) -> dict:
        lowered = prompt.lower()
        protein_match = re.search(r"(\d{2,3})\s*(g|gm|grams?)\b", lowered)
        delivery_mode = None
        if "shopping list only" in lowered or "only shopping list" in lowered:
            delivery_mode = "shopping_only"
        elif "menu only" in lowered or "plan only" in lowered:
            delivery_mode = "menu_only"
        elif "full plan" in lowered or "full message" in lowered:
            delivery_mode = "full"

        day_match = re.search(
            r"\b(mon|monday|tue|tuesday|wed|wednesday|thu|thursday|fri|friday|sat|saturday|sun|sunday)\b",
            lowered,
        )
        hour_match = re.search(r"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b", lowered)
        send_now = "send now" in lowered or "send it now" in lowered

        schedule_day = normalize_day(day_match.group(1)) if day_match else None
        schedule_hour = None
        schedule_minute = None
        if hour_match:
            schedule_hour = int(hour_match.group(1)) % 12
            if hour_match.group(3) == "pm":
                schedule_hour += 12
            schedule_minute = int(hour_match.group(2) or 0)

        notes = None
        if "cheaper" in lowered:
            notes = "Prefer budget-friendly protein staples."
        elif "higher protein at breakfast" in lowered:
            notes = "Bias breakfast choices toward the highest protein options."

        target_protein = int(protein_match.group(1)) if protein_match else None
        recipient = extract_recipient(prompt)
        unsupported_requests = detect_unsupported_requests(lowered)
        assistant_reply = build_fallback_reply(
            current_settings=settings,
            target_protein=target_protein,
            recipient=recipient,
            delivery_mode=delivery_mode,
            schedule_day=schedule_day,
            schedule_hour=schedule_hour,
            schedule_minute=schedule_minute,
            customization_notes=notes,
            unsupported_requests=unsupported_requests,
        )

        return {
            "assistant_reply": assistant_reply,
            "target_protein": target_protein,
            "recipient": recipient,
            "delivery_mode": delivery_mode,
            "send_now": send_now,
            "schedule_day": schedule_day,
            "schedule_hour": schedule_hour,
            "schedule_minute": schedule_minute,
            "customization_notes": notes,
            "unsupported_requests": unsupported_requests,
        }


def normalize_day(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    lookup = {
        "mon": "mon",
        "monday": "mon",
        "tue": "tue",
        "tuesday": "tue",
        "wed": "wed",
        "wednesday": "wed",
        "thu": "thu",
        "thursday": "thu",
        "fri": "fri",
        "friday": "fri",
        "sat": "sat",
        "saturday": "sat",
        "sun": "sun",
        "sunday": "sun",
    }
    return lookup.get(value.lower())


def extract_recipient(prompt: str) -> Optional[str]:
    email_match = re.search(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", prompt, re.I)
    if email_match:
        return email_match.group(0)

    phone_match = re.search(r"(\+?\d[\d\s-]{7,}\d)", prompt)
    if not phone_match:
        return None
    return phone_match.group(1).replace(" ", "").replace("-", "")


def detect_unsupported_requests(lowered_prompt: str) -> list[str]:
    unsupported = []
    if "change breakfast" in lowered_prompt or "swap breakfast" in lowered_prompt:
        unsupported.append("specific meal swaps")
    if "order groceries" in lowered_prompt or "add to cart" in lowered_prompt:
        unsupported.append("direct grocery ordering")
    return unsupported


def build_fallback_reply(
    current_settings: AppSettings,
    target_protein: Optional[int],
    recipient: Optional[str],
    delivery_mode: Optional[str],
    schedule_day: Optional[str],
    schedule_hour: Optional[int],
    schedule_minute: Optional[int],
    customization_notes: Optional[str],
    unsupported_requests: list[str],
) -> str:
    changes = []

    if target_protein is not None and target_protein != current_settings.target_protein:
        changes.append(f"updated your protein target to {target_protein}g")

    if recipient and recipient != current_settings.recipient:
        changes.append("updated your email recipient")

    if delivery_mode and delivery_mode != current_settings.delivery_mode:
        mode_copy = {
            "full": "full plan mode",
            "menu_only": "menu-only mode",
            "shopping_only": "shopping-list-only mode",
        }
        changes.append(f"switched to {mode_copy.get(delivery_mode, delivery_mode)}")

    if schedule_day is not None or schedule_hour is not None or schedule_minute is not None:
        next_day = schedule_day or current_settings.weekly_send_day
        next_hour = schedule_hour if schedule_hour is not None else current_settings.weekly_send_hour
        next_minute = (
            schedule_minute if schedule_minute is not None else current_settings.weekly_send_minute
        )
        changes.append(f"set the weekly send time to {next_day.title()} at {next_hour:02d}:{next_minute:02d}")

    if customization_notes is not None and customization_notes != current_settings.customization_notes:
        changes.append(f"added this note: {customization_notes}")

    if not changes:
        reply = "I understood your message, but there was nothing new to change in the saved settings."
    elif len(changes) == 1:
        reply = f"I {changes[0]}."
    else:
        reply = f"I {', '.join(changes[:-1])}, and {changes[-1]}."

    if unsupported_requests:
        reply += f" I could not apply: {', '.join(unsupported_requests)}."

    return reply
