# TeXiFiEd

[TeXiFiEd](https://texified.org/) is a new, modern LaTeX pastebin.

It (currently) uses MathJax and the Haskell Scotty framework, with a focus on
being fast and simple.

In the future, we might offer the download of pastes in other formats (we're
already using Haskell, why not take advantage of Pandoc while we're at it?)

## Setting up

- `cabal install dbm`
- `git clone git://github.com/relrod/texified.org && cd texified.org`
- `vim sql/.dbm # change your database path`
- `cp src/TexifiedConfig.hs.example src/TexifiedConfig.hs`
- `vim src/TexifiedConfig.hs # change your database path and captcha secret`
- `dbm migrate development`
- `cabal run`

# License

BSD-3
