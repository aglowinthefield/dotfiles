# User Preferences

## Shell compatibility
- The user uses fish. Default to fish-compatible commands, terminal examples, and interactive shell snippets across projects, even when the tool execution shell is zsh or Bash.
- Use fish syntax for variables, command substitutions, loops, conditionals, and functions in snippets intended for the user to paste; avoid POSIX/Bash-only syntax and heredocs.
- When another interpreter is required, provide a fish-compatible invocation and clearly identify that interpreter.
- Preserve existing script shebangs and repository-required languages (for example, POSIX sh); this preference does not require converting project scripts to fish.
- Match commands executed by tools to the tool's actual shell, or explicitly invoke fish when validating fish snippets.
