---
title: "Building a Python Command Runner for DevOps Workflows"
date: 2026-05-24
draft: false
description: "Build a Python CLI that runs shell commands with timeout handling, clean error output, JSON reporting, and pytest coverage."
tags:
  - python
  - devops
  - cli
  - subprocess
  - pytest
categories:
  - DevOps
  - Python
---

Running shell commands is a common part of DevOps automation. Python becomes useful when a script needs to run external tools, capture their output, enforce timeouts, handle errors consistently, and optionally produce structured output for other systems.

This post walks through a small Python command runner that wraps shell commands with predictable behavior.

Source code: [github.com/sreevamsiy/devops-python-toolkit/tree/main/command-runner](https://github.com/sreevamsiy/devops-python-toolkit/tree/main/command-runner)

## The Goal

Build a CLI that can run a shell command and report the result cleanly.

Example usage:

```bash
python3 command_runner.py "echo hello"
python3 command_runner.py "ls missing-file"
python3 command_runner.py "sleep 5" --timeout 1
python3 command_runner.py "echo hello" --json
```

The tool should handle:

- command success
- command failure
- timeout
- invalid timeout input
- human-readable output
- JSON output
- correct exit codes

## Why Wrap Shell Commands?

For a single command, running it directly is usually simpler:

```bash
echo hello
```

A wrapper becomes useful when automation needs consistent behavior around the command:

- capture `stdout` and `stderr`
- inspect the return code
- fail cleanly on timeout
- convert results into JSON
- reuse the same command-running logic across scripts

This is useful when wrapping tools such as `kubectl`, `docker`, `terraform`, `aws`, `curl`, or `systemctl`.

## Running Commands With `subprocess`

The core of the tool is `subprocess.run()`.

```python
result = subprocess.run(
    command,
    shell=True,
    capture_output=True,
    text=True,
    timeout=timeout,
)
```

The important options are:

- `shell=True`: runs the command through the shell
- `capture_output=True`: captures both `stdout` and `stderr`
- `text=True`: returns strings instead of bytes
- `timeout=timeout`: stops commands that run too long

For this tool, the command is accepted as a single CLI string:

```bash
python3 command_runner.py "echo hello"
```

## Returning a Structured Result

The command runner returns a dictionary instead of printing directly from the function.

```python
def run_command(command, timeout):
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "stdout": "",
            "stderr": f"Error: command timed out after {timeout} seconds",
            "returncode": 124,
        }

    return {
        "success": result.returncode == 0,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
        "returncode": result.returncode,
    }
```

This makes the behavior easy to test and reuse.

Example success result:

```python
{
    "success": True,
    "stdout": "hello",
    "stderr": "",
    "returncode": 0,
}
```

Example failure result:

```python
{
    "success": False,
    "stdout": "",
    "stderr": "ls: missing-file: No such file or directory",
    "returncode": 1,
}
```

## Timeout Handling

Timeouts are handled with `subprocess.TimeoutExpired`.

```python
except subprocess.TimeoutExpired:
    return {
        "success": False,
        "stdout": "",
        "stderr": f"Error: command timed out after {timeout} seconds",
        "returncode": 124,
    }
```

The tool uses return code `124` for timeouts. That convention is commonly used by timeout-style command wrappers.

Example:

```bash
python3 command_runner.py "sleep 5" --timeout 1
```

Output:

```text
Error: command timed out after 1 seconds
```

Exit code:

```text
124
```

## Building the CLI

The CLI uses `argparse`.

```python
parser = argparse.ArgumentParser(description="Run shell commands with timeout handling")
parser.add_argument("command", help="Command to run")
parser.add_argument("--timeout", type=int, default=10, help="Timeout in seconds")
parser.add_argument("--json", action="store_true", help="Print output in JSON")
```

The command is positional:

```bash
python3 command_runner.py "echo hello"
```

The timeout is optional:

```bash
python3 command_runner.py "sleep 5" --timeout 1
```

## Validating Input

The timeout must be greater than zero.

```python
if args.timeout <= 0:
    print("Error: --timeout must be greater than 0", file=sys.stderr)
    sys.exit(1)
```

This prevents invalid calls such as:

```bash
python3 command_runner.py "echo hello" --timeout 0
```

Error output goes to `stderr`, and the tool exits with code `1`.

## Human-Readable Output

On success, the tool prints `stdout`.

```python
if result["success"]:
    if result["stdout"]:
        print(result["stdout"])
    sys.exit(0)
```

On failure, the tool prints `stderr` and exits with the command's return code.

```python
if result["stderr"]:
    print(result["stderr"], file=sys.stderr)
else:
    print(f"Error: command failed with exit code {result['returncode']}", file=sys.stderr)

sys.exit(result["returncode"])
```

This keeps the command runner aligned with normal CLI behavior:

- normal output goes to `stdout`
- errors go to `stderr`
- exit codes represent success or failure

## JSON Output

For automation, the `--json` flag prints the full structured result.

```python
if args.json:
    print(json.dumps(result, indent=2))
    sys.exit(result["returncode"])
```

Example:

```bash
python3 command_runner.py "echo hello" --json
```

Output:

```json
{
  "success": true,
  "stdout": "hello",
  "stderr": "",
  "returncode": 0
}
```

For a failed command:

```bash
python3 command_runner.py "ls missing-file" --json
```

Output:

```json
{
  "success": false,
  "stdout": "",
  "stderr": "ls: missing-file: No such file or directory",
  "returncode": 1
}
```

In JSON mode, the tool prints only JSON. It does not also print the normal human-readable output.

## Testing Function Behavior

The first tests call `run_command()` directly.

```python
def test_run_command_success():
    result = run_command("echo hello", 5)

    assert result["success"] is True
    assert result["stdout"] == "hello"
    assert result["stderr"] == ""
    assert result["returncode"] == 0
```

Failure behavior:

```python
def test_run_command_failure():
    result = run_command("ls missing-file", 5)

    assert result["success"] is False
    assert result["returncode"] != 0
    assert "missing-file" in result["stderr"]
```

Timeout behavior:

```python
def test_run_command_timeout():
    result = run_command("sleep 5", 1)

    assert result["success"] is False
    assert result["stderr"] == "Error: command timed out after 1 seconds"
    assert result["returncode"] == 124
```

These tests verify the reusable Python function without going through the CLI.

## Testing CLI Behavior

The CLI is tested with `subprocess.run()`.

```python
def test_cli_success():
    result = subprocess.run(
        [sys.executable, "command_runner.py", "echo hello"],
        capture_output=True,
        text=True,
        cwd=TOOL_DIR,
    )

    assert result.stderr == ""
    assert result.stdout.strip() == "hello"
    assert result.returncode == 0
```

`cwd=TOOL_DIR` ensures the test runs from the tool directory, even when pytest is launched from the repository root.

Invalid timeout:

```python
def test_cli_rejects_invalid_timeout():
    result = subprocess.run(
        [sys.executable, "command_runner.py", "echo hello", "--timeout", "0"],
        capture_output=True,
        text=True,
        cwd=TOOL_DIR,
    )

    assert result.returncode == 1
    assert "Error: --timeout must be greater than 0" in result.stderr
```

JSON output:

```python
def test_cli_json_success():
    result = subprocess.run(
        [sys.executable, "command_runner.py", "echo hello", "--json"],
        capture_output=True,
        text=True,
        cwd=TOOL_DIR,
    )

    data = json.loads(result.stdout)

    assert result.returncode == 0
    assert data["success"] is True
    assert data["stdout"] == "hello"
    assert data["stderr"] == ""
    assert data["returncode"] == 0
    assert result.stderr == ""
```

This checks the JSON structure instead of matching raw text.

## Final Test Result

The toolkit test suite now includes both the log parser and command runner tests:

```text
18 passed
```

The command runner tests cover:

- function success
- function failure
- function timeout
- CLI success
- CLI failure
- invalid timeout validation
- CLI timeout
- JSON success
- JSON failure

## Key Takeaways

This command runner demonstrates several useful DevOps Python patterns:

- use `subprocess.run()` to call external tools
- capture `stdout` and `stderr`
- preserve command return codes
- enforce timeouts
- validate CLI input
- write errors to `stderr`
- support JSON for automation
- separate reusable logic from CLI behavior
- test both functions and real CLI execution

The result is a small but practical wrapper that can become a building block for larger automation scripts.
