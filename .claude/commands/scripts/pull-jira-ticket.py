#!/usr/bin/env python3
"""Fetch a Jira ticket (description + comments) and print it as readable markdown.

Auth/config is reused from jiratui (~/.config/jiratui/config.yaml for base URL
and username, JIRA_API_TOKEN env var for the token - same as jiratui itself).

Usage:
    pull-jira-ticket.py VS-27154
    pull-jira-ticket.py VS-27154 --json
"""
import base64
import json
import os
import sys
import urllib.error
import urllib.request

CONFIG_PATH = os.path.expanduser("~/.config/jiratui/config.yaml")


def load_config():
    base_url = None
    username = None
    with open(CONFIG_PATH) as f:
        for line in f:
            line = line.strip()
            if line.startswith("jira_api_base_url:"):
                base_url = line.split(":", 1)[1].strip().strip('"')
            elif line.startswith("jira_api_username:"):
                username = line.split(":", 1)[1].strip().strip('"')
    token = os.environ.get("JIRA_API_TOKEN")
    if not base_url or not username:
        sys.exit(f"error: could not read jira_api_base_url/jira_api_username from {CONFIG_PATH}")
    if not token:
        sys.exit("error: JIRA_API_TOKEN is not set in the environment")
    return base_url, username, token


def api_get(base_url, username, token, path):
    auth = base64.b64encode(f"{username}:{token}".encode()).decode()
    req = urllib.request.Request(
        f"{base_url}{path}",
        headers={"Authorization": f"Basic {auth}", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        sys.exit(f"error: {e.code} {e.reason} for {path}\n{e.read().decode(errors='replace')}")


def adf_to_text(node):
    """Recursively flatten an Atlassian Document Format node tree to markdown-ish text."""
    if node is None:
        return ""
    node_type = node.get("type")
    content = node.get("content", [])

    if node_type == "text":
        text = node.get("text", "")
        for mark in node.get("marks", []):
            if mark.get("type") == "code":
                text = f"`{text}`"
            elif mark.get("type") == "strong":
                text = f"**{text}**"
            elif mark.get("type") == "em":
                text = f"*{text}*"
            elif mark.get("type") == "link":
                href = mark.get("attrs", {}).get("href", "")
                text = f"[{text}]({href})"
        return text

    if node_type == "hardBreak":
        return "\n"

    inline = "".join(adf_to_text(c) for c in content)

    if node_type == "paragraph":
        return inline + "\n"
    if node_type == "heading":
        level = node.get("attrs", {}).get("level", 1)
        return f"\n{'#' * level} {inline}\n"
    if node_type == "codeBlock":
        return f"\n```\n{inline}\n```\n"
    if node_type == "blockquote":
        return "\n".join(f"> {line}" for line in inline.splitlines()) + "\n"
    if node_type == "bulletList":
        return "".join(f"- {adf_to_text(item).strip()}\n" for item in content)
    if node_type == "orderedList":
        return "".join(f"{i}. {adf_to_text(item).strip()}\n" for i, item in enumerate(content, 1))
    if node_type == "listItem":
        return inline
    if node_type == "taskList":
        return "".join(f"- {adf_to_text(item).strip()}\n" for item in content)
    if node_type == "taskItem":
        state = node.get("attrs", {}).get("state", "TODO")
        box = "[x]" if state == "DONE" else "[ ]"
        return f"{box} {inline}"
    if node_type == "rule":
        return "\n---\n"
    if node_type == "mediaSingle" or node_type == "media":
        return "[attachment]\n"

    # doc, table, and anything unhandled: just concatenate children
    return inline


def render_issue(issue):
    fields = issue["fields"]
    key = issue["key"]
    lines = [
        f"# {key}: {fields.get('summary', '')}",
        "",
        f"- Type: {fields.get('issuetype', {}).get('name', '?')}",
        f"- Status: {fields.get('status', {}).get('name', '?')}",
        f"- Priority: {(fields.get('priority') or {}).get('name', '?')}",
        f"- Reporter: {(fields.get('reporter') or {}).get('displayName', '?')}",
        f"- Assignee: {(fields.get('assignee') or {}).get('displayName', 'Unassigned')}",
        f"- Created: {fields.get('created', '?')}",
        f"- Updated: {fields.get('updated', '?')}",
        "",
        "## Description",
        "",
        adf_to_text(fields.get("description")).strip() or "_(no description)_",
    ]
    return "\n".join(lines)


def render_comments(comments_payload):
    comments = comments_payload.get("comments", [])
    if not comments:
        return "## Comments\n\n_(no comments)_"
    lines = ["## Comments", ""]
    for c in comments:
        author = (c.get("author") or {}).get("displayName", "?")
        created = c.get("created", "?")
        body = adf_to_text(c.get("body")).strip()
        lines.append(f"### {author} — {created}")
        lines.append("")
        lines.append(body)
        lines.append("")
    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        sys.exit(f"usage: {sys.argv[0]} <TICKET-KEY> [--json]")
    ticket_key = sys.argv[1]
    as_json = "--json" in sys.argv[2:]

    base_url, username, token = load_config()
    issue = api_get(
        base_url,
        username,
        token,
        f"/rest/api/3/issue/{ticket_key}"
        "?fields=summary,description,status,assignee,reporter,issuetype,created,updated,priority",
    )
    comments = api_get(base_url, username, token, f"/rest/api/3/issue/{ticket_key}/comment")

    if as_json:
        print(json.dumps({"issue": issue, "comments": comments}, indent=2))
        return

    print(render_issue(issue))
    print()
    print(render_comments(comments))


if __name__ == "__main__":
    main()
