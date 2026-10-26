# Demo walkthrough and recording

`integration_test/app_test.dart` walks through the whole app at a pace you can watch. It covers:

1. Signing in.
2. The Pi's status, with detection off.
3. Switching the siren and sprinkler by hand.
4. Live view.
5. The alerts list and one alert's clip.
6. Settings.
7. Users.
8. Turning the system off and back on.
9. Finale: turning animal detection on. The coyote in the video sets off the siren and sprinkler, and a live alert may arrive.

Before the app opens, the test uses the API to turn animal and person detection off and the system on, so every run starts the same way. Person detection stays off throughout because YOLO sometimes mistakes something in the coyote video for a person, which would set off the siren during the manual-control step.

Taps show a white circle so they're visible on video. The run takes about 90 seconds.

It needs a local cloud server with demo data and a connected Pi. These steps assume the three repos sit side by side, and that `coyote_meets_camera (540p).mp4` is in the Pi folder.

## 1. Start the server, fake S3 and Pi

```bash
# Fake S3 (from agrynex-cloud-server, with requirements-dev installed)
moto_server -p 5001
python -c "import boto3; boto3.client('s3', endpoint_url='http://localhost:5001', region_name='us-east-1').create_bucket(Bucket='agrynex-media')"

# Cloud server, with a .env like .env.example plus:
#   MONGODB_URI=mongodb://127.0.0.1:27017  MONGODB_DB=agrynex_demo
#   S3_BUCKET=agrynex-media  S3_ENDPOINT_URL=http://localhost:5001
#   AWS_ACCESS_KEY_ID=test  AWS_SECRET_ACCESS_KEY=test
#   DEVICE_TOKEN=local-device-token  SESSION_COOKIE_SECURE=false
#   ADMIN_EMAIL=admin@example.com  ADMIN_PASSWORD=admin-pass-1
gunicorn -w 1 --threads 100 -b 0.0.0.0:8000 wsgi:app

# Pi, on this computer with mock GPIO (from agrynex-raspberry-pi)
GPIOZERO_PIN_FACTORY=mock AGRYNEX_SERVER_URL=http://localhost:8000 \
AGRYNEX_DEVICE_TOKEN=local-device-token AGRYNEX_VIDEO_SOURCE="coyote_meets_camera (540p).mp4" \
python newer_yolo_detection.py
```

Wait for the Pi to make its first detection, so the dashboard shows a "last detection" time. Then turn animal and person detection off from the dashboard, so the Pi stops making alerts while you seed. Delete any alerts it made, either from the dashboard or with `DELETE /api/alerts/<id>`.

## 2. Seed demo data

The seed script runs the Pi's own detection model over the video and turns real detections into six alerts, each with a snapshot and clip. The alerts are spread over the last 19 hours. It also adds two users. Run it with the Pi's Python environment:

```bash
cd integration_test/demo
python seed_demo_data.py --pi-dir ../../../agrynex-raspberry-pi --video "coyote_meets_camera (540p).mp4" --labels dog
```

`--labels dog` keeps only frames the model labeled "dog", which is its closest class to a coyote. In other frames it calls the coyote a bird, sheep or cow. The clips show every box the model drew.

## 3. Record

```bash
# Clean status bar: 9:41, full battery
xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3

xcrun simctl io booted recordVideo --codec=h264 --force raw.mp4 &
flutter test integration_test/app_test.dart -d <simulator id> --dart-define=SERVER_URL=http://localhost:8000
kill -INT %1
```

The raw recording starts with the build and Flutter's "Test starting…" screen. Trim it to where the sign-in screen appears, for example:

```bash
ffmpeg -ss <start> -to <end> -i raw.mp4 -vf fps=60 -c:v libx264 -crf 16 -pix_fmt yuv420p out.mp4
```

The test leaves the system switched on. If it stops partway through, switch the system back on before running it again.
