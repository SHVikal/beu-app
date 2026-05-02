#!/bin/zsh
set -e

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example. Add your email and OpenAI keys, then rerun ./start.sh."
  exit 0
fi

if [ ! -d .venv ]; then
  /usr/bin/python3 -m venv .venv
fi

source .venv/bin/activate
pip install -r requirements.txt
python app.py
