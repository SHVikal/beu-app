import os
import smtplib
from email.message import EmailMessage


class EmailSender:
    def __init__(self):
        self.smtp_host = os.getenv("SMTP_HOST", "")
        self.smtp_port = int(os.getenv("SMTP_PORT", "587"))
        self.smtp_username = os.getenv("SMTP_USERNAME", "")
        self.smtp_password = os.getenv("SMTP_PASSWORD", "")
        self.from_email = os.getenv("EMAIL_FROM", self.smtp_username)

    def send_message(self, recipient: str, message: str) -> dict:
        missing = [
            name
            for name, value in {
                "SMTP_HOST": self.smtp_host,
                "SMTP_PORT": str(self.smtp_port),
                "SMTP_USERNAME": self.smtp_username,
                "SMTP_PASSWORD": self.smtp_password,
                "EMAIL_FROM": self.from_email,
            }.items()
            if not value
        ]
        if missing:
            return {"ok": False, "error": f"Missing environment variables: {', '.join(missing)}"}

        recipients = normalize_recipients(recipient)
        if not recipients:
            return {"ok": False, "error": "No valid email recipients provided."}

        email = EmailMessage()
        email["From"] = self.from_email
        email["To"] = ", ".join(recipients)
        email["Subject"] = "Weekly protein plan"
        email.set_content(message)

        try:
            with smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=30) as smtp:
                smtp.starttls()
                smtp.login(self.smtp_username, self.smtp_password)
                smtp.send_message(email)
        except Exception as exc:
            return {"ok": False, "error": str(exc)}

        return {"ok": True, "status": "sent", "recipients": recipients}


def normalize_recipients(recipient_value: str) -> list[str]:
    return [
        item.strip()
        for item in recipient_value.split(",")
        if item.strip()
    ]
