# Code explanation latency measurements

Measured on 2026-11-05 using the currently configured Responses API provider.
These are local observations, not guarantees for another provider, workload, or time.

## Method

Every run used the same randomID function below and the same English teaching
instructions requesting 250-350 words. Runs were sequential, with framework and
model variants interleaved. Timings include child-process startup and network time.
No model tools were enabled for the API, Pi, or Agents SDK variants. Codex was
instructed not to use tools. SDK tracing was disabled. SDK proxy inheritance was
disabled to match the direct HTTP connection used by the other clients.

The first visible text is the first answer delta for streaming clients. The old
Codex integration reads the final answer file, so its first visible text equals
completion. Medians below count only completed requests; sample sizes are shown.

| Client | Model | Effort | Runs | First text median (s) | Complete median (s) | Words |
| --- | --- | --- | ---: | ---: | ---: | --- |
| codex | gpt-6.1-sol | xhigh | 1 | 57.33 | 57.33 | 311-311 |
| codex | gpt-6.1-sol | low | 1 | 21.90 | 21.90 | 331-331 |
| direct | gpt-6.1-sol | low | 2 | 5.53 | 18.29 | 320-336 |
| pi | gpt-6.1-sol | low | 2 | 5.45 | 15.24 | 304-321 |
| direct | gpt-6.1-terra | low | 3 | 5.13 | 12.17 | 287-311 |
| pi | gpt-6.1-terra | low | 3 | 5.21 | 12.21 | 294-307 |
| agents | gpt-6.1-terra | low | 3 | 2.99 | 11.42 | 282-314 |
| direct | gpt-6.1-terra | none | 3 | 3.02 | 10.56 | 298-310 |
| direct | gpt-5.6-luna | low | 3 | 4.43 | 14.94 | 331-357 |

## Decision

The initial selection was the standard-library Python Responses client,
gpt-6.1-terra, effort none, and incremental Markdown display. This had the lowest median completion time
among the repeated configurations tested, with first text comparable to the
Agents SDK result (3.02 versus 2.99 seconds). At equal low effort,
direct, Pi, and Python Agents SDK results were close enough that these small
samples do not establish a general framework speed ranking. The direct path
also requires no installed agent framework.

The selected configuration produced first text in 1.76-6.10 seconds across
three runs. Provider queueing and output length still affect latency. The old
Codex baseline loaded 21,867 input tokens; the direct requests used 118 input
tokens for this controlled case. Cached input and reasoning tokens differ too,
so that comparison measures the entire integration, not only process startup.

Answers were checked for 32 bytes, 64 hexadecimal characters, panic/error
handling, and the missing rand import assumption. Literal keyword checks were
used as a screening aid, not as proof of full correctness. Saved answers for the
selected profile were reviewed for those facts. Broader model quality is not
established by this one function.

The provider listed gpt-5.4-mini and gpt-5.3-codex-spark but rejected their
requests with HTTP 400. gpt-6.1-sol also rejected effort none. Initial SDK runs
failed before inference because an inherited SOCKS proxy required an optional
dependency; the successful SDK measurements use a direct connection. A separate
Pi effort off trial is excluded from the equal-effort comparison.

Versions: Codex CLI 0.164.0; Python 3.13.5; Node 22.22.0;
@earendil-works/pi-agent-core 1.5.0; openai-agents 0.24.0;
OpenAI Python SDK 3.46.0 for the Agents SDK variant.

## Actual Neovim integration

Separate live checks used the production prompt, helper, and split with
gpt-6.1-terra / none. These are individual observations, not medians.

| Request | First text in Markdown (s) | Complete (s) |
| --- | ---: | ---: |
| randomID explanation | 3.34 | 11.46 |
| One-sentence follow-up about bit length | 1.89 | 2.35 |
| Session.Resolve explanation with its types | 9.47 | 19.04 |

The first Markdown update followed the first helper output by about 0.10 seconds
in all three checks. All answers were English, and the follow-up correctly
distinguished 256 bits from 64 hexadecimal characters. The session explanation
correctly described the exact expiration boundary and any non-nil revocation
timestamp. An earlier randomID request took 21.83 seconds to first text, so
the controlled-case median must not be interpreted as a latency guarantee.

## xhigh and Fast follow-up (2026-11-06)

At the owner's request, the default effort changed to `xhigh` and requests now
explicitly set `service_tier: "fast"`. These sequential single-run checks used
the same randomID snapshot and production English teaching instructions.

| Effort | Requested tier | Returned tier | First text (s) | Complete (s) | Reasoning tokens |
| --- | --- | --- | ---: | ---: | ---: |
| none | omitted | default | 6.54 | 15.45 | 0 |
| xhigh | fast | default | 2.47 | 6.39 | 87 |
| none | fast | default | 2.94 | 7.15 | 0 |
| xhigh | omitted | default | 8.26 | 16.68 | 223 |
| xhigh | priority | default | 7.60 | 12.48 | 147 |

The response confirmed `reasoning.effort: "xhigh"`, but every response reported
`service_tier: "default"`. The provider accepted both Fast request spellings;
actual Fast processing was not confirmed. These small samples cannot establish
a speedup from Fast or a general speed ranking between efforts. The plugin now
records the requested and returned tiers so that an accepted parameter is not
mistaken for confirmed Fast processing.

An actual Neovim request with the updated default displayed English text in
6.09 seconds and completed in 9.15 seconds. Its Markdown recorded the requested
`fast` tier and returned `default` tier correctly.

[OpenAI Docs for Terra](https://developers.openai.com/api/docs/models/gpt-6.1-terra)
list `xhigh` support and Fast pricing at twice Standard. The
[Fast mode guide](https://developers.openai.com/api/docs/guides/priority-processing)
documents `fast` and `priority` as equivalent request values and the returned
tier as the processing mode used. The configured provider's actual rates were
not independently verified. Reasoning tokens can increase total billed output.

## Input

After reviewing the sample answers, the owner selected `none` again and asked
to remove the extra explanation heading and model/service tier information
from new records. The current default is therefore `gpt-6.1-terra / none`, with
Fast still requested. The measurements and tier observations above describe
the versions tested at that time.

```go
func randomID() string {
    b := make([]byte, 32)
    if _, e := rand.Read(b); e != nil {
        panic(e)
    }
    return hex.EncodeToString(b)
}
```

The controlled benchmark used these instructions:

```text
Explain the selected Go function in English for a learner, in 250-350 words. Cover purpose, declaration and syntax, each statement, returned value and length, errors, and assumptions. Be precise: the rand import is not shown. Use readable Markdown and no progress logs. Do not use tools or inspect files.
```
