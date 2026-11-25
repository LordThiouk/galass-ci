# Galass state of play before the fix FullRun. Read-only on the code; a single report. Commit right away.

Forbidden: push, `gh`, editing any code, editing anything other than `GALASS-STATE.md`. Author: `Papa Diop <76528706+LordThiouk@users.noreply.github.com>`.

Repos available (extra_repos): Galass_Rider, Galass_Driver, Galass_backend, galass-emu-actions-pub, plus this repo (galass-ci). Cover the latest work in ALL of them.
1. In Galass_Rider: the last 15 commits across all branches (`git fetch origin '+refs/heads/*:refs/remotes/origin/*'`, `git log --all -15`), the open branches and what each one changes. List the UI screens/points still to fix (TODO, review notes in docs, failing tests, unchecked ISC).
2. Find the Rider multistop ISA file (under the ISAs folder): which ISCs are checked and which are not, and what blocks closure. Note the golden capture system (golden screenshots / L2 pixel proof, ISC-F4-10, Bridge-B3): where it lives, how it runs, what is missing to validate.
3. For every other repo: last 10 commits across all branches, open branches, and what remains unfinished.
4. Write `GALASS-STATE.md` (60 lines max): (a) the UI fixes to make, with file:line; (b) the ISCs remaining for multistop and the needed proof; (c) the golden capture state; (d) an ordered list of tasks for a fix FullRun. Commit with the message "docs: état galass avant fullrun". Stop.
