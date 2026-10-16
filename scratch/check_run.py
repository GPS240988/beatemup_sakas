import urllib.request
import json

run_id = "38946629599"
url = f"https://api.github.com/repos/GPS240988/beatemup_sakas/actions/runs/{run_id}/jobs"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode())
    print("Total jobs:", data.get("total_count"))
    for job in data.get("jobs", []):
        name = job.get("name")
        conclusion = job.get("conclusion")
        print(f"Job: {name} -> {conclusion}")
        if conclusion == "failure":
            for step in job.get("steps", []):
                if step.get("conclusion") == "failure":
                    print(f"   FAILED STEP: {step.get('name')}")
