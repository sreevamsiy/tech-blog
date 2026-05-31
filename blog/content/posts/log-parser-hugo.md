---
title: "Building a Python Log Parser for DevOps Workflows"
date: 2026-05-24
draft: false
description: "A small Python CLI for parsing access logs and surfacing useful DevOps signals."
tags:
  - python
  - devops
  - cli
  - pytest
categories:
  - DevOps
  - Python
---

A small access-log analysis tool is a useful example of Python in DevOps workflows. It starts with basic file parsing and grows into a practical CLI with JSON output, input validation, and tests.

This post walks through the design and implementation of that tool.

Source code: [github.com/sreevamsiy/devops-python-toolkit/tree/main/log-parser](https://github.com/sreevamsiy/devops-python-toolkit/tree/main/log-parser)

## The Goal

Given a web access log, write a Python script that can answer common operational questions:

- Which IP addresses made the most requests?
- Which HTTP status codes are most common?
- Which requests failed?
- Which endpoints are requested the most?

The script can also be exposed as a CLI tool:

```bash
python3 parser.py sample_access.log --top-ips --limit 3
```

And also support JSON output:

```bash
python3 parser.py sample_access.log --top-ips --limit 2 --json
```

## Sample Log Format

The sample log used an Apache/Nginx-style access log format:

```text
192.168.1.10 - - [23/May/2026:09:12:01 +0530] "GET /api/v1/users HTTP/1.1" 200 512 "-" "curl/8.1.2"
```

After splitting the line with `split()`, the important fields are:

```text
0  IP address
5  HTTP method
6  endpoint
8  status code
9  bytes sent
```

This is a simple approach and works for this controlled log format.

## First Version

The first version counted IP addresses with a normal dictionary:

```python
ip_count[ip] = ip_count.get(ip, 0) + 1
```

That works, but Python has a better tool for counting: `Counter`.

```python
from collections import Counter

ip_count = Counter()
ip_count[ip] += 1
```

`Counter` behaves like a dictionary, but missing keys start at `0`, which makes counting cleaner.

## Parsing the Log File

The parser reads each line, skips malformed lines, converts numeric fields, and keeps the raw line for later output.

```python
def parse_log_file(filename):
    line_list = []

    with open(filename, "r") as file:
        for line in file:
            line_dict = {}
            parts = line.split()

            if len(parts) < 10:
                continue

            line_dict["ip"] = parts[0]
            line_dict["endpoint"] = parts[6]

            try:
                line_dict["http_code"] = int(parts[8])
                line_dict["bytes"] = int(parts[9])
            except ValueError:
                continue

            line_dict["raw"] = line.strip()
            line_list.append(line_dict)

    return line_list
```

Two important production-minded details:

- malformed lines are skipped
- `http_code` and `bytes` are converted to integers during parsing

## Analysis Functions

The analysis functions return data instead of printing directly. This makes them easier to test and reuse.

```python
def top_ips(records, limit):
    ip_count = Counter()

    for item in records:
        ip_count[item["ip"]] += 1

    return dict(ip_count.most_common(limit))
```

The same pattern is used for status codes and endpoints:

```python
def top_codes(records, limit):
    code_counter = Counter()

    for item in records:
        code_counter[item["http_code"]] += 1

    return dict(code_counter.most_common(limit))
```

```python
def most_requested(records, limit):
    endpoint_counter = Counter()

    for item in records:
        endpoint_counter[item["endpoint"]] += 1

    return dict(endpoint_counter.most_common(limit))
```

Failed requests return the raw log lines:

```python
def failed_requests(records):
    failed_reqs = []

    for item in records:
        if item["http_code"] > 399:
            failed_reqs.append(item["raw"])

    return failed_reqs
```

## Turning It Into a CLI

The script uses `argparse` so the filename and report type can be passed from the command line.

```python
parser = argparse.ArgumentParser(description="Analyze web access logs")
parser.add_argument("filename", help="Path to access log file")
parser.add_argument("--top-ips", action="store_true", help="Show top IP addresses")
parser.add_argument("--top-codes", action="store_true", help="Show top HTTP status codes")
parser.add_argument("--failed", action="store_true", help="Show failed requests")
parser.add_argument("--top-endpoints", action="store_true", help="Show most requested endpoints")
parser.add_argument("--limit", type=int, default=5, help="Number of top results to show")
parser.add_argument("--json", action="store_true", help="Output results as JSON")
```

`action="store_true"` means the flag becomes `True` if it appears in the command:

```bash
python3 parser.py sample_access.log --top-ips
```

So inside Python:

```python
args.top_ips == True
```

## Showing All Reports by Default

If the user does not pass any report flag, the script shows all reports.

```python
show_all = not any([
    args.top_ips,
    args.top_codes,
    args.failed,
    args.top_endpoints,
])
```

`not any([...])` means none of those flags were selected.

## Clean Error Handling

For invalid input, the tool prints errors to `stderr` and exits with a non-zero code.

```python
if args.limit <= 0:
    print("Error: --limit must be greater than 0", file=sys.stderr)
    sys.exit(1)
```

For missing files:

```python
try:
    records = parse_log_file(args.filename)
except FileNotFoundError:
    print(f"Error: file not found: {args.filename}", file=sys.stderr)
    sys.exit(1)
```

This matters for DevOps because scripts are often used in CI/CD pipelines. A non-zero exit code tells the shell or pipeline that the command failed.

## JSON Output

For automation, JSON is better than human-formatted text.

```python
if args.json:
    print(json.dumps(results, indent=2))
```

Example:

```bash
python3 parser.py sample_access.log --top-ips --limit 2 --json
```

Output:

```json
{
  "top_ips": {
    "192.168.1.10": 5,
    "10.0.0.25": 4
  }
}
```

## Testing With Pytest

The project also includes pytest tests.

The reusable fixture loads the sample log:

```python
@pytest.fixture
def records():
    return parse_log_file("sample_access.log")
```

Then tests can receive `records` automatically:

```python
def test_top_ips(records):
    assert top_ips(records, 1) == {"192.168.1.10": 5}
```

## Testing Bad Lines With `tmp_path`

`tmp_path` creates a temporary directory for tests. This lets the test create its own log file instead of depending on the real sample file.

```python
def test_parse_log_file_skips_bad_lines(tmp_path):
    log_file = tmp_path / "test.log"

    log_file.write_text(
        '1.1.1.1 - - [23/May/2026:09:12:01 +0530] "GET /ok HTTP/1.1" 200 123 "-" "curl"\n'
        'bad malformed line\n'
        '2.2.2.2 - - [23/May/2026:09:12:02 +0530] "GET /bad HTTP/1.1" ERROR 456 "-" "curl"\n'
    )

    records = parse_log_file(log_file)

    assert len(records) == 1
    assert records[0]["ip"] == "1.1.1.1"
    assert records[0]["endpoint"] == "/ok"
    assert records[0]["http_code"] == 200
    assert records[0]["bytes"] == 123
```

This test proves the parser skips malformed lines and invalid status codes.

## Testing CLI Behavior

The CLI is tested with `subprocess.run()`:

```python
def test_cli_rejects_invalid_limit():
    result = subprocess.run(
        [sys.executable, "parser.py", "sample_access.log", "--limit", "0"],
        capture_output=True,
        text=True,
    )

    assert result.returncode == 1
    assert "Error: --limit must be greater than 0" in result.stderr
```

This runs the script like a real user would run it.

JSON output is tested by parsing `stdout`:

```python
def test_cli_json_top_ips_success():
    result = subprocess.run(
        [sys.executable, "parser.py", "sample_access.log", "--top-ips", "--limit", "1", "--json"],
        capture_output=True,
        text=True,
    )

    data = json.loads(result.stdout)

    assert result.returncode == 0
    assert data == {"top_ips": {"192.168.1.10": 5}}
    assert result.stderr == ""
```

## Final Test Result

The final test suite has 9 tests:

```text
9 passed
```

It covers:

- parsing valid log lines
- skipping malformed log lines
- top IP calculation
- top status code calculation
- failed request filtering
- top endpoint calculation
- invalid CLI limit
- missing file handling
- JSON CLI output

## Key Takeaways

This example starts as a simple script, but the useful engineering details come from improving it:

- use `Counter` for counting problems
- parse once, analyze many times
- return data from functions instead of printing inside them
- use `argparse` for CLI tools
- validate user input
- print errors to `stderr`
- exit with non-zero status on failure
- support JSON for automation
- test functions directly
- test CLI behavior with `subprocess`
- use `tmp_path` for temporary test files

These are the kinds of habits that make Python useful in DevOps automation.

## Final Thoughts

This log parser combines Python fundamentals with practical operational concerns. It touches file parsing, dictionaries, counters, CLI arguments, error handling, JSON output, and automated tests.

The main goal is not just making the script work. It is making it reusable, testable, and safe to run from the command line.
