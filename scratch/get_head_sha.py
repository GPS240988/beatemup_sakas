import urllib.request
import json

url = "https://api.github.com/repos/GPS240988/beatemup_sakas/actions/runs/38946629599"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode())
    print("Run name:", data.get("name"))
    print("Head SHA:", data.get("head_sha"))
    print("Head Commit:", data.get("head_commit", {}).get("message"))
