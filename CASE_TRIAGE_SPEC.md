# Automatic Jev Case Triage

**Status:** Initial implementation brief  
**Workshop:** ClaudeForce, Nov 26, 2026  
**Linear project:** [Nov 26 CS](https://linear.app/divings/project/nov-26-cs-80d85a67d354)  
**Linear Epic:** [DIV-72: Automatic Jev Case Triage and Salesforce Actions](https://linear.app/divings/issue/DIV-72/epic-automatic-jev-case-triage-and-salesforce-actions)

## Goal

When an eligible Salesforce Case is created, start Jev triage automatically as soon as the Case save commits. Do not require a button, user action, or synchronous external callout. Salesforce automation owns every Case update, routing decision, notification, retry, and review path. Jev provides structured recommendations only.

The solution is implemented in a separate implementation repository/org using Claude Code, then packaged and configured in the Nov 26 demo org. This repository is a specification starter only; it is not the implementation repository.

## User Outcome

- Case creation is not delayed or failed by Jev availability.
- Newly created eligible Cases are triaged in the background without manual intervention.
- Clear supported Cases are assigned to the configured Salesforce queue and receive approved triage field updates.
- Ambiguous, unsupported, security-sensitive, or failed triage is surfaced for human review rather than silently guessed.
- The Case record shows whether triage is pending, completed, or needs review.

## Decision And Action Boundary

**Jev decides:**
- Which supported Case category best fits the supplied Case context.
- The Case impact level according to an approved descriptive rubric.
- Whether the Case fits any supported category at all.
- Probabilities/confidence for its bounded recommendations.

**Salesforce decides and acts:**
- Whether confidence/probability thresholds permit automation.
- How category and impact map to Salesforce fields and queues.
- Whether a Case goes to a human-review queue.
- All Case DML, assignment, notifications, retries, audit status, and downstream automation.

Do not ask Jev to generate a narrative summary, customer response, Salesforce record ID, queue ID, or executable action. Jev is a structured-decision model, not a text generator or action agent. Typed output guarantees shape, not semantic correctness.

## Proposed End-To-End Flow

1. An after-insert Case automation identifies eligible records and marks/dispatches them for triage.
2. A post-commit asynchronous worker processes the Case. The Case insert transaction must not wait on Jev and must succeed if Jev is unavailable.
3. The worker reloads the required Case fields and sends only the minimum context needed for classification. Avoid sending Salesforce IDs, unrelated record data, attachments, or personal/sensitive data unless explicitly approved.
4. One Jev System One request asks several narrow questions about the Case: a `Choice` for category, a `Score` for impact, and a companion `Noul` for whether any supported category applies.
5. Salesforce validates the HTTP status, response structure, expected question IDs and types, allowed values, and numeric probability ranges. A Choice always selects one option, so never use it without checking the companion no-match question.
6. Salesforce applies versioned/configurable thresholds. A supported, sufficiently certain result maps to allowed Case fields and a configured queue. Uncertainty, no-match, security/privacy signals, invalid responses, and exhausted retries go to human review.
7. Salesforce updates triage status and assignment. That update must not retrigger a second triage run.

### Asynchronous Architecture To Validate

Preferred starting point: a bulk-safe after-insert dispatcher enqueues a Queueable worker implementing `Database.AllowsCallouts`. The worker should perform callouts before DML, collect decisions, then update Cases in bulk. Respect Salesforce's per-transaction callout and queueable limits; process a bounded chunk and chain or otherwise schedule remaining IDs without dropping work. Confirm the final trigger/Flow/Queueable arrangement in the implementation org before coding.

Never perform an HTTP callout synchronously from the Case insert/DML transaction. A Platform Event or another post-commit pattern is acceptable if it preserves the same acceptance criteria and is easier to recover operationally.

## Jev Request Contract

- Endpoint: `POST https://api.typesafe.ai/v1/systemone`
- Authentication: bearer API key stored in Salesforce Named Credential/External Credential configuration; never put the key in this repository, source, Flow metadata, test fixtures, or logs.
- Model: use an account-available pinned model version for reproducible evaluation; record the actual returned model version. Avoid silently relying on a moving alias for a measured demo.
- State: minimum approved Case fields only, such as subject, description, origin, and product/category context when needed. Data fields are subject to privacy review.
- Questions:
  - `Choice`: category from a finite, approved list with concise, mutually distinguishable criteria.
  - `Score`: impact against concrete descriptions (e.g. routine, degraded with workaround, blocking/no workaround, critical/security-sensitive). Keep scoring semantics separate from arithmetic or policy logic.
  - `Noul`: whether any supported category applies, to prevent forced routing for out-of-scope Cases.
- Response: typed answers, probabilities/confidence, model version, and usage. Never treat a high confidence score as proof that the answer is correct.

### Initial Category Candidates

These are a starting point for product-owner review, not final approved taxonomy:

- `access`: login, permissions, or account access
- `billing`: charges, invoices, or payments
- `product_issue`: product malfunction or defect
- `integration`: API, connectivity, or integration failure
- `how_to`: product usage question
- `other`: supported-case residual, if the team approves it

The taxonomy must be revised against actual support ownership and queue names before implementation. Prefer a companion Noul for “none of the supported categories applies” rather than relying on `other` as the only catch-all.

## Salesforce State And Mapping

Proposed triage state values: `Pending`, `Completed`, `Review Required`, and `Failed`. Confirm API names and whether retry state needs a separate value in the implementation org.

The implementation must define and document:
- Case category and impact fields, including accepted picklist/API values.
- Category-to-queue mapping using portable configuration, not hard-coded org-specific IDs.
- Thresholds for each automated route, selected against labeled evaluation data.
- A human-review queue and review reason for low certainty, unsupported category, security/privacy concerns, malformed response, and final service failure.
- Whether a Case with missing subject/description is sent to review without a Jev call.

Never overwrite a non-empty human-entered value unless the business owner explicitly approves that behavior. Preserve the selected option and relevant probability/triage metadata needed to explain why an automated route occurred, without storing unnecessary customer text.

## Reliability, Security, And Privacy

- Use an async process with durable status and bounded retry behavior. Retry only transient network failures and documented transient responses such as `429`/`529`, using bounded backoff. Do not loop indefinitely.
- A Jev timeout, authentication/configuration problem, permanent client error, invalid response, or exhausted retry must not block Case creation; mark the Case for review and retain a diagnostic reason that contains no secret or unnecessary customer content.
- Make processing idempotent. Guard against duplicate enqueue, triage-result updates retriggering the worker, and replaying already completed Cases.
- For bulk inserts, process within Salesforce callout/job limits and have a tested continuation strategy for more work than a single job can handle.
- Keep the TypeSafe key in a Named Credential/External Credential. Do not commit credentials. Rotate any API key previously pasted into chat or a config file; do not reuse it.
- Send only the minimum context required. Use synthetic Cases for this workshop. Review TypeSafe's current data processing terms, subprocessors, retention, residency, and required commercial approvals before using real customer data.
- Jev documents known weaknesses including adversarial content, irrelevant context, literal interpretation, option-order sensitivity, and poor numeric/date reasoning. Keep deterministic calculations in code and test prompt-injection-like Case text.

## Evaluation And Test Plan

Create a labeled, synthetic evaluation set and agree on expected answers before tuning thresholds. Keep a holdout subset separate from the examples used to write criteria. Report per-category precision/recall or equivalent error counts, false auto-routes, human-review rate, Jev latency, API failure rate, and estimated usage cost. Do not present TypeSafe vendor claims or a few hand-picked examples as proof of production accuracy.

Required scenarios:

1. Clear supported Case for each category routes to the expected Salesforce queue and field values.
2. Mixed-category Case stays in review or follows the explicitly approved multi-category policy.
3. Out-of-scope Case is not force-routed by a Choice result.
4. Low-probability/low-confidence Case goes to human review.
5. Critical, security, or privacy-sensitive Case follows the conservative review policy.
6. Missing or insufficient Case context does not produce a confident fabricated route.
7. Prompt-injection-like or adversarial description does not grant the model authority to act; Salesforce policy still gates all side effects.
8. Existing human-entered triage fields are preserved.
9. Jev 401/configuration error, 422 invalid request, 429/529 throttling/overload, timeout, 5xx, malformed response, and exhausted retry reach the defined recovery/review path.
10. Bulk Case insert (including 200 records) creates every Case, processes records within limits, and does not enqueue duplicates or recursively re-triage updated Cases.
11. Replaying a successful or failed job is idempotent and does not duplicate actions.

Apex tests should use `HttpCalloutMock` and test dispatch/worker behavior without a real TypeSafe key. Include an authorized-org integration test for Named Credential setup and end-to-end behavior in the demo org.

## Definition Of Done

- Creating an eligible Case automatically starts post-commit asynchronous Jev triage; there is no button or manual invocation.
- Case creation remains successful and responsive when the external service is slow or unavailable.
- Salesforce applies only validated, threshold-approved recommendations; all other cases have a visible human-review path.
- Bulk, idempotency, recursion, security, and failure-path tests pass.
- The labeled evaluation set supports the chosen thresholds and documents known limitations.
- The package is installed/configured and verified in the Nov 26 demo org using synthetic data, with a runbook and service-unavailable fallback.

## Related Linear Issues

- [DIV-78: Define Case triage taxonomy and Jev evaluation set](https://linear.app/divings/issue/DIV-78/define-case-triage-taxonomy-and-jev-evaluation-set)
- [DIV-75: Add Case triage fields and routing configuration](https://linear.app/divings/issue/DIV-75/add-case-triage-fields-and-routing-configuration)
- [DIV-73: Implement secure Apex client for TypeSafe Jev](https://linear.app/divings/issue/DIV-73/implement-secure-apex-client-for-typesafe-jev)
- [DIV-74: Trigger bulk-safe asynchronous triage on Case creation](https://linear.app/divings/issue/DIV-74/trigger-bulk-safe-asynchronous-triage-on-case-creation)
- [DIV-77: Apply Jev decisions with Salesforce routing and review fallbacks](https://linear.app/divings/issue/DIV-77/apply-jev-decisions-with-salesforce-routing-and-review-fallbacks)
- [DIV-76: Evaluate and package Case triage for the Nov 26 demo org](https://linear.app/divings/issue/DIV-76/evaluate-and-package-case-triage-for-the-nov-26-demo-org)

## References

- TypeSafe, [Introducing System One Models and Jev](https://typesafe.ai/blog/introducing-system-one-models-and-jev)
- TypeSafe, [API Quick Start](https://docs.typesafe.ai/introduction/quickstart.md)
- TypeSafe, [Choice](https://docs.typesafe.ai/primitives/choice.md), [Noul](https://docs.typesafe.ai/primitives/noul.md), and [Score](https://docs.typesafe.ai/primitives/score.md)
- TypeSafe, [Companion Noul](https://docs.typesafe.ai/patterns/companion-noul.md), [Confidence](https://docs.typesafe.ai/confidence.md), and [Model Jaggedness](https://docs.typesafe.ai/model-jaggedness.md)
- TypeSafe, [Request rules and errors](https://docs.typesafe.ai/api/errors.md) and [Data Processing Addendum](https://typesafe.ai/legal/data-processing)
- Salesforce, [Named Credentials](https://developer.salesforce.com/docs/platform/named-credentials/guide/get-started)