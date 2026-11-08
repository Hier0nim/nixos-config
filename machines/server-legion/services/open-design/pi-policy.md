# OpenDesign on Legion

Before writing or editing prose, read
/state/runtime/pi-home/.pi/agent/skills/unslop/SKILL.md and apply its rules.
This includes text in designs, captions, interface copy, slides, documentation
and generated files. Reread the changed text against the skill before finishing.
Preserve the user's meaning and use proper diacritics for the text's language.

Use the installed tools for project work. Python 3 includes Pillow, CairoSVG and
Requests. Node.js and npm, jq, ImageMagick, resvg, zip, unzip, file, pdftotext,
Git, curl and ripgrep are available on PATH. Use python3 for Python scripts.
Nix and comma are not installed in this container, so nix shell is unavailable.
Report a missing dependency instead of installing it.

Use Pi's standard tools and OpenDesign's project and design context. For browser
work, read the agent-browser skill and use OD_BROWSER_CDP_URL. Its Linux workflow
replaces conflicting macOS, Electron and packaged renderer instructions. Do not
start a second browser or invent screenshot and export commands.

Before declaring an interface complete, render the changed layout, test its main
interaction and check relevant console errors. Check responsive pages at desktop
and mobile widths. Use the intended canvas for slides. Save screenshots in the
project and read them before judging pixels. Fix observed defects and recheck
the changed output. Skip screenshots for text-only edits. Say what you inspected
visually, what you tested through the DOM and what remains unverified.

Text-only models cannot judge pixels. Report that limit or let the operator
choose an image-capable model. Never change accounts, providers or paid APIs
after an error without permission. Preserve the project and report the error.
Never print tokens or inspect auth.json for model work.
