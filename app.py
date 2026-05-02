import os
from dataclasses import asdict

from email_service import EmailSender
from flask import Flask, jsonify, render_template, request

from natural_language import PromptInterpreter
from planner import MessageOptions, build_plan, build_whatsapp_message_with_options
from scheduler import ReminderScheduler
from settings_store import SettingsStore


def load_env_file(path: str = ".env") -> None:
    if not os.path.exists(path):
        return

    with open(path, "r", encoding="utf-8") as env_file:
        for line in env_file:
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or "=" not in stripped:
                continue
            key, value = stripped.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip())


def create_app() -> Flask:
    load_env_file()
    app = Flask(__name__)
    settings_store = SettingsStore()
    prompt_interpreter = PromptInterpreter()

    scheduler = ReminderScheduler(
        plan_builder=build_plan,
        message_builder=build_whatsapp_message_with_options,
        sender=EmailSender(),
        settings_store=settings_store,
    )
    scheduler.start()

    @app.get("/")
    def home():
        settings = settings_store.get()
        target = int(request.args.get("target", settings.target_protein))
        plan = build_plan(target)
        preview = build_whatsapp_message_with_options(
            plan,
            MessageOptions(
                delivery_mode=settings.delivery_mode,
                customization_notes=settings.customization_notes,
                next_day_only=settings.next_day_only,
                timezone_name=settings.app_timezone,
            ),
        )
        return render_template(
            "index.html",
            plan=plan,
            preview=preview,
            target=target,
            schedule=scheduler.describe_schedule(),
            settings=settings,
        )

    @app.post("/api/preview")
    def preview():
        payload = request.get_json(silent=True) or {}
        settings = settings_store.get()
        target = int(payload.get("targetProtein", settings.target_protein))
        delivery_mode = payload.get("deliveryMode", settings.delivery_mode)
        customization_notes = payload.get("customizationNotes", settings.customization_notes)
        plan = build_plan(target)
        preview_message = build_whatsapp_message_with_options(
            plan,
            MessageOptions(
                delivery_mode=delivery_mode,
                customization_notes=customization_notes,
                next_day_only=settings.next_day_only,
                timezone_name=settings.app_timezone,
            ),
        )
        return jsonify(
            {
                "targetProtein": target,
                "summary": {
                    "days": len(plan.days),
                    "averageProtein": round(
                        sum(day.total_protein for day in plan.days) / len(plan.days)
                    ),
                    "shoppingItems": len(plan.shopping_items),
                },
                "message": preview_message,
                "shoppingItems": [asdict(item) for item in plan.shopping_items],
            }
        )

    @app.post("/api/send-now")
    def send_now():
        payload = request.get_json(silent=True) or {}
        settings = settings_store.get()
        target = int(payload.get("targetProtein", settings.target_protein))
        recipient = payload.get("recipient") or settings.recipient

        if not recipient:
            return (
                jsonify(
                    {
                        "ok": False,
                        "error": (
                            "Missing recipient. Set EMAIL_RECIPIENT or provide "
                            "recipient in the request."
                        ),
                    }
                ),
                400,
            )

        plan = build_plan(target)
        message = build_whatsapp_message_with_options(
            plan,
            MessageOptions(
                delivery_mode=payload.get("deliveryMode", settings.delivery_mode),
                customization_notes=payload.get("customizationNotes", settings.customization_notes),
                next_day_only=settings.next_day_only,
                timezone_name=settings.app_timezone,
            ),
        )
        result = scheduler.send_message(recipient=recipient, message=message)
        return jsonify(result)

    @app.post("/api/prompt")
    def prompt():
        payload = request.get_json(silent=True) or {}
        prompt_text = (payload.get("prompt") or "").strip()
        if not prompt_text:
            return jsonify({"ok": False, "error": "Prompt is required."}), 400

        current_settings = settings_store.get()
        interpreted = prompt_interpreter.interpret(prompt_text, current_settings)
        updated_settings = settings_store.update(
            target_protein=interpreted.get("target_protein") or current_settings.target_protein,
            recipient=interpreted.get("recipient") or current_settings.recipient,
            delivery_mode=interpreted.get("delivery_mode") or current_settings.delivery_mode,
            customization_notes=interpreted.get("customization_notes")
            if interpreted.get("customization_notes") is not None
            else current_settings.customization_notes,
            weekly_send_day=interpreted.get("schedule_day") or current_settings.weekly_send_day,
            weekly_send_hour=interpreted.get("schedule_hour")
            if interpreted.get("schedule_hour") is not None
            else current_settings.weekly_send_hour,
            weekly_send_minute=interpreted.get("schedule_minute")
            if interpreted.get("schedule_minute") is not None
            else current_settings.weekly_send_minute,
        )
        scheduler.refresh_schedule()

        plan = build_plan(updated_settings.target_protein)
        message = build_whatsapp_message_with_options(
            plan,
            MessageOptions(
                delivery_mode=updated_settings.delivery_mode,
                customization_notes=updated_settings.customization_notes,
                next_day_only=updated_settings.next_day_only,
                timezone_name=updated_settings.app_timezone,
            ),
        )
        send_result = None
        if interpreted.get("send_now") and updated_settings.recipient:
            send_result = scheduler.send_message(updated_settings.recipient, message)

        return jsonify(
            {
                "ok": True,
                "assistantReply": interpreted.get("assistant_reply"),
                "unsupportedRequests": interpreted.get("unsupported_requests", []),
                "settings": asdict(updated_settings),
                "message": message,
                "sendResult": send_result,
                "schedule": scheduler.describe_schedule(),
            }
        )

    return app


app = create_app()


if __name__ == "__main__":
    debug = os.getenv("FLASK_DEBUG", "0") == "1"
    app.run(
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8000")),
        debug=debug,
        use_reloader=False,
    )
