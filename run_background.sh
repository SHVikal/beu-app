#!/bin/zsh
set -e

cd "/Users/avikal/Documents/New project"

if [ ! -d ".venv" ]; then
  /usr/bin/python3 -m venv .venv
fi

source .venv/bin/activate
pip install -r requirements.txt >/tmp/protein-planner-pip.log 2>&1
exec python app.py
