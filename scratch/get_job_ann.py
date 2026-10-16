import urllib.request
import json

url = "https://api.github.com/repos/GPS240988/beatemup_sakas/check-runs/117127290397/annotations"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
try:
    with urllib.request.urlopen(req) as resp:
        print("Annotations:", resp.read().decode())
except Exception as e:
    print("Error:", e)
