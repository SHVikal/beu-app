import os
from datetime import datetime

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from zoneinfo import ZoneInfo

from planner import MessageOptions


class ReminderScheduler:
    def __init__(self, plan_builder, message_builder, sender, settings_store):
        self.plan_builder = plan_builder
        self.message_builder = message_builder
        self.sender = sender
        self.settings_store = settings_store
        self.scheduler = BackgroundScheduler(timezone=self.timezone)

    @property
    def timezone(self):
        return ZoneInfo(self.settings_store.get().app_timezone)

    def start(self):
        if self.scheduler.running:
            return

        self._upsert_job()
        self.scheduler.start()

    def refresh_schedule(self):
        self._upsert_job()

    def describe_schedule(self) -> str:
        settings = self.settings_store.get()
        local_now = datetime.now(self.timezone).strftime("%A, %d %b %Y %H:%M %Z")
        if settings.schedule_frequency == "daily":
            cadence = f"every day at {settings.weekly_send_hour:02d}:{settings.weekly_send_minute:02d}"
        else:
            cadence = (
                f"every {settings.weekly_send_day.title()} at "
                f"{settings.weekly_send_hour:02d}:{settings.weekly_send_minute:02d}"
            )
        return (
            f"Configured to send {cadence} "
            f"({self.timezone.key}). Current app time: {local_now}."
        )

    def send_message(self, recipient: str, message: str) -> dict:
        return self.sender.send_message(recipient=recipient, message=message)

    def _scheduled_send(self):
        settings = self.settings_store.get()
        recipient = settings.recipient
        if not recipient:
            return

        plan = self.plan_builder(settings.target_protein)
        message = self.message_builder(
            plan,
            MessageOptions(
                delivery_mode=settings.delivery_mode,
                customization_notes=settings.customization_notes,
                next_day_only=settings.next_day_only,
                timezone_name=settings.app_timezone,
            ),
        )
        self.sender.send_message(recipient=recipient, message=message)

    def _upsert_job(self):
        settings = self.settings_store.get()
        if settings.schedule_frequency == "daily":
            trigger = CronTrigger(
                hour=settings.weekly_send_hour,
                minute=settings.weekly_send_minute,
                timezone=self.timezone,
            )
        else:
            trigger = CronTrigger(
                day_of_week=settings.weekly_send_day,
                hour=settings.weekly_send_hour,
                minute=settings.weekly_send_minute,
                timezone=self.timezone,
            )
        self.scheduler.add_job(
            self._scheduled_send,
            trigger,
            id="weekly-whatsapp-menu",
            replace_existing=True,
        )
