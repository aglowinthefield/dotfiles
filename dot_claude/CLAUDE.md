# User Preferences

## Less code

- Prefer the change that leaves less code to maintain: reuse an existing seam, delete dead or
  superseded paths, and justify every new file, abstraction, option, or dependency. A diff that
  removes more than it adds is a good sign. "Less" means fewer concepts to maintain, not line-count
  golf or cramming logic into one place.
- Do not add speculative generality: no config knobs, extension points, or modes the task doesn't
  need.

## ClearStack
- Apply the `clear-mode` skill to every non-trivial engineering task. Repo instructions still win where they are stricter.
