import urllib.request
import json

commit_sha = "f2047da58db16503c15aa31952a2ceb587989932"
# Let's inspect all check runs for this commit
url = f"https://api.github.com/repos/GPS240988/beatemup_sakas/commits/{commit_sha}/check-runs?per_page=100"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode())
    print("Check runs count:", len(data.get("check_runs", [])))
    for cr in data.get("check_runs", []):
        if cr.get("conclusion") == "failure":
            print("=" * 60)
            print("FAILED:", cr.get("name"), "id:", cr.get("id"))
            out = cr.get("output", {})
            print("Title:", out.get("title"))
            print("Summary:", out.get("summary"))
            text = out.get("text")
            if text:
                print("Text:\n", text[:1000])
            ann_url = cr.get("annotations_url")
            if ann_url:
                try:
                    req_a = urllib.request.Request(ann_url, headers={"User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(req_a) as resp_a:
                        anns = json.loads(resp_a.read().decode())
                        for a in anns:
                            print("  Annotation:", a.get("path"), a.get("start_line"), a.get("message"))
                except Exception as ea:
                    print("  Ann error:", ea)
