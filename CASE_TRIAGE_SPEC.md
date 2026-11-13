# Nov 26 CS Workshop: Build And Debug With Salesforce Skills

**Workshop:** ClaudeForce, Nov 26, 2026  
**Purpose:** Give developers two practical exercises: build a Jev-powered Case triage workflow, then diagnose and fix a seeded Mixed DML failure.  
**Implementation boundary:** Build and validate in the separate implementation org/repository using Claude Code, then package and configure the demo org. This repository is a workshop starter, not the implementation org. Use synthetic data only.

## Use Case 1: Automatic Jev Case Triage

### Goal

When an eligible Salesforce Case is created, start Jev triage automatically as soon as the Case save commits. Do not require a button, user action, or synchronous external callout. Salesforce automation owns every Case update, routing decision, notification, retry, and review path. Jev provides structured recommendations only.

### User outcome

- Case creation is not delayed or failed by Jev availability.
- Newly created eligible Cases are triaged in the background without manual intervention.
- Clear supported Cases are assigned to a configured Salesforce queue and receive approved triage field updates.
- Ambiguous, unsupported, security-sensitive, or failed triage is surfaced for human review rather than silently guessed.
- The Case record shows whether triage is pending, completed, or needs review.

### Decision and action boundary

**Jev decides:**
- Which supported Case category best fits the supplied Case context.
- The Case impact level according to an approved descriptive rubric.
- Whether the Case fits any supported category at all.
- Probabilities/confidence for its bounded recommendations.

**Salesforce decides and acts:**
- Whether probability/confidence thresholds permit automation.
- How category and impact map to Salesforce fields and queues.
- Whether a Case goes to a human-review queue.
- All Case DML, assignment, notifications, retries, audit status, and downstream automation.

Do not ask Jev to generate a narrative summary, customer response, Salesforce record ID, queue ID, or executable action. Jev is a structured-decision model, not a text generator or action agent. Typed output guarantees shape, not semantic correctness.

### Proposed flow

1. An after-insert Case automation identifies eligible records and dispatches them for triage.
2. A post-commit asynchronous worker processes each Case. The Case insert transaction must not wait on Jev and must succeed if Jev is unavailable.
3. The worker reloads the required Case fields and sends only the minimum context needed for classification. Avoid sending Salesforce IDs, unrelated record data, attachments, or personal/sensitive data unless explicitly approved.
4. One Jev System One request asks several narrow questions: a `Choice` for category, a `Score` for impact, and a companion `Noul` for whether any supported category applies.
5. Salesforce validates the HTTP status, response structure, expected question IDs and types, allowed values, and numeric probability ranges. A Choice always selects one option, so never use it without checking the companion no-match question.
6. Salesforce applies versioned/configurable thresholds. A supported, sufficiently certain result maps to allowed Case fields and a configured queue. Uncertainty, no-match, security/privacy signals, invalid responses, and exhausted retries go to human review.
7. Salesforce updates triage status and assignment. That update must not retrigger a second triage run.

### Asynchronous architecture to validate

Preferred starting point: a bulk-safe after-insert dispatcher enqueues a Queueable worker implementing `Database.AllowsCallouts`. The worker should perform callouts before DML, collect decisions, then update Cases in bulk. Respect Salesforce's per-transaction callout and queueable limits; process a bounded chunk and chain or otherwise schedule remaining IDs without dropping work. Confirm the final trigger/Flow/Queueable arrangement in the implementation org before coding.

Never perform an HTTP callout synchronously from the Case insert/DML transaction. A Platform Event or another post-commit pattern is acceptable if it preserves the same acceptance criteria and is easier to recover operationally.

### Jev request contract

- Endpoint: `POST https://api.typesafe.ai/v1/systemone`.
- Authentication: bearer API key stored in Salesforce Named Credential/External Credential configuration; never put the key in this repository, source, Flow metadata, test fixtures, or logs.
- Model: use an account-available pinned model version for reproducible evaluation and record the actual returned model version.
- State: minimum approved Case fields only, such as subject, description, origin, and product/category context when needed. Data fields are subject to privacy review.
- `Choice`: category from a finite, approved list with concise, mutually distinguishable criteria.
- `Score`: impact against concrete descriptions (e.g. routine, degraded with workaround, blocking/no workaround, critical/security-sensitive). Keep scoring semantics separate from arithmetic or policy logic.
- `Noul`: whether any supported category applies, to prevent forced routing for out-of-scope Cases.
- Response: typed answers, probabilities/confidence, model version, and usage. Never treat high confidence as proof of correctness.

### Initial category candidates

These are a starting point for product-owner review, not final approved taxonomy:

- `access`: login, permissions, or account access
- `billing`: charges, invoices, or payments
- `product_issue`: product malfunction or defect
- `integration`: API, connectivity, or integration failure
- `how_to`: product usage question
- `other`: supported-case residual, if the team approves it

The taxonomy must be revised against actual support ownership and queue names before implementation. Prefer a companion Noul for “none of the supported categories applies” rather than relying on `other` as the only catch-all.

### Salesforce state and mapping

Proposed triage state values: `Pending`, `Completed`, `Review Required`, and `Failed`. Confirm API names and whether retry state needs a separate value in the implementation org.

The implementation must define and document:
- Case category and impact fields, including accepted picklist/API values.
- Category-to-queue mapping using portable configuration, not hard-coded org-specific IDs.
- Thresholds for each automated route, selected against labeled evaluation data.
- A human-review queue and review reason for low certainty, unsupported category, security/privacy concerns, malformed response, and final service failure.
- Whether a Case with missing subject/description is sent to review without a Jev call.

Never overwrite a non-empty human-entered value unless the business owner explicitly approves that behavior. Preserve the selected option and relevant probability/triage metadata needed to explain an automated route, without storing unnecessary customer text.

### Reliability, security, and privacy

- Use an async process with durable status and bounded retry behavior. Retry only transient network failures and documented transient responses such as `429`/`529`, using bounded backoff.
- A Jev timeout, authentication/configuration problem, permanent client error, invalid response, or exhausted retry must not block Case creation; mark the Case for review and retain a diagnostic reason that contains no secret or unnecessary customer content.
- Make processing idempotent. Guard against duplicate enqueue, triage-result updates retriggering the worker, and replaying completed Cases.
- For bulk inserts, process within Salesforce callout/job limits and test a continuation strategy for more work than a single job can handle.
- Keep the TypeSafe key in a Named Credential/External Credential. Do not commit credentials. Rotate any API key previously pasted into chat or a config file; do not reuse it.
- Send only the minimum context required. Use synthetic Cases for this workshop. Review TypeSafe's current data processing terms, subprocessors, retention, residency, and required commercial approvals before using real customer data.
- Jev documents known weaknesses including adversarial content, irrelevant context, literal interpretation, option-order sensitivity, and poor numeric/date reasoning. Keep deterministic calculations in code and test prompt-injection-like Case text.

### Evaluation and tests

Create a labeled, synthetic evaluation set and agree on expected answers before tuning thresholds. Keep a holdout subset separate from examples used to write criteria. Report per-category precision/recall or equivalent error counts, false auto-routes, human-review rate, Jev latency, API failure rate, and estimated usage cost. Do not present vendor claims or a few hand-picked examples as proof of production accuracy.

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

## Use Case 2: Diagnose And Fix A Mixed DML Failure

### Scenario

The starter Apex service simulates support-account onboarding. It creates a customer `Account` and assigns the `Support_Account_Triage_Access` permission set to an existing internal support user in the same transaction. `Account` is a business object; `PermissionSetAssignment` is a setup object. Salesforce rejects the mixed transaction with `MIXED_DML_OPERATION`, so onboarding fails.

The starter includes a regression test that exercises the failing path. The code is intentionally defective. Do not deploy it to a shared or production org.

### Participant challenge

Give an AI coding agent the debugging issue, ask it to inspect the repository, reproduce and explain the failure, propose a safe transaction design, then implement the fix with tests. The issue deliberately describes the observed failure and desired behavior without prescribing the solution.

Expected behavior after the fix:
- The customer Account is created successfully.
- The specified support user receives the configured permission set.
- If permission assignment becomes asynchronous, the completion semantics are clear and any failure is observable and retryable rather than silently ignored.
- Duplicate requests do not create duplicate Accounts or assignments.
- Tests cover successful outcomes and invalid user/permission or assignment failure paths.

### Starter files

- `force-app/main/default/classes/SupportAccountOnboarding.cls`: intentionally performs Account DML and PermissionSetAssignment DML in one transaction.
- `force-app/main/default/classes/SupportAccountOnboardingTest.cls`: regression test expected to expose the failure before the fix.
- `force-app/main/default/classes/TestDataFactory.cls`: isolated test user factory.
- `force-app/main/default/permissionsets/Support_Account_Triage_Access.permissionset-meta.xml`: permission set referenced by the sample service.

The learner should not edit the first use case to solve this independent debugging exercise. The challenge uses synthetic data and does not call Jev.

### Test caveat

Salesforce permits mixed DML in certain test-only contexts when the DML is wrapped in `System.runAs`. The regression test intentionally calls the flawed service outside `System.runAs`; keep it that way so the test exposes the same transaction constraint. Salesforce also documents differences in Mixed DML validation during deployment, so run the test in the target test org rather than treating a deploy-validation result as proof that the defect is absent.

## Definition Of Done

- Case creation automatically starts post-commit asynchronous Jev triage; there is no button or manual invocation.
- Case creation remains successful and responsive when Jev is slow or unavailable.
- Salesforce applies only validated, threshold-approved recommendations; other cases have a visible human-review path.
- Bulk, idempotency, recursion, security, and failure-path tests are specified and pass in the authorized implementation org.
- The labeled Jev evaluation set supports the chosen thresholds and documents limitations.
- The Mixed DML exercise starts with an Apex test that demonstrates the defect; after the learner's fix, Account creation and access assignment both complete and regression tests pass.
- The demo org uses synthetic data and has a runbook and service-unavailable fallback.

## References

- TypeSafe, [Introducing System One Models and Jev](https://typesafe.ai/blog/introducing-system-one-models-and-jev)
- TypeSafe, [API Quick Start](https://docs.typesafe.ai/introduction/quickstart.md)
- TypeSafe, [Choice](https://docs.typesafe.ai/primitives/choice.md), [Noul](https://docs.typesafe.ai/primitives/noul.md), and [Score](https://docs.typesafe.ai/primitives/score.md)
- TypeSafe, [Companion Noul](https://docs.typesafe.ai/patterns/companion-noul.md), [Confidence](https://docs.typesafe.ai/confidence.md), and [Model Jaggedness](https://docs.typesafe.ai/model-jaggedness.md)
- TypeSafe, [Request rules and errors](https://docs.typesafe.ai/api/errors.md) and [Data Processing Addendum](https://typesafe.ai/legal/data-processing)
- Salesforce, [Mixed DML operations](https://developer.salesforce.com/docs/platform/apex-dev/references/apex-dev/apex-dml-non-mix-sobjects.html) and [Named Credentials](https://developer.salesforce.com/docs/platform/named-credentials/guide/get-started)