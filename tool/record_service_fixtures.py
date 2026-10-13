#!/usr/bin/env python3
"""Records replies from a running PulseOS service, as the fixtures the app's widget tests replay without a network.

    python3 -I tool/record_service_fixtures.py            # service at http://localhost:8000/v1/pulse
    PULSE_API=http://host:8000/v1/pulse python3 -I tool/record_service_fixtures.py

It starts one Demo Mode visit per role (patient, doctor, nurse), asks the routes the screens call, saves each reply as
JSON under test/fixtures/service/ and ends every visit with POST /demo/end. It also runs POST /study twice. It uses
Demo Mode and /study only: it never signs up or signs in. Python 3 standard library only.

The assistant is asked 18 questions in English and in Hindi (X-Lang: hi, the same English text), about a minute in all,
because the service allows 30 questions a minute per visitor. The Research Lab study can take a while the first time.

What is saved (test/fixtures/service/):
  meta.json                          the day it was recorded (India) and the time-zone offset, so tests can move the dates
  study_seed7.json, study_lab.json   POST /study: {"config":{"seed":7},"noise":null,"markdown":false} and the Research Lab's
                                     default request
  demo_end.json                      POST /demo/end
  patient/                           demo_start (token replaced), me, me_data, doctors, slots_d1, wearer_live.ndjson (the
                                     first 4 lines), assistant_en / assistant_hi (question -> reply), sos, sos_end,
                                     wearer_live_hypoxia (a snapshot with a level-4 safety alert after the oxygen
                                     scenario in fast mode), wearer_update_hypoxia (the update line that carried it)
  doctor/ and nurse/                 demo_start (token replaced), me, care_state, labels, ward_live.ndjson (the first 3
                                     lines), wearer_live.ndjson (the first line), ward_chat

Demo tokens are never saved: demo_start.json holds "pd1.recorded.<role>" instead.
"""
import json
import os
import shutil
import sys
import threading
import time
import urllib.error
import urllib.request
from collections import deque
from datetime import datetime, timedelta, timezone
from pathlib import Path

BASE = os.environ.get("PULSE_API", "http://localhost:8000/v1/pulse").rstrip("/")
OUT = Path(__file__).resolve().parent.parent / "test" / "fixtures" / "service"
TZ_OFFSET = 330  # India
BEDS = "B01,B02,B03,B04,B05,B06,B08,B09,B10,B11,B12"

# The questions the assistant screen sends: HealthAssistant.suggestions, HealthAssistant.helpSuggestions, the help-topic
# buttons, and the question typed in the old "help topic opens the right place" test.
QUESTIONS = [
    "How am I doing today?",
    "Why did I get my last alert?",
    "What has AdaptAlert learned about me?",
    "When is my next appointment?",
    "What medicines do I take?",
    "Is my insurance claim approved?",
    "I have chest pain",
    "Where are my reports?",
    "Where are my medicines?",
    "How do I book an appointment?",
    "How do I change the language?",
    "I feel unwell",
    "Where are my family contacts?",
    "Where is my insurance?",
    "Call my family",
    "How do I make the text bigger?",
    "What can you help with?",
    "How do I change my appointment?",
]

# What the Research Lab sends when it opens: StudyConfig() and the noise sweep it asks for (24 patients, 3 seeds).
LAB_REQUEST = {
    "config": {
        "patients": 40, "days": 30, "seed": 7, "labelRate": 0.9, "labelNoise": 0.0, "dismissRate": 0.0, "k": 4.0,
        "rejectStep": 0.03, "confirmStep": 0.05, "realEventRate": 0.12,
    },
    "noise": {"patients": 24, "seeds": 3},
    "markdown": True,
}
SEED_REQUEST = {"config": {"seed": 7}, "noise": None, "markdown": False}


class Failed(Exception):
    pass


def request(method, path, body=None, token=None, lang="en"):
    headers = {"Accept": "application/json", "X-Tz-Offset": str(TZ_OFFSET), "X-Lang": lang}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    if token:
        headers["Authorization"] = "Bearer " + token
    return urllib.request.Request(BASE + path, data=data, headers=headers, method=method)


def call(method, path, body=None, token=None, lang="en", timeout=60):
    """The decoded JSON reply. Anything but a 2xx stops the run."""
    try:
        with urllib.request.urlopen(request(method, path, body, token, lang), timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8") or "null")
    except urllib.error.HTTPError as e:
        raise Failed("%s %s answered %s: %s" % (method, path, e.code, e.read().decode("utf-8", "replace")[:300]))
    except (urllib.error.URLError, OSError) as e:
        raise Failed("%s %s could not be reached (%s). Is the service running at %s?" % (method, path, e, BASE))


def open_stream(path, token, timeout=30):
    try:
        return urllib.request.urlopen(request("GET", path, token=token), timeout=timeout)
    except urllib.error.HTTPError as e:
        raise Failed("GET %s answered %s: %s" % (path, e.code, e.read().decode("utf-8", "replace")[:300]))
    except (urllib.error.URLError, OSError) as e:
        raise Failed("GET %s could not be reached (%s)" % (path, e))


def read_lines(path, token, count, timeout=30):
    """The first [count] lines of an NDJSON stream (pings do not count), then the connection is closed."""
    resp = open_stream(path, token, timeout)
    try:
        lines = []
        while len(lines) < count:
            raw = resp.readline()
            if not raw:
                raise Failed("GET %s ended after %d line(s), wanted %d" % (path, len(lines), count))
            if not raw.strip():
                continue
            line = json.loads(raw)
            if line.get("type") != "ping":
                lines.append(line)
        return lines
    except OSError as e:  # a stalled stream
        raise Failed("GET %s stopped answering (%s)" % (path, e))
    finally:
        resp.close()


def pretty(obj):
    """Small replies are indented so a diff can be read; big ones (the band's history) stay on one line."""
    compact = json.dumps(obj, ensure_ascii=False, separators=(",", ":"))
    if len(compact) > 20000:
        return compact + "\n"
    return json.dumps(obj, ensure_ascii=False, indent=2) + "\n"


class Files:
    def __init__(self, root):
        self.root = root

    def json(self, name, obj):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(pretty(obj), encoding="utf-8")

    def ndjson(self, name, lines):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("".join(json.dumps(l, ensure_ascii=False, separators=(",", ":")) + "\n" for l in lines), encoding="utf-8")


class Visit:
    """One Demo Mode visit: started on entry, always ended on exit."""

    def __init__(self, role, files):
        self.role, self.files = role, files
        self.token = None

    def __enter__(self):
        start = call("POST", "/demo/start", {"role": self.role})
        self.token = start.pop("token")
        if not isinstance(self.token, str) or not self.token.startswith("pd1."):
            raise Failed("POST /demo/start gave no demo token")
        start["token"] = "pd1.recorded." + self.role  # a real token is never kept
        self.files.json(self.role + "/demo_start.json", start)
        print("  %s visit started (%s)" % (self.role, start.get("name")))
        return self

    def __exit__(self, *exc):
        if self.token:
            try:
                ended = call("POST", "/demo/end", token=self.token)
                if self.role == "patient":
                    self.files.json("demo_end.json", ended)
                print("  %s visit ended" % self.role)
            except Failed as e:
                print("  could not end the %s visit: %s" % (self.role, e), file=sys.stderr)
        return False

    def get(self, path, lang="en"):
        return call("GET", path, token=self.token, lang=lang)

    def post(self, path, body=None, lang="en"):
        return call("POST", path, body, token=self.token, lang=lang)

    def lines(self, path, count):
        return read_lines(path, self.token, count)


# --------------------------------------------------------------------------------------------------------------------

def ask_all(visit, files):
    """Every question, in English and then in Hindi, kept under the service's 30 questions a minute."""
    sent = deque()

    def ask(question, lang):
        while len(sent) >= 29 and time.monotonic() - sent[0] < 61:
            time.sleep(1)
        while sent and time.monotonic() - sent[0] >= 61:
            sent.popleft()
        sent.append(time.monotonic())
        return visit.post("/assistant", {"q": question}, lang=lang)

    for lang in ("en", "hi"):
        replies = {}
        for q in QUESTIONS:
            replies[q] = ask(q, lang)
        files.json("patient/assistant_%s.json" % lang, replies)
        print("  assistant: %d questions in %s" % (len(replies), lang))


def hypoxia(visit, files):
    """Plays the oxygen-drop scenario in fast mode until the level-4 safety alert arrives, and keeps what the service sent."""
    found = {}
    stop = threading.Event()
    up = threading.Event()

    def watch():
        resp = None
        try:
            resp = open_stream("/wearer/live", visit.token, timeout=30)
            up.set()
            while not stop.is_set():
                raw = resp.readline()
                if not raw:
                    break
                line = json.loads(raw) if raw.strip() else {}
                if line.get("type") != "update":
                    continue
                for alert in line.get("alerts", []):
                    if alert.get("level") == 4 and alert.get("safety"):
                        found["update"], found["alert"] = line, alert
                        stop.set()
                        return
        except Exception as e:  # reported by the caller
            found["error"] = e
        finally:
            up.set()
            if resp is not None:
                resp.close()

    watcher = threading.Thread(target=watch, daemon=True)
    watcher.start()
    if not up.wait(30) or "error" in found:
        raise Failed("the wearer stream did not open: %s" % found.get("error"))
    visit.post("/wearer/fast", {"fast": True})
    visit.post("/wearer/scenario", {"id": "hypoxia"})
    watcher.join(90)
    stop.set()
    if "alert" not in found:
        raise Failed("no level-4 safety alert came within 90 seconds: %s" % found.get("error"))
    snapshot = visit.lines("/wearer/live", 1)[0]
    alerts = [a for a in snapshot["state"]["alerts"] if a.get("level") == 4 and a.get("safety")]
    if snapshot.get("type") != "snapshot" or not alerts:
        raise Failed("the snapshot after the oxygen drop has no level-4 safety alert")
    if not alerts[0].get("auto_sos"):
        raise Failed("the level-4 alert is not marked for auto SOS (is the patient's Auto SOS preference off?)")
    files.json("patient/wearer_live_hypoxia.json", snapshot)
    files.json("patient/wearer_update_hypoxia.json", found["update"])
    print("  hypoxia: level-4 alert #%s recorded" % alerts[0]["id"])


def patient(files):
    with Visit("patient", files) as v:
        files.json("patient/me.json", v.get("/me"))
        files.json("patient/me_data.json", v.get("/me/data"))
        files.json("patient/doctors.json", v.get("/doctors"))
        today = (datetime.now(timezone(timedelta(minutes=TZ_OFFSET)))).date().isoformat()
        files.json("patient/slots_d1.json", v.get("/doctors/d1/slots?from=%s&days=14" % today))
        # The assistant answers from the band, so ask before anything moves it.
        ask_all(v, files)
        files.ndjson("patient/wearer_live.ndjson", v.lines("/wearer/live", 4))
        sos = v.post("/sos", {"alert_id": None})
        files.json("patient/sos.json", sos)
        files.json("patient/sos_end.json", v.post("/sos/%s/end" % sos["id"]))
        hypoxia(v, files)
        return today


def staff(role, files):
    with Visit(role, files) as v:
        files.json("%s/me.json" % role, v.get("/me"))
        files.json("%s/care_state.json" % role, v.get("/care/state?beds=" + BEDS))
        files.json("%s/labels.json" % role, v.get("/labels"))
        files.ndjson("%s/ward_live.ndjson" % role, v.lines("/ward/live", 3))
        files.ndjson("%s/wearer_live.ndjson" % role, v.lines("/wearer/live", 1))
        files.json("%s/ward_chat.json" % role, v.post("/ward/chat", {"bed": "B02", "q": "Is this sepsis?"}))


def studies(files):
    files.json("study_seed7.json", call("POST", "/study", SEED_REQUEST, timeout=600))
    print("  study: seed 7")
    files.json("study_lab.json", call("POST", "/study", LAB_REQUEST, timeout=600))
    print("  study: the Research Lab's default")


def main():
    tmp = OUT.parent / (OUT.name + ".recording")
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir(parents=True)
    files = Files(tmp)
    try:
        print("Recording from %s" % BASE)
        today = patient(files)
        staff("doctor", files)
        staff("nurse", files)
        studies(files)
        files.json("meta.json", {
            "recorded_on": today, "tz_offset": TZ_OFFSET, "api": BASE, "beds": BEDS.split(","), "questions": QUESTIONS,
        })
    except Failed as e:
        shutil.rmtree(tmp, ignore_errors=True)
        print("Stopped, nothing was changed in %s: %s" % (OUT, e), file=sys.stderr)
        return 1
    if OUT.exists():
        shutil.rmtree(OUT)
    os.replace(tmp, OUT)
    print("Saved %d files under %s" % (sum(1 for p in OUT.rglob("*") if p.is_file()), OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
