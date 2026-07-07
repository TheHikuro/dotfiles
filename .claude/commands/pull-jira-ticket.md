Fetch a Jira ticket and print its summary, decoded description, and decoded comments as readable markdown.

Usage: /pull-jira-ticket [TICKET-KEY]
  - TICKET-KEY is case-sensitive, e.g. VS-27154
  - If no key is given, ask the user for one

Steps:
1. Run: `python3 /Users/loancleris/.claude/commands/scripts/pull-jira-ticket.py <TICKET-KEY>`
2. The script prints the issue (summary, type, status, priority, reporter, assignee, dates),
   the description, and all comments — Jira's Atlassian Document Format (ADF) is decoded
   to plain markdown (headings, bold/italic/code marks, bullet/ordered/task lists, links,
   code blocks) so it's directly readable, no raw ADF JSON.
3. Read the output back to the user, or use it as context for the next step (e.g. checking
   acceptance criteria against code changes).

Applying the ticket (don't skip this):
  Most tickets ask for something that's a variation of a pattern already used elsewhere in
  the target codebase (a form field, a modal, a list column, an API route shape). Before
  writing any new code:
  1. Identify the kind of thing being asked for.
  2. Grep the codebase for an existing instance of that kind (similar component/hook names,
     a sibling screen that already does something close to this).
  3. If a match exists, follow its pattern instead of building a second way to do the same
     thing. If not, implement fresh, following the project's normal file-placement rules.
  4. Before calling the ticket done, re-check its Acceptance Criteria list (or comments, if
     AC lives there) item by item against what was actually implemented.

Gotchas:
  - A ticket's description can reference files/tooling from the wrong base branch (e.g. a
    branch cut from a stale `main` instead of `develop`). If a referenced file doesn't exist,
    check whether the branch is missing commits from the main development branch before
    assuming the ticket itself is wrong.

Options:
  --json   Print the raw issue + comments payloads as JSON instead of rendered markdown
           (useful if you need fields beyond what the renderer prints).

Auth: reuses jiratui's own config — jira_api_base_url / jira_api_username from
~/.config/jiratui/config.yaml, and the JIRA_API_TOKEN environment variable (macOS Keychain).
If pull-jira-ticket.py errors on missing config/token, run `jiratui config` first to confirm
jiratui itself is set up.

To extend: the ADF → markdown conversion lives in `adf_to_text()` in the script. Add a branch
there for any node type (e.g. `table`) that currently falls through to plain concatenation.
