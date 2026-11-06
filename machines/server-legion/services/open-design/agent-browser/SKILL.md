---
name: agent-browser
description: Check web pages with the local Linux Chromium browser.
allowed-tools: Bash(agent-browser:*)
---

# Local Linux browser

Use this workflow instead of macOS, Electron or packaged renderer instructions.
The launcher sets OD_BROWSER_CDP_URL and AGENT_BROWSER_SESSION for this run.
If either is missing, report that the browser is unavailable. Do not start a
second browser, guess a port or use another run's session.

Pass the endpoint on every command. Open a working project preview URL, then
inspect its current elements before acting:

```sh
agent-browser --cdp "$OD_BROWSER_CDP_URL" open "$preview_url"
agent-browser --cdp "$OD_BROWSER_CDP_URL" snapshot -i
agent-browser --cdp "$OD_BROWSER_CDP_URL" click @e1
agent-browser --cdp "$OD_BROWSER_CDP_URL" screenshot ./checks/desktop.png
```

Get fresh element references after navigation or layout changes. Use the
installed CLI's help rather than guessing commands. Prefer OpenDesign's local
artifact preview. If a project needs its own server, bind it to loopback, serve
only that project and stop its recorded PID when finished. Never serve `/state`,
Pi's home or a parent directory. Do not copy SSO cookies or use the public URL.

Check responsive pages at desktop and mobile widths, such as 1440 and 390 pixels.
Use the intended canvas for slides. Test the main interaction and relevant
console errors. Save screenshots inside the project and read them with Pi's read
tool before judging pixels. Text-only models must report that limitation rather
than change providers. Fix observed defects and recheck the changed output.
Distinguish visual inspection from DOM checks and anything left untested.

Browser profiles may reset between turns. Project files and screenshots persist.
