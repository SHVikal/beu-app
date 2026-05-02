import json
import os
from dataclasses import asdict, dataclass, field


@dataclass
class AppSettings:
    target_protein: int = 100
    recipient: str = ""
    delivery_mode: str = "menu_only"
    customization_notes: str = ""
    schedule_frequency: str = "daily"
    weekly_send_day: str = "sat"
    weekly_send_hour: int = 19
    weekly_send_minute: int = 0
    app_timezone: str = "Asia/Dubai"
    openai_model: str = "gpt-5"
    next_day_only: bool = True
    excluded_ingredients: list[str] = field(default_factory=list)


class SettingsStore:
    def __init__(self, path: str = "data/settings.json"):
        self.path = path
        self._settings = self._load()

    def get(self) -> AppSettings:
        return self._settings

    def update(self, **changes) -> AppSettings:
        payload = asdict(self._settings)
        for key, value in changes.items():
            if value is None:
                continue
            payload[key] = value

        self._settings = AppSettings(**payload)
        self._save()
        return self._settings

    def _load(self) -> AppSettings:
        defaults = AppSettings(
            target_protein=int(os.getenv("DEFAULT_TARGET_PROTEIN", "100")),
            recipient=os.getenv("EMAIL_RECIPIENT", ""),
            delivery_mode=os.getenv("DEFAULT_DELIVERY_MODE", "menu_only"),
            customization_notes=os.getenv("CUSTOMIZATION_NOTES", ""),
            schedule_frequency=os.getenv("SCHEDULE_FREQUENCY", "daily"),
            weekly_send_day=os.getenv("WEEKLY_SEND_DAY", "sat"),
            weekly_send_hour=int(os.getenv("WEEKLY_SEND_HOUR", "19")),
            weekly_send_minute=int(os.getenv("WEEKLY_SEND_MINUTE", "0")),
            app_timezone=os.getenv("APP_TIMEZONE", "Asia/Dubai"),
            openai_model=os.getenv("OPENAI_MODEL", "gpt-5"),
            next_day_only=os.getenv("NEXT_DAY_ONLY", "1") != "0",
            excluded_ingredients=[],
        )

        if not os.path.exists(self.path):
            return defaults

        with open(self.path, "r", encoding="utf-8") as settings_file:
            saved = json.load(settings_file)

        merged = asdict(defaults)
        merged.update(saved)
        if str(merged.get("recipient", "")).startswith("whatsapp:"):
            merged["recipient"] = defaults.recipient
        merged.setdefault("schedule_frequency", defaults.schedule_frequency)
        merged.setdefault("next_day_only", defaults.next_day_only)
        if merged.get("delivery_mode") == "full":
            merged["delivery_mode"] = defaults.delivery_mode
        return AppSettings(**merged)

    def _save(self) -> None:
        directory = os.path.dirname(self.path)
        if directory:
            os.makedirs(directory, exist_ok=True)

        with open(self.path, "w", encoding="utf-8") as settings_file:
            json.dump(asdict(self._settings), settings_file, indent=2)
