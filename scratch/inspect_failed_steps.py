import urllib.request
import json

url = "https://api.github.com/repos/GPS240988/beatemup_sakas/actions/runs/38946629599/jobs"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode())
    for job in data.get("jobs", []):
        if job.get("conclusion") == "failure":
            print("=" * 60)
            print("JOB:", job.get("name"), "id:", job.get("id"))
            for step in job.get("steps", []):
                print(f"  Step: {step.get('name')} | conclusion: {step.get('conclusion')} | number: {step.get('number')}")
