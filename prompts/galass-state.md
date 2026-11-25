# Galass state of play before the fix FullRun, read from the MULTISTOP branches (not main). Read-only on code; one report. Commit right away.

Forbidden: push, editing any code, editing anything other than `GALASS-STATE.md`, `gh` write commands. Allowed `gh`: `gh auth setup-git`, `gh api` GET, `gh repo view`. Author: `Papa Diop <76528706+LordThiouk@users.noreply.github.com>`.

The real work is on each repo's multistop branch, NOT on main. Repos (extra_repos): Galass_Rider, Galass_Driver, Galass_backend, galass-emu-actions-pub, plus this repo (galass-ci).
0. First run `gh auth setup-git`. In each repo: `git fetch --unshallow || true`, then `git fetch origin '+refs/heads/*:refs/remotes/origin/*'`. If fetch still fails, list branches with `gh api repos/LordThiouk/<repo>/branches --paginate -q '.[].name'` and fetch the multistop branch by name. Find the multistop branch (name contains "multi" or "stop"; if several, the most recent). Check it out. If a repo has none, say so in one line.
1. On each multistop branch: last 15 commits, diff summary vs main (`git diff --stat origin/main...HEAD | tail -5`), what was done and what is unfinished.
2. Rider multistop: list the UI screens/points still to fix (TODO, review notes in docs, failing tests, unchecked ISC), with file:line taken from the multistop branch.
3. Find the multistop ISA file on the multistop branch (under the ISAs folder): ISCs checked or not, what blocks closure. Golden capture system (golden screenshots / L2 pixel proof, ISC-F4-10, Bridge-B3): where it lives, how it runs, what is missing.
4. Write `GALASS-STATE.md` (70 lines max): first line per repo = branch name + head commit sha; then (a) UI fixes with file:line; (b) multistop ISCs remaining + needed proof; (c) golden capture state; (d) ordered task list for a fix FullRun, each task naming its repo and branch. Commit "docs: état galass branches multistop". Stop.
