# User Preferences

## Shell compatibility
- The user uses fish. Default to fish-compatible commands, terminal examples, and interactive shell snippets across projects, even when the tool execution shell is zsh or Bash.
- Use fish syntax for variables, command substitutions, loops, conditionals, and functions in snippets intended for the user to paste; avoid POSIX/Bash-only syntax and heredocs.
- When another interpreter is required, provide a fish-compatible invocation and clearly identify that interpreter.
- Preserve existing script shebangs and repository-required languages (for example, POSIX sh); this preference does not require converting project scripts to fish.
- Match commands executed by tools to the tool's actual shell, or explicitly invoke fish when validating fish snippets.

## Less code
- Prefer the change that leaves less code to maintain: reuse an existing seam, delete dead or superseded paths, and justify every new file, abstraction, option, or dependency. A diff that removes more than it adds is a good sign. "Less" means fewer concepts to maintain, not line-count golf or cramming logic into one place.
- Do not add speculative generality: no config knobs, extension points, or modes the task doesn't need.

## ClearStack
- Apply the `clear-mode` skill to every non-trivial engineering task. Repo instructions still win where they are stricter.
