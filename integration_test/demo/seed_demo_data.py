"""Fills a local Agrynex server with demo alerts and users for the app walkthrough.

Alerts come from running the Pi's own animal detection over a video, so every
snapshot, clip and label is what the real system would produce. They're spread
over the last day, newest first.

Run with the Python environment of the Raspberry Pi repo (it needs OpenCV and
the models):
    python seed_demo_data.py --pi-dir ../../../agrynex-raspberry-pi --video "coyote_meets_camera (540p).mp4"
"""
import argparse
import os
import sys
from datetime import datetime, timedelta, timezone

import requests

# How long ago each alert happened.
ALERT_AGES = [timedelta(minutes=m) for m in (25, 95, 190, 360, 660, 1140)]
MIN_GAP_S = 20          # Keep picked detections this far apart in the video
CLIP_FPS = 10
DEMO_USERS = [
    {"name": "Sam Patel", "email": "sam@example.com", "password": "demo-pass-1", "role": "user"},
    {"name": "Alex Morgan", "email": "alex@example.com", "password": "demo-pass-2", "role": "admin"},
]


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--server", default="http://localhost:8000")
    p.add_argument("--device-token", default="local-device-token")
    p.add_argument("--admin-email", default="admin@example.com")
    p.add_argument("--admin-password", default="admin-pass-1")
    p.add_argument("--pi-dir", required=True)
    p.add_argument("--video", required=True, help="Video file, relative to --pi-dir or absolute")
    p.add_argument("--labels", default="",
                   help="Comma-separated labels to keep, for example dog. Default: any animal")
    return p.parse_args()


def main():
    args = parse_args()
    pi_dir = os.path.abspath(args.pi_dir)
    sys.path.insert(0, pi_dir)
    os.chdir(pi_dir)  # The Pi code loads its models by relative path.
    import cv2
    import newer_yolo_detection as pi
    from clip_recorder import encode_mp4

    pi.load_models()
    admin = requests.Session()
    token = admin.post(f"{args.server}/api/auth/login",
                       json={"email": args.admin_email, "password": args.admin_password}).json()["token"]
    admin.headers["Authorization"] = f"Bearer {token}"
    device = requests.Session()
    device.headers["Authorization"] = f"Bearer {args.device_token}"

    cap = cv2.VideoCapture(args.video)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    def frame_at(seconds):
        cap.set(cv2.CAP_PROP_POS_FRAMES, int(seconds * fps))
        ok, frame = cap.read()
        return frame if ok else None

    def annotate(frame):
        """Detect and draw boxes the same way the Pi's camera loop does."""
        detections = pi.detect_animals(frame)
        for det in detections:
            (sx, sy, ex, ey) = det["box"]
            cv2.rectangle(frame, (sx, sy), (ex, ey), (0, 0, 255), 2)
            cv2.putText(frame, f"{det['label']}: {det['confidence']:.2f}", (sx, sy - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 2)
        return frame, detections

    labels = {label.strip() for label in args.labels.split(",") if label.strip()}
    # Find confident detections, spread through the video.
    print("Scanning video for detections...")
    picks = []
    for second in range(5, int(total / fps) - 10):
        frame = frame_at(second)
        if frame is None:
            continue
        found = [d for d in pi.detect_animals(frame)
                 if d["confidence"] >= 0.6 and (not labels or d["label"] in labels)]
        if found and (not picks or second - picks[-1][0] >= MIN_GAP_S):
            best = max(found, key=lambda d: d["confidence"])
            print(f"  {second}s: {best['label']} {best['confidence']:.2f}")
            picks.append((second, found))
    picks = picks[:len(ALERT_AGES)]
    if not picks:
        sys.exit("No detections found in the video")

    # Oldest first, so the newest alert is created last.
    now = datetime.now(timezone.utc)
    for (second, _), age in sorted(zip(picks, ALERT_AGES), key=lambda p: -p[1].total_seconds()):
        snapshot_frame, detections = annotate(frame_at(second))
        if labels:
            detections = [d for d in detections if d["label"] in labels]
        ok, snapshot = cv2.imencode(".jpg", snapshot_frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
        clip_frames = []
        for i in range(-5 * CLIP_FPS, 10 * CLIP_FPS):
            t = second + i / CLIP_FPS
            frame = frame_at(t)
            if frame is not None:
                frame, _ = annotate(frame)
                clip_frames.append((t, cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 80])[1].tobytes()))
        clip = encode_mp4(clip_frames)

        res = device.post(f"{args.server}/api/device/alerts", json={
            "detections": [{"kind": "animal", "label": d["label"], "confidence": d["confidence"]}
                           for d in detections],
            "detected_at": (now - age).isoformat(),
            "snapshot": True,
            "clip": clip is not None,
        })
        res.raise_for_status()
        alert = res.json()
        status = {}
        for kind, data in (("snapshot", snapshot.tobytes()), ("clip", clip)):
            if data is None:
                continue
            upload = alert["uploads"][kind]
            put = requests.put(upload["url"], data=data, headers={"Content-Type": upload["content_type"]})
            status[kind] = "ready" if put.ok else "failed"
        device.post(f"{args.server}/api/device/alerts/{alert['id']}/media", json=status).raise_for_status()
        print(f"Alert {alert['id']}: {[d['label'] for d in detections]}, {age} ago, {status}")

    for user in DEMO_USERS:
        res = admin.post(f"{args.server}/api/users", json=user)
        print(f"User {user['email']}: {res.status_code}")


if __name__ == "__main__":
    main()
